class_name HouseInteriorBuilder
extends LocationBase
## A single reusable, data-driven house interior. The active house id selects
## palette and props, while the persistent party is untouched.

var _house: Dictionary
var _gold: StandardMaterial3D
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _stone: StandardMaterial3D
var _accent: StandardMaterial3D
var _rug: StandardMaterial3D
var _plaster: StandardMaterial3D
var _window_light: StandardMaterial3D
var _fire: StandardMaterial3D
var _flower_mats: Array[StandardMaterial3D] = []
var _service_id: String = ""
var _service: Dictionary = {}


func build() -> void:
	_house = GameState.get_house(variant)
	if _house.is_empty():
		_house = GameState.get_house_list()[0]
	_service_id = GameState.get_service_id_for_house(str(_house["id"]))
	_service = GameState.get_service(_service_id)
	title = str(_house["name"])
	var subtitle_tail := str(_service.get("subtitle", _house["name"])) if not _service.is_empty() else str(_house["name"])
	subtitle = "Корнелия · %s" % subtitle_tail.to_lower()
	name = "House_%s" % str(_house["id"])
	_init_materials()
	_build_room()
	_build_furniture()
	_build_service_station()
	_build_lighting()
	_build_exit()
	finalize()


func _init_materials() -> void:
	var interior: Dictionary = _house["interior"]
	_gold = MeshLib.material("#b89755", 0.38, 0.5)
	_wood = MeshLib.material("#6b4b34", 0.88)
	_wood_dark = MeshLib.material("#3f2c20", 0.94)
	_stone = MeshLib.material("#8f897d", 0.94)
	_accent = MeshLib.material(str(interior["accent_color"]), 0.83)
	_rug = MeshLib.material(str(interior["rug_color"]), 0.99)
	_plaster = MeshLib.material(str(interior["wall_color"]), 0.96)
	_window_light = MeshLib.emissive("#ffd38e", 1.15)
	_fire = MeshLib.emissive("#ff9640", 2.2)
	_flower_mats = [
		MeshLib.material("#b85c60", 0.9),
		MeshLib.material("#d6b662", 0.9),
		MeshLib.material("#d8d0ba", 0.9)
	]


func _build_room() -> void:
	var room: Dictionary = data["room"]
	var rmin: Vector2 = GameState.vec2_from_array(room["min"])
	var rmax: Vector2 = GameState.vec2_from_array(room["max"])
	var height := float(room["height"])
	var width := rmax.x - rmin.x
	var depth := rmax.y - rmin.y
	var center := (rmin + rmax) * 0.5
	var floor_color := str(_house["interior"].get("floor_color", "#8a6547"))

	# A dark lawn under the cutaway grounds the house in a larger world.
	var outside := MeshLib.add_plane(self, Vector2(52.0, 52.0), Vector3(center.x, -0.07, center.y + 6.0), MeshLib.material("#27301f", 0.99), "CottageGround")
	outside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Floor boards and foundation.
	MeshLib.add_box(self, Vector3(width, 0.35, depth), Vector3(center.x, -0.18, center.y), _wood_dark, "FloorFoundation")
	var floor_mat: StandardMaterial3D = MeshLib.material(floor_color, 0.86)
	var floor := MeshLib.add_plane(self, Vector2(width, depth), Vector3(center.x, 0.01, center.y), floor_mat, "WoodFloor")
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plank_count := 18
	for i in plank_count:
		var x := rmin.x + (float(i) + 0.5) * (width / float(plank_count))
		MeshLib.add_box(self, Vector3(0.025, 0.01, depth), Vector3(x, 0.017, center.y), _wood_dark, "PlankSeam")
	for i in 5:
		var z := rmin.y + 2.2 + float(i) * 4.0
		MeshLib.add_box(self, Vector3(width, 0.012, 0.03), Vector3(center.x, 0.018, z), _wood_dark, "BoardJoint")

	# Walls and beams.
	var wall_t := 0.7
	MeshLib.add_box(self, Vector3(width + wall_t * 2.0, height, wall_t), Vector3(center.x, height * 0.5, rmin.y - wall_t * 0.5), _plaster, "BackWall")
	MeshLib.add_box(self, Vector3(wall_t, height, depth), Vector3(rmin.x - wall_t * 0.5, height * 0.5, center.y), _plaster, "WestWall")
	MeshLib.add_box(self, Vector3(wall_t, height, depth), Vector3(rmax.x + wall_t * 0.5, height * 0.5, center.y), _plaster, "EastWall")
	# The south side is a deliberate cutaway: the camera can see the room without
	# a foreground beam wall. A short sill still reads as the house edge.
	MeshLib.add_box(self, Vector3(width + wall_t * 2.0, 0.3, 0.4), Vector3(center.x, 0.15, rmax.y + 0.2), _wood_dark, "FrontSill")
	MeshLib.add_box_collider(self, Vector3(width + 3.0, 3.0, wall_t + 1.0), Vector3(center.x, 1.5, rmax.y + 0.7), "FrontSolid")
	MeshLib.add_box_collider(self, Vector3(width + 3.0, 3.0, wall_t + 1.0), Vector3(center.x, 1.5, rmin.y - 0.7), "BackSolid")
	MeshLib.add_box_collider(self, Vector3(wall_t + 1.0, 3.0, depth + 3.0), Vector3(rmin.x - 0.7, 1.5, center.y), "WestSolid")
	MeshLib.add_box_collider(self, Vector3(wall_t + 1.0, 3.0, depth + 3.0), Vector3(rmax.x + 0.7, 1.5, center.y), "EastSolid")

	# Skirting, top beam and rough timber structure.
	for wall in [
		[Vector3(width, 0.24, 0.22), Vector3(center.x, 0.12, rmin.y + 0.1)],
		[Vector3(0.22, 0.24, depth), Vector3(rmin.x + 0.1, 0.12, center.y)],
		[Vector3(0.22, 0.24, depth), Vector3(rmax.x - 0.1, 0.12, center.y)]
	]:
		MeshLib.add_box(self, wall[0], wall[1], _wood_dark, "Skirting")
	for x: float in [rmin.x + 0.12, rmax.x - 0.12]:
		MeshLib.add_box(self, Vector3(0.18, height, 0.18), Vector3(x, height * 0.5, rmin.y + 0.1), _wood_dark, "CornerBeam")
		MeshLib.add_box(self, Vector3(0.18, 2.5, 0.18), Vector3(x, 1.25, rmax.y - 0.04), _wood_dark, "FrontCornerPost")
	MeshLib.add_box(self, Vector3(width, 0.22, 0.2), Vector3(center.x, height - 0.2, rmin.y + 0.1), _wood_dark, "TopBeam")
	MeshLib.add_box(self, Vector3(0.2, 0.22, depth), Vector3(rmin.x + 0.1, height - 0.2, center.y), _wood_dark, "TopBeam")
	MeshLib.add_box(self, Vector3(0.2, 0.22, depth), Vector3(rmax.x - 0.1, height - 0.2, center.y), _wood_dark, "TopBeam")
	for side: float in [-1.0, 1.0]:
		for i in 2:
			var x: float = center.x + side * (1.5 + float(i) * 3.6)
			MeshLib.add_box(self, Vector3(0.17, 2.6, 0.15), Vector3(x, 1.5, rmin.y + 0.11), _wood_dark, "WallPost")
	# A deep covered porch replaces the missing front wall.
	MeshLib.add_box(self, Vector3(width + wall_t * 2.0, 0.22, 6.0), Vector3(center.x, -0.11, rmax.y + 3.0), _wood_dark, "PorchFoundation")
	MeshLib.add_plane(self, Vector2(width + wall_t * 2.0, 6.0), Vector3(center.x, 0.011, rmax.y + 3.0), _wood, "PorchDeck")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.28, 3.4, 0.28), Vector3(rmin.x - 0.1 if side < 0.0 else rmax.x + 0.1, 1.7, rmax.y + 4.8), _wood_dark, "PorchPost")
		MeshLib.add_box(self, Vector3(1.2, 0.16, 0.4), Vector3(rmin.x + 0.2 if side < 0.0 else rmax.x - 0.2, 0.55, rmax.y + 1.5), _wood, "PorchRail")
		MeshLib.add_omni_light(self, Vector3(side * 6.4, 2.8, rmax.y + 2.0), "#ffc779", 0.8, 5.0, false)
	MeshLib.add_box(self, Vector3(9.0, 0.2, 0.9), Vector3(0.0, 0.1, rmax.y + 6.0), _stone, "PorchStep")
	MeshLib.add_box(self, Vector3(9.4, 0.1, 0.4), Vector3(0.0, 0.23, rmax.y + 5.65), _wood_dark, "PorchStepCap")

	# Windows and their warm light.
	_build_window(Vector3(-2.4, 3.3, rmin.y + 0.12), true)
	_build_window(Vector3(2.8, 3.3, rmin.y + 0.12), true)
	_build_window(Vector3(rmin.x + 0.12, 3.35, -4.6), false)
	# Small curtains.
	MeshLib.add_box(self, Vector3(0.5, 1.75, 0.12), Vector3(-3.0, 3.25, rmin.y + 0.23), _rug, "Curtain")
	MeshLib.add_box(self, Vector3(0.5, 1.75, 0.12), Vector3(3.4, 3.25, rmin.y + 0.23), _rug, "Curtain")

	# Open cottage door, kept at the side of the cutaway so it never hides the party.
	MeshLib.add_box(self, Vector3(3.5, 0.12, 1.0), Vector3(0.0, 0.06, rmax.y - 0.2), _stone, "Threshold")
	MeshLib.add_box(self, Vector3(3.0, 0.035, 0.25), Vector3(0.0, 0.15, rmax.y - 0.48), _gold, "ThresholdInlay")
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(1.7, 0.0, rmax.y - 0.5)
	hinge.rotation_degrees = Vector3(0.0, 65.0, 0.0)
	add_child(hinge)
	MeshLib.add_box(hinge, Vector3(1.9, 2.8, 0.14), Vector3(-0.95, 1.4, 0.0), _wood, "HouseExitDoor")
	for i in 3:
		MeshLib.add_box(hinge, Vector3(1.75, 0.1, 0.03), Vector3(-0.95, 0.6 + float(i) * 0.72, 0.09), _gold, "DoorBand")
	MeshLib.add_sphere(hinge, 0.07, Vector3(-1.65, 1.35, 0.1), _gold, "DoorHandle", -1.0, 8)
	MeshLib.add_cylinder(self, 0.12, 0.08, 2.4, Vector3(-1.75, 1.2, rmax.y + 1.7), _wood_dark, "PorchPost", 6)
	MeshLib.add_box(self, Vector3(0.45, 0.5, 0.28), Vector3(-1.75, 2.35, rmax.y + 1.7), _wood_dark, "PorchLanternBracket")
	MeshLib.add_box(self, Vector3(0.26, 0.36, 0.22), Vector3(-1.75, 2.2, rmax.y + 1.7), MeshLib.emissive("#ffc477", 1.3), "PorchLantern")
	MeshLib.add_omni_light(self, Vector3(-1.75, 2.15, rmax.y + 1.8), "#ffc477", 0.7, 4.0, false)
	# Rug with a woven border.
	MeshLib.add_box(self, Vector3(5.4, 0.035, 6.2), Vector3(0.0, 0.028, 2.2), _rug, "HouseRug")
	MeshLib.add_box(self, Vector3(5.7, 0.02, 6.5), Vector3(0.0, 0.021, 2.2), _wood_dark, "RugUnderlay")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.12, 0.04, 6.3), Vector3(side * 2.7, 0.045, 2.2), _gold, "RugBorder")
	for i in 3:
		var diamond := MeshLib.add_box(self, Vector3(0.3, 0.03, 0.3), Vector3(0.0, 0.05, -0.2 + float(i) * 2.3), _gold, "RugDiamond", Vector3(0.0, 45.0, 0.0))
		diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_window(pos: Vector3, on_back_wall: bool) -> void:
	var frame_mat := _wood_dark
	if on_back_wall:
		MeshLib.add_box(self, Vector3(1.75, 2.0, 0.16), pos, frame_mat, "WindowFrame")
		MeshLib.add_box(self, Vector3(1.48, 1.72, 0.1), pos + Vector3(0.0, 0.0, 0.05), _window_light, "WindowGlass")
		MeshLib.add_box(self, Vector3(0.08, 1.7, 0.12), pos + Vector3(0.0, 0.0, 0.08), frame_mat, "MullionV")
		MeshLib.add_box(self, Vector3(1.46, 0.08, 0.12), pos + Vector3(0.0, 0.0, 0.08), frame_mat, "MullionH")
		MeshLib.add_box(self, Vector3(2.1, 0.14, 0.34), pos + Vector3(0.0, -1.06, 0.1), _stone, "WindowSill")
	else:
		MeshLib.add_box(self, Vector3(0.16, 2.0, 1.75), pos, frame_mat, "WindowFrame")
		MeshLib.add_box(self, Vector3(0.1, 1.72, 1.48), pos + Vector3(0.05, 0.0, 0.0), _window_light, "WindowGlass")
		MeshLib.add_box(self, Vector3(0.12, 1.7, 0.08), pos + Vector3(0.08, 0.0, 0.0), frame_mat, "MullionV")
		MeshLib.add_box(self, Vector3(0.12, 0.08, 1.46), pos + Vector3(0.08, 0.0, 0.0), frame_mat, "MullionH")
		MeshLib.add_box(self, Vector3(0.34, 0.14, 2.1), pos + Vector3(0.1, -1.06, 0.0), _stone, "WindowSill")
	MeshLib.add_omni_light(self, pos + Vector3(0.0, 0.2, -0.5), "#ffd196", 0.7, 5.0, false)


func _build_furniture() -> void:
	var theme := str(_house["interior"].get("theme", "hearth"))
	_build_bed()
	_build_table_and_chairs()
	_build_hearth()
	_build_shelves()
	_build_chest_and_barrel()
	match theme:
		"hearth":
			_build_bread_props()
		"herbs":
			_build_herb_props()
		"sea":
			_build_sea_props()
		"elder":
			_build_elder_props()
		"loom":
			_build_loom()
		"forge":
			_build_forge_props()
	# A couple of small stools leave the centre lane open.
	MeshLib.add_cylinder(self, 0.3, 0.27, 0.45, Vector3(2.7, 0.23, 6.2), _wood_dark, "Stool", 8)
	MeshLib.add_cylinder(self, 0.34, 0.3, 0.08, Vector3(2.7, 0.49, 6.2), _wood, "StoolTop", 8)


func _build_service_station() -> void:
	if _service.is_empty():
		return
	var station: Vector2 = GameState.vec2_from_array(_service.get("station", [2.7, -7.4]))
	var accent := Color(str(_service.get("accent", "#b89755")))
	var accent_mat := MeshLib.material(accent.to_html(false), 0.55, 0.18)
	var counter_z := station.y - 0.6
	var room: Dictionary = data["room"]
	var rmin: Vector2 = GameState.vec2_from_array(room["min"])

	# A small woven runner draws the eye toward the service counter.
	MeshLib.add_box(self, Vector3(3.4, 0.02, 2.6), Vector3(station.x, 0.022, station.y + 1.2), _wood_dark, "ServiceRunnerUnderlay")
	MeshLib.add_box(self, Vector3(3.1, 0.03, 2.3), Vector3(station.x, 0.034, station.y + 1.2), _rug, "ServiceRunner")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(self, Vector3(0.06, 0.035, 2.3), Vector3(station.x + side * 1.55, 0.04, station.y + 1.2), accent_mat, "ServiceRunnerTrim")

	# Shop counter.
	MeshLib.add_box(self, Vector3(3.6, 0.82, 0.86), Vector3(station.x, 0.42, counter_z), _wood_dark, "ServiceCounterBody")
	MeshLib.add_box(self, Vector3(3.85, 0.14, 1.02), Vector3(station.x, 0.91, counter_z), _wood, "ServiceCounterTop")
	MeshLib.add_box(self, Vector3(3.1, 0.48, 0.05), Vector3(station.x, 0.48, counter_z + 0.47), accent_mat, "ServiceCounterPanel")
	MeshLib.add_box(self, Vector3(3.0, 0.04, 0.06), Vector3(station.x, 0.32, counter_z + 0.51), _gold, "ServiceCounterTrim")
	MeshLib.add_box_collider(self, Vector3(3.8, 1.1, 1.0), Vector3(station.x, 0.55, counter_z), "ServiceCounterSolid")

	# Bell, ledger and a candle on the counter.
	MeshLib.add_cylinder(self, 0.12, 0.07, 0.08, Vector3(station.x - 0.9, 1.03, counter_z), _gold, "ServiceBell", 10)
	MeshLib.add_sphere(self, 0.1, Vector3(station.x - 0.9, 1.1, counter_z), _gold, "ServiceBellTop", 0.1, 8)
	MeshLib.add_box(self, Vector3(0.55, 0.08, 0.38), Vector3(station.x + 0.4, 1.0, counter_z - 0.05), _plaster, "ServiceLedger", Vector3(0.0, 12.0, 0.0))
	MeshLib.add_box(self, Vector3(0.42, 0.02, 0.28), Vector3(station.x + 0.4, 1.05, counter_z - 0.05), MeshLib.material("#e3d5b8", 0.95), "ServicePage")
	MeshLib.add_cylinder(self, 0.06, 0.06, 0.3, Vector3(station.x + 1.35, 1.06, counter_z), MeshLib.material("#e2d6ba", 0.9), "ServiceCandle", 8)
	MeshLib.add_sphere(self, 0.065, Vector3(station.x + 1.35, 1.25, counter_z), _fire, "ServiceCandleFlame", 0.16, 6)

	# The service name is mounted on the back wall.
	var back_z := rmin.y + 0.16
	MeshLib.add_box(self, Vector3(3.3, 0.95, 0.12), Vector3(station.x, 3.0, back_z), _wood_dark, "ServiceSignBoard")
	MeshLib.add_box(self, Vector3(3.5, 0.08, 0.17), Vector3(station.x, 3.48, back_z + 0.02), _gold, "ServiceSignTop")
	MeshLib.add_box(self, Vector3(3.5, 0.08, 0.17), Vector3(station.x, 2.52, back_z + 0.02), _gold, "ServiceSignBottom")
	var sign_label := MeshLib.add_label3d(self, str(_service.get("sign", "УСЛУГИ")), Vector3(station.x, 3.0, back_z + 0.2), 34, accent.lightened(0.2).to_html(false), "ServiceSign")
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.no_depth_test = true
	sign_label.pixel_size = 0.009
	sign_label.width = 2000.0
	sign_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# A warm pool of light isolates the counter from the living part of the room.
	MeshLib.add_omni_light(self, Vector3(station.x, 2.5, station.y), accent.lightened(0.12).to_html(false), 1.15, 5.2, false)
	match _service_id:
		"inn":
			_build_inn_service(station, accent_mat)
		"item_shop":
			_build_item_service(station, accent_mat)
		"weapon_shop":
			_build_weapon_service(station, accent_mat)
		"armor_shop":
			_build_armor_service(station, accent_mat)
		"clinic":
			_build_clinic_service(station, accent_mat)
	var point := add_interactable("service", str(_service.get("prompt", "E — Услуга")), {
		"service_id": _service_id,
		"house_id": str(_house["id"])
	}, Vector3(station.x, 0.0, station.y))
	point.focus_offset = Vector3(0.0, 1.25, 0.0)


func _build_inn_service(station: Vector2, accent_mat: StandardMaterial3D) -> void:
	var back_z := float(data["room"]["min"][1]) + 0.2
	# Key rack.
	MeshLib.add_box(self, Vector3(2.2, 1.25, 0.12), Vector3(station.x - 2.5, 2.4, back_z), _wood, "InnKeyRack")
	for i in 5:
		var key_y := 2.17 + float(i % 3) * 0.2
		var key_x := station.x - 3.1 + float(i) * 0.28
		MeshLib.add_sphere(self, 0.04, Vector3(key_x, key_y, back_z + 0.1), _gold, "InnKeyRing", -1.0, 6)
		MeshLib.add_box(self, Vector3(0.025, 0.14, 0.025), Vector3(key_x, key_y - 0.08, back_z + 0.1), _gold, "InnKey")
	MeshLib.add_cylinder(self, 0.19, 0.14, 0.35, Vector3(station.x + 1.35, 1.1, station.y - 0.2), MeshLib.material("#b9aa8e", 0.95), "InnJug", 8)
	MeshLib.add_box(self, Vector3(0.8, 0.05, 0.5), Vector3(station.x - 1.8, 0.05, station.y + 1.4), _rug, "InnWelcomeMat")
	MeshLib.add_box(self, Vector3(0.9, 0.03, 0.6), Vector3(station.x - 1.8, 0.08, station.y + 1.4), accent_mat, "InnMatTrim")


func _build_item_service(station: Vector2, accent_mat: StandardMaterial3D) -> void:
	var back_z := float(data["room"]["min"][1]) + 0.2
	# Apothecary shelves behind the counter.
	MeshLib.add_box(self, Vector3(2.4, 2.2, 0.35), Vector3(station.x + 2.2, 1.35, back_z), _wood_dark, "ShopCabinet")
	for shelf in 3:
		MeshLib.add_box(self, Vector3(2.1, 0.08, 0.5), Vector3(station.x + 2.2, 0.55 + float(shelf) * 0.62, back_z + 0.18), _wood, "ShopShelf")
		for i in 3:
			var jar_color: Color = accent_mat.albedo_color.lerp(Color("#b55b55"), float(i) * 0.3)
			MeshLib.add_cylinder(self, 0.08, 0.06, 0.22, Vector3(station.x + 1.55 + float(i) * 0.5, 0.72 + float(shelf) * 0.62, back_z + 0.18), MeshLib.emissive(jar_color.to_html(false), 0.25), "ShopJar", 8)
	# A small basket of goods on the counter.
	MeshLib.add_cylinder(self, 0.25, 0.19, 0.16, Vector3(station.x + 0.95, 1.04, station.y - 0.65), _wood, "ShopBasket", 10)
	for i in 3:
		MeshLib.add_sphere(self, 0.07, Vector3(station.x + 0.82 + float(i) * 0.13, 1.12, station.y - 0.65), _flower_mats[i % _flower_mats.size()], "ShopHerb", -1.0, 6)


func _build_weapon_service(station: Vector2, accent_mat: StandardMaterial3D) -> void:
	var back_z := float(data["room"]["min"][1]) + 0.2
	var steel := MeshLib.material("#8d979e", 0.35, 0.6)
	MeshLib.add_box(self, Vector3(2.5, 1.55, 0.13), Vector3(station.x + 2.7, 1.85, back_z), _wood, "WeaponRack")
	for i in 2:
		var x := station.x + 2.05 + float(i) * 1.25
		MeshLib.add_box(self, Vector3(0.08, 1.35, 0.05), Vector3(x, 1.85, back_z + 0.12), steel, "WeaponSword")
		MeshLib.add_box(self, Vector3(0.4, 0.06, 0.08), Vector3(x, 1.2, back_z + 0.14), _gold, "WeaponGuard")
		MeshLib.add_cylinder(self, 0.035, 0.03, 0.8, Vector3(x + 0.5, 1.7, back_z + 0.12), _wood_dark, "WeaponSpearShaft", 6)
		MeshLib.add_box(self, Vector3(0.09, 0.3, 0.04), Vector3(x + 0.5, 2.2, back_z + 0.12), steel, "WeaponSpearhead")
	var display_sword := MeshLib.add_box(self, Vector3(0.06, 0.9, 0.04), Vector3(station.x + 0.9, 1.55, station.y - 0.7), steel, "DisplaySword")
	display_sword.rotation_degrees = Vector3(0.0, 0.0, -15.0)
	MeshLib.add_box(self, Vector3(0.5, 0.06, 0.35), Vector3(station.x + 0.9, 1.06, station.y - 0.7), _gold, "DisplaySwordStand")


func _build_armor_service(station: Vector2, accent_mat: StandardMaterial3D) -> void:
	var stand_pos := Vector3(station.x + 2.3, 0.0, station.y - 0.25)
	MeshLib.add_box(self, Vector3(0.8, 0.18, 0.8), stand_pos + Vector3(0.0, 0.09, 0.0), _wood_dark, "ArmorStandBase")
	MeshLib.add_cylinder(self, 0.12, 0.09, 1.6, stand_pos + Vector3(0.0, 0.9, 0.0), _wood, "ArmorStandPole", 8)
	MeshLib.add_cylinder(self, 0.4, 0.3, 0.7, stand_pos + Vector3(0.0, 1.6, 0.0), accent_mat, "ArmorStandTorso", 8)
	MeshLib.add_box(self, Vector3(0.75, 0.28, 0.35), stand_pos + Vector3(0.0, 1.35, 0.0), MeshLib.material("#b9aa8e", 0.7, 0.25), "ArmorStandBelt")
	MeshLib.add_box_collider(self, Vector3(1.1, 1.9, 1.1), stand_pos + Vector3(0.0, 0.95, 0.0), "ArmorStandSolid")
	var back_z := float(data["room"]["min"][1]) + 0.2
	MeshLib.add_cylinder(self, 0.65, 0.65, 0.12, Vector3(station.x + 4.3, 2.2, back_z), SteelShieldMaterial(), "DisplayShield", 16, Vector3(90.0, 0.0, 0.0))
	MeshLib.add_cylinder(self, 0.18, 0.18, 0.14, Vector3(station.x + 4.3, 2.2, back_z + 0.08), _gold, "DisplayShieldBoss", 12, Vector3(90.0, 0.0, 0.0))


func _build_clinic_service(station: Vector2, accent_mat: StandardMaterial3D) -> void:
	var cot_pos := Vector3(station.x + 3.2, 0.0, station.y - 0.1)
	MeshLib.add_box(self, Vector3(2.4, 0.36, 3.0), cot_pos + Vector3(0.0, 0.35, 0.0), _wood_dark, "ClinicCotFrame")
	MeshLib.add_box(self, Vector3(2.25, 0.18, 2.8), cot_pos + Vector3(0.0, 0.62, 0.0), MeshLib.material("#ddd3bd", 0.96), "ClinicCotMattress")
	MeshLib.add_box(self, Vector3(2.05, 0.1, 2.5), cot_pos + Vector3(0.0, 0.72, 0.08), accent_mat, "ClinicCotBlanket")
	MeshLib.add_box(self, Vector3(1.5, 0.18, 0.55), cot_pos + Vector3(0.0, 0.72, -1.05), MeshLib.material("#e9e1d0", 0.98), "ClinicPillow")
	MeshLib.add_box_collider(self, Vector3(2.6, 1.0, 3.2), cot_pos + Vector3(0.0, 0.5, 0.0), "ClinicCotSolid")
	var back_z := float(data["room"]["min"][1]) + 0.2
	for i in 4:
		var jar_mat := MeshLib.emissive(accent_mat.albedo_color.lightened(0.12 + float(i) * 0.06).to_html(false), 0.2)
		MeshLib.add_cylinder(self, 0.09, 0.07, 0.24, Vector3(station.x - 2.0 + float(i) * 0.35, 1.9 + float(i % 2) * 0.25, back_z + 0.12), jar_mat, "ClinicJar", 8)
	MeshLib.add_box(self, Vector3(1.8, 0.12, 0.5), Vector3(station.x - 1.8, 1.4, back_z + 0.28), _wood, "ClinicShelf")
	MeshLib.add_cylinder(self, 0.28, 0.22, 0.22, Vector3(station.x - 1.4, 1.58, back_z + 0.28), _stone, "ClinicMortar", 10)
	MeshLib.add_box(self, Vector3(2.4, 2.0, 0.07), Vector3(station.x - 2.3, 1.7, station.y + 0.4), _rug, "ClinicCurtain")
	MeshLib.add_cylinder(self, 0.045, 0.035, 2.1, Vector3(station.x - 2.3, 2.8, station.y + 0.4), _gold, "ClinicCurtainRod", 6)


func SteelShieldMaterial() -> StandardMaterial3D:
	return MeshLib.material("#929ba0", 0.4, 0.55)


func _build_bed() -> void:
	var bed_center := Vector3(-5.1, 0.0, -6.1)
	MeshLib.add_box(self, Vector3(2.8, 0.45, 4.0), bed_center + Vector3(0.0, 0.3, 0.0), _wood_dark, "BedFrame")
	MeshLib.add_box(self, Vector3(2.55, 0.3, 3.7), bed_center + Vector3(0.0, 0.63, 0.0), MeshLib.material("#d8c9aa", 0.98), "Mattress")
	MeshLib.add_box(self, Vector3(2.35, 0.22, 2.6), bed_center + Vector3(0.0, 0.83, 0.55), _rug, "Blanket")
	MeshLib.add_box(self, Vector3(2.35, 0.08, 0.75), bed_center + Vector3(0.0, 0.78, 0.35), _gold, "BlanketTrim")
	MeshLib.add_box(self, Vector3(1.8, 0.24, 0.7), bed_center + Vector3(0.0, 0.86, -1.25), MeshLib.material("#e9dfca", 1.0), "Pillow")
	MeshLib.add_box(self, Vector3(3.0, 1.2, 0.22), bed_center + Vector3(0.0, 0.8, -2.0), _wood, "Headboard")
	MeshLib.add_box_collider(self, Vector3(3.0, 1.0, 4.2), bed_center + Vector3(0.0, 0.5, 0.0), "BedSolid")


func _build_table_and_chairs() -> void:
	var t := Vector3(4.0, 0.0, -3.0)
	MeshLib.add_box(self, Vector3(2.6, 0.14, 1.6), t + Vector3(0.0, 0.86, 0.0), _wood, "TableTop")
	for x: float in [-1.05, 1.05]:
		for z: float in [-0.55, 0.55]:
			MeshLib.add_box(self, Vector3(0.14, 0.85, 0.14), t + Vector3(x, 0.43, z), _wood_dark, "TableLeg")
	MeshLib.add_box_collider(self, Vector3(2.7, 0.95, 1.7), t + Vector3(0.0, 0.48, 0.0), "TableSolid")
	# Chairs.
	for side: float in [-1.0, 1.0]:
		var c := t + Vector3(0.0, 0.0, side * 1.45)
		MeshLib.add_box(self, Vector3(0.8, 0.12, 0.8), c + Vector3(0.0, 0.48, 0.0), _wood, "ChairSeat")
		MeshLib.add_box(self, Vector3(0.8, 0.9, 0.12), c + Vector3(0.0, 0.95, -0.34), _wood_dark, "ChairBack")
		for lx in [-0.3, 0.3]:
			MeshLib.add_box(self, Vector3(0.09, 0.48, 0.09), c + Vector3(lx, 0.24, 0.28), _wood_dark, "ChairLeg")
		MeshLib.add_box_collider(self, Vector3(0.9, 0.9, 0.9), c + Vector3(0.0, 0.45, 0.0), "ChairSolid")
	# Table props.
	MeshLib.add_cylinder(self, 0.24, 0.2, 0.08, t + Vector3(0.3, 0.97, 0.1), MeshLib.material("#cec2a8", 0.7), "Plate", 12)
	MeshLib.add_cylinder(self, 0.16, 0.11, 0.18, t + Vector3(-0.6, 0.99, -0.1), MeshLib.material("#d4c8ac", 0.45), "Mug", 8)
	MeshLib.add_sphere(self, 0.12, t + Vector3(0.55, 1.05, -0.25), MeshLib.material("#b76b42", 0.9), "Loaf", 0.18, 8)
	MeshLib.add_box(self, Vector3(0.12, 0.24, 0.12), t + Vector3(-0.9, 1.05, 0.35), MeshLib.material("#e2d3b4", 0.8), "Candle")
	MeshLib.add_sphere(self, 0.045, t + Vector3(-0.9, 1.2, 0.35), _fire, "CandleFlame", 0.12, 6)
	MeshLib.add_omni_light(self, t + Vector3(-0.9, 1.35, 0.35), "#ffb968", 0.7, 3.5, false)


func _build_hearth() -> void:
	var p := Vector3(-7.2, 0.0, 2.0)
	MeshLib.add_box(self, Vector3(1.8, 3.9, 2.7), p + Vector3(0.7, 1.95, 0.0), _stone, "Chimney")
	MeshLib.add_box(self, Vector3(1.9, 0.3, 2.8), p + Vector3(0.7, 0.15, 0.0), _stone, "HearthBase")
	MeshLib.add_box(self, Vector3(0.45, 1.5, 1.8), p + Vector3(1.45, 0.9, 0.0), MeshLib.material("#1e1815", 1.0), "Firebox")
	for i in 3:
		MeshLib.add_box(self, Vector3(0.3, 0.9, 0.18), p + Vector3(1.55, 1.9 + float(i) * 0.62, 0.0), _stone, "HearthMantel")
	MeshLib.add_box(self, Vector3(1.1, 0.15, 0.9), p + Vector3(0.45, 0.1, 0.0), _wood_dark, "HearthLog")
	var flame := MeshLib.add_cylinder(self, 0.4, 0.04, 0.9, p + Vector3(1.05, 0.7, 0.0), _fire, "HearthFlame", 7)
	flame.scale = Vector3(1.0, 1.0, 0.65)
	MeshLib.add_omni_light(self, p + Vector3(1.2, 1.1, 0.0), "#ff9148", 1.9, 7.5, true)
	MeshLib.add_box_collider(self, Vector3(2.1, 2.8, 3.0), p + Vector3(0.7, 1.4, 0.0), "HearthSolid")


func _build_shelves() -> void:
	var x := 7.62
	MeshLib.add_box(self, Vector3(0.35, 2.6, 4.8), Vector3(x, 1.3, -5.6), _wood_dark, "ShelfBack")
	for i in 4:
		var y := 0.55 + float(i) * 0.62
		MeshLib.add_box(self, Vector3(0.7, 0.12, 4.5), Vector3(x - 0.2, y, -5.6), _wood, "Shelf")
		for j in 4:
			var mat: Material = [_accent, _rug, _window_light, _stone][(i + j) % 4]
			var h := 0.3 + float((i * 3 + j) % 3) * 0.12
			MeshLib.add_box(self, Vector3(0.2, h, 0.28), Vector3(x - 0.25, y + h * 0.5 + 0.06, -7.0 + float(j) * 0.9), mat, "Book")
	MeshLib.add_box_collider(self, Vector3(0.8, 2.6, 4.8), Vector3(x - 0.2, 1.3, -5.6), "ShelfSolid")


func _build_chest_and_barrel() -> void:
	var chest := Vector3(5.0, 0.0, 8.1)
	MeshLib.add_box(self, Vector3(1.6, 0.8, 1.0), chest + Vector3(0.0, 0.4, 0.0), _wood, "Chest")
	MeshLib.add_box(self, Vector3(1.65, 0.25, 1.05), chest + Vector3(0.0, 0.93, 0.0), _wood_dark, "ChestLid")
	for x: float in [-0.5, 0.5]:
		MeshLib.add_box(self, Vector3(0.12, 0.82, 1.07), chest + Vector3(x, 0.42, 0.0), _gold, "ChestBand")
	MeshLib.add_box_collider(self, Vector3(1.7, 0.9, 1.1), chest + Vector3(0.0, 0.5, 0.0), "ChestSolid")
	var barrel := Vector3(-5.7, 0.0, 7.9)
	MeshLib.add_cylinder(self, 0.48, 0.42, 1.0, barrel + Vector3(0.0, 0.5, 0.0), _wood, "Barrel", 10)
	MeshLib.add_cylinder(self, 0.5, 0.5, 0.08, barrel + Vector3(0.0, 0.3, 0.0), _gold, "BarrelBand", 10)
	MeshLib.add_cylinder(self, 0.5, 0.5, 0.08, barrel + Vector3(0.0, 0.78, 0.0), _gold, "BarrelBand", 10)
	MeshLib.add_cylinder_collider(self, 0.5, 1.0, barrel + Vector3(0.0, 0.5, 0.0), "BarrelSolid")


func _build_bread_props() -> void:
	for i in 3:
		MeshLib.add_sphere(self, 0.14, Vector3(3.1 + float(i) * 0.42, 1.08, -3.0), MeshLib.material("#b97545", 0.9), "Bread", 0.22, 8)
	MeshLib.add_box(self, Vector3(0.7, 0.9, 0.7), Vector3(-6.2, 0.45, -1.0), MeshLib.material("#bcad8c", 0.95), "FlourSack")
	MeshLib.add_cylinder(self, 0.35, 0.3, 0.42, Vector3(6.2, 0.21, 2.4), _accent, "Bowl", 10)


func _build_herb_props() -> void:
	for i in 5:
		var x := -2.4 + float(i) * 1.25
		MeshLib.add_box(self, Vector3(0.12, 0.9, 0.12), Vector3(x, 4.55, -9.55), _wood_dark, "HerbHanger")
		for j in 3:
			MeshLib.add_sphere(self, 0.19, Vector3(x - 0.16 + float(j) * 0.16, 4.4, -9.45), _accent, "HerbBundle", 0.35, 6)
	for i in 4:
		MeshLib.add_cylinder(self, 0.12, 0.09, 0.3, Vector3(6.3, 1.0, 1.0 + float(i) * 0.5), MeshLib.material("#7f8e64", 0.7), "Jar", 8)
	MeshLib.add_cylinder(self, 0.24, 0.2, 0.25, Vector3(4.0, 1.0, -1.4), _stone, "Mortar", 10)


func _build_sea_props() -> void:
	var net_mat := MeshLib.material("#6b715d", 0.95)
	MeshLib.add_box(self, Vector3(2.4, 1.8, 0.06), Vector3(6.2, 2.3, -8.62), net_mat, "FishingNet")
	for i in 5:
		MeshLib.add_box(self, Vector3(2.2, 0.025, 0.035), Vector3(6.2, 1.5 + float(i) * 0.35, -8.56), net_mat, "NetThread")
		MeshLib.add_box(self, Vector3(0.035, 1.65, 0.035), Vector3(5.25 + float(i) * 0.47, 2.3, -8.56), net_mat, "NetThread")
	for i in 4:
		var angle := TAU * float(i) / 4.0
		MeshLib.add_cylinder(self, 0.32, 0.32, 0.06, Vector3(5.8 + cos(angle) * 0.1, 0.05 + float(i) * 0.065, 5.0 + sin(angle) * 0.1), MeshLib.material("#8a7448", 0.95), "RopeCoil", 16)
	MeshLib.add_sphere(self, 0.22, Vector3(-5.8, 0.25, 5.1), _accent, "NetFloat", 0.35, 8)


func _build_elder_props() -> void:
	var shelf_x := -7.2
	MeshLib.add_box(self, Vector3(0.5, 2.8, 3.4), Vector3(shelf_x, 1.4, -4.0), _wood_dark, "Bookcase")
	for i in 4:
		MeshLib.add_box(self, Vector3(0.8, 0.1, 3.2), Vector3(shelf_x + 0.2, 0.5 + float(i) * 0.62, -4.0), _wood, "BookShelf")
		for j in 5:
			MeshLib.add_box(self, Vector3(0.25, 0.36, 0.28), Vector3(shelf_x + 0.3, 0.7 + float(i) * 0.62, -5.3 + float(j) * 0.55), [_rug, _accent, _gold][j % 3], "Book")
	MeshLib.add_box_collider(self, Vector3(0.9, 2.8, 3.4), Vector3(shelf_x, 1.4, -4.0), "BookcaseSolid")
	MeshLib.add_box(self, Vector3(1.4, 0.08, 1.0), Vector3(-3.8, 0.62, 4.4), _wood, "OpenBook")
	MeshLib.add_box(self, Vector3(1.2, 0.02, 0.8), Vector3(-3.8, 0.68, 4.4), MeshLib.material("#e0d6bd", 0.9), "Pages")


func _build_loom() -> void:
	var loom := Vector3(5.9, 0.0, 3.2)
	MeshLib.add_box(self, Vector3(0.18, 3.0, 0.18), loom + Vector3(-1.0, 1.5, -1.4), _wood_dark, "LoomPost")
	MeshLib.add_box(self, Vector3(0.18, 3.0, 0.18), loom + Vector3(1.0, 1.5, -1.4), _wood_dark, "LoomPost")
	MeshLib.add_box(self, Vector3(2.3, 0.16, 0.2), loom + Vector3(0.0, 2.6, -1.35), _wood, "LoomBeam")
	MeshLib.add_box(self, Vector3(1.9, 2.0, 0.08), loom + Vector3(0.0, 1.45, -1.3), _rug, "Cloth")
	MeshLib.add_box(self, Vector3(2.0, 0.16, 1.1), loom + Vector3(0.0, 0.6, -0.7), _wood, "LoomSeat")
	for i in 7:
		MeshLib.add_box(self, Vector3(0.035, 1.8, 0.035), loom + Vector3(-0.8 + float(i) * 0.26, 1.5, -1.22), _window_light, "LoomThread")
	MeshLib.add_box_collider(self, Vector3(2.6, 1.4, 2.4), loom + Vector3(0.0, 0.7, -0.2), "LoomSolid")


func _build_forge_props() -> void:
	var anvil := Vector3(-4.8, 0.0, 3.4)
	MeshLib.add_box(self, Vector3(1.0, 0.6, 0.7), anvil + Vector3(0.0, 0.3, 0.0), MeshLib.material("#4e5456", 0.5, 0.5), "AnvilBase")
	MeshLib.add_box(self, Vector3(1.8, 0.3, 0.55), anvil + Vector3(0.0, 0.72, 0.0), MeshLib.material("#555c60", 0.4, 0.6), "Anvil")
	MeshLib.add_box(self, Vector3(0.35, 0.25, 0.35), anvil + Vector3(0.65, 0.98, 0.0), MeshLib.material("#3b4144", 0.5, 0.6), "Hammer")
	MeshLib.add_box_collider(self, Vector3(1.9, 1.0, 0.8), anvil + Vector3(0.0, 0.5, 0.0), "AnvilSolid")
	for i in 3:
		MeshLib.add_box(self, Vector3(0.12, 2.0, 0.12), Vector3(7.3, 1.0, 5.4 + float(i) * 0.35), _wood_dark, "WeaponRack")
		MeshLib.add_box(self, Vector3(0.06, 1.4, 0.22), Vector3(7.25, 2.0, 5.4 + float(i) * 0.35), MeshLib.material("#7a8287", 0.35, 0.7), "Blade")


func _build_lighting() -> void:
	MeshLib.add_omni_light(self, Vector3(0.0, 4.3, 1.0), "#ffc981", 1.8, 12.0, true)
	MeshLib.add_omni_light(self, Vector3(0.0, 3.7, 8.0), "#eec187", 0.9, 8.0, false)
	MeshLib.add_omni_light(self, Vector3(-4.0, 3.0, -5.0), "#d7a56f", 0.7, 8.0, false)
	MeshLib.add_omni_light(self, Vector3(4.5, 3.2, 4.5), "#e0b77c", 0.7, 8.0, false)
	# Warm dust motes, a tiny bit of life in the still room.
	var particles := GPUParticles3D.new()
	particles.name = "DustMotes"
	particles.position = Vector3(0.0, 2.2, 1.0)
	particles.amount = 20
	particles.lifetime = 8.0
	particles.preprocess = 2.0
	particles.emitting = true
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(5.5, 1.8, 6.0)
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = 0.01
	process.initial_velocity_max = 0.05
	process.gravity = Vector3(0.0, 0.01, 0.0)
	process.scale_min = 0.4
	process.scale_max = 0.9
	process.color = Color(1.0, 0.9, 0.68, 0.5)
	particles.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.022
	mesh.height = 0.044
	mesh.radial_segments = 5
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.62, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.draw_pass_1 = mesh
	add_child(particles)


func _build_exit() -> void:
	var exit_data: Dictionary = data["exit"]
	var pos: Vector2 = GameState.vec2_from_array(exit_data["local"])
	var point := add_interactable("door", str(exit_data["prompt"]), {
		"target": "town",
		"spawn": str(_house["door"]["return_spawn"]),
		"label": "Корнелия"
	}, Vector3(pos.x, 0.0, pos.y))
	point.focus_offset = Vector3(0.0, 1.2, 0.0)
