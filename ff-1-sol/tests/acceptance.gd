extends Node
## Executed through the production controller, with only tween time shortened.
var game
var failures: Array[String] = []
var checks: int
var original_ids: Array[int] = []
var original_heroes: Array
var screenshots := false

func _check(condition: bool, message: String) -> void:
	checks += int(GameState.rules.n.one)
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func run(controller: Node) -> void:
	game = controller
	# The old city/service route is deterministic. Dedicated combat tests re-enable encounters.
	GameState.session.encounters_enabled = false
	checks = int(GameState.rules.n.zero)
	screenshots = OS.get_cmdline_user_args().has("--screenshots")
	original_heroes = GameState.session.heroes
	for actor in game.actors:
		original_ids.append(actor.get_instance_id())
	await get_tree().physics_frame
	_check(game.actors.size() == int(GameState.rules.test.party_count), "Exactly four heroes")
	_check(GameState.leader() == GameState.cell(GameState.map.town.spawn), "Start at castle gates")
	_check(GameState.map.town.houses.size() == int(GameState.rules.test.house_count), "Six enterable houses")
	_check(not game.world.can_walk(GameState.cell(GameState.rules.test.blocked_wall)), "City wall blocks movement")
	_check(not game.world.can_walk(GameState.cell(GameState.rules.test.blocked_water)), "River blocks movement")
	_check(not await game.request_step(Vector2i.ONE), "Diagonal input is rejected")
	await _capture("cornelia")
	await _keyboard_check()
	await _walk_to(GameState.cell(GameState.map.town.spawn))
	# Acceptance route begins here, before any optional house visits.
	await _walk_to(GameState.cell(GameState.rules.test.bridge_goal))
	_check(GameState.session.bridge_reached, "Castle gates to far end of bridge in the same run")
	await get_tree().create_timer(GameState.rules.test.wait_seconds).timeout
	var expected_camera: Vector3 = game.actors.front().position + GameState.vec(GameState.rules.camera.offset) + GameState.vec(GameState.rules.camera.target_offset)
	_check(game.camera.position.distance_to(expected_camera) < GameState.rules.test.camera_tolerance, "Camera follows the actual leader after movement")
	await _walk_to(GameState.cell(GameState.rules.test.bridge_view))
	await _capture("bridge")
	await _walk_to(GameState.cell(GameState.rules.test.water_approach))
	var before: Vector2i = GameState.leader()
	_check(not await game.request_step(Vector2i.LEFT), "Cannot leave bridge into water")
	_check(GameState.leader() == before, "Blocked move preserves party position")
	await _walk_to(GameState.cell(GameState.rules.test.castle_door))
	_check(GameState.session.location == "throne", "Castle door actually loads throne scene")
	_check(GameState.session.returned_to_throne, "Bridge to throne return completed")
	_check(_same_party(), "All four original party nodes and state survive scene change")
	await _walk_to(GameState.cell(GameState.rules.test.king_approach))
	game.interact()
	_check(game.hud.dialog_open and game.hud.dialog.id == "king", "King can be spoken to")
	_check("Сару унёс Гарланд" in game.hud.dialog.text, "King tells of Sarah and Garland")
	_check(not await game.request_step(Vector2i.RIGHT), "Dialogue pauses party movement")
	await _capture("throne")
	game.interact()
	await _walk_to(GameState.cell(GameState.map.throne.portals.front().cell))
	_check(GameState.session.location == "town", "Throne exit returns to town")
	for approach in [GameState.rules.test.guard_approach, GameState.rules.test.resident_approach]:
		await _walk_to(GameState.cell(approach))
		game.interact()
		_check(game.hud.dialog_open, "Town NPC dialogue: " + str(game.hud.dialog.get("id", "missing")))
		game.interact()
	for house in GameState.map.town.houses:
		await _walk_to(GameState.cell(house.door))
		_check(GameState.session.location == "house" and GameState.session.house_id == house.id, "Enter " + house.id)
		_check(_same_party(), "Party persists inside " + house.id)
		await _capture("house" if house.id == GameState.map.town.houses.front().id else ("interior_" + house.id if house.id != GameState.rules.test.services.weapon_house else ""))
		await _walk_to(GameState.cell(GameState.map.house.portals.front().cell))
		_check(GameState.session.location == "town", "Exit " + house.id)
		for hero in GameState.session.heroes:
			_check(game.world.can_walk(hero.cell), "Safe exit formation: " + house.id + " / " + hero.id)
	game.paused = true
	_check(not await game.request_step(Vector2i.RIGHT), "Pause blocks movement")
	game.paused = false
	await _walk_to(GameState.cell(GameState.rules.test.square_view))
	await _capture("square")
	game.hud.map_open = true
	_check(not await game.request_step(Vector2i.RIGHT), "Map blocks movement")
	await _capture("map")
	game.hud.map_open = false
	_check(_same_party(), "Party instances preserved across all fourteen transitions")
	var services = preload("res://tests/services.gd").new()
	await services.run(self)
	var combat = preload("res://tests/combat.gd").new()
	await combat.run(self)
	var polish = preload("res://tests/finalization.gd").new()
	await polish.before_rescue(self)
	var dungeon = preload("res://tests/dungeon.gd").new()
	await dungeon.run(self)
	await polish.after_rescue()
	print("ACCEPTANCE: " + str(checks - failures.size()) + "/" + str(checks) + " passed")
	if failures.is_empty():
		get_tree().quit(int(GameState.rules.n.zero))
	else:
		get_tree().quit(int(GameState.rules.n.one))

func _keyboard_check() -> void:
	var start := GameState.leader()
	game.testing = false
	game.last_action = "east"
	Input.action_press("north")
	Input.action_press("east")
	for frame in range(int(GameState.rules.test.input_frames)):
		await get_tree().physics_frame
		if game.moving:
			break
	Input.action_release("north")
	Input.action_release("east")
	while game.moving:
		await get_tree().process_frame
	game.testing = true
	_check(GameState.leader() == start + Vector2i.RIGHT, "Held simultaneous inputs produce exactly one orthogonal step")
	for index in game.actors.size():
		_check(game.actors[index].position.distance_to(GameState.ground(GameState.session.heroes[index].cell)) < GameState.rules.test.position_tolerance, "Rendered hero finishes on its authoritative trail: " + GameState.session.heroes[index].id)

func _same_party() -> bool:
	if not is_same(original_heroes, GameState.session.heroes):
		return false
	for index in game.actors.size():
		if game.actors[index].get_instance_id() != original_ids[index]:
			return false
	return true

func _walk_to(goal: Vector2i) -> void:
	var start := GameState.leader()
	var frontier: Array[Vector2i] = [start]
	var parents: Dictionary = {start:start}
	while not frontier.is_empty() and not parents.has(goal):
		var current: Vector2i = frontier.pop_front()
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if parents.has(next) or not game.world.can_walk(next):
				continue
			if not game.world.portal_at(next).is_empty() and next != goal:
				continue
			parents[next] = current
			frontier.append(next)
	if not parents.has(goal):
		_check(false, "Unreachable destination: " + str(goal))
		return
	var path: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		path.append(cursor)
		cursor = parents[cursor]
	path.reverse()
	for destination in path:
		var old_cells: Array[Vector2i] = []
		for hero in GameState.session.heroes:
			old_cells.append(hero.cell)
		var old_location: String = GameState.session.location
		var accepted: bool = await game.request_step(destination - GameState.leader())
		if not accepted:
			_check(false, "Production controller rejected route step: " + str(destination))
			return
		if GameState.session.location == old_location:
			var index := int(GameState.rules.n.one)
			while index < GameState.session.heroes.size():
				if GameState.session.heroes[index].cell != old_cells[index - int(GameState.rules.n.one)]:
					_check(false, "Follower deviated from the previous hero's exact trail")
					return
				index += int(GameState.rules.n.one)
			for hero in GameState.session.heroes:
				if not game.world.can_walk(hero.cell) and not game.world.portals.has(hero.cell):
					_check(false, "A follower entered an obstacle")
					return

func _capture(label: String) -> void:
	if not screenshots or label.is_empty():
		return
	await get_tree().create_timer(GameState.rules.test.capture_wait).timeout
	game._snap_camera()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://docs/" + label + ".png")
	_check(error == OK, "Screenshot: " + label)

