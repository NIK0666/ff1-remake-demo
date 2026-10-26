extends Node
## Headless end-to-end acceptance run:
##   castle gate -> far end of the north bridge -> back -> throne room.
## Uses the same collision queries and GameState commits as real movement.

var main: GameMain
var failures: Array[String] = []
var checks: Array[String] = []
var _start_time: int = 0


func _ready() -> void:
	_start_time = Time.get_ticks_msec()
	Engine.time_scale = 3.0
	print("[ACCEPTANCE] start")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if not await _wait_until(func() -> bool: return main.gameplay_ready, 20.0):
		_fail("initial town did not become playable")
		_finish()
		return
	GameState.encounters_enabled = false
	await get_tree().process_frame
	await get_tree().process_frame

	# Party identity and classes -------------------------------------------------
	var party := main.get_party()
	_expect(GameState.party.size() == 4, "party has exactly 4 heroes")
	_expect(party.actors.size() == 4, "4 persistent hero actors exist")
	_expect(party.party_ids() == ["brandt", "shade", "kai", "lira"], "party order is warrior, thief, monk, white mage")
	_expect(party.party_classes() == ["warrior", "thief", "monk", "white_mage"], "class ids match the brief")
	_expect(GameState.location_id == "town", "run begins in Cornelia")

	# Real keyboard-driven movement smoke test -----------------------------------
	var input_start := GameState.leader_cell
	Input.action_press("move_up")
	if await _wait_until(func() -> bool: return GameState.leader_cell != input_start, 3.0):
		Input.action_release("move_up")
		await _wait_until(func() -> bool: return not main.get_party().moving, 3.0)
		_expect(GameState.leader_cell == input_start + Vector2i(0, -1), "WASD/arrow actions move exactly one orthogonal grid cell")
		Input.action_press("move_down")
		await _wait_until(func() -> bool: return GameState.leader_cell == input_start, 3.0)
		Input.action_release("move_down")
		await _wait_until(func() -> bool: return not main.get_party().moving, 3.0)
	else:
		Input.action_release("move_up")
		_fail("keyboard movement action did not reach the party")

	# NPC / content invariants --------------------------------------------------
	var town_data := GameState.get_location("town")
	_expect(town_data["npcs"].size() == 2, "two town NPCs are present")
	var throne_data := GameState.get_location("throne_room")
	_expect(throne_data["npcs"].size() == 1, "one NPC in the throne room")
	_expect(GameState.get_dialogue("king")["line"].contains("Гарланд"), "king's line mentions Garland")
	_expect(GameState.get_dialogue("king")["line"].contains("Сару"), "king's line mentions Sarah")
	_expect(town_data["houses"].size() == 6, "six enterable houses are authored")
	_expect(int(GameState.dialogue.get("npc_count", 0)) == 3, "dialogue data declares exactly three NPCs")
	for npc_id: String in ["guard", "resident", "king"]:
		var line := str(GameState.get_dialogue(npc_id).get("line", ""))
		_expect(not line.is_empty(), "NPC '%s' has one authored line" % npc_id)

	# Collision invariants ------------------------------------------------------
	var location := main.current_location
	_expect(not location.can_party_stand(Vector2i(-8, 3)), "castle interior wall blocks the party")
	_expect(not location.can_party_stand(Vector2i(4, -25)), "river water is impassable")
	_expect(location.can_party_stand(Vector2i(0, -25)), "bridge deck is walkable")
	_expect(not location.can_party_stand(Vector2i(10, -11)), "one of the northern houses blocks its footprint")

	var start_cell: Vector2i = GameState.leader_cell
	print("[ACCEPTANCE] start cell: %s" % str(start_cell))
	_expect(start_cell == Vector2i(-12, 12), "start is on the ceremonial south side of the castle")

	# Every house is reachable on foot from the castle gate.
	for house: Dictionary in town_data["houses"]:
		var return_spawn := str(house["door"]["return_spawn"])
		var approach := GameState.to_cell(GameState.get_spawn_data("town", return_spawn).get("leader", [0, 0]))
		var house_path := _find_path(location, start_cell, approach)
		_expect(not house_path.is_empty(), "house '%s' is reachable on foot from the gate" % str(house["id"]))

	# The route: castle gate -> far end of the bridge ----------------------------
	var path_to_bridge := _find_path(location, GameState.leader_cell, Vector2i(0, -34))
	_expect(not path_to_bridge.is_empty(), "a walkable route exists from the castle gate to the far bridge")
	if path_to_bridge.is_empty():
		_finish()
		return
	print("[ACCEPTANCE] bridge path: %d steps" % path_to_bridge.size())
	if not await _walk(path_to_bridge):
		_fail("walking to the bridge failed")
		_finish()
		return
	await get_tree().process_frame
	_expect(GameState.leader_cell == Vector2i(0, -34), "party reached the far end of the bridge")
	_expect(GameState.has_flag("reached_bridge_end"), "bridge objective flag fired")
	_expect(GameState.objective_text().contains("Вернитесь"), "objective switched to returning to the castle")

	# ... and back into the throne room -----------------------------------------
	var path_back := _find_path(location, GameState.leader_cell, start_cell)
	_expect(not path_back.is_empty(), "a walkable route exists back to the castle gate")
	if path_back.is_empty():
		_finish()
		return
	print("[ACCEPTANCE] return path: %d steps" % path_back.size())
	if not await _walk(path_back):
		_fail("walking back to the castle failed")
		_finish()
		return
	await get_tree().process_frame
	_expect(GameState.leader_cell == start_cell, "party returned to the castle gate")
	var before_party_id := party.get_instance_id()
	var before_actor_ids: Array[int] = []
	for actor: CharacterVisual in party.actors:
		before_actor_ids.append(actor.get_instance_id())

	var target: Interactable = main.test_refresh_interaction()
	_expect(target != null, "castle gate interaction is available")
	if target == null:
		_finish()
		return
	_expect(str(target.payload.get("target", "")) == "throne_room", "castle gate targets the throne room")
	main.test_interact()
	if not await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "throne_room", 20.0):
		_fail("court transition did not finish")
		_finish()
		return
	await get_tree().process_frame
	_expect(main.get_party().get_instance_id() == before_party_id, "party node survived the scene change (no reload)")
	var after_actor_ids: Array[int] = []
	for actor: CharacterVisual in main.get_party().actors:
		after_actor_ids.append(actor.get_instance_id())
	_expect(after_actor_ids == before_actor_ids, "all four hero actors survived the scene change")
	_expect(GameState.location_id == "throne_room", "party is now in the throne room")
	_expect(GameState.has_flag("throne_entered"), "throne room objective flag fired")

	# Walk to the king and verify the dialogue is interactable.
	var throne_path := _find_path(main.current_location, GameState.leader_cell, Vector2i(0, -4))
	_expect(not throne_path.is_empty(), "a route to the king exists inside the throne room")
	if not throne_path.is_empty():
		await _walk(throne_path)
		await get_tree().process_frame
		var king_target: Interactable = main.test_refresh_interaction()
		_expect(king_target != null and str(king_target.payload.get("npc_id", "")) == "king", "king is interactable from the aisle")
		if king_target != null:
			main.test_interact()
			await get_tree().process_frame
			_expect(main.hud.is_dialogue_open(), "king dialogue opens")
			_expect(main.hud._dialogue_full_text.contains("Гарланд") and main.hud._dialogue_full_text.contains("Сару"), "king speaks about Garland and Sarah")
			main.test_advance_dialogue()
			main.test_advance_dialogue()
			await get_tree().process_frame
			_expect(not main.hud.is_dialogue_open(), "dialogue closes with E")

	_finish()


func _walk(path_cells: Array[Vector2i]) -> bool:
	for i in path_cells.size():
		var next_cell: Vector2i = path_cells[i]
		var dir := next_cell - GameState.leader_cell
		if not main.test_try_step(dir):
			_fail("step %d/%d to %s was blocked" % [i + 1, path_cells.size(), str(next_cell)])
			return false
		if i % 8 == 0:
			await get_tree().process_frame
	await get_tree().process_frame
	return true


func _find_path(location: LocationBase, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == goal:
			break
		for d: Vector2i in DIRS:
			var nb := cell + d
			if came_from.has(nb):
				continue
			if not location.can_party_stand(nb):
				continue
			came_from[nb] = cell
			queue.append(nb)
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		path.push_front(cursor)
		cursor = came_from[cursor]
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
		checks.append(message)
		print("[ACCEPTANCE] PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[ACCEPTANCE] FAIL: %s" % message)
	print("[ACCEPTANCE] FAIL: %s" % message)


func _finish() -> void:
	Engine.time_scale = 1.0
	var elapsed := float(Time.get_ticks_msec() - _start_time) / 1000.0
	print("[ACCEPTANCE] %d checks passed, %d failed in %.1fs" % [checks.size(), failures.size(), elapsed])
	if failures.is_empty():
		print("[ACCEPTANCE] RESULT: PASS — castle gate -> bridge -> throne room")
		get_tree().quit(0)
	else:
		print("[ACCEPTANCE] RESULT: FAIL")
		for failure: String in failures:
			print("  - %s" % failure)
		get_tree().quit(1)
