extends Node
## Single source of truth for the party, the current location and quest flags.
## All tunable numbers and content live in res://data/*.json.

const GAME_JSON := "res://data/game.json"
const WORLD_JSON := "res://data/world.json"
const DIALOGUE_JSON := "res://data/dialogue.json"
const ITEMS_JSON := "res://data/items.json"
const COMBAT_JSON := "res://data/combat.json"

var game: Dictionary = {}
var world: Dictionary = {}
var dialogue: Dictionary = {}
var items_data: Dictionary = {}
var combat: Dictionary = {}

# --- Party / game state (the only mutable party state in the project) ---
var party: Array[Dictionary] = []
var gold: int = 0
var experience: int = 0
var inventory: Dictionary = {}
var location_id: String = ""
var spawn_id: String = ""
var house_id: String = ""
var leader_cell: Vector2i = Vector2i.ZERO
var trail: Array[Vector2i] = []
var facing: Vector2i = Vector2i(0, 1)
var flags: Dictionary = {}
var last_rest: Dictionary = {}
var encounters_enabled: bool = true

var _encounter_cooldown_steps: int = 0
var _encounter_rng := RandomNumberGenerator.new()

signal flag_changed(flag: String, value: bool)
signal party_status_changed


func _ready() -> void:
	game = _read_json(GAME_JSON)
	world = _read_json(WORLD_JSON)
	dialogue = _read_json(DIALOGUE_JSON)
	items_data = _read_json(ITEMS_JSON)
	combat = _read_json(COMBAT_JSON)
	_setup_input()
	start_new_game()


func start_new_game() -> void:
	party.clear()
	for member: Dictionary in game["party"]["members"]:
		var runtime_member: Dictionary = member.duplicate(true)
		var max_hp := int(runtime_member.get("max_hp", 1))
		runtime_member["max_hp"] = max_hp
		runtime_member["hp"] = max_hp
		runtime_member["lost"] = false
		runtime_member["row"] = str(runtime_member.get("row", "front"))
		runtime_member["equipment"] = {"weapon": "", "armor": ""}
		runtime_member["spell_charges"] = {}
		var slots: Dictionary = runtime_member.get("spell_slots", {})
		for school: Variant in slots.keys():
			var levels: Dictionary = slots[school]
			var copied_levels: Dictionary = {}
			for level: Variant in levels.keys():
				copied_levels[str(level)] = int(levels[level])
			runtime_member["spell_charges"][str(school)] = copied_levels
		party.append(runtime_member)

	gold = int(game["party"].get("starting_gold", 0))
	experience = int(game["party"].get("starting_experience", 0))
	inventory.clear()
	var starting_inventory: Dictionary = game["party"].get("starting_inventory", {})
	for item_id: Variant in starting_inventory.keys():
		var count := int(starting_inventory[item_id])
		if count > 0:
			inventory[str(item_id)] = count

	flags.clear()
	house_id = ""
	location_id = str(world["start_location"])
	spawn_id = str(world["start_spawn"])
	last_rest = {
		"location": str(world["start_location"]),
		"house_id": "",
		"spawn": str(world["start_spawn"])
	}
	_encounter_cooldown_steps = 0
	var encounter_cfg: Dictionary = combat.get("encounter", {})
	encounters_enabled = bool(encounter_cfg.get("enabled", true))
	var seed_value := int(encounter_cfg.get("rng_seed", 0))
	if seed_value == 0:
		_encounter_rng.randomize()
	else:
		_encounter_rng.seed = seed_value
	apply_spawn(location_id, spawn_id)
	party_status_changed.emit()


# ---------------------------------------------------------------------------
# Spawns and coordinates
# ---------------------------------------------------------------------------

func apply_spawn(loc_id: String, new_spawn_id: String) -> bool:
	var spawn := get_spawn_data(loc_id, new_spawn_id)
	if spawn.is_empty():
		push_error("Unknown spawn '%s' in location '%s'" % [new_spawn_id, loc_id])
		return false

	var new_leader := to_cell(spawn.get("leader", [0, 0]))
	var formation: Array = spawn.get("formation", [])
	var new_trail: Array[Vector2i] = [new_leader]
	for raw_cell: Variant in formation:
		new_trail.append(to_cell(raw_cell))
	while new_trail.size() < party.size():
		new_trail.append(new_trail[new_trail.size() - 1])

	location_id = loc_id
	spawn_id = new_spawn_id
	leader_cell = new_leader
	facing = to_cell(spawn.get("facing", [0, 1]))
	trail = new_trail.slice(0, party.size())
	return true


func commit_step(new_leader: Vector2i, new_facing: Vector2i) -> void:
	var old_leader := leader_cell
	leader_cell = new_leader
	facing = new_facing
	trail.push_front(new_leader)
	if trail.size() > party.size():
		trail.resize(party.size())
	if old_leader == new_leader:
		return


func get_spawn_data(loc_id: String, spawn_name: String) -> Dictionary:
	var loc := get_location(loc_id)
	var spawns: Dictionary = loc.get("spawns", {})
	if not spawns.has(spawn_name):
		return {}
	return spawns[spawn_name]


func get_location(loc_id: String = "") -> Dictionary:
	var key := location_id if loc_id.is_empty() else loc_id
	var locations: Dictionary = world.get("locations", {})
	return locations.get(key, {})


func get_house(house_key: String) -> Dictionary:
	var town: Dictionary = get_location("town")
	for house: Dictionary in town.get("houses", []):
		if str(house.get("id", "")) == house_key:
			return house
	return {}


func get_house_list() -> Array:
	return get_location("town").get("houses", [])


func step_size() -> float:
	return float(game["world"]["step"])


func cell_to_world(cell: Vector2i) -> Vector3:
	var step := step_size()
	return Vector3(float(cell.x) * step, 0.0, float(cell.y) * step)


func to_cell(raw: Variant, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	if raw is Vector2i:
		return raw
	return fallback


func vec2_from_array(raw: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if raw is Array and raw.size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback


func vec3_from_array(raw: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if raw is Array and raw.size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return fallback


# ---------------------------------------------------------------------------
# Quest / objective state
# ---------------------------------------------------------------------------

func mark_flag(flag: String) -> bool:
	if flags.get(flag, false):
		return false
	flags[flag] = true
	flag_changed.emit(flag, true)
	return true


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func objective_text() -> String:
	var ui: Dictionary = game["ui"]
	if has_flag("king_rescued_spoken"):
		return str(ui["objective_complete"])
	if has_flag("sarah_rescued"):
		return str(ui["objective_rescued"])
	if has_flag("king_spoken"):
		return str(ui["objective_done"])
	if has_flag("throne_entered"):
		return str(ui["objective_king"])
	if has_flag("reached_bridge_end"):
		return str(ui["objective_return"])
	return str(ui["objective_bridge"])


func ui_text(key: String, fallback: String = "") -> String:
	var ui: Dictionary = game.get("ui", {})
	return str(ui.get(key, fallback))


func get_dialogue(npc_id: String) -> Dictionary:
	var all: Dictionary = dialogue.get("dialogues", {})
	var base: Dictionary = all.get(npc_id, {})
	if npc_id == "king" and has_flag("sarah_rescued"):
		var after: Dictionary = base.get("after", {})
		if not after.is_empty():
			return after
	return base


func get_cutscene(cutscene_id: String) -> Array:
	var all: Dictionary = dialogue.get("cutscenes", {})
	return all.get(cutscene_id, [])


func dialogue_ui(key: String, fallback: String = "") -> String:
	var ui: Dictionary = dialogue.get("ui", {})
	return str(ui.get(key, fallback))


func member_by_id(member_id: String) -> Dictionary:
	for member: Dictionary in party:
		if str(member.get("id", "")) == member_id:
			return member
	return {}


func party_snapshot() -> Array:
	return party.duplicate(true)


# ---------------------------------------------------------------------------
# Gold, inventory, hero HP and house services
# ---------------------------------------------------------------------------

func currency_short() -> String:
	var currency: Dictionary = items_data.get("currency", {})
	return str(currency.get("short", "G"))


func currency_name() -> String:
	var currency: Dictionary = items_data.get("currency", {})
	return str(currency.get("name", "гил"))


func service_ui(key: String, fallback: String = "") -> String:
	var ui: Dictionary = items_data.get("ui", {})
	return str(ui.get(key, fallback))


func get_item(item_id: String) -> Dictionary:
	var all_items: Dictionary = items_data.get("items", {})
	return all_items.get(item_id, {})


func get_item_name(item_id: String) -> String:
	return str(get_item(item_id).get("name", item_id))


func get_service(service_id: String) -> Dictionary:
	var services: Dictionary = items_data.get("services", {})
	return services.get(service_id, {})


func get_service_id_for_house(house_key: String) -> String:
	var house := get_house(house_key)
	return str(house.get("service", ""))


func get_service_for_house(house_key: String) -> Dictionary:
	return get_service(get_service_id_for_house(house_key))


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func inventory_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var all_items: Dictionary = items_data.get("items", {})
	for item_id: Variant in all_items.keys():
		var count := item_count(str(item_id))
		if count <= 0:
			continue
		var item: Dictionary = all_items[item_id]
		entries.append({
			"id": str(item_id),
			"name": str(item.get("name", item_id)),
			"description": str(item.get("description", "")),
			"count": count
		})
	return entries


func get_inventory_summary_text() -> String:
	var entries := inventory_entries()
	if entries.is_empty():
		return service_ui("bag_empty", "Сумка пуста")
	var parts: PackedStringArray = []
	for entry: Dictionary in entries:
		parts.append("%s ×%d" % [str(entry["name"]), int(entry["count"])])
	return "   ".join(parts)


# ---------------------------------------------------------------------------
# Equipment, derived stats, rows and spell charges
# ---------------------------------------------------------------------------

func get_effective_stats(member_id: String) -> Dictionary:
	var member := member_by_id(member_id)
	if member.is_empty():
		return {"attack": 0, "defense": 0, "agility": 0, "magic": 0}
	var result: Dictionary = {"attack": 0, "defense": 0, "agility": 0, "magic": 0}
	var base: Dictionary = member.get("base_stats", {})
	for stat_name: String in result.keys():
		result[stat_name] = int(base.get(stat_name, 0))
	var equipment: Dictionary = member.get("equipment", {})
	for slot: String in ["weapon", "armor"]:
		var item_id := str(equipment.get(slot, ""))
		if item_id.is_empty():
			continue
		var item_stats: Dictionary = get_item(item_id).get("stats", {})
		for stat_name: String in result.keys():
			result[stat_name] = int(result[stat_name]) + int(item_stats.get(stat_name, 0))
	return result


func get_equipped_item_id(member_id: String, slot: String) -> String:
	var member := member_by_id(member_id)
	if member.is_empty():
		return ""
	var equipment: Dictionary = member.get("equipment", {})
	return str(equipment.get(slot, ""))


func get_equipped_item(member_id: String, slot: String) -> Dictionary:
	var item_id := get_equipped_item_id(member_id, slot)
	if item_id.is_empty():
		return {}
	return get_item(item_id)


func get_equipment_entries(slot: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var all_items: Dictionary = items_data.get("items", {})
	for item_id: Variant in all_items.keys():
		var item: Dictionary = all_items[item_id]
		if str(item.get("slot", "")) != slot:
			continue
		var count := item_count(str(item_id))
		if count <= 0:
			continue
		entries.append({
			"id": str(item_id),
			"name": str(item.get("name", item_id)),
			"description": str(item.get("description", "")),
			"count": count,
			"stats": item.get("stats", {}).duplicate(true)
		})
	return entries


func equip_item(member_id: String, slot: String, item_id: String) -> Dictionary:
	if slot != "weapon" and slot != "armor":
		return {"ok": false, "message": "Неизвестный слот снаряжения."}
	var member := member_by_id(member_id)
	if member.is_empty():
		return {"ok": false, "message": "Такого героя нет в отряде."}
	if item_id.is_empty():
		return unequip_item(member_id, slot)
	var item := get_item(item_id)
	if item.is_empty() or str(item.get("slot", "")) != slot:
		return {"ok": false, "message": "Этот предмет не подходит в этот слот."}
	if item_count(item_id) <= 0:
		return {"ok": false, "message": "В сумке нет этого предмета."}
	var equipment: Dictionary = member.get("equipment", {})
	var previous := str(equipment.get(slot, ""))
	_remove_inventory_item(item_id, 1)
	if not previous.is_empty():
		inventory[previous] = item_count(previous) + 1
	equipment[slot] = item_id
	member["equipment"] = equipment
	party_status_changed.emit()
	return {"ok": true, "message": "Экипировано: %s." % get_item_name(item_id)}


func unequip_item(member_id: String, slot: String) -> Dictionary:
	var member := member_by_id(member_id)
	if member.is_empty():
		return {"ok": false, "message": "Такого героя нет в отряде."}
	var equipment: Dictionary = member.get("equipment", {})
	var previous := str(equipment.get(slot, ""))
	if previous.is_empty():
		return {"ok": false, "message": "Этот слот уже пуст."}
	inventory[previous] = item_count(previous) + 1
	equipment[slot] = ""
	member["equipment"] = equipment
	party_status_changed.emit()
	return {"ok": true, "message": "Снято: %s." % get_item_name(previous)}


func set_member_row(member_id: String, new_row: String) -> bool:
	if new_row != "front" and new_row != "back":
		return false
	var member := member_by_id(member_id)
	if member.is_empty():
		return false
	member["row"] = new_row
	party_status_changed.emit()
	return true


func toggle_member_row(member_id: String) -> bool:
	var member := member_by_id(member_id)
	if member.is_empty():
		return false
	var new_row := "back" if str(member.get("row", "front")) == "front" else "front"
	return set_member_row(member_id, new_row)


func get_member_row(member_id: String) -> String:
	var member := member_by_id(member_id)
	if member.is_empty():
		return "front"
	return str(member.get("row", "front"))


func get_known_spells(member_id: String) -> Array[String]:
	var result: Array[String] = []
	var member := member_by_id(member_id)
	for raw_id: Variant in member.get("spells", []):
		result.append(str(raw_id))
	return result


func get_spell_charges(member_id: String, school: String, level: int) -> int:
	var member := member_by_id(member_id)
	if member.is_empty():
		return 0
	var charges: Dictionary = member.get("spell_charges", {})
	var levels: Dictionary = charges.get(school, {})
	return int(levels.get(str(level), 0))


func consume_spell_charge(member_id: String, school: String, level: int) -> bool:
	var member := member_by_id(member_id)
	if member.is_empty():
		return false
	var charges: Dictionary = member.get("spell_charges", {})
	var levels: Dictionary = charges.get(school, {})
	var current := int(levels.get(str(level), 0))
	if current <= 0:
		return false
	levels[str(level)] = current - 1
	charges[school] = levels
	member["spell_charges"] = charges
	party_status_changed.emit()
	return true


func restore_member_charges(member: Dictionary) -> void:
	var slots: Dictionary = member.get("spell_slots", {})
	var restored: Dictionary = {}
	for school: Variant in slots.keys():
		var levels: Dictionary = slots[school]
		var copied: Dictionary = {}
		for level: Variant in levels.keys():
			copied[str(level)] = int(levels[level])
		restored[str(school)] = copied
	member["spell_charges"] = restored


func restore_all_spell_charges() -> void:
	for member: Dictionary in party:
		restore_member_charges(member)
	party_status_changed.emit()


func get_spell(spell_id: String) -> Dictionary:
	var spells: Dictionary = combat.get("spells", {})
	return spells.get(spell_id, {})


func get_combat_ui(key: String, fallback: String = "") -> String:
	var ui: Dictionary = combat.get("ui", {})
	return str(ui.get(key, fallback))


func get_battle_usable_items() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var all_items: Dictionary = items_data.get("items", {})
	for item_id: Variant in all_items.keys():
		var item: Dictionary = all_items[item_id]
		if not item.has("battle_use"):
			continue
		var count := item_count(str(item_id))
		if count <= 0:
			continue
		entries.append({
			"id": str(item_id),
			"name": str(item.get("name", item_id)),
			"count": count,
			"battle_use": item["battle_use"].duplicate(true),
			"description": str(item.get("description", ""))
		})
	return entries


func consume_inventory_item(item_id: String, amount: int = 1) -> bool:
	var count := item_count(item_id)
	if count < amount:
		return false
	_remove_inventory_item(item_id, amount)
	party_status_changed.emit()
	return true


func heal_member(member_id: String, amount: int) -> int:
	var member := member_by_id(member_id)
	if member.is_empty() or amount <= 0:
		return 0
	var before := int(member.get("hp", 0))
	var max_hp := int(member.get("max_hp", 1))
	var after := mini(max_hp, before + amount)
	set_member_hp(member_id, after)
	return after - before


func damage_member(member_id: String, amount: int) -> int:
	var member := member_by_id(member_id)
	if member.is_empty() or amount <= 0:
		return 0
	var before := int(member.get("hp", 0))
	var after := maxi(0, before - amount)
	set_member_hp(member_id, after)
	return before - after


func _remove_inventory_item(item_id: String, amount: int) -> void:
	var count := item_count(item_id)
	if count <= amount:
		inventory.erase(item_id)
	else:
		inventory[item_id] = count - amount


# ---------------------------------------------------------------------------
# Experience, rest checkpoint and defeat recovery
# ---------------------------------------------------------------------------

func add_battle_rewards(xp_gain: int, gold_gain: int) -> void:
	experience += maxi(0, xp_gain)
	gold += maxi(0, gold_gain)
	party_status_changed.emit()


func prepare_defeat_return() -> Dictionary:
	heal_all_members()
	restore_all_spell_charges()
	party_status_changed.emit()
	if last_rest.is_empty():
		return {
			"location": str(world["start_location"]),
			"house_id": "",
			"spawn": str(world["start_spawn"])
		}
	return last_rest.duplicate(true)


# ---------------------------------------------------------------------------
# Bridge encounters and combat formulas
# ---------------------------------------------------------------------------

func is_bridge_cell(cell: Vector2i) -> bool:
	var town: Dictionary = get_location("town")
	var bridge: Dictionary = town.get("bridge", {})
	if bridge.is_empty():
		return false
	var world_pos := cell_to_world(cell)
	var half_width := float(bridge.get("width", 8.0)) * 0.5
	if absf(world_pos.x) > half_width:
		return false
	var start_z := float(bridge.get("start_z", -34.0))
	var end_z := float(bridge.get("end_z", -70.0))
	return world_pos.z <= start_z and world_pos.z >= end_z


func try_start_encounter(cell: Vector2i) -> Dictionary:
	if not encounters_enabled:
		return {}
	var chance := 0.0
	var ids: Array = []
	if location_id == "town":
		if not is_bridge_cell(cell):
			return {}
		var bridge_cfg: Dictionary = combat.get("encounter", {})
		chance = float(bridge_cfg.get("bridge_chance", 0.0))
		ids = bridge_cfg.get("bridge_ids", [])
	else:
		var location_cfg: Dictionary = get_location().get("encounter", {})
		if location_cfg.is_empty():
			return {}
		chance = float(location_cfg.get("chance", 0.0))
		ids = location_cfg.get("ids", [])
	if chance <= 0.0:
		return {}
	if _encounter_cooldown_steps > 0:
		_encounter_cooldown_steps -= 1
		return {}
	if _encounter_rng.randf() > chance:
		return {}
	return _pick_weighted_encounter(ids)


func set_post_battle_grace() -> void:
	var encounter_cfg: Dictionary = combat.get("encounter", {})
	_encounter_cooldown_steps = int(encounter_cfg.get("cooldown_steps", 0))


func get_encounter_by_id(encounter_id: String) -> Dictionary:
	for encounter: Dictionary in combat.get("encounters", []):
		if str(encounter.get("id", "")) == encounter_id:
			return encounter
	return {}


func _pick_weighted_encounter(ids: Array = []) -> Dictionary:
	var pool: Array[Dictionary] = []
	var all_encounters: Array = combat.get("encounters", [])
	for encounter: Dictionary in all_encounters:
		if not ids.is_empty() and not ids.has(str(encounter.get("id", ""))):
			continue
		pool.append(encounter)
	if pool.is_empty():
		return {}
	var total_weight := 0.0
	for encounter: Dictionary in pool:
		total_weight += maxf(0.0, float(encounter.get("weight", 1.0)))
	if total_weight <= 0.0:
		return {}
	var roll := _encounter_rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for encounter: Dictionary in pool:
		cursor += maxf(0.0, float(encounter.get("weight", 1.0)))
		if roll <= cursor:
			return encounter.duplicate(true)
	return pool[pool.size() - 1].duplicate(true)


func get_boss_encounter(boss_id: String) -> Dictionary:
	var bosses: Dictionary = combat.get("bosses", {})
	return bosses.get(boss_id, {})


func open_chest(chest_id: String, item_id: String, opened_flag: String) -> Dictionary:
	if has_flag(opened_flag):
		return {"ok": false, "already_open": true, "message": "Сундук пуст."}
	var item := get_item(item_id)
	if item.is_empty():
		return {"ok": false, "message": "Сундук не открывается."}
	inventory[item_id] = item_count(item_id) + 1
	mark_flag(opened_flag)
	party_status_changed.emit()
	return {
		"ok": true,
		"message": "Получен предмет: %s." % str(item.get("name", item_id)),
		"item_id": item_id
	}


func unlock_door(door_flag: String, key_item_id: String) -> Dictionary:
	if has_flag(door_flag):
		return {"ok": true, "already_open": true, "message": "Дверь уже открыта."}
	if item_count(key_item_id) <= 0:
		return {"ok": false, "message": "Дверь заперта. Нужен ключ Хаоса."}
	mark_flag(door_flag)
	return {"ok": true, "message": "Ключ подошёл. Дверь открыта."}


func eval_combat_formula(formula_key: String, inputs: Dictionary) -> float:
	var formulas: Dictionary = combat.get("formulas", {})
	var formula := str(formulas.get(formula_key, "0"))
	var names: Array[String] = []
	var values: Array = []
	for key: String in inputs.keys():
		names.append(key)
		values.append(inputs[key])
	var expression := Expression.new()
	var parse_error := expression.parse(formula, names)
	if parse_error != OK:
		push_error("Bad combat formula '%s': %s" % [formula_key, expression.get_error_text()])
		return 0.0
	var result: Variant = expression.execute(values, null, false)
	if expression.has_execute_failed():
		push_error("Combat formula failed: %s" % formula_key)
		return 0.0
	if not (result is float or result is int):
		return 0.0
	return float(result)


func is_member_lost(member: Dictionary) -> bool:
	return bool(member.get("lost", false)) or int(member.get("hp", 0)) <= 0


func get_lost_members() -> Array[Dictionary]:
	var lost: Array[Dictionary] = []
	for member: Dictionary in party:
		if is_member_lost(member):
			lost.append(member)
	return lost


func set_member_hp(member_id: String, new_hp: int) -> bool:
	var member := member_by_id(member_id)
	if member.is_empty():
		return false
	var max_hp := int(member.get("max_hp", 1))
	var clamped := clampi(new_hp, 0, max_hp)
	member["hp"] = clamped
	member["lost"] = clamped <= 0
	party_status_changed.emit()
	return true


func heal_all_members() -> void:
	for member: Dictionary in party:
		var max_hp := int(member.get("max_hp", 1))
		member["hp"] = max_hp
		member["lost"] = false
	party_status_changed.emit()


func can_afford(price: int) -> bool:
	return gold >= price


func get_shop_entries(service_id: String, mode: String) -> Array[Dictionary]:
	var service := get_service(service_id)
	var entries: Array[Dictionary] = []
	var stock: Array = service.get("stock", [])
	for raw_id: Variant in stock:
		var item_id := str(raw_id)
		var item := get_item(item_id)
		if item.is_empty():
			continue
		var owned := item_count(item_id)
		if mode == "sell" and owned <= 0:
			continue
		var price := int(item.get("buy_price", 0))
		if mode == "sell":
			price = int(item.get("sell_price", 0))
		entries.append({
			"id": item_id,
			"name": str(item.get("name", item_id)),
			"description": str(item.get("description", "")),
			"price": price,
			"owned": owned
		})
	return entries


func buy_item(service_id: String, item_id: String) -> Dictionary:
	var service := get_service(service_id)
	if str(service.get("type", "")) != "shop":
		return _service_result(false, "Здесь не торгуют.")
	if not _stock_has(service, item_id):
		return _service_result(false, "Этого товара нет в продаже.")
	var item := get_item(item_id)
	var price := int(item.get("buy_price", 0))
	if not can_afford(price):
		return _service_result(false, _not_enough_gold_message(price))
	gold -= price
	inventory[item_id] = item_count(item_id) + 1
	party_status_changed.emit()
	return _service_result(true, "Куплено: %s  (−%d %s)." % [str(item.get("name", item_id)), price, currency_short()])


func sell_item(service_id: String, item_id: String) -> Dictionary:
	var service := get_service(service_id)
	if str(service.get("type", "")) != "shop":
		return _service_result(false, "Здесь не торгуют.")
	if not _stock_has(service, item_id):
		return _service_result(false, "Эта лавка не покупает такой товар.")
	var owned := item_count(item_id)
	if owned <= 0:
		return _service_result(false, "В сумке нет этого предмета.")
	var item := get_item(item_id)
	var price := int(item.get("sell_price", 0))
	gold += price
	if owned <= 1:
		inventory.erase(item_id)
	else:
		inventory[item_id] = owned - 1
	party_status_changed.emit()
	return _service_result(true, "Продано: %s  (+%d %s)." % [str(item.get("name", item_id)), price, currency_short()])


func use_inn(service_id: String) -> Dictionary:
	var service := get_service(service_id)
	if str(service.get("type", "")) != "inn":
		return _service_result(false, "Здесь не сдают комнат.")
	var price := int(service.get("price", 0))
	if not can_afford(price):
		return _service_result(false, _not_enough_gold_message(price))
	gold -= price
	for member: Dictionary in party:
		var max_hp := int(member.get("max_hp", 1))
		member["hp"] = max_hp
		member["lost"] = false
		restore_member_charges(member)
	var checkpoint_house := house_id
	if checkpoint_house.is_empty():
		for house: Dictionary in get_house_list():
			if str(house.get("service", "")) == service_id:
				checkpoint_house = str(house.get("id", ""))
				break
	if not checkpoint_house.is_empty():
		last_rest = {
			"location": "house",
			"house_id": checkpoint_house,
			"spawn": "entry"
		}
	party_status_changed.emit()
	return _service_result(true, "Ночлег оплачен  (−%d %s). Все четверо героев полностью исцелены, заряды магии восстановлены." % [price, currency_short()])


func use_clinic(service_id: String, member_id: String) -> Dictionary:
	var service := get_service(service_id)
	if str(service.get("type", "")) != "clinic":
		return _service_result(false, "Здесь не лечат.")
	var member := member_by_id(member_id)
	if member.is_empty():
		return _service_result(false, "Такого героя нет в отряде.")
	if not is_member_lost(member):
		return _service_result(false, "Этот герой не потерян и не нуждается в помощи.")
	var price := int(service.get("price", 0))
	if not can_afford(price):
		return _service_result(false, _not_enough_gold_message(price))
	gold -= price
	var max_hp := int(member.get("max_hp", 1))
	member["hp"] = max_hp
	member["lost"] = false
	party_status_changed.emit()
	return _service_result(true, "%s возвращён в строй. Лечение оплачено  (−%d %s)." % [str(member.get("name", member_id)), price, currency_short()])


func _stock_has(service: Dictionary, item_id: String) -> bool:
	for raw_id: Variant in service.get("stock", []):
		if str(raw_id) == item_id:
			return true
	return false


func _not_enough_gold_message(price: int) -> String:
	return "Не хватает золота. Нужно: %d %s." % [price, currency_short()]


func _service_result(ok: bool, message: String) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
		"gold": gold,
		"inventory": inventory.duplicate(true)
	}


# ---------------------------------------------------------------------------
# Input + config helpers
# ---------------------------------------------------------------------------

func _setup_input() -> void:
	var controls: Dictionary = game.get("controls", {})
	for action_name: String in controls.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		for keycode: Variant in controls[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = int(keycode)
			InputMap.action_add_event(action_name, event)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		assert(false, "Missing data file")
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Invalid JSON in %s" % path)
		assert(false, "Invalid JSON")
		return {}
	return parsed
