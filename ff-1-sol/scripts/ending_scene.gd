extends Node3D
## An uninterrupted, once-per-story bridge construction scene.
var game
var backdrop
var camera: Camera3D
var ui
var workers: Array[Node3D] = []
var phase := "opening"
var stage := int(GameState.rules.n.zero)
var elapsed: float = GameState.rules.n.zero
var built_segments := int(GameState.rules.n.zero)
var v = preload("res://scripts/visuals.gd").new()

func _ready() -> void:
	var cfg: Dictionary = GameState.polish.ending
	backdrop = preload("res://scenes/town.tscn").instantiate()
	add_child(backdrop)
	for node in backdrop.get_children():
		if node is Label3D:
			node.hide()
	backdrop.bridge_root.hide()
	v.assembly(self, cfg.work_parts)
	v.assembly(self, cfg.stack_parts)
	for index in cfg.worker_starts.size():
		var worker: Node3D = v.actor(self, {"id":"worker_" + str(index), "appearance":"worker"})
		worker.position = GameState.vec(cfg.worker_starts[index])
		worker.scale = Vector3.ONE * cfg.worker_scale
		var tool := Node3D.new()
		tool.name = "Hammer"
		tool.position = GameState.vec(cfg.tool_origin)
		worker.add_child(tool)
		v.assembly(tool, cfg.hammer_parts)
		workers.append(worker)
	for index in game.actors.size():
		game.actors[index].position = GameState.vec(cfg.hero_positions[index])
		game.actors[index].rotation = Vector3.ZERO
		game.actors[index].rotation_degrees.y = cfg.hero_rotation
		game.actors[index].scale = Vector3.ONE
		v.fallen(game.actors[index], GameState.session.heroes[index].hp <= GameState.rules.n.zero)
	var sarah: Node3D = v.actor(self, GameState.dungeon.sarah)
	sarah.position = GameState.vec(cfg.sarah_position)
	sarah.rotation_degrees.y = cfg.hero_rotation
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cfg.camera_size
	camera.position = GameState.vec(cfg.camera_position)
	add_child(camera)
	camera.look_at(GameState.vec(cfg.camera_target), Vector3.UP)
	camera.make_current()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = preload("res://scripts/ending_hud.gd").new()
	ui.hud = game.hud
	ui.controller = self
	canvas.add_child(ui)
	_run.call_deferred()

func _seconds(value: float) -> float:
	if not game.testing:
		return value
	return GameState.polish.ending.preview_seconds if OS.get_cmdline_user_args().has("--screenshots") else GameState.polish.ending.test_seconds

func _run() -> void:
	var cfg: Dictionary = GameState.polish.ending
	await get_tree().create_timer(_seconds(cfg.opening_seconds)).timeout
	phase = "workers"
	stage = int(GameState.rules.n.one)
	var arrival := create_tween().set_parallel(true)
	for index in workers.size():
		var offset: Vector3 = GameState.vec(cfg.worker_targets[index]) - workers[index].position
		workers[index].rotation.y = atan2(offset.x, offset.z)
		arrival.tween_property(workers[index], "position", GameState.vec(cfg.worker_targets[index]), _seconds(cfg.step_seconds))
	await arrival.finished
	phase = "building"
	for z in cfg.segments:
		var slab := v.shape(self, "box", GameState.vec(cfg.segment_size), Vector3(cfg.bridge_x, cfg.segment_start_y, z), cfg.segment_color)
		var lift := create_tween()
		lift.tween_property(slab, "position:y", cfg.segment_final_y, _seconds(cfg.step_seconds))
		await lift.finished
		built_segments += int(GameState.rules.n.one)
	phase = "finishing"
	stage = int(GameState.rules.n.two)
	backdrop.build_bridge(true)
	var pan := create_tween()
	pan.tween_property(camera, "position", GameState.vec(cfg.camera_end_position), _seconds(cfg.hold_seconds))
	await pan.finished
	await get_tree().create_timer(_seconds(cfg.hold_seconds)).timeout
	GameState.session.quest.bridge_built = true
	GameState.session.quest.demo_complete = true
	phase = "complete"
	ui.show_complete()

func _process(delta: float) -> void:
	elapsed += delta
	var cfg: Dictionary = GameState.polish.ending
	if is_instance_valid(camera):
		camera.look_at(GameState.vec(cfg.camera_target), Vector3.UP)
	for worker in workers:
		var angle: float = sin(elapsed * cfg.hammer_speed) * cfg.hammer_angle if phase == "building" else GameState.rules.n.zero
		worker.get_node("RightArm").rotation.x = angle
		worker.get_node("Hammer").rotation.x = angle
		var step: float = sin(elapsed * cfg.hammer_speed) * cfg.walk_angle if phase == "workers" else GameState.rules.n.zero
		worker.get_node("LeftLeg").rotation.x = step
		worker.get_node("RightLeg").rotation.x = -step
	if is_instance_valid(ui):
		ui.queue_redraw()

func handle_event(event: InputEvent) -> void:
	if phase == "complete" and event.is_action_pressed("talk"):
		finish()

func finish() -> void:
	if phase == "complete":
		game.finish_ending()
