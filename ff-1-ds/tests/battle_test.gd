extends Node
## End-to-end combat test: turn order, rows, equipment stats, attack/magic/item,
## white and black charges, victory rewards, flee, defeat checkpoint and bridge trigger.

var main: GameMain
var passes: int = 0
var failures: Array[String] = []


func _ready() -> void:
	Engine.time_scale = 6.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if not await _wait_until(func() -> bool: return main.gameplay_ready, 25.0):
		_fail("game did not load")
		_finish()
		return
	GameState.encounters_enabled = false
	GameState.inventory["potion"] = 2
	GameState.inventory["bronze_sword"] = 1
	var equip: Dictionary = GameState.equip_item("brandt", "weapon", "bronze_sword")
	_expect(bool(equip.get("ok", false)), "sword equips before battle")
	GameState.set_member_hp("brandt", 50)
	await get_tree().process_frame

	# --- Victory battle: commands, spells, items, rows, rewards --------------
	var pre_gold := GameState.gold
	var pre_xp := GameState.experience
	await main.test_start_battle("bridge_patrol")
	var battle := main.battle_scene
	if battle == null or not await _wait_until(func() -> bool: return battle.phase == "command", 25.0):
		_fail("battle did not reach the first command")
		_finish()
		return

	var hero_units := battle.get_hero_units()
	var enemy_units := battle.get_enemy_units()
	_expect(hero_units.size() == 4, "battle contains all four heroes")
	_expect(enemy_units.size() == 4, "battle contains the encounter enemies")
	var distinct_enemy_names := {}
	for enemy: BattleUnit in enemy_units:
		distinct_enemy_names[enemy.display_name()] = true
	_expect(distinct_enemy_names.size() == enemy_units.size(), "duplicate enemies get unambiguous battle names")
	_expect(battle.heroes[0].stats().get("attack", 0) == 26, "equipped weapon affects battle attack")
	_expect(GameState.location_id == "town", "battle starts from the town bridge")
	_expect(not main.hud.visible, "exploration HUD is hidden during battle")

	var order := battle.get_turn_order()
	_expect(order.size() == 8, "all living combatants are in the turn order")
	var ordered := true
	for i in range(1, order.size()):
		if order[i - 1].agility() < order[i].agility():
			ordered = false
	_expect(ordered, "turn order is sorted by agility")
	_expect(order[0].is_hero, "the fastest hero acts first")
	_expect(battle.get_unit_label_text(hero_units[0]) != "", "battlefield shows a name label over each combatant")
	_expect(battle.hud.get_action_text().contains(battle.active_unit.display_name()), "turn banner names the acting hero")

	# Target highlighting is visible in the 3D battlefield, not only in the menu.
	battle._begin_target_select("АТАКА", battle._living(enemy_units))
	_expect(battle.phase == "target", "attack opens target selection")
	_expect(battle.is_target_ring_visible(), "targeted enemy gets a battlefield ring")
	_expect(battle.hud.get_menu_title().contains("АТАКА"), "target menu names the action")
	battle._cancel_target()
	_expect(not battle.is_target_ring_visible(), "target ring disappears on cancel")

	# A fallen hero must be unmistakable in both the field label and HUD flow.
	var fallen_hero := hero_units[3]
	var fallen_max: int = int(GameState.member_by_id(fallen_hero.member_id).get("max_hp", 1))
	GameState.set_member_hp(fallen_hero.member_id, 0)
	battle._mark_ko(fallen_hero)
	await get_tree().process_frame
	_expect(battle.get_unit_label_text(fallen_hero) == "ПАЛ", "fallen hero's field label says ПАЛ")
	_expect(battle.get_fallen_marker_count() == 1, "fallen hero gets a battlefield marker")
	GameState.set_member_hp(fallen_hero.member_id, int(fallen_max))
	battle._revive_visual(fallen_hero)
	await get_tree().process_frame
	_expect(battle.get_unit_label_text(fallen_hero) != "ПАЛ", "revived hero's label is restored")
	_expect(battle.get_fallen_marker_count() == 0, "revived hero's fallen marker is removed")
	_expect(battle.phase == "command", "target cancel returns to the command menu")

	# Real keyboard routing while Main is in battle mode.
	var menu_before := battle.menu_index
	await _tap_action("move_down")
	_expect(battle.menu_index == wrapi(menu_before + 1, 0, 4), "arrow key navigates the battle command menu")
	await _tap_action("move_up")
	_expect(battle.menu_index == menu_before, "arrow key returns to the first command")
	await _tap_action("equipment")
	_expect(not main.hud.is_equipment_open(), "equipment menu cannot open during battle")

	# Row formulas: back row deals less and takes less from physical attacks.
	var row_target := battle.enemies[0]
	var original_target_row := row_target.row()
	var original_variance := int(GameState.combat.get("variance", {}).get("physical", 0))
	GameState.combat["variance"]["physical"] = 0
	GameState.set_member_row("brandt", "front")
	row_target.enemy_data["row"] = "front"
	var front_dealt := battle._physical_damage(battle.heroes[0], row_target)
	GameState.set_member_row("brandt", "back")
	var back_dealt := battle._physical_damage(battle.heroes[0], row_target)
	_expect(back_dealt < front_dealt, "back row deals less physical damage")
	GameState.set_member_row("brandt", "front")
	row_target.enemy_data["row"] = "front"
	var front_taken := battle._physical_damage(battle.heroes[0], row_target)
	row_target.enemy_data["row"] = "back"
	var back_taken := battle._physical_damage(battle.heroes[0], row_target)
	_expect(back_taken < front_taken, "back row receives less melee damage")
	row_target.enemy_data["row"] = original_target_row
	GameState.combat["variance"]["physical"] = original_variance
	GameState.set_member_row("brandt", "front")

	# Keep the enemies alive while we exercise every command.
	for enemy: BattleUnit in battle.enemies:
		enemy.enemy_hp = 300
	GameState.combat["enemy_ai"]["cast_chance"] = 1.0
	var shaman: BattleUnit = null
	for enemy: BattleUnit in battle.enemies:
		if enemy.enemy_key == "goblin_shaman":
			shaman = enemy
			break
	_expect(shaman != null, "encounter contains a black-magic caster")
	var black_charge_before := shaman.charge("black", 1) if shaman != null else 0
	_expect(black_charge_before == 2, "black magic starts with level charges")

	var magic_tested := false
	var item_tested := false
	var black_tested := false
	var finishing := false
	var guard := 0
	while not battle.battle_over and guard < 80:
		if shaman != null and not black_tested and shaman.charge("black", 1) < black_charge_before:
			black_tested = true
			_expect(true, "enemy black magic consumes a level charge")
		if battle.phase == "command":
			var active_id := battle.active_unit.member_id
			if active_id == "lira" and not magic_tested:
				magic_tested = await _do_white_magic(battle)
			elif active_id == "brandt" and not item_tested:
				item_tested = await _do_potion(battle)
			else:
				if magic_tested and item_tested and black_tested and not finishing:
					_leave_one_enemy(battle)
					finishing = true
				await _do_attack(battle)
			guard += 1
		await get_tree().create_timer(0.08).timeout
	_expect(magic_tested, "white magic was cast and used a level charge")
	_expect(item_tested, "potion was used from the inventory")
	_expect(black_tested, "enemy black magic cast during the battle")
	_expect(finishing, "battle reached its finishing setup")
	_expect(battle.battle_over, "battle ends when the enemies are defeated")
	_expect(str(battle.hud.get_center_title()) == "ПОБЕДА", "victory screen is shown")
	_expect(GameState.gold == pre_gold + 70, "victory grants JSON gold reward")
	_expect(GameState.experience == pre_xp + 61, "victory grants JSON experience reward")
	_expect(battle.phase == "victory", "battle is in victory phase")
	battle.test_confirm_selection()
	if not await _wait_until(func() -> bool: return not main.battle_active, 25.0):
		_fail("battle did not return to exploration after victory")
	await get_tree().process_frame
	_expect(GameState.location_id == "town", "victory returns to the bridge")
	_expect(main.hud.visible, "exploration HUD is visible again")

	# --- Flee battle ----------------------------------------------------------
	var gold_before_flee := GameState.gold
	var xp_before_flee := GameState.experience
	await main.test_start_battle("bridge_scouts")
	var flee_battle := main.battle_scene
	if flee_battle == null or not await _wait_until(func() -> bool: return flee_battle.phase == "command", 25.0):
		_fail("flee battle did not start")
		_finish()
		return
	flee_battle.flee_roll_override = 0.0
	flee_battle.test_move_selection(-1)
	_expect(flee_battle.menu_index == 3, "flee is the fourth battle command")
	flee_battle.test_confirm_selection()
	if not await _wait_until(func() -> bool: return not main.battle_active, 25.0):
		_fail("flee did not return to exploration")
	_finish_if_failed()
	_expect(GameState.gold == gold_before_flee, "flee grants no gold")
	_expect(GameState.experience == xp_before_flee, "flee grants no experience")

	# --- Last rest, then defeat and checkpoint --------------------------------
	await main._load_location("house", "entry", "baker", false)
	var inn_result: Dictionary = GameState.use_inn("inn")
	_expect(bool(inn_result.get("ok", false)), "inn sets the recovery checkpoint")
	_expect(str(GameState.last_rest.get("house_id", "")) == "baker", "last rest is the inn house")
	await main._load_location("town", "castle_gate", "", false)
	await main.test_start_battle("bridge_patrol")
	var defeat_battle := main.battle_scene
	if defeat_battle == null:
		_fail("defeat battle did not start")
		_finish()
		return
	await _wait_until(func() -> bool: return defeat_battle.phase == "command", 20.0)
	for member_id: String in ["brandt", "shade", "kai", "lira"]:
		GameState.set_member_hp(member_id, 0)
	defeat_battle._check_battle_end()
	await _wait_until(func() -> bool: return defeat_battle.phase == "defeat", 5.0)
	_expect(str(defeat_battle.hud.get_center_title()) == "ПАРТИЯ ПОГИБЛА", "party-defeated screen is shown")
	defeat_battle.test_confirm_selection()
	if not await _wait_until(func() -> bool: return not main.battle_active and main.gameplay_ready, 30.0):
		_fail("defeat did not return to the last rest")
	await get_tree().process_frame
	_expect(GameState.location_id == "house", "defeat returns to the inn interior")
	_expect(GameState.house_id == "baker", "defeat returns to the inn house")
	var all_healed := true
	for member: Dictionary in GameState.party:
		if int(member.get("hp", 0)) != int(member.get("max_hp", 1)):
			all_healed = false
	_expect(all_healed, "last rest restores the whole party")
	var charges_restored := GameState.get_spell_charges("lira", "white", 2) == 1
	_expect(charges_restored, "last rest restores spell level charges")

	# --- Random encounter on the bridge --------------------------------------
	await main._load_location("town", "castle_gate", "", false)
	GameState.encounters_enabled = true
	GameState.combat["encounter"]["bridge_chance"] = 1.0
	GameState._encounter_cooldown_steps = 0
	_expect(GameState.is_bridge_cell(Vector2i(0, -20)), "bridge cells are encounter cells")
	_expect(not GameState.is_bridge_cell(Vector2i(0, 0)), "plaza cells are not encounter cells")
	var direct_encounter := GameState.try_start_encounter(Vector2i(0, -20))
	_expect(not direct_encounter.is_empty(), "bridge encounter roll returns an encounter at 100% chance")
	GameState._encounter_cooldown_steps = 0
	main._on_party_stepped(Vector2i(0, -20), Vector2i(0, -1))
	if not await _wait_until(func() -> bool: return main.battle_active and main.battle_scene != null, 20.0):
		_fail("Main did not start a battle from a bridge step")
	else:
		_expect(true, "Main starts a battle from a bridge step")
		var bridge_battle := main.battle_scene
		for enemy: BattleUnit in bridge_battle.enemies:
			enemy.enemy_hp = 0
		bridge_battle._check_battle_end()
		await _wait_until(func() -> bool: return bridge_battle.phase == "victory", 5.0)
		bridge_battle.test_confirm_selection()
		await _wait_until(func() -> bool: return not main.battle_active, 25.0)
	GameState.combat["encounter"]["bridge_chance"] = 0.22
	GameState.encounters_enabled = false

	_finish()


func _do_attack(battle: BattleScene) -> void:
	battle.test_move_selection(-battle.menu_index)
	battle.test_confirm_selection()
	await get_tree().process_frame
	if battle.phase == "target":
		battle.test_confirm_selection()
	await get_tree().create_timer(0.3).timeout


func _do_white_magic(battle: BattleScene) -> bool:
	if battle.active_unit.member_id != "lira":
		return false
	battle.test_move_selection(1 - battle.menu_index)
	battle.test_confirm_selection()
	await get_tree().process_frame
	if battle.phase != "spell":
		return false
	var holy_index := -1
	for i in battle.spell_choices.size():
		if str(battle.spell_choices[i].get("id", "")) == "holy_lance":
			holy_index = i
			break
	if holy_index < 0:
		battle.test_cancel_selection()
		return false
	battle.test_move_selection(holy_index - battle.menu_index)
	battle.test_confirm_selection()
	await get_tree().process_frame
	if battle.phase != "target":
		return false
	battle.test_confirm_selection()
	await get_tree().create_timer(0.5).timeout
	return GameState.get_spell_charges("lira", "white", 2) == 0 and GameState.get_spell_charges("lira", "white", 1) == 3


func _do_potion(battle: BattleScene) -> bool:
	if battle.active_unit.member_id != "brandt":
		return false
	var before := GameState.item_count("potion")
	if before <= 0:
		return false
	battle.test_move_selection(2 - battle.menu_index)
	battle.test_confirm_selection()
	await get_tree().process_frame
	if battle.phase != "item":
		return false
	var potion_index := -1
	for i in battle.item_choices.size():
		if str(battle.item_choices[i].get("id", "")) == "potion":
			potion_index = i
			break
	if potion_index < 0:
		battle.test_cancel_selection()
		return false
	battle.test_move_selection(potion_index - battle.menu_index)
	battle.test_confirm_selection()
	await get_tree().process_frame
	if battle.phase != "target":
		return false
	battle.test_confirm_selection()
	await get_tree().create_timer(0.5).timeout
	return GameState.item_count("potion") == before - 1


func _leave_one_enemy(battle: BattleScene) -> void:
	for i in battle.enemies.size():
		battle.enemies[i].enemy_hp = 1 if i == 0 else 0


func _finish_if_failed() -> void:
	if not failures.is_empty():
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
		print("[BATTLE] PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	print("[BATTLE] FAIL: %s" % message)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[BATTLE] %d checks passed, %d failed" % [passes, failures.size()])
	if failures.is_empty():
		print("[BATTLE] RESULT: PASS — equipment, turn order, rows, commands, charges, rewards, flee, defeat and bridge encounters")
		get_tree().quit(0)
	else:
		print("[BATTLE] RESULT: FAIL")
		for failure: String in failures:
			print("  - %s" % failure)
		get_tree().quit(1)
