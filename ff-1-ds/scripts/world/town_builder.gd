class_name TownBuilder
extends LocationBase
## Cornelia — the outdoor slice: walls, castle exterior, six houses,
## fountain plaza, north gate and the bridge over the river.

var _cobble_mat: ShaderMaterial
var _grass_mat: ShaderMaterial
var _water_mat: ShaderMaterial

var _stone: StandardMaterial3D
var _stone_light: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _stone_warm: StandardMaterial3D
var _roof_blue: StandardMaterial3D
var _roof_dark: StandardMaterial3D
var _gold: StandardMaterial3D
var _iron: StandardMaterial3D
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _window_light: StandardMaterial3D
var _window_dark: StandardMaterial3D
var _foliage: Array[StandardMaterial3D] = []
var _flower_mats: Array[StandardMaterial3D] = []
var _flag_blue: StandardMaterial3D
var _flag_red: StandardMaterial3D
var _flag_gold: StandardMaterial3D

var _walls_cfg: Dictionary
var _castle_cfg: Dictionary
var _bridge_cfg: Dictionary
var _river_cfg: Dictionary
var _gate_cfg: Dictionary


func build() -> void:
	name = "Cornelia"
	_walls_cfg = data["walls"]
	_castle_cfg = data["castle"]
	_bridge_cfg = data["bridge"]
	_river_cfg = data["river"]
	_gate_cfg = data["north_gate"]
	_init_materials()
	_build_ground_and_river()
	_build_town_walls()
	_build_north_gate()
	_build_castle_exterior()
	_build_castle_south_gate()
	_build_houses()
	_build_plaza_props()
	_build_bridge()
	_build_shrine_entrance()
	_build_atmosphere_and_scenery()
	_build_npcs()
	_build_door_interactions()
	finalize()


func _init_materials() -> void:
	_cobble_mat = _shader_material("res://shaders/cobblestone.gdshader")
	_grass_mat = _shader_material("res://shaders/grass.gdshader")
	_water_mat = _shader_material("res://shaders/water.gdshader", {
		"shallow_color": Color(str(_river_cfg["shallow_color"])),
		"deep_color": Color(str(_river_cfg["deep_color"])),
		"foam_color": Color(str(_river_cfg["foam_color"]))
	})
	_stone = MeshLib.material("#978f80", 0.93)
	_stone_light = MeshLib.material("#b5aa97", 0.91)
	_stone_dark = MeshLib.material("#625c51", 0.95)
	_stone_warm = MeshLib.material("#a99b88", 0.92)
	_roof_blue = MeshLib.material("#3d5c86", 0.66, 0.08)
	_roof_dark = MeshLib.material("#384552", 0.74, 0.05)
	_gold = MeshLib.material("#c3a35c", 0.36, 0.55)
	_iron = MeshLib.material("#3e4448", 0.52, 0.65)
	_wood = MeshLib.material("#6d4b32", 0.88)
	_wood_dark = MeshLib.material("#3f2d22", 0.94)
	_window_light = MeshLib.emissive("#ffc67c", 1.7)
	_window_dark = MeshLib.material("#1c262b", 0.4, 0.1)
	_foliage = [
		MeshLib.material("#3f6042", 0.96),
		MeshLib.material("#53764c", 0.96),
		MeshLib.material("#6d8349", 0.96),
		MeshLib.material("#8b8646", 0.96)
	]
	_flower_mats = [
		MeshLib.material("#b85c60", 0.9),
		MeshLib.material("#d6b662", 0.9),
		MeshLib.material("#d8d0ba", 0.9)
	]
	_flag_blue = MeshLib.material("#315179", 0.85)
	_flag_red = MeshLib.material("#7d2937", 0.9)
	_flag_gold = MeshLib.material("#c5a45c", 0.5, 0.3)


func _shader_material(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	for key: String in params.keys():
		mat.set_shader_parameter(key, params[key])
	return mat


func _add_ground_plane(size: Vector2, pos: Vector3, mat: Material, node_name: String, subdiv: int = 1) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = subdiv
	mesh.subdivide_depth = subdiv
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Ground, water and banks
# ---------------------------------------------------------------------------

func _build_ground_and_river() -> void:
	var river_south := float(_river_cfg["z_max"])
	var river_north := float(_river_cfg["z_min"])
	var grass_width := float(data["terrain"]["grass_size"][0])
	var quay: Dictionary = data["terrain"]["quay"]

	# The grass is split by the river so the water really sits below the banks.
	_add_ground_plane(Vector2(grass_width, 126.5), Vector3(0.0, -0.025, 26.2), _grass_mat, "SouthMeadow")
	_add_ground_plane(Vector2(grass_width, 95.0), Vector3(0.0, -0.025, -116.9), _grass_mat, "NorthMeadow")
	_add_ground_plane(Vector2(grass_width - 8.0, river_south - river_north), Vector3(0.0, -2.05, (river_south + river_north) * 0.5), MeshLib.material("#26312c", 1.0), "RiverBed")
	_add_ground_plane(Vector2(float(_river_cfg["width"]), river_south - river_north + 0.3), Vector3(0.0, float(_river_cfg["water_y"]), (river_south + river_north) * 0.5), _water_mat, "River", 48)

	# Stone quays frame the river and hide the ground seam.
	var quay_height := float(quay["height"])
	var quay_thick := float(quay["thickness"])
	for z: float in [float(quay["south_z"]), float(quay["north_z"])]:
		MeshLib.add_box(self, Vector3(grass_width, quay_height, quay_thick), Vector3(0.0, -0.86, z), _stone_dark, "QuayWall")
		MeshLib.add_box(self, Vector3(grass_width, 0.22, quay_thick + 0.45), Vector3(0.0, 0.06, z), _stone_light, "QuayCap")
		MeshLib.add_box(self, Vector3(grass_width, 0.4, quay_thick + 0.18), Vector3(0.0, -0.18, z + (0.18 if z < -50.0 else -0.18)), _stone, "QuayCourse")

	var plaza: Dictionary = data["terrain"]["plaza"]
	_add_ground_plane(Vector2(plaza["size"][0], plaza["size"][1]), Vector3(plaza["center"][0], 0.012, plaza["center"][1]), _cobble_mat, "PlazaCobbles")
	var road: Dictionary = data["terrain"]["north_road"]
	_add_ground_plane(Vector2(road["size"][0], road["size"][1]), Vector3(road["center"][0], 0.012, road["center"][1]), _cobble_mat, "NorthRoad")

	var approach: Vector2 = GameState.vec2_from_array(_castle_cfg["approach_center"])
	MeshLib.add_box(self, Vector3(float(_castle_cfg["approach_size"][0]), 0.05, float(_castle_cfg["approach_size"][1])), Vector3(approach.x, 0.02, approach.y), _stone_warm, "CastleApron")
	var forecourt: Dictionary = data["terrain"]["castle_forecourt"]
	_add_ground_plane(Vector2(forecourt["size"][0], forecourt["size"][1]), Vector3(forecourt["center"][0], 0.014, forecourt["center"][1]), _cobble_mat, "CastleForecourt")
	var castle_path: Dictionary = data["terrain"]["castle_path"]
	_add_ground_plane(Vector2(castle_path["size"][0], castle_path["size"][1]), Vector3(castle_path["center"][0], 0.012, castle_path["center"][1]), _cobble_mat, "CastleWalk")

	var path_width := float(data["terrain"]["house_path_width"])
	var path_length := float(data["terrain"]["house_path_length"])
	for house: Dictionary in data["houses"]:
		var door_pos := GameState.vec2_from_array(house["door"]["position"])
		var out_dir := GameState.vec2_from_array(house["door"]["facing"])
		var center := door_pos + out_dir * path_length * 0.5
		var size := Vector2(path_width, path_length) if absf(out_dir.y) > 0.5 else Vector2(path_length, path_width)
		_add_ground_plane(size, Vector3(center.x, 0.011, center.y), _cobble_mat, "Path_%s" % str(house["id"]))

	var landing: Dictionary = _bridge_cfg["far_landing"]
	_add_ground_plane(Vector2(landing["size"][0], landing["size"][1]), Vector3(landing["center"][0], 0.012, landing["center"][1]), _cobble_mat, "FarLanding")

	_build_river_reeds()


func _build_river_reeds() -> void:
	var reed_mat := MeshLib.material("#75815a", 0.95)
	var reed_tip := MeshLib.material("#a39362", 0.9)
	var rocks := [
		Vector3(-27.0, -1.28, -40.5), Vector3(31.0, -1.28, -43.0), Vector3(-48.0, -1.28, -55.0),
		Vector3(16.0, -1.28, -63.0), Vector3(45.0, -1.28, -50.0), Vector3(-12.0, -1.28, -65.0)
	]
	for i in rocks.size():
		var r: Vector3 = rocks[i]
		var s := 0.26 + float(i % 3) * 0.12
		var rock := MeshLib.add_sphere(self, s, r, _stone_dark, "RiverRock", s * 1.3, 7)
		rock.scale = Vector3(1.5, 0.45, 1.0)
	for z: float in [-36.0, -69.0]:
		for i in 9:
			var x := -54.0 + float(i) * 13.2
			if absf(x) < 7.0:
				continue
			MeshLib.add_cylinder(self, 0.035, 0.012, 1.2 + float(i % 3) * 0.35, Vector3(x, -0.65, z + (0.65 if z < -50.0 else -0.65)), reed_mat, "Reed", 4)
			MeshLib.add_cylinder(self, 0.055, 0.02, 0.26, Vector3(x + 0.02, -0.02, z + (0.65 if z < -50.0 else -0.65)), reed_tip, "ReedTip", 4)


# ---------------------------------------------------------------------------
# Town walls
# ---------------------------------------------------------------------------

func _build_town_walls() -> void:
	var min_x := float(_walls_cfg["min"][0])
	var min_z := float(_walls_cfg["min"][1])
	var max_x := float(_walls_cfg["max"][0])
	var max_z := float(_walls_cfg["max"][1])
	var height := float(_walls_cfg["height"])
	var thick := float(_walls_cfg["thickness"])
	var gate_half := float(_gate_cfg["opening_width"]) * 0.5

	_add_wall_box(Vector3((max_x - min_x) * 0.5 * 2.0, height, thick), Vector3(0.0, height * 0.5, max_z), true, 0)
	_add_wall_box(Vector3(thick, height, max_z - min_z), Vector3(max_x, height * 0.5, 0.0), false, 0)
	_add_wall_box(Vector3(thick, height, max_z - min_z), Vector3(min_x, height * 0.5, 0.0), false, 0)
	_add_wall_box(Vector3(-gate_half - min_x, height, thick), Vector3((min_x - gate_half) * 0.5, height * 0.5, min_z), true, 0)
	_add_wall_box(Vector3(max_x - gate_half, height, thick), Vector3((max_x + gate_half) * 0.5, height * 0.5, min_z), true, 0)

	for pos: Vector3 in [
		Vector3(min_x, 0.0, min_z), Vector3(max_x, 0.0, min_z),
		Vector3(min_x, 0.0, max_z), Vector3(max_x, 0.0, max_z)
	]:
		_round_tower(pos, float(_walls_cfg["tower_radius"]), float(_walls_cfg["tower_height"]), float(_walls_cfg["tower_roof_height"]), _flag_blue, true, 1.25)


func _add_wall_box(size: Vector3, center: Vector3, along_x: bool, _unused: int) -> void:
	MeshLib.add_box(self, size, center, _stone, "Wall")
	MeshLib.add_box_collider(self, size, center, "WallSolid")
	var plinth := Vector3(size.x + 0.45, 0.65, size.z + 0.45)
	MeshLib.add_box(self, plinth, Vector3(center.x, 0.325, center.z), _stone_dark, "WallPlinth")
	var course := Vector3(size.x + 0.15, 0.15, size.z + 0.15)
	MeshLib.add_box(self, course, Vector3(center.x, float(_walls_cfg["height"]) * 0.63, center.z), _stone_light, "WallCourse")
	_add_battlements_along(center, size, along_x, float(_walls_cfg["height"]), float(_walls_cfg["thickness"]), float(_walls_cfg["battlement_width"]), float(_walls_cfg["battlement_height"]))


func _add_battlements_along(center: Vector3, size: Vector3, along_x: bool, wall_height: float, thickness: float, width: float, height: float) -> void:
	var step := width * 2.05
	var half := (size.x if along_x else size.z) * 0.5
	var count: int = maxi(2, int((half * 2.0) / step))
	var start := -half + step * 0.5
	for i in count:
		var offset := start + float(i) * step
		var pos := center
		pos.y = wall_height + height * 0.5
		var merlon_size := Vector3(width, height, thickness * 0.56)
		if along_x:
			pos.x += offset
		else:
			pos.z += offset
			merlon_size = Vector3(thickness * 0.56, height, width)
		MeshLib.add_box(self, merlon_size, pos, _stone_light, "Merlon")


func _round_tower(pos: Vector3, radius: float, height: float, roof_height: float, flag_mat: StandardMaterial3D, add_collision: bool, roof_scale: float = 1.0) -> void:
	MeshLib.add_cylinder(self, radius + 0.18, radius + 0.08, 0.9, Vector3(pos.x, 0.45, pos.z), _stone_dark, "TowerPlinth", 16)
	MeshLib.add_cylinder(self, radius, radius * 0.94, height, Vector3(pos.x, height * 0.5, pos.z), _stone, "TowerBody", 16)
	# Masonry bands keep the towers from reading as blank cylinders.
	for band: float in [2.7, 5.4, 8.1, 10.8]:
		if band >= height:
			continue
		MeshLib.add_cylinder(self, radius + 0.06, radius + 0.06, 0.12, Vector3(pos.x, band, pos.z), _stone_dark, "TowerCourse", 16)
	MeshLib.add_cylinder(self, radius + 0.12, radius + 0.12, 0.18, Vector3(pos.x, height - 0.12, pos.z), _stone_light, "TowerRing", 16)
	var cone := MeshLib.add_cylinder(self, radius + 0.6, 0.04, roof_height, Vector3(pos.x, height + roof_height * 0.5, pos.z), _roof_blue, "TowerRoof", 16)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for t: float in [0.22, 0.46, 0.7]:
		var rr := (radius + 0.6) * (1.0 - t) + 0.03
		MeshLib.add_cylinder(self, rr, rr * 0.96, 0.055, Vector3(pos.x, height + roof_height * t, pos.z), _roof_dark, "RoofShingle", 16)
	MeshLib.add_cylinder(self, radius + 0.63, radius + 0.6, 0.13, Vector3(pos.x, height + 0.04, pos.z), _stone_light, "RoofEave", 16)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var merlon_pos := Vector3(pos.x + cos(angle) * (radius + 0.02), height + 0.33, pos.z + sin(angle) * (radius + 0.02))
		MeshLib.add_box(self, Vector3(0.5, 0.55, 0.4), merlon_pos, _stone_light, "TowerMerlon", Vector3(0.0, -rad_to_deg(angle), 0.0))
	for i in 4:
		var angle := -PI * 0.55 + float(i) * PI * 0.36 + 0.6
		var slit_pos := Vector3(pos.x + cos(angle) * (radius - 0.02), 3.9 + float(i) * 1.4, pos.z + sin(angle) * (radius - 0.02))
		MeshLib.add_box(self, Vector3(0.2, 0.8, 0.08), slit_pos, _window_dark, "ArrowSlit", Vector3(0.0, -rad_to_deg(angle), 0.0))
	var pole := MeshLib.add_cylinder(self, 0.045, 0.035, 2.1, Vector3(pos.x, height + roof_height + 0.85, pos.z), _iron, "Flagpole", 6)
	_add_flag(Vector3(pos.x, height + roof_height + 1.55, pos.z), flag_mat, 1.0, 0.42)
	# A little corbel balcony near the top.
	MeshLib.add_cylinder(self, radius + 0.28, radius + 0.05, 0.35, Vector3(pos.x, height + 0.1, pos.z), _stone_dark, "TowerCorbel", 16)
	if add_collision:
		MeshLib.add_cylinder_collider(self, radius + 0.05, height, Vector3(pos.x, height * 0.5, pos.z), "TowerSolid")


func _add_flag(attach: Vector3, cloth_mat: StandardMaterial3D, length: float, height: float) -> void:
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = attach
	flag.rotation_degrees = Vector3(0.0, -18.0, 0.0)
	add_child(flag)
	MeshLib.add_box(flag, Vector3(length, height, 0.03), Vector3(length * 0.5, -height * 0.5, 0.0), cloth_mat, "Cloth")
	MeshLib.add_box(flag, Vector3(length * 0.22, height * 0.22, 0.04), Vector3(length * 0.42, -height * 0.5, 0.0), _flag_gold, "Emblem")
	MeshLib.add_box(flag, Vector3(length * 0.32, 0.035, 0.04), Vector3(length * 0.65, -height * 0.42, 0.0), _flag_gold, "Stripe")


# ---------------------------------------------------------------------------
# North gate and bridge
# ---------------------------------------------------------------------------

func _build_north_gate() -> void:
	var z := float(_gate_cfg["z"])
	var tower_x := float(_gate_cfg["tower_x"])
	var tower_radius := float(_gate_cfg["tower_radius"])
	var tower_height := float(_gate_cfg["tower_height"])
	var roof_height := float(_gate_cfg["roof_height"])
	var arch_height := float(_gate_cfg["arch_height"])
	var depth := float(_gate_cfg["arch_depth"])
	for side: float in [-1.0, 1.0]:
		_round_tower(Vector3(tower_x * side, 0.0, z), tower_radius, tower_height, roof_height, _flag_blue, true, 1.15)
	# Bridge entrance posts and lamp marks are added by the bridge builder.
	# Gatehouse block above the arch.
	MeshLib.add_box(self, Vector3(15.0, 4.4, depth + 0.8), Vector3(0.0, tower_height - 1.7, z), _stone, "Gatehouse")
	MeshLib.add_box(self, Vector3(15.4, 0.24, depth + 1.1), Vector3(0.0, tower_height + 0.45, z), _stone_light, "GatehouseCornice")
	_add_gate_battlements(Vector3(0.0, tower_height + 0.45, z), 15.0, depth, 8)
	# Arched stone ring. Purely decorative; clearance stays generous.
	_arch_ring(Vector3(0.0, 4.15, z + depth * 0.5 + 0.03), 4.05, arch_height - 4.15, depth + 0.12, _stone_light, true)
	_arch_ring(Vector3(0.0, 4.15, z - depth * 0.5 - 0.03), 4.05, arch_height - 4.15, depth + 0.12, _stone_light, false)
	# Raised portcullis teeth above the walkway.
	for i in 7:
		var x := -3.3 + float(i) * 1.1
		MeshLib.add_box(self, Vector3(0.09, 1.8, 0.12), Vector3(x, 6.1, z + 0.05), _iron, "Portcullis")
	MeshLib.add_box(self, Vector3(7.8, 0.13, 0.16), Vector3(0.0, 5.55, z + 0.05), _iron, "PortcullisBar")
	var gate_label := MeshLib.add_label3d(self, "СЕВЕРНЫЙ МОСТ", Vector3(0.0, tower_height + 0.75, z + depth * 0.6), 30, "#f1dba8", "NorthGateSign")
	gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Wall-mounted torches.
	for side: float in [-1.0, 1.0]:
		_add_torch(Vector3(4.9 * side, 4.7, z + 1.4), true)
		_add_hanging_banner(Vector3(4.25 * side, 7.9, z + depth * 0.55), Vector3(0.0, 0.0, 0.0), _flag_blue, 1.25, 2.8)
	# Bridge entry posts.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.45, 1.45, 0.45), Vector3(3.8 * side, 0.72, z - 1.9), _stone_light, "BridgePost")
		MeshLib.add_box(self, Vector3(0.55, 0.16, 0.55), Vector3(3.8 * side, 1.52, z - 1.9), _gold, "BridgePostCap")


func _add_gate_battlements(center: Vector3, width: float, depth: float, count: int) -> void:
	var step := width / float(count)
	for i in count:
		var x := -width * 0.5 + step * (float(i) + 0.5)
		MeshLib.add_box(self, Vector3(step * 0.46, 0.75, depth * 0.62), Vector3(x, center.y + 0.43, center.z), _stone_light, "GateMerlon")


func _arch_ring(center: Vector3, radius: float, rise: float, depth: float, mat: Material, front_face: bool, axis: String = "x") -> void:
	var segments := 9
	for i in segments:
		var t := float(i + 0.5) / float(segments)
		var angle := PI * (1.0 - t)
		var py := sin(angle) * rise
		var tangent := angle + PI * 0.5
		if axis == "x":
			var px := cos(angle) * radius
			var stone := MeshLib.add_box(self, Vector3(1.32, 0.62, depth + (0.08 if front_face else 0.0)), center + Vector3(px, py, 0.0), mat, "ArchStone")
			stone.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(tangent))
		else:
			var pz := cos(angle) * radius
			var stone := MeshLib.add_box(self, Vector3(depth + (0.08 if front_face else 0.0), 0.62, 1.32), center + Vector3(0.0, py, pz), mat, "ArchStone")
			stone.rotation_degrees = Vector3(rad_to_deg(angle), 0.0, 0.0)
	# Keystone and spring stones give the opening character.
	var key_pos := center + Vector3(0.0, rise + 0.35, 0.0)
	var spring_size := Vector3(0.95, 1.1, depth + 0.08)
	if axis == "z":
		spring_size = Vector3(depth + 0.08, 1.1, 0.95)
	MeshLib.add_box(self, Vector3(0.9, 1.15, depth + 0.12) if axis == "x" else Vector3(depth + 0.12, 1.15, 0.9), key_pos, _stone_light, "Keystone")
	for side: float in [-1.0, 1.0]:
		var off := Vector3(radius * side, -0.28, 0.0) if axis == "x" else Vector3(0.0, -0.28, radius * side)
		MeshLib.add_box(self, spring_size, center + off, _stone, "SpringStone")


func _build_bridge() -> void:
	var width := float(_bridge_cfg["width"])
	var start_z := float(_bridge_cfg["start_z"])
	var end_z := float(_bridge_cfg["end_z"])
	var length := start_z - end_z
	var center_z := (start_z + end_z) * 0.5
	var deck_y := 0.0
	var deck_thick := float(_bridge_cfg["deck_thickness"])
	# Deck and side beams.
	var deck := MeshLib.add_box(self, Vector3(width, deck_thick, length), Vector3(0.0, deck_y - deck_thick * 0.5, center_z), _cobble_mat, "BridgeDeck")
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	MeshLib.add_box(self, Vector3(width + 0.55, 0.25, length), Vector3(0.0, -0.36, center_z), _stone_dark, "BridgeFascia")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.3, 0.72, length), Vector3(side * (width * 0.5 - 0.15), 0.3, center_z), _stone, "BridgeParapet")
		MeshLib.add_box(self, Vector3(0.42, 0.12, length), Vector3(side * (width * 0.5 - 0.15), 0.72, center_z), _stone_light, "BridgeRail")
		MeshLib.add_box(self, Vector3(0.33, 0.1, length), Vector3(side * (width * 0.5 - 0.15), 0.05, center_z), _stone_dark, "BridgeRailBase")
		MeshLib.add_box_collider(self, Vector3(0.42, 2.0, length), Vector3(side * (width * 0.5 - 0.1), 1.0, center_z), "BridgeRailSolid")
		var panel_count := int(length / 4.5)
		for p in panel_count:
			var pz := start_z - 2.5 - float(p) * 4.5
			if pz < end_z + 1.0:
				continue
			MeshLib.add_box(self, Vector3(0.03, 0.3, 2.4), Vector3(side * (width * 0.5 - 0.305), 0.36, pz), _stone_dark, "BridgePanel")
			MeshLib.add_box(self, Vector3(0.04, 0.5, 0.04), Vector3(side * (width * 0.5 - 0.31), 0.38, pz), _gold, "BridgePanelDiamond", Vector3(45.0, 0.0, 0.0))
		var post_step := 4.2
		var posts := int(length / post_step)
		for i in posts + 1:
			var pz := start_z - 0.6 - float(i) * post_step
			MeshLib.add_box(self, Vector3(0.44, 1.35, 0.44), Vector3(side * (width * 0.5 - 0.1), 0.78, pz), _stone, "BridgePillar")
			MeshLib.add_box(self, Vector3(0.56, 0.16, 0.56), Vector3(side * (width * 0.5 - 0.1), 1.48, pz), _gold, "BridgePillarCap")
	# Lamps on the parapet.
	var lantern_index := 0
	for z: float in _bridge_cfg["lantern_z"]:
		for side: float in [-1.0, 1.0]:
			_add_bridge_lantern(Vector3(side * (width * 0.5 - 0.1), 1.52, z), lantern_index % 2 == 0)
		lantern_index += 1
	# Piers and arch silhouettes.
	var span := length / 3.6
	for i in 3:
		var pz := start_z - length * (float(i + 1) / 4.0)
		MeshLib.add_box(self, Vector3(width + 0.7, 2.35, 1.2), Vector3(0.0, -1.2, pz), _stone_dark, "BridgePier")
		MeshLib.add_box(self, Vector3(width + 1.0, 0.22, 1.35), Vector3(0.0, -0.35, pz), _stone, "PierCap")
		var cut := MeshLib.add_box(self, Vector3(1.3, 2.3, 1.2), Vector3(0.0, -1.2, pz + 0.9), _stone_dark, "PierCutwater", Vector3(0.0, 45.0, 0.0))
		cut.scale = Vector3(0.35, 1.0, 1.0)
	# Far landing.
	var landing: Dictionary = _bridge_cfg["far_landing"]
	var lc: Vector2 = GameState.vec2_from_array(landing["center"])
	var ls: Vector2 = GameState.vec2_from_array(landing["size"])
	MeshLib.add_box(self, Vector3(ls.x + 0.4, 0.35, ls.y + 0.4), Vector3(lc.x, -0.18, lc.y), _stone_dark, "LandingBase")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.6, 1.0, ls.y), Vector3(lc.x + side * (ls.x * 0.5), 0.5, lc.y), _stone_light, "LandingWall")
		MeshLib.add_box_collider(self, Vector3(0.6, 1.6, ls.y), Vector3(lc.x + side * (ls.x * 0.5), 0.8, lc.y), "LandingWallSolid")
	# Back border and decorative archway.
	var bound_z := float(_bridge_cfg["far_boundary_z"])
	MeshLib.add_box(self, Vector3(ls.x + 1.0, 1.3, 0.7), Vector3(lc.x, 0.65, bound_z), _stone, "FarBankWall")
	MeshLib.add_box_collider(self, Vector3(ls.x + 1.0, 2.5, 0.7), Vector3(lc.x, 1.25, bound_z), "FarBankSolid")
	var arch_z := float(_bridge_cfg["arch_z"])
	# A gatehouse-scale wooden sign, not a giant portal, closes the bridge axis.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.9, 3.6, 0.9), Vector3(side * 4.6, 1.8, arch_z), _stone_light, "FarGatePost")
		MeshLib.add_box(self, Vector3(1.15, 0.24, 1.15), Vector3(side * 4.6, 3.68, arch_z), _gold, "FarGateCap")
		MeshLib.add_box_collider(self, Vector3(1.0, 3.6, 1.0), Vector3(side * 4.6, 1.8, arch_z), "FarGateSolid")
	MeshLib.add_box(self, Vector3(10.2, 0.26, 0.55), Vector3(0.0, 3.55, arch_z), _wood_dark, "FarGateBeam")
	MeshLib.add_box(self, Vector3(8.4, 1.6, 0.22), Vector3(0.0, 2.67, arch_z + 0.1), _wood, "FarGateBoard")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.1, 1.42, 0.08), Vector3(side * 4.05, 2.67, arch_z + 0.24), _gold, "FarSignTrim")
	MeshLib.add_box(self, Vector3(8.2, 0.1, 0.08), Vector3(0.0, 3.4, arch_z + 0.24), _gold, "FarSignTrim")
	MeshLib.add_box(self, Vector3(8.2, 0.1, 0.08), Vector3(0.0, 1.94, arch_z + 0.24), _gold, "FarSignTrim")
	var far_label_a := MeshLib.add_label3d(self, "СЕВЕРНЫЙ", Vector3(0.0, 2.94, arch_z + 0.8), 44, "#f4dfb0", "FarGateSignTop")
	far_label_a.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	far_label_a.pixel_size = 0.011
	far_label_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	far_label_a.width = 2000.0
	far_label_a.autowrap_mode = TextServer.AUTOWRAP_OFF
	far_label_a.no_depth_test = true
	var far_label_b := MeshLib.add_label3d(self, "ТРАКТ", Vector3(0.0, 2.42, arch_z + 0.8), 36, "#e9d19b", "FarGateSignBottom")
	far_label_b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	far_label_b.pixel_size = 0.011
	far_label_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	far_label_b.width = 2000.0
	far_label_b.autowrap_mode = TextServer.AUTOWRAP_OFF
	far_label_b.no_depth_test = true
	_add_torch(Vector3(-3.9, 2.5, arch_z + 0.8), false)
	_add_torch(Vector3(3.9, 2.5, arch_z + 0.8), false)
	# Invisible water guard on both sides of the bridge. Only the river channel:
	# town-side land must remain fully walkable.
	var water_south := float(_river_cfg["z_max"])
	var water_north := float(_river_cfg["z_min"])
	var water_block_len := water_south - water_north
	var water_center := (water_south + water_north) * 0.5
	for side: float in [-1.0, 1.0]:
		var block_x: float = side * (width * 0.5 + 37.0)
		MeshLib.add_box_collider(self, Vector3(74.0, 3.0, water_block_len), Vector3(block_x, 1.45, water_center), "WaterSolid")
	# Keep players inside the far landing.
	MeshLib.add_box_collider(self, Vector3(20.0, 3.0, 0.6), Vector3(0.0, 1.5, bound_z - 0.35), "Backstop")


func _build_shrine_entrance() -> void:
	var cfg: Dictionary = data.get("shrine_entrance", {})
	if cfg.is_empty():
		return
	var pos: Vector2 = GameState.vec2_from_array(cfg.get("position", [7.4, -72.5]))
	var center := Vector3(pos.x - 0.5, 0.0, pos.y)
	# A sunken stair mouth cut into the eastern side of the far landing.
	MeshLib.add_box(self, Vector3(3.5, 0.04, 4.0), center + Vector3(0.0, 0.035, 0.0), _window_dark, "ShrineEntranceVoid")
	for i in 4:
		MeshLib.add_box(self, Vector3(0.8, 0.16, 3.5), center + Vector3(-0.9 + float(i) * 0.62, -0.03 - float(i) * 0.12, 0.0), _stone_dark, "ShrineEntranceStep")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.5, 0.55, 0.5), center + Vector3(-1.4, 0.28, side * 1.9), _stone, "ShrineEntrancePost")
		MeshLib.add_box(self, Vector3(0.62, 0.14, 0.62), center + Vector3(-1.4, 0.61, side * 1.9), _gold, "ShrineEntrancePostCap")
		MeshLib.add_box(self, Vector3(0.18, 0.6, 3.6), center + Vector3(-1.35, 0.3, 0.0), _stone_dark, "ShrineEntranceRim")
		MeshLib.add_box(self, Vector3(3.4, 0.12, 0.16), center + Vector3(0.0, 0.07, side * 2.0), _stone_light, "ShrineEntranceRim")
	MeshLib.add_box(self, Vector3(3.1, 0.3, 0.24), center + Vector3(0.0, 3.2, -2.0), _wood_dark, "ShrineEntranceLintel")
	var glow_a := MeshLib.add_sphere(self, 0.13, center + Vector3(-1.4, 1.0, -2.0), MeshLib.emissive("#a57ae2", 2.0), "ShrineEntranceFlame", 0.26, 8)
	glow_a.scale = Vector3(0.7, 1.3, 0.7)
	var glow_b := MeshLib.add_sphere(self, 0.13, center + Vector3(-1.4, 1.0, 2.0), MeshLib.emissive("#a57ae2", 2.0), "ShrineEntranceFlame", 0.26, 8)
	glow_b.scale = Vector3(0.7, 1.3, 0.7)
	MeshLib.add_omni_light(self, center + Vector3(-0.9, 1.2, 0.0), "#9a6bd2", 1.4, 5.0, false)
	var sign := MeshLib.add_label3d(self, "СВЯТИЛИЩЕ ХАОСА", center + Vector3(0.0, 3.65, -1.8), 34, "#d7bde8", "ShrineEntranceSign")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.pixel_size = 0.009
	sign.width = 2000.0
	sign.autowrap_mode = TextServer.AUTOWRAP_OFF
	var point := add_interactable("door", str(cfg.get("prompt", "E — Святилище Хаоса")), {
		"target": str(cfg.get("target", "chaos_shrine_1")),
		"spawn": str(cfg.get("spawn", "entry"))
	}, Vector3(pos.x - 1.4, 0.0, pos.y))
	point.focus_offset = Vector3(0.0, 0.9, 0.0)


func _add_bridge_lantern(pos: Vector3, with_light: bool) -> void:
	MeshLib.add_cylinder(self, 0.055, 0.04, 1.2, pos, _iron, "LanternPost", 6)
	var housing := MeshLib.add_box(self, Vector3(0.32, 0.42, 0.32), pos + Vector3(0.0, 0.72, 0.0), _iron, "LanternHousing")
	MeshLib.add_box(self, Vector3(0.22, 0.3, 0.22), pos + Vector3(0.0, 0.72, 0.0), _window_light, "LanternGlass")
	MeshLib.add_cylinder(self, 0.14, 0.04, 0.16, pos + Vector3(0.0, 1.0, 0.0), _roof_dark, "LanternCap", 4)
	if with_light:
		MeshLib.add_omni_light(self, pos + Vector3(0.0, 0.9, 0.0), "#ffb768", 1.25, 6.5, false)


func _add_torch(pos: Vector3, shadows: bool) -> void:
	MeshLib.add_cylinder(self, 0.09, 0.05, 0.65, pos, _iron, "TorchBracket", 6, Vector3(0.0, 0.0, -18.0))
	var flame := MeshLib.add_sphere(self, 0.16, pos + Vector3(0.0, 0.5, 0.0), MeshLib.emissive("#ff9d45", 2.4), "TorchFlame", 0.42, 8)
	flame.scale = Vector3(0.75, 1.25, 0.75)
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 0.7, 0.0), "#ff9f50", 1.2, 5.5, shadows)


# ---------------------------------------------------------------------------
# Castle exterior
# ---------------------------------------------------------------------------

func _build_castle_exterior() -> void:
	var cmin: Vector2 = GameState.vec2_from_array(_castle_cfg["min"])
	var cmax: Vector2 = GameState.vec2_from_array(_castle_cfg["max"])
	var gate: Dictionary = _castle_cfg["gate"]
	var gate_pos: Vector2 = GameState.vec2_from_array(gate["position"])
	var wall_height := float(_castle_cfg["wall_height"])
	var gate_width := float(gate["width"])
	var gate_height := float(gate["height"])
	var east_x := cmax.x
	var tower_radius := float(_castle_cfg["tower_radius"])
	var tower_height := float(_castle_cfg["tower_height"])
	var tower_roof := float(_castle_cfg["tower_roof_height"])
	var tower_z: Array = _castle_cfg["tower_z"]

	# One solid body keeps the castle exterior non-enterable; the gate is an
	# interaction that swaps the location while GameState keeps the party.
	var body_size := Vector3(cmax.x - cmin.x, 24.0, cmax.y - cmin.y)
	MeshLib.add_box_collider(self, body_size, Vector3((cmin.x + cmax.x) * 0.5, 12.0, (cmin.y + cmax.y) * 0.5), "CastleBodySolid")

	# Curtain walls (the east wall has a gate opening).
	_castle_curtain(Vector3((cmin.x + cmax.x) * 0.5, wall_height * 0.5, cmin.y), Vector3(cmax.x - cmin.x, wall_height, 2.2), true)
	_castle_curtain(Vector3((cmin.x + cmax.x) * 0.5, wall_height * 0.5, cmax.y), Vector3(cmax.x - cmin.x, wall_height, 2.2), true)
	_castle_curtain(Vector3(cmin.x, wall_height * 0.5, (cmin.y + cmax.y) * 0.5), Vector3(2.2, wall_height, cmax.y - cmin.y), false)
	var seg1 := gate_pos.y - gate_width * 0.5 - cmin.y
	var seg2 := cmax.y - (gate_pos.y + gate_width * 0.5)
	_castle_curtain(Vector3(east_x, wall_height * 0.5, cmin.y + seg1 * 0.5), Vector3(2.2, wall_height, seg1), false)
	_castle_curtain(Vector3(east_x, wall_height * 0.5, gate_pos.y + gate_width * 0.5 + seg2 * 0.5), Vector3(2.2, wall_height, seg2), false)

	# Twin gate towers.
	for z: float in tower_z:
		_round_tower(Vector3(east_x - 0.2, 0.0, z), tower_radius, tower_height, tower_roof, _flag_blue, true, 1.3)
		_add_hanging_banner(Vector3(east_x + tower_radius - 0.45, 8.5, z), Vector3.ZERO, _flag_red, 1.1, 3.3)
	# Gatehouse mass above the gate.
	MeshLib.add_box(self, Vector3(3.8, 6.4, gate_width + 2.7), Vector3(east_x - 0.2, gate_height + 2.3, gate_pos.y), _stone, "CastleGatehouse")
	MeshLib.add_box(self, Vector3(4.2, 0.28, gate_width + 3.2), Vector3(east_x - 0.1, gate_height + 5.55, gate_pos.y), _stone_light, "CastleGatehouseTrim")
	for band_y: float in [7.4, 9.8, 11.9]:
		MeshLib.add_box(self, Vector3(3.95, 0.11, gate_width + 2.85), Vector3(east_x - 0.2, band_y, gate_pos.y), _stone_dark, "GatehouseCourse")
	_add_battlement_row_z(east_x - 0.1, gate_pos.y - gate_width * 0.5 - 1.3, gate_pos.y + gate_width * 0.5 + 1.3, gate_height + 5.7, 1.0, 0.75, 3.4)
	# Central watch turret above the gatehouse.
	var turret_x := east_x - 0.35
	MeshLib.add_cylinder(self, 1.9, 1.75, 4.4, Vector3(turret_x, 14.5, gate_pos.y), _stone, "GateTurret", 12)
	MeshLib.add_cylinder(self, 2.05, 2.05, 0.22, Vector3(turret_x, 16.65, gate_pos.y), _stone_light, "GateTurretRing", 12)
	MeshLib.add_cylinder(self, 2.3, 0.04, 3.6, Vector3(turret_x, 18.5, gate_pos.y), _roof_blue, "GateTurretRoof", 12)
	MeshLib.add_cylinder(self, 2.34, 2.3, 0.12, Vector3(turret_x, 16.78, gate_pos.y), _stone_light, "GateTurretEave", 12)
	for i in 3:
		var slit_angle := -PI * 0.5 + float(i) * PI * 0.45 + 1.2
		MeshLib.add_box(self, Vector3(0.18, 0.8, 0.08), Vector3(turret_x + cos(slit_angle) * 1.9, 14.0, gate_pos.y + sin(slit_angle) * 1.9), _window_dark, "TurretSlit", Vector3(0.0, -rad_to_deg(slit_angle), 0.0))
	MeshLib.add_cylinder(self, 0.035, 0.028, 1.7, Vector3(turret_x, 20.3, gate_pos.y), _iron, "TurretPole", 5)
	_add_flag(Vector3(turret_x, 21.0, gate_pos.y), _flag_blue, 0.8, 0.36)
	# Heraldic shield over the doorway.
	var crest_center := Vector3(east_x + 1.58, 9.35, gate_pos.y)
	MeshLib.add_cylinder(self, 1.25, 1.25, 0.18, crest_center, _gold, "GateShieldFrame", 16, Vector3(0.0, 0.0, 90.0))
	MeshLib.add_cylinder(self, 0.98, 0.98, 0.2, crest_center + Vector3(0.07, 0.0, 0.0), _flag_blue, "GateShieldField", 16, Vector3(0.0, 0.0, 90.0))
	MeshLib.add_cylinder(self, 0.28, 0.0, 0.8, crest_center + Vector3(0.18, 0.0, 0.0), MeshLib.emissive("#d5b66d", 0.8), "GateShieldCrystal", 4, Vector3(0.0, 0.0, 90.0))
	# Recessed gate portal, arch and wooden gate leaves.
	MeshLib.add_box(self, Vector3(0.45, gate_height, gate_width), Vector3(east_x + 0.02, gate_height * 0.5, gate_pos.y), _window_dark, "GateRecess")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.18, gate_height * 0.78, gate_width * 0.44), Vector3(east_x + 0.22, gate_height * 0.4, gate_pos.y + side * gate_width * 0.23), _wood_dark, "CastleDoorLeaf")
		for band in 4:
			MeshLib.add_box(self, Vector3(0.09, 0.13, gate_width * 0.38), Vector3(east_x + 0.33, 1.0 + float(band) * 1.2, gate_pos.y + side * gate_width * 0.23), _iron, "DoorBand")
	MeshLib.add_box(self, Vector3(0.12, gate_height, 0.22), Vector3(east_x + 0.35, gate_height * 0.5, gate_pos.y), _gold, "GateSplit")
	_arch_ring(Vector3(east_x + 0.3, gate_height * 0.57, gate_pos.y), gate_width * 0.5, gate_height * 0.4, 0.5, _stone_light, true, "z")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.9, 0.3, 0.9), Vector3(east_x + 1.1, 0.15, gate_pos.y + side * (gate_width * 0.5 + 0.8)), _stone_light, "GateStep")
		MeshLib.add_box(self, Vector3(0.9, 0.2, 0.9), Vector3(east_x + 1.85, 0.1, gate_pos.y + side * (gate_width * 0.5 + 0.8)), _stone_warm, "GateStep")
		_add_torch(Vector3(east_x + 0.7, 4.2, gate_pos.y + side * (gate_width * 0.5 + 1.0)), true)
		_add_hanging_banner(Vector3(east_x + 0.5, 8.8, gate_pos.y + side * (gate_width * 0.5 + 0.7)), Vector3.ZERO, _flag_blue, 1.0, 3.0)
	# A warm seam under the gate hints at the hall beyond.
	MeshLib.add_box(self, Vector3(0.1, 0.3, gate_width * 0.4), Vector3(east_x + 0.4, 0.2, gate_pos.y), _window_light, "GateGlow")
	MeshLib.add_omni_light(self, Vector3(east_x + 1.3, 2.2, gate_pos.y), "#ffc071", 1.4, 7.0, true)

	# Keep.
	var keep: Dictionary = _castle_cfg["keep"]
	var keep_center: Vector2 = GameState.vec2_from_array(keep["center"])
	var keep_size: Vector2 = GameState.vec2_from_array(keep["size"])
	var keep_height := float(keep["height"])
	var keep_roof := float(keep["roof_height"])
	MeshLib.add_box(self, Vector3(keep_size.x + 1.0, 1.1, keep_size.y + 1.0), Vector3(keep_center.x, 0.55, keep_center.y), _stone_dark, "KeepPlinth")
	MeshLib.add_box(self, Vector3(keep_size.x, keep_height, keep_size.y), Vector3(keep_center.x, keep_height * 0.5, keep_center.y), _stone_warm, "KeepBody")
	for y: float in [5.0, 10.5, 15.8]:
		MeshLib.add_box(self, Vector3(keep_size.x + 0.22, 0.2, keep_size.y + 0.22), Vector3(keep_center.x, y, keep_center.y), _stone_light, "KeepBand")
	MeshLib.add_box(self, Vector3(keep_size.x + 0.8, 0.55, keep_size.y + 0.8), Vector3(keep_center.x, keep_height + 0.24, keep_center.y), _stone_light, "KeepCornice")
	MeshLib.add_pyramid(self, Vector2(keep_size.x + 1.1, keep_size.y + 1.1), keep_roof, Vector3(keep_center.x, keep_height + 0.45, keep_center.y), _roof_blue, "KeepRoof")
	# Corner bartizans on the keep.
	for corner: Vector2 in [
		Vector2(keep_center.x + keep_size.x * 0.5 - 0.5, keep_center.y + keep_size.y * 0.5 - 0.5),
		Vector2(keep_center.x + keep_size.x * 0.5 - 0.5, keep_center.y - keep_size.y * 0.5 + 0.5)
	]:
		_round_tower(Vector3(corner.x, keep_height - 2.0, corner.y), 1.35, 5.8, 3.4, _flag_blue, false, 1.1)
	# Tall lancet windows on the east face of the keep.
	for i in 3:
		var z := keep_center.y - 3.0 + float(i) * 3.0
		_keep_window(Vector3(keep_center.x + keep_size.x * 0.5 + 0.04, 13.0, z), 0.7, 2.6)
	# Rose window.
	var rose := Node3D.new()
	rose.name = "RoseWindow"
	rose.position = Vector3(keep_center.x + keep_size.x * 0.5 + 0.1, 17.2, keep_center.y)
	rose.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	add_child(rose)
	MeshLib.add_cylinder(rose, 1.75, 1.75, 0.15, Vector3.ZERO, _stone_dark, "RoseFrame", 16)
	MeshLib.add_cylinder(rose, 1.5, 1.5, 0.18, Vector3(0.0, -0.03, 0.0), MeshLib.emissive("#d2ba82", 1.0), "RoseGlass", 16)
	for spoke in 8:
		var angle := TAU * float(spoke) / 8.0
		var bar := MeshLib.add_box(rose, Vector3(0.1, 2.9, 0.2), Vector3.ZERO, _gold, "RoseSpoke")
		bar.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(angle))
	MeshLib.add_cylinder(rose, 0.42, 0.42, 0.22, Vector3(0.0, -0.08, 0.0), MeshLib.emissive("#f2d694", 1.4), "RoseCenter", 12)
	# Roof pennants.
	_add_flag(Vector3(keep_center.x, keep_height + keep_roof + 1.3, keep_center.y), _flag_red, 1.2, 0.5)
	# Ivy softening the oldest stones.
	var ivy := MeshLib.material("#405c36", 0.98)
	for i in 7:
		var y := 2.0 + float(i % 4) * 2.6
		var z := 14.8 - float(i) * 1.1
		var leaf := MeshLib.add_sphere(self, 0.7 + float(i % 3) * 0.3, Vector3(east_x + 0.15, y, z), ivy, "Ivy", 0.5, 7)
		leaf.scale = Vector3(0.3, 0.8, 0.7)


func _build_castle_south_gate() -> void:
	# The ceremonial entrance faces the city square, so the player always sees
	# an actual facade at the starting position (rather than the top of a wall).
	var gate: Dictionary = _castle_cfg["south_gate"]
	var gp: Vector2 = GameState.vec2_from_array(gate["position"])
	var width := float(gate["width"])
	var height := float(gate["height"])
	var z_face := gp.y
	var tower_xs: Array = gate["tower_x"]
	var tower_z := float(gate["tower_z"])
	var tower_radius := float(gate["tower_radius"])
	var tower_height := float(gate["tower_height"])
	var roof_height := float(gate["tower_roof_height"])
	for tx: float in tower_xs:
		_round_tower(Vector3(tx, 0.0, tower_z), tower_radius, tower_height, roof_height, _flag_blue, true, 1.2)
	# Recessed porch and oak doors.
	MeshLib.add_box(self, Vector3(width + 1.6, height + 1.0, 1.1), Vector3(gp.x, height * 0.55, z_face + 0.45), _stone_dark, "SouthGatePorch")
	MeshLib.add_box(self, Vector3(width - 0.4, height - 0.2, 0.35), Vector3(gp.x, height * 0.5, z_face + 0.98), _window_dark, "SouthGateRecess")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(width * 0.44, height * 0.82, 0.22), Vector3(gp.x + side * width * 0.23, height * 0.41, z_face + 1.1), _wood_dark, "SouthGateDoor")
		for band in 5:
			MeshLib.add_box(self, Vector3(width * 0.38, 0.13, 0.06), Vector3(gp.x + side * width * 0.23, 0.9 + float(band) * 1.15, z_face + 1.22), _iron, "SouthDoorBand")
		MeshLib.add_sphere(self, 0.11, Vector3(gp.x + side * 0.3, 2.4, z_face + 1.28), _gold, "SouthDoorRing", -1.0, 8)
		MeshLib.add_box(self, Vector3(0.16, height * 0.82, 0.2), Vector3(gp.x + side * width * 0.47, height * 0.41, z_face + 1.1), _gold, "DoorEdge")
	MeshLib.add_box(self, Vector3(0.21, height * 0.85, 0.24), Vector3(gp.x, height * 0.42, z_face + 1.12), _iron, "SouthDoorSplit")
	_arch_ring(Vector3(gp.x, height * 0.57, z_face + 1.25), width * 0.54, height * 0.39, 0.55, _stone_light, true, "x")
	# Gatehouse body, crest, battlements.
	MeshLib.add_box(self, Vector3(width + 3.6, 6.0, 3.0), Vector3(gp.x, height + 3.0, z_face + 0.85), _stone, "SouthGatehouse")
	for band_y: float in [8.2, 10.8, 13.0]:
		MeshLib.add_box(self, Vector3(width + 3.75, 0.12, 3.15), Vector3(gp.x, band_y, z_face + 0.85), _stone_dark, "SouthGateCourse")
	MeshLib.add_box(self, Vector3(width + 4.3, 0.3, 3.5), Vector3(gp.x, height + 6.2, z_face + 0.8), _stone_light, "SouthGateCornice")
	_add_gate_battlements(Vector3(gp.x, height + 6.3, z_face + 0.8), width + 3.8, 2.8, 7)
	var crest_center := Vector3(gp.x, 11.9, z_face + 2.5)
	MeshLib.add_cylinder(self, 1.55, 1.55, 0.2, crest_center, _gold, "SouthCrestFrame", 16, Vector3(90.0, 0.0, 0.0))
	MeshLib.add_cylinder(self, 1.25, 1.25, 0.22, crest_center + Vector3(0.0, 0.0, 0.06), _flag_blue, "SouthCrestField", 16, Vector3(90.0, 0.0, 0.0))
	MeshLib.add_cylinder(self, 0.33, 0.0, 0.9, crest_center + Vector3(0.0, 0.0, 0.15), _gold, "SouthCrestCrystal", 4, Vector3(90.0, 0.0, 0.0))
	# Wide ceremonial steps.
	for i in 3:
		var step_width := width + 2.4 + float(i) * 1.0
		var step_z := z_face + 1.5 + float(i) * 0.55
		MeshLib.add_box(self, Vector3(step_width, 0.2, 0.75), Vector3(gp.x, 0.1 + 0.18 * float(2 - i), step_z), _stone_light, "SouthGateStep")
		MeshLib.add_box(self, Vector3(step_width - 0.8, 0.04, 0.1), Vector3(gp.x, 0.21 + 0.18 * float(2 - i), step_z + 0.28), _gold, "SouthStepTrim")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.75, 1.15, 0.75), Vector3(gp.x + side * (width * 0.5 + 1.6), 0.57, z_face + 2.55), _stone, "SouthGateBollard")
		MeshLib.add_box(self, Vector3(0.86, 0.16, 0.86), Vector3(gp.x + side * (width * 0.5 + 1.6), 1.2, z_face + 2.55), _gold, "SouthBollardCap")
		_add_torch(Vector3(gp.x + side * (width * 0.5 + 0.8), 4.6, z_face + 1.8), true)
	# Banner falls flank the door.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(1.35, 3.2, 0.07), Vector3(gp.x + side * (width * 0.5 + 1.7), 8.3, z_face + 2.22), _flag_red, "SouthGateBanner")
		MeshLib.add_box(self, Vector3(1.5, 0.18, 0.12), Vector3(gp.x + side * (width * 0.5 + 1.7), 9.96, z_face + 2.22), _gold, "SouthBannerRod")
		MeshLib.add_box(self, Vector3(0.7, 0.7, 0.08), Vector3(gp.x + side * (width * 0.5 + 1.7), 8.0, z_face + 2.27), _gold, "SouthBannerEmblem", Vector3(0.0, 0.0, 45.0))
	MeshLib.add_omni_light(self, Vector3(gp.x, 3.5, z_face + 3.5), "#ffc27a", 2.2, 10.0, true)
	# The castle wall itself closes the threshold; interaction swaps the scene.
	MeshLib.add_box(self, Vector3(width - 1.6, 0.02, 1.2), Vector3(gp.x, 0.05, z_face + 1.1), _stone_warm, "GateThreshold")


func _castle_curtain(center: Vector3, size: Vector3, along_x: bool) -> void:
	MeshLib.add_box(self, size, center, _stone, "CastleWall")
	MeshLib.add_box(self, Vector3(size.x + 0.35, 0.55, size.z + 0.35), Vector3(center.x, 0.28, center.z), _stone_dark, "CastleWallPlinth")
	for y: float in [2.2, 4.3, 6.4]:
		MeshLib.add_box(self, Vector3(size.x + 0.13, 0.09, size.z + 0.13), Vector3(center.x, y, center.z), _stone_dark, "WallJoint")
	MeshLib.add_box(self, Vector3(size.x + 0.15, 0.18, size.z + 0.15), Vector3(center.x, float(_castle_cfg["wall_height"]) * 0.58, center.z), _stone_light, "CastleWallCourse")
	_add_battlements_along(center, size, along_x, float(_castle_cfg["wall_height"]), 2.2, 1.15, 0.8)
	# Narrow buttresses break up the long curtain.
	var span := size.x if along_x else size.z
	var buttress_count := maxi(1, int(span / 7.0))
	for i in buttress_count:
		var offset := (float(i) + 0.5) * span / float(buttress_count) - span * 0.5
		var bpos := center
		if along_x:
			bpos.x += offset
		else:
			bpos.z += offset
		MeshLib.add_box(self, Vector3(0.85, 4.5, 0.65), Vector3(bpos.x + (0.2 if not along_x else 0.0), 2.25, bpos.z + (0.2 if along_x else 0.0)), _stone_light, "Buttress")
		MeshLib.add_box(self, Vector3(1.0, 0.25, 0.8), Vector3(bpos.x + (0.2 if not along_x else 0.0), 4.45, bpos.z + (0.2 if along_x else 0.0)), _stone_dark, "ButtressCap")
	# Arrow slits.
	var count := 3
	for i in count:
		var offset := float(i - count / 2) * 4.2
		var pos := center
		pos.y = 4.2
		if along_x:
			pos.x += offset
			pos.z += size.z * 0.5 + 0.02
		else:
			pos.z += offset
			pos.x += size.x * 0.5 + 0.02
		MeshLib.add_box(self, Vector3(0.22, 0.9, 0.08), pos, _window_dark, "ArrowSlit")


func _add_battlement_row_z(x: float, z_start: float, z_end: float, y_base: float, width: float, height: float, depth: float) -> void:
	var length := z_end - z_start
	var count: int = maxi(3, int(length / (width * 1.8)))
	var step := length / float(count)
	for i in count:
		var z := z_start + step * (float(i) + 0.5)
		MeshLib.add_box(self, Vector3(depth, height, width * 0.8), Vector3(x, y_base + height * 0.5, z), _stone_light, "GateMerlon")


func _keep_window(pos: Vector3, half_width: float, height: float) -> void:
	MeshLib.add_box(self, Vector3(0.1, height, half_width * 2.0), pos, _window_dark, "KeepWindow")
	MeshLib.add_box(self, Vector3(0.12, height * 0.84, half_width * 1.7), pos + Vector3(0.02, 0.0, 0.0), MeshLib.emissive("#d7b779", 1.1), "KeepWindowGlow")
	MeshLib.add_box(self, Vector3(0.14, height + 0.25, 0.16), pos + Vector3(0.04, 0.0, 0.0), _stone_light, "KeepWindowFrame")
	MeshLib.add_cylinder(self, half_width * 0.9, half_width * 0.9, 0.14, pos + Vector3(0.06, height * 0.46, 0.0), MeshLib.emissive("#d7b779", 1.0), "KeepWindowArch", 10, Vector3(0.0, 0.0, 90.0))


func _add_hanging_banner(attach: Vector3, _rot: Vector3, cloth_mat: StandardMaterial3D, width: float, height: float) -> void:
	MeshLib.add_box(self, Vector3(0.07, height, width), attach + Vector3(0.0, -height * 0.5, 0.0), cloth_mat, "Banner")
	MeshLib.add_box(self, Vector3(0.08, 0.25, width + 0.12), attach + Vector3(0.0, -0.1, 0.0), _gold, "BannerRod")
	MeshLib.add_box(self, Vector3(0.09, 0.4, width * 0.45), attach + Vector3(0.02, -height * 0.55, 0.0), _gold, "BannerEmblem")
	MeshLib.add_box(self, Vector3(0.1, height * 0.75, 0.06), attach + Vector3(0.04, -height * 0.5, 0.0), _flag_gold, "BannerStripe")


# ---------------------------------------------------------------------------
# Houses
# ---------------------------------------------------------------------------

func _build_houses() -> void:
	for i in data["houses"].size():
		_build_house(data["houses"][i], i)


func _build_house(house: Dictionary, index: int) -> void:
	var center: Vector2 = GameState.vec2_from_array(house["center"])
	var size: Vector2 = GameState.vec2_from_array(house["size"])
	var height := float(house["height"])
	var wall_col := str(house["wall_color"])
	var timber_col := str(house["timber_color"])
	var roof_col := str(house["roof_color"])
	var accent_col := str(house["accent_color"])
	var wall_mat := MeshLib.material(wall_col, 0.94)
	var timber_mat := MeshLib.material(timber_col, 0.95)
	var roof_mat := MeshLib.material(roof_col, 0.78, 0.03)
	var roof_light := MeshLib.material(Color(roof_col).lightened(0.08).to_html(false), 0.75, 0.03)
	var timber_dark := MeshLib.material(Color(timber_col).darkened(0.1).to_html(false), 0.96)
	var accent_mat := MeshLib.material(accent_col, 0.8)
	var base_height := 0.55
	var wall_top := base_height + height

	# Foundation and wall volume.
	MeshLib.add_box(self, Vector3(size.x + 0.3, base_height, size.y + 0.3), Vector3(center.x, base_height * 0.5, center.y), _stone_dark, "HouseFoundation")
	MeshLib.add_box(self, Vector3(size.x, height, size.y), Vector3(center.x, base_height + height * 0.5, center.y), wall_mat, "HouseWalls")
	MeshLib.add_box_collider(self, Vector3(size.x + 0.3, height + 4.0, size.y + 0.3), Vector3(center.x, (height + 4.0) * 0.5, center.y), "HouseSolid")
	MeshLib.add_box(self, Vector3(size.x + 0.24, 0.13, size.y + 0.24), Vector3(center.x, wall_top - 0.02, center.y), timber_mat, "HouseHeadBeam")
	MeshLib.add_box(self, Vector3(size.x + 0.2, 0.11, size.y + 0.2), Vector3(center.x, base_height + height * 0.58, center.y), timber_mat, "HouseMidBeam")
	# Decorative sill / lower stone band.
	MeshLib.add_box(self, Vector3(size.x + 0.34, 0.18, size.y + 0.34), Vector3(center.x, base_height + 0.04, center.y), _stone_light, "HouseSill")

	# Roof.
	var roof_height := size.x * 0.34 + 1.2
	MeshLib.add_box(self, Vector3(size.x + 1.5, 0.2, size.y + 1.5), Vector3(center.x, wall_top + 0.08, center.y), timber_dark, "HouseEave")
	MeshLib.add_pyramid(self, Vector2(size.x + 1.25, size.y + 1.25), roof_height, Vector3(center.x, wall_top + 0.18, center.y), roof_mat, "HouseRoof")
	MeshLib.add_cylinder(self, 0.055, 0.025, 0.34, Vector3(center.x, wall_top + roof_height + 0.42, center.y), _gold, "RoofFinial", 8)
	MeshLib.add_sphere(self, 0.1, Vector3(center.x, wall_top + roof_height + 0.62, center.y), _gold, "RoofFinialOrb", -1.0, 8)
	# A slim ridge cap catches the sun at the apex.
	MeshLib.add_box(self, Vector3(0.28, 0.16, size.y * 0.22), Vector3(center.x, wall_top + 0.18 + roof_height + 0.02, center.y), roof_light, "RoofRidge")

	# Timber framing.
	_add_house_timber(center, size, base_height, height, timber_mat)
	# Door and windows.
	_add_house_door(house, center, size, base_height, timber_mat, accent_mat, roof_mat)
	_add_house_windows(house, center, size, base_height, height, timber_mat, accent_mat)

	# Chimneys.
	if bool(house.get("chimney", false)):
		var chimney_x := center.x + (size.x * 0.25 if index % 2 == 0 else -size.x * 0.28)
		var chimney_z := center.y + size.y * 0.16
		var chimney_h := roof_height * 0.85 + 1.6
		MeshLib.add_box(self, Vector3(0.85, chimney_h, 0.85), Vector3(chimney_x, wall_top + chimney_h * 0.48, chimney_z), _stone_dark, "Chimney")
		MeshLib.add_box(self, Vector3(1.02, 0.18, 1.02), Vector3(chimney_x, wall_top + chimney_h * 0.97, chimney_z), _stone, "ChimneyCap")
		_add_chimney_smoke(Vector3(chimney_x, wall_top + chimney_h * 1.02, chimney_z))

	# Side details: quirky lean-to crates and a flower box.
	var door_side: Vector2 = GameState.vec2_from_array(house["door"]["facing"])
	var side_dir := Vector2(-door_side.y, door_side.x)
	var prop_pos := center + side_dir * (size.x * 0.5 + 1.0)
	MeshLib.add_cylinder(self, 0.38, 0.34, 0.7, Vector3(prop_pos.x, 0.35, prop_pos.y + 1.1), _wood, "HouseBarrel", 10)
	MeshLib.add_cylinder(self, 0.41, 0.41, 0.08, Vector3(prop_pos.x, 0.48, prop_pos.y + 1.1), _iron, "BarrelBand", 10)
	if index % 3 == 0:
		MeshLib.add_box(self, Vector3(0.75, 0.7, 0.65), Vector3(prop_pos.x + 0.8, 0.35, prop_pos.y + 0.2), _wood_dark, "Crate", Vector3(0.0, 18.0, 0.0))
	# Warm lantern beside the door.
	var door_world := GameState.vec2_from_array(house["door"]["position"])
	var door_tangent := Vector2(-door_side.y, door_side.x)
	var lantern_pos := door_world + door_tangent * 1.35 + door_side * 0.3
	_add_wall_lantern(Vector3(lantern_pos.x, 2.5, lantern_pos.y), index % 2 == 0)
	var service_id := str(house.get("service", ""))
	if not service_id.is_empty():
		_add_service_door_sign(house, service_id, door_world, door_side)


func _add_service_door_sign(house: Dictionary, service_id: String, door_pos: Vector2, out_dir: Vector2) -> void:
	var service := GameState.get_service(service_id)
	if service.is_empty():
		return
	var accent := Color(str(service.get("accent", "#d5b16b")))
	var accent_mat := MeshLib.material(accent.to_html(false), 0.6, 0.15)
	var horizontal := absf(out_dir.x) > 0.5
	var sign_center := Vector3(door_pos.x, 4.15, door_pos.y) + Vector3(out_dir.x, 0.0, out_dir.y) * 0.22
	if horizontal:
		MeshLib.add_box(self, Vector3(0.16, 0.68, 2.9), sign_center, _wood_dark, "ServiceDoorSign")
		MeshLib.add_box(self, Vector3(0.22, 0.06, 3.0), sign_center + Vector3(out_dir.x * 0.02, 0.34, 0.0), accent_mat, "ServiceDoorSignTrim")
		MeshLib.add_box(self, Vector3(0.22, 0.06, 3.0), sign_center + Vector3(out_dir.x * 0.02, -0.34, 0.0), _gold, "ServiceDoorSignTrim")
	else:
		MeshLib.add_box(self, Vector3(2.9, 0.68, 0.16), sign_center, _wood_dark, "ServiceDoorSign")
		MeshLib.add_box(self, Vector3(3.0, 0.06, 0.22), sign_center + Vector3(0.0, 0.34, out_dir.y * 0.02), accent_mat, "ServiceDoorSignTrim")
		MeshLib.add_box(self, Vector3(3.0, 0.06, 0.22), sign_center + Vector3(0.0, -0.34, out_dir.y * 0.02), _gold, "ServiceDoorSignTrim")
	var sign_label := MeshLib.add_label3d(self, str(service.get("sign", "УСЛУГИ")), sign_center + Vector3(out_dir.x, 0.0, out_dir.y) * 0.2, 42, accent.lightened(0.24).to_html(false), "ServiceDoorLabel")
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.no_depth_test = true
	sign_label.pixel_size = 0.01
	sign_label.width = 2000.0
	sign_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _add_house_timber(center: Vector2, size: Vector2, base: float, height: float, mat: StandardMaterial3D) -> void:
	var hw := size.x * 0.5
	var hd := size.y * 0.5
	var y_mid := base + height * 0.58
	var y_high := base + height - 0.2
	# Verticals on each facade.
	var fxs := [-hw * 0.82, -hw * 0.32, hw * 0.32, hw * 0.82]
	for fx: float in fxs:
		MeshLib.add_box(self, Vector3(0.16, height, 0.12), Vector3(center.x + fx, base + height * 0.5, center.y + hd + 0.06), mat, "TimberS")
		MeshLib.add_box(self, Vector3(0.16, height, 0.12), Vector3(center.x + fx, base + height * 0.5, center.y - hd - 0.06), mat, "TimberN")
	var fzs := [-hd * 0.82, -hd * 0.32, hd * 0.32, hd * 0.82]
	for fz: float in fzs:
		MeshLib.add_box(self, Vector3(0.12, height, 0.16), Vector3(center.x + hw + 0.06, base + height * 0.5, center.y + fz), mat, "TimberE")
		MeshLib.add_box(self, Vector3(0.12, height, 0.16), Vector3(center.x - hw - 0.06, base + height * 0.5, center.y + fz), mat, "TimberW")
	# Horizontals.
	MeshLib.add_box(self, Vector3(size.x, 0.14, 0.12), Vector3(center.x, y_mid, center.y + hd + 0.07), mat, "TimberS")
	MeshLib.add_box(self, Vector3(size.x, 0.14, 0.12), Vector3(center.x, y_high, center.y + hd + 0.07), mat, "TimberS2")
	MeshLib.add_box(self, Vector3(size.x, 0.14, 0.12), Vector3(center.x, y_mid, center.y - hd - 0.07), mat, "TimberN")
	MeshLib.add_box(self, Vector3(size.x, 0.14, 0.12), Vector3(center.x, y_high, center.y - hd - 0.07), mat, "TimberN2")
	MeshLib.add_box(self, Vector3(0.12, 0.14, size.y), Vector3(center.x + hw + 0.07, y_high, center.y), mat, "TimberE2")
	MeshLib.add_box(self, Vector3(0.12, 0.14, size.y), Vector3(center.x - hw - 0.07, y_high, center.y), mat, "TimberW2")
	# Diagonal braces on the upper half.
	var diag_len := sqrt(pow(size.x * 0.42, 2.0) + pow(height * 0.3, 2.0))
	for side: float in [-1.0, 1.0]:
		var z: float = center.y + side * (hd + 0.08)
		var brace := MeshLib.add_box(self, Vector3(diag_len, 0.12, 0.1), Vector3(center.x, base + height * 0.78, z), mat, "TimberBrace")
		brace.rotation_degrees = Vector3(0.0, 0.0, 34.0 * side)


func _add_house_door(house: Dictionary, center: Vector2, size: Vector2, base: float, timber_mat: StandardMaterial3D, accent_mat: StandardMaterial3D, roof_mat: StandardMaterial3D) -> void:
	var door_pos: Vector2 = GameState.vec2_from_array(house["door"]["position"])
	var out_dir: Vector2 = GameState.vec2_from_array(house["door"]["facing"])
	var horizontal: bool = absf(out_dir.x) > 0.5
	var door_width := 1.35
	var door_height := 2.45
	var frame_w := door_width + 0.5
	var frame_d := 0.17
	# Frame.
	if horizontal:
		MeshLib.add_box(self, Vector3(frame_d, door_height + 0.4, frame_w), Vector3(door_pos.x, base + door_height * 0.5 + 0.15, door_pos.y), timber_mat, "DoorFrame")
		MeshLib.add_box(self, Vector3(0.1, door_height, door_width), Vector3(door_pos.x + out_dir.x * 0.08, base + door_height * 0.5, door_pos.y), _wood_dark, "Door")
		MeshLib.add_box(self, Vector3(0.08, 0.16, door_width * 0.82), Vector3(door_pos.x + out_dir.x * 0.14, base + door_height * 0.7, door_pos.y), _iron, "DoorBand")
		MeshLib.add_box(self, Vector3(0.08, 0.16, door_width * 0.82), Vector3(door_pos.x + out_dir.x * 0.14, base + door_height * 0.3, door_pos.y), _iron, "DoorBand2")
		MeshLib.add_sphere(self, 0.08, Vector3(door_pos.x + out_dir.x * 0.16, base + 1.2, door_pos.y + door_width * 0.3), _gold, "DoorKnob", -1.0, 8)
		MeshLib.add_box(self, Vector3(1.1, 0.16, 1.8), Vector3(door_pos.x + out_dir.x * 0.55, 0.08, door_pos.y), _stone_light, "DoorStep")
	else:
		MeshLib.add_box(self, Vector3(frame_w, door_height + 0.4, frame_d), Vector3(door_pos.x, base + door_height * 0.5 + 0.15, door_pos.y), timber_mat, "DoorFrame")
		MeshLib.add_box(self, Vector3(door_width, door_height, 0.1), Vector3(door_pos.x, base + door_height * 0.5, door_pos.y + out_dir.y * 0.08), _wood_dark, "Door")
		MeshLib.add_box(self, Vector3(door_width * 0.82, 0.16, 0.08), Vector3(door_pos.x, base + door_height * 0.7, door_pos.y + out_dir.y * 0.14), _iron, "DoorBand")
		MeshLib.add_box(self, Vector3(door_width * 0.82, 0.16, 0.08), Vector3(door_pos.x, base + door_height * 0.3, door_pos.y + out_dir.y * 0.14), _iron, "DoorBand2")
		MeshLib.add_sphere(self, 0.08, Vector3(door_pos.x + door_width * 0.3, base + 1.2, door_pos.y + out_dir.y * 0.16), _gold, "DoorKnob", -1.0, 8)
		MeshLib.add_box(self, Vector3(1.8, 0.16, 1.1), Vector3(door_pos.x, 0.08, door_pos.y + out_dir.y * 0.55), _stone_light, "DoorStep")
	# Little canopy.
	var canopy_pos := Vector3(door_pos.x + out_dir.x * 0.55, base + door_height + 0.5, door_pos.y + out_dir.y * 0.55)
	if horizontal:
		var canopy := MeshLib.add_box(self, Vector3(1.0, 0.11, door_width + 0.75), canopy_pos, roof_mat, "DoorCanopy")
		canopy.rotation_degrees = Vector3(0.0, 0.0, 28.0 * out_dir.x)
	else:
		var canopy := MeshLib.add_box(self, Vector3(door_width + 0.75, 0.11, 1.0), canopy_pos, roof_mat, "DoorCanopy")
		canopy.rotation_degrees = Vector3(-28.0 * out_dir.y, 0.0, 0.0)
	# Flower box over the door.
	var fb_pos := Vector3(door_pos.x + out_dir.x * 0.25, base + door_height + 0.12, door_pos.y + out_dir.y * 0.25)
	MeshLib.add_box(self, Vector3(1.4 if not horizontal else 0.35, 0.2, 0.35 if not horizontal else 1.4), fb_pos, timber_mat, "FlowerBox")
	for j in 3:
		MeshLib.add_sphere(self, 0.11, fb_pos + Vector3((-0.4 + 0.4 * float(j)) if not horizontal else 0.0, 0.14, 0.0 if not horizontal else (-0.4 + 0.4 * float(j))), _flower_mats[j % _flower_mats.size()], "Flower", -1.0, 6)


func _add_house_windows(house: Dictionary, center: Vector2, size: Vector2, base: float, height: float, timber_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var hw := size.x * 0.5
	var hd := size.y * 0.5
	var y := base + height * 0.63
	# Each facade gets a pair of windows; the door lives below them.
	for side: float in [-1.0, 1.0]:
		var sx: float = center.x + side * hw
		for j: float in [-1.0, 1.0]:
			_add_window(Vector3(sx, y, center.y + j * size.y * 0.24), false, timber_mat, accent_mat)
		var sz: float = center.y + side * hd
		for j: float in [-1.0, 1.0]:
			_add_window(Vector3(center.x + j * size.x * 0.24, y, sz), true, timber_mat, accent_mat)


func _add_window(pos: Vector3, on_z_wall: bool, timber_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var pane_light := index_mod(pos) % 5 != 0
	if on_z_wall:
		MeshLib.add_box(self, Vector3(1.0, 1.2, 0.08), pos, timber_mat, "WindowFrame")
		MeshLib.add_box(self, Vector3(0.82, 1.0, 0.09), pos + Vector3(0.0, 0.0, 0.01), _window_light if pane_light else _window_dark, "WindowPane")
		MeshLib.add_box(self, Vector3(0.05, 1.0, 0.1), pos + Vector3(0.0, 0.0, 0.02), timber_mat, "WindowMullionV")
		MeshLib.add_box(self, Vector3(0.82, 0.05, 0.1), pos + Vector3(0.0, 0.0, 0.02), timber_mat, "WindowMullionH")
		MeshLib.add_box(self, Vector3(1.2, 0.1, 0.18), pos + Vector3(0.0, -0.64, 0.06), _stone_light, "WindowSill")
		MeshLib.add_box(self, Vector3(0.23, 1.18, 0.07), pos + Vector3(0.63, 0.0, 0.02), accent_mat, "Shutter")
		MeshLib.add_box(self, Vector3(0.23, 1.18, 0.07), pos + Vector3(-0.63, 0.0, 0.02), accent_mat, "Shutter")
	else:
		MeshLib.add_box(self, Vector3(0.08, 1.2, 1.0), pos, timber_mat, "WindowFrame")
		MeshLib.add_box(self, Vector3(0.09, 1.0, 0.82), pos + Vector3(0.01, 0.0, 0.0), _window_light if pane_light else _window_dark, "WindowPane")
		MeshLib.add_box(self, Vector3(0.1, 1.0, 0.05), pos + Vector3(0.02, 0.0, 0.0), timber_mat, "WindowMullionV")
		MeshLib.add_box(self, Vector3(0.1, 0.05, 0.82), pos + Vector3(0.02, 0.0, 0.0), timber_mat, "WindowMullionH")
		MeshLib.add_box(self, Vector3(0.18, 0.1, 1.2), pos + Vector3(0.06, -0.64, 0.0), _stone_light, "WindowSill")
		MeshLib.add_box(self, Vector3(0.07, 1.18, 0.23), pos + Vector3(0.02, 0.0, 0.63), accent_mat, "Shutter")
		MeshLib.add_box(self, Vector3(0.07, 1.18, 0.23), pos + Vector3(0.02, 0.0, -0.63), accent_mat, "Shutter")


func index_mod(pos: Vector3) -> int:
	return int(absf(pos.x * 7.0 + pos.z * 11.0)) % 7


func _add_wall_lantern(pos: Vector3, with_light: bool) -> void:
	MeshLib.add_box(self, Vector3(0.14, 0.55, 0.14), pos, _iron, "LanternBracket")
	var housing := MeshLib.add_box(self, Vector3(0.28, 0.42, 0.28), pos + Vector3(0.0, 0.1, 0.0), _iron, "LanternHousing")
	MeshLib.add_box(self, Vector3(0.19, 0.3, 0.19), pos + Vector3(0.0, 0.1, 0.0), _window_light, "LanternGlass")
	MeshLib.add_cylinder(self, 0.16, 0.02, 0.15, pos + Vector3(0.0, 0.46, 0.0), _stone_dark, "LanternTop", 4)
	if with_light:
		MeshLib.add_omni_light(self, pos + Vector3(0.0, 0.3, 0.0), "#ffb768", 0.85, 4.5, false)


# ---------------------------------------------------------------------------
# Plaza and props
# ---------------------------------------------------------------------------

func _build_plaza_props() -> void:
	_build_fountain()
	for tree_data: Array in data["props"]["trees"]:
		var x := float(tree_data[0])
		var z := float(tree_data[1])
		var scale := float(tree_data[2])
		_build_tree(Vector3(x, 0.0, z), scale, true)
	for lamp: Array in data["props"]["lamps"]:
		_build_lamp(Vector3(float(lamp[0]), 0.0, float(lamp[1])))
	for bench: Array in data["props"]["benches"]:
		_build_bench(Vector3(float(bench[0]), 0.0, float(bench[1])), float(bench[2]))
	for planter: Array in data["props"]["planters"]:
		_build_planter(Vector3(float(planter[0]), 0.0, float(planter[1])))
	for barrel: Array in data["props"]["barrels"]:
		_build_barrel(Vector3(float(barrel[0]), 0.0, float(barrel[1])))
	_build_signpost(Vector3(11.4, 0.0, -8.2))
	# A pair of topiary planters and braziers dress the castle forecourt.
	for side: float in [-1.0, 1.0]:
		var fp := Vector3(-31.0 if side < 0.0 else -15.6, 0.0, 31.0)
		_add_planter(fp)
		_build_lamp(Vector3(-32.4 if side < 0.0 else -15.2, 0.0, 26.8))
	# Central old well? A pair of stone obelisks frames the road to the bridge.
	for side: float in [-1.0, 1.0]:
		var x: float = 6.8 * side
		var z := -10.5
		MeshLib.add_box(self, Vector3(0.8, 0.55, 0.8), Vector3(x, 0.27, z), _stone_dark, "ObeliskBase")
		MeshLib.add_box(self, Vector3(0.5, 2.0, 0.5), Vector3(x, 1.5, z), _stone_light, "Obelisk", Vector3(0.0, 18.0 * side, 0.0))
		MeshLib.add_cylinder(self, 0.22, 0.03, 0.5, Vector3(x, 2.75, z), _gold, "ObeliskTip", 4)
		MeshLib.add_box_collider(self, Vector3(0.8, 2.0, 0.8), Vector3(x, 1.0, z), "ObeliskSolid")


func _build_fountain() -> void:
	var f: Dictionary = data["fountain"]
	var pos2: Vector2 = GameState.vec2_from_array(f["position"])
	var center := Vector3(pos2.x, 0.0, pos2.y)
	var radius := float(f["radius"])
	var height := float(f["height"])
	var stone_warm := MeshLib.material("#c0b7a3", 0.9)
	MeshLib.add_cylinder(self, radius, radius + 0.15, 0.55, center + Vector3(0.0, 0.27, 0.0), _stone_light, "FountainBasin", 28)
	MeshLib.add_cylinder(self, radius + 0.25, radius + 0.25, 0.28, center + Vector3(0.0, 0.72, 0.0), _stone, "FountainRim", 28)
	MeshLib.add_cylinder(self, radius - 0.2, radius - 0.2, 0.11, center + Vector3(0.0, 0.64, 0.0), MeshLib.transparent("#5d9e9e", 0.62), "FountainWater", 28)
	MeshLib.add_cylinder(self, radius + 0.36, radius + 0.5, 0.22, center + Vector3(0.0, 0.11, 0.0), _stone_dark, "FountainPlinth", 28)
	# Central tier.
	MeshLib.add_cylinder(self, 0.58, 0.46, 1.5, center + Vector3(0.0, 1.4, 0.0), _stone_warm, "FountainColumn", 12)
	MeshLib.add_cylinder(self, 1.45, 1.05, 0.18, center + Vector3(0.0, 2.08, 0.0), stone_warm, "FountainUpper", 20)
	MeshLib.add_cylinder(self, 1.15, 1.15, 0.08, center + Vector3(0.0, 2.14, 0.0), MeshLib.transparent("#76b6b2", 0.66), "FountainUpperWater", 20)
	MeshLib.add_cylinder(self, 0.25, 0.12, 1.0, center + Vector3(0.0, 2.6, 0.0), _stone_light, "FountainStem", 8)
	var crystal_mat := MeshLib.emissive("#87d7dc", 2.2)
	var crystal := Node3D.new()
	crystal.position = center + Vector3(0.0, 3.35, 0.0)
	add_child(crystal)
	var c1 := MeshLib.add_cylinder(crystal, 0.32, 0.0, 0.6, Vector3.ZERO, crystal_mat, "CrystalTop", 4)
	var c2 := MeshLib.add_cylinder(crystal, 0.0, 0.32, 0.6, Vector3(0.0, -0.6, 0.0), crystal_mat, "CrystalBottom", 4)
	MeshLib.add_cylinder(crystal, 0.55, 0.55, 0.06, Vector3(0.0, -0.92, 0.0), _gold, "CrystalSetting", 12)
	MeshLib.add_omni_light(self, center + Vector3(0.0, 3.2, 0.0), "#8fdde0", 1.2, 7.0, false)
	for side: float in [-1.0, 1.0]:
		var fish := Node3D.new()
		fish.position = center + Vector3(side * (radius - 0.4), 0.85, 0.0)
		add_child(fish)
		var spout := MeshLib.add_cylinder(fish, 0.17, 0.11, 0.36, Vector3.ZERO, _stone_dark, "FishSpout", 8)
		spout.rotation_degrees = Vector3(0.0, 0.0, 76.0 * side)
	# Collision plus a water spray particle burst.
	MeshLib.add_cylinder_collider(self, radius + 0.15, 1.1, center + Vector3(0.0, 0.55, 0.0), "FountainSolid")
	_add_fountain_spray(center + Vector3(0.0, 2.25, 0.0))
	# Benches frame the fountain.
	for angle in [-0.8, 2.35]:
		var p := Vector2(cos(angle), sin(angle)) * (radius + 2.2)
		_build_bench(Vector3(center.x + p.x, 0.0, center.z + p.y), -angle + PI * 0.5)
	_add_planter(Vector3(center.x - radius - 2.6, 0.0, center.z + 1.2))
	_add_planter(Vector3(center.x + radius + 2.2, 0.0, center.z - 1.7))


func _add_fountain_spray(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "FountainSpray"
	particles.position = pos
	particles.amount = 28
	particles.lifetime = 1.1
	particles.preprocess = 0.4
	particles.emitting = true
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 28.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 2.1
	process.gravity = Vector3(0.0, -4.2, 0.0)
	process.scale_min = 0.35
	process.scale_max = 0.8
	process.color = Color(0.75, 0.92, 0.94, 0.8)
	particles.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.95, 0.96, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	particles.draw_pass_1 = mesh
	add_child(particles)


func _build_tree(pos: Vector3, scale: float, collision: bool) -> void:
	var trunk_mat := MeshLib.material("#5a4531", 0.96)
	var variation := int(absf(pos.x + pos.z * 3.0)) % _foliage.size()
	var leaf_mat := _foliage[variation]
	var trunk_h := 2.0 * scale
	MeshLib.add_cylinder(self, 0.22 * scale, 0.32 * scale, trunk_h, pos + Vector3(0.0, trunk_h * 0.5, 0.0), trunk_mat, "TreeTrunk", 7)
	MeshLib.add_cylinder(self, 0.09 * scale, 0.06 * scale, 1.2 * scale, pos + Vector3(0.35 * scale, trunk_h * 0.77, 0.0), trunk_mat, "TreeBranch", 5, Vector3(0.0, 0.0, -35.0))
	for i in 3:
		var y := trunk_h + 0.45 * scale + float(i) * 0.72 * scale
		var r := (1.45 - float(i) * 0.3) * scale
		var foliage := MeshLib.add_sphere(self, r, pos + Vector3(float(i - 1) * 0.38 * scale, y, float(i % 2 - 0.5) * 0.3 * scale), leaf_mat, "Foliage", r * 1.5, 8)
		foliage.scale = Vector3(1.0, 0.88, 1.0)
	var crown := MeshLib.add_sphere(self, 1.15 * scale, pos + Vector3(0.0, trunk_h + 1.9 * scale, 0.0), _foliage[(variation + 1) % _foliage.size()], "Crown", 1.35 * scale, 8)
	crown.scale = Vector3(1.0, 0.75, 1.0)
	if collision:
		MeshLib.add_cylinder_collider(self, 0.35 * scale, 2.2 * scale, pos + Vector3(0.0, 1.1 * scale, 0.0), "TreeSolid")


func _build_lamp(pos: Vector3) -> void:
	MeshLib.add_cylinder(self, 0.24, 0.17, 0.22, pos + Vector3(0.0, 0.11, 0.0), _stone_dark, "LampBase", 8)
	MeshLib.add_cylinder(self, 0.075, 0.055, 2.9, pos + Vector3(0.0, 1.5, 0.0), _iron, "LampPost", 8)
	MeshLib.add_box(self, Vector3(0.5, 0.1, 0.5), pos + Vector3(0.0, 2.93, 0.0), _iron, "LampArm")
	for side: float in [-1.0, 1.0]:
		var housing := MeshLib.add_box(self, Vector3(0.25, 0.42, 0.25), pos + Vector3(0.26 * side, 2.9, 0.0), _iron, "LampHousing")
		MeshLib.add_box(self, Vector3(0.18, 0.3, 0.18), pos + Vector3(0.26 * side, 2.9, 0.0), _window_light, "LampGlass")
		MeshLib.add_omni_light(self, pos + Vector3(0.26 * side, 2.75, 0.0), "#ffc57f", 0.95, 5.2, false)
	# A small flower basket softens every lamp post.
	MeshLib.add_box(self, Vector3(0.62, 0.26, 0.46), pos + Vector3(0.0, 2.1, 0.0), _wood_dark, "LampFlowerBox")
	var leaves := MeshLib.material("#4f724b", 0.96)
	MeshLib.add_sphere(self, 0.22, pos + Vector3(0.0, 2.27, 0.0), leaves, "LampLeaves", 0.4, 6)
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		var petal := MeshLib.material("#f0c9c3" if i % 2 == 0 else "#e9dfb4", 0.92)
		MeshLib.add_sphere(self, 0.075, pos + Vector3(cos(angle) * 0.18, 2.33, sin(angle) * 0.13), petal, "LampFlower", 0.4, 6)
	MeshLib.add_cylinder_collider(self, 0.18, 3.0, pos + Vector3(0.0, 1.5, 0.0), "LampSolid")


func _add_chimney_smoke(pos: Vector3) -> void:
	var smoke := CPUParticles3D.new()
	smoke.name = "ChimneySmoke"
	smoke.position = pos
	smoke.amount = 10
	smoke.lifetime = 5.2
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.15
	smoke.direction = Vector3(0.0, 1.0, 0.0)
	smoke.spread = 14.0
	smoke.gravity = Vector3(0.03, 0.04, 0.0)
	smoke.initial_velocity_min = 0.18
	smoke.initial_velocity_max = 0.42
	smoke.scale_amount_min = 0.12
	smoke.scale_amount_max = 0.34
	smoke.color = Color(0.72, 0.72, 0.7, 0.3)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.74, 0.73, 0.7, 0.24)
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	smoke.mesh = quad
	add_child(smoke)


func _build_bench(pos: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.name = "Bench"
	g.position = pos
	g.rotation_degrees = Vector3(0.0, rad_to_deg(yaw), 0.0)
	add_child(g)
	MeshLib.add_box(g, Vector3(2.1, 0.14, 0.58), Vector3(0.0, 0.52, 0.0), _wood, "BenchSeat")
	MeshLib.add_box(g, Vector3(2.1, 0.45, 0.12), Vector3(0.0, 0.78, 0.26), _wood, "BenchBack")
	for x in [-0.8, 0.8]:
		MeshLib.add_box(g, Vector3(0.12, 0.55, 0.12), Vector3(x, 0.27, 0.17), _iron, "BenchLeg")
		MeshLib.add_box(g, Vector3(0.12, 1.05, 0.12), Vector3(x, 0.52, 0.27), _iron, "BenchBackPost")
	MeshLib.add_box_collider(g, Vector3(2.2, 0.9, 0.7), Vector3(0.0, 0.45, 0.0), "BenchSolid")


func _build_planter(pos: Vector3) -> void:
	_add_planter(pos)


func _add_planter(pos: Vector3) -> void:
	MeshLib.add_box(self, Vector3(1.25, 0.5, 0.55), pos + Vector3(0.0, 0.25, 0.0), _stone_dark, "Planter")
	MeshLib.add_box(self, Vector3(1.1, 0.37, 0.42), pos + Vector3(0.0, 0.34, 0.0), MeshLib.material("#3f4d32", 0.98), "PlanterSoil")
	for i in 5:
		var x := -0.45 + float(i) * 0.22
		MeshLib.add_cylinder(self, 0.025, 0.015, 0.45, pos + Vector3(x, 0.66, 0.02 * float(i % 2)), MeshLib.material("#577348", 0.96), "PlantStem", 4)
		MeshLib.add_sphere(self, 0.11, pos + Vector3(x, 0.9 + 0.08 * float(i % 3), 0.02 * float(i % 2)), _flower_mats[i % _flower_mats.size()], "Flower", -1.0, 6)
	MeshLib.add_box_collider(self, Vector3(1.3, 0.8, 0.6), pos + Vector3(0.0, 0.4, 0.0), "PlanterSolid")


func _build_barrel(pos: Vector3) -> void:
	MeshLib.add_cylinder(self, 0.43, 0.37, 0.9, pos + Vector3(0.0, 0.45, 0.0), _wood, "Barrel", 10)
	for y in [0.23, 0.63]:
		MeshLib.add_cylinder(self, 0.45, 0.45, 0.06, pos + Vector3(0.0, y, 0.0), _iron, "BarrelBand", 10)
	MeshLib.add_cylinder_collider(self, 0.45, 1.0, pos + Vector3(0.0, 0.5, 0.0), "BarrelSolid")


func _build_signpost(pos: Vector3) -> void:
	MeshLib.add_cylinder(self, 0.11, 0.08, 2.4, pos + Vector3(0.0, 1.2, 0.0), _wood_dark, "SignPost", 6)
	var board := MeshLib.add_box(self, Vector3(1.7, 0.7, 0.12), pos + Vector3(0.0, 2.05, 0.0), _wood, "SignBoard")
	board.rotation_degrees = Vector3(0.0, -18.0, 0.0)
	var label := MeshLib.add_label3d(self, "СЕВЕРНЫЙ МОСТ", pos + Vector3(0.0, 2.05, 0.09), 26, "#f1dba8", "SignText")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.rotation_degrees = Vector3(0.0, -18.0, 0.0)
	var arrow := MeshLib.add_box(self, Vector3(0.7, 0.16, 0.14), pos + Vector3(0.0, 1.55, 0.0), _wood, "SignArrow")
	arrow.rotation_degrees = Vector3(0.0, -18.0, 27.0)
	MeshLib.add_box_collider(self, Vector3(0.4, 2.4, 0.4), pos + Vector3(0.0, 1.2, 0.0), "SignSolid")


# ---------------------------------------------------------------------------
# NPCs and interaction anchors
# ---------------------------------------------------------------------------

func _build_npcs() -> void:
	for npc: Dictionary in data["npcs"]:
		var pos: Vector2 = GameState.vec2_from_array(npc["position"])
		var npc_root := Node3D.new()
		npc_root.name = "NPC_%s" % str(npc["id"])
		npc_root.position = Vector3(pos.x, 0.0, pos.y)
		add_child(npc_root)
		var visual := CharacterVisual.new()
		visual.name = "Visual"
		visual.setup_npc(npc)
		var facing: Vector2 = GameState.vec2_from_array(npc["facing"])
		visual.set_facing(Vector3(facing.x, 0.0, facing.y), true)
		npc_root.add_child(visual)
		MeshLib.add_cylinder_collider(npc_root, 0.38, 1.9, Vector3(0.0, 0.95, 0.0), "NPCSolid")
		var prompt := "E — Поговорить: %s" % str(npc["name"])
		var point := add_interactable("npc", prompt, {
			"npc_id": str(npc["id"]),
			"dialogue": str(npc["dialogue"]),
			"name": str(npc["name"])
		}, npc_root.position)
		point.focus_offset = Vector3(0.0, 1.6, 0.0)


func _build_door_interactions() -> void:
	var gate: Dictionary = _castle_cfg["gate"]
	var gate_pos: Vector2 = GameState.vec2_from_array(gate["position"])
	add_interactable("door", str(gate["prompt"]), {
		"target": str(gate["target"]),
		"spawn": str(gate["spawn"]),
		"label": "Замок Корнелии"
	}, Vector3(gate_pos.x + 0.1, 0.0, gate_pos.y))
	var south_gate: Dictionary = _castle_cfg["south_gate"]
	var south_pos: Vector2 = GameState.vec2_from_array(south_gate["position"])
	add_interactable("door", str(south_gate["prompt"]), {
		"target": str(south_gate["target"]),
		"spawn": str(south_gate["spawn"]),
		"label": "Замок Корнелии"
	}, Vector3(south_pos.x, 0.0, south_pos.y + 0.9))
	for house: Dictionary in data["houses"]:
		var door_pos: Vector2 = GameState.vec2_from_array(house["door"]["position"])
		var prompt := str(house["door"]["prompt"])
		var point := add_interactable("door", prompt, {
			"target": "house",
			"house_id": str(house["id"]),
			"spawn": "entry",
			"label": str(house["name"])
		}, Vector3(door_pos.x, 0.0, door_pos.y))
		point.focus_offset = Vector3(0.0, 1.2, 0.0)


# ---------------------------------------------------------------------------
# Distant scenery
# ---------------------------------------------------------------------------

func _build_atmosphere_and_scenery() -> void:
	# Soft silhouettes beyond the north bank give the bridge a destination.
	var hill_mat := MeshLib.material("#5c6a52", 0.98)
	var hill_mat_dark := MeshLib.material("#475744", 0.99)
	var hills := [
		[Vector3(-56.0, -2.5, -112.0), Vector3(38.0, 15.0, 22.0), hill_mat],
		[Vector3(18.0, -2.0, -122.0), Vector3(54.0, 19.0, 28.0), hill_mat_dark],
		[Vector3(82.0, -2.0, -98.0), Vector3(34.0, 13.0, 20.0), hill_mat],
		[Vector3(-92.0, -2.0, -88.0), Vector3(40.0, 12.0, 19.0), hill_mat_dark],
		[Vector3(0.0, -3.0, -146.0), Vector3(90.0, 25.0, 36.0), hill_mat_dark]
	]
	for h: Array in hills:
		var sphere := MeshLib.add_sphere(self, 1.0, h[0], h[2], "DistantHill", 1.0, 12)
		sphere.scale = h[1]
		sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A small pine wood beyond the far gate.
	for i in 12:
		var x := -42.0 + float(i) * 7.2
		if absf(x) < 8.0:
			continue
		var z := -83.0 - float(i % 3) * 4.0
		var scale := 0.8 + float(i % 4) * 0.17
		_build_pine(Vector3(x, 0.0, z), scale)
	# Closer trees make the far bridge landing feel like the edge of a forest.
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var px := side * (11.0 + float(i) * 1.8)
		var pz := -79.0 - float(i) * 2.1
		_build_pine(Vector3(px, 0.0, pz), 1.25 + float(i % 3) * 0.22)
	# Two pines on the south meadow, outside the walls, visible over rooftops.
	_build_pine(Vector3(-42.0, 0.0, 18.0), 1.3)
	_build_pine(Vector3(45.0, 0.0, 26.0), 1.5)
	# Warm motes above the plaza.
	_add_fireflies()


func _build_pine(pos: Vector3, scale: float) -> void:
	MeshLib.add_cylinder(self, 0.18 * scale, 0.26 * scale, 2.4 * scale, pos + Vector3(0.0, 1.2 * scale, 0.0), MeshLib.material("#4a3a2b", 0.98), "PineTrunk", 6)
	for i in 3:
		var radius := (1.4 - float(i) * 0.28) * scale
		var h := 1.8 * scale
		MeshLib.add_cylinder(self, radius, 0.03, h, pos + Vector3(0.0, (2.2 + float(i) * 0.8) * scale, 0.0), _foliage[0], "PineFoliage", 8)


func _add_fireflies() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "Fireflies"
	particles.position = Vector3(2.0, 1.5, 2.0)
	particles.amount = 30
	particles.lifetime = 8.0
	particles.preprocess = 3.0
	particles.emitting = true
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(15.0, 1.5, 10.0)
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = 0.03
	process.initial_velocity_max = 0.16
	process.gravity = Vector3(0.0, 0.0, 0.0)
	process.scale_min = 0.45
	process.scale_max = 1.0
	process.color = Color(1.0, 0.86, 0.47, 0.8)
	particles.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.87, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.3)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.draw_pass_1 = mesh
	add_child(particles)
