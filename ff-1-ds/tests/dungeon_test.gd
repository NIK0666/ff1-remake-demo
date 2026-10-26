extends Node
## End-to-end Chaos Shrine test: town entrance, two floors, stairs, key chest,
## locked door, rare shrine encounters, Garland, Sarah rescue and the king's replay.

var main: GameMain
var passes: int = 0
var failures: Array[String] = []


func _ready() -> void:
	Engine.time_scale = 4.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if not await _wait_until(func() -> bool: return main.gameplay_ready, 25.0):
		_fail("game did not load")
		_finish()
		return
	GameState.encounters_enabled = false

	# Town side of the entrance.
	await main._load_location("town", "shrine_return", "", false)
	await get_tree().process_frame
	var entrance_point := _find_door_to("chaos_shrine_1")
	_expect(entrance_point != null and str(entrance_point.payload.get("target", "")) == "chaos_shrine_1", "far bridge has an entrance to the shrine")
	if entrance_point != null:
		main.test_refresh_interaction()
		main.test_interact()
	if not await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "chaos_shrine_1", 20.0):
		_fail("town entrance did not load shrine floor one")
		_finish()
		return
	_expect(main.current_location is ChaosShrineBuilder, "shrine floor one uses the shrine builder")
	await get_tree().process_frame

	# Rare encounters use the same battle rules with a shrine arena.
	var shrine_cfg: Dictionary = GameState.get_location("chaos_shrine_1").get("encounter", {})
	var chance := float(shrine_cfg.get("chance", 1.0))
	_expect(chance > 0.0 and chance < 0.1, "shrine random encounters are rare")
	_expect(not ((shrine_cfg.get("ids", []) as Array).is_empty()), "shrine has an encounter table")
	shrine_cfg["chance"] = 1.0
	GameState.encounters_enabled = true
	GameState._encounter_cooldown_steps = 0
	var random_encounter := GameState.try_start_encounter(GameState.leader_cell)
	GameState.encounters_enabled = false
	shrine_cfg["chance"] = chance
	_expect(not random_encounter.is_empty(), "a shrine step can produce a random encounter")
	_expect(str(random_encounter.get("arena", "")) == "shrine", "shrine encounters use the shrine battle arena")

	# Regain deterministic control and inspect all floor-one interaction points.
	var chest_point := _find_interactable("chest")
	var door_point := _find_interactable("locked_door")
	var stairs_point := _find_door_to("chaos_shrine_2")
	_expect(chest_point != null, "floor one contains a chest")
	_expect(door_point != null, "floor one contains a locked door")
	_expect(stairs_point != null, "floor one contains stairs to floor two")
	_expect(stairs_point != null and not stairs_point.enabled, "stairs behind the locked door start disabled")

	# Locked door first: refusal without the key.
	if door_point != null:
		await _walk_near(door_point.global_position)
		main.test_refresh_interaction()
		var target := main.current_interactable
		_expect(target != null and target.kind == "locked_door", "door is the nearby interaction")
		main.test_interact()
		await get_tree().process_frame
		_expect(not GameState.has_flag("shrine_door_opened"), "door stays locked without the key")
		_expect(GameState.item_count("chaos_key") == 0, "party does not have the key before the chest")

	# Chest gives the key once.
	if chest_point != null:
		await _walk_near(chest_point.global_position)
		main.test_refresh_interaction()
		var target := main.current_interactable
		_expect(target != null and target.kind == "chest", "chest is the nearby interaction")
		main.test_interact()
		await get_tree().process_frame
		_expect(GameState.item_count("chaos_key") == 1, "chest puts the Chaos Key in the inventory")
		_expect(GameState.has_flag("shrine_chest_opened"), "chest remembers that it was opened")
		_expect(not chest_point.enabled, "opened chest is no longer interactable")
		main.test_refresh_interaction()

	# The door now accepts the key.
	if door_point != null:
		await _walk_near(door_point.global_position)
		main.test_refresh_interaction()
		main.test_interact()
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		_expect(GameState.has_flag("shrine_door_opened"), "door opens with the Chaos Key")
		_expect(GameState.item_count("chaos_key") == 1, "Chaos Key is kept after opening the door")
		_expect(stairs_point.enabled, "stairs become available after opening the door")

	# Climb the staircase to floor two.
	if stairs_point != null:
		await _walk_near(stairs_point.global_position)
		main.test_refresh_interaction()
		var target := main.current_interactable
		_expect(target != null and target.kind == "door" and str(target.payload.get("target", "")) == "chaos_shrine_2", "stairs target floor two")
		main.test_interact()
	if not await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "chaos_shrine_2", 20.0):
		_fail("stairs did not load shrine floor two")
		_finish()
		return
	_expect(main.current_location is ChaosShrineBuilder, "shrine floor two uses the shrine builder")
	_expect(not main.current_location.has_node("Sarah"), "Sarah appears only after Garland falls")
	await get_tree().process_frame

	# Garland.
	var boss_point := _find_interactable("boss")
	_expect(boss_point != null, "Garland is interactable on floor two")
	var boss_template: Dictionary = GameState.combat.get("enemies", {}).get("garland", {})
	_expect(int(boss_template.get("max_hp", 0)) == 380, "Garland has late-game boss HP")
	_expect(int((boss_template.get("stats", {}) as Dictionary).get("attack", 0)) >= 20, "Garland hits hard without equipment")
	if boss_point != null:
		await _walk_near(boss_point.global_position)
		main.test_refresh_interaction()
		var target := main.current_interactable
		_expect(target != null and target.kind == "boss", "boss prompt is the nearby interaction")
		main.test_interact()
	if not await _wait_until(func() -> bool: return main.battle_active and main.battle_scene != null, 25.0):
		_fail("Garland battle did not start")
		_finish()
		return
	var battle := main.battle_scene
	if not await _wait_until(func() -> bool: return battle.phase == "command", 25.0):
		_fail("Garland battle did not reach command")
		_finish()
		return
	_expect(str(battle.arena.get("title", "")) == "СВЯТИЛИЩЕ ХАОСА", "Garland fights in the shrine arena")
	_expect(str(main.get_battle_context().get("type", "")) == "boss", "battle carries the boss context")
	_expect(battle.enemies.size() == 1 and battle.enemies[0].display_name() == "Гарланд", "Garland is the sole boss enemy")

	# The encounter flow is verified without a long random fight; force the
	# boss's defeat to exercise the victory screen, rescue scene and flags.
	for enemy: BattleUnit in battle.enemies:
		enemy.enemy_hp = 0
	battle._check_battle_end()
	await _wait_until(func() -> bool: return battle.phase == "victory", 5.0)
	_expect(str(battle.hud.get_center_title()) == "ПОБЕДА", "Garland victory screen appears")
	battle.test_confirm_selection()
	if not await _wait_until(func() -> bool: return not main.battle_active and main.hud.is_story_open(), 30.0):
		_fail("Garland victory did not start the Sarah scene")
		_finish()
		return
	_expect(GameState.has_flag("garland_defeated"), "Garland defeat is recorded")
	_expect(not GameState.has_flag("sarah_rescued"), "rescue is not marked before the scene ends")
	_expect(main.current_location.has_node("Sarah"), "Sarah appears in the altar room")
	_expect(main.hud._dialogue_name.text == "Сара", "rescue scene opens with Sarah")
	var story_guard := 0
	while main.hud.is_story_open() and story_guard < 24:
		main.hud.advance_dialogue()
		await get_tree().process_frame
		story_guard += 1
	await get_tree().process_frame
	_expect(not main.hud.is_story_open(), "Sarah scene finishes")
	_expect(GameState.has_flag("sarah_rescued"), "Sarah rescue flag is set")
	_expect(GameState.objective_text() == GameState.ui_text("objective_rescued"), "objective points back to the king")
	_expect(main.party.controls_enabled, "control returns after the rescue scene")
	_expect(not main.ending_active, "rescuing Sarah alone does not end the demo")

	# Re-entering the boss room shows Sarah and no repeat boss.
	await main._load_location("chaos_shrine_2", "from_floor1", "", false)
	await get_tree().process_frame
	_expect(main.current_location.has_node("Sarah"), "Sarah remains in the shrine after the rescue")
	var repeat_boss := _find_interactable("boss")
	_expect(repeat_boss == null, "Garland cannot be fought again")
	var down_stairs := _find_door_to("chaos_shrine_1")
	_expect(down_stairs != null, "floor two still has stairs down")
	if down_stairs != null:
		await _walk_near(down_stairs.global_position)
		main.test_refresh_interaction()
		var target := main.current_interactable
		_expect(target != null and str(target.payload.get("target", "")) == "chaos_shrine_1", "floor two stairs lead back to floor one")
		main.test_interact()
		await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "chaos_shrine_1", 20.0)
		_expect(GameState.location_id == "chaos_shrine_1", "descending the stairs returns to floor one")

	# Floor-one exit back to the far bridge landing.
	var town_exit := _find_door_to("town")
	_expect(town_exit != null, "floor one has an exit back to town")
	if town_exit != null:
		await _walk_near(town_exit.global_position)
		main.test_refresh_interaction()
		var target := main.current_interactable
		_expect(target != null and str(target.payload.get("target", "")) == "town", "shrine exit targets town")
		main.test_interact()
		await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "town", 20.0)
		_expect(GameState.location_id == "town", "shrine exit returns to the far bridge")
		_expect(GameState.spawn_id == "shrine_return", "shrine exit uses the far-landing spawn")

	# King's alternate line now triggers the bridge-construction finale.
	await main._load_location("throne_room", "from_town", "", false)
	await get_tree().process_frame
	var king_point := _find_interactable("npc")
	_expect(king_point != null and str(king_point.payload.get("npc_id", "")) == "king", "king is present for the epilogue")
	if king_point != null:
		await _walk_near(king_point.global_position)
		main.test_refresh_interaction()
		main.test_interact()
		await get_tree().process_frame
		_expect(main.hud.is_dialogue_open(), "king dialogue opens after the rescue")
		_expect(main.hud._dialogue_full_text.contains("Сара вернулась"), "king gives a different line after the rescue")
		main.hud.advance_dialogue()
		await get_tree().process_frame
		main.hud.advance_dialogue()
		await get_tree().process_frame
		_expect(GameState.has_flag("king_rescued_spoken"), "king recognises the rescue")
		_expect(GameState.objective_text() == GameState.ui_text("objective_complete"), "epilogue objective is complete")

	if not await _wait_until(func() -> bool: return main.ending_active and main.ending_scene != null, 20.0):
		_fail("king epilogue did not start the bridge finale")
		_finish()
		return
	var ending := main.ending_scene
	_expect(ending.get_worker_count() >= 4, "bridge finale shows royal workers")
	_expect(not main.hud.visible, "exploration HUD is hidden during the finale")
	_expect(not GameState.has_flag("demo_complete"), "demo is not marked complete before the ending title")
	if not await _wait_until(func() -> bool: return ending.is_final_visible(), 30.0):
		_fail("bridge finale did not reach the demo-complete screen")
		_finish()
		return
	_expect(ending.get_final_title_text() == "ДЕМО ЗАВЕРШЕНО", "final screen says the demo is complete")
	_expect(GameState.has_flag("demo_ending_started"), "bridge finale is marked as started")
	_expect(GameState.has_flag("demo_complete"), "demo-complete flag is set")

	_finish()


func _find_interactable(kind: String) -> Interactable:
	if main.current_location == null:
		return null
	for point: Interactable in main.current_location.interactables:
		if point.kind == kind and point.enabled:
			return point
	return null


func _find_door_to(target: String) -> Interactable:
	if main.current_location == null:
		return null
	for point: Interactable in main.current_location.interactables:
		if point.kind == "door" and str(point.payload.get("target", "")) == target:
			return point
	return null


func _walk_near(world_point: Vector3) -> bool:
	var location := main.current_location
	if location == null:
		return false
	var reach := float(GameState.game["interaction"]["range"])
	var path_info := _find_path_near(location, GameState.leader_cell, world_point, reach)
	if not bool(path_info.get("found", false)):
		_fail("no path near %s" % str(world_point))
		return false
	var path: Array = path_info.get("path", [])
	for cell: Vector2i in path:
		if not main.test_try_step(cell - GameState.leader_cell):
			_fail("movement blocked before %s" % str(cell))
			return false
		await get_tree().process_frame
	await get_tree().process_frame
	return true


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
			if location.cell_to_world(nb).distance_to(world_point) <= max_distance:
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
		print("[DUNGEON] PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	print("[DUNGEON] FAIL: %s" % message)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[DUNGEON] %d checks passed, %d failed" % [passes, failures.size()])
	if failures.is_empty():
		print("[DUNGEON] RESULT: PASS — shrine, key, locked door, stairs, Garland, Sarah and king epilogue")
		get_tree().quit(0)
	else:
		print("[DUNGEON] RESULT: FAIL")
		for failure: String in failures:
			print("  - %s" % failure)
		get_tree().quit(1)
