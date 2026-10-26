extends Node3D

signal portal_requested(door: Dictionary)
signal step_completed(cell: Vector2i)

var data: Dictionary
var math: Dictionary
var visuals
var state: Dictionary = {}
var checkpoint: Dictionary = {}
var models: Array = []


func _init(config: Dictionary, factory) -> void:
	data = config
	math = data.settings.math
	visuals = factory


func _ready() -> void:
	name = "Party"
	state = {
		"location": str(data.party.location),
		"heroes": [],
		"history": [],
		"facing": visuals.cell(data.party.direction),
		"moving": false,
		"progress": math.zero,
		"locked": false,
		"flags": {},
		"gold": int(data.party.gold),
		"inventory": data.party.inventory.duplicate(true)
	}
	if data.party.heroes.size() != int(data.settings.party_size):
		push_error("The party must contain exactly four heroes.")
		return
	for definition in data.party.heroes:
		state.heroes.append({
			"id": str(definition.id),
			"cell": Vector2i.ZERO,
			"from": Vector2i.ZERO,
			"max_hp": int(definition.max_hp),
			"hp": int(definition.hp),
			"fallen": bool(definition.fallen),
			"level": int(definition.level),
			"experience": int(definition.experience),
			"attack": int(definition.attack),
			"defense": int(definition.defense),
			"agility": int(definition.agility),
			"row": str(definition.row),
			"charges": definition.charges.duplicate(true),
			"equipment": definition.equipment.duplicate(true)
		})
		models.append(visuals.character(self, str(definition.id)))
	relocate(str(data.party.location), visuals.cell(data.party.spawn), visuals.cell(data.party.direction))
	checkpoint = make_checkpoint(str(data.party.location), visuals.cell(data.party.spawn), visuals.cell(data.party.direction))


func item(item_id: String) -> Dictionary:
	for catalog in data.economy.catalogs.values():
		for definition in catalog:
			if str(definition.id) == item_id:
				return definition
	return {}


func item_count(item_id: String) -> int:
	return int(state.inventory.get(item_id, int(math.zero)))


func add_item(item_id: String, amount: int) -> void:
	state.inventory[item_id] = maxi(int(math.zero), item_count(item_id) + amount)


func flag(flag_name: String) -> bool:
	return bool(state.flags.get(flag_name, false))


func set_flag(flag_name: String) -> void:
	state.flags[flag_name] = true


func equipped_count(item_id: String) -> int:
	var count: int = int(math.zero)
	for hero in state.heroes:
		for slot in hero.equipment.values():
			if str(slot) == item_id:
				count += int(math.one)
	return count


func hero_stat(hero_index: int, stat_name: String) -> int:
	var hero: Dictionary = state.heroes[hero_index]
	var result: int = int(hero[stat_name])
	for item_id in hero.equipment.values():
		if str(item_id).is_empty():
			continue
		var definition: Dictionary = item(str(item_id))
		result += int(definition.get(stat_name, int(math.zero)))
	return result


func equip_item(hero_index: int, item_id: String) -> bool:
	var definition: Dictionary = item(item_id)
	if definition.is_empty() or not definition.has("slot"):
		return false
	if str(state.heroes[hero_index].equipment[definition.slot]) == item_id:
		return true
	if item_count(item_id) <= equipped_count(item_id):
		return false
	state.heroes[hero_index].equipment[definition.slot] = item_id
	return true


func unequip(hero_index: int, slot: String) -> void:
	state.heroes[hero_index].equipment[slot] = ""


func toggle_row(hero_index: int) -> void:
	var hero: Dictionary = state.heroes[hero_index]
	hero.row = "back" if str(hero.row) == "front" else "front"


func spells(hero_index: int) -> Array:
	return data.party.heroes[hero_index].spells


func charge_count(hero_index: int, level: int) -> int:
	return int(state.heroes[hero_index].charges.get(str(level), int(math.zero)))


func spend_charge(hero_index: int, level: int) -> bool:
	var key: String = str(level)
	if charge_count(hero_index, level) <= int(math.zero):
		return false
	state.heroes[hero_index].charges[key] = charge_count(hero_index, level) - int(math.one)
	return true


func is_caster(hero_index: int) -> bool:
	return not data.party.heroes[hero_index].charges.is_empty()


func can_use_item(item_id: String, hero_index: int) -> bool:
	var definition: Dictionary = item(item_id)
	if item_count(item_id) <= int(math.zero) or not definition.has("effect"):
		return false
	var hero: Dictionary = state.heroes[hero_index]
	match str(definition.target):
		"ally":
			return not bool(hero.fallen) and int(hero.hp) < int(hero.max_hp)
		"fallen":
			return bool(hero.fallen)
		"caster":
			if bool(hero.fallen) or not is_caster(hero_index):
				return false
			for level in data.party.heroes[hero_index].charges:
				if charge_count(hero_index, int(level)) < int(data.party.heroes[hero_index].charges[level]):
					return true
	return false


func use_item(item_id: String, hero_index: int) -> int:
	if not can_use_item(item_id, hero_index):
		return -int(math.one)
	var definition: Dictionary = item(item_id)
	var hero: Dictionary = state.heroes[hero_index]
	add_item(item_id, -int(math.one))
	match str(definition.effect):
		"heal":
			var amount: int = mini(int(hero.max_hp) - int(hero.hp), int(definition.power))
			hero.hp += amount
			return amount
		"revive":
			hero.fallen = false
			hero.hp = maxi(int(math.one), roundi(float(hero.max_hp) * float(definition.ratio)))
			refresh_spirits()
			return int(hero.hp)
		_:
			hero.charges = data.party.heroes[hero_index].charges.duplicate(true)
			return int(math.zero)


func usable_items() -> Array:
	var result: Array = []
	for catalog in data.economy.catalogs.values():
		for definition in catalog:
			if definition.has("effect") and item_count(str(definition.id)) > int(math.zero):
				result.append(definition)
	return result


func gain_rewards(experience: int, gold: int) -> Dictionary:
	state.gold += gold
	var living: Array = []
	for index in range(state.heroes.size()):
		if not bool(state.heroes[index].fallen):
			living.append(index)
	var share: int = ceili(float(experience) / float(maxi(int(math.one), living.size())))
	var level_ups: Array = []
	var levels: Array = data.party.levels
	for index in living:
		var hero: Dictionary = state.heroes[index]
		var definition: Dictionary = data.party.heroes[index]
		hero.experience += share
		while int(hero.level) < levels.size() and int(hero.experience) >= int(levels[int(hero.level)]):
			hero.level += int(math.one)
			for stat in definition.growth:
				hero[stat] += int(definition.growth[stat])
			hero.hp += int(definition.growth.max_hp)
			level_ups.append(str(data.battle.text.level_up) % [str(definition.name), int(hero.level)])
	return {"share": share, "level_ups": level_ups}


func buy_item(item_id: String) -> String:
	var definition: Dictionary = item(item_id)
	if definition.is_empty():
		return ""
	if int(state.gold) < int(definition.buy):
		return str(data.economy.text.no_gold)
	state.gold -= int(definition.buy)
	state.inventory[item_id] = item_count(item_id) + int(math.one)
	return str(data.economy.text.bought) % [str(definition.name), int(definition.buy)]


func sell_item(item_id: String) -> String:
	var definition: Dictionary = item(item_id)
	if definition.is_empty():
		return ""
	if item_count(item_id) <= int(math.zero):
		return str(data.economy.text.sold_out)
	if bool(definition.get("key", false)):
		return str(data.economy.text.key_sale)
	if item_count(item_id) <= equipped_count(item_id):
		return str(data.economy.text.equipped_sale)
	state.gold += int(definition.sell)
	state.inventory[item_id] = item_count(item_id) - int(math.one)
	return str(data.economy.text.sold) % [str(definition.name), int(definition.sell)]


func make_checkpoint(location_id: String, spawn: Vector2i, facing: Vector2i) -> Dictionary:
	var heroes: Array = []
	var keys: Array = ["max_hp", "hp", "fallen", "level", "experience", "attack", "defense", "agility", "row", "charges", "equipment"]
	for hero in state.heroes:
		var saved: Dictionary = {}
		for key in keys:
			saved[key] = hero[key]
		heroes.append(saved.duplicate(true))
	return {"location": location_id, "spawn": [spawn.x, spawn.y], "direction": [facing.x, facing.y], "gold": int(state.gold), "inventory": state.inventory.duplicate(true), "heroes": heroes, "flags": state.flags.duplicate(true)}


func restore_checkpoint() -> void:
	state.gold = int(checkpoint.gold)
	state.inventory = checkpoint.inventory.duplicate(true)
	state.flags = checkpoint.flags.duplicate(true)
	for index in range(state.heroes.size()):
		for key in checkpoint.heroes[index]:
			state.heroes[index][key] = checkpoint.heroes[index][key].duplicate(true) if checkpoint.heroes[index][key] is Dictionary or checkpoint.heroes[index][key] is Array else checkpoint.heroes[index][key]
	relocate(str(checkpoint.location), visuals.cell(checkpoint.spawn), visuals.cell(checkpoint.direction))


func rest() -> String:
	var price: int = int(data.economy.inn_price)
	if int(state.gold) < price:
		return str(data.economy.text.no_gold)
	state.gold -= price
	for index in range(state.heroes.size()):
		var hero: Dictionary = state.heroes[index]
		if not bool(hero.fallen):
			hero.hp = int(hero.max_hp)
		hero.charges = data.party.heroes[index].charges.duplicate(true)
	checkpoint = make_checkpoint("home_hearth", visuals.cell(data.home_template.arrival), visuals.cell(data.home_template.direction))
	return str(data.economy.text.inn_success)


func revive(hero_index: int) -> String:
	if hero_index < int(math.zero) or hero_index >= state.heroes.size():
		return str(data.economy.text.clinic_none)
	var hero: Dictionary = state.heroes[hero_index]
	if not bool(hero.fallen):
		return str(data.economy.text.clinic_none)
	var price: int = int(data.economy.clinic_price)
	if int(state.gold) < price:
		return str(data.economy.text.no_gold)
	state.gold -= price
	hero.fallen = false
	hero.hp = int(hero.max_hp)
	refresh_spirits()
	return str(data.economy.text.clinic_success) % str(data.party.heroes[hero_index].name)


func relocate(location_id: String, spawn: Vector2i, facing: Vector2i) -> void:
	state.location = location_id
	state.facing = facing
	state.moving = false
	state.progress = math.zero
	state.history.clear()
	for hero in state.heroes:
		hero.cell = spawn
		hero.from = spawn
	for index in range(int(math.one), state.heroes.size()):
		state.history.append(spawn)
	_sync_instant()
	refresh_spirits()


func formation(cells: Array, facing: Vector2i) -> void:
	state.facing = facing
	state.history.clear()
	for index in range(state.heroes.size()):
		state.heroes[index].cell = cells[index]
		state.heroes[index].from = cells[index]
		if index > int(math.zero):
			state.history.append(cells[index])
	_sync_instant()


func refresh_spirits() -> void:
	for index in range(models.size()):
		visuals.fade(models[index], float(data.settings.spirit_transparency) if bool(state.heroes[index].fallen) else math.zero)


func _update_visibility() -> void:
	for index in range(models.size()):
		var hero: Dictionary = state.heroes[index]
		var covered: bool = false
		for other in range(index):
			if state.heroes[other].cell == hero.cell and state.heroes[other].from == hero.from:
				covered = true
		models[index].visible = not covered


func _sync_instant() -> void:
	for index in range(models.size()):
		models[index].position = visuals.at(state.heroes[index].cell, math.zero)
		models[index].rotation.y = atan2(float(state.facing.x), float(state.facing.y))
	_update_visibility()


func leader_cell() -> Vector2i:
	return state.heroes.front().cell


func leader_position() -> Vector3:
	if models.is_empty():
		return Vector3.ZERO
	return models.front().global_position


func is_idle() -> bool:
	return not bool(state.moving) and not bool(state.locked)


func set_locked(value: bool) -> void:
	state.locked = value


func _input_direction() -> Vector2i:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return Vector2i.ZERO
	if absf(input.x) > absf(input.y):
		return Vector2i.RIGHT if input.x > math.zero else Vector2i.LEFT
	return Vector2i.DOWN if input.y > math.zero else Vector2i.UP


func _face(direction: Vector2i) -> void:
	state.facing = direction
	if not models.is_empty():
		models.front().rotation.y = atan2(float(direction.x), float(direction.y))


func _restore_history_tail() -> void:
	while state.history.size() < state.heroes.size():
		if state.history.size() >= int(math.double):
			var last: Vector2i = state.history.back()
			var previous: Vector2i = state.history[state.history.size() - int(math.double)]
			state.history.append(last + last - previous)
		else:
			state.history.append(leader_cell() - state.facing * state.history.size())


func _step(direction: Vector2i, world) -> void:
	_face(direction)
	var origin: Vector2i = leader_cell()
	var destination: Vector2i = origin + direction
	if not bool(world.is_walkable(destination)):
		return
	if destination != state.history.front():
		for index in range(int(math.one), state.heroes.size()):
			if state.heroes[index].cell == destination:
				return
	for hero in state.heroes:
		hero.from = hero.cell
	if not state.history.is_empty() and destination == state.history.front():
		state.history.pop_front()
	else:
		state.history.push_front(origin)
		while state.history.size() > int(data.settings.history_limit):
			state.history.pop_back()
	_restore_history_tail()
	state.heroes.front().cell = destination
	for index in range(int(math.one), state.heroes.size()):
		state.heroes[index].cell = state.history[index - int(math.one)]
	state.progress = math.zero
	state.moving = true
	_update_visibility()


func tick(delta: float, world, input_enabled: bool) -> void:
	if bool(state.locked):
		return
	if bool(state.moving):
		state.progress = minf(float(math.one), float(state.progress) + delta / float(data.settings.step_duration))
		var blend: float = smoothstep(float(math.zero), float(math.one), float(state.progress))
		for index in range(models.size()):
			var hero: Dictionary = state.heroes[index]
			var start: Vector3 = visuals.at(hero.from, math.zero)
			var finish: Vector3 = visuals.at(hero.cell, math.zero)
			models[index].position = start.lerp(finish, blend)
			var direction: Vector2i = hero.cell - hero.from
			if direction != Vector2i.ZERO:
				models[index].rotation.y = atan2(float(direction.x), float(direction.y))
		if float(state.progress) >= float(math.one):
			state.moving = false
			for hero in state.heroes:
				hero.from = hero.cell
			_update_visibility()
			step_completed.emit(leader_cell())
			if bool(state.locked):
				return
			var door: Dictionary = world.portal_for(leader_cell())
			if not door.is_empty():
				state.locked = true
				portal_requested.emit(door)
				return
	if input_enabled and not bool(state.moving):
		var direction: Vector2i = _input_direction()
		if direction != Vector2i.ZERO:
			_step(direction, world)
