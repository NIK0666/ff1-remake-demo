extends Node
## Non-headless screenshot tour used during development.

var main: GameMain
var _shot_index: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if not await _wait_until(func() -> bool: return main.gameplay_ready, 25.0):
		push_error("Capture scene: game did not load")
		get_tree().quit(1)
		return
	GameState.encounters_enabled = false
	await get_tree().create_timer(1.2).timeout
	await _shot("01_cornelia_castle_gate")
	await _capture_overview()

	var start_cell := GameState.leader_cell
	await _walk_to(Vector2i(0, 3))
	await get_tree().create_timer(1.1).timeout
	await _shot("02_cornelia_plaza")

	await _walk_to(Vector2i(0, -25))
	await get_tree().create_timer(1.2).timeout
	await _shot("03_north_bridge")

	await _walk_to(Vector2i(0, -33))
	await get_tree().create_timer(1.0).timeout
	await _shot("04_far_bridge")

	# Return to the castle gate, interact, then settle into the throne room.
	await _walk_to(start_cell)
	await get_tree().process_frame
	main.test_refresh_interaction()
	main.test_interact()
	if not await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "throne_room", 25.0):
		push_error("Capture scene: throne room did not load")
		get_tree().quit(1)
		return
	await get_tree().create_timer(4.0).timeout
	await _shot("05_throne_room")

	await _walk_to(Vector2i(0, -4))
	await get_tree().process_frame
	main.test_refresh_interaction()
	main.test_interact()
	await get_tree().create_timer(2.6).timeout
	await _shot("06_king_audience")
	main.test_advance_dialogue()
	main.test_advance_dialogue()
	await get_tree().create_timer(0.2).timeout

	# A house interior, reached through the real town door flow.
	main._load_location("town", "baker_return", "", false)
	if not await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "town", 25.0):
		get_tree().quit(1)
		return
	await _walk_to(Vector2i(10, -8))
	await get_tree().process_frame
	main.test_refresh_interaction()
	main.test_interact()
	if not await _wait_until(func() -> bool: return main.gameplay_ready and GameState.location_id == "house", 25.0):
		get_tree().quit(1)
		return
	await get_tree().create_timer(4.0).timeout
	await _shot("07_house_interior")

	# Service UI screenshots.
	if main.hud.is_service_open():
		main.test_service_close()
	main._open_service({"service_id": "inn"})
	await get_tree().create_timer(0.3).timeout
	await _shot("08_inn_service")
	main.test_service_close()
	await get_tree().create_timer(0.2).timeout

	await main._load_location("house", "entry", "herbalist", false)
	await get_tree().create_timer(0.8).timeout
	main._open_service({"service_id": "item_shop"})
	await get_tree().create_timer(0.3).timeout
	await _shot("09_item_shop")

	# Reproduce the service acceptance flow for the final plaza screenshot.
	main.test_service_confirm()
	main.test_service_close()
	await get_tree().create_timer(0.2).timeout
	await main._load_location("house", "entry", "baker", false)
	await get_tree().create_timer(0.5).timeout
	main._open_service({"service_id": "inn"})
	await get_tree().create_timer(0.3).timeout
	main.test_service_confirm()
	main.test_service_close()
	await get_tree().create_timer(0.2).timeout
	await main._load_location("town", "baker_return", "", false)
	await _walk_to(Vector2i(0, 3))
	await get_tree().create_timer(3.5).timeout
	await _shot("10_plaza_after_services")

	print("[CAPTURE] done: %d screenshots" % _shot_index)
	get_tree().quit(0)


func _capture_overview() -> void:
	main.hud.visible = false
	var overview := Camera3D.new()
	overview.name = "OverviewCamera"
	overview.fov = 52.0
	add_child(overview)
	overview.current = true
	overview.global_position = Vector3(48.0, 58.0, 56.0)
	overview.look_at(Vector3(2.0, 0.0, 2.0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("00_cornelia_overview")
	overview.queue_free()
	main.camera_rig.camera.current = true
	main.hud.visible = true
	await get_tree().process_frame


func _walk_to(goal: Vector2i) -> void:
	if main.current_location == null:
		return
	var path := _find_path(main.current_location, GameState.leader_cell, goal)
	for cell: Vector2i in path:
		var dir := cell - GameState.leader_cell
		if not main.test_try_step(dir):
			push_error("Capture walk blocked at %s" % str(cell))
			break
		await get_tree().process_frame


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


func _shot(shot_name: String) -> void:
	_shot_index += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://screenshots/%s.png" % shot_name
	image.save_png(path)
	print("[CAPTURE] saved %s (%dx%d)" % [path, image.get_width(), image.get_height()])
