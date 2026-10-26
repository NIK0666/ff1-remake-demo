class_name BattleScene
extends Node3D
## The separate, top-down bridge battle. Party right, enemies left, two ranks.
## All formulas, spells, enemies, encounters and rewards are loaded from JSON.

signal battle_finished(result: Dictionary)
signal _hero_turn_done

const GOLD := Color("#d5b16b")

var encounter_data: Dictionary = {}
var combat: Dictionary = {}
var arena: Dictionary = {}
var heroes: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var turn_order: Array[BattleUnit] = []
var active_unit: BattleUnit = null
var round_number: int = 0
var turn_cursor: int = 0
var phase: String = "intro"
var battle_over: bool = false
var input_locked: bool = true
var menu_index: int = 0
var target_units: Array[BattleUnit] = []
var pending_action: String = ""
var pending_spell: Dictionary = {}
var pending_item: Dictionary = {}
var spell_choices: Array[Dictionary] = []
var item_choices: Array[Dictionary] = []
var hud: BattleHUD
var rng := RandomNumberGenerator.new()
var rng_seed_override: int = 0
var flee_roll_override: float = -1.0

var _hero_root: Node3D
var _enemy_root: Node3D
var _active_ring: MeshInstance3D
var _target_ring: MeshInstance3D
var _unit_labels: Dictionary = {}
var _fallen_markers: Dictionary = {}
var _log_lines: Array[String] = []
var _end_mode: String = ""
var _finished: bool = false
var _campaign_title: String = ""


func _ready() -> void:
	combat = GameState.combat
	var arena_key := str(encounter_data.get("arena", "bridge"))
	arena = combat.get("shrine_arena", {}) if arena_key == "shrine" else combat.get("arena", {})
	if encounter_data.is_empty():
		encounter_data = GameState.get_encounter_by_id("bridge_patrol")
	_campaign_title = str(encounter_data.get("title", "Северный мост"))
	if rng_seed_override == 0:
		rng.randomize()
	else:
		rng.seed = rng_seed_override
	_build_environment()
	if arena_key == "shrine":
		_build_shrine_arena()
	else:
		_build_bridge()
	_build_camera()
	_build_units()
	_layout_units()
	_build_active_ring()
	_build_target_ring()
	_build_unit_labels()
	hud = BattleHUD.new()
	hud.name = "BattleHUD"
	add_child(hud)
	var arena_title := str(arena.get("title", "СЕВЕРНЫЙ МОСТ"))
	hud.setup(heroes, enemies, "%s · %s" % [arena_title, _campaign_title])
	_add_log(str(encounter_data.get("intro", "Враги преграждают путь!")))
	_add_log("Бой начинается. Отряд справа, враги слева.")
	_start_battle()


# ---------------------------------------------------------------------------
# Scene construction: a close-up section of the same north bridge
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var cfg: Dictionary = arena.get("environment", {})
	var env := Environment.new()
	if str(cfg.get("background", "sky")) == "color":
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(str(cfg.get("background_color", "#100b16")))
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(str(cfg.get("sky_top_color", "#566b86")))
		sky_mat.sky_horizon_color = Color(str(cfg.get("sky_horizon_color", "#c7a98b")))
		sky_mat.ground_horizon_color = Color(str(cfg.get("ground_horizon_color", "#7d8068")))
		sky_mat.ground_bottom_color = Color(str(cfg.get("ground_bottom_color", "#34434b")))
		sky_mat.sun_angle_max = 25.0
		sky_mat.sun_curve = 0.12
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(str(cfg.get("ambient_color", "#b8c9d5")))
	env.ambient_light_energy = float(cfg.get("ambient_energy", 0.48))
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = bool(cfg.get("fog_enabled", true))
	env.fog_light_color = Color(str(cfg.get("fog_color", "#8896a0")))
	env.fog_density = float(cfg.get("fog_density", 0.012))
	env.fog_sky_affect = 0.35
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.04
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(str(cfg.get("sun_color", "#ffd3a0")))
	sun.light_energy = float(cfg.get("sun_energy", 1.25))
	sun.rotation_degrees = GameState.vec3_from_array(cfg.get("sun_rotation", [-48.0, -132.0, 0.0]))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	add_child(sun)
	MeshLib.add_omni_light(self, Vector3(0.0, 4.0, 2.0), "#ffd7a0", 1.0, 15.0, false)


func _build_bridge() -> void:
	var width := float(arena.get("deck_width", 8.0))
	var length := float(arena.get("deck_length", 24.0))
	var stone := MeshLib.material("#9a9384", 0.94)
	var stone_dark := MeshLib.material("#5b554b", 0.95)
	var stone_light := MeshLib.material("#b5a994", 0.9)
	var iron := MeshLib.material("#3c4146", 0.55, 0.55)
	var wood := MeshLib.material("#6b4d34", 0.9)
	var gold := MeshLib.material("#c4a35e", 0.38, 0.5)
	var cobble := _shader_material("res://shaders/cobblestone.gdshader")
	var water := _shader_material("res://shaders/water.gdshader", _water_params())

	var deck := MeshLib.add_box(self, Vector3(width, 0.9, length), Vector3(0.0, -0.45, 0.0), cobble, "BattleBridgeDeck")
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	MeshLib.add_box(self, Vector3(width + 0.6, 0.3, length), Vector3(0.0, -0.35, 0.0), stone_dark, "BattleBridgeFascia")
	# Water on both sides, as in the town bridge view.
	MeshLib.add_plane(self, Vector2(30.0, length + 8.0), Vector3(-19.0, -1.32, 0.0), water, "BattleWaterLeft")
	MeshLib.add_plane(self, Vector2(30.0, length + 8.0), Vector3(19.0, -1.32, 0.0), water, "BattleWaterRight")
	for side: float in [-1.0, 1.0]:
		var parapet_x := side * (width * 0.5 - 0.15)
		MeshLib.add_box(self, Vector3(0.3, 0.72, length), Vector3(parapet_x, 0.3, 0.0), stone, "BattleParapet")
		MeshLib.add_box(self, Vector3(0.44, 0.12, length), Vector3(parapet_x, 0.73, 0.0), stone_light, "BattleRailTop")
		MeshLib.add_box(self, Vector3(0.34, 0.1, length), Vector3(parapet_x, 0.05, 0.0), stone_dark, "BattleRailBase")
		var post_count := 6
		for i in post_count + 1:
			var pz := -length * 0.5 + float(i) * (length / float(post_count))
			MeshLib.add_box(self, Vector3(0.46, 1.35, 0.46), Vector3(parapet_x, 0.78, pz), stone, "BattlePillar")
			MeshLib.add_box(self, Vector3(0.58, 0.16, 0.58), Vector3(parapet_x, 1.48, pz), gold, "BattlePillarCap")
		for j in 6:
			var panel_z := -length * 0.5 + 2.0 + float(j) * ((length - 4.0) / 5.0)
			MeshLib.add_box(self, Vector3(0.035, 0.3, 1.35), Vector3(side * (width * 0.5 - 0.31), 0.36, panel_z), stone_dark, "BattleRailPanel")
			MeshLib.add_box(self, Vector3(0.05, 0.5, 0.05), Vector3(side * (width * 0.5 - 0.32), 0.38, panel_z), gold, "BattleRailDiamond", Vector3(45.0, 0.0, 0.0))
	# A few bridge lamps for the same warm evening look.
	for z: float in [-8.5, -2.0, 4.5, 10.5]:
		_add_battle_lamp(Vector3(-(width * 0.5 - 0.15), 0.74, z), false)
		_add_battle_lamp(Vector3(width * 0.5 - 0.15, 0.74, z), true)
	# Crude stone lip at both ends closes the arena while keeping it on the bridge.
	for end: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(width, 0.18, 0.5), Vector3(0.0, 0.08, end * (length * 0.5)), stone_dark, "BattleEndCurb")
	# Piers silhouettes under the deck.
	for z: float in [-8.0, 0.0, 8.0]:
		MeshLib.add_box(self, Vector3(width + 0.6, 2.3, 1.1), Vector3(0.0, -1.4, z), stone_dark, "BattlePier")
	MeshLib.add_omni_light(self, Vector3(0.0, 3.2, -4.0), "#ffd29a", 0.9, 13.0, false)
	MeshLib.add_omni_light(self, Vector3(0.0, 3.2, 6.0), "#ffd29a", 0.7, 12.0, false)
	# A sign at the near end ties the arena to the north bridge.
	var sign_label := MeshLib.add_label3d(self, "СЕВЕРНЫЙ МОСТ", Vector3(0.0, 3.3, length * 0.5 - 0.4), 38, "#f0d49a", "BattleBridgeSign")
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.no_depth_test = true
	sign_label.pixel_size = 0.009
	sign_label.width = 2000.0
	sign_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.08, 0.72, 0.08), Vector3(side * 3.7, 1.85, length * 0.5 - 0.35), iron, "BattleSignPost")
	MeshLib.add_box(self, Vector3(5.0, 0.12, 0.3), Vector3(0.0, 2.21, length * 0.5 - 0.35), wood, "BattleSignBeam")


func _build_shrine_arena() -> void:
	var width := float(arena.get("room_width", 16.0))
	var depth := float(arena.get("room_depth", 16.0))
	var wall_h := float(arena.get("wall_height", 6.0))
	var stone := MeshLib.material("#4a4450", 0.95)
	var stone_dark := MeshLib.material("#27232e", 0.97)
	var trim := MeshLib.material("#a98b58", 0.5, 0.35)
	var accent := MeshLib.material("#7f58b8", 0.6, 0.15)
	var accent_glow := MeshLib.emissive("#a678e2", 1.8)
	var iron := MeshLib.material("#302b35", 0.5, 0.45)
	MeshLib.add_box(self, Vector3(width, 0.4, depth), Vector3(0.0, -0.2, 0.0), stone, "ShrineArenaFloor")
	MeshLib.add_box(self, Vector3(width + 1.0, 0.25, depth + 1.0), Vector3(0.0, -0.43, 0.0), stone_dark, "ShrineArenaBase")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(width, wall_h, 0.55), Vector3(0.0, wall_h * 0.5, side * (depth * 0.5 + 0.25)), stone_dark, "ShrineArenaWall")
		MeshLib.add_box(self, Vector3(0.55, wall_h, depth), Vector3(side * (width * 0.5 + 0.25), wall_h * 0.5, 0.0), stone_dark, "ShrineArenaWall")
		MeshLib.add_box(self, Vector3(width + 0.5, 0.18, 0.18), Vector3(0.0, wall_h - 0.25, side * (depth * 0.5 - 0.05)), trim, "ShrineArenaWallTrim")
		MeshLib.add_box(self, Vector3(0.18, wall_h - 0.4, 0.18), Vector3(side * (width * 0.5 - 0.05), wall_h * 0.5, 0.0), trim, "ShrineArenaWallTrim")
	for x: float in [-6.0, 6.0]:
		for z: float in [-5.0, 0.0, 5.0]:
			MeshLib.add_box(self, Vector3(0.9, 0.3, 0.9), Vector3(x, 0.15, z), stone_dark, "ShrineArenaPillarBase")
			MeshLib.add_cylinder(self, 0.32, 0.27, 3.8, Vector3(x, 2.05, z), stone, "ShrineArenaPillar", 10)
			MeshLib.add_cylinder(self, 0.42, 0.42, 0.16, Vector3(x, 3.98, z), trim, "ShrineArenaPillarCap", 10)
	# Central ritual circle.
	var sigil := MeshLib.add_cylinder(self, 3.0, 3.0, 0.025, Vector3(0.0, 0.025, 0.0), MeshLib.transparent("#8c61c9", 0.14, true), "ShrineArenaSigil", 48)
	sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var torus := TorusMesh.new()
	torus.inner_radius = 2.85
	torus.outer_radius = 3.0
	torus.rings = 40
	torus.ring_segments = 8
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = accent_glow
	ring.position = Vector3(0.0, 0.045, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		MeshLib.add_box(self, Vector3(0.32, 0.018, 0.09), Vector3(cos(angle) * 2.65, 0.04, sin(angle) * 2.65), accent_glow, "ShrineArenaRune", Vector3(0.0, -rad_to_deg(angle), 0.0), false)
	# Altar at the back of the chamber.
	MeshLib.add_box(self, Vector3(5.2, 0.5, 2.4), Vector3(0.0, 0.25, -depth * 0.5 + 1.6), stone_dark, "ShrineArenaAltarDais")
	MeshLib.add_box(self, Vector3(4.2, 0.15, 1.5), Vector3(0.0, 0.57, -depth * 0.5 + 1.6), trim, "ShrineArenaAltarTop")
	MeshLib.add_box(self, Vector3(1.8, 1.2, 0.9), Vector3(0.0, 1.15, -depth * 0.5 + 1.55), stone, "ShrineArenaAltar")
	MeshLib.add_sphere(self, 0.3, Vector3(0.0, 2.0, -depth * 0.5 + 1.55), accent_glow, "ShrineArenaCrystal", 0.7, 12)
	MeshLib.add_omni_light(self, Vector3(0.0, 2.1, -depth * 0.5 + 1.55), "#c07adf", 1.5, 7.0, false)
	# Braziers and sconces.
	for side: float in [-1.0, 1.0]:
		for z: float in [-4.0, 3.0]:
			_add_shrine_arena_brazier(Vector3(side * 5.0, 0.0, z), iron, accent_glow)
		MeshLib.add_box(self, Vector3(0.26, 2.0, 0.26), Vector3(side * (width * 0.5 - 0.45), 2.2, -2.0), iron, "ShrineArenaSconce")
		MeshLib.add_sphere(self, 0.16, Vector3(side * (width * 0.5 - 0.45), 3.3, -2.0), accent_glow, "ShrineArenaFlame", 0.3, 8)
		MeshLib.add_omni_light(self, Vector3(side * (width * 0.5 - 0.45), 3.3, -2.0), "#a272dd", 1.1, 5.5, false)
	MeshLib.add_omni_light(self, Vector3(0.0, 4.0, 3.0), "#8060b0", 0.9, 14.0, false)
	if bool(encounter_data.get("boss", false)):
		MeshLib.add_omni_light(self, Vector3(-1.35, 2.6, 0.0), "#d05e70", 1.3, 6.0, false)
		var boss_title := MeshLib.add_label3d(self, "ГАРЛАНД", Vector3(0.0, 4.2, -depth * 0.5 + 0.15), 42, "#d67f87", "ShrineArenaBossTitle")
		boss_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		boss_title.no_depth_test = true
		boss_title.pixel_size = 0.01
		boss_title.width = 2000.0
		boss_title.autowrap_mode = TextServer.AUTOWRAP_OFF


func _add_shrine_arena_brazier(pos: Vector3, iron: StandardMaterial3D, flame: StandardMaterial3D) -> void:
	MeshLib.add_cylinder(self, 0.16, 0.22, 0.65, pos + Vector3(0.0, 0.32, 0.0), iron, "ShrineArenaBrazierStem", 8)
	MeshLib.add_cylinder(self, 0.36, 0.27, 0.22, pos + Vector3(0.0, 0.76, 0.0), iron, "ShrineArenaBrazierBowl", 10)
	MeshLib.add_sphere(self, 0.2, pos + Vector3(0.0, 0.93, 0.0), flame, "ShrineArenaBrazierFlame", 0.4, 8)
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 1.0, 0.0), "#a976dc", 1.1, 4.5, false)


func _add_battle_lamp(pos: Vector3, side: bool) -> void:
	var iron := MeshLib.material("#383d42", 0.5, 0.55)
	var gold := MeshLib.material("#c4a35e", 0.4, 0.5)
	var flame := MeshLib.emissive("#ffcf82", 1.9)
	MeshLib.add_cylinder(self, 0.05, 0.04, 0.9, pos + Vector3(0.0, 0.45, 0.0), iron, "BattleLampPost", 6)
	MeshLib.add_box(self, Vector3(0.28, 0.36, 0.28), pos + Vector3(0.0, 1.02, 0.0), MeshLib.material("#2f363b", 0.6, 0.4), "BattleLampCage")
	MeshLib.add_sphere(self, 0.11, pos + Vector3(0.0, 1.02, 0.0), flame, "BattleLampFlame", -1.0, 8)
	MeshLib.add_box(self, Vector3(0.34, 0.05, 0.34), pos + Vector3(0.0, 1.22, 0.0), gold, "BattleLampCap")
	if side:
		MeshLib.add_omni_light(self, pos + Vector3(0.0, 1.1, 0.0), "#ffc47d", 1.2, 4.5, false)


func _water_params() -> Dictionary:
	var river: Dictionary = GameState.get_location("town").get("river", {})
	return {
		"shallow_color": Color(str(river.get("shallow_color", "#3f6f78"))),
		"deep_color": Color(str(river.get("deep_color", "#173847"))),
		"foam_color": Color(str(river.get("foam_color", "#cfe0d4")))
	}


func _shader_material(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	for key: String in params.keys():
		mat.set_shader_parameter(key, params[key])
	return mat


func _build_camera() -> void:
	var cfg: Dictionary = arena.get("camera", {})
	var camera := Camera3D.new()
	camera.name = "BattleCamera"
	camera.fov = float(cfg.get("fov", 39.0))
	camera.near = 0.15
	camera.far = 120.0
	var distance := float(cfg.get("distance", 15.0))
	var pitch := deg_to_rad(float(cfg.get("pitch_degrees", 57.0)))
	var yaw := deg_to_rad(float(cfg.get("yaw_degrees", 0.0)))
	var target := Vector3(0.0, float(cfg.get("target_height", 1.0)), 0.0)
	var offset := Vector3(
		sin(yaw) * cos(pitch) * distance,
		sin(pitch) * distance,
		cos(yaw) * cos(pitch) * distance
	)
	camera.position = target + offset
	camera.current = true
	add_child(camera)
	camera.look_at(target, Vector3.UP)


func _build_units() -> void:
	_hero_root = Node3D.new()
	_hero_root.name = "BattleHeroes"
	add_child(_hero_root)
	_enemy_root = Node3D.new()
	_enemy_root.name = "BattleEnemies"
	add_child(_enemy_root)
	for i in GameState.party.size():
		var member: Dictionary = GameState.party[i]
		var unit := BattleUnit.make_hero(str(member.get("id", "")))
		var visual := CharacterVisual.new()
		visual.name = "BattleHero_%s" % unit.member_id
		visual.setup_hero(member, i)
		visual.set_facing(Vector3(-1.0, 0.0, 0.0), true)
		_hero_root.add_child(visual)
		unit.visual = visual
		heroes.append(unit)
	var raw_enemies: Array = encounter_data.get("enemies", [])
	var templates: Dictionary = combat.get("enemies", {})
	for i in raw_enemies.size():
		var enemy_key := str(raw_enemies[i])
		var template: Dictionary = templates.get(enemy_key, {})
		if template.is_empty():
			continue
		var unit := BattleUnit.make_enemy(enemy_key, template)
		var visual_data: Dictionary = template.duplicate(true)
		visual_data["id"] = "%s_%d" % [enemy_key, i]
		var visual := CharacterVisual.new()
		visual.name = "BattleEnemy_%d" % i
		visual.setup_enemy(visual_data)
		visual.set_facing(Vector3(1.0, 0.0, 0.0), true)
		_enemy_root.add_child(visual)
		unit.visual = visual
		enemies.append(unit)
	# Duplicate enemies get Roman suffixes so logs, targets and labels stay unambiguous.
	var name_counts: Dictionary = {}
	for unit: BattleUnit in enemies:
		var base := unit.display_name()
		name_counts[base] = int(name_counts.get(base, 0)) + 1
	var used_names: Dictionary = {}
	var numerals := [" I", " II", " III", " IV", " V", " VI"]
	for unit: BattleUnit in enemies:
		var base := unit.display_name()
		if int(name_counts.get(base, 1)) <= 1:
			continue
		var used := int(used_names.get(base, 0))
		unit.name_suffix = numerals[mini(used, numerals.size() - 1)]
		used_names[base] = used + 1


func _layout_units() -> void:
	_layout_side(heroes, true)
	_layout_side(enemies, false)


func _layout_side(units: Array[BattleUnit], is_party: bool) -> void:
	var rows: Dictionary = arena.get("party_rows" if is_party else "enemy_rows", {})
	var spacing := float(arena.get("slot_spacing", 1.55))
	for row_name: String in ["front", "back"]:
		var row_units: Array[BattleUnit] = []
		for unit: BattleUnit in units:
			if unit.row() == row_name:
				row_units.append(unit)
		var count := row_units.size()
		var x := float(rows.get(row_name, 1.25 if is_party else -1.25))
		for i in count:
			var unit: BattleUnit = row_units[i]
			var z := 0.0 if count <= 1 else (float(i) - float(count - 1) * 0.5) * spacing
			var pos := Vector3(x, 0.0, z)
			unit.base_position = pos
			unit.formation_slot = pos
			if unit.visual != null:
				unit.visual.position = pos
				unit.visual.set_facing(Vector3(-1.0 if is_party else 1.0, 0.0, 0.0), true)


func _build_active_ring() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.42, 0.8)
	mat.emission_enabled = true
	mat.emission = Color("#e6c36b")
	mat.emission_energy_multiplier = 1.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var torus := TorusMesh.new()
	torus.inner_radius = 0.44
	torus.outer_radius = 0.52
	torus.rings = 24
	torus.ring_segments = 8
	_active_ring = MeshInstance3D.new()
	_active_ring.name = "BattleActiveRing"
	_active_ring.mesh = torus
	_active_ring.material_override = mat
	_active_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_active_ring.visible = false
	add_child(_active_ring)


func _build_target_ring() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.42, 0.28, 0.9)
	mat.emission_enabled = true
	mat.emission = Color("#e8764e")
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var torus := TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.57
	torus.rings = 24
	torus.ring_segments = 8
	_target_ring = MeshInstance3D.new()
	_target_ring.name = "BattleTargetRing"
	_target_ring.mesh = torus
	_target_ring.material_override = mat
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ring.visible = false
	add_child(_target_ring)


func _build_unit_labels() -> void:
	for unit: BattleUnit in heroes:
		_make_unit_label(unit, false)
	for unit: BattleUnit in enemies:
		_make_unit_label(unit, true)


func _short_field_name(unit: BattleUnit) -> String:
	var full := unit.display_name()
	if unit.is_hero:
		return full
	var dash := full.find("-")
	if dash < 0:
		return full
	var short := full.substr(dash + 1)
	if short.is_empty():
		return full
	return short.substr(0, 1).to_upper() + short.substr(1)


func _make_unit_label(unit: BattleUnit, enemy: bool) -> void:
	var label := Label3D.new()
	label.name = "Name_%s" % unit.display_name()
	label.text = _short_field_name(unit)
	label.font_size = 30
	label.pixel_size = 0.0045
	label.outline_size = 7
	label.outline_modulate = Color(0.015, 0.02, 0.025, 0.92)
	label.modulate = Color("#e6a08a") if enemy else Color("#f0dcb6")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = unit.base_position + Vector3(0.0, 2.55, 0.0)
	add_child(label)
	_unit_labels[unit] = label


func _update_unit_labels() -> void:
	for unit: BattleUnit in heroes:
		_update_unit_label(unit)
	for unit: BattleUnit in enemies:
		_update_unit_label(unit)


func _update_unit_label(unit: BattleUnit) -> void:
	var label: Label3D = _unit_labels.get(unit, null)
	if label == null:
		return
	label.position = unit.base_position + Vector3(0.0, 2.55, 0.0)
	if not unit.is_alive():
		label.text = "ПОВЕРЖЕН" if not unit.is_hero else "ПАЛ"
		label.modulate = Color("#8d7770")
	elif unit == active_unit:
		label.text = "▶ " + _short_field_name(unit)
		label.modulate = Color("#ffe3a1")
	else:
		label.text = _short_field_name(unit)
		label.modulate = Color("#e6a08a") if not unit.is_hero else Color("#f0dcb6")


func _update_target_ring() -> void:
	if _target_ring == null:
		return
	if phase != "target" or target_units.is_empty():
		_target_ring.visible = false
		return
	var index := clampi(menu_index, 0, target_units.size() - 1)
	var target: BattleUnit = target_units[index]
	if target == null or not target.is_alive():
		_target_ring.visible = false
		return
	_target_ring.visible = true
	_target_ring.position = target.base_position + Vector3(0.0, 0.045, 0.0)


# ---------------------------------------------------------------------------
# Turn loop
# ---------------------------------------------------------------------------

func _start_battle() -> void:
	await get_tree().process_frame
	await hud.fade_from_black(0.35)
	await get_tree().create_timer(0.6).timeout
	await _run_battle_loop()


func _run_battle_loop() -> void:
	while not battle_over:
		_start_round()
		for i in turn_order.size():
			if battle_over:
				break
			var unit: BattleUnit = turn_order[i]
			if not unit.is_alive():
				continue
			turn_cursor = i
			_set_active(unit)
			hud.set_turn_order(turn_order, i)
			if unit.is_hero:
				_begin_hero_turn()
				await _hero_turn_done
			else:
				await _run_enemy_turn(unit)
			if battle_over:
				break
			await get_tree().create_timer(0.16).timeout
		if not battle_over:
			_add_log("Раунд завершён.")
			await get_tree().create_timer(0.25).timeout


func _start_round() -> void:
	round_number += 1
	turn_order.clear()
	for unit: BattleUnit in heroes:
		if unit.is_alive():
			turn_order.append(unit)
	for unit: BattleUnit in enemies:
		if unit.is_alive():
			turn_order.append(unit)
	turn_order.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.agility() == b.agility():
			return a.display_name() < b.display_name()
		return a.agility() > b.agility()
	)
	_add_log("Раунд %d. Ход по ловкости." % round_number)
	hud.set_turn_order(turn_order, 0)
	hud.refresh_units(null)
	_update_unit_labels()


func _set_active(unit: BattleUnit) -> void:
	active_unit = unit
	if _active_ring != null:
		_active_ring.visible = true
		_active_ring.position = unit.base_position + Vector3(0.0, 0.035, 0.0)
	if _target_ring != null:
		_target_ring.visible = false
	_update_unit_labels()
	hud.refresh_units(unit)


func _begin_hero_turn() -> void:
	phase = "command"
	input_locked = false
	menu_index = 0
	pending_action = ""
	pending_spell = {}
	pending_item = {}
	hud.hide_center()
	hud.show_action("ХОД: %s" % active_unit.display_name(), Color("#f0d796"))
	_render_commands()


func _render_commands() -> void:
	var commands: Array[String] = []
	for raw: Variant in combat.get("ui", {}).get("commands", ["Атака", "Заклинание", "Предмет", "Бегство"]):
		commands.append(str(raw))
	while commands.size() < 4:
		commands.append("—")
	var title := "ХОД: %s · %s" % [active_unit.display_name(), active_unit.row_label()]
	hud.set_menu(title, commands, menu_index, "W/S — выбор    E — подтвердить")
	hud.refresh_units(active_unit)


# ---------------------------------------------------------------------------
# Player input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if _finished:
		return
	if phase == "victory" or phase == "defeat":
		if event.is_action_pressed("interact") and not input_locked:
			get_viewport().set_input_as_handled()
			_confirm_end()
		return
	if input_locked or battle_over or active_unit == null:
		return
	match phase:
		"command":
			if event.is_action_pressed("move_up"):
				menu_index = wrapi(menu_index - 1, 0, 4)
				_render_commands()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("move_down"):
				menu_index = wrapi(menu_index + 1, 0, 4)
				_render_commands()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_choose_command(menu_index)
		"spell":
			if event.is_action_pressed("move_up"):
				menu_index = wrapi(menu_index - 1, 0, maxi(1, spell_choices.size()))
				_render_spell_menu()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("move_down"):
				menu_index = wrapi(menu_index + 1, 0, maxi(1, spell_choices.size()))
				_render_spell_menu()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_choose_spell()
			elif event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				phase = "command"
				menu_index = 0
				_render_commands()
		"item":
			if event.is_action_pressed("move_up"):
				menu_index = wrapi(menu_index - 1, 0, maxi(1, item_choices.size()))
				_render_item_menu()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("move_down"):
				menu_index = wrapi(menu_index + 1, 0, maxi(1, item_choices.size()))
				_render_item_menu()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_choose_item()
			elif event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				phase = "command"
				menu_index = 0
				_render_commands()
		"target":
			if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
				menu_index = wrapi(menu_index - 1, 0, maxi(1, target_units.size()))
				_render_target_menu()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
				menu_index = wrapi(menu_index + 1, 0, maxi(1, target_units.size()))
				_render_target_menu()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_confirm_target()
			elif event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				_cancel_target()


func _choose_command(index: int) -> void:
	match index:
		0:
			pending_action = "attack"
			pending_spell = {}
			pending_item = {}
			_begin_target_select("АТАКА", _living(enemies))
		1:
			_show_spells()
		2:
			_show_items()
		3:
			_attempt_flee()


func _show_spells() -> void:
	spell_choices = active_unit.castable_spells()
	if spell_choices.is_empty():
		_add_log(GameState.get_combat_ui("no_spells", "Нет доступных заклинаний."))
		_render_commands()
		return
	phase = "spell"
	menu_index = 0
	_render_spell_menu()


func _render_spell_menu() -> void:
	var entries: Array[String] = []
	for spell: Dictionary in spell_choices:
		entries.append("%s · ур.%d · %d/%d" % [
			str(spell.get("name", "")),
			int(spell.get("level", 1)),
			int(spell.get("charges", 0)),
			int(spell.get("max_charges", 0))
		])
	hud.set_menu("ЗАКЛИНАНИЯ · %s" % active_unit.display_name(), entries, menu_index, "Заряды уровня, не мана.    W/S — выбор    E — выбрать    Esc — назад")
	hud.refresh_units(active_unit)


func _choose_spell() -> void:
	if spell_choices.is_empty():
		return
	var spell: Dictionary = spell_choices[menu_index]
	pending_action = "spell"
	pending_spell = spell
	var target_kind := str(spell.get("target", "enemy"))
	var targets := _allies() if target_kind == "ally" else _living(enemies)
	_begin_target_select(str(spell.get("name", "ЗАКЛИНАНИЕ")), targets)


func _show_items() -> void:
	item_choices = GameState.get_battle_usable_items()
	if item_choices.is_empty():
		_add_log(GameState.get_combat_ui("no_items", "В сумке нет боевых предметов."))
		_render_commands()
		return
	phase = "item"
	menu_index = 0
	_render_item_menu()


func _render_item_menu() -> void:
	var entries: Array[String] = []
	for entry: Dictionary in item_choices:
		entries.append("%s ×%d" % [str(entry.get("name", "")), int(entry.get("count", 0))])
	hud.set_menu("ПРЕДМЕТЫ · %s" % active_unit.display_name(), entries, menu_index, "W/S — предмет    E — использовать    Esc — назад")
	hud.refresh_units(active_unit)


func _choose_item() -> void:
	if item_choices.is_empty():
		return
	pending_action = "item"
	pending_item = item_choices[menu_index]
	_begin_target_select(str(pending_item.get("name", "ПРЕДМЕТ")), _allies())


func _begin_target_select(label: String, targets: Array[BattleUnit]) -> void:
	if targets.is_empty():
		_add_log("Нет подходящей цели.")
		phase = "command"
		menu_index = 0
		_render_commands()
		return
	target_units = targets
	phase = "target"
	menu_index = 0
	_render_target_menu(label)


func _render_target_menu(action_label: String = "ЦЕЛЬ") -> void:
	var entries: Array[String] = []
	for unit: BattleUnit in target_units:
		entries.append("%s   %d/%d" % [unit.display_name(), unit.hp(), unit.max_hp()])
	hud.set_menu("%s · выберите цель" % action_label, entries, menu_index, "W/S — цель    E — подтвердить    Esc — назад")
	hud.refresh_units(active_unit)
	_update_target_ring()


func _confirm_target() -> void:
	if input_locked or target_units.is_empty():
		return
	input_locked = true
	phase = "busy"
	if _target_ring != null:
		_target_ring.visible = false
	hud.hide_menu()
	_execute_player_action()


func _cancel_target() -> void:
	if _target_ring != null:
		_target_ring.visible = false
	if pending_action == "spell":
		phase = "spell"
		menu_index = 0
		_render_spell_menu()
	elif pending_action == "item":
		phase = "item"
		menu_index = 0
		_render_item_menu()
	else:
		pending_action = ""
		phase = "command"
		menu_index = 0
		_render_commands()


func _execute_player_action() -> void:
	var target: BattleUnit = target_units[menu_index]
	match pending_action:
		"attack":
			await _perform_attack(active_unit, target)
		"spell":
			await _perform_spell(active_unit, target, pending_spell)
		"item":
			await _perform_item(active_unit, target, pending_item)
	if phase == "busy":
		phase = "waiting"
	await get_tree().create_timer(0.2).timeout
	_check_battle_end()
	hud.refresh_units(active_unit)
	_hero_turn_done.emit()


# ---------------------------------------------------------------------------
# Actions and formulas
# ---------------------------------------------------------------------------

func _perform_attack(attacker: BattleUnit, target: BattleUnit) -> void:
	hud.show_action("%s  →  %s" % [attacker.display_name(), target.display_name()], Color("#e8b184"))
	_add_log("%s атакует %s." % [attacker.display_name(), target.display_name()])
	await _lunge(attacker, target, 0.4)
	await _hit_flash(target, Color("#e1a176"))
	var damage := _physical_damage(attacker, target)
	var dealt := target.take_damage(damage)
	_float_number(target, "-%d" % dealt, Color("#e49a7c"))
	_add_log("%s получает %d урона." % [target.display_name(), dealt])
	if not target.is_alive():
		_mark_ko(target)
	await get_tree().create_timer(0.22).timeout


func _perform_spell(caster: BattleUnit, target: BattleUnit, spell: Dictionary) -> void:
	var school := str(spell.get("school", "white"))
	var level := int(spell.get("level", 1))
	if not caster.consume_charge(school, level):
		_add_log("%s: заряды уровня исчерпаны." % caster.display_name())
		return
	var spell_name := str(spell.get("name", "Заклинание"))
	var charges_left := caster.charge(school, level)
	hud.show_action("%s: «%s»" % [caster.display_name(), spell_name], Color("#f0d38b") if school == "white" else Color("#b693eb"))
	_add_log("%s читает «%s» (ур.%d, зарядов %d)." % [caster.display_name(), spell_name, level, charges_left])
	await _spell_burst(target, Color("#f0d38b") if school == "white" else Color("#a177df"))
	if str(spell.get("type", "damage")) == "heal":
		var was_down := not target.is_alive()
		var amount := _heal_amount(caster, target, spell)
		var healed := target.heal(amount)
		_float_number(target, "+%d" % healed, Color("#9ed59b"))
		_add_log("%s восстанавливает %d HP." % [target.display_name(), healed])
		if was_down and target.is_alive():
			_revive_visual(target)
	else:
		var damage := _spell_damage(caster, target, spell)
		var dealt := target.take_damage(damage)
		_float_number(target, "-%d" % dealt, Color("#d09aef") if school == "black" else Color("#f0d38b"))
		_add_log("%s получает %d магического урона." % [target.display_name(), dealt])
		if not target.is_alive():
			_mark_ko(target)
	hud.refresh_units(active_unit)
	await get_tree().create_timer(0.25).timeout


func _perform_item(user: BattleUnit, target: BattleUnit, entry: Dictionary) -> void:
	var item_id := str(entry.get("id", ""))
	var item_name := str(entry.get("name", "предмет"))
	if not GameState.consume_inventory_item(item_id):
		_add_log("В сумке больше нет: %s." % item_name)
		return
	hud.show_action("%s: %s" % [user.display_name(), item_name], Color("#a9d492"))
	_add_log("%s использует %s на %s." % [user.display_name(), item_name, target.display_name()])
	var battle_use: Dictionary = entry.get("battle_use", {})
	var was_down := not target.is_alive()
	var amount := _item_heal(user, battle_use)
	var healed := target.heal(amount)
	_float_number(target, "+%d" % healed, Color("#9ed59b"))
	_add_log("%s восстанавливает %d HP." % [target.display_name(), healed])
	if was_down and target.is_alive():
		_revive_visual(target)
	await _spell_burst(target, Color("#a7c783"))
	await get_tree().create_timer(0.2).timeout


func _physical_damage(attacker: BattleUnit, target: BattleUnit) -> int:
	var a_stats := attacker.stats()
	var t_stats := target.stats()
	var row_dealt := _row_dealt(attacker)
	var row_taken := _row_taken(target)
	var variance := int(combat.get("variance", {}).get("physical", 0))
	var inputs := {
		"attack": float(a_stats.get("attack", 0)),
		"defense": float(t_stats.get("defense", 0)),
		"variance": float(rng.randi_range(-variance, variance)),
		"row_mult": row_dealt * row_taken
	}
	var raw := GameState.eval_combat_formula("physical_damage", inputs)
	var rules: Dictionary = combat.get("rules", {})
	return maxi(int(rules.get("min_damage", 1)), roundi(raw))


func _spell_damage(caster: BattleUnit, target: BattleUnit, spell: Dictionary) -> int:
	var c_stats := caster.stats()
	var t_stats := target.stats()
	var variance := int(combat.get("variance", {}).get("magic", 0))
	var inputs := {
		"magic": float(c_stats.get("magic", 0)),
		"spell_power": float(spell.get("power", 0)),
		"defense": float(t_stats.get("defense", 0)),
		"variance": float(rng.randi_range(-variance, variance)),
		"row_mult": _row_dealt(caster)
	}
	var raw := GameState.eval_combat_formula("spell_damage", inputs)
	var rules: Dictionary = combat.get("rules", {})
	return maxi(int(rules.get("min_damage", 1)), roundi(raw))


func _heal_amount(caster: BattleUnit, _target: BattleUnit, spell: Dictionary) -> int:
	var c_stats := caster.stats()
	var variance := int(combat.get("variance", {}).get("heal", 0))
	var inputs := {
		"magic": float(c_stats.get("magic", 0)),
		"spell_power": float(spell.get("power", 0)),
		"variance": float(rng.randi_range(-variance, variance))
	}
	var rules: Dictionary = combat.get("rules", {})
	return maxi(int(rules.get("min_heal", 1)), roundi(GameState.eval_combat_formula("heal", inputs)))


func _item_heal(_user: BattleUnit, battle_use: Dictionary) -> int:
	var variance := int(combat.get("variance", {}).get("item", 0))
	var inputs := {
		"item_power": float(battle_use.get("power", 0)),
		"variance": float(rng.randi_range(-variance, variance))
	}
	var rules: Dictionary = combat.get("rules", {})
	return maxi(int(rules.get("min_heal", 1)), roundi(GameState.eval_combat_formula("item_heal", inputs)))


func _row_dealt(unit: BattleUnit) -> float:
	var mult: Dictionary = combat.get("row", {}).get("damage_dealt", {})
	return float(mult.get(unit.row(), 1.0))


func _row_taken(unit: BattleUnit) -> float:
	var mult: Dictionary = combat.get("row", {}).get("melee_damage_taken", {})
	return float(mult.get(unit.row(), 1.0))


# ---------------------------------------------------------------------------
# Enemy turns
# ---------------------------------------------------------------------------

func _run_enemy_turn(unit: BattleUnit) -> void:
	input_locked = true
	phase = "busy"
	hud.hide_menu()
	hud.show_action("ХОД ПРОТИВНИКА: %s" % unit.display_name(), Color("#e39a86"))
	hud.refresh_units(unit)
	hud.set_turn_order(turn_order, turn_cursor)
	_update_unit_labels()
	await get_tree().create_timer(0.45).timeout
	var spell_list := unit.castable_spells()
	var cast_chance := float(combat.get("enemy_ai", {}).get("cast_chance", 0.0))
	var living_heroes := _living(heroes)
	if living_heroes.is_empty():
		return
	if not spell_list.is_empty() and rng.randf() < cast_chance:
		var spell: Dictionary = spell_list[rng.randi_range(0, spell_list.size() - 1)]
		var target: BattleUnit = living_heroes[rng.randi_range(0, living_heroes.size() - 1)]
		await _perform_spell(unit, target, spell)
	else:
		var target: BattleUnit = _weighted_hero_target()
		await _perform_attack(unit, target)
	hud.refresh_units(unit)
	_check_battle_end()
	await get_tree().create_timer(0.2).timeout


func _weighted_hero_target() -> BattleUnit:
	var living := _living(heroes)
	if living.is_empty():
		return null
	var weights: Dictionary = combat.get("row", {}).get("enemy_melee_target_weight", {})
	var total := 0.0
	for unit: BattleUnit in living:
		total += maxf(0.01, float(weights.get(unit.row(), 1.0)))
	var roll := rng.randf_range(0.0, total)
	var cursor := 0.0
	for unit: BattleUnit in living:
		cursor += maxf(0.01, float(weights.get(unit.row(), 1.0)))
		if roll <= cursor:
			return unit
	return living[living.size() - 1]


func _attempt_flee() -> void:
	input_locked = true
	phase = "busy"
	hud.hide_menu()
	var party_agi := _average_agility(heroes)
	var enemy_agi := _average_agility(enemies)
	var inputs := {"party_agility": party_agi, "enemy_agility": enemy_agi}
	var rules: Dictionary = combat.get("rules", {})
	var chance := clampf(
		GameState.eval_combat_formula("flee_chance", inputs),
		float(rules.get("flee_min_chance", 0.1)),
		float(rules.get("flee_max_chance", 0.9))
	)
	await get_tree().create_timer(0.3).timeout
	var roll := flee_roll_override if flee_roll_override >= 0.0 else rng.randf()
	if roll <= chance:
		_add_log(GameState.get_combat_ui("flee_success", "Отряд отступает с моста."))
		phase = "fled"
		battle_over = true
		if _active_ring != null:
			_active_ring.visible = false
		if _target_ring != null:
			_target_ring.visible = false
		hud.show_action("ОТСТУПЛЕНИЕ", GOLD)
		hud.show_center("ОТСТУПЛЕНИЕ", "Отряд покидает мост.", "", GOLD)
		_hero_turn_done.emit()
		await get_tree().create_timer(0.6).timeout
		await _finish_battle("fled")
	else:
		_add_log(GameState.get_combat_ui("flee_fail", "Отступление не удалось."))
		await get_tree().create_timer(0.25).timeout
		phase = "command"
		input_locked = false
		_render_commands()
		# A failed escape still consumes the turn.
		_hero_turn_done.emit()


func _average_agility(units: Array[BattleUnit]) -> float:
	var total := 0.0
	var count := 0
	for unit: BattleUnit in units:
		if not unit.is_alive():
			continue
		total += float(unit.agility())
		count += 1
	if count <= 0:
		return 0.0
	return total / float(count)


func _check_battle_end() -> bool:
	if battle_over:
		return true
	if _living(enemies).is_empty():
		_victory()
		return true
	if _living(heroes).is_empty():
		_defeat()
		return true
	return false


func _victory() -> void:
	if battle_over:
		return
	battle_over = true
	phase = "victory"
	input_locked = false
	if _active_ring != null:
		_active_ring.visible = false
	if _target_ring != null:
		_target_ring.visible = false
	hud.hide_menu()
	hud.refresh_units(null)
	var xp_gain := 0
	var gold_gain := 0
	for unit: BattleUnit in enemies:
		xp_gain += unit.xp_reward()
		gold_gain += unit.gold_reward()
	GameState.add_battle_rewards(xp_gain, gold_gain)
	_add_log("Победа! Опыт +%d, золото +%d." % [xp_gain, gold_gain])
	hud.show_center(
		GameState.get_combat_ui("victory", "ПОБЕДА"),
		"Опыт: +%d\nЗолото: +%d %s" % [xp_gain, gold_gain, GameState.currency_short()],
		GameState.get_combat_ui("continue", "E — продолжить"),
		Color("#a8d38d")
	)
	_end_mode = "victory"


func _defeat() -> void:
	if battle_over:
		return
	battle_over = true
	phase = "defeat"
	input_locked = false
	if _active_ring != null:
		_active_ring.visible = false
	if _target_ring != null:
		_target_ring.visible = false
	hud.hide_menu()
	hud.refresh_units(null)
	_add_log("Партия погибла на северном мосту.")
	hud.show_center(
		GameState.get_combat_ui("defeat", "ПАРТИЯ ПОГИБЛА"),
		GameState.get_combat_ui("defeat_hint", "Последний ночлег вернёт отряд в строй."),
		GameState.get_combat_ui("continue", "E — продолжить"),
		Color("#e08a7c")
	)
	_end_mode = "defeat"


func _confirm_end() -> void:
	if _end_mode.is_empty() or _finished:
		return
	input_locked = true
	await hud.fade_to_black(0.3)
	if _finished:
		return
	_finished = true
	battle_finished.emit({"result": _end_mode})


func _finish_battle(result: String) -> void:
	if _finished:
		return
	await hud.fade_to_black(0.3)
	if _finished:
		return
	_finished = true
	battle_finished.emit({"result": result})


# ---------------------------------------------------------------------------
# Presentation helpers
# ---------------------------------------------------------------------------

func _add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 4:
		_log_lines.pop_front()
	if hud != null:
		var visible_lines: Array[String] = []
		for line: String in _log_lines:
			visible_lines.append(line)
		hud.set_log_lines(visible_lines)


func _lunge(attacker: BattleUnit, target: BattleUnit, distance: float) -> void:
	if attacker.visual == null or target.visual == null:
		return
	var start := attacker.base_position
	var toward := target.base_position - start
	toward.y = 0.0
	if toward.length_squared() < 0.001:
		return
	toward = toward.normalized() * distance
	var tw := create_tween()
	tw.tween_property(attacker.visual, "position", start + toward, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(attacker.visual, "position", start, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


func _hit_flash(target: BattleUnit, color: Color) -> void:
	if target.visual == null:
		return
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.65
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mesh.material_override = mat
	mesh.position = target.base_position + Vector3(0.0, 1.05, 0.0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mesh, "scale", Vector3(1.7, 1.7, 1.7), 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	await tw.finished
	mesh.queue_free()


func _spell_burst(target: BattleUnit, color: Color) -> void:
	await _hit_flash(target, color)
	await get_tree().create_timer(0.05).timeout


func _float_number(target: BattleUnit, text: String, color: Color) -> void:
	if target.visual == null:
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 54
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color("#17120e")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.position = target.base_position + Vector3(0.0, 2.3, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 0.8, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(label.queue_free)


func _mark_ko(unit: BattleUnit) -> void:
	_add_log("%s повержен." % unit.display_name())
	hud.show_action("%s повержен" % unit.display_name(), Color("#b58a80"))
	if _target_ring != null:
		_target_ring.visible = false
	if unit.visual != null:
		unit.visual.set_fallen_tint(true)
		var tw := create_tween()
		tw.tween_property(unit.visual, "rotation_degrees", Vector3(0.0, unit.visual.rotation_degrees.y, -78.0 if unit.is_hero else 78.0), 0.3)
	_update_unit_label(unit)
	_add_fallen_marker(unit)
	hud.refresh_units(active_unit)


func _revive_visual(unit: BattleUnit) -> void:
	if unit.visual == null:
		return
	unit.visual.set_fallen_tint(false)
	var tw := create_tween()
	tw.tween_property(unit.visual, "rotation_degrees", Vector3(0.0, unit.visual.rotation_degrees.y, 0.0), 0.3)
	_update_unit_label(unit)
	_remove_fallen_marker(unit)
	hud.refresh_units(active_unit)


func _add_fallen_marker(unit: BattleUnit) -> void:
	if _fallen_markers.has(unit) or unit.visual == null:
		return
	var marker := Node3D.new()
	marker.name = "FallenMarker"
	marker.position = unit.base_position + Vector3(0.62 if unit.is_hero else -0.62, 0.0, 0.28)
	add_child(marker)
	var stone := MeshLib.material("#504844", 0.96)
	var gold := MeshLib.material("#8f7652", 0.8)
	MeshLib.add_box(marker, Vector3(0.2, 0.95, 0.14), Vector3(0.0, 0.48, 0.0), stone, "FallenCross")
	MeshLib.add_box(marker, Vector3(0.62, 0.16, 0.14), Vector3(0.0, 0.62, 0.0), stone, "FallenCross")
	MeshLib.add_box(marker, Vector3(0.82, 0.1, 0.28), Vector3(0.0, 0.05, 0.0), gold, "FallenBase")
	MeshLib.add_sphere(marker, 0.06, Vector3(0.0, 0.88, 0.1), MeshLib.emissive("#b87565", 1.0), "FallenEmber", -1.0, 6)
	_fallen_markers[unit] = marker


func _remove_fallen_marker(unit: BattleUnit) -> void:
	if not _fallen_markers.has(unit):
		return
	var marker: Node3D = _fallen_markers[unit]
	_fallen_markers.erase(unit)
	marker.queue_free()


func _allies() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit: BattleUnit in heroes:
		result.append(unit)
	return result


func _living(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit: BattleUnit in units:
		if unit.is_alive():
			result.append(unit)
	return result


# ---------------------------------------------------------------------------
# Test hooks
# ---------------------------------------------------------------------------

func test_move_selection(delta: int) -> void:
	if phase == "command":
		menu_index = wrapi(menu_index + delta, 0, 4)
		_render_commands()
	elif phase == "spell":
		menu_index = wrapi(menu_index + delta, 0, maxi(1, spell_choices.size()))
		_render_spell_menu()
	elif phase == "item":
		menu_index = wrapi(menu_index + delta, 0, maxi(1, item_choices.size()))
		_render_item_menu()
	elif phase == "target":
		menu_index = wrapi(menu_index + delta, 0, maxi(1, target_units.size()))
		_render_target_menu()


func test_confirm_selection() -> void:
	if phase == "command":
		_choose_command(menu_index)
	elif phase == "spell":
		_choose_spell()
	elif phase == "item":
		_choose_item()
	elif phase == "target":
		_confirm_target()
	elif phase == "victory" or phase == "defeat":
		_confirm_end()


func test_cancel_selection() -> void:
	if phase == "target":
		_cancel_target()
	elif phase == "spell" or phase == "item":
		phase = "command"
		menu_index = 0
		_render_commands()


func get_hero_units() -> Array[BattleUnit]:
	return heroes


func is_target_ring_visible() -> bool:
	return _target_ring.visible if _target_ring != null else false


func get_unit_label_text(unit: BattleUnit) -> String:
	var label: Label3D = _unit_labels.get(unit, null)
	return label.text if label != null else ""


func get_fallen_marker_count() -> int:
	return _fallen_markers.size()


func get_enemy_units() -> Array[BattleUnit]:
	return enemies


func get_turn_order() -> Array[BattleUnit]:
	return turn_order
