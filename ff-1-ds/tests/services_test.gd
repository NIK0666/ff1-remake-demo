extends Node
## End-to-end service test:
##   item shop -> buy potion -> inn -> rest -> back to the plaza,
## plus lists/prices/buy/sell for every shop and the clinic refusal path.

var main: GameMain
var failures: Array[String] = []
var passes: int = 0
var start_gold: int = 0


func _ready() -> void:
	Engine.time_scale = 3.0
	print("[SERVICES] start")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if not await _wait_until(func() -> bool: return main.gameplay_ready, 20.0):
		_fail("game did not load")
		_finish()
		return
	await get_tree().process_frame
	start_gold = int(GameState.game["party"]["starting_gold"])
	_expect(GameState.gold == start_gold, "starting gold comes from JSON")
	_expect(GameState.inventory.is_empty(), "starting inventory comes from JSON (empty)")
	for member: Dictionary in GameState.party:
		_expect(int(member.get("hp", -1)) == int(member.get("max_hp", -2)), "hero starts at full HP")
	_expect(main.hud.get_wallet_gold_text().contains(str(start_gold)), "wallet shows starting gold")
	_expect(main.hud.get_wallet_inventory_text().contains(GameState.service_ui("bag_empty", "Сумка пуста")), "wallet shows an empty bag")

	var potion := GameState.get_item("potion")
	var potion_price := int(potion.get("buy_price", 0))
	var inn_service := GameState.get_service("inn")
	var inn_price := int(inn_service.get("price", 0))

	# --- Required route: buy a potion, spend gold, rest, come back to town ---
	var gold_before_shop := GameState.gold
	var inventory_before_shop := GameState.inventory.duplicate(true)
	if not await _enter_house("herbalist"):
		_finish()
		return
	_expect(GameState.gold == gold_before_shop, "entering the shop house does not reset gold")
	_expect(GameState.inventory == inventory_before_shop, "entering the shop house does not reset inventory")
	if not await _open_service_in_current_house("item_shop"):
		_finish()
		return
	_expect(main.hud.is_service_open(), "item shop UI opens")
	var shop_entries := main.hud.get_service_visible_entries()
	_expect(not shop_entries.is_empty(), "item shop shows a stock list")
	_expect(_entry_price(shop_entries, "potion") == potion_price, "item shop shows the potion price from JSON")
	var index_before_arrows := main.hud.get_service_index()
	await _tap_action("move_down")
	_expect(main.hud.get_service_index() != index_before_arrows, "arrow key navigates the shop list")
	await _tap_action("move_up")
	_expect(main.hud.get_service_index() == index_before_arrows, "arrow key returns to the first shop row")
	var potion_index := _entry_index(shop_entries, "potion")
	_expect(potion_index >= 0, "potion is listed in the item shop")
	if potion_index >= 0:
		_select_entry(potion_index)
		var buy_result: Dictionary = main.test_service_confirm()
		_expect(bool(buy_result.get("ok", false)), "buying a potion succeeds")
		_expect(GameState.item_count("potion") == 1, "potion appears in the party inventory")
		_expect(GameState.gold == gold_before_shop - potion_price, "potion purchase spends exactly its JSON price")
		_expect(main.hud.get_wallet_gold_text().contains(str(GameState.gold)), "wallet updates after buying")
		_expect(main.hud.get_wallet_inventory_text().contains("Зелье ×1"), "wallet shows the bought potion")
	main.test_service_close()
	await get_tree().process_frame
	_expect(not main.hud.is_service_open(), "shop UI closes with service close")
	if not await _exit_current_house():
		_finish()
		return
	_expect(GameState.location_id == "town", "party leaves the shop and returns to town")
	_expect(GameState.gold == gold_before_shop - potion_price, "gold survives leaving the shop")
	_expect(GameState.item_count("potion") == 1, "inventory survives leaving the shop")

	if not await _enter_house("baker"):
		_finish()
		return
	_expect(GameState.gold == gold_before_shop - potion_price, "gold survives entering the inn")
	_expect(GameState.item_count("potion") == 1, "inventory survives entering the inn")
	var max_brandt := int(GameState.member_by_id("brandt").get("max_hp", 1))
	var max_shade := int(GameState.member_by_id("shade").get("max_hp", 1))
	var max_kai := int(GameState.member_by_id("kai").get("max_hp", 1))
	var max_lira := int(GameState.member_by_id("lira").get("max_hp", 1))
	GameState.set_member_hp("brandt", 3)
	GameState.set_member_hp("shade", 0)
	GameState.set_member_hp("kai", 5)
	GameState.set_member_hp("lira", max_lira - 1)
	if not await _open_service_in_current_house("inn"):
		_finish()
		return
	_expect(main.hud.is_service_open(), "inn UI opens")
	var gold_before_inn := GameState.gold
	var inn_result: Dictionary = main.test_service_confirm()
	_expect(bool(inn_result.get("ok", false)), "paying for the inn succeeds")
	_expect(GameState.gold == gold_before_inn - inn_price, "inn night costs exactly its JSON price")
	_expect(GameState.member_by_id("brandt")["hp"] == max_brandt, "inn heals the warrior")
	_expect(GameState.member_by_id("shade")["hp"] == max_shade, "inn heals the thief who was lost")
	_expect(GameState.member_by_id("kai")["hp"] == max_kai, "inn heals the monk")
	_expect(GameState.member_by_id("lira")["hp"] == max_lira, "inn heals the white mage")
	_expect(GameState.get_lost_members().is_empty(), "inn leaves no lost heroes")
	main.test_service_close()
	await get_tree().process_frame
	if not await _exit_current_house():
		_finish()
		return
	if not await _walk_to_cell(Vector2i(0, 3)):
		_fail("could not walk back to the plaza")
		_finish()
		return
	await get_tree().process_frame
	var expected_gold := start_gold - potion_price - inn_price
	_expect(GameState.location_id == "town", "party is back in town on the plaza")
	_expect(GameState.leader_cell == Vector2i(0, 3), "party stands on the plaza")
	_expect(GameState.gold == expected_gold, "gold after shop + inn matches the expected total")
	_expect(GameState.item_count("potion") == 1, "potion is still in the inventory on the plaza")
	_expect(main.hud.get_wallet_gold_text().contains(str(expected_gold)), "wallet on the plaza shows the same gold")
	_expect(main.hud.get_wallet_inventory_text().contains("Зелье ×1"), "wallet on the plaza shows the same potion count")
	print("[SERVICES] acceptance numbers: gold=%d, potion=%d" % [GameState.gold, GameState.item_count("potion")])

	# --- Every shop: list, prices, buy, sell -------------------------------
	for shop_house in ["smith", "weaver", "herbalist"]:
		var shop_service_id := GameState.get_service_id_for_house(shop_house)
		var shop_service := GameState.get_service(shop_service_id)
		if shop_service.is_empty():
			_fail("%s has no service" % shop_house)
			continue
		if not await _enter_house(shop_house):
			continue
		if not await _open_service_in_current_house(shop_service_id):
			continue
		var entries := main.hud.get_service_visible_entries()
		_expect(entries.size() > 0, "%s shop has a non-empty list" % shop_house)
		for entry: Dictionary in entries:
			var expected_price := int(GameState.get_item(str(entry["id"])).get("buy_price", -1))
			if int(entry.get("price", -2)) != expected_price:
				_fail("%s lists a wrong buy price for %s" % [shop_house, str(entry["id"])])
				break
		if entries.is_empty():
			main.test_service_close()
			continue
		var buy_entry: Dictionary = entries[0]
		var buy_item_id := str(buy_entry["id"])
		var buy_price := int(buy_entry["price"])
		var sell_price := int(GameState.get_item(buy_item_id).get("sell_price", 0))
		var prior_gold := GameState.gold
		var prior_count := GameState.item_count(buy_item_id)
		var buy_result: Dictionary = main.test_service_confirm()
		_expect(bool(buy_result.get("ok", false)), "%s: buying %s succeeds" % [shop_house, buy_item_id])
		_expect(GameState.gold == prior_gold - buy_price, "%s: buy spends the listed price" % shop_house)
		_expect(GameState.item_count(buy_item_id) == prior_count + 1, "%s: bought item enters inventory" % shop_house)
		main.test_service_toggle_mode()
		_expect(main.hud.get_service_mode() == "sell", "%s: sell mode is available" % shop_house)
		var sell_entries := main.hud.get_service_visible_entries()
		var sell_index := _entry_index(sell_entries, buy_item_id)
		_expect(sell_index >= 0, "%s: bought item appears in the sell list" % shop_house)
		if sell_index >= 0:
			_expect(_entry_price(sell_entries, buy_item_id) == sell_price, "%s: sell price comes from JSON" % shop_house)
			_select_entry(sell_index)
			var sell_result: Dictionary = main.test_service_confirm()
			_expect(bool(sell_result.get("ok", false)), "%s: selling the item succeeds" % shop_house)
			_expect(GameState.gold == prior_gold - buy_price + sell_price, "%s: sale pays the JSON sell price" % shop_house)
			_expect(GameState.item_count(buy_item_id) == prior_count, "%s: sold item leaves inventory" % shop_house)
		main.test_service_close()
		await get_tree().process_frame

	# --- Clinic: lost hero, insufficient gold refusal, then full healing ----
	var clinic_service := GameState.get_service("clinic")
	var clinic_price := int(clinic_service.get("price", 0))
	if not await _enter_house("elder"):
		_finish()
		return
	GameState.set_member_hp("shade", 0)
	GameState.gold = clinic_price - 1
	if not await _open_service_in_current_house("clinic"):
		_finish()
		return
	_expect(main.hud.is_service_open(), "clinic UI opens")
	_expect(GameState.get_lost_members().size() == 1, "clinic has exactly one lost hero to treat")
	var refused: Dictionary = main.test_service_confirm()
	_expect(not bool(refused.get("ok", true)), "clinic refuses treatment without enough gold")
	_expect(str(refused.get("message", "")).contains("Не хватает золота"), "clinic refusal is explicit text")
	_expect(str(main.hud.get_service_message_text()).contains("Не хватает золота"), "clinic refusal is shown in the UI")
	_expect(GameState.gold == clinic_price - 1, "refused treatment does not spend gold")
	_expect(GameState.is_member_lost(GameState.member_by_id("shade")), "refused treatment leaves the hero lost")
	GameState.gold = clinic_price + 10
	var healed: Dictionary = main.test_service_confirm()
	_expect(bool(healed.get("ok", false)), "clinic heals when enough gold is available")
	_expect(GameState.gold == 10, "clinic deducts exactly its price")
	_expect(int(GameState.member_by_id("shade")["hp"]) == max_shade, "clinic restores the lost hero's HP")
	_expect(not GameState.is_member_lost(GameState.member_by_id("shade")), "clinic marks the hero as no longer lost")
	main.test_service_close()
	await get_tree().process_frame

	_finish()


# ---------------------------------------------------------------------------
# Service helpers
# ---------------------------------------------------------------------------

func _enter_house(house_key: String) -> bool:
	var house := GameState.get_house(house_key)
	var spawn_name := str(house["door"]["return_spawn"])
	await main._load_location("town", spawn_name, "", false)
	await get_tree().process_frame
	main.test_refresh_interaction()
	var target := main.current_interactable
	if target == null:
		_fail("%s: no door interaction from its return spawn" % house_key)
		return false
	if str(target.payload.get("house_id", "")) != house_key:
		_fail("%s: nearest interaction is not its door" % house_key)
		return false
	main.test_interact()
	var entered := await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "house", 20.0)
	_expect(entered, "%s: entering the house succeeds" % house_key)
	await get_tree().process_frame
	return entered


func _open_service_in_current_house(expected_service_id: String) -> bool:
	var service_point := _find_service_point()
	if service_point == null:
		_fail("no service point in house")
		return false
	var reach := float(GameState.game["interaction"]["range"])
	if not await _walk_near(service_point.global_position, reach):
		return false
	main.test_refresh_interaction()
	var target := main.current_interactable
	if target == null or target.kind != "service":
		_fail("service point is not interactable from the approached cell")
		return false
	if str(target.payload.get("service_id", "")) != expected_service_id:
		_fail("opened wrong service: %s" % str(target.payload.get("service_id", "")))
		return false
	main.test_interact()
	await get_tree().process_frame
	if not main.hud.is_service_open():
		_fail("%s: service UI did not open" % expected_service_id)
		return false
	return true


func _exit_current_house() -> bool:
	if main.hud.is_service_open():
		main.test_service_close()
		await get_tree().process_frame
	var exit_point: Interactable = null
	for point: Interactable in main.current_location.interactables:
		if point.kind == "door" and str(point.payload.get("target", "")) == "town":
			exit_point = point
			break
	if exit_point == null:
		_fail("house has no exit door")
		return false
	var reach := float(GameState.game["interaction"]["range"])
	if not await _walk_near(exit_point.global_position, reach):
		return false
	main.test_refresh_interaction()
	if main.current_interactable == null:
		_fail("exit prompt is not available")
		return false
	main.test_interact()
	var returned := await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "town", 20.0)
	_expect(returned, "exiting the house returns to town")
	await get_tree().process_frame
	return returned


func _find_service_point() -> Interactable:
	for point: Interactable in main.current_location.interactables:
		if point.kind == "service":
			return point
	return null


func _walk_near(world_point: Vector3, max_distance: float) -> bool:
	var location := main.current_location
	var path_info := _find_path_near(location, GameState.leader_cell, world_point, max_distance)
	if not bool(path_info.get("found", false)):
		_fail("no walkable cell in reach of %s" % str(world_point))
		return false
	var path: Array = path_info.get("path", [])
	for cell: Vector2i in path:
		if not main.test_try_step(cell - GameState.leader_cell):
			_fail("movement blocked before service at %s" % str(cell))
			return false
		await get_tree().process_frame
	await get_tree().process_frame
	return true


func _walk_to_cell(goal: Vector2i) -> bool:
	var path := _find_path(main.current_location, GameState.leader_cell, goal)
	if path.is_empty():
		return false
	for cell: Vector2i in path:
		if not main.test_try_step(cell - GameState.leader_cell):
			return false
		await get_tree().process_frame
	await get_tree().process_frame
	return true


func _find_path(location: LocationBase, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if start == goal:
		return []
	const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var queue: Array[Vector2i] = [start]
	var came: Dictionary = {start: start}
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for d: Vector2i in DIRS:
			var nb := cell + d
			if came.has(nb) or not location.can_party_stand(nb):
				continue
			came[nb] = cell
			if nb == goal:
				return _rebuild_path(start, goal, came)
			queue.append(nb)
	return []


func _find_path_near(location: LocationBase, start: Vector2i, world_point: Vector3, max_distance: float) -> Dictionary:
	var start_world := location.cell_to_world(start)
	if start_world.distance_to(world_point) <= max_distance:
		return {"found": true, "path": []}
	const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var queue: Array[Vector2i] = [start]
	var came: Dictionary = {start: start}
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for d: Vector2i in DIRS:
			var nb := cell + d
			if came.has(nb) or not location.can_party_stand(nb):
				continue
			came[nb] = cell
			var nb_world := location.cell_to_world(nb)
			if nb_world.distance_to(world_point) <= max_distance:
				return {"found": true, "path": _rebuild_path(start, nb, came)}
			queue.append(nb)
	return {"found": false, "path": []}


func _rebuild_path(start: Vector2i, goal: Vector2i, came: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		path.push_front(cursor)
		cursor = came[cursor]
	return path


# ---------------------------------------------------------------------------
# Assertions and service list helpers
# ---------------------------------------------------------------------------

func _entry_index(entries: Array[Dictionary], item_id: String) -> int:
	for i in entries.size():
		if str(entries[i].get("id", "")) == item_id:
			return i
	return -1


func _entry_price(entries: Array[Dictionary], item_id: String) -> int:
	var index := _entry_index(entries, item_id)
	if index < 0:
		return -1
	return int(entries[index].get("price", -1))


func _select_entry(index: int) -> void:
	var current := main.hud.get_service_index()
	main.test_service_move(index - current)


func _tap_action(action_name: String) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not bool(condition.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("[SERVICES] PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	print("[SERVICES] FAIL: %s" % message)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[SERVICES] %d checks passed, %d failed" % [passes, failures.size()])
	if failures.is_empty():
		print("[SERVICES] RESULT: PASS — shops, inn, clinic, persistent gold and inventory")
		get_tree().quit(0)
	else:
		print("[SERVICES] RESULT: FAIL")
		for failure: String in failures:
			print("  - %s" % failure)
		get_tree().quit(1)
