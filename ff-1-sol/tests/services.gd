extends RefCounted
## End-to-end service flow through actual doors and the production UI buttons.
var flow
var game
var panel
var config: Dictionary
var inventory_reference: Dictionary

func run(driver: Node) -> void:
	flow = driver
	game = flow.game
	panel = game.hud.service
	config = GameState.rules.test.services
	inventory_reference = GameState.session.inventory
	var initial_gold: int = GameState.session.gold
	_check(initial_gold == int(GameState.economy.starting_gold), "Starting gold comes from JSON")
	_check(GameState.owned(config.potion) == int(GameState.rules.n.zero), "Potion starts absent")
	var potion: Dictionary = GameState.economy.items[config.potion]
	var inn_fee := int(GameState.economy.services.inn.fee)
	var clinic_fee := int(GameState.economy.services.clinic.fee)

	await _enter(config.item_house)
	_check(panel.rows[config.potion].text.contains(str(int(potion.buy)) + " G"), "Shop list displays JSON purchase price")
	_check(not await game.request_step(Vector2i.RIGHT), "Service menu blocks world movement")
	panel.rows[config.potion].pressed.emit()
	panel.action_button.pressed.emit()
	_check(panel.result_ok and GameState.owned(config.potion) == int(GameState.rules.n.one), "Purchase button adds one potion")
	_check(GameState.session.gold == initial_gold - int(potion.buy), "Potion purchase spends the exact price")
	await flow._capture("shop_purchase")
	var after_purchase := _snapshot()
	await _leave()
	_check(_snapshot() == after_purchase, "Purchase values survive shop exit")

	await _enter(config.inn_house)
	_check(panel.entries.size() == int(GameState.rules.test.party_count), "Inn shows all four heroes")
	panel.action_button.pressed.emit()
	_check(panel.result_ok, "Inn accepts paid rest")
	_check(GameState.session.gold == initial_gold - int(potion.buy) - inn_fee, "Inn charges exactly the JSON fee")
	_check(_all_healed(), "Paid night fully heals all four heroes, including the lost hero")
	await flow._capture("inn_rest")
	var after_rest := _snapshot()
	await _leave()
	await flow._walk_to(GameState.cell(GameState.rules.test.square_view))
	_check(_snapshot() == after_rest, "Same gold, potion and HP remain on the square")
	_check(is_same(inventory_reference, GameState.session.inventory), "Inventory dictionary identity survives house changes")
	var lines: Array[String] = game.hud.economy_lines()
	_check(lines.front().contains(str(GameState.session.gold)) and lines.back().contains(potion.name + " ×" + str(int(GameState.rules.n.one))), "Square HUD displays remaining gold and potion count")
	_check(flow._same_party(), "Service route preserves the original four hero nodes")
	await flow._capture("services_square")
	print("SERVICES ROUTE: " + str(GameState.session.gold) + " G; " + GameState.inventory_summary() + "; all four heroes fully healed on square")

	# There are no battles in this slice. Seed two lost heroes for clinic cases.
	for hero in GameState.session.heroes:
		if config.lost_heroes.has(hero.id):
			hero.hp = int(GameState.rules.n.zero)
	await _enter(config.clinic_house)
	var first: String = config.lost_heroes.front()
	var second: String = config.lost_heroes.back()
	var gold_before: int = GameState.session.gold
	panel.rows[first].pressed.emit()
	panel.action_button.pressed.emit()
	_check(panel.result_ok and GameState.session.gold == gold_before - clinic_fee, "Clinic charges for exactly one chosen hero")
	_check(_hero(first).hp == _hero(first).max_hp and _hero(second).hp == GameState.rules.n.zero, "Clinic heals the selected lost hero and leaves the other lost")
	_check(not panel.entries.has(first) and panel.entries.has(second), "Clinic list removes healed heroes")
	var unchanged := _snapshot()
	_check(not GameState.revive_hero(first).ok and _snapshot() == unchanged, "Clinic rejects an already restored hero without charge")
	_check(not GameState.revive_hero("unknown_hero").ok and _snapshot() == unchanged, "Clinic rejects an invalid target without charge")
	await _leave()

	await _enter(config.weapon_house)
	panel.rows[config.weapon].pressed.emit()
	panel.action_button.pressed.emit()
	_check(panel.result_ok and GameState.owned(config.weapon) == int(GameState.rules.n.one), "Weapon shop purchase works")
	unchanged = _snapshot()
	_check(not GameState.buy_item(config.armor).ok and _snapshot() == unchanged, "Shop rejects an item from a different catalogue")
	_check(not GameState.sell_item(config.potion).ok and _snapshot() == unchanged, "Weapon shop refuses to buy a potion")
	await _leave()
	await _enter(config.armor_house)
	panel.rows[config.armor].pressed.emit()
	panel.action_button.pressed.emit()
	_check(panel.result_ok and GameState.owned(config.armor) == int(GameState.rules.n.one), "Armor shop purchase works")
	await _leave()

	await _enter(config.clinic_house)
	unchanged = _snapshot()
	panel.rows[second].pressed.emit()
	panel.action_button.pressed.emit()
	_check(not panel.result_ok and panel.message.contains("Недостаточно золота"), "Clinic visibly refuses insufficient gold")
	_check(_snapshot() == unchanged, "Clinic refusal preserves gold, all HP and inventory")
	await flow._capture("clinic_refusal")
	await _leave()
	await _enter(config.inn_house)
	panel.action_button.pressed.emit()
	_check(not panel.result_ok and panel.message.contains("Недостаточно золота") and _snapshot() == unchanged, "Unpaid night neither charges nor heals anyone")
	await _leave()

	await _enter(config.item_house)
	panel.rows[config.potion].pressed.emit()
	panel.action_button.pressed.emit()
	_check(not panel.result_ok and _snapshot() == unchanged, "Unaffordable purchase changes nothing")
	panel.sell_tab.pressed.emit()
	_check(panel.rows[config.potion].text.contains(str(int(potion.sell)) + " G"), "Sell list displays JSON resale price")
	gold_before = GameState.session.gold
	panel.action_button.pressed.emit()
	_check(panel.result_ok and GameState.owned(config.potion) == int(GameState.rules.n.zero), "Selling the last potion removes it from the bag")
	_check(GameState.session.gold == gold_before + int(potion.sell), "Item sale credits the exact resale price")
	_check(panel.entries.is_empty(), "Sell list updates after the last item")
	unchanged = _snapshot()
	panel.action_button.pressed.emit()
	_check(not panel.result_ok and _snapshot() == unchanged, "Empty sell list cannot generate gold")
	await _leave()

	await _enter(config.weapon_house)
	panel.sell_tab.pressed.emit()
	gold_before = GameState.session.gold
	panel.action_button.pressed.emit()
	_check(panel.result_ok and GameState.session.gold == gold_before + int(GameState.economy.items[config.weapon].sell), "Weapon sale credits the configured price")
	panel.buy_tab.pressed.emit()
	panel.rows[config.boundary_weapon].pressed.emit()
	panel.action_button.pressed.emit()
	_check(panel.result_ok, "Second weapon purchase works after switching tabs")
	await _leave()
	await _enter(config.clinic_house)
	_check(GameState.session.gold == clinic_fee, "Clinic exact-payment boundary is reached by real transactions")
	panel.action_button.pressed.emit()
	_check(panel.result_ok and GameState.session.gold == GameState.rules.n.zero and _all_healed(), "Clinic accepts exact payment, with no negative balance")
	_check(panel.entries.is_empty(), "Clinic shows no targets after all heroes are restored")
	unchanged = _snapshot()
	panel.action_button.pressed.emit()
	_check(not panel.result_ok and _snapshot() == unchanged, "Clinic without a lost hero does not charge")
	await _leave()
	await _enter(config.armor_house)
	panel.sell_tab.pressed.emit()
	gold_before = GameState.session.gold
	panel.action_button.pressed.emit()
	_check(panel.result_ok and GameState.session.gold == gold_before + int(GameState.economy.items[config.armor].sell), "Armor sale credits the configured price")
	await _leave()
	await _enter(config.weapon_house)
	panel.sell_tab.pressed.emit()
	panel.action_button.pressed.emit()
	await _leave()
	await flow._walk_to(GameState.cell(GameState.rules.test.square_view))
	unchanged = _snapshot()
	_check(not GameState.buy_item(config.potion).ok and not GameState.rest_at_inn().ok and _snapshot() == unchanged, "Transactions cannot run on the town square")
	var event := InputEventAction.new()
	event.action = "inventory"
	event.pressed = true
	game._unhandled_input(event)
	_check(panel.visible and panel.mode == "inventory", "Inventory key opens the shared bag on the square")
	_check(not await game.request_step(Vector2i.RIGHT), "Inventory blocks walking while open")
	game._unhandled_input(event)
	_check(not panel.visible, "Inventory key closes the bag")
	_check(is_same(inventory_reference, GameState.session.inventory) and flow._same_party(), "All purchases, sales, healing and refusals keep the same party state objects")

func _enter(house_id: String) -> void:
	for house in GameState.map.town.houses:
		if house.id == house_id:
			await flow._walk_to(GameState.cell(house.door))
			break
	_check(GameState.session.location == "house" and GameState.session.house_id == house_id, "Enter service building: " + house_id)
	game.interact()
	_check(panel.visible, "E opens services in " + house_id)

func _leave() -> void:
	panel.close()
	await flow._walk_to(GameState.cell(GameState.map.house.portals.front().cell))
	_check(GameState.session.location == "town", "Leave service building without resetting session")

func _check(condition: bool, label: String) -> void:
	flow._check(condition, label)

func _hero(id: String) -> Dictionary:
	for hero in GameState.session.heroes:
		if hero.id == id:
			return hero
	return {}

func _all_healed() -> bool:
	for hero in GameState.session.heroes:
		if hero.hp != hero.max_hp:
			return false
	return true

func _snapshot() -> Dictionary:
	var health: Array = []
	for hero in GameState.session.heroes:
		health.append(hero.hp)
	return {"gold":GameState.session.gold, "inventory":GameState.session.inventory.duplicate(true), "health":health}
