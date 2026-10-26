extends Node3D

signal scene_advanced

const WorldScript = preload("res://scripts/world.gd")
const PartyScript = preload("res://scripts/party.gd")
const HudScript = preload("res://scripts/hud.gd")
const VisualsScript = preload("res://scripts/props.gd")
const ServicesScript = preload("res://scripts/services.gd")
const BattleScene = preload("res://scenes/battle.tscn")

var data: Dictionary
var math: Dictionary
var visuals
var world
var party
var hud
var services
var battle
var camera: Camera3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var transitioning: bool = false
var scene_active: bool = false
var camera_focus: Variant = null
var active_npc: Dictionary = {}
var encounter_id: String = ""
var encounter_rng := RandomNumberGenerator.new()


func _ready() -> void:
	var file := FileAccess.open("res://data/game.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open game data: " + str(FileAccess.get_open_error()))
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Game data must be a valid JSON object.")
		return
	data = parsed
	math = data.settings.math
	_configure_input()
	visuals = VisualsScript.new(data)
	encounter_rng.seed = int(data.battle.random_seed)
	_build_environment()
	party = PartyScript.new(data, visuals)
	add_child(party)
	party.portal_requested.connect(_on_portal)
	party.step_completed.connect(_on_party_step)
	hud = HudScript.new(data)
	add_child(hud)
	services = ServicesScript.new(data)
	add_child(services)
	camera = Camera3D.new()
	camera.name = "LeaderCamera"
	camera.fov = float(data.settings.camera.field_of_view)
	camera.near = float(data.settings.camera.near)
	camera.far = float(data.settings.camera.far)
	add_child(camera)
	camera.current = true
	_load_location(str(party.state.location))
	_snap_camera()
	hud.show_location(world.location)
	hud.refresh(world, party)


func _configure_input() -> void:
	for action in data.controls:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key_name in data.controls[action]:
			var event := InputEventKey.new()
			event.physical_keycode = OS.find_keycode_from_string(str(key_name))
			event.keycode = event.physical_keycode
			InputMap.action_add_event(action, event)


func _build_environment() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color.html(str(data.settings.environment.sky_top))
	sky_material.sky_horizon_color = Color.html(str(data.settings.environment.sky_horizon))
	sky_material.ground_bottom_color = Color.html(str(data.settings.environment.ground))
	sky_material.ground_horizon_color = Color.html(str(data.settings.environment.sky_horizon))
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.html(str(data.settings.environment.ambient))
	environment.ambient_light_energy = float(data.settings.lighting.ambient_energy)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = float(data.settings.lighting.tonemap_exposure)
	environment.fog_enabled = true
	environment.fog_light_color = Color.html(str(data.settings.environment.fog))
	environment.fog_density = float(data.settings.lighting.fog_density)
	environment.fog_sky_affect = float(data.settings.lighting.fog_sky_affect)
	world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = visuals.vector(data.settings.lighting.sun_rotation)
	sun.light_color = Color.html(str(data.settings.environment.sun))
	sun.light_energy = float(data.settings.lighting.sun_energy)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float(data.settings.lighting.shadow_distance)
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = visuals.vector(data.settings.lighting.fill_rotation)
	fill.light_color = Color.html(str(data.settings.environment.fill))
	fill.light_energy = float(data.settings.lighting.fill_energy)
	add_child(fill)


func _load_location(location_id: String) -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = WorldScript.new(data, location_id, visuals, party.state.flags)
	add_child(world)
	var indoors: bool = not bool(world.location.get("outdoor", world.location.kind == "town"))
	var lighting: Dictionary = data.settings.lighting
	var atmosphere: Dictionary = data.settings.atmospheres.get(str(world.location.get("atmosphere", "")), {})
	var environment: Environment = world_environment.environment
	environment.background_mode = Environment.BG_COLOR if indoors else Environment.BG_SKY
	environment.background_color = Color.html(str(atmosphere.get("background", data.settings.environment.interior_background)))
	environment.fog_enabled = not indoors
	environment.ambient_light_color = Color.html(str(atmosphere.get("ambient", data.settings.environment.ambient)))
	environment.ambient_light_energy = float(atmosphere.get("ambient_energy", lighting.ambient_energy))
	sun.light_energy = float(atmosphere.get("sun_energy", lighting.sun_energy))
	fill.light_energy = float(atmosphere.get("fill_energy", lighting.fill_energy))


func _camera_target() -> Vector3:
	if camera_focus is Vector3:
		return camera_focus + visuals.vector(data.settings.camera.focus_offset)
	return party.leader_position() + Vector3.UP * float(data.settings.geometry.character.body_y) + visuals.vector(data.settings.camera.focus_offset)


func _snap_camera() -> void:
	var target: Vector3 = _camera_target()
	camera.position = target + visuals.vector(data.settings.camera.offset)
	camera.look_at(target, Vector3.UP)


func _process(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(party) or is_instance_valid(battle):
		return
	var target: Vector3 = _camera_target()
	var speed: float = float(data.settings.camera.follow_speed)
	var weight: float = float(math.one) - exp(-speed * delta)
	var desired: Vector3 = target + visuals.vector(data.settings.camera.offset)
	camera.position = camera.position.lerp(desired, weight)
	camera.look_at(target, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(party) or transitioning or is_instance_valid(battle):
		return
	party.tick(delta, world, not hud.dialogue_open() and not services.is_open())
	hud.refresh(world, party)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(party) or transitioning or is_instance_valid(battle):
		return
	if scene_active:
		if (hud.dialogue_open() or hud.end_card_open()) and (event.is_action_pressed("interact") or event.is_action_pressed("cancel")):
			hud.close_dialogue()
			hud.hide_end_card()
			get_viewport().set_input_as_handled()
			scene_advanced.emit()
		return
	if services.is_open():
		if event.is_action_pressed("inventory") or (event.is_action_pressed("cancel") and not services.back()):
			services.close()
			party.refresh_spirits()
			hud.refresh(world, party)
		if event.is_action_pressed("inventory") or event.is_action_pressed("cancel"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel") and hud.dialogue_open():
		hud.close_dialogue()
		active_npc = {}
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and party.is_idle() and not hud.dialogue_open():
		services.open_inventory(party)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if hud.dialogue_open():
			hud.close_dialogue()
			var challenger: Dictionary = active_npc
			active_npc = {}
			if challenger.has("battle"):
				_start_battle(str(challenger.battle))
		elif party.is_idle():
			var npc: Dictionary = world.nearest_npc(party.leader_cell())
			var service: Dictionary = world.nearest_service(party.leader_cell())
			var prop: Dictionary = world.nearest_prop(party.leader_cell())
			if not npc.is_empty():
				_talk(npc)
			elif not service.is_empty():
				services.open_service(world.location, party)
			elif not prop.is_empty():
				_use_prop(prop)
		get_viewport().set_input_as_handled()


func _talk(npc: Dictionary) -> void:
	active_npc = npc
	world.face_npc(npc, party.leader_cell())
	var line: String = str(npc.line)
	for variant in npc.get("lines", []):
		if party.flag(str(variant.flag)):
			line = str(variant.line)
			break
	hud.show_dialogue({"name": npc.name, "line": line}, "talk_eyebrow", "battle_hint" if npc.has("battle") else "close_hint")
	if npc.has("sets"):
		party.set_flag(str(npc.sets))
		hud.update_objective(party.state.flags)


func _use_prop(prop: Dictionary) -> void:
	var text: Dictionary = data.dialogue
	if str(prop.type) == "chest":
		party.set_flag(str(prop.flag))
		party.add_item(str(prop.item), int(math.one))
		world.open_prop(prop)
		hud.show_dialogue({"name": prop.name, "line": str(text.chest_found) % str(party.item(str(prop.item)).name)}, "found_eyebrow")
	elif party.item_count(str(prop.key)) > int(math.zero):
		party.set_flag(str(prop.flag))
		party.add_item(str(prop.key), -int(math.one))
		world.open_prop(prop)
		hud.show_dialogue({"name": prop.name, "line": str(text.door_opened) % str(party.item(str(prop.key)).name)}, "notice_eyebrow")
	else:
		hud.show_dialogue({"name": prop.name, "line": str(text.door_locked)}, "notice_eyebrow")


func _on_portal(door: Dictionary) -> void:
	if transitioning:
		return
	transitioning = true
	party.set_locked(true)
	hud.close_dialogue()
	hud.prompt.hide()
	active_npc = {}
	_transition(door)


func _travel(destination: String, arrival: Vector2i, facing: Vector2i) -> void:
	await hud.fade_to(float(math.one), float(data.settings.fade_duration)).finished
	party.relocate(destination, arrival, facing)
	_load_location(destination)
	_snap_camera()
	hud.show_location(world.location)
	await hud.fade_to(float(math.zero), float(data.settings.fade_duration)).finished


func _transition(door: Dictionary) -> void:
	await _travel(str(door.destination), visuals.cell(door.arrival), visuals.cell(door.direction))
	transitioning = false
	party.set_locked(false)
	hud.refresh(world, party)


func _on_party_step(cell: Vector2i) -> void:
	if is_instance_valid(battle) or scene_active:
		return
	var id: String = world.encounter_at(cell)
	if id.is_empty():
		return
	if encounter_rng.randf() < float(data.battle.encounters[id].chance):
		_start_battle(id)


func _start_battle(id: String) -> void:
	encounter_id = id
	var encounter: Dictionary = data.battle.encounters[id]
	party.set_locked(true)
	services.close()
	hud.close_dialogue()
	hud.root.hide()
	world.hide()
	party.hide()
	active_npc = {}
	battle = BattleScene.instantiate()
	battle.data = data
	battle.visuals = visuals
	battle.party = party
	battle.encounter = encounter
	battle.group = encounter.groups[encounter_rng.randi_range(int(math.zero), encounter.groups.size() - int(math.one))]
	add_child(battle)
	battle.finished.connect(_on_battle_finished)


func _on_battle_finished(result: String) -> void:
	var encounter: Dictionary = data.battle.encounters[encounter_id]
	if result == "defeat":
		party.restore_checkpoint()
		_load_location(str(party.state.location))
	elif result == "victory" and encounter.has("victory_flag"):
		party.set_flag(str(encounter.victory_flag))
		_load_location(str(party.state.location))
	hud.update_objective(party.state.flags)
	remove_child(battle)
	battle.queue_free()
	battle = null
	world.show()
	party.show()
	party.refresh_spirits()
	hud.root.show()
	camera.current = true
	_snap_camera()
	hud.set_location(world.location)
	hud.refresh(world, party)
	if result == "victory" and encounter.has("victory_scene"):
		_play_scene(str(encounter.victory_scene))
	else:
		party.set_locked(false)


func _play_scene(scene_id: String) -> void:
	scene_active = true
	party.set_locked(true)
	hud.prompt.hide()
	for step in data.scenes[scene_id]:
		match str(step.type):
			"move":
				await world.move_npc(str(step.npc), visuals.cell(step.to), float(step.duration), party.leader_cell()).finished
			"line":
				hud.show_dialogue(step, "talk_eyebrow", "scene_hint")
				await scene_advanced
			"flag":
				party.set_flag(str(step.flag))
				hud.update_objective(party.state.flags)
			"travel":
				await _travel(str(step.destination), visuals.cell(step.arrival), visuals.cell(step.direction))
			"checkpoint":
				party.checkpoint = party.make_checkpoint(str(party.state.location), party.leader_cell(), party.state.facing)
			"formation":
				party.formation(step.cells.map(func(point: Array) -> Vector2i: return visuals.cell(point)), visuals.cell(step.direction))
			"camera":
				camera_focus = visuals.vector(step.target) if step.has("target") else null
			"build":
				await world.build_bridge()
			"end_card":
				hud.show_end_card()
				await scene_advanced
	scene_active = false
	party.set_locked(false)
	hud.refresh(world, party)
