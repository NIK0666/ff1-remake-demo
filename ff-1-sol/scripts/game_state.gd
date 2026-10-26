extends Node
## The only authoritative party/session state. Scene nodes are presentation only.

var rules: Dictionary
var map: Dictionary
var art: Dictionary
var economy: Dictionary
var combat: Dictionary
var dungeon: Dictionary
var polish: Dictionary
var battle_system
var formula_cache: Dictionary = {}
var session: Dictionary

func _ready() -> void:
	rules = _read("res://data/game.json")
	map = _read("res://data/world.json")
	art = _read("res://data/art.json")
	economy = _read("res://data/services.json")
	combat = _read("res://data/combat.json")
	dungeon = _read("res://data/dungeon.json")
	polish = _read("res://data/polish.json")
	map.merge(dungeon.locations)
	session = {
		"heroes": rules.heroes.duplicate(true),
		"location": "town", "house_id": "", "facing": Vector2i.UP,
		"bridge_reached": false, "returned_to_throne": false,
		"king_spoken": false, "steps": int(rules.n.zero),
		"gold": int(economy.starting_gold), "inventory": economy.starting_inventory.duplicate(true)
	}
	arrange(cell(map.town.spawn), Vector2i.UP)
	session.battle = {"active":false}
	session.encounters_enabled = combat.encounters.enabled
	session.encounter_cooldown = int(rules.n.zero)
	session.quest = {"key_taken":false, "door_open":false, "garland_defeated":false, "sarah_rescued":false, "king_thanked":false}
	session.quest.bridge_built = false
	session.quest.demo_complete = false
	for member in session.heroes:
		member.level = int(combat.initial_level)
		member.experience = int(combat.initial_experience)
		member.base_max_hp = member.max_hp
		member.equipment = {"weapon":"", "armor":""}
		member.row = combat.classes[member.id].row
		member.charges = combat.classes[member.id].charges.duplicate(true)
	save_checkpoint("Начало пути", cell(map.town.spawn), Vector2i.UP, true)
	battle_system = load("res://scripts/battle_system.gd").new()

func _read(path: String) -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	assert(error == OK, "Invalid JSON: " + path + " — " + parser.get_error_message())
	return parser.data

func cell(values: Array) -> Vector2i:
	return Vector2i(int(values.front()), int(values.back()))

func vec(values: Array) -> Vector3:
	return Vector3(values[int(rules.n.zero)], values[int(rules.n.one)], values[int(rules.n.two)])

func ground(at: Vector2i) -> Vector3:
	return Vector3(at.x * rules.movement.cell_size, rules.n.zero, at.y * rules.movement.cell_size)

func inside(at: Vector2i, rect: Array) -> bool:
	return at.x >= rect.front() and at.x <= rect[int(rules.n.two)] and at.y >= rect[int(rules.n.one)] and at.y <= rect.back()

func leader() -> Vector2i:
	return session.heroes.front().cell

func arrange(at: Vector2i, facing: Vector2i) -> void:
	session.facing = facing
	var next := at
	for hero in session.heroes:
		hero.cell = next
		hero.facing = facing
		next -= facing

func advance(at: Vector2i, facing: Vector2i) -> void:
	var previous := at
	var previous_facing := facing
	for hero in session.heroes:
		var old: Vector2i = hero.cell
		var old_facing: Vector2i = hero.facing
		hero.cell = previous
		hero.facing = previous_facing
		previous = old
		previous_facing = old_facing
	session.facing = facing
	session.steps += int(rules.n.one)

func objective() -> String:
	if session.quest.demo_complete:
		return "Демо завершено · Новый мост построен"
	if session.quest.king_thanked:
		return "Сара спасена · Король благодарит воинов Света"
	if session.quest.sarah_rescued:
		return "Принцесса спасена · Вернитесь к королю"
	if session.location.begins_with("chaos_"):
		if session.quest.garland_defeated:
			return "Гарланд повержен · Освободите Сару"
		if session.location == "chaos_2":
			return "Победите Гарланда · Спасите Сару"
		return "Найдите лестницу на II этаж" if session.quest.door_open else ("Откройте северную дверь ключом" if session.quest.key_taken else "Ключ в западном зале · Найдите сундук")
	if session.king_spoken or session.quest.key_taken:
		return "Святилище Хаоса · За северным мостом"
	if session.returned_to_throne:
		return "Путь пройден · Вы снова в тронном зале"
	if session.bridge_reached:
		return "Вернитесь в замок · Войдите в тронный зал"
	return "За северные ворота · К дальнему концу моста"

func open_chaos_chest() -> Dictionary:
	var chest: Dictionary = dungeon.chest
	if not _near_chaos_object(chest):
		return _result(false, "Сундук слишком далеко.")
	if session.quest.key_taken:
		return _result(false, chest.empty)
	session.quest.key_taken = true
	session.inventory[chest.item] = owned(chest.item) + int(rules.n.one)
	return _result(true, chest.text)

func unlock_chaos_door() -> Dictionary:
	var door: Dictionary = dungeon.door
	if not _near_chaos_object(door):
		return _result(false, "Дверь слишком далеко.")
	if session.quest.door_open:
		return _result(true, door.opened)
	if owned(door.item) <= rules.n.zero:
		return _result(false, door.locked)
	session.quest.door_open = true
	return _result(true, door.opened)

func _near_chaos_object(spec: Dictionary) -> bool:
	var offset := cell(spec.cell) - leader()
	return session.location == "chaos_1" and not in_battle() and absi(offset.x) + absi(offset.y) <= rules.movement.interact_distance

func npc_dialog(npc: Dictionary) -> Dictionary:
	var result: Dictionary = npc.duplicate()
	if npc.id == "king" and session.quest.sarah_rescued:
		result.text = dungeon.story.king_text
	elif npc.id == "sarah" and session.quest.sarah_rescued:
		result.text = dungeon.sarah.rescued_text
	return result

func service_for_house(house_id: String) -> Dictionary:
	for house in map.town.houses:
		if house.id == house_id:
			return economy.services.get(house.get("service", ""), {})
	return {}

func current_service() -> Dictionary:
	if session.location != "house" or in_battle():
		return {}
	return service_for_house(session.house_id)

func owned(item_id: String) -> int:
	return int(session.inventory.get(item_id, rules.n.zero))

func inventory_summary() -> String:
	var entries: PackedStringArray = []
	for item_id in economy.items:
		if owned(item_id) > rules.n.zero:
			entries.append(economy.items[item_id].name + " ×" + str(owned(item_id)))
	return " · ".join(entries) if not entries.is_empty() else "Сумка пуста"

func hero_status(hero: Dictionary) -> String:
	return "Потерян" if hero.hp <= rules.n.zero else str(int(hero.hp)) + " / " + str(int(hero.max_hp)) + " HP"

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok, "message":message}

func _afford(price: int) -> Dictionary:
	if price < rules.n.zero:
		return _result(false, "Некорректная цена услуги.")
	if session.gold < price:
		return _result(false, "Недостаточно золота: нужно " + str(price) + " G, у партии " + str(session.gold) + " G.")
	return _result(true, "")

func _shop_has(item_id: String) -> bool:
	var service := current_service()
	return service.get("kind", "") == "shop" and economy.items.has(item_id) and service.stock.has(item_id)

func buy_item(item_id: String) -> Dictionary:
	if not _shop_has(item_id):
		return _result(false, "Этот товар здесь не продаётся.")
	var item: Dictionary = economy.items[item_id]
	var price := int(item.buy)
	var payment := _afford(price)
	if not payment.ok:
		return payment
	session.gold -= price
	session.inventory[item_id] = owned(item_id) + int(rules.n.one)
	return _result(true, "Куплено: " + item.name + ". Потрачено " + str(price) + " G.")

func sell_item(item_id: String) -> Dictionary:
	if not _shop_has(item_id):
		return _result(false, "Эта лавка не принимает такой товар.")
	if owned(item_id) <= rules.n.zero:
		return _result(false, "Такого предмета нет в сумке.")
	var item: Dictionary = economy.items[item_id]
	var price := int(item.sell)
	if price < rules.n.zero:
		return _result(false, "Некорректная цена товара.")
	var remaining := owned(item_id) - int(rules.n.one)
	if remaining == int(rules.n.zero):
		session.inventory.erase(item_id)
	else:
		session.inventory[item_id] = remaining
	session.gold += price
	return _result(true, "Продано: " + item.name + ". Получено " + str(price) + " G.")

func rest_at_inn() -> Dictionary:
	var service := current_service()
	if service.get("kind", "") != "inn":
		return _result(false, "Ночлег доступен в постоялом дворе.")
	var price := int(service.fee)
	var payment := _afford(price)
	if not payment.ok:
		return payment
	session.gold -= price
	for hero in session.heroes:
		hero.hp = int(hero.max_hp)
		hero.charges = combat.classes[hero.id].charges.duplicate(true)
	for house in map.town.houses:
		if house.id == session.house_id:
			var facing := Vector2i.LEFT if house.return_facing == "west" else Vector2i.RIGHT
			save_checkpoint(house.title, cell(house.door) + Vector2i.DOWN, facing)
	return _result(true, "Утро в Корнелии. Все четверо в строю, здоровье полностью восстановлено. Оплачено " + str(price) + " G.")

func revive_hero(hero_id: String) -> Dictionary:
	var service := current_service()
	if service.get("kind", "") != "clinic":
		return _result(false, "Возвращение героя доступно в клинике.")
	for hero in session.heroes:
		if hero.id != hero_id:
			continue
		if hero.hp > rules.n.zero:
			return _result(false, "Этот герой уже в строю. Плата не взимается.")
		var price := int(service.fee)
		var payment := _afford(price)
		if not payment.ok:
			return payment
		session.gold -= price
		hero.hp = int(hero.max_hp)
		return _result(true, hero.name + " снова в строю. Оплачено " + str(price) + " G.")
	return _result(false, "Выберите потерянного героя. Плата не взимается.")

func in_battle() -> bool:
	return session.get("battle", {}).get("active", false)

func hero(id: String) -> Dictionary:
	for member in session.heroes:
		if member.id == id:
			return member
	return {}

func calculate(name: String, context: Dictionary) -> float:
	var spec: Dictionary = combat.formulas[name]
	if not formula_cache.has(name):
		var expression := Expression.new()
		assert(expression.parse(spec.expression, PackedStringArray(spec.inputs)) == OK, expression.get_error_text())
		formula_cache[name] = expression
	var parameters: Dictionary = spec.constants.duplicate()
	parameters.merge(context, true)
	var values: Array = []
	for input_name in spec.inputs:
		assert(parameters.has(input_name), "Missing formula input: " + input_name)
		values.append(parameters[input_name])
	var expression: Expression = formula_cache[name]
	var result = expression.execute(values, null, true, true)
	assert(not expression.has_execute_failed(), expression.get_error_text())
	return float(result)

func stats(id: String, equipment_override: Dictionary = {}) -> Dictionary:
	var member := hero(id)
	if member.is_empty():
		return {}
	var definition: Dictionary = combat.classes[id]
	var equipment: Dictionary = member.equipment if equipment_override.is_empty() else equipment_override
	var result: Dictionary = {}
	for stat in combat.stat_names:
		var gear: float = rules.n.zero
		for item_id in equipment.values():
			if not item_id.is_empty():
				gear += economy.items[item_id].equipment.stats.get(stat, rules.n.zero)
		result[stat] = int(calculate("stat", {"base":definition.base[stat], "growth":definition.growth[stat], "level":member.level, "initial_level":combat.initial_level, "gear":gear}))
	return result

func equip(id: String, item_id: String, slot: String = "") -> Dictionary:
	if in_battle():
		return _result(false, "Снаряжение и ряды меняются вне боя.")
	var member := hero(id)
	if member.is_empty():
		return _result(false, "Герой не найден.")
	if not item_id.is_empty():
		if not economy.items.has(item_id) or not economy.items[item_id].has("equipment"):
			return _result(false, "Это не снаряжение.")
		var gear: Dictionary = economy.items[item_id].equipment
		if not gear.classes.has(id) or owned(item_id) <= rules.n.zero:
			return _result(false, "Предмет недоступен этому герою или отсутствует в сумке.")
		slot = gear.slot
	if not member.equipment.has(slot):
		return _result(false, "Неизвестный слот снаряжения.")
	var previous: String = member.equipment[slot]
	if item_id.is_empty() and previous.is_empty():
		return _result(false, "Этот слот уже пуст.")
	if not item_id.is_empty():
		var count := owned(item_id) - int(rules.n.one)
		if count == int(rules.n.zero):
			session.inventory.erase(item_id)
		else:
			session.inventory[item_id] = count
	if not previous.is_empty():
		session.inventory[previous] = owned(previous) + int(rules.n.one)
	member.equipment[slot] = item_id
	return _result(true, member.name + ": " + ("снаряжение снято" if item_id.is_empty() else "надето «" + economy.items[item_id].name + "»") + ". Характеристики обновлены.")

func toggle_row(id: String) -> Dictionary:
	if in_battle() or hero(id).is_empty():
		return _result(false, "Ряд меняется перед боем.")
	var member := hero(id)
	member.row = "back" if member.row == "front" else "front"
	return _result(true, member.name + ": " + combat.rows[member.row].name + " ряд.")

func equipment_score(id: String, item_id: String) -> float:
	var score: float = rules.n.zero
	if item_id.is_empty():
		return score
	var modifiers: Dictionary = economy.items[item_id].equipment.stats
	for stat in modifiers:
		score += modifiers[stat] * polish.gear.best_weights[id].get(stat, rules.n.zero)
	return score

func equip_best(id: String) -> Dictionary:
	if in_battle() or hero(id).is_empty():
		return _result(false, "Подбор снаряжения доступен вне боя.")
	var changed := false
	for slot in hero(id).equipment:
		var best: String = hero(id).equipment[slot]
		for item_id in economy.items:
			var item: Dictionary = economy.items[item_id]
			if not item.has("equipment") or owned(item_id) <= rules.n.zero:
				continue
			if item.equipment.slot == slot and item.equipment.classes.has(id) and equipment_score(id, item_id) > equipment_score(id, best):
				best = item_id
		if best != hero(id).equipment[slot]:
			changed = equip(id, best).ok or changed
	return _result(true, "Подобрано лучшее доступное снаряжение из сумки." if changed else "У героя уже лучшее доступное снаряжение.")

func grant_experience(amount: int) -> void:
	for member in session.heroes:
		if member.hp <= rules.n.zero:
			continue
		member.experience += amount
		var old_max := int(member.max_hp)
		while member.level < combat.levels.size() and member.experience >= combat.levels[int(member.level)]:
			member.level += int(rules.n.one)
		member.max_hp = int(calculate("max_hp", {"base_hp":member.base_max_hp, "growth":combat.classes[member.id].hp_growth, "level":member.level, "initial_level":combat.initial_level}))
		member.hp = mini(int(member.max_hp), int(member.hp) + int(member.max_hp) - old_max)

func save_checkpoint(title: String, at: Vector2i, facing: Vector2i, heal_copy: bool = false) -> void:
	var snapshot: Dictionary = {"title":title, "spawn":at, "facing":facing}
	for key in ["heroes", "gold", "inventory", "quest", "bridge_reached", "returned_to_throne", "king_spoken"]:
		var value = session[key]
		snapshot[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	if heal_copy:
		for member in snapshot.heroes:
			member.hp = member.max_hp
	session.checkpoint = snapshot

func restore_checkpoint() -> Dictionary:
	var snapshot: Dictionary = session.checkpoint
	for member in session.heroes:
		for saved in snapshot.heroes:
			if saved.id == member.id:
				member.clear()
				member.merge(saved.duplicate(true))
				break
	session.inventory.clear()
	session.inventory.merge(snapshot.inventory.duplicate(true))
	session.quest.clear()
	session.quest.merge(snapshot.quest.duplicate(true))
	for key in ["gold", "bridge_reached", "returned_to_throne", "king_spoken"]:
		session[key] = snapshot[key]
	session.battle.active = false
	session.encounter_cooldown = int(combat.encounters.grace_steps)
	return snapshot
