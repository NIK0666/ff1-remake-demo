class_name ChaosShrineBuilder
extends LocationBase
## Two-floor Chaos Shrine. The same builder produces both floors; the floor
## number, room, chest, door, stairs, boss and altar positions are data-driven.

var _floor: int = 1
var _room_min: Vector2 = Vector2(-13.0, -15.0)
var _room_max: Vector2 = Vector2(13.0, 15.0)
var _wall_height: float = 6.8

var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _wall_dark: StandardMaterial3D
var _trim_mat: StandardMaterial3D
var _accent_mat: StandardMaterial3D
var _accent_glow: StandardMaterial3D
var _iron: StandardMaterial3D

var _chest_lid: Node3D
var _chest_interactable: Interactable
var _door_pivots: Array[Node3D] = []
var _door_collision: StaticBody3D
var _door_interactable: Interactable
var _stairs_up_interactable: Interactable
var _garland_visual: CharacterVisual
var _boss_interactable: Interactable
var _sarah_visual: CharacterVisual


func build() -> void:
	_floor = int(data.get("floor", 1))
	var room: Dictionary = data.get("room", {})
	_room_min = GameState.vec2_from_array(room.get("min", [-13.0, -15.0]))
	_room_max = GameState.vec2_from_array(room.get("max", [13.0, 15.0]))
	_wall_height = float(room.get("height", 6.8))
	name = "ChaosShrine_Floor%d" % _floor
	_init_materials()
	_build_room()
	if _floor == 1:
		_build_floor_one()
	else:
		_build_floor_two()
	_build_ambient_lights()
	finalize()


func _init_materials() -> void:
	var room: Dictionary = data.get("room", {})
	_floor_mat = MeshLib.material(str(room.get("floor_color", "#3e3a46")), 0.96)
	_wall_mat = MeshLib.material(str(room.get("wall_color", "#57515f")), 0.95)
	_wall_dark = MeshLib.material(str(room.get("wall_color", "#57515f")).to_lower(), 0.98)
	_trim_mat = MeshLib.material(str(room.get("trim_color", "#a98b58")), 0.45, 0.35)
	_accent_mat = MeshLib.material(str(room.get("accent_color", "#8e5bd6")), 0.65, 0.12)
	_accent_glow = MeshLib.emissive(str(room.get("accent_color", "#8e5bd6")), 1.7)
	_iron = MeshLib.material("#302b35", 0.5, 0.45)


func _build_room() -> void:
	var width := _room_max.x - _room_min.x
	var depth := _room_max.y - _room_min.y
	var center := (_room_min + _room_max) * 0.5
	# Dais/floor.
	MeshLib.add_box(self, Vector3(width, 0.35, depth), Vector3(center.x, -0.175, center.y), _floor_mat, "ShrineFloor")
	MeshLib.add_box(self, Vector3(width + 0.9, 0.22, depth + 0.9), Vector3(center.x, -0.36, center.y), _wall_dark, "ShrineFloorBase")
	# Inlaid stone border and central ritual circle.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.35, 0.035, depth - 1.8), Vector3(center.x + side * (width * 0.5 - 0.9), 0.02, center.y), _trim_mat, "ShrineFloorBorder")
		MeshLib.add_box(self, Vector3(width - 1.8, 0.035, 0.35), Vector3(center.x, 0.02, center.y + side * (depth * 0.5 - 0.9)), _trim_mat, "ShrineFloorBorder")
	# Flagstone seams and a dark central aisle.
	var seam_mat := MeshLib.material("#3c3545", 0.98)
	for x: float in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0]:
		MeshLib.add_box(self, Vector3(0.04, 0.015, depth - 2.2), Vector3(x, 0.012, center.y), seam_mat, "ShrineFloorSeam", Vector3.ZERO, false)
	for z: float in [-12.0, -9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0, 12.0]:
		MeshLib.add_box(self, Vector3(width - 2.2, 0.015, 0.04), Vector3(center.x, 0.012, z), seam_mat, "ShrineFloorSeam", Vector3.ZERO, false)
	var aisle_mat := MeshLib.material("#292331", 0.96)
	MeshLib.add_box(self, Vector3(4.0, 0.03, depth - 3.2), Vector3(center.x, 0.02, center.y), aisle_mat, "ShrineCentralAisle")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.09, 0.04, depth - 3.2), Vector3(center.x + side * 2.05, 0.035, center.y), _trim_mat, "ShrineAisleTrim")
	_add_floor_sigil(Vector3(center.x, 0.025, center.y - 1.0), 3.0)
	# Outer walls.
	var wall_t := 0.8
	MeshLib.add_box(self, Vector3(width + wall_t * 2.0, _wall_height, wall_t), Vector3(center.x, _wall_height * 0.5, _room_min.y - wall_t * 0.5), _wall_mat, "ShrineWallNorth")
	MeshLib.add_box(self, Vector3(width + wall_t * 2.0, _wall_height, wall_t), Vector3(center.x, _wall_height * 0.5, _room_max.y + wall_t * 0.5), _wall_mat, "ShrineWallSouth")
	MeshLib.add_box(self, Vector3(wall_t, _wall_height, depth + wall_t * 2.0), Vector3(_room_min.x - wall_t * 0.5, _wall_height * 0.5, center.y), _wall_mat, "ShrineWallWest")
	MeshLib.add_box(self, Vector3(wall_t, _wall_height, depth + wall_t * 2.0), Vector3(_room_max.x + wall_t * 0.5, _wall_height * 0.5, center.y), _wall_mat, "ShrineWallEast")
	MeshLib.add_box_collider(self, Vector3(width + 2.0, _wall_height, 1.0), Vector3(center.x, _wall_height * 0.5, _room_min.y - 0.5), "ShrineWallNorthSolid")
	MeshLib.add_box_collider(self, Vector3(width + 2.0, _wall_height, 1.0), Vector3(center.x, _wall_height * 0.5, _room_max.y + 0.5), "ShrineWallSouthSolid")
	MeshLib.add_box_collider(self, Vector3(1.0, _wall_height, depth + 2.0), Vector3(_room_min.x - 0.5, _wall_height * 0.5, center.y), "ShrineWallWestSolid")
	MeshLib.add_box_collider(self, Vector3(1.0, _wall_height, depth + 2.0), Vector3(_room_max.x + 0.5, _wall_height * 0.5, center.y), "ShrineWallEastSolid")
	# Wall trim and pilasters.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(width + 1.4, 0.16, 0.14), Vector3(center.x, _wall_height - 0.25, _room_min.y + side * 0.0), _trim_mat, "ShrineWallTrim")
		MeshLib.add_box(self, Vector3(0.16, _wall_height - 1.0, 0.14), Vector3(_room_min.x + 0.12, _wall_height * 0.5, center.y), _trim_mat, "ShrineWallPilaster")
		MeshLib.add_box(self, Vector3(0.16, _wall_height - 1.0, 0.14), Vector3(_room_max.x - 0.12, _wall_height * 0.5, center.y), _trim_mat, "ShrineWallPilaster")
	# Columns along the side walls.
	for side: float in [-1.0, 1.0]:
		for z: float in [-8.0, -2.0, 4.0, 9.0]:
			_add_pillar(Vector3(side * (_room_max.x - 2.0), 0.0, z))
	# Wall sconces and pilasters.
	for side: float in [-1.0, 1.0]:
		for z: float in [-9.0, -2.5, 4.5, 10.0]:
			_add_wall_sconce(Vector3(side * (_room_max.x - 0.55), 2.8, z), side)
		for z: float in [-11.0, -5.0, 1.0, 7.0, 12.0]:
			MeshLib.add_box(self, Vector3(0.42, _wall_height - 0.8, 0.22), Vector3(side * (_room_max.x - 0.55), _wall_height * 0.5, z), _wall_dark, "ShrineWallPilaster")
			MeshLib.add_box(self, Vector3(0.56, 0.14, 0.34), Vector3(side * (_room_max.x - 0.55), 0.75, z), _trim_mat, "ShrineWallPilasterBase")
	# A pair of urns flanking the central aisle.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_cylinder(self, 0.34, 0.23, 0.9, Vector3(side * 2.7, 0.45, 8.0), _wall_dark, "ShrineUrn", 10)
		MeshLib.add_cylinder(self, 0.38, 0.38, 0.1, Vector3(side * 2.7, 0.88, 8.0), _trim_mat, "ShrineUrnRim", 10)
		MeshLib.add_omni_light(self, Vector3(side * 2.7, 1.2, 8.0), "#9b76cc", 0.5, 3.0, false)
	_add_wall_reliefs()
	_add_scattered_rubble()
	# A faint dust field.
	var dust := CPUParticles3D.new()
	dust.name = "ShrineDust"
	dust.amount = 48
	dust.lifetime = 10.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(width * 0.42, 3.0, depth * 0.42)
	dust.direction = Vector3(0.0, 1.0, 0.0)
	dust.spread = 35.0
	dust.gravity = Vector3(0.0, 0.02, 0.0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.08
	dust.scale_amount_min = 0.02
	dust.scale_amount_max = 0.06
	dust.color = Color(0.66, 0.55, 0.82, 0.35)
	dust.position = Vector3(center.x, 2.4, center.y)
	add_child(dust)


func _add_wall_reliefs() -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in [-6.8, -0.5, 6.2]:
			var x := side * (_room_max.x - 0.57)
			var panel := MeshLib.add_box(self, Vector3(0.08, 2.1, 1.7), Vector3(x, 2.75, z), MeshLib.material("#3b3442", 0.96), "ShrineReliefPanel")
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for edge: float in [-1.0, 1.0]:
				MeshLib.add_box(self, Vector3(0.11, 2.35, 0.12), Vector3(x - side * 0.03, 2.75, z + edge * 0.93), _trim_mat, "ShrineReliefFrame")
				MeshLib.add_box(self, Vector3(0.11, 0.12, 1.96), Vector3(x - side * 0.03, 2.75 + edge * 1.12, z), _trim_mat, "ShrineReliefFrame")
			var sigil := MeshLib.add_cylinder(self, 0.23, 0.23, 0.06, Vector3(x - side * 0.07, 2.75, z), _accent_glow, "ShrineReliefSigil", 8, Vector3(0.0, 0.0, 90.0))
			sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for i in 4:
				var angle := TAU * float(i) / 4.0 + PI * 0.25
				var rune := MeshLib.add_box(self, Vector3(0.06, 0.22, 0.07), Vector3(x - side * 0.08, 2.75 + sin(angle) * 0.55, z + cos(angle) * 0.55), _accent_glow, "ShrineReliefRune")
				rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_scattered_rubble() -> void:
	var rubble_mat := MeshLib.material("#4a434e", 0.98)
	for pos: Vector3 in [
		Vector3(-11.0, 0.0, -12.2), Vector3(-10.2, 0.0, -11.6),
		Vector3(10.8, 0.0, -11.4), Vector3(11.4, 0.0, 10.8),
		Vector3(-11.1, 0.0, 11.0), Vector3(-10.5, 0.0, 11.7)
	]:
		MeshLib.add_box(self, Vector3(0.55, 0.2, 0.4), pos + Vector3(0.0, 0.1, 0.0), rubble_mat, "ShrineRubble", Vector3(0.0, fmod(pos.x * 13.0, 45.0), 0.0))
		MeshLib.add_sphere(self, 0.16, pos + Vector3(0.4, 0.14, 0.2), rubble_mat, "ShrineRubble", 0.6, 6)
	# A few old bones near the side walls.
	for side: float in [-1.0, 1.0]:
		for z: float in [-10.6, 9.4]:
			var bone := MeshLib.add_cylinder(self, 0.055, 0.04, 1.0, Vector3(side * 10.9, 0.06, z), MeshLib.material("#b3a38b", 0.9), "ShrineBone", 6, Vector3(90.0, 0.0, 20.0 * side))
			bone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_candle_cluster(pos: Vector3, count: int = 3) -> void:
	var wax := MeshLib.material("#d8c9a8", 0.85)
	for i in count:
		var offset := Vector3((float(i) - float(count - 1) * 0.5) * 0.23, 0.0, float((i % 2) - 0) * 0.12)
		var height := 0.34 + float(i % 3) * 0.12
		MeshLib.add_cylinder(self, 0.045, 0.055, height, pos + offset + Vector3(0.0, height * 0.5, 0.0), wax, "ShrineCandle", 7)
		MeshLib.add_sphere(self, 0.055, pos + offset + Vector3(0.0, height + 0.05, 0.0), _accent_glow, "ShrineCandleFlame", 0.16, 6)
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 0.6, 0.0), "#e2bc82", 0.8, 3.2, false)


func _add_guardian_statue(pos: Vector3, facing_side: float) -> void:
	# Tall rune-carved sentinel obelisks: they read clearly from the top-down
	# camera and flank the altar/door without looking like furniture.
	var stone := MeshLib.material("#655d6c", 0.96)
	var stone_light := MeshLib.material("#83788b", 0.93)
	var dark := MeshLib.material("#38333f", 0.98)
	MeshLib.add_box(self, Vector3(1.45, 0.46, 1.45), pos + Vector3(0.0, 0.23, 0.0), dark, "ShrineSentinelPlinth")
	MeshLib.add_box(self, Vector3(1.2, 0.16, 1.2), pos + Vector3(0.0, 0.52, 0.0), _trim_mat, "ShrineSentinelPlinthTrim")
	MeshLib.add_box(self, Vector3(0.92, 0.35, 0.92), pos + Vector3(0.0, 0.77, 0.0), stone_light, "ShrineSentinelBase")
	MeshLib.add_box(self, Vector3(0.56, 2.6, 0.56), pos + Vector3(0.0, 2.18, 0.0), stone, "ShrineSentinelShaft")
	MeshLib.add_box(self, Vector3(0.7, 0.2, 0.7), pos + Vector3(0.0, 3.45, 0.0), _trim_mat, "ShrineSentinelCap")
	MeshLib.add_pyramid(self, Vector2(0.64, 0.64), 0.65, pos + Vector3(0.0, 3.82, 0.0), stone_light, "ShrineSentinelCrown")
	for y: float in [1.05, 2.35, 3.25]:
		MeshLib.add_box(self, Vector3(0.65, 0.08, 0.65), pos + Vector3(0.0, y, 0.0), _trim_mat, "ShrineSentinelBand")
	# A glowing vertical rune slit and a cold crown light.
	MeshLib.add_box(self, Vector3(0.06, 1.25, 0.08), pos + Vector3(0.0, 1.8, 0.31), _accent_glow, "ShrineSentinelRune")
	var crown_light := MeshLib.add_sphere(self, 0.13, pos + Vector3(0.0, 3.55, 0.28), _accent_glow, "ShrineSentinelEye", -1.0, 8)
	crown_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var side_rune := MeshLib.add_box(self, Vector3(0.06, 0.32, 0.5), pos + Vector3(facing_side * 0.31, 2.8, 0.0), _accent_glow, "ShrineSentinelSideRune")
	side_rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshLib.add_box_collider(self, Vector3(1.35, 0.8, 1.35), pos + Vector3(0.0, 0.4, 0.0), "ShrineSentinelSolid")
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 2.1, 0.5), "#9a76b9", 0.45, 2.8, false)


func _add_floor_sigil(center: Vector3, radius: float) -> void:
	var disc := MeshLib.add_cylinder(self, radius, radius, 0.025, center, MeshLib.transparent("#9a6fd8", 0.16, true), "ShrineSigilDisc", 48)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat := _accent_glow
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	torus.rings = 40
	torus.ring_segments = 8
	var ring := MeshInstance3D.new()
	ring.name = "ShrineSigilRing"
	ring.mesh = torus
	ring.material_override = ring_mat
	ring.position = center + Vector3(0.0, 0.02, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var rune := MeshLib.add_box(self, Vector3(0.3, 0.02, 0.08), center + Vector3(cos(angle) * (radius - 0.55), 0.035, sin(angle) * (radius - 0.55)), ring_mat, "ShrineSigilRune", Vector3(0.0, -rad_to_deg(angle), 0.0), false)
		rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_pillar(pos: Vector3) -> void:
	MeshLib.add_box(self, Vector3(1.0, 0.35, 1.0), pos + Vector3(0.0, 0.18, 0.0), _wall_dark, "ShrinePillarBase")
	MeshLib.add_cylinder(self, 0.38, 0.32, 4.2, pos + Vector3(0.0, 2.3, 0.0), _wall_mat, "ShrinePillar", 10)
	MeshLib.add_cylinder(self, 0.46, 0.46, 0.18, pos + Vector3(0.0, 4.45, 0.0), _trim_mat, "ShrinePillarCap", 10)
	MeshLib.add_box(self, Vector3(0.95, 0.18, 0.95), pos + Vector3(0.0, 4.55, 0.0), _wall_dark, "ShrinePillarAbacus")
	MeshLib.add_box_collider(self, Vector3(0.85, 4.7, 0.85), pos + Vector3(0.0, 2.35, 0.0), "ShrinePillarSolid")


func _add_wall_sconce(pos: Vector3, side: float) -> void:
	var bracket := MeshLib.add_box(self, Vector3(0.38, 0.08, 0.08), pos + Vector3(0.18 * side, 0.0, 0.0), _iron, "ShrineSconceBracket")
	bracket.rotation_degrees = Vector3(0.0, 0.0, 20.0 * side)
	MeshLib.add_box(self, Vector3(0.3, 0.34, 0.3), pos + Vector3(0.25 * side, 0.15, 0.0), _iron, "ShrineSconceCage")
	MeshLib.add_sphere(self, 0.13, pos + Vector3(0.25 * side, 0.18, 0.0), _accent_glow, "ShrineSconceFlame", 0.24, 8)
	MeshLib.add_omni_light(self, pos + Vector3(0.25 * side, 0.2, 0.0), "#a87add", 0.9, 4.5, false)


func _build_ambient_lights() -> void:
	MeshLib.add_omni_light(self, Vector3(0.0, 3.5, 3.0), "#7d62ae", 0.8, 14.0, false)
	MeshLib.add_omni_light(self, Vector3(0.0, 2.8, -8.0), "#9b5f83", 0.9, 10.0, false)


# ---------------------------------------------------------------------------
# Floor one: chest, locked door and stairs
# ---------------------------------------------------------------------------

func _build_floor_one() -> void:
	var chest_cfg: Dictionary = data.get("chest", {})
	var chest_pos: Vector2 = GameState.vec2_from_array(chest_cfg.get("position", [-9.2, -2.0]))
	_build_chest(Vector3(chest_pos.x, 0.0, chest_pos.y), chest_cfg)
	var door_cfg: Dictionary = data.get("locked_door", {})
	var door_pos: Vector2 = GameState.vec2_from_array(door_cfg.get("position", [0.0, -11.5]))
	_build_locked_door(door_pos, float(door_cfg.get("width", 4.0)), door_cfg)
	var stairs_cfg: Dictionary = data.get("stairs_up", {})
	var stairs_pos: Vector2 = GameState.vec2_from_array(stairs_cfg.get("position", [0.0, -13.2]))
	_build_up_stairs(Vector3(stairs_pos.x, 0.0, stairs_pos.y), stairs_cfg, GameState.has_flag(str(door_cfg.get("flag", "shrine_door_opened"))))
	var exit_cfg: Dictionary = data.get("exit", {})
	var exit_pos: Vector2 = GameState.vec2_from_array(exit_cfg.get("position", [0.0, 13.2]))
	_build_down_stairs(Vector3(exit_pos.x, 0.0, exit_pos.y), exit_cfg, "E — Выйти из святилища")
	# Light pools around the key landmarks.
	_add_brazier(Vector3(-6.4, 0.0, 2.6))
	_add_brazier(Vector3(6.4, 0.0, 10.2))
	MeshLib.add_omni_light(self, Vector3(-8.8, 1.8, 2.5), "#d4b06b", 1.0, 5.0, false)
	MeshLib.add_omni_light(self, Vector3(0.0, 2.2, 11.5), "#a87ad6", 1.0, 6.0, false)
	_build_chest_alcove(Vector3(chest_pos.x, 0.0, chest_pos.y))
	_add_guardian_statue(Vector3(-6.3, 0.0, -6.5), 1.0)
	_add_guardian_statue(Vector3(6.3, 0.0, -6.5), -1.0)
	_add_candle_cluster(Vector3(-2.9, 0.0, -10.7), 3)
	_add_candle_cluster(Vector3(2.9, 0.0, -10.7), 3)
	_add_candle_cluster(Vector3(-10.6, 0.0, 2.2), 2)


func _build_chest_alcove(chest_pos: Vector3) -> void:
	var wall_x := _room_min.x + 0.62
	var z := chest_pos.z
	MeshLib.add_box(self, Vector3(0.08, 2.7, 1.9), Vector3(wall_x - 0.18, 1.55, z), MeshLib.material("#332c3a", 0.98), "ShrineChestAlcoveBack")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.42, 3.0, 0.38), Vector3(wall_x, 1.5, z + side * 1.08), _wall_dark, "ShrineChestAlcovePillar")
		MeshLib.add_box(self, Vector3(0.56, 0.16, 0.5), Vector3(wall_x, 3.02, z + side * 1.08), _trim_mat, "ShrineChestAlcoveCap")
		MeshLib.add_box(self, Vector3(0.1, 2.2, 0.1), Vector3(wall_x - 0.15, 1.55, z + side * 0.82), _trim_mat, "ShrineChestAlcoveTrim")
	MeshLib.add_box(self, Vector3(0.46, 0.28, 2.55), Vector3(wall_x, 3.18, z), _trim_mat, "ShrineChestAlcoveLintel")
	var rune := MeshLib.add_cylinder(self, 0.24, 0.24, 0.06, Vector3(wall_x - 0.24, 2.55, z), _accent_glow, "ShrineChestAlcoveRune", 8, Vector3(0.0, 0.0, 90.0))
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var alcove_light := MeshLib.add_omni_light(self, Vector3(wall_x + 0.4, 1.9, z), "#d5ae72", 1.1, 4.5, false)
	alcove_light.name = "ShrineChestAlcoveLight"


func _build_chest(pos: Vector3, cfg: Dictionary) -> void:
	var opened := GameState.has_flag(str(cfg.get("flag", "shrine_chest_opened")))
	MeshLib.add_box(self, Vector3(1.5, 0.85, 1.0), pos + Vector3(0.0, 0.45, 0.0), MeshLib.material("#4b3326", 0.9), "ShrineChestBody")
	MeshLib.add_box(self, Vector3(1.62, 0.1, 1.12), pos + Vector3(0.0, 0.88, 0.0), _trim_mat, "ShrineChestRim")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.1, 0.88, 1.04), pos + Vector3(side * 0.71, 0.45, 0.0), _iron, "ShrineChestBand")
		MeshLib.add_box(self, Vector3(1.35, 0.06, 0.1), pos + Vector3(0.0, 0.4, side * 0.52), _trim_mat, "ShrineChestTrim")
	MeshLib.add_box(self, Vector3(0.16, 0.22, 0.06), pos + Vector3(0.0, 0.56, 0.52), _trim_mat, "ShrineChestLock")
	MeshLib.add_sphere(self, 0.055, pos + Vector3(0.0, 0.56, 0.56), _accent_glow, "ShrineChestKeyhole", -1.0, 6)
	_chest_lid = Node3D.new()
	_chest_lid.name = "ChestLidPivot"
	_chest_lid.position = pos + Vector3(0.0, 0.92, -0.5)
	if opened:
		_chest_lid.rotation_degrees.x = -68.0
	add_child(_chest_lid)
	MeshLib.add_box(_chest_lid, Vector3(1.52, 0.22, 1.0), Vector3(0.0, 0.08, 0.5), MeshLib.material("#5a3d2b", 0.88), "ShrineChestLid")
	MeshLib.add_box(_chest_lid, Vector3(1.58, 0.08, 0.28), Vector3(0.0, 0.2, 0.5), _trim_mat, "ShrineChestLidBand")
	MeshLib.add_box_collider(self, Vector3(1.7, 1.1, 1.2), pos + Vector3(0.0, 0.55, 0.0), "ShrineChestSolid")
	if not opened:
		_chest_interactable = add_interactable("chest", str(cfg.get("prompt", "E — Сундук")), {
			"chest_id": str(cfg.get("id", "shrine_chest")),
			"item_id": str(cfg.get("item", "chaos_key")),
			"flag": str(cfg.get("flag", "shrine_chest_opened"))
		}, pos + Vector3(0.0, 0.0, 1.1))
		_chest_interactable.focus_offset = Vector3(0.0, 0.9, 0.0)


func _build_locked_door(door_pos: Vector2, door_width: float, cfg: Dictionary) -> void:
	var opened := GameState.has_flag(str(cfg.get("flag", "shrine_door_opened")))
	var z := door_pos.y
	var half := door_width * 0.5
	# Interior partition with a central doorway.
	MeshLib.add_box(self, Vector3(absf(_room_min.x - (-half)) - 0.2, _wall_height, 0.55), Vector3((_room_min.x - half) * 0.5, _wall_height * 0.5, z), _wall_mat, "ShrineDoorWall")
	MeshLib.add_box(self, Vector3(absf(_room_max.x - half) - 0.2, _wall_height, 0.55), Vector3((_room_max.x + half) * 0.5, _wall_height * 0.5, z), _wall_mat, "ShrineDoorWall")
	MeshLib.add_box_collider(self, Vector3(absf(_room_min.x - (-half)) - 0.2, _wall_height, 0.7), Vector3((_room_min.x - half) * 0.5, _wall_height * 0.5, z), "ShrineDoorWallSolid")
	MeshLib.add_box_collider(self, Vector3(absf(_room_max.x - half) - 0.2, _wall_height, 0.7), Vector3((_room_max.x + half) * 0.5, _wall_height * 0.5, z), "ShrineDoorWallSolid")
	# Frame.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.35, 3.2, 0.75), Vector3(side * (half + 0.15), 1.6, z), _wall_dark, "ShrineDoorJamb")
		MeshLib.add_box(self, Vector3(0.55, 0.18, 0.9), Vector3(side * (half + 0.15), 3.2, z), _trim_mat, "ShrineDoorCap")
	MeshLib.add_box(self, Vector3(door_width + 0.6, 0.28, 0.6), Vector3(0.0, 3.4, z), _trim_mat, "ShrineDoorLintel")
	# Two wooden leaves, each hinged at the frame.
	var leaf_width := half - 0.05
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "ShrineDoorPivot%s" % ("L" if side < 0.0 else "R")
		pivot.position = Vector3(side * (half - 0.05), 0.0, z)
		if opened:
			pivot.rotation_degrees.y = -105.0 * side
		add_child(pivot)
		_door_pivots.append(pivot)
		MeshLib.add_box(pivot, Vector3(leaf_width, 2.9, 0.18), Vector3(-side * leaf_width * 0.5, 1.45, 0.0), MeshLib.material("#2d2428", 0.92), "ShrineDoorLeaf")
		for band in 4:
			MeshLib.add_box(pivot, Vector3(leaf_width, 0.11, 0.22), Vector3(-side * leaf_width * 0.5, 0.5 + float(band) * 0.62, 0.0), _iron, "ShrineDoorBand")
		MeshLib.add_box(pivot, Vector3(leaf_width * 0.75, 0.05, 0.24), Vector3(-side * leaf_width * 0.5, 1.4, 0.0), _trim_mat, "ShrineDoorRune")
	if not opened:
		_door_collision = MeshLib.add_box_collider(self, Vector3(door_width, 3.0, 0.6), Vector3(0.0, 1.5, z), "ShrineLockedDoorSolid")
		_door_interactable = add_interactable("locked_door", str(cfg.get("prompt", "E — Запертая дверь")), {
			"door_id": str(cfg.get("id", "shrine_door")),
			"key_id": str(cfg.get("key", "chaos_key")),
			"flag": str(cfg.get("flag", "shrine_door_opened"))
		}, Vector3(0.0, 0.0, z + 1.15))
		_door_interactable.focus_offset = Vector3(0.0, 1.3, 0.0)
	# A faint sigil above the door turns from red to gold once opened.
	var sigil := MeshLib.add_cylinder(self, 0.25, 0.25, 0.08, Vector3(0.0, 2.6, z + 0.34), _accent_glow if not opened else _trim_mat, "ShrineDoorSigil", 8, Vector3(90.0, 0.0, 0.0))
	sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_up_stairs(pos: Vector3, cfg: Dictionary, door_open: bool) -> void:
	# Steps beyond the locked door.
	for i in 5:
		MeshLib.add_box(self, Vector3(4.2, 0.22, 0.75), pos + Vector3(0.0, 0.11 + float(i) * 0.2, 1.9 - float(i) * 0.7), _wall_dark, "ShrineUpStep")
	var arch_dark := MeshLib.add_box(self, Vector3(4.2, 3.1, 0.25), pos + Vector3(0.0, 1.55, -1.8), MeshLib.material("#120f16", 0.98), "ShrineUpPortal")
	arch_dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := MeshLib.add_box(self, Vector3(3.4, 2.4, 0.06), pos + Vector3(0.0, 1.4, -1.65), _accent_glow, "ShrineUpGlow")
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stairs_up_interactable = add_interactable("door", str(cfg.get("prompt", "E — Подняться на второй этаж")), {
		"target": str(cfg.get("target", "chaos_shrine_2")),
		"spawn": str(cfg.get("spawn", "from_floor1"))
	}, pos + Vector3(0.0, 0.0, 1.2))
	_stairs_up_interactable.enabled = door_open
	_stairs_up_interactable.focus_offset = Vector3(0.0, 1.0, 0.0)


func _build_down_stairs(pos: Vector3, cfg: Dictionary, prompt: String) -> void:
	for i in 4:
		MeshLib.add_box(self, Vector3(4.2, 0.2, 0.65), pos + Vector3(0.0, -0.1 - float(i) * 0.16, -1.5 + float(i) * 0.55), _wall_dark, "ShrineDownStep")
	var dark := MeshLib.add_box(self, Vector3(4.2, 2.2, 0.2), pos + Vector3(0.0, 1.1, -1.9), MeshLib.material("#0e0b12", 0.98), "ShrineDownPortal")
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var point := add_interactable("door", prompt, {
		"target": str(cfg.get("target", "town")),
		"spawn": str(cfg.get("spawn", "shrine_return"))
	}, pos + Vector3(0.0, 0.0, 1.0))
	point.focus_offset = Vector3(0.0, 0.8, 0.0)


# ---------------------------------------------------------------------------
# Floor two: altar, Garland and Sarah
# ---------------------------------------------------------------------------

func _build_floor_two() -> void:
	var altar_cfg: Dictionary = data.get("altar", {})
	var altar_pos: Vector2 = GameState.vec2_from_array(altar_cfg.get("position", [0.0, -11.9]))
	_build_altar(Vector3(altar_pos.x, 0.0, altar_pos.y))
	var exit_cfg: Dictionary = data.get("exit", {})
	var exit_pos: Vector2 = GameState.vec2_from_array(exit_cfg.get("position", [0.0, 12.0]))
	_build_down_stairs(Vector3(exit_pos.x, 0.0, exit_pos.y), exit_cfg, "E — Спуститься на первый этаж")
	_add_brazier(Vector3(-4.6, 0.0, 9.4))
	_add_brazier(Vector3(4.6, 0.0, 9.4))
	MeshLib.add_omni_light(self, Vector3(0.0, 2.6, 4.0), "#b28bd0", 0.8, 10.0, false)
	_build_altar_backdrop(Vector3(altar_pos.x, 0.0, altar_pos.y))
	_add_guardian_statue(Vector3(-5.7, 0.0, -8.7), 1.0)
	_add_guardian_statue(Vector3(5.7, 0.0, -8.7), -1.0)
	_add_candle_cluster(Vector3(-2.1, 0.0, -10.5), 3)
	_add_candle_cluster(Vector3(2.1, 0.0, -10.5), 3)
	if not GameState.has_flag("garland_defeated"):
		_build_garland()
	else:
		_reveal_sarah()
	# The altar and its crystal carry the chamber's storytelling.
	MeshLib.add_omni_light(self, Vector3(0.0, 3.0, -7.0), "#b87ad5", 0.8, 9.0, false)


func _build_altar_backdrop(altar_pos: Vector3) -> void:
	var z := _room_min.y + 0.52
	# A massive ritual arch behind the altar.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.8, 4.8, 0.72), Vector3(side * 3.55, 2.4, z), _wall_dark, "ShrineAltarArchPillar")
		MeshLib.add_box(self, Vector3(1.1, 0.28, 1.0), Vector3(side * 3.55, 4.82, z), _trim_mat, "ShrineAltarArchCap")
		MeshLib.add_box(self, Vector3(0.22, 3.3, 0.1), Vector3(side * 3.55, 2.5, z + 0.4), _trim_mat, "ShrineAltarArchTrim")
	MeshLib.add_box(self, Vector3(8.2, 0.55, 0.9), Vector3(0.0, 5.05, z), _trim_mat, "ShrineAltarArchLintel")
	MeshLib.add_box(self, Vector3(5.9, 2.1, 0.08), Vector3(0.0, 3.5, z - 0.06), MeshLib.emissive("#3d2757", 0.7), "ShrineAltarArchGlow")
	# The old idol watching over the altar: a horned stone mask with burning eyes.
	var stone := MeshLib.material("#5a5360", 0.96)
	var stone_dark := MeshLib.material("#37313f", 0.98)
	var eye := MeshLib.emissive("#d88aa8", 1.6)
	MeshLib.add_box(self, Vector3(2.8, 1.2, 0.7), Vector3(0.0, 3.2, z + 0.15), stone, "ShrineIdolCrown")
	MeshLib.add_sphere(self, 0.72, Vector3(0.0, 2.65, z + 0.2), stone, "ShrineIdolHead", 0.9, 10)
	MeshLib.add_box(self, Vector3(1.25, 0.56, 0.7), Vector3(0.0, 2.18, z + 0.18), stone_dark, "ShrineIdolJaw")
	for side: float in [-1.0, 1.0]:
		var horn := MeshLib.add_pyramid(self, Vector2(0.28, 0.28), 1.1, Vector3(side * 0.82, 3.75, z + 0.12), stone_dark, "ShrineIdolHorn")
		horn.rotation_degrees.z = -26.0 * side
		MeshLib.add_sphere(self, 0.11, Vector3(side * 0.31, 2.74, z + 0.84), eye, "ShrineIdolEye", -1.0, 8)
		var wing := MeshLib.add_box(self, Vector3(0.16, 1.6, 0.9), Vector3(side * 1.55, 3.0, z + 0.05), stone, "ShrineIdolWing")
		wing.rotation_degrees.z = 22.0 * side
	# Two long crimson banners flank the idol.
	var cloth := MeshLib.material("#6e2c46", 0.92)
	var gold := MeshLib.material("#c5a05f", 0.8, 0.15)
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(1.25, 2.85, 0.07), Vector3(side * 2.35, 3.05, z + 0.42), cloth, "ShrineAltarBanner")
		MeshLib.add_box(self, Vector3(1.35, 0.12, 0.1), Vector3(side * 2.35, 4.51, z + 0.43), gold, "ShrineAltarBannerRod")
		MeshLib.add_box(self, Vector3(0.2, 0.2, 0.09), Vector3(side * 2.35, 3.15, z + 0.49), gold, "ShrineAltarBannerEmblem")
	# Candle banks on the altar steps.
	for side: float in [-1.0, 1.0]:
		_add_candle_cluster(Vector3(side * 2.55, 0.75, altar_pos.z + 0.9), 3)
	MeshLib.add_omni_light(self, Vector3(0.0, 3.0, z + 1.1), "#b77ed0", 1.1, 7.0, false)


func _build_altar(pos: Vector3) -> void:
	MeshLib.add_box(self, Vector3(6.0, 0.6, 3.0), pos + Vector3(0.0, 0.3, 0.0), _wall_dark, "ShrineAltarDais")
	MeshLib.add_box(self, Vector3(5.2, 0.18, 2.2), pos + Vector3(0.0, 0.68, 0.0), _trim_mat, "ShrineAltarTop")
	MeshLib.add_box(self, Vector3(2.2, 1.2, 1.0), pos + Vector3(0.0, 1.25, 0.0), _wall_mat, "ShrineAltarBlock")
	MeshLib.add_box(self, Vector3(2.5, 0.18, 1.3), pos + Vector3(0.0, 1.9, 0.0), _trim_mat, "ShrineAltarCornice")
	MeshLib.add_sphere(self, 0.34, pos + Vector3(0.0, 2.25, 0.0), _accent_glow, "ShrineAltarCrystal", 0.8, 12)
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 2.2, 0.0), "#d18fba", 1.7, 8.0, false)
	for side: float in [-1.0, 1.0]:
		_add_brazier(pos + Vector3(side * 3.3, 0.0, 1.3))
	for i in 8:
		var angle := TAU * float(i) / 8.0
		MeshLib.add_box(self, Vector3(0.08, 0.012, 0.5), pos + Vector3(cos(angle) * 4.0, 0.03, sin(angle) * 2.2), _accent_glow, "ShrineAltarRune", Vector3(0.0, -rad_to_deg(angle), 0.0), false)


func _build_garland() -> void:
	var boss_cfg: Dictionary = data.get("boss", {})
	var boss_pos: Vector2 = GameState.vec2_from_array(boss_cfg.get("position", [0.0, -9.6]))
	var template: Dictionary = GameState.combat.get("enemies", {}).get("garland", {})
	var visual_data: Dictionary = template.duplicate(true)
	visual_data["id"] = "garland_exploration"
	_garland_visual = CharacterVisual.new()
	_garland_visual.name = "Garland"
	_garland_visual.setup_enemy(visual_data)
	_garland_visual.position = Vector3(boss_pos.x, 0.0, boss_pos.y)
	_garland_visual.set_facing(Vector3(0.0, 0.0, 1.0), true)
	add_child(_garland_visual)
	MeshLib.add_omni_light(self, Vector3(boss_pos.x, 2.4, boss_pos.y), "#b25c65", 1.2, 6.0, false)
	_boss_interactable = add_interactable("boss", str(boss_cfg.get("prompt", "E — Гарланд")), {
		"boss_id": str(boss_cfg.get("id", "garland")),
		"encounter": str(boss_cfg.get("encounter", "garland"))
	}, Vector3(boss_pos.x, 0.0, boss_pos.y + 1.4))
	_boss_interactable.focus_offset = Vector3(0.0, 1.2, 0.0)


func _reveal_sarah() -> void:
	var sarah_cfg: Dictionary = data.get("sarah", {})
	var sarah_pos: Vector2 = GameState.vec2_from_array(sarah_cfg.get("position", [0.0, -11.2]))
	_sarah_visual = CharacterVisual.new()
	_sarah_visual.name = "Sarah"
	_sarah_visual.setup_sarah({"primary": "#e8e2f2", "accent": "#d5b16b", "dark": "#68758f"})
	_sarah_visual.position = Vector3(sarah_pos.x, 0.0, sarah_pos.y)
	_sarah_visual.set_facing(Vector3(0.0, 0.0, 1.0), true)
	add_child(_sarah_visual)
	var halo_mat := MeshLib.emissive("#f4dfa5", 1.2)
	var halo := MeshLib.add_cylinder(self, 0.8, 0.8, 0.03, Vector3(sarah_pos.x, 0.03, sarah_pos.y), halo_mat, "SarahHalo", 24)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshLib.add_omni_light(self, Vector3(sarah_pos.x, 2.2, sarah_pos.y), "#f1dfae", 1.4, 6.0, false)


func _add_brazier(pos: Vector3) -> void:
	MeshLib.add_cylinder(self, 0.18, 0.24, 0.8, pos + Vector3(0.0, 0.4, 0.0), _iron, "ShrineBrazierStem", 8)
	MeshLib.add_cylinder(self, 0.42, 0.32, 0.25, pos + Vector3(0.0, 0.9, 0.0), _iron, "ShrineBrazierBowl", 10)
	MeshLib.add_sphere(self, 0.24, pos + Vector3(0.0, 1.08, 0.0), _accent_glow, "ShrineBrazierFlame", 0.48, 8)
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 1.1, 0.0), "#b875dc", 1.4, 5.0, false)


# ---------------------------------------------------------------------------
# Runtime changes from Main
# ---------------------------------------------------------------------------

func on_chest_opened(_chest_id: String) -> void:
	if _chest_lid != null:
		var tw := create_tween()
		tw.tween_property(_chest_lid, "rotation_degrees:x", -68.0, 0.35)
	if _chest_interactable != null:
		_chest_interactable.enabled = false


func unlock_door(door_id: String) -> void:
	var cfg: Dictionary = data.get("locked_door", {})
	if not door_id.is_empty() and door_id != str(cfg.get("id", "")):
		return
	if _door_collision != null:
		_door_collision.queue_free()
		_door_collision = null
	if _door_interactable != null:
		_door_interactable.enabled = false
	for i in _door_pivots.size():
		var pivot: Node3D = _door_pivots[i]
		var target := 105.0 if i == 0 else -105.0
		var tw := create_tween()
		tw.tween_property(pivot, "rotation_degrees:y", target, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _stairs_up_interactable != null:
		_stairs_up_interactable.enabled = true
	var door_pos: Vector2 = GameState.vec2_from_array(cfg.get("position", [0.0, -11.5]))
	MeshLib.add_omni_light(self, Vector3(0.0, 2.4, door_pos.y + 1.0), "#d3b36f", 1.0, 5.0, false)


func on_boss_defeated() -> void:
	if _boss_interactable != null:
		_boss_interactable.enabled = false
	if _garland_visual != null:
		var tw := create_tween()
		tw.tween_property(_garland_visual, "rotation_degrees:z", 80.0, 0.4)
		tw.tween_callback(_garland_visual.hide)
	if _sarah_visual == null:
		_reveal_sarah()
