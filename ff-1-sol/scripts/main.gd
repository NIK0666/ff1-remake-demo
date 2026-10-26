extends Node3D
## Persistent scene shell: Party, camera and HUD survive every location swap.

signal location_changed

var world
var party: Node3D
var actors: Array[Node3D] = []
var camera: Camera3D
var hud
var v = preload("res://scripts/visuals.gd").new()
var moving := false
var transitioning := false
var paused := false
var testing := false
var elapsed: float
var last_action := "north"
var zoom: float
var battle_scene
var story_busy := false
var story_lines: Array = []
var story_completion := ""
var sun: DirectionalLight3D
var environment: Environment
var ending_scene

func _ready() -> void:
	testing = OS.get_cmdline_user_args().has("--self-test")
	elapsed = GameState.rules.n.zero
	_bind_inputs()
	_setup_light()
	party = Node3D.new()
	party.name = "PersistentParty"
	add_child(party)
	for hero in GameState.session.heroes:
		actors.append(v.actor(party, hero))
	camera = Camera3D.new()
	camera.name = "LeaderCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = GameState.rules.camera.near
	camera.far = GameState.rules.camera.far
	add_child(camera)
	camera.make_current()
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	canvas.add_child(hud)
	_load_location("town", GameState.cell(GameState.map.town.spawn))
	if testing:
		var verifier = preload("res://tests/acceptance.gd").new()
		add_child(verifier)
		verifier.call_deferred("run", self)
	elif OS.get_cmdline_user_args().has("--capture"):
		_capture_preview.call_deferred()

func _bind_inputs() -> void:
	var bindings := {
		"north":[KEY_W, KEY_UP], "south":[KEY_S, KEY_DOWN],
		"west":[KEY_A, KEY_LEFT], "east":[KEY_D, KEY_RIGHT],
		"talk":[KEY_E, KEY_ENTER, KEY_SPACE], "map":[KEY_M, KEY_TAB],
		"inventory":[KEY_I],
		"equipment":[KEY_C],
		"pause":[KEY_ESCAPE], "fullscreen":[KEY_F11]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _setup_light() -> void:
	var settings: Dictionary = GameState.rules.environment
	var light := DirectionalLight3D.new()
	sun = light
	light.rotation_degrees = GameState.vec(settings.sun_rotation)
	light.light_color = Color(settings.sun_color)
	light.light_energy = settings.sun_energy
	light.shadow_enabled = true
	light.shadow_opacity = settings.shadow_opacity
	add_child(light)
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	environment = sky.environment
	sky.environment.background_mode = Environment.BG_COLOR
	sky.environment.background_color = Color(settings.background)
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color = Color(settings.ambient_color)
	sky.environment.ambient_light_energy = settings.ambient_energy
	add_child(sky)

func _load_location(id: String, spawn: Vector2i, house: String = "", facing: Vector2i = Vector2i.UP) -> void:
	hud.service.close()
	hud.gear.close()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	GameState.session.location = id
	if not house.is_empty():
		GameState.session.house_id = house
	var packed: PackedScene = load("res://scenes/" + id + ".tscn")
	world = packed.instantiate()
	world.house_id = GameState.session.house_id
	add_child(world)
	apply_lighting(id)
	GameState.arrange(spawn, facing)
	for index in actors.size():
		actors[index].position = GameState.ground(GameState.session.heroes[index].cell)
		actors[index].rotation.y = atan2(float(facing.x), float(facing.y))
		actors[index].rotation.z = GameState.rules.n.zero
		actors[index].rotation.x = GameState.rules.n.zero
		v.fallen(actors[index], GameState.session.heroes[index].hp <= GameState.rules.n.zero)
	zoom = GameState.rules.camera.size if id == "town" else GameState.rules.camera.interior_size
	camera.size = zoom
	_snap_camera()
	if id == "throne" and GameState.session.bridge_reached:
		GameState.session.returned_to_throne = true
	location_changed.emit()

func change_location(portal: Dictionary) -> void:
	transitioning = true
	var duration: float = GameState.rules.test.fade_seconds if testing else GameState.rules.movement.fade_seconds
	var fade := create_tween()
	fade.tween_property(hud, "fade", GameState.rules.n.one, duration)
	await fade.finished
	var spawn: Vector2i
	var facing := Vector2i.UP
	if portal.has("spawn"):
		spawn = GameState.cell(portal.spawn)
		if portal.has("facing"):
			facing = GameState.cell(portal.facing)
	else:
		for house in GameState.map.town.houses:
			if house.id == GameState.session.house_id:
				spawn = GameState.cell(house.door) + Vector2i.DOWN
				facing = Vector2i.RIGHT if house.return_facing == "east" else Vector2i.LEFT
	_load_location(portal.to, spawn, portal.get("house_id", ""), facing)
	var reveal := create_tween()
	reveal.tween_property(hud, "fade", GameState.rules.n.zero, duration)
	await reveal.finished
	transitioning = false

func request_step(direction: Vector2i) -> bool:
	if moving or transitioning or story_busy or paused or hud.dialog_open or hud.map_open or hud.service.visible or hud.gear.visible or GameState.in_battle():
		return false
	if absi(direction.x) + absi(direction.y) != int(GameState.rules.n.one):
		return false
	GameState.session.facing = direction
	GameState.session.heroes.front().facing = direction
	var target := GameState.leader() + direction
	if not world.can_walk(target):
		return false
	moving = true
	GameState.advance(target, direction)
	var duration: float = GameState.rules.test.step_seconds if testing else GameState.rules.movement.step_seconds
	var tween := create_tween().set_parallel(true)
	for index in actors.size():
		tween.tween_property(actors[index], "position", GameState.ground(GameState.session.heroes[index].cell), duration)
	await tween.finished
	moving = false
	if GameState.session.location == "town" and GameState.inside(target, GameState.map.town.bridge_arrival):
		GameState.session.bridge_reached = true
	var portal: Dictionary = world.portal_at(target)
	if not portal.is_empty():
		await change_location(portal)
	elif world.boss_at(target):
		show_story([GameState.dungeon.boss], "boss")
	elif GameState.battle_system.encounter(target):
		start_battle()
	return true

func _physics_process(_delta: float) -> void:
	if testing or moving or transitioning or story_busy or paused or hud.dialog_open or hud.map_open or hud.service.visible or hud.gear.visible or GameState.in_battle():
		return
	# The most recently pressed held direction wins. Diagonal steps never exist.
	for action in ["north", "south", "west", "east"]:
		if Input.is_action_just_pressed(action):
			last_action = action
	var directions := {"north":Vector2i.UP,"south":Vector2i.DOWN,"west":Vector2i.LEFT,"east":Vector2i.RIGHT}
	if Input.is_action_pressed(last_action):
		request_step(directions[last_action])
		return
	for action in directions:
		if Input.is_action_pressed(action):
			last_action = action
			request_step(directions[action])
			return

func _process(delta: float) -> void:
	elapsed += delta
	if GameState.in_battle() or is_instance_valid(ending_scene):
		return
	if camera == null or actors.is_empty():
		return
	var target: Vector3 = actors.front().position + GameState.vec(GameState.rules.camera.target_offset)
	var weight: float = minf(GameState.rules.n.one, delta * GameState.rules.camera.follow_speed)
	camera.position = camera.position.lerp(target + GameState.vec(GameState.rules.camera.offset), weight)
	camera.look_at(camera.position - GameState.vec(GameState.rules.camera.offset), Vector3.UP)
	camera.size = lerpf(camera.size, zoom, weight)
	for index in actors.size():
		var actor := actors[index]
		var dead: bool = GameState.session.heroes[index].hp <= GameState.rules.n.zero
		v.fallen(actor, dead)
		var facing: Vector2i = GameState.session.heroes[index].facing
		var heading := atan2(float(facing.x), float(facing.y))
		actor.rotation.y = lerp_angle(actor.rotation.y, heading, minf(GameState.rules.n.one, delta * GameState.rules.movement.turn_speed))
		var swing: float = sin(elapsed * GameState.rules.movement.bob_speed) * GameState.rules.movement.limb_swing if moving and not dead else GameState.rules.n.zero
		actor.get_node("LeftLeg").rotation.x = swing
		actor.get_node("RightLeg").rotation.x = -swing
		actor.get_node("LeftArm").rotation.x = -swing
		actor.get_node("RightArm").rotation.x = swing
	hud.queue_redraw()

func apply_lighting(location: String) -> void:
	var key := "dungeon" if location.begins_with("chaos_") else location
	var settings: Dictionary = GameState.polish.lighting[key]
	sun.light_energy = settings.sun
	environment.ambient_light_energy = settings.ambient
	environment.background_color = Color(settings.background)

func _snap_camera() -> void:
	var target: Vector3 = actors.front().position + GameState.vec(GameState.rules.camera.target_offset)
	camera.position = target + GameState.vec(GameState.rules.camera.offset)
	camera.look_at(target, Vector3.UP)

func interact() -> void:
	if moving or transitioning or story_busy or paused or hud.map_open or GameState.in_battle():
		return
	if hud.gear.visible:
		hud.gear.activate()
		return
	if hud.service.visible:
		hud.service.activate()
		return
	if hud.dialog_open:
		advance_story()
		return
	if not GameState.current_service().is_empty():
		hud.service.open_service()
		return
	var action: Dictionary = world.action_near(GameState.leader(), GameState.session.facing)
	if not action.is_empty():
		var result: Dictionary = GameState.open_chaos_chest() if action.kind == "chest" else GameState.unlock_chaos_door()
		world.refresh_progress()
		action.text = result.message
		hud.dialog = action
		hud.dialog_open = true
		return
	var npc: Dictionary = world.npc_near(GameState.leader(), GameState.session.facing)
	if not npc.is_empty():
		if npc.id == "garland":
			show_story([npc], "boss")
			return
		hud.dialog = npc
		hud.dialog_open = true
		if npc.id == "king":
			GameState.session.king_spoken = true
			if GameState.session.quest.sarah_rescued:
				GameState.session.quest.king_thanked = true
				if not GameState.session.quest.demo_complete:
					story_completion = "ending"

func show_story(lines: Array, completion: String) -> void:
	story_lines = lines.duplicate(true)
	story_completion = completion
	hud.dialog = story_lines.pop_front()
	hud.dialog_open = true

func advance_story() -> void:
	if not story_lines.is_empty():
		hud.dialog = story_lines.pop_front()
		return
	hud.dialog_open = false
	var completion := story_completion
	story_completion = ""
	if completion == "boss":
		start_battle(GameState.dungeon.boss.formation, "garland")
	elif completion == "rescue":
		GameState.session.quest.sarah_rescued = true
		hud.queue_redraw()
	elif completion == "ending":
		start_ending()

func start_ending() -> void:
	if is_instance_valid(ending_scene) or GameState.session.location != "throne" or not GameState.session.quest.sarah_rescued or not GameState.session.quest.king_thanked or GameState.session.quest.demo_complete:
		return
	story_busy = true
	hud.dialog_open = false
	hud.service.close()
	hud.gear.close()
	hud.hide()
	world.hide()
	apply_lighting("town")
	ending_scene = preload("res://scenes/ending.tscn").instantiate()
	ending_scene.game = self
	add_child(ending_scene)

func finish_ending() -> void:
	if not is_instance_valid(ending_scene) or not GameState.session.quest.demo_complete:
		return
	remove_child(ending_scene)
	ending_scene.queue_free()
	ending_scene = null
	story_busy = false
	for index in actors.size():
		actors[index].position = GameState.ground(GameState.session.heroes[index].cell)
		actors[index].rotation = Vector3.ZERO
		v.fallen(actors[index], GameState.session.heroes[index].hp <= GameState.rules.n.zero)
	world.show()
	hud.show()
	apply_lighting(GameState.session.location)
	camera.make_current()
	_snap_camera()

func play_rescue() -> void:
	story_busy = true
	await world.release_sarah()
	story_busy = false
	show_story(GameState.dungeon.story.rescue, "rescue")

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(ending_scene) and not event.is_action_pressed("fullscreen"):
		ending_scene.handle_event(event)
		return
	if GameState.in_battle() and not event.is_action_pressed("fullscreen"):
		if is_instance_valid(battle_scene):
			battle_scene.handle_event(event)
		return
	if (story_busy or not story_completion.is_empty()) and not event.is_action_pressed("fullscreen"):
		if not story_busy and event.is_action_pressed("talk"):
			advance_story()
		return
	if hud.gear.visible and not event.is_action_pressed("fullscreen"):
		hud.gear.handle_event(event)
		return
	if hud.service.visible and not event.is_action_pressed("fullscreen"):
		if event.is_action_pressed("equipment"):
			hud.service.close()
			hud.gear.open_equipment()
		else:
			hud.service.handle_event(event)
		return
	for action in ["north", "south", "west", "east"]:
		if event.is_action_pressed(action):
			last_action = action
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("pause"):
		if hud.dialog_open:
			hud.dialog_open = false
		elif hud.map_open:
			hud.map_open = false
		else:
			paused = not paused
	elif event.is_action_pressed("talk"):
		interact()
	elif event.is_action_pressed("inventory") and not moving and not transitioning and not paused and not hud.dialog_open and not hud.map_open:
		hud.service.open_inventory()
	elif event.is_action_pressed("equipment") and not moving and not transitioning and not paused and not hud.dialog_open and not hud.map_open:
		hud.gear.open_equipment()
	elif event.is_action_pressed("map") and not transitioning and not hud.dialog_open and not paused:
		hud.map_open = not hud.map_open
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(GameState.rules.camera.min_size, zoom - GameState.rules.camera.zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(GameState.rules.camera.max_size, zoom + GameState.rules.camera.zoom_step)

func location_title() -> String:
	if GameState.session.location == "house":
		for house in GameState.map.town.houses:
			if house.id == GameState.session.house_id:
				return house.title
	return GameState.map[GameState.session.location].title

func _capture_preview() -> void:
	await get_tree().create_timer(GameState.rules.test.capture_wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/cornelia.png")
	get_tree().quit()

func start_battle(formation: Array = [], kind: String = "") -> void:
	if GameState.in_battle() or is_instance_valid(ending_scene) or story_busy:
		return
	hud.service.close()
	hud.gear.close()
	hud.map_open = false
	GameState.battle_system.start(formation, kind)
	world.hide()
	hud.hide()
	battle_scene = preload("res://scenes/battle.tscn").instantiate()
	battle_scene.game = self
	add_child(battle_scene)

func return_from_battle() -> void:
	if not GameState.in_battle() or GameState.session.battle.phase != "result":
		return
	var outcome: String = GameState.session.battle.result
	var defeated_garland: bool = outcome == "victory" and GameState.session.battle.kind == "garland"
	GameState.session.battle.active = false
	GameState.session.encounter_cooldown = int(GameState.dungeon.encounters.grace_steps if GameState.session.location.begins_with("chaos_") else GameState.combat.encounters.grace_steps)
	if is_instance_valid(battle_scene):
		remove_child(battle_scene)
		battle_scene.queue_free()
		battle_scene = null
	for actor in actors:
		actor.scale = Vector3.ONE
		actor.rotation.z = GameState.rules.n.zero
		actor.rotation.x = GameState.rules.n.zero
		actor.show()
	if outcome == "defeat":
		var checkpoint := GameState.restore_checkpoint()
		_load_location("town", checkpoint.spawn, "", checkpoint.facing)
	else:
		for index in actors.size():
			actors[index].position = GameState.ground(GameState.session.heroes[index].cell)
			var facing: Vector2i = GameState.session.heroes[index].facing
			actors[index].rotation.y = atan2(float(facing.x), float(facing.y))
		world.show()
		_snap_camera()
	hud.show()
	camera.make_current()
	if defeated_garland:
		GameState.session.quest.garland_defeated = true
		story_busy = true
		world.refresh_progress()
		play_rescue.call_deferred()
