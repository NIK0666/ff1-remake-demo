class_name DemoEnding
extends Node3D
## Closing cinematic: royal workers finish the northern bridge. No exploration
## input is accepted; the finale ends with the demo-complete title card.

const GOLD := Color("#d5b16b")
const GOLD_BRIGHT := Color("#f0d89b")
const IVORY := Color("#eee6d6")
const MUTED := Color("#aeb5b2")

var _camera: Camera3D
var _workers: Array[CharacterVisual] = []
var _slab: Node3D
var _gap_dust: CPUParticles3D
var _time: float = 0.0
var _working: bool = true
var _camera_target := Vector3(0.0, 1.35, 0.4)
var _camera_tween: Tween

var _font_body: SystemFont
var _font_bold: SystemFont
var _ui_root: Control
var _caption_panel: PanelContainer
var _caption_label: Label
var _caption_tween: Tween
var _letter_top: ColorRect
var _letter_bottom: ColorRect
var _fade: ColorRect
var _final_root: Control
var _final_title: Label
var _final_subtitle: Label
var _final_hint: Label
var _final_visible: bool = false
var _finished: bool = false


func _ready() -> void:
	_time = 0.0
	_make_fonts()
	_build_environment()
	_build_bridge()
	_build_workers()
	_build_camera()
	_build_ui()
	_run_cutscene()


func _process(delta: float) -> void:
	_time += delta
	for i in _workers.size():
		var worker: CharacterVisual = _workers[i]
		if _working:
			var swing := sin(_time * 9.0 + float(i) * 1.7) * 0.72 - 0.1
			worker.arm_r.rotation.x = swing
			worker.arm_l.rotation.x = -swing * 0.35
		else:
			worker.arm_r.rotation.x = lerp(worker.arm_r.rotation.x, -2.2, 1.0 - exp(-6.0 * delta))
			worker.arm_l.rotation.x = lerp(worker.arm_l.rotation.x, -1.4, 1.0 - exp(-6.0 * delta))
	if _camera != null:
		_camera.look_at(_camera_target, Vector3.UP)


# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

func _make_fonts() -> void:
	_font_body = SystemFont.new()
	_font_body.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "Noto Serif"])
	_font_body.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_font_body.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font_body.font_names
	_font_bold.font_weight = 700
	_font_bold.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_font_bold.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO


func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#486ca0")
	sky_mat.sky_horizon_color = Color("#e3b57f")
	sky_mat.ground_horizon_color = Color("#7c815f")
	sky_mat.ground_bottom_color = Color("#42545a")
	sky_mat.sun_angle_max = 24.0
	sky_mat.sun_curve = 0.16
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c5c7c4")
	env.ambient_light_energy = 0.56
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color("#c1ad96")
	env.fog_density = 0.005
	env.fog_sky_affect = 0.3
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "EndingSun"
	sun.light_color = Color("#ffd6a0")
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-44.0, -128.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	add_child(sun)


func _build_bridge() -> void:
	var cobble := _shader_material("res://shaders/cobblestone.gdshader")
	var water := _shader_material("res://shaders/water.gdshader", {
		"shallow_color": Color("#477a80"),
		"deep_color": Color("#1a3848"),
		"foam_color": Color("#d3e1d5")
	})
	var stone := MeshLib.material("#a39a89", 0.93)
	var stone_light := MeshLib.material("#c1b49c", 0.9)
	var stone_dark := MeshLib.material("#665e53", 0.95)
	var wood := MeshLib.material("#725237", 0.91)
	var wood_dark := MeshLib.material("#4a3527", 0.94)
	var iron := MeshLib.material("#3b3f43", 0.55, 0.55)
	# A broad river band crosses beneath the unfinished bridge, with green banks
	# on the north and south sides.
	var grass := MeshLib.material("#6f7c50", 0.98)
	MeshLib.add_plane(self, Vector2(90.0, 26.0), Vector3(0.0, -1.34, 0.0), water, "EndingRiver")
	MeshLib.add_plane(self, Vector2(90.0, 30.0), Vector3(0.0, -0.34, -26.0), grass, "EndingGrassNorth")
	MeshLib.add_plane(self, Vector2(90.0, 30.0), Vector3(0.0, -0.34, 26.0), grass, "EndingGrassSouth")
	# Soft muddy banks.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(90.0, 0.18, 0.8), Vector3(0.0, -0.44, side * 13.0), MeshLib.material("#7b7254", 0.98), "EndingRiverBank")
	# Reeds and rocks break up the river line.
	for i in 13:
		var x := -17.0 + float(i) * 2.8
		var z := 12.4 if i % 2 == 0 else -12.4
		var reed := MeshLib.add_cylinder(self, 0.05, 0.01, 0.7, Vector3(x, 0.12, z), MeshLib.material("#6b744a", 0.95), "EndingReed", 5)
		reed.rotation_degrees.z = float((i % 3) - 1) * 8.0
	for i in 10:
		var x := -20.0 + float(i) * 4.1
		var z := 11.7 if i % 3 == 0 else -11.7
		MeshLib.add_sphere(self, 0.28, Vector3(x, -0.48, z), MeshLib.material("#67675c", 0.98), "EndingRiverRock", 0.7, 7)
	# Distant north gate and trees frame the crossing.
	_build_distant_gate(stone, stone_light, wood_dark)
	for i in 8:
		var tx := -23.0 + float(i) * 6.4
		var tz := -17.0 if i % 2 == 0 else 18.0
		_add_tree(Vector3(tx, -0.25, tz), 1.0 + float(i % 3) * 0.16)
	# Bridge-side banners and torch posts.
	var cloth := MeshLib.material("#6d3d53", 0.94)
	var cloth_gold := MeshLib.material("#c39d5d", 0.9, 0.15)
	for side: float in [-1.0, 1.0]:
		for z: float in [5.2, -5.2]:
			MeshLib.add_box(self, Vector3(0.06, 1.15, 0.7), Vector3(side * 3.55, 2.35, z), cloth, "EndingBanner")
			MeshLib.add_box(self, Vector3(0.07, 0.08, 0.74), Vector3(side * 3.55, 2.92, z), cloth_gold, "EndingBannerTrim")
			MeshLib.add_box(self, Vector3(0.5, 0.08, 0.08), Vector3(side * 3.55, 2.95, z), wood_dark, "EndingBannerRod")
	# Two unfinished deck sections with a central 4.4 m gap.
	MeshLib.add_box(self, Vector3(8.0, 0.9, 12.2), Vector3(0.0, -0.45, 8.1), cobble, "EndingBridgeSouth")
	MeshLib.add_box(self, Vector3(8.0, 0.9, 12.2), Vector3(0.0, -0.45, -8.1), cobble, "EndingBridgeNorth")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(8.6, 0.28, 12.2), Vector3(0.0, -0.35, side * 8.1), stone_dark, "EndingBridgeFascia")
		MeshLib.add_box(self, Vector3(0.32, 0.72, 12.2), Vector3(side * 3.85, 0.3, 8.1), stone, "EndingParapetSouth")
		MeshLib.add_box(self, Vector3(0.32, 0.72, 12.2), Vector3(side * 3.85, 0.3, -8.1), stone, "EndingParapetNorth")
		MeshLib.add_box(self, Vector3(0.5, 0.14, 12.2), Vector3(side * 3.85, 0.73, 8.1), stone_light, "EndingRailSouth")
		MeshLib.add_box(self, Vector3(0.5, 0.14, 12.2), Vector3(side * 3.85, 0.73, -8.1), stone_light, "EndingRailNorth")
		for i in 3:
			var zs := 2.8 + float(i) * 3.8
			var zn := -2.8 - float(i) * 3.8
			MeshLib.add_box(self, Vector3(0.48, 1.3, 0.48), Vector3(side * 3.85, 0.76, zs), stone, "EndingPillarSouth")
			MeshLib.add_box(self, Vector3(0.48, 1.3, 0.48), Vector3(side * 3.85, 0.76, zn), stone, "EndingPillarNorth")
			MeshLib.add_box(self, Vector3(0.62, 0.16, 0.62), Vector3(side * 3.85, 1.47, zs), stone_light, "EndingPillarCapSouth")
			MeshLib.add_box(self, Vector3(0.62, 0.16, 0.62), Vector3(side * 3.85, 1.47, zn), stone_light, "EndingPillarCapNorth")
	# Piers and the unfinished gap.
	for z: float in [-9.0, -4.0, 4.0, 9.0]:
		MeshLib.add_box(self, Vector3(8.8, 2.4, 1.25), Vector3(0.0, -1.45, z), stone_dark, "EndingPier")
	MeshLib.add_box(self, Vector3(8.0, 0.3, 0.3), Vector3(0.0, -0.05, 2.2), stone_light, "EndingBrokenEdgeSouth")
	MeshLib.add_box(self, Vector3(8.0, 0.3, 0.3), Vector3(0.0, -0.05, -2.2), stone_light, "EndingBrokenEdgeNorth")
	# Scaffolding around the gap.
	for side: float in [-1.0, 1.0]:
		for z: float in [-2.55, 2.55]:
			MeshLib.add_cylinder(self, 0.09, 0.075, 4.3, Vector3(side * 2.7, 2.15, z), wood, "EndingScaffoldPost", 7)
			MeshLib.add_cylinder(self, 0.09, 0.075, 4.3, Vector3(side * 2.7, 2.15, z * 1.25), wood, "EndingScaffoldPost", 7)
			MeshLib.add_box(self, Vector3(0.16, 0.16, 4.8), Vector3(side * 2.7, 4.45, 0.0), wood_dark, "EndingScaffoldBeam")
		for z: float in [-5.0, 5.0]:
			MeshLib.add_box(self, Vector3(0.16, 0.16, 9.9), Vector3(side * 2.7, 4.45, -z * 0.0), wood_dark, "EndingScaffoldBeam")
	for z: float in [-4.0, 4.0]:
		MeshLib.add_box(self, Vector3(8.0, 0.16, 0.16), Vector3(0.0, 4.55, z * 0.55), wood_dark, "EndingScaffoldCross")
	# Stone blocks and a barrow.
	MeshLib.add_box(self, Vector3(1.5, 0.7, 0.8), Vector3(-4.5, 0.35, 5.3), stone, "EndingBlock")
	MeshLib.add_box(self, Vector3(1.3, 0.6, 0.7), Vector3(4.4, 0.3, 5.6), stone, "EndingBlock")
	MeshLib.add_box(self, Vector3(1.3, 0.55, 0.7), Vector3(-4.6, 0.27, 6.2), stone_dark, "EndingBlock")
	MeshLib.add_box(self, Vector3(2.2, 0.16, 1.2), Vector3(3.8, 0.22, 7.1), wood, "EndingCartBed")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_cylinder(self, 0.34, 0.34, 0.14, Vector3(4.7, 0.34, 7.1 + side * 0.55), wood_dark, "EndingCartWheel", 10, Vector3(90.0, 0.0, 0.0))
	# Lamps at the south end.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_cylinder(self, 0.06, 0.045, 1.0, Vector3(side * 3.4, 1.05, 9.8), iron, "EndingLampPost", 6)
		MeshLib.add_box(self, Vector3(0.3, 0.34, 0.3), Vector3(side * 3.4, 1.65, 9.8), iron, "EndingLampCage")
		MeshLib.add_sphere(self, 0.13, Vector3(side * 3.4, 1.65, 9.8), MeshLib.emissive("#ffd18a", 1.9), "EndingLampFlame", -1.0, 8)
		MeshLib.add_omni_light(self, Vector3(side * 3.4, 1.7, 9.8), "#ffc77d", 1.2, 5.5, false)
	# The final slab, suspended above the gap.
	_slab = Node3D.new()
	_slab.name = "EndingFinalSlab"
	_slab.position = Vector3(0.0, 1.9, 0.0)
	add_child(_slab)
	var slab_top := MeshLib.material("#d0c1a3", 0.88)
	var slab_gold := MeshLib.material("#c9a45d", 0.42, 0.5)
	MeshLib.add_box(_slab, Vector3(7.8, 0.34, 4.1), Vector3.ZERO, stone_light, "EndingSlab")
	MeshLib.add_box(_slab, Vector3(7.9, 0.06, 4.2), Vector3(0.0, 0.2, 0.0), slab_top, "EndingSlabTop")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(_slab, Vector3(0.1, 0.42, 4.2), Vector3(side * 3.92, 0.0, 0.0), stone, "EndingSlabEdge")
		for end: float in [-1.0, 1.0]:
			MeshLib.add_box(_slab, Vector3(0.38, 0.14, 0.38), Vector3(side * 3.55, 0.25, end * 1.78), slab_gold, "EndingSlabClamp")
	# Ropes from the scaffold to the slab (visual only).
	for side: float in [-1.0, 1.0]:
		var rope := MeshLib.add_cylinder(_slab, 0.026, 0.026, 2.5, Vector3(side * 2.7, 1.55, 0.0), MeshLib.material("#7c6650", 0.9), "EndingRope", 5)
		rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Dust burst for the slab landing.
	_gap_dust = CPUParticles3D.new()
	_gap_dust.name = "EndingSlabDust"
	_gap_dust.amount = 80
	_gap_dust.lifetime = 1.8
	_gap_dust.one_shot = true
	_gap_dust.emitting = false
	_gap_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_gap_dust.emission_box_extents = Vector3(3.8, 0.2, 2.0)
	_gap_dust.direction = Vector3(0.0, 0.4, 0.0)
	_gap_dust.spread = 80.0
	_gap_dust.gravity = Vector3(0.0, -0.4, 0.0)
	_gap_dust.initial_velocity_min = 0.4
	_gap_dust.initial_velocity_max = 2.0
	_gap_dust.scale_amount_min = 0.08
	_gap_dust.scale_amount_max = 0.25
	_gap_dust.color = Color("#d2c2a6")
	_gap_dust.position = Vector3(0.0, 0.1, 0.0)
	add_child(_gap_dust)
	MeshLib.add_omni_light(self, Vector3(0.0, 4.5, 0.0), "#ffe0b0", 1.0, 10.0, false)


func _shader_material(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	for key: String in params.keys():
		mat.set_shader_parameter(key, params[key])
	return mat


func _build_distant_gate(stone: Material, stone_light: Material, wood_dark: Material) -> void:
	var gate_root := Node3D.new()
	gate_root.name = "NorthGateBackdrop"
	gate_root.position = Vector3(0.0, 0.0, -20.0)
	add_child(gate_root)
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(gate_root, Vector3(2.4, 5.4, 2.6), Vector3(side * 5.4, 2.7, 0.0), stone, "NorthGateTower")
		MeshLib.add_box(gate_root, Vector3(2.9, 0.35, 3.0), Vector3(side * 5.4, 5.5, 0.0), stone_light, "NorthGateTowerCap")
		for i in 3:
			MeshLib.add_box(gate_root, Vector3(0.75, 0.5, 0.5), Vector3(side * 5.4 - 0.8 + float(i) * 0.8, 5.9, 0.0), stone_light, "NorthGateCrenel")
		MeshLib.add_box(gate_root, Vector3(0.08, 2.2, 1.3), Vector3(side * 5.4, 3.7, -1.34), MeshLib.material("#6d3d53", 0.94), "NorthGateBanner")
	MeshLib.add_box(gate_root, Vector3(8.6, 3.8, 2.2), Vector3(0.0, 1.9, 0.0), stone, "NorthGateWall")
	MeshLib.add_box(gate_root, Vector3(3.8, 3.1, 0.6), Vector3(0.0, 1.55, 1.2), MeshLib.material("#3d3a38", 0.98), "NorthGateArch")
	MeshLib.add_box(gate_root, Vector3(4.4, 0.3, 2.6), Vector3(0.0, 3.9, 0.0), stone_light, "NorthGateLintel")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_cylinder(gate_root, 0.08, 0.06, 2.0, Vector3(side * 2.6, 6.0, 0.0), wood_dark, "NorthGatePole", 6)
		MeshLib.add_box(gate_root, Vector3(0.5, 0.12, 0.12), Vector3(side * 2.6, 7.0, 0.0), wood_dark, "NorthGateCross")
	# A few silhouette rooftops behind the wall.
	for i in 5:
		var x := -10.0 + float(i) * 5.0
		MeshLib.add_box(gate_root, Vector3(2.8, 2.2 + float(i % 2) * 0.8, 2.0), Vector3(x, 1.0, -2.8), MeshLib.material("#6d6253", 0.98), "NorthGateHouse")
		MeshLib.add_pyramid(gate_root, Vector2(2.4, 1.2), 1.2, Vector3(x, 2.4 + float(i % 2) * 0.4, -2.8), MeshLib.material("#574838", 0.96), "NorthGateRoof")


func _add_tree(pos: Vector3, scale_factor: float) -> void:
	var root := Node3D.new()
	root.name = "EndingTree"
	root.position = pos
	root.scale = Vector3.ONE * scale_factor
	add_child(root)
	MeshLib.add_cylinder(root, 0.18, 0.11, 2.4, Vector3(0.0, 1.2, 0.0), MeshLib.material("#5f4a32", 0.96), "Trunk", 7)
	var leaf := MeshLib.material("#526846", 0.98)
	var leaf_light := MeshLib.material("#5f7750", 0.98)
	MeshLib.add_sphere(root, 1.15, Vector3(0.0, 2.7, 0.0), leaf, "Leaves", 1.5, 9)
	MeshLib.add_sphere(root, 0.86, Vector3(-0.55, 3.1, 0.2), leaf_light, "Leaves", 1.4, 8)
	MeshLib.add_sphere(root, 0.8, Vector3(0.6, 3.0, -0.2), leaf, "Leaves", 1.3, 8)


func _build_workers() -> void:
	var positions := [
		Vector3(-2.5, 0.0, -3.0),
		Vector3(0.0, 0.0, -3.2),
		Vector3(2.6, 0.0, -3.0),
		Vector3(-1.8, 0.0, 3.0),
		Vector3(2.1, 0.0, 3.0)
	]
	for i in positions.size():
		var worker := CharacterVisual.new()
		worker.name = "Worker_%d" % i
		worker.setup_worker(i)
		worker.position = positions[i]
		worker.set_facing(Vector3(0.0, 0.0, 1.0 if positions[i].z < 0.0 else -1.0), true)
		add_child(worker)
		_workers.append(worker)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "EndingCamera"
	_camera.fov = 38.0
	_camera.near = 0.15
	_camera.far = 180.0
	_camera.position = Vector3(9.8, 7.6, 13.6)
	_camera.current = true
	add_child(_camera)
	_camera.look_at(_camera_target, Vector3.UP)


# ---------------------------------------------------------------------------
# Ending sequence
# ---------------------------------------------------------------------------

func _run_cutscene() -> void:
	await get_tree().process_frame
	await _fade_from_black(0.9)
	_show_caption(GameState.ui_text("ending_caption_1", "Король отдал приказ завершить северный мост."))
	await get_tree().create_timer(2.3).timeout
	_show_caption(GameState.ui_text("ending_caption_2", "Королевские рабочие ставят последний пролёт."))
	var slab_tween := create_tween()
	slab_tween.tween_property(_slab, "position:y", 0.0, 2.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, "position", Vector3(13.8, 10.6, 19.0), 4.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(2.75).timeout
	_working = false
	if _gap_dust != null:
		_gap_dust.emitting = true
	_show_caption(GameState.ui_text("ending_caption_3", "Мост готов. Путь на север открыт."))
	await get_tree().create_timer(2.4).timeout
	await _fade_to_black(1.0)
	_show_final()


func _show_caption(text: String) -> void:
	if _caption_label == null:
		return
	_caption_label.text = text
	_caption_panel.visible = true
	_caption_panel.modulate.a = 0.0
	if _caption_tween != null and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption_panel, "modulate:a", 1.0, 0.35)
	_caption_tween.tween_interval(1.7)
	_caption_tween.tween_property(_caption_panel, "modulate:a", 0.0, 0.45)
	_caption_tween.tween_callback(_caption_panel.hide)


func _show_final() -> void:
	if _final_visible:
		return
	_final_visible = true
	_finished = true
	GameState.mark_flag("demo_complete")
	_caption_panel.hide()
	_fade.visible = false
	_final_root.visible = true
	_final_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_final_root, "modulate:a", 1.0, 1.0)
	_letter_top.modulate.a = 0.0
	_letter_bottom.modulate.a = 0.0


func _fade_from_black(duration: float) -> void:
	_fade.visible = true
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)
	await tw.finished
	_fade.visible = false


func _fade_to_black(duration: float) -> void:
	_fade.visible = true
	_fade.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	await tw.finished


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "EndingUI"
	layer.layer = 50
	add_child(layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = _font_body
	theme.default_font_size = 18
	_ui_root.theme = theme
	layer.add_child(_ui_root)
	_letter_top = ColorRect.new()
	_letter_top.color = Color("#090b0d")
	_letter_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_letter_top.offset_bottom = 66.0
	_letter_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_letter_top)
	_letter_bottom = ColorRect.new()
	_letter_bottom.color = Color("#090b0d")
	_letter_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_letter_bottom.offset_top = -66.0
	_letter_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_letter_bottom)
	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -178.0
	bottom.offset_bottom = -78.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(bottom)
	_caption_panel = PanelContainer.new()
	_caption_panel.custom_minimum_size = Vector2(760.0, 0.0)
	_caption_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.06, 0.078, 0.92), Color(0.76, 0.61, 0.35, 0.9), 1, 3, 12))
	_caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_panel.visible = false
	bottom.add_child(_caption_panel)
	_caption_label = _label("", 18, IVORY, false)
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_panel.add_child(_caption_label)
	# Final screen.
	_final_root = Control.new()
	_final_root.name = "DemoComplete"
	_final_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_final_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_root.visible = false
	_ui_root.add_child(_final_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.012, 0.018, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	var style := _panel_style(Color(0.035, 0.06, 0.08, 0.97), Color(0.76, 0.61, 0.35, 0.98), 2, 5, 30)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 11)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var kicker := _label("СЕВЕРНЫЙ МОСТ · КОРНЕЛИЯ", 11, GOLD, true)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(kicker)
	var rule := ColorRect.new()
	rule.color = Color(0.76, 0.61, 0.35, 0.5)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rule)
	_final_title = _label(GameState.ui_text("ending_title", "ДЕМО ЗАВЕРШЕНО"), 42, GOLD_BRIGHT, true)
	_final_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_title.add_theme_constant_override("outline_size", 0)
	vbox.add_child(_final_title)
	_final_subtitle = _label(GameState.ui_text("ending_subtitle", "Спасибо за игру."), 19, IVORY, false)
	_final_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_final_subtitle)
	var rule2 := ColorRect.new()
	rule2.color = Color(0.76, 0.61, 0.35, 0.35)
	rule2.custom_minimum_size = Vector2(0.0, 1.0)
	rule2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rule2)
	_final_hint = _label(GameState.ui_text("ending_hint", "E — выйти"), 12, MUTED, false)
	_final_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_final_hint)
	_fade = ColorRect.new()
	_fade.name = "EndingFade"
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.008, 0.012, 0.018, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_fade)


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font_bold if bold else _font_body)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(bg: Color, border: Color, border_width: int = 1, radius: int = 3, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = float(margin)
	style.content_margin_right = float(margin)
	style.content_margin_top = float(margin)
	style.content_margin_bottom = float(margin)
	return style


func _unhandled_input(event: InputEvent) -> void:
	if not _final_visible or _finished == false:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().quit(0)


# ---------------------------------------------------------------------------
# Test hooks
# ---------------------------------------------------------------------------

func is_final_visible() -> bool:
	return _final_visible


func get_final_title_text() -> String:
	return _final_title.text if _final_title != null else ""


func get_worker_count() -> int:
	return _workers.size()
