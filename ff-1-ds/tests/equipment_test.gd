extends Node
## Equipment acceptance test: items move from the bag to a slot, change derived
## stats, return to the bag and the front/back row can be changed.

var main: GameMain
var passes := 0
var failures: Array[String] = []


func _ready() -> void:
	Engine.time_scale = 3.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if not await _wait_until(func() -> bool: return main.gameplay_ready, 20.0):
		_fail("game did not load")
		_finish()
		return
	await get_tree().process_frame
	GameState.encounters_enabled = false
	GameState.inventory.clear()
	GameState.inventory["bronze_sword"] = 1
	GameState.inventory["iron_dagger"] = 1
	GameState.inventory["leather_armor"] = 1
	GameState.party_status_changed.emit()

	var base := GameState.get_effective_stats("brandt")
	_expect(int(base.get("attack", 0)) == 16, "base attack comes from JSON")
	_expect(int(base.get("defense", 0)) == 12, "base defense comes from JSON")
	_expect(GameState.get_member_row("brandt") == "front", "starting row comes from JSON")

	await _tap_action("equipment")
	await get_tree().process_frame
	_expect(main.hud.is_equipment_open(), "equipment panel opens with the I key")
	_expect(str(GameState.party[0]["id"]) == main.hud.get_equipment_selected_member_id(), "first hero is selected")
	_expect(main.hud.get_equipment_slot_index() == 0, "weapon slot is selected")

	var enter_result: Dictionary = main.test_equipment_confirm()
	_expect(bool(enter_result.get("ok", false)), "weapon slot enters item selection")
	_expect(main.hud.is_equipment_picking(), "item selection is active")
	var weapon_ids := main.hud.get_equipment_item_ids()
	_expect(weapon_ids.has("bronze_sword"), "owned bronze sword is listed")
	_expect(weapon_ids.has("iron_dagger"), "owned iron dagger is listed")
	_expect(main.hud.get_equipment_item_index() == 0 and not weapon_ids[0].is_empty(), "item picker defaults to a real item, not unequip")
	_expect(main.hud.get_equipment_detail_text().contains("изменение"), "item picker previews the stat change")
	_select_equipment_item("bronze_sword")
	var equip_result: Dictionary = main.test_equipment_confirm()
	_expect(bool(equip_result.get("ok", false)), "bronze sword equips")
	_expect(GameState.get_equipped_item_id("brandt", "weapon") == "bronze_sword", "weapon slot stores the item")
	_expect(GameState.item_count("bronze_sword") == 0, "equipped weapon leaves the bag")
	var after_sword := GameState.get_effective_stats("brandt")
	_expect(int(after_sword.get("attack", 0)) == 26, "weapon attack bonus changes derived attack")
	_expect(int(after_sword.get("agility", 0)) == 7, "weapon agility penalty changes derived agility")

	# Swap the weapon: the old one must go back into the bag.
	main.test_equipment_confirm()
	await get_tree().process_frame
	_select_equipment_item("iron_dagger")
	main.test_equipment_confirm()
	await get_tree().process_frame
	_expect(GameState.get_equipped_item_id("brandt", "weapon") == "iron_dagger", "weapon can be swapped")
	_expect(GameState.item_count("bronze_sword") == 1, "previous weapon returns to the bag")
	var after_dagger := GameState.get_effective_stats("brandt")
	_expect(int(after_dagger.get("attack", 0)) == 22, "swapped weapon stats replace the old bonus")
	_expect(int(after_dagger.get("agility", 0)) == 12, "swapped weapon agility applies")

	# Armor slot.
	main.test_equipment_move_horizontal(1)
	_expect(main.hud.get_equipment_slot_index() == 1, "armor slot can be selected")
	main.test_equipment_confirm()
	await get_tree().process_frame
	_expect(main.hud.get_equipment_item_ids().has("leather_armor"), "owned armor is listed")
	_select_equipment_item("leather_armor")
	main.test_equipment_confirm()
	await get_tree().process_frame
	_expect(GameState.get_equipped_item_id("brandt", "armor") == "leather_armor", "armor equips")
	var after_armor := GameState.get_effective_stats("brandt")
	_expect(int(after_armor.get("defense", 0)) == 19, "armor defense bonus applies")
	_expect(int(after_armor.get("agility", 0)) == 13, "armor agility bonus applies")

	# Row toggle.
	main.test_equipment_move_horizontal(1)
	_expect(main.hud.get_equipment_slot_index() == 2, "row field can be selected")
	main.test_equipment_confirm()
	await get_tree().process_frame
	_expect(GameState.get_member_row("brandt") == "back", "row toggles to back")
	main.test_equipment_confirm()
	await get_tree().process_frame
	_expect(GameState.get_member_row("brandt") == "front", "row toggles back to front")

	# Unequip the weapon.
	main.test_equipment_move_horizontal(-2)
	_expect(main.hud.get_equipment_slot_index() == 0, "weapon slot reselected")
	main.test_equipment_confirm()
	await get_tree().process_frame
	_expect(main.hud.get_equipment_item_ids().has(""), "unequip entry is offered when a weapon is worn")
	_select_equipment_item("")
	_expect(main.hud.get_equipment_detail_text().contains("Снять"), "unequip preview explains what is removed")
	var unequip_result: Dictionary = main.test_equipment_confirm()
	_expect(bool(unequip_result.get("ok", false)), "weapon can be unequipped")
	_expect(GameState.get_equipped_item_id("brandt", "weapon").is_empty(), "weapon slot is empty")
	_expect(GameState.item_count("iron_dagger") == 1, "unequipped weapon returns to the bag")
	var final_stats := GameState.get_effective_stats("brandt")
	_expect(int(final_stats.get("attack", 0)) == 16, "unequipping restores base attack")
	_expect(int(final_stats.get("defense", 0)) == 19, "armor still contributes defense")

	await _tap_action("equipment")
	await get_tree().process_frame
	_expect(not main.hud.is_equipment_open(), "equipment panel closes with the I key")
	_expect(main.party.controls_enabled, "movement is enabled after closing equipment")
	_finish()


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


func _select_equipment_item(item_id: String) -> void:
	var ids := main.hud.get_equipment_item_ids()
	var index := ids.find(item_id)
	if index < 0:
		_fail("equipment item not found: %s" % item_id)
		return
	var delta := index - main.hud.get_equipment_item_index()
	main.test_equipment_move_vertical(delta)


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
		print("[EQUIP] PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	print("[EQUIP] FAIL: %s" % message)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[EQUIP] %d checks passed, %d failed" % [passes, failures.size()])
	if failures.is_empty():
		print("[EQUIP] RESULT: PASS — equipment changes derived stats and returns to the bag")
		get_tree().quit(0)
	else:
		print("[EQUIP] RESULT: FAIL")
		for failure: String in failures:
			print("  - %s" % failure)
		get_tree().quit(1)
