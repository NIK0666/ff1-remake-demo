extends Node
## Verifies every one of the six house doors: enter -> different location ->
## exit -> correct return spawn, while the same party instances persist.

var main: GameMain
var failures: Array[String] = []
var passed: int = 0


func _ready() -> void:
	Engine.time_scale = 3.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if not await _wait_until(func() -> bool: return main.gameplay_ready, 20.0):
		_fail("game did not load")
		_finish()
		return
	var party_id := main.get_party().get_instance_id()
	var actor_ids: Array = main.get_party().actors.map(func(actor: CharacterVisual) -> int: return actor.get_instance_id())
	var houses: Array = GameState.get_house_list()
	for house: Dictionary in houses:
		var house_id := str(house["id"])
		var return_spawn := str(house["door"]["return_spawn"])
		await main._load_location("town", return_spawn, "", false)
		await get_tree().process_frame
		var target: Interactable = main.test_refresh_interaction()
		_expect(target != null, "%s: door is in reach from its return spawn" % house_id)
		if target == null:
			continue
		_expect(str(target.payload.get("house_id", "")) == house_id, "%s: nearest interaction is the correct house door" % house_id)
		main.test_interact()
		var entered := await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "house", 20.0)
		_expect(entered, "%s: entering the house changes the scene" % house_id)
		if not entered:
			continue
		_expect(GameState.house_id == house_id, "%s: active house variant is correct" % house_id)
		_expect(main.get_party().get_instance_id() == party_id, "%s: party node was not reloaded" % house_id)
		var current_ids: Array = main.get_party().actors.map(func(actor: CharacterVisual) -> int: return actor.get_instance_id())
		_expect(current_ids == actor_ids, "%s: all four hero actors persisted" % house_id)
		var exit_point: Interactable = null
		for point: Interactable in main.current_location.interactables:
			if point.kind == "door" and str(point.payload.get("target", "")) == "town":
				exit_point = point
				break
		_expect(exit_point != null, "%s: interior has a return door" % house_id)
		if exit_point == null:
			continue
		var route := _find_path(main.current_location, GameState.leader_cell, Vector2i(0, 5))
		_expect(not route.is_empty(), "%s: exit route is walkable" % house_id)
		if route.is_empty():
			continue
		for cell: Vector2i in route:
			if not main.test_try_step(cell - GameState.leader_cell):
				_fail("%s: interior step blocked" % house_id)
				break
			await get_tree().process_frame
		main.test_refresh_interaction()
		_expect(main.is_interaction_available(), "%s: exit prompt is available" % house_id)
		main.test_interact()
		var returned := await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "town", 20.0)
		_expect(returned, "%s: exiting returns to town" % house_id)
		if not returned:
			continue
		var expected := GameState.get_spawn_data("town", return_spawn)
		var expected_leader := GameState.to_cell(expected.get("leader", [0, 0]))
		_expect(GameState.leader_cell == expected_leader, "%s: return spawn is correct" % house_id)
		_expect(main.get_party().get_instance_id() == party_id, "%s: party survived the round trip" % house_id)
		await get_tree().process_frame
	_finish()


func _find_path(location: LocationBase, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var queue: Array[Vector2i] = [start]
	var came: Dictionary = {start: start}
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == goal:
			break
		for d: Vector2i in DIRS:
			var nb := cell + d
			if came.has(nb) or not location.can_party_stand(nb):
				continue
			came[nb] = cell
			queue.append(nb)
	if not came.has(goal):
		return []
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
		passed += 1
		print("[HOUSES] PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	print("[HOUSES] FAIL: %s" % message)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[HOUSES] %d checks passed, %d failed" % [passed, failures.size()])
	if failures.is_empty():
		print("[HOUSES] RESULT: PASS — all six house scene transitions")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
