extends Node3D

var data: Dictionary
var math: Dictionary
var location_id: String
var location: Dictionary
var visuals
var floors: Array = []
var solids: Array = []
var npcs: Array = []
var npc_nodes: Dictionary = {}
var service: Dictionary = {}
var flags: Dictionary = {}
var props: Array = []
var prop_nodes: Dictionary = {}
var planks: Array = []
var rails: Array = []
var builders: Array = []
var carriers: Array = []
var front_x: float = 0.0
var building: bool = false


func _init(config: Dictionary, id: String, factory, flag_state: Dictionary) -> void:
	data = config
	math = data.settings.math
	location_id = id
	location = data.locations[location_id].duplicate(true)
	solids = location.get("solids", []).duplicate(true)
	visuals = factory
	flags = flag_state


func _ready() -> void:
	name = "Location_" + location_id
	if location.kind == "town":
		floors = location.floors.duplicate(true)
		_build_town()
	elif location.kind == "dungeon":
		floors = location.floors.duplicate(true)
		_build_dungeon()
	elif location.kind == "strait":
		floors = location.floors.duplicate(true)
		_build_strait()
	else:
		if location.kind == "home":
			floors = data.home_template.floors.duplicate(true)
		else:
			floors = location.floors.duplicate(true)
		_build_interior()
	_build_npcs()


func contains(rect: Dictionary, point: Vector2i) -> bool:
	var first: Vector2i = visuals.cell(rect.from)
	var last: Vector2i = visuals.cell(rect.to)
	return point.x >= first.x and point.x <= last.x and point.y >= first.y and point.y <= last.y


func is_walkable(point: Vector2i) -> bool:
	var on_floor: bool = false
	for rect in floors:
		if contains(rect, point):
			on_floor = true
			break
	if not on_floor:
		return false
	for rect in solids:
		if contains(rect, point):
			return false
	for npc in npcs:
		if visuals.cell(npc.cell) == point:
			return false
	for prop in props:
		if visuals.cell(prop.cell) == point and not (str(prop.type) == "locked_door" and is_set(str(prop.flag))):
			return false
	return true


func is_set(flag: String) -> bool:
	return bool(flags.get(flag, false))


func shown(entry: Dictionary) -> bool:
	if entry.has("requires") and not is_set(str(entry.requires)):
		return false
	return not (entry.has("hidden_by") and is_set(str(entry.hidden_by)))


func is_bridge(point: Vector2i) -> bool:
	return location_id == "town" and contains(data.town.bridge, point)


func encounter_at(point: Vector2i) -> String:
	if not portal_for(point).is_empty():
		return ""
	if is_bridge(point):
		return "bridge"
	return str(location.get("encounter", ""))


func portal_for(point: Vector2i) -> Dictionary:
	for door in location.get("doors", []):
		if visuals.cell(door.cell) == point:
			return door
	return {}


func nearest_npc(point: Vector2i) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance: float = float(data.settings.interaction_distance) + float(math.one)
	for npc in npcs:
		var offset: Vector2i = visuals.cell(npc.cell) - point
		var distance: float = float(absi(offset.x) + absi(offset.y))
		if distance <= float(data.settings.interaction_distance) and distance < nearest_distance:
			nearest = npc
			nearest_distance = distance
	return nearest


func nearest_service(point: Vector2i) -> Dictionary:
	if service.is_empty():
		return {}
	var offset: Vector2i = visuals.cell(service.cell) - point
	var distance: float = float(absi(offset.x) + absi(offset.y))
	return service if distance <= float(data.settings.interaction_distance) else {}


func nearest_prop(point: Vector2i) -> Dictionary:
	for prop in props:
		var offset: Vector2i = visuals.cell(prop.cell) - point
		if not is_set(str(prop.flag)) and float(absi(offset.x) + absi(offset.y)) <= float(data.settings.interaction_distance):
			return prop
	return {}


func open_prop(prop: Dictionary) -> void:
	var d: Dictionary = data.settings.geometry.dungeon
	var node: Node3D = prop_nodes[str(prop.flag)]
	var tween: Tween = create_tween()
	if str(prop.type) == "chest":
		var glint: Node3D = node.get_node("Glint")
		glint.show()
		tween.tween_property(node.get_node("LidPivot"), "rotation:x", -float(d.chest_open_angle), float(d.chest_open_time))
		tween.parallel().tween_property(glint, "position:y", glint.position.y + float(d.chest_lid[int(math.middle)]) * math.double, float(d.chest_open_time) * math.double)
		tween.tween_callback(glint.hide)
	else:
		tween.tween_property(node.get_node("LeafPivot"), "rotation:y", float(d.door_open_angle), float(d.door_open_time))


func face_npc(npc: Dictionary, from_cell: Vector2i) -> void:
	var offset: Vector2i = from_cell - visuals.cell(npc.cell)
	if npc_nodes.has(npc.id):
		npc_nodes[npc.id].rotation.y = atan2(float(offset.x), float(offset.y))


func move_npc(npc_id: String, destination: Vector2i, duration: float, look_cell: Vector2i) -> Tween:
	var node: Node3D = npc_nodes[npc_id]
	for npc in npcs:
		if str(npc.id) == npc_id:
			npc.cell = [destination.x, destination.y]
	var target: Vector3 = visuals.at(destination, math.zero)
	var offset: Vector3 = target - node.position
	node.rotation.y = atan2(offset.x, offset.z)
	var facing: Vector2i = look_cell - destination
	var tween: Tween = create_tween()
	tween.tween_property(node, "position", target, duration)
	tween.tween_property(node, "rotation:y", atan2(float(facing.x), float(facing.y)), duration * math.quarter)
	return tween


func _block(rect: Dictionary) -> void:
	solids.append(rect.duplicate(true))


func _ground(rect: Dictionary) -> void:
	var info: Dictionary = visuals.rectangle(rect)
	var depth: float = float(data.settings.geometry.ground_depth)
	var surface_offset: float = float(data.settings.geometry.path_height)
	visuals.box(self, info.center - Vector3.UP * (depth * math.half + surface_offset), Vector3(info.width, depth, info.depth), "soil")
	visuals.plane(self, info.center, info.width, info.depth, "grass")


func _paving(rect: Dictionary) -> void:
	var info: Dictionary = visuals.rectangle(rect)
	var g: Dictionary = data.settings.geometry
	visuals.plane(self, info.center + Vector3.UP * float(g.path_height), info.width, info.depth, "path")
	_stones(info)


func _curbs(rects: Array) -> void:
	var g: Dictionary = data.settings.geometry
	var tile: float = float(data.settings.tile_size)
	var cells: Dictionary = {}
	for rect in rects:
		var first: Vector2i = visuals.cell(rect.from)
		var last: Vector2i = visuals.cell(rect.to)
		for x in range(first.x, last.x + int(math.one)):
			for z in range(first.y, last.y + int(math.one)):
				cells[Vector2i(x, z)] = true
	var y: float = float(g.path_height) + float(g.path_border_height) * math.half
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var horizontal: bool = direction.x == int(math.zero)
		var lines: Dictionary = {}
		for point in cells:
			if cells.has(point + direction):
				continue
			var key: int = point.y if horizontal else point.x
			if not lines.has(key):
				lines[key] = []
			lines[key].append(point.x if horizontal else point.y)
		var sign_value: float = float(direction.y if horizontal else direction.x)
		for key in lines:
			var values: Array = lines[key]
			values.sort()
			var start: int = values.front()
			for index in range(values.size()):
				if index + int(math.one) < values.size() and values[index + int(math.one)] == values[index] + int(math.one):
					continue
				var from_value: float = (float(start) - math.half) * tile
				var to_value: float = (float(values[index]) + math.half) * tile
				var middle: float = (from_value + to_value) * math.half
				var length: float = to_value - from_value + float(g.path_border_width)
				var offset: float = (float(key) + math.half * sign_value) * tile
				if horizontal:
					visuals.box(self, Vector3(middle, y, offset), Vector3(length, g.path_border_height, g.path_border_width), "curb")
				else:
					visuals.box(self, Vector3(offset, y, middle), Vector3(g.path_border_width, g.path_border_height, length), "curb")
				if index + int(math.one) < values.size():
					start = values[index + int(math.one)]


func _stones(info: Dictionary) -> void:
	var g: Dictionary = data.settings.geometry
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.settings.random_seed) + int(info.center.x) - int(info.center.z)
	var count: int = int(float(info.width) * float(info.depth) * float(g.cobble_density))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = count
	for index in range(count):
		var width: float = rng.randf_range(float(g.cobble_min_size), float(g.cobble_max_size))
		var depth: float = rng.randf_range(float(g.cobble_min_size), float(g.cobble_max_size))
		var x: float = rng.randf_range(float(info.min_x) + width, float(info.max_x) - width)
		var z: float = rng.randf_range(float(info.min_z) + depth, float(info.max_z) - depth)
		var basis := Basis(Vector3.UP, rng.randf_range(-float(math.quarter) * float(math.quarter), float(math.quarter) * float(math.quarter)))
		basis = basis.scaled(Vector3(width, g.cobble_height, depth))
		var y: float = float(g.path_height) + float(g.cobble_height) * math.half
		multi_mesh.set_instance_transform(index, Transform3D(basis, Vector3(x, y, z)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi_mesh
	instance.material_override = visuals.material("path_light")
	add_child(instance)


func _flowers(rect: Dictionary, material_name: String) -> void:
	var info: Dictionary = visuals.rectangle(rect)
	var g: Dictionary = data.settings.geometry
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.settings.random_seed) - int(info.center.z)
	var count: int = int(float(info.width) * float(info.depth) * float(g.flower_density))
	var mesh := SphereMesh.new()
	mesh.radius = float(g.flower_radius)
	mesh.height = float(g.flower_radius) * math.double
	mesh.radial_segments = int(g.low_poly_segments)
	mesh.rings = int(g.low_poly_segments)
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = count
	for index in range(count):
		var x: float = rng.randf_range(float(info.min_x), float(info.max_x))
		var z: float = rng.randf_range(float(info.min_z), float(info.max_z))
		var point := Vector2i(roundi(x / float(data.settings.tile_size)), roundi(z / float(data.settings.tile_size)))
		var scale_value: float = math.one if can_plant(point) else math.zero
		var basis: Basis = Basis.IDENTITY.scaled(Vector3.ONE * scale_value)
		multi_mesh.set_instance_transform(index, Transform3D(basis, Vector3(x, g.flower_height, z)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi_mesh
	instance.material_override = visuals.material(material_name)
	add_child(instance)


func can_plant(point: Vector2i) -> bool:
	if location.kind != "town" or not is_walkable(point):
		return false
	for rect in data.town.paved:
		if contains(rect, point):
			return false
	return true


func _build_town() -> void:
	var town: Dictionary = data.town
	var g: Dictionary = data.settings.geometry
	for rect in town.outer:
		visuals.outer_ground(self, rect)
	visuals.forest(self, town.forest_areas, town.forest_clear, int(town.forest_count), int(data.settings.random_seed))
	for definition in town.mountains:
		visuals.mountain(self, definition)
	_ground(town.land)
	_ground(town.far_land)
	var riverbed: Dictionary = visuals.rectangle(town.riverbed)
	visuals.box(self, riverbed.center - Vector3.UP * (float(g.riverbed_depth) + float(g.ground_depth) * math.half), Vector3(riverbed.width, g.ground_depth, riverbed.depth), "riverbed")
	var river: Dictionary = visuals.rectangle(town.river)
	visuals.plane(self, river.center + Vector3.UP * float(g.water_level), river.width, river.depth, "water")
	for glint in town.water_glints:
		var position_value: Vector3 = visuals.at(visuals.cell(glint.cell), float(g.water_level) + float(g.path_height))
		visuals.plane(self, position_value, glint.length, g.path_border_width, "water_glint")
	for rect in town.paved:
		_paving(rect)
	_curbs(town.paved)
	visuals.castle(self, town.castle, town.castle_door)
	_block(town.castle)
	for house in town.houses:
		visuals.house(self, house)
		_block(house.rect)
		location.doors.append({"cell": house.door, "destination": house.id, "arrival": data.home_template.arrival, "direction": data.home_template.direction})
	visuals.north_gate(self, visuals.cell(town.north_gate))
	visuals.shrine(self, town.shrine.rect, town.shrine.door)
	visuals.bridge(self, town.bridge)
	visuals.fountain(self, visuals.cell(town.fountain))
	for tree in town.trees:
		visuals.tree(self, visuals.cell(tree.cell), tree.scale, tree.tone)
		var tree_cell: Vector2i = visuals.cell(tree.cell)
		if contains(town.land, tree_cell):
			_block({"from": tree.cell, "to": tree.cell})
	for rect in town.benches:
		visuals.bench(self, rect)
		_block(rect)
	for point in town.planters:
		visuals.planter(self, visuals.cell(point))
		_block({"from": point, "to": point})
	for point in town.rocks:
		visuals.rock(self, visuals.cell(point))
		_block({"from": point, "to": point})
	for wall in town.boundary_walls:
		visuals.wall_between(self, visuals.cell(wall.from), visuals.cell(wall.to), g.town_wall_height, "stone")
	for fence in town.far_fences:
		visuals.wall_between(self, visuals.cell(fence.from), visuals.cell(fence.to), float(g.town_wall_height) * math.half, "stone_dark")
	for entry in town.decor:
		_decor(entry)
	visuals.scatter_grass(self, town.land, can_plant)
	visuals.scatter_grass(self, town.far_land, can_plant)
	_flowers(town.land, "flower_pink")
	_flowers(town.far_land, "flower_yellow")


func _floor(rect: Dictionary, material_name: String, wooden: bool) -> void:
	var info: Dictionary = visuals.rectangle(rect)
	var g: Dictionary = data.settings.geometry
	visuals.box(self, info.center - Vector3.UP * float(g.floor_depth) * math.half, Vector3(info.width, g.floor_depth, info.depth), material_name)
	if wooden:
		var count: int = maxi(int(math.one), int(float(info.depth) / (float(data.settings.tile_size) * math.half)))
		for index in range(count):
			var z: float = float(info.min_z) + float(info.depth) * float(index) / float(count)
			visuals.box(self, Vector3(info.center.x, g.path_height, z), Vector3(info.width, g.path_height, g.interior.rug_height), "wood_light")


func _wall_rect(rect: Dictionary, height: float, material_name: String) -> void:
	var info: Dictionary = visuals.rectangle(rect)
	var g: Dictionary = data.settings.geometry.interior
	var dimensions := Vector3(info.width, height, info.depth)
	if float(info.depth) > float(info.width):
		dimensions.x = float(g.wall_thickness)
	else:
		dimensions.z = float(g.wall_thickness)
	visuals.box(self, info.center + Vector3.UP * height * math.half, dimensions, material_name)
	var trim_dimensions: Vector3 = dimensions
	trim_dimensions.y = float(g.baseboard_height)
	trim_dimensions.x += float(g.wall_thickness) * math.half
	trim_dimensions.z += float(g.wall_thickness) * math.half
	visuals.box(self, info.center + Vector3.UP * float(g.baseboard_height) * math.half, trim_dimensions, "wood")


func _front_wall(rect: Dictionary, height: float, material_name: String) -> void:
	var info: Dictionary = visuals.rectangle(rect)
	var g: Dictionary = data.settings.geometry.interior
	var section_width: float = (float(info.width) - float(g.door_width)) * math.half
	for side in [math.zero - math.one, math.one]:
		var x: float = float(info.center.x) + side * (float(g.door_width) + section_width) * math.half
		visuals.box(self, Vector3(x, height * math.half, info.center.z), Vector3(section_width, height, g.wall_thickness), material_name)
		visuals.box(self, Vector3(float(info.center.x) + side * float(g.door_width) * math.half, float(g.door_height) * math.half, info.center.z), Vector3(g.beam_width, g.door_height, g.wall_thickness), "wood_light")
	visuals.box(self, Vector3(info.center.x, g.door_height, info.center.z), Vector3(float(g.door_width) + float(g.beam_width), g.beam_width, g.wall_thickness), "wood_light")


func _corridor(rect: Dictionary, material_name: String) -> void:
	var info: Dictionary = visuals.rectangle(rect)
	var g: Dictionary = data.settings.geometry.interior
	_floor(rect, "wood_dark", false)
	for side in [math.zero - math.one, math.one]:
		visuals.box(self, Vector3(float(info.center.x) + side * float(info.width) * math.half, float(g.side_wall_height) * math.half, info.center.z), Vector3(g.wall_thickness, g.side_wall_height, info.depth), material_name)
	visuals.box(self, Vector3(info.center.x, float(g.door_height) * math.half, info.max_z), Vector3(g.corridor_width, g.door_height, g.wall_thickness), "wood_dark")


func _room_shell(floor_rect: Dictionary, corridor_rect: Dictionary, wall_material: String, floor_material: String, wooden: bool) -> void:
	var first: Vector2i = visuals.cell(floor_rect.from)
	var last: Vector2i = visuals.cell(floor_rect.to)
	var g: Dictionary = data.settings.geometry.interior
	var back := {"from": [first.x, first.y], "to": [last.x, first.y]}
	var front := {"from": [first.x, last.y], "to": [last.x, last.y]}
	var left := {"from": [first.x, first.y], "to": [first.x, last.y]}
	var right := {"from": [last.x, first.y], "to": [last.x, last.y]}
	_floor(floor_rect, floor_material, wooden)
	_wall_rect(back, g.wall_height, wall_material)
	_wall_rect(left, g.side_wall_height, wall_material)
	_wall_rect(right, g.side_wall_height, wall_material)
	_front_wall(front, g.south_wall_height, wall_material)
	_corridor(corridor_rect, wall_material)
	if wooden:
		var info: Dictionary = visuals.rectangle(floor_rect)
		for side in [math.zero - math.one, math.one]:
			visuals.window(self, Vector3(float(info.center.x) + side * float(info.width) * math.quarter, data.settings.geometry.house.window_y, float(info.min_z) + float(data.settings.tile_size) * math.half + float(g.wall_thickness) * math.half))


func _throne() -> void:
	var g: Dictionary = data.settings.geometry.interior
	var position_value: Vector3 = visuals.at(visuals.cell(data.castle_visual.throne), g.dais_height)
	var root: Node3D = visuals.group(self, "Throne", position_value)
	visuals.box(root, Vector3(math.zero, g.throne_seat_height, math.zero), Vector3(g.throne_width, g.beam_width, g.throne_depth), "gold")
	visuals.box(root, Vector3(math.zero, float(g.throne_seat_height) + float(g.beam_width), math.zero), Vector3(g.throne_width, g.beam_width, g.throne_depth), "royal")
	visuals.box(root, Vector3(math.zero, float(g.throne_height) * math.half, -float(g.throne_depth) * math.half), Vector3(g.throne_width, g.throne_height, g.beam_width), "royal")
	for side in [math.zero - math.one, math.one]:
		visuals.box(root, Vector3(side * float(g.throne_width) * math.half, float(g.throne_height) * math.half, -float(g.throne_depth) * math.half), Vector3(g.beam_width, g.throne_height, g.beam_width), "gold")
		visuals.box(root, Vector3(side * float(g.throne_width) * math.half, float(g.throne_seat_height) * math.half, math.zero), Vector3(g.beam_width, g.throne_seat_height, g.beam_width), "gold")
	visuals.sphere(root, Vector3(math.zero, g.throne_height, -float(g.throne_depth) * math.half), g.column_radius, g.column_radius, "gold")


func _castle_decor() -> void:
	var g: Dictionary = data.settings.geometry.interior
	var carpet: Dictionary = visuals.rectangle(data.castle_visual.carpet)
	visuals.box(self, carpet.center + Vector3.UP * float(g.rug_height), Vector3(carpet.width, g.rug_height, carpet.depth), "carpet")
	for side in [math.zero - math.one, math.one]:
		visuals.box(self, carpet.center + Vector3(float(side) * (float(carpet.width) * math.half - float(g.rug_height)), float(g.rug_height) * math.double, math.zero), Vector3(g.rug_height, g.rug_height, carpet.depth), "carpet_trim")
	var dais: Dictionary = visuals.rectangle(data.castle_visual.dais)
	visuals.box(self, dais.center + Vector3.UP * float(g.dais_height) * math.half, Vector3(dais.width, g.dais_height, dais.depth), "stone_light")
	visuals.box(self, Vector3(dais.center.x, float(g.dais_height) * math.quarter, float(dais.max_z) + float(g.wall_thickness)), Vector3(dais.width, float(g.dais_height) * math.half, g.wall_thickness), "stone")
	for point in data.castle_visual.columns:
		var root: Node3D = visuals.group(self, "Column", visuals.at(visuals.cell(point), math.zero))
		visuals.cylinder(root, Vector3(math.zero, float(g.column_height) * math.half, math.zero), g.column_radius, g.column_height, "stone_light")
		visuals.cylinder(root, Vector3(math.zero, g.beam_width, math.zero), float(g.column_radius) + float(g.beam_width), float(g.beam_width) * math.double, "stone")
		visuals.cylinder(root, Vector3(math.zero, g.column_height, math.zero), float(g.column_radius) + float(g.beam_width), g.beam_width, "gold")
	_throne()
	for definition in data.castle_visual.windows:
		visuals.stained_window(self, visuals.vector(definition))
	for entry in data.castle_visual.decor:
		_decor(entry)
	var floor_info: Dictionary = visuals.rectangle(data.castle_visual.floor)
	for side in [math.zero - math.one, math.one]:
		var x: float = side * float(floor_info.width) * math.quarter
		var wall_face: float = float(floor_info.min_z) + float(data.settings.tile_size) * math.half + float(g.wall_thickness) * math.half
		visuals.box(self, Vector3(x, data.settings.geometry.castle.banner_y, wall_face + float(g.rug_height)), Vector3(data.settings.geometry.castle.banner_width, data.settings.geometry.castle.banner_height, g.rug_height), "banner")
		visuals.box(self, Vector3(x, data.settings.geometry.castle.banner_y, wall_face + float(g.rug_height) * math.double), Vector3(g.rug_height, data.settings.geometry.castle.banner_height, g.rug_height), "gold")


func _build_interior() -> void:
	var floor_rect: Dictionary
	var corridor_rect: Dictionary
	if location.kind == "home":
		floor_rect = data.home_template.visual_floor
		corridor_rect = data.home_template.corridor
	else:
		floor_rect = data.castle_visual.floor
		corridor_rect = data.castle_visual.corridor
	var floor_material: String = str(location.get("floor_material", "stone_light"))
	_room_shell(floor_rect, corridor_rect, "interior_wall", floor_material, location.kind == "home")
	if location.kind == "home":
		for item in location.furniture:
			visuals.furniture(self, item, location)
			if bool(item.get("blocking", true)):
				_block(item.rect)
		if location.has("service"):
			service = {"id": str(location.service), "name": str(location.title), "cell": data.economy.service_cell}
			visuals.counter(self, data.economy.counter_rect)
			_block(data.economy.counter_rect)
	else:
		_castle_decor()


func _build_dungeon() -> void:
	var d: Dictionary = data.settings.geometry.dungeon
	var floor_cells: Dictionary = {}
	for rect in floors:
		var info: Dictionary = visuals.rectangle(rect)
		visuals.box(self, info.center - Vector3.UP * float(d.floor_depth) * math.half, Vector3(info.width, d.floor_depth, info.depth), "shrine_floor")
		visuals.flagstones(self, rect, "shrine_floor_light", int(data.settings.random_seed) + int(info.center.x) * int(math.double) - int(info.center.z))
		var first: Vector2i = visuals.cell(rect.from)
		var last: Vector2i = visuals.cell(rect.to)
		for x in range(first.x, last.x + int(math.one)):
			for z in range(first.y, last.y + int(math.one)):
				floor_cells[Vector2i(x, z)] = true
	var open: Dictionary = floor_cells.duplicate()
	for stair in location.get("stairs", []):
		open[visuals.cell(stair.cell)] = true
		visuals.stairs(self, visuals.cell(stair.cell), visuals.cell(stair.toward), bool(stair.rising))
	var low_walls: Dictionary = {}
	var steps: Array = [-int(math.one), int(math.zero), int(math.one)]
	for point in open:
		for dx in steps:
			for dz in steps:
				var neighbor: Vector2i = point + Vector2i(dx, dz)
				if not open.has(neighbor):
					low_walls[neighbor] = open.has(neighbor + Vector2i.UP)
	var rows: Dictionary = {}
	for point in low_walls:
		if not rows.has(point.y):
			rows[point.y] = []
		rows[point.y].append(point.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.settings.random_seed) + location_id.length()
	for z in rows:
		var xs: Array = rows[z]
		xs.sort()
		var start: int = xs.front()
		for index in range(xs.size()):
			var x: int = xs[index]
			var last_in_run: bool = index + int(math.one) >= xs.size() or xs[index + int(math.one)] != x + int(math.one) or low_walls[Vector2i(xs[index + int(math.one)], z)] != low_walls[Vector2i(x, z)]
			if last_in_run:
				_wall_run(Vector2i(start, z), Vector2i(x, z), bool(low_walls[Vector2i(x, z)]), floor_cells, rng)
				if index + int(math.one) < xs.size():
					start = xs[index + int(math.one)]
	for point in location.get("torches", []):
		visuals.torch(self, visuals.cell(point))
	for entry in location.get("decor", []):
		if shown(entry):
			_decor(entry)
	for prop in location.get("props", []):
		var opened: bool = is_set(str(prop.flag))
		var prop_cell: Vector2i = visuals.cell(prop.cell)
		prop_nodes[str(prop.flag)] = visuals.chest(self, prop_cell, opened) if str(prop.type) == "chest" else visuals.dungeon_door(self, prop_cell, opened)
		props.append(prop)


func _wall_run(first: Vector2i, last: Vector2i, low: bool, floor_cells: Dictionary, rng: RandomNumberGenerator) -> void:
	var d: Dictionary = data.settings.geometry.dungeon
	var tile: float = float(data.settings.tile_size)
	visuals.dungeon_wall(self, first, last, float(d.low_wall_height) if low else float(d.wall_height))
	if low:
		return
	var face_z: float = (float(first.y) + math.half) * tile
	var face_start: int = first.x
	var facing: bool = false
	for x in range(first.x, last.x + int(math.double)):
		var faces_floor: bool = x <= last.x and floor_cells.has(Vector2i(x, first.y) + Vector2i.DOWN)
		if faces_floor and not facing:
			face_start = x
		elif facing and not faces_floor:
			visuals.wall_face(self, (float(face_start) - math.half) * tile, (float(x) - math.half) * tile, face_z, rng)
		facing = faces_floor


func _decor(entry: Dictionary) -> void:
	if not shown(entry):
		return
	if entry.has("rect"):
		match str(entry.type):
			"dais":
				visuals.dais(self, entry.rect)
			"hedge":
				visuals.hedge(self, entry.rect)
			"flowerbed":
				visuals.flowerbed(self, entry.rect)
			"stall":
				visuals.stall(self, entry)
		if bool(entry.get("blocking", true)):
			_block(entry.rect)
		return
	if str(entry.type) == "bunting":
		visuals.bunting(self, entry)
		return
	var point: Vector2i = visuals.cell(entry.cell)
	var spot: Vector3 = visuals.at(point, math.zero)
	match str(entry.type):
		"lamp":
			visuals.lamp_post(self, point)
		"barrel":
			visuals.barrel(self, spot)
		"crate":
			visuals.crate(self, spot)
		"sack":
			visuals.sack(self, spot)
		"well":
			visuals.well(self, point)
		"reeds":
			visuals.reeds(self, point)
		"tent":
			visuals.tent(self, point, str(entry.color))
		"signpost":
			visuals.signpost(self, point, str(entry.text))
		"planks":
			visuals.plank_stack(self, point)
		"tree":
			visuals.tree(self, point, entry.scale, entry.tone)
		"candelabra":
			visuals.candelabra(self, point)
		"plant":
			visuals.planter(self, point)
		"crest":
			visuals.crest(self, spot)
		"pillar":
			visuals.pillar(self, point, false)
		"pillar_broken":
			visuals.pillar(self, point, true)
		"statue":
			visuals.statue(self, point)
		"brazier":
			visuals.brazier(self, point)
		"bones":
			visuals.bones(self, point)
		"rubble":
			visuals.rubble_heap(self, point)
		"runes":
			visuals.runes(self, point)
		"prison":
			visuals.prison(self, point, float(data.settings.geometry.dungeon.dais_height))
		"exit_light":
			visuals.exit_light(self, point)
	if bool(entry.get("blocking", true)):
		_block({"from": entry.cell, "to": entry.cell})


func _build_npcs() -> void:
	npcs = location.get("npcs", []).filter(shown).duplicate(true)
	for npc in npcs:
		var root: Node3D = visuals.character(self, str(npc.get("model", npc.id)))
		root.name = "NPC_" + str(npc.id)
		root.position = visuals.at(visuals.cell(npc.cell), float(npc.get("elevation", math.zero)))
		if npc.has("facing"):
			root.rotation.y = atan2(float(npc.facing[int(math.zero)]), float(npc.facing[int(math.one)]))
		npc_nodes[npc.id] = root


func _build_strait() -> void:
	var s: Dictionary = data.strait
	var g: Dictionary = data.settings.geometry
	for rect in s.banks:
		_ground(rect)
	var water: Dictionary = visuals.rectangle(s.water)
	visuals.box(self, water.center - Vector3.UP * (float(g.riverbed_depth) + float(g.ground_depth) * math.half), Vector3(water.width, g.ground_depth, water.depth), "riverbed")
	visuals.plane(self, water.center + Vector3.UP * float(g.water_level), water.width, water.depth, "water")
	for glint in s.glints:
		visuals.plane(self, visuals.at(visuals.cell(glint.cell), float(g.water_level) + float(g.path_height)), glint.length, g.path_border_width, "water_glint")
	for rect in s.roads:
		_paving(rect)
	_curbs(s.roads)
	var deck: Dictionary = visuals.rectangle(s.bridge)
	var thickness: float = float(s.deck_thickness)
	for side in [math.zero - math.one, math.one]:
		var abutment: Vector3 = visuals.vector(s.abutment)
		visuals.box(self, Vector3(deck.center.x + side * (float(deck.width) + abutment.x) * math.half, -abutment.y * math.half, deck.center.z), abutment, "stone_dark")
	for point in s.posts:
		var post: Vector3 = visuals.at(visuals.cell(point), math.zero)
		var height: float = float(g.riverbed_depth) + thickness
		visuals.box(self, post - Vector3.UP * height * math.half, Vector3(s.post_width, height, s.post_width), "wood_dark")
	var count: int = int(s.planks)
	var plank_width: float = float(deck.width) / float(count)
	for index in range(count):
		var plank: MeshInstance3D = visuals.box(self, Vector3(float(deck.min_x) + plank_width * (float(index) + math.half), -thickness * math.half, deck.center.z), Vector3(plank_width - float(s.plank_gap), thickness, float(deck.depth) - float(s.side_inset) * math.double), "wood_light" if index % int(math.double) == int(math.zero) else "wood")
		plank.hide()
		planks.append(plank)
	for side in [math.zero - math.one, math.one]:
		var rail: Node3D = visuals.group(self, "Rail", Vector3(deck.center.x, math.zero, deck.center.z + side * (float(deck.depth) * math.half - float(s.side_inset))))
		visuals.box(rail, Vector3.UP * float(s.rail_height), Vector3(deck.width, s.rail_thickness, s.rail_thickness), "wood_light")
		visuals.box(rail, Vector3.UP * float(s.rail_height) * math.half, Vector3(deck.width, s.rail_thickness, s.rail_thickness), "wood")
		for index in range(int(s.rail_posts)):
			var x: float = -float(deck.width) * math.half + float(deck.width) * float(index) / float(int(s.rail_posts) - int(math.one))
			visuals.box(rail, Vector3(x, float(s.rail_height) * math.half, math.zero), Vector3(s.post_width, s.rail_height, s.post_width), "wood_dark")
		rail.hide()
		rails.append(rail)
	for definition in s.mountains:
		visuals.mountain(self, definition)
	for entry in location.get("decor", []):
		_decor(entry)
	for point in s.carriers:
		carriers.append(_worker(visuals.cell(point)))
	for point in s.builders:
		builders.append(_worker(visuals.cell(point)))
	front_x = float(deck.min_x)
	for rect in s.banks:
		visuals.scatter_grass(self, rect, func(point: Vector2i) -> bool: return not _on_road(point))


func _on_road(point: Vector2i) -> bool:
	for rect in data.strait.roads:
		if contains(rect, point):
			return true
	return false


func _worker(point: Vector2i) -> Node3D:
	var s: Dictionary = data.strait
	var model: Node3D = visuals.character(self, "worker")
	model.position = visuals.at(point, math.zero)
	model.rotation.y = PI * math.half
	var load: MeshInstance3D = visuals.box(model, Vector3.UP * float(s.load_height), visuals.vector(s.load), "wood_light")
	load.name = "Load"
	load.hide()
	return model


func _walk(model: Node3D, destination: Vector3) -> Tween:
	var offset: Vector3 = destination - model.position
	if offset.length() > float(math.zero):
		model.rotation.y = atan2(offset.x, offset.z)
	var tween: Tween = create_tween()
	tween.tween_property(model, "position", destination, offset.length() / float(data.strait.walk_speed))
	return tween


func _carry_loop(worker: Node3D, lane: float) -> void:
	var home: Vector3 = worker.position
	var load: Node3D = worker.get_node("Load")
	while building:
		load.show()
		await _walk(worker, Vector3(front_x - float(data.strait.drop_distance), math.zero, lane)).finished
		load.hide()
		await _walk(worker, home).finished
	worker.rotation.y = PI * math.half


func build_bridge() -> void:
	var s: Dictionary = data.strait
	building = true
	for index in range(carriers.size()):
		_carry_loop(carriers[index], float(s.lanes[index % s.lanes.size()]))
	var plank_width: float = float(visuals.rectangle(s.bridge).width) / float(planks.size())
	for index in range(planks.size()):
		var plank: MeshInstance3D = planks[index]
		plank.scale = Vector3(math.one, float(s.pop_start), math.one)
		plank.show()
		create_tween().tween_property(plank, "scale", Vector3.ONE, float(s.pop_time))
		front_x = plank.position.x + plank_width * math.half
		for builder_index in range(builders.size()):
			var builder: Node3D = builders[builder_index]
			var spot := Vector3(front_x - float(s.builder_gap), math.zero, float(s.lanes[builder_index % s.lanes.size()]))
			var tween: Tween = create_tween()
			tween.tween_property(builder, "position", spot + Vector3.UP * float(s.hammer_hop), float(s.pop_time))
			tween.tween_property(builder, "position", spot, float(s.pop_time))
		await get_tree().create_timer(float(s.plank_interval)).timeout
	building = false
	for rail in rails:
		rail.scale = Vector3(float(s.pop_start), math.one, math.one)
		rail.show()
		create_tween().tween_property(rail, "scale", Vector3.ONE, float(s.rail_time))
	await get_tree().create_timer(float(s.rail_time)).timeout
	for worker in carriers + builders:
		var tween: Tween = create_tween()
		for hop in range(int(s.cheer_hops)):
			tween.tween_property(worker, "position:y", float(s.cheer_height), float(s.pop_time))
			tween.tween_property(worker, "position:y", math.zero, float(s.pop_time))
	await get_tree().create_timer(float(s.pop_time) * float(s.cheer_hops) * math.double).timeout
