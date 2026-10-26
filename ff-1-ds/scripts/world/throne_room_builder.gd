class_name ThroneRoomBuilder
extends LocationBase
## The interior of Cornelia Castle: a warm, ceremonial hall with the king,
## stained glass, a red carpet and an ornate throne.

var _gold: StandardMaterial3D
var _gold_soft: StandardMaterial3D
var _stone: StandardMaterial3D
var _stone_light: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _carpet: StandardMaterial3D
var _carpet_dark: StandardMaterial3D
var _royal_blue: StandardMaterial3D
var _window_colors: Array[StandardMaterial3D] = []
var _fire: StandardMaterial3D
var _floor_mat: ShaderMaterial


func build() -> void:
	name = "ThroneRoom"
	_init_materials()
	_build_shell()
	_build_carpet()
	_build_columns()
	_build_dais_and_throne()
	_build_lighting()
	_build_npcs()
	_build_exit()
	finalize()


func _init_materials() -> void:
	_gold = MeshLib.material("#c5a35f", 0.32, 0.6)
	_gold_soft = MeshLib.material("#9f814c", 0.55, 0.35)
	_stone = MeshLib.material("#7b6f61", 0.92)
	_stone_light = MeshLib.material("#8d7f6c", 0.9)
	_stone_dark = MeshLib.material("#544b43", 0.94)
	_wood = MeshLib.material("#5e4030", 0.88)
	_wood_dark = MeshLib.material("#39261e", 0.95)
	_carpet = MeshLib.material("#721f2c", 0.99)
	_carpet_dark = MeshLib.material("#4d1520", 0.99)
	_royal_blue = MeshLib.material("#253b62", 0.9)
	_window_colors = [
		MeshLib.emissive("#5f78b6", 1.2),
		MeshLib.emissive("#b88a57", 1.15),
		MeshLib.emissive("#7f4f75", 1.0),
		MeshLib.emissive("#c8bda1", 0.95)
	]
	_fire = MeshLib.emissive("#ff9a44", 2.2)
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = load("res://shaders/marble.gdshader")
	_floor_mat.set_shader_parameter("marble_light", Color("#6c645b"))
	_floor_mat.set_shader_parameter("marble_dark", Color("#3b3834"))
	_floor_mat.set_shader_parameter("vein_color", Color("#8d7e69"))
	_floor_mat.set_shader_parameter("gold_inlay", Color("#51432b"))


func _build_shell() -> void:
	var room: Dictionary = data["room"]
	var rmin: Vector2 = GameState.vec2_from_array(room["min"])
	var rmax: Vector2 = GameState.vec2_from_array(room["max"])
	var height := float(room["height"])
	var width := rmax.x - rmin.x
	var depth := rmax.y - rmin.y
	var center := (rmin + rmax) * 0.5

	# Floor: a marble slab with a thick foundation under it.
	MeshLib.add_box(self, Vector3(width, 0.4, depth), Vector3(center.x, -0.2, center.y), _stone_dark, "HallFoundation")
	var floor_plane := MeshLib.add_plane(self, Vector2(width, depth), Vector3(center.x, 0.012, center.y), _floor_mat, "MarbleFloor")
	floor_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Outer walls, with the inner face exactly on the room edge. The south side
	# is deliberately a cutaway so the high camera can see the whole hall.
	var wall_thickness := 1.2
	MeshLib.add_box(self, Vector3(width + wall_thickness * 2.0, height, wall_thickness), Vector3(center.x, height * 0.5, rmin.y - wall_thickness * 0.5), _stone_light, "NorthWall")
	MeshLib.add_box(self, Vector3(4.5, height, wall_thickness), Vector3(rmin.x + 2.25, height * 0.5, rmax.y + wall_thickness * 0.5), _stone_light, "SouthWallWest")
	MeshLib.add_box(self, Vector3(4.5, height, wall_thickness), Vector3(rmax.x - 2.25, height * 0.5, rmax.y + wall_thickness * 0.5), _stone_light, "SouthWallEast")
	MeshLib.add_box(self, Vector3(wall_thickness, height, depth), Vector3(rmin.x - wall_thickness * 0.5, height * 0.5, center.y), _stone_light, "WestWall")
	MeshLib.add_box(self, Vector3(wall_thickness, height, depth), Vector3(rmax.x + wall_thickness * 0.5, height * 0.5, center.y), _stone_light, "EastWall")
	# Wall colliders sit just outside the playable rectangle. The south collider is
	# invisible but still prevents walking out through the open doorway.
	MeshLib.add_box_collider(self, Vector3(width + 4.0, 4.0, wall_thickness + 1.0), Vector3(center.x, 2.0, rmin.y - 0.8), "NorthWallSolid")
	MeshLib.add_box_collider(self, Vector3(width + 4.0, 4.0, wall_thickness + 1.0), Vector3(center.x, 2.0, rmax.y + 0.8), "SouthWallSolid")
	MeshLib.add_box_collider(self, Vector3(wall_thickness + 1.0, 4.0, depth), Vector3(rmin.x - 0.8, 2.0, center.y), "WestWallSolid")
	MeshLib.add_box_collider(self, Vector3(wall_thickness + 1.0, 4.0, depth), Vector3(rmax.x + 0.8, 2.0, center.y), "EastWallSolid")

	# Wainscoting, cornice and gold string courses.
	for side: float in [-1.0, 1.0]:
		var x: float = (rmin.x if side < 0.0 else rmax.x) + side * 0.02
		MeshLib.add_box(self, Vector3(0.18, 2.8, depth), Vector3(x, 1.4, center.y), _stone_dark, "Wainscot")
		MeshLib.add_box(self, Vector3(0.16, 0.14, depth), Vector3(x, 2.9, center.y), _gold_soft, "WainscotTrim")
		MeshLib.add_box(self, Vector3(0.2, 0.22, depth), Vector3(x, 9.2, center.y), _gold_soft, "WallCornice")
		MeshLib.add_box(self, Vector3(0.25, 0.75, depth), Vector3(x, 10.4, center.y), _stone_dark, "WallCrown")
	# North band.
	var z_north: float = rmin.y + 0.02
	MeshLib.add_box(self, Vector3(width, 0.2, 0.18), Vector3(center.x, 9.2, z_north), _gold_soft, "WallCornice")
	MeshLib.add_box(self, Vector3(width, 2.8, 0.19), Vector3(center.x, 1.4, z_north), _stone_dark, "Wainscot")
	MeshLib.add_box(self, Vector3(width, 0.14, 0.17), Vector3(center.x, 2.9, z_north), _gold_soft, "WainscotTrim")
	# Short south wall stubs frame the open entrance.
	for side: float in [-1.0, 1.0]:
		var stub_x: float = (rmin.x + 2.25) if side < 0.0 else (rmax.x - 2.25)
		MeshLib.add_box(self, Vector3(4.5, 2.8, 0.19), Vector3(stub_x, 1.4, rmax.y - 0.02), _stone_dark, "Wainscot")
		MeshLib.add_box(self, Vector3(4.5, 0.14, 0.17), Vector3(stub_x, 2.9, rmax.y - 0.02), _gold_soft, "WainscotTrim")
	# Extend a shallow vestibule floor south so the cutaway has grounded foreground.
	MeshLib.add_box(self, Vector3(width + 1.5, 0.4, 16.0), Vector3(center.x, -0.2, rmax.y + 8.0), _stone_dark, "EntranceFoundation")
	var vest_floor := MeshLib.add_plane(self, Vector2(width + 1.5, 16.0), Vector3(center.x, 0.012, rmax.y + 8.0), _floor_mat, "VestibuleFloor")
	vest_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshLib.add_box(self, Vector3(6.0, 0.035, 14.0), Vector3(0.0, 0.07, rmax.y + 7.0), _carpet_dark, "VestibuleRunner")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.16, 0.06, 14.0), Vector3(side * 3.05, 0.08, rmax.y + 7.0), _gold_soft, "VestibuleRunnerTrim")
		MeshLib.add_box(self, Vector3(0.7, 2.0, 9.0), Vector3((rmin.x if side < 0 else rmax.x) + side * 0.2, 1.0, rmax.y + 7.0), _stone_dark, "VestibulePlinth")
	# Low approach steps outside the threshold.
	for i in 3:
		MeshLib.add_box(self, Vector3(width - 4.0 - float(i) * 1.4, 0.12, 0.7), Vector3(0.0, 0.06 + float(i) * 0.02, rmax.y + 1.2 + float(i) * 0.7), _stone_light, "ApproachStep")

	# Pilasters rhythm on the side walls.
	for side: float in [-1.0, 1.0]:
		var x: float = (rmin.x if side < 0.0 else rmax.x) + side * 0.1
		for z: float in [-14.0, -6.0, 2.0, 10.0]:
			MeshLib.add_box(self, Vector3(0.5, 8.4, 0.65), Vector3(x, 4.2, z), _stone_light, "Pilaster")
			MeshLib.add_box(self, Vector3(0.65, 0.3, 0.8), Vector3(x, 8.2, z), _gold_soft, "PilasterCapital")
			MeshLib.add_box(self, Vector3(0.65, 0.3, 0.8), Vector3(x, 0.3, z), _gold_soft, "PilasterBase")
	# Heavy south entrance doors.
	_build_entrance_doors(rmax.y)
	# Stained glass side windows and banners.
	for side: float in [-1.0, 1.0]:
		var x: float = (rmin.x if side < 0.0 else rmax.x) - side * 0.02
		for i in 4:
			var z := -11.0 + float(i) * 8.0
			_build_side_window(Vector3(x, 5.9, z), side)
		for i in 3:
			var z := -7.0 + float(i) * 8.0
			_add_wall_banner(Vector3(x - side * 0.08, 7.5, z), side)
	# North wall backdrops around the throne.
	var z_back := rmin.y + 0.04
	MeshLib.add_box(self, Vector3(width - 5.0, 0.14, 0.16), Vector3(center.x, 3.15, z_back), _gold_soft, "ThroneLedge")
	# Tall arched recess, dark velvet with a gold frame.
	MeshLib.add_box(self, Vector3(9.5, 8.2, 0.12), Vector3(0.0, 5.3, z_back + 0.02), _royal_blue, "ThroneRecess")
	MeshLib.add_box(self, Vector3(10.4, 0.38, 0.25), Vector3(0.0, 9.55, z_back + 0.08), _gold, "RecessTop")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.45, 8.0, 0.25), Vector3(5.0 * side, 5.4, z_back + 0.08), _gold, "RecessPillar")
	# Stained glass above / behind the throne.
	_build_rose_window(Vector3(0.0, 7.4, z_back + 0.18))
	# Tall side drapes framing the north wall.
	for side: float in [-1.0, 1.0]:
		_add_north_drape(Vector3(5.9 * side, 8.0, z_back + 0.22))
	# Two marble urns in the wings.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_cylinder(self, 0.5, 0.36, 0.7, Vector3(11.5 * side, 0.35, -13.0), _stone_light, "UrnBase", 12)
		MeshLib.add_sphere(self, 0.55, Vector3(11.5 * side, 1.15, -13.0), _stone_light, "Urn", 1.15, 12)
		MeshLib.add_box_collider(self, Vector3(1.0, 1.6, 1.0), Vector3(11.5 * side, 0.8, -13.0), "UrnSolid")
	# Wall behind camera: the closed south wall is behind the doors; no extra work needed.


func _build_entrance_doors(south_z: float) -> void:
	# The camera sits outside a cutaway south side, so the doors are swung wide
	# open and the threshold remains the interaction point.
	MeshLib.add_box(self, Vector3(13.2, 0.16, 1.2), Vector3(0.0, 0.08, south_z - 0.35), _stone_light, "EntranceThreshold")
	MeshLib.add_box(self, Vector3(12.6, 0.035, 0.4), Vector3(0.0, 0.18, south_z - 0.7), _gold, "ThresholdInlay")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(1.25, 7.3, 1.4), Vector3(side * 6.15, 3.65, south_z - 0.3), _stone, "EntranceJamb")
		MeshLib.add_box(self, Vector3(1.5, 0.3, 1.7), Vector3(side * 6.15, 7.35, south_z - 0.3), _gold_soft, "EntranceJambCap")
		MeshLib.add_box(self, Vector3(1.42, 0.35, 1.6), Vector3(side * 6.15, 0.18, south_z - 0.3), _gold_soft, "EntranceJambFoot")
		var hinge := Node3D.new()
		hinge.name = "EntranceHinge"
		hinge.position = Vector3(side * 5.5, 0.0, south_z - 0.55)
		hinge.rotation_degrees = Vector3(0.0, side * 72.0, 0.0)
		add_child(hinge)
		MeshLib.add_box(hinge, Vector3(0.16, 5.9, 2.65), Vector3(0.0, 2.95, -1.25), _wood, "EntranceDoorLeaf")
		for band in 4:
			MeshLib.add_box(hinge, Vector3(0.05, 0.13, 2.2), Vector3(side * -0.1, 0.85 + float(band) * 1.3, -1.25), _gold_soft, "DoorBand")
		MeshLib.add_cylinder(hinge, 0.14, 0.14, 0.22, Vector3(0.0, 2.8, -2.3), _gold, "DoorHandle", 10, Vector3(90.0, 0.0, 0.0))
		_add_candle_stand(Vector3(side * 7.4, 0.0, south_z + 0.6))
	# A tall but open arch of light marks the way out without blocking the cutaway.
	MeshLib.add_omni_light(self, Vector3(0.0, 4.0, south_z + 2.2), "#ffcf8e", 1.4, 10.0, true)
	MeshLib.add_box(self, Vector3(10.6, 0.05, 0.1), Vector3(0.0, 0.2, south_z + 0.2), MeshLib.emissive("#f0d29a", 0.45), "ThresholdGlow")


func _build_carpet() -> void:
	var carpet: Dictionary = data["carpet"]
	var width := float(carpet["width"])
	var start_z := float(carpet["start_z"])
	var end_z := float(carpet["end_z"])
	var length := start_z - end_z
	var center_z := (start_z + end_z) * 0.5
	MeshLib.add_box(self, Vector3(width, 0.05, length), Vector3(0.0, 0.04, center_z), _carpet, "RoyalCarpet")
	MeshLib.add_box(self, Vector3(width + 0.28, 0.028, length), Vector3(0.0, 0.025, center_z), _carpet_dark, "CarpetUnderlay")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.16, 0.06, length), Vector3(side * (width * 0.5 + 0.02), 0.05, center_z), _gold, "CarpetBorder")
	# Repeated gold diamonds down the runner.
	var count := int(length / 2.4)
	for i in count:
		var z := end_z + 1.3 + float(i) * 2.4
		if z > start_z - 0.5:
			continue
		for side: float in [-1.0, 1.0]:
			var diamond := MeshLib.add_box(self, Vector3(0.23, 0.035, 0.23), Vector3(side * width * 0.3, 0.061, z), _gold_soft, "CarpetDiamond", Vector3(0.0, 45.0, 0.0))
			diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A wide gold-trimmed landing before the dais.
	MeshLib.add_box(self, Vector3(width + 2.2, 0.06, 2.0), Vector3(0.0, 0.045, end_z - 0.2), _carpet_dark, "CarpetDaisApron")
	MeshLib.add_box(self, Vector3(width + 2.5, 0.03, 0.15), Vector3(0.0, 0.08, end_z - 1.18), _gold, "ApronTrim")


func _build_columns() -> void:
	var columns: Dictionary = data["columns"]
	var xs: Array = columns["x"]
	var zs: Array = columns["z"]
	var radius := float(columns["radius"])
	var height := float(columns["height"])
	for x: float in xs:
		for z: float in zs:
			MeshLib.add_cylinder(self, radius + 0.3, radius + 0.25, 0.4, Vector3(x, 0.2, z), _stone_dark, "ColumnBase", 16)
			MeshLib.add_cylinder(self, radius * 0.92, radius, height, Vector3(x, height * 0.5 + 0.4, z), _stone_light, "ColumnShaft", 16)
			MeshLib.add_cylinder(self, radius + 0.16, radius + 0.05, 0.3, Vector3(x, height * 0.76, z), _stone_light, "ColumnNeck", 16)
			MeshLib.add_box(self, Vector3(radius * 2.5, 0.32, radius * 2.5), Vector3(x, height + 0.43, z), _gold_soft, "ColumnCapital")
			MeshLib.add_box(self, Vector3(radius * 2.9, 0.16, radius * 2.9), Vector3(x, height + 0.64, z), _stone_light, "Abacus")
			# Flutes.
			for i in 8:
				var a := TAU * float(i) / 8.0
				var px := x + cos(a) * (radius * 0.92)
				var pz := z + sin(a) * (radius * 0.92)
				MeshLib.add_box(self, Vector3(0.035, height * 0.76, 0.035), Vector3(px, height * 0.47, pz), _stone_dark, "Flute")
			MeshLib.add_cylinder_collider(self, radius + 0.18, height, Vector3(x, height * 0.5 + 0.4, z), "ColumnSolid")
	# A pair of braziers between the front columns.
	for side: float in [-1.0, 1.0]:
		_add_brazier(Vector3(4.9 * side, 0.0, -9.0))


func _build_dais_and_throne() -> void:
	var dais: Dictionary = data["dais"]
	var dc: Vector2 = GameState.vec2_from_array(dais["center"])
	var ds: Vector2 = GameState.vec2_from_array(dais["size"])
	var dh := float(dais["height"])
	MeshLib.add_box(self, Vector3(ds.x, dh, ds.y), Vector3(dc.x, dh * 0.5, dc.y), _stone_dark, "Dais")
	MeshLib.add_box(self, Vector3(ds.x + 0.35, 0.18, ds.y + 0.35), Vector3(dc.x, dh + 0.03, dc.y), _gold_soft, "DaisTrim")
	MeshLib.add_box(self, Vector3(ds.x - 1.0, 0.04, ds.y - 1.0), Vector3(dc.x, dh + 0.13, dc.y), _carpet, "DaisCarpet")
	MeshLib.add_box_collider(self, Vector3(ds.x, 1.2, ds.y), Vector3(dc.x, 0.6, dc.y), "DaisSolid")
	# Two low steps at the front edge.
	for i in 2:
		MeshLib.add_box(self, Vector3(8.2 - float(i) * 0.8, 0.2, 0.7), Vector3(0.0, 0.1 + float(i) * 0.2, dc.y + ds.y * 0.5 + 0.35 - float(i) * 0.65), _stone_light, "DaisStep")
		MeshLib.add_box(self, Vector3(2.2, 0.035, 0.7), Vector3(0.0, 0.22 + float(i) * 0.2, dc.y + ds.y * 0.5 + 0.35 - float(i) * 0.65), _carpet, "DaisRunner")

	var throne: Dictionary = data["throne"]
	var tp: Vector2 = GameState.vec2_from_array(throne["position"])
	var base_y := dh + 0.12
	# Footstool and legs.
	MeshLib.add_box(self, Vector3(2.6, 0.25, 1.4), Vector3(tp.x, base_y + 0.125, tp.y + 0.55), _gold_soft, "ThroneStep")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.22, 0.8, 0.22), Vector3(tp.x + side * 0.9, base_y + 0.4, tp.y + 0.1), _gold, "ThroneLeg")
	MeshLib.add_box(self, Vector3(2.4, 0.42, 1.35), Vector3(tp.x, base_y + 0.78, tp.y + 0.1), _gold, "ThroneSeatFrame")
	MeshLib.add_box(self, Vector3(2.0, 0.22, 1.05), Vector3(tp.x, base_y + 0.98, tp.y + 0.16), _carpet, "ThroneCushion")
	# High back with a red velvet panel and gold sun.
	MeshLib.add_box(self, Vector3(2.5, 3.6, 0.35), Vector3(tp.x, base_y + 2.65, tp.y - 0.6), _gold_soft, "ThroneBackFrame")
	MeshLib.add_box(self, Vector3(1.95, 3.0, 0.12), Vector3(tp.x, base_y + 2.62, tp.y - 0.4), _carpet, "ThroneBackVelvet")
	for i in 6:
		var a := TAU * float(i) / 6.0
		MeshLib.add_box(self, Vector3(0.08, 0.65, 0.08), Vector3(tp.x + cos(a) * 0.45, base_y + 2.8, tp.y - 0.33), _gold, "ThroneRay", Vector3(0.0, 0.0, rad_to_deg(a)))
	MeshLib.add_sphere(self, 0.28, Vector3(tp.x, base_y + 2.8, tp.y - 0.32), _gold, "ThroneSun", 0.3, 12)
	# Arms.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.28, 0.8, 1.0), Vector3(tp.x + side * 1.18, base_y + 1.28, tp.y + 0.1), _gold, "ThroneArm")
		MeshLib.add_sphere(self, 0.15, Vector3(tp.x + side * 1.18, base_y + 1.72, tp.y + 0.56), _gold, "ThroneFinial", -1.0, 8)
	MeshLib.add_cylinder(self, 0.35, 0.04, 0.7, Vector3(tp.x, base_y + 4.7, tp.y - 0.5), _gold, "ThroneSpire", 5)
	# Soft light focused on the empty throne.
	var spot := SpotLight3D.new()
	spot.position = Vector3(tp.x, 10.2, tp.y + 2.0)
	spot.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	spot.light_color = Color("#ffd9a0")
	spot.light_energy = 4.5
	spot.spot_range = 15.0
	spot.spot_angle = 25.0
	spot.shadow_enabled = true
	add_child(spot)


func _build_lighting() -> void:
	# The hall is lit by braziers, window light and warm pools over the aisle.
	for z: float in [-8.0, 2.0, 12.0, 20.0]:
		MeshLib.add_omni_light(self, Vector3(0.0, 6.8, z), "#f0bd7a", 1.55, 13.0, false)
	MeshLib.add_omni_light(self, Vector3(0.0, 5.5, -13.0), "#ffd294", 2.4, 14.0, true)
	MeshLib.add_omni_light(self, Vector3(0.0, 7.0, -7.0), "#dfb57e", 1.1, 12.0, false)
	MeshLib.add_omni_light(self, Vector3(-12.0, 5.4, -4.0), "#7889c8", 0.85, 10.0, false)
	MeshLib.add_omni_light(self, Vector3(12.0, 5.4, 6.0), "#b57a68", 0.8, 10.0, false)
	for side: float in [-1.0, 1.0]:
		for z: float in [-7.0, 9.0]:
			_add_sconce(Vector3(14.55 * side, 4.7, z), -side)
	# Candles flanking the entrance and the long aisle.
	for side: float in [-1.0, 1.0]:
		_add_candle_stand(Vector3(3.2 * side, 0.0, 15.6))
		_add_candle_stand(Vector3(5.9 * side, 0.0, 6.0))
		_add_candle_stand(Vector3(5.9 * side, 0.0, -3.0))
	# A warm directional fill reveals the whole hall from the high camera.
	var fill := DirectionalLight3D.new()
	fill.name = "HallFill"
	fill.light_color = Color("#ffdcb2")
	fill.light_energy = 0.62
	fill.rotation_degrees = Vector3(-58.0, -22.0, 0.0)
	fill.shadow_enabled = false
	add_child(fill)


func _add_brazier(pos: Vector3) -> void:
	MeshLib.add_cylinder(self, 0.38, 0.28, 0.7, pos + Vector3(0.0, 0.35, 0.0), _stone_dark, "BrazierPlinth", 10)
	MeshLib.add_cylinder(self, 0.58, 0.46, 0.4, pos + Vector3(0.0, 0.9, 0.0), _gold_soft, "BrazierBowl", 12)
	var flame := MeshLib.add_cylinder(self, 0.42, 0.02, 1.2, pos + Vector3(0.0, 1.55, 0.0), _fire, "BrazierFlame", 7)
	flame.scale = Vector3(0.72, 1.0, 0.72)
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 1.8, 0.0), "#ff9f50", 1.5, 7.5, false)


func _add_sconce(pos: Vector3, facing: float) -> void:
	MeshLib.add_cylinder(self, 0.1, 0.06, 0.75, pos, _gold_soft, "SconceArm", 6, Vector3(0.0, 0.0, 35.0 * facing))
	var flame := MeshLib.add_sphere(self, 0.16, pos + Vector3(-0.18 * facing, 0.32, 0.0), _fire, "SconceFlame", 0.45, 8)
	flame.scale = Vector3(0.7, 1.4, 0.7)
	MeshLib.add_omni_light(self, pos + Vector3(-0.2 * facing, 0.45, 0.0), "#ff9a4a", 1.0, 6.0, false)


func _add_candle_stand(pos: Vector3) -> void:
	MeshLib.add_cylinder(self, 0.32, 0.24, 0.18, pos + Vector3(0.0, 0.09, 0.0), _gold, "CandleBase", 10)
	MeshLib.add_cylinder(self, 0.06, 0.04, 1.35, pos + Vector3(0.0, 0.85, 0.0), _gold_soft, "CandleStem", 8)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var px := pos.x + cos(a) * 0.28
		var pz := pos.z + sin(a) * 0.28
		MeshLib.add_cylinder(self, 0.06, 0.06, 0.55, Vector3(px, 1.65, pz), MeshLib.material("#e4d5b4", 0.9), "Candle", 8)
		MeshLib.add_sphere(self, 0.06, Vector3(px, 1.98, pz), _fire, "CandleFlame", 0.16, 6)
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 2.0, 0.0), "#ffc477", 0.8, 4.5, false)


func _build_side_window(pos: Vector3, side: float) -> void:
	var frame_depth := 0.22
	MeshLib.add_box(self, Vector3(frame_depth, 4.4, 1.9), pos, _stone_dark, "WindowFrame")
	var inward := -side
	for segment in 4:
		var mat: StandardMaterial3D = _window_colors[(segment + int(absf(pos.z))) % _window_colors.size()]
		var pane := MeshLib.add_box(self, Vector3(0.12, 0.88, 1.45), pos + Vector3(0.05 * inward, -1.5 + float(segment) * 0.96, 0.0), mat, "WindowPane")
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshLib.add_box(self, Vector3(frame_depth + 0.12, 4.9, 0.24), pos + Vector3(0.02 * inward, 0.0, 1.1), _stone_light, "WindowJamb")
	MeshLib.add_box(self, Vector3(frame_depth + 0.12, 4.9, 0.24), pos + Vector3(0.02 * inward, 0.0, -1.1), _stone_light, "WindowJamb")
	MeshLib.add_box(self, Vector3(frame_depth + 0.16, 0.3, 2.3), pos + Vector3(0.02 * inward, 2.35, 0.0), _stone_light, "WindowLintel")
	MeshLib.add_box(self, Vector3(frame_depth + 0.1, 4.7, 0.08), pos + Vector3(0.04 * inward, 0.0, 0.0), _gold_soft, "WindowTracery")
	MeshLib.add_cylinder(self, 0.85, 0.85, 0.18, pos + Vector3(0.06 * inward, 1.8, 0.0), _stone_light, "WindowArch", 12, Vector3(0.0, 0.0, 90.0))
	MeshLib.add_cylinder(self, 0.65, 0.65, 0.2, pos + Vector3(0.08 * inward, 1.8, 0.0), _window_colors[0], "WindowRose", 12, Vector3(0.0, 0.0, 90.0))


func _build_rose_window(pos: Vector3) -> void:
	var rose := Node3D.new()
	rose.name = "ThroneRose"
	rose.position = pos
	rose.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(rose)
	MeshLib.add_cylinder(rose, 2.5, 2.5, 0.15, Vector3.ZERO, _gold, "RoseFrame", 20)
	MeshLib.add_cylinder(rose, 2.25, 2.25, 0.16, Vector3(0.0, -0.03, 0.0), MeshLib.emissive("#4f6fa6", 0.8), "RoseGlassBlue", 20)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var mat := _window_colors[i % _window_colors.size()]
		var wedge := MeshLib.add_box(rose, Vector3(0.65, 2.2, 0.18), Vector3(cos(a) * 1.35, -0.08, sin(a) * 1.35), mat, "RosePetal")
		wedge.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(a + PI * 0.5))
		var spoke := MeshLib.add_box(rose, Vector3(0.08, 4.2, 0.22), Vector3.ZERO, _gold_soft, "RoseSpoke")
		spoke.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(a))
	MeshLib.add_cylinder(rose, 0.75, 0.75, 0.2, Vector3(0.0, -0.1, 0.0), _gold_soft, "RoseHub", 12)
	MeshLib.add_cylinder(rose, 0.5, 0.5, 0.22, Vector3(0.0, -0.14, 0.0), _window_colors[1], "RoseHubGlass", 12)
	# A narrow shaft of tinted light toward the carpet is faked with a soft spot.
	var spot := SpotLight3D.new()
	spot.position = pos + Vector3(0.0, 0.0, 0.4)
	spot.rotation_degrees = Vector3(-64.0, 0.0, 0.0)
	spot.light_color = Color("#8fa7dc")
	spot.light_energy = 2.2
	spot.spot_range = 16.0
	spot.spot_angle = 21.0
	spot.shadow_enabled = false
	add_child(spot)


func _add_wall_banner(pos: Vector3, side: float) -> void:
	MeshLib.add_box(self, Vector3(0.08, 2.9, 1.6), pos + Vector3(0.0, -1.45, 0.0), _carpet, "WallBanner")
	MeshLib.add_box(self, Vector3(0.1, 0.22, 1.85), pos, _gold, "BannerRod")
	for side_y in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.1, 0.1, 1.6), pos + Vector3(0.0, 0.0, 0.0), _gold_soft, "BannerStripe")
	MeshLib.add_box(self, Vector3(0.1, 0.82, 0.82), pos + Vector3(0.02, -1.7, 0.0), _gold, "BannerEmblem", Vector3(45.0, 0.0, 0.0))
	MeshLib.add_box(self, Vector3(0.12, 0.6, 0.08), pos + Vector3(0.03, -1.2, 0.0), _gold_soft, "BannerDrop")
	# Banner pole brackets.
	for z: float in [-0.95, 0.95]:
		MeshLib.add_box(self, Vector3(0.35, 0.12, 0.16), pos + Vector3(0.0, 0.0, z), _gold_soft, "BannerBracket")


func _add_north_drape(pos: Vector3) -> void:
	MeshLib.add_box(self, Vector3(2.0, 5.6, 0.1), pos + Vector3(0.0, -2.8, 0.0), _royal_blue, "NorthDrape")
	MeshLib.add_box(self, Vector3(2.2, 0.22, 0.2), pos, _gold, "DrapeRod")
	MeshLib.add_box(self, Vector3(0.18, 5.2, 0.14), pos + Vector3(-0.75, -2.6, 0.03), _gold_soft, "DrapeTrim")
	MeshLib.add_box(self, Vector3(0.18, 5.2, 0.14), pos + Vector3(0.75, -2.6, 0.03), _gold_soft, "DrapeTrim")


func _build_npcs() -> void:
	for npc: Dictionary in data["npcs"]:
		var pos: Vector2 = GameState.vec2_from_array(npc["position"])
		var npc_root := Node3D.new()
		npc_root.name = "NPC_%s" % str(npc["id"])
		npc_root.position = Vector3(pos.x, 0.0, pos.y)
		add_child(npc_root)
		var visual := CharacterVisual.new()
		visual.setup_npc(npc)
		var facing: Vector2 = GameState.vec2_from_array(npc["facing"])
		visual.set_facing(Vector3(facing.x, 0.0, facing.y), true)
		npc_root.add_child(visual)
		MeshLib.add_cylinder_collider(npc_root, 0.38, 1.9, Vector3(0.0, 0.95, 0.0), "KingSolid")
		var prompt := "E — Поговорить: %s" % str(npc["name"])
		var point := add_interactable("npc", prompt, {
			"npc_id": str(npc["id"]),
			"dialogue": str(npc["dialogue"]),
			"name": str(npc["name"])
		}, npc_root.position)
		point.focus_offset = Vector3(0.0, 1.55, 0.0)
	# A small kneeling cushion and standing space for the king.
	MeshLib.add_box(self, Vector3(3.2, 0.04, 1.6), Vector3(0.0, 0.025, -9.2), _carpet_dark, "KingCarpetPatch")
	MeshLib.add_box(self, Vector3(3.3, 0.03, 0.1), Vector3(0.0, 0.05, -8.4), _gold, "KingCarpetTrim")


func _build_exit() -> void:
	var exit_data: Dictionary = data["exit"]
	var pos: Vector2 = GameState.vec2_from_array(exit_data["position"])
	var point := add_interactable("door", str(exit_data["prompt"]), {
		"target": str(exit_data["target"]),
		"spawn": str(exit_data["spawn"]),
		"label": "Город"
	}, Vector3(pos.x, 0.0, pos.y))
	point.focus_offset = Vector3(0.0, 1.2, 0.0)
	# A line of cold air under the doors.
	MeshLib.add_box(self, Vector3(4.5, 0.04, 0.1), Vector3(0.0, 0.02, 17.82), MeshLib.emissive("#c8d7e5", 0.5), "DoorLightSeam")
