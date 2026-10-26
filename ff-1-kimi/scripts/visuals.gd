extends RefCounted

var data: Dictionary
var math: Dictionary
var geometry: Dictionary
var tile_size: float
var materials: Dictionary = {}


func _init(config: Dictionary) -> void:
	data = config
	math = data.settings.math
	geometry = data.settings.geometry
	tile_size = float(data.settings.tile_size)


func vector(value: Array) -> Vector3:
	return Vector3(float(value.front()), float(value[int(math.middle)]), float(value.back()))


func cell(value: Array) -> Vector2i:
	return Vector2i(int(value.front()), int(value.back()))


func at(value: Vector2i, elevation: float) -> Vector3:
	return Vector3(float(value.x) * tile_size, elevation, float(value.y) * tile_size)


func rectangle(rect: Dictionary) -> Dictionary:
	var first: Vector2i = cell(rect.from)
	var last: Vector2i = cell(rect.to)
	var width: float = float(last.x - first.x + int(math.one)) * tile_size
	var depth: float = float(last.y - first.y + int(math.one)) * tile_size
	var center: Vector3 = (at(first, math.zero) + at(last, math.zero)) * math.half
	return {
		"center": center,
		"width": width,
		"depth": depth,
		"min_x": center.x - width * math.half,
		"max_x": center.x + width * math.half,
		"min_z": center.z - depth * math.half,
		"max_z": center.z + depth * math.half
	}


func color(material_name: String) -> Color:
	return Color.html(str(data.palette[material_name]))


func material(material_name: String) -> StandardMaterial3D:
	if materials.has(material_name):
		return materials[material_name]
	var result := StandardMaterial3D.new()
	result.albedo_color = color(material_name)
	result.roughness = math.opacity
	if data.settings.materials.has(material_name):
		var options: Dictionary = data.settings.materials[material_name]
		result.metallic = float(options.get("metallic", math.zero))
		result.roughness = float(options.get("roughness", math.opacity))
		if bool(options.get("transparent", false)) or options.has("alpha"):
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.albedo_color.a = float(options.get("alpha", math.opacity))
		if bool(options.get("emission", false)):
			result.emission_enabled = true
			result.emission = result.albedo_color
			result.emission_energy_multiplier = float(options.emission_energy)
		if bool(options.get("double_sided", false)):
			result.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[material_name] = result
	return result


func mesh_node(parent: Node3D, mesh: Mesh, position_value: Vector3, material_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(material_name)
	instance.position = position_value
	parent.add_child(instance)
	return instance


func box(parent: Node3D, position_value: Vector3, dimensions: Vector3, material_name: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return mesh_node(parent, mesh, position_value, material_name)


func plane(parent: Node3D, position_value: Vector3, width: float, depth: float, material_name: String) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, depth)
	return mesh_node(parent, mesh, position_value, material_name)


func cylinder(parent: Node3D, position_value: Vector3, radius: float, height: float, material_name: String) -> MeshInstance3D:
	return tapered(parent, position_value, radius, height, material_name, math.one)


func tapered(parent: Node3D, position_value: Vector3, radius: float, height: float, material_name: String, top_ratio: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * top_ratio
	mesh.height = height
	mesh.radial_segments = int(geometry.radial_segments)
	return mesh_node(parent, mesh, position_value, material_name)


func sphere(parent: Node3D, position_value: Vector3, radius: float, height: float, material_name: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = int(geometry.radial_segments)
	mesh.rings = int(geometry.sphere_rings)
	return mesh_node(parent, mesh, position_value, material_name)


func prism(parent: Node3D, position_value: Vector3, dimensions: Vector3, material_name: String) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = dimensions
	mesh.left_to_right = float(geometry.prism_ridge)
	return mesh_node(parent, mesh, position_value, material_name)


func torus(parent: Node3D, position_value: Vector3, inner_radius: float, outer_radius: float, material_name: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = int(geometry.radial_segments)
	mesh.ring_segments = int(geometry.low_poly_segments)
	return mesh_node(parent, mesh, position_value, material_name)


func rod(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material_name: String) -> MeshInstance3D:
	var direction: Vector3 = finish - start
	var instance: MeshInstance3D = cylinder(parent, (start + finish) * math.half, radius, direction.length(), material_name)
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return instance


func group(parent: Node3D, group_name: String, position_value: Vector3) -> Node3D:
	var result := Node3D.new()
	result.name = group_name
	result.position = position_value
	parent.add_child(result)
	return result


func window(parent: Node3D, position_value: Vector3) -> void:
	var house: Dictionary = geometry.house
	var root: Node3D = group(parent, "Window", position_value)
	var depth: float = float(house.door_depth)
	var frame: float = float(house.window_frame)
	var width: float = float(house.window_width)
	var height: float = float(house.window_height)
	box(root, Vector3.ZERO, Vector3(width + frame * math.double, height + frame * math.double, depth), "wood_dark")
	box(root, Vector3(math.zero, math.zero, depth), Vector3(width, height, depth), "window")
	box(root, Vector3(math.zero, math.zero, depth * math.double), Vector3(frame, height, frame), "wood")
	box(root, Vector3(math.zero, math.zero, depth * math.double), Vector3(width, frame, frame), "wood")
	for side in [math.zero - math.one, math.one]:
		var x: float = side * (width + float(house.shutter_width) + frame) * math.half
		box(root, Vector3(x, math.zero, depth * math.half), Vector3(house.shutter_width, height, depth), "door_green")
		box(root, Vector3(x, math.zero, depth), Vector3(house.shutter_width, frame, depth), "wood_light")


func house(parent: Node3D, definition: Dictionary) -> void:
	var h: Dictionary = geometry.house
	var info: Dictionary = rectangle(definition.rect)
	var root: Node3D = group(parent, str(definition.id), info.center)
	var width: float = float(info.width)
	var depth: float = float(info.depth)
	var front: float = depth * math.half
	var foundation: float = float(h.foundation_height)
	var roof_base: float = foundation + float(h.wall_height)
	var door_x: float = float(cell(definition.door).x) * tile_size - float(info.center.x)
	box(root, Vector3(math.zero, foundation * math.half, math.zero), Vector3(width + h.beam_width, foundation, depth + h.beam_width), "stone_dark")
	box(root, Vector3(math.zero, foundation + float(h.wall_height) * math.half, math.zero), Vector3(width, h.wall_height, depth), str(definition.wall))
	box(root, Vector3(math.zero, foundation, front), Vector3(width, h.beam_width, h.beam_width), "wood")
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(side * (width * math.half - float(h.beam_width)), foundation + float(h.wall_height) * math.half, front), Vector3(h.beam_width, h.wall_height, h.beam_width), "wood")
	var roof_dimensions := Vector3(width + float(h.roof_overhang) * math.double, h.roof_height, depth + float(h.roof_overhang) * math.double)
	prism(root, Vector3(math.zero, roof_base + float(h.roof_height) * math.half, math.zero), roof_dimensions, str(definition.roof))
	rod(root, Vector3(math.zero, roof_base + float(h.roof_height), -roof_dimensions.z * math.half), Vector3(math.zero, roof_base + float(h.roof_height), roof_dimensions.z * math.half), h.ridge_radius, str(definition.roof))
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(math.zero, roof_base, side * roof_dimensions.z * math.half), Vector3(roof_dimensions.x, h.beam_width, h.beam_width), "wood")
	var door_z: float = front + float(h.door_depth)
	box(root, Vector3(door_x, foundation + float(h.door_height) * math.half, door_z), Vector3(h.door_width, h.door_height, h.door_depth), str(definition.door_material))
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(door_x + side * (float(h.door_width) + float(h.window_frame)) * math.half, foundation + float(h.door_height) * math.half, door_z + float(h.door_depth)), Vector3(h.window_frame, h.door_height, h.door_depth), "wood_light")
	box(root, Vector3(door_x, foundation + float(h.door_height), door_z + float(h.door_depth)), Vector3(float(h.door_width) + float(h.window_frame), h.window_frame, h.door_depth), "wood_light")
	box(root, Vector3(door_x + float(h.door_width) * math.quarter, foundation + float(h.door_height) * math.half, door_z + float(h.door_depth)), Vector3(h.window_frame, h.window_frame, h.window_frame), "gold")
	box(root, Vector3(door_x, float(h.step_height) * math.half, front + float(h.step_depth) * math.half), Vector3(float(h.door_width) + float(h.window_frame) * math.double, h.step_height, h.step_depth), "stone_light")
	for side in [math.zero - math.one, math.one]:
		window(root, Vector3(side * width * float(h.window_offset), float(h.window_y) + foundation, front + float(h.door_depth)))
	var side_window: Node3D = group(root, "SideWindow", Vector3(width * math.half, float(h.window_y) + foundation, math.zero))
	side_window.rotation.y = deg_to_rad(float(math.right_angle))
	window(side_window, Vector3.ZERO)
	box(root, Vector3(door_x, h.sign_y, door_z), Vector3(h.sign_width, h.sign_height, h.door_depth), "wood_dark")
	var sign := Label3D.new()
	sign.text = str(definition.name)
	sign.font_size = int(h.sign_font_size)
	sign.pixel_size = float(h.sign_pixel_size)
	sign.outline_size = int(h.sign_outline_size)
	sign.modulate = color("linen")
	sign.outline_modulate = color("wood_dark")
	sign.position = Vector3(door_x, h.sign_y, door_z + float(h.door_depth))
	root.add_child(sign)
	var chimney := Vector3(width * float(h.chimney_offset), roof_base + float(h.roof_height) * math.half + float(h.chimney_height) * math.half, -depth * math.quarter)
	box(root, chimney, Vector3(h.chimney_width, h.chimney_height, h.chimney_depth), "stone_dark")
	box(root, chimney + Vector3(math.zero, float(h.chimney_height) * math.half, math.zero), Vector3(float(h.chimney_width) + float(h.beam_width), h.beam_width, float(h.chimney_depth) + float(h.beam_width)), "stone")


func battlements(parent: Node3D, start: Vector3, finish: Vector3, elevation: float) -> void:
	var c: Dictionary = geometry.castle
	var length: float = start.distance_to(finish)
	var count: int = maxi(int(math.one), ceili(length / float(c.battlement_spacing)))
	for index in range(count + int(math.one)):
		var position_value: Vector3 = start.lerp(finish, float(index) / float(count))
		position_value.y = elevation + float(c.battlement_height) * math.half
		var instance: MeshInstance3D = box(parent, position_value, Vector3(c.battlement_width, c.battlement_height, c.battlement_depth), "stone_light")
		if is_zero_approx(finish.x - start.x):
			instance.rotation.y = deg_to_rad(float(math.right_angle))


func castle(parent: Node3D, rect: Dictionary, door_cell: Array) -> void:
	var c: Dictionary = geometry.castle
	var info: Dictionary = rectangle(rect)
	var root: Node3D = group(parent, "CorneliaCastle", info.center)
	var width: float = float(info.width)
	var depth: float = float(info.depth)
	var front: float = depth * math.half
	var wall_top: float = float(c.foundation_height) + float(c.wall_height)
	var gate_x: float = float(cell(door_cell).x) * tile_size - float(info.center.x)
	box(root, Vector3(math.zero, float(c.foundation_height) * math.half, math.zero), Vector3(width, c.foundation_height, depth), "stone_dark")
	box(root, Vector3(math.zero, float(c.foundation_height) + float(c.wall_height) * math.half, math.zero), Vector3(width, c.wall_height, depth), "stone")
	box(root, Vector3(math.zero, wall_top, front), Vector3(width, c.tower_trim_height, c.battlement_depth), "stone_light")
	var left: float = -width * math.half + float(c.tower_radius)
	var right: float = width * math.half - float(c.tower_radius)
	var back: float = -depth * math.half + float(c.tower_radius)
	var near: float = depth * math.half - float(c.tower_radius)
	battlements(root, Vector3(left, math.zero, front), Vector3(right, math.zero, front), wall_top)
	battlements(root, Vector3(left, math.zero, -front), Vector3(right, math.zero, -front), wall_top)
	battlements(root, Vector3(-width * math.half, math.zero, back), Vector3(-width * math.half, math.zero, near), wall_top)
	battlements(root, Vector3(width * math.half, math.zero, back), Vector3(width * math.half, math.zero, near), wall_top)
	var keep_position := Vector3(math.zero, wall_top + float(c.upper_keep_height) * math.half, -depth * math.quarter)
	box(root, keep_position, Vector3(c.upper_keep_width, c.upper_keep_height, c.upper_keep_depth), "stone_light")
	battlements(root, keep_position + Vector3(-float(c.upper_keep_width) * math.half, float(c.upper_keep_height) * math.half, float(c.upper_keep_depth) * math.half), keep_position + Vector3(float(c.upper_keep_width) * math.half, float(c.upper_keep_height) * math.half, float(c.upper_keep_depth) * math.half), wall_top + float(c.upper_keep_height))
	for x in [left, right]:
		for z in [back, near]:
			var tower: Node3D = group(root, "Tower", Vector3(x, math.zero, z))
			cylinder(tower, Vector3(math.zero, float(c.tower_height) * math.half, math.zero), c.tower_radius, c.tower_height, "stone")
			cylinder(tower, Vector3(math.zero, float(c.tower_trim_height), math.zero), float(c.tower_radius) + float(c.tower_trim_height), float(c.tower_trim_height) * math.double, "stone_dark")
			cylinder(tower, Vector3(math.zero, c.tower_height, math.zero), float(c.tower_radius) + float(c.tower_trim_height), c.tower_trim_height, "stone_light")
			tapered(tower, Vector3(math.zero, float(c.tower_height) + float(c.tower_roof_height) * math.half, math.zero), c.tower_roof_radius, c.tower_roof_height, "slate", math.zero)
			var flag_base: float = float(c.tower_height) + float(c.tower_roof_height)
			cylinder(tower, Vector3(math.zero, flag_base + float(c.flagpole_height) * math.half, math.zero), c.flagpole_radius, c.flagpole_height, "gold")
			box(tower, Vector3(float(c.flag_width) * math.half, flag_base + float(c.flagpole_height) * math.quarter * (math.one + math.double), math.zero), Vector3(c.flag_width, c.flag_height, c.flagpole_radius), "flag")
			box(tower, Vector3(math.zero, float(c.tower_height) * math.half, float(c.tower_radius)), Vector3(c.battlement_width, c.banner_height, c.flagpole_radius), "window_dark")
	box(root, Vector3(gate_x, float(c.gate_height) * math.half, front + float(c.tower_trim_height)), Vector3(c.gate_width, c.gate_height, c.tower_trim_height), "wood_dark")
	for side in [math.zero - math.one, math.one]:
		var pillar_x: float = gate_x + side * (float(c.gate_width) + float(c.gate_pillar_width)) * math.half
		box(root, Vector3(pillar_x, float(c.gate_height) * math.half, front + float(c.gate_pillar_width) * math.half), Vector3(c.gate_pillar_width, c.gate_height, c.gate_pillar_width), "stone_light")
		var door: MeshInstance3D = box(root, Vector3(gate_x + side * float(c.gate_width) * math.half, float(c.gate_height) * math.half, front + float(c.gate_pillar_width)), Vector3(c.door_leaf_width, c.gate_height, c.tower_trim_height), "wood")
		door.rotation.y = side * float(c.door_open_angle)
		box(root, Vector3(gate_x + side * float(c.gate_width) * math.double, c.banner_y, front + float(c.tower_trim_height)), Vector3(c.banner_width, c.banner_height, c.flagpole_radius), "banner")
		box(root, Vector3(gate_x + side * float(c.gate_width) * math.double, c.banner_y, front + float(c.tower_trim_height) * math.double), Vector3(c.flagpole_radius, c.banner_height, c.flagpole_radius), "gold")
	box(root, Vector3(gate_x, c.gate_height, front + float(c.gate_pillar_width) * math.half), Vector3(float(c.gate_width) + float(c.gate_pillar_width) * math.double, c.gate_lintel_height, c.gate_pillar_width), "stone_light")
	box(root, Vector3(gate_x, float(c.gate_height) + float(c.gate_lintel_height), front + float(c.gate_pillar_width)), Vector3(c.banner_width, c.battlement_width, c.tower_trim_height), "royal")


func wall_between(parent: Node3D, first: Vector2i, last: Vector2i, height: float, material_name: String) -> void:
	var start: Vector3 = at(first, math.zero)
	var finish: Vector3 = at(last, math.zero)
	var length: float = start.distance_to(finish)
	var midpoint: Vector3 = (start + finish) * math.half
	midpoint.y = height * math.half
	var root: Node3D = group(parent, "Wall", midpoint)
	root.rotation.y = -atan2(finish.z - start.z, finish.x - start.x)
	box(root, Vector3.ZERO, Vector3(length, height, geometry.wall_thickness), material_name)
	box(root, Vector3(math.zero, height * math.half, math.zero), Vector3(length, geometry.town_wall_cap_height, float(geometry.wall_thickness) + float(geometry.town_wall_cap_height)), "stone_light")
	var count: int = maxi(int(math.one), ceili(length / float(geometry.town_wall_post_spacing)))
	for index in range(count + int(math.one)):
		var x: float = -length * math.half + length * float(index) / float(count)
		box(root, Vector3(x, math.zero, math.zero), Vector3(geometry.town_wall_post_width, height + float(geometry.town_wall_cap_height), float(geometry.wall_thickness) + float(geometry.town_wall_cap_height)), "stone")


func north_gate(parent: Node3D, gate_cell: Vector2i) -> void:
	var g: Dictionary = geometry.north_gate
	var root: Node3D = group(parent, "NorthGate", at(gate_cell, math.zero))
	for side in [math.zero - math.one, math.one]:
		var x: float = side * float(g.width) * math.half
		box(root, Vector3(x, float(g.height) * math.half, math.zero), Vector3(g.pillar_width, g.height, g.pillar_depth), "stone")
		box(root, Vector3(x, g.height, math.zero), Vector3(float(g.pillar_width) + float(g.roof_overhang), g.roof_overhang, float(g.pillar_depth) + float(g.roof_overhang)), "stone_light")
	box(root, Vector3(math.zero, float(g.height) - float(g.pillar_width) * math.half, math.zero), Vector3(g.width, g.pillar_width, g.pillar_depth), "stone")
	var roof: MeshInstance3D = prism(root, Vector3(math.zero, float(g.height) + float(g.roof_height) * math.half, math.zero), Vector3(float(g.pillar_depth) + float(g.roof_overhang) * math.double, g.roof_height, float(g.width) + float(g.pillar_width) + float(g.roof_overhang) * math.double), "slate")
	roof.rotation.y = deg_to_rad(float(math.right_angle))
	box(root, Vector3(math.zero, float(g.height) - float(g.crest_height), float(g.pillar_depth) * math.half), Vector3(g.crest_width, g.crest_height, g.roof_overhang), "royal")
	box(root, Vector3(math.zero, float(g.height) - float(g.crest_height), float(g.pillar_depth) * math.half + float(g.roof_overhang)), Vector3(g.roof_overhang, g.crest_height, g.roof_overhang), "gold")


func bridge(parent: Node3D, rect: Dictionary) -> void:
	var b: Dictionary = geometry.bridge
	var info: Dictionary = rectangle(rect)
	var root: Node3D = group(parent, "NorthBridge", info.center)
	var width: float = float(info.width)
	var depth: float = float(info.depth)
	var count: int = int(b.plank_count)
	var plank_depth: float = depth / float(count)
	for index in range(count):
		var z: float = -depth * math.half + (float(index) + math.half) * plank_depth
		var material_name: String = "wood_light" if index % int(math.double) == int(math.zero) else "wood"
		box(root, Vector3(math.zero, -float(b.deck_thickness) * math.half, z), Vector3(width - float(b.side_inset) * math.double, b.deck_thickness, plank_depth - float(b.plank_gap)), material_name)
	for side in [math.zero - math.one, math.one]:
		var x: float = side * (width * math.half - float(b.side_inset))
		box(root, Vector3(x, b.rail_height, math.zero), Vector3(b.rail_thickness, b.rail_thickness, depth), "wood_light")
		box(root, Vector3(x, float(b.rail_height) * math.half, math.zero), Vector3(b.rail_thickness, b.rail_thickness, depth), "wood")
		for index in range(int(b.post_count)):
			var z: float = -depth * math.half + depth * float(index) / float(int(b.post_count) - int(math.one))
			box(root, Vector3(x, float(b.rail_height) * math.half, z), Vector3(b.post_width, b.rail_height, b.post_width), "wood_dark")
		for fraction in [math.zero, math.half, math.one]:
			var z: float = -depth * math.half + depth * fraction
			box(root, Vector3(x, -float(b.support_height) * math.half, z), Vector3(b.support_width, b.support_height, b.support_width), "wood_dark")
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(math.zero, -float(b.abutment_height) * math.half, side * depth * math.half), Vector3(width, b.abutment_height, b.abutment_depth), "stone_dark")


func tree(parent: Node3D, position_cell: Vector2i, scale_value: float, tone: String) -> void:
	var t: Dictionary = geometry
	var root: Node3D = group(parent, "Tree", at(position_cell, math.zero))
	root.scale = Vector3.ONE * scale_value
	cylinder(root, Vector3(math.zero, float(t.tree_trunk_height) * math.half, math.zero), t.tree_trunk_radius, t.tree_trunk_height, "bark")
	sphere(root, Vector3(math.zero, t.tree_crown_y, math.zero), t.tree_crown_radius, t.tree_crown_height, tone)
	sphere(root, Vector3(t.tree_crown_offset, float(t.tree_crown_y) - float(t.tree_crown_offset), math.zero), float(t.tree_crown_radius) * math.half + float(t.tree_crown_offset) * math.quarter, t.tree_crown_height, tone)
	sphere(root, Vector3(-float(t.tree_crown_offset), float(t.tree_crown_y) - float(t.tree_crown_offset), float(t.tree_crown_offset)), t.tree_crown_radius, t.tree_crown_height, "leaf_light" if tone == "leaf" else tone)


func bench(parent: Node3D, rect: Dictionary) -> void:
	var b: Dictionary = geometry.bench
	var info: Dictionary = rectangle(rect)
	var root: Node3D = group(parent, "Bench", info.center)
	box(root, Vector3(math.zero, b.seat_y, math.zero), Vector3(b.seat_width, b.seat_height, b.seat_depth), "wood_light")
	box(root, Vector3(math.zero, float(b.seat_y) + float(b.back_height) * math.half, -float(b.seat_depth) * math.half), Vector3(b.seat_width, b.back_height, b.seat_height), "wood")
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(side * float(b.seat_width) * math.quarter, float(b.leg_height) * math.half, math.zero), Vector3(b.leg_width, b.leg_height, b.seat_depth), "iron")


func planter(parent: Node3D, position_cell: Vector2i) -> void:
	var p: Dictionary = geometry.planter
	var root: Node3D = group(parent, "Planter", at(position_cell, math.zero))
	cylinder(root, Vector3(math.zero, float(p.height) * math.half, math.zero), p.radius, p.height, "stone_light")
	sphere(root, Vector3(math.zero, p.height, math.zero), p.leaf_radius, p.leaf_height, "leaf")
	for side in [math.zero - math.one, math.one]:
		sphere(root, Vector3(side * float(p.radius) * math.half, float(p.height) + float(p.leaf_height) * math.half, math.zero), geometry.flower_radius, geometry.flower_radius, "flower_pink")


func fountain(parent: Node3D, position_cell: Vector2i) -> void:
	var f: Dictionary = geometry.fountain
	var root: Node3D = group(parent, "Fountain", at(position_cell, math.zero))
	cylinder(root, Vector3(math.zero, float(f.base_height) * math.half, math.zero), f.base_radius, f.base_height, "stone_dark")
	cylinder(root, Vector3(math.zero, float(f.base_height) + float(f.basin_height) * math.half, math.zero), f.basin_radius, f.basin_height, "stone")
	cylinder(root, Vector3(math.zero, float(f.base_height) + float(f.basin_height), math.zero), f.water_radius, geometry.path_height, "fountain_water")
	torus(root, Vector3(math.zero, float(f.base_height) + float(f.basin_height), math.zero), f.rim_inner_radius, f.rim_outer_radius, "stone_light")
	cylinder(root, Vector3(math.zero, float(f.base_height) + float(f.pillar_height) * math.half, math.zero), f.pillar_radius, f.pillar_height, "stone_light")
	cylinder(root, Vector3(math.zero, f.bowl_y, math.zero), f.bowl_radius, f.bowl_height, "stone_light")
	cylinder(root, Vector3(math.zero, float(f.bowl_y) + float(f.bowl_height) * math.half, math.zero), f.bowl_radius, geometry.path_height, "fountain_water")
	sphere(root, Vector3(math.zero, float(f.bowl_y) + float(f.pillar_radius), math.zero), f.finial_radius, float(f.finial_radius) * math.double, "gold")
	for x in [math.zero - math.one, math.one]:
		for z in [math.zero - math.one, math.one]:
			cylinder(root, Vector3(x * float(f.jet_offset), f.jet_y, z * float(f.jet_offset)), f.jet_radius, f.jet_height, "fountain_water")


func rock(parent: Node3D, position_cell: Vector2i) -> void:
	var instance: MeshInstance3D = sphere(parent, at(position_cell, float(geometry.rock_radius) * math.half), geometry.rock_radius, geometry.rock_radius, "stone_dark")
	instance.rotation.y = float(position_cell.x) * float(math.quarter)


func character(parent: Node3D, kind: String) -> Node3D:
	var c: Dictionary = geometry.character
	var root: Node3D = group(parent, kind.capitalize(), Vector3.ZERO)
	var primary: String = kind
	var secondary: String = kind
	var hair: String = "hair_gold"
	var skin: String = "skin"
	match kind:
		"warrior":
			secondary = "warrior_dark"
		"thief":
			secondary = "thief_dark"
			hair = "hair_brown"
		"monk":
			secondary = "monk_dark"
			hair = "hair_dark"
		"white_mage":
			primary = "mage"
			secondary = "mage_trim"
		"guard":
			primary = "silver"
			secondary = "banner"
			hair = "hair_dark"
		"king":
			primary = "royal"
			secondary = "gold"
			hair = "hair_brown"
		"villager":
			primary = "villager"
			secondary = "villager_apron"
			hair = "hair_brown"
		"goblin":
			secondary = "goblin_dark"
			hair = "hair_dark"
		"dark_mage":
			secondary = "dark_mage_trim"
			hair = "hair_dark"
		"skeleton":
			primary = "bone"
			secondary = "bone_dark"
			hair = "bone"
			skin = "bone"
		"garland":
			primary = "garland_armor"
			secondary = "garland_cape"
			hair = "garland_armor"
		"sara":
			primary = "sara_dress"
			secondary = "sara_trim"
		"worker", "smith", "healer", "merchant", "dancer", "elder", "child":
			primary = kind
			secondary = kind + "_trim"
			hair = str(geometry.character.hair[kind])
	var shadow: MeshInstance3D = cylinder(root, Vector3(math.zero, c.shadow_y, math.zero), c.shadow_radius, c.shadow_height, "shadow")
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(side * float(c.boot_spacing), c.boot_y, math.zero), Vector3(c.boot_width, c.boot_height, c.boot_depth), "wood_dark")
		box(root, Vector3(side * float(c.boot_spacing), c.leg_y, math.zero), Vector3(c.leg_width, c.leg_height, c.leg_width), secondary)
	var robe: bool = kind in ["white_mage", "king", "villager", "dark_mage", "sara", "healer", "merchant", "dancer", "elder"]
	tapered(root, Vector3(math.zero, c.body_y, math.zero), float(c.body_radius) * (float(c.robe_bottom_ratio) if robe else math.one), c.body_height, primary, c.body_top_ratio)
	box(root, Vector3(math.zero, c.belt_y, math.zero), Vector3(c.belt_width, c.belt_height, c.belt_depth), secondary)
	for side in [math.zero - math.one, math.one]:
		cylinder(root, Vector3(side * float(c.arm_spacing), c.arm_y, math.zero), c.arm_radius, c.arm_height, primary)
		sphere(root, Vector3(side * float(c.arm_spacing), c.hand_y, math.zero), c.hand_radius, float(c.hand_radius) * math.double, skin)
	if kind in ["warrior", "thief", "king", "garland"]:
		box(root, Vector3(math.zero, c.cape_y, c.cape_z), Vector3(c.cape_width, c.cape_height, c.cape_depth), secondary)
	if kind == "white_mage":
		sphere(root, Vector3(math.zero, c.head_y, math.zero), c.hood_radius, c.hood_height, "mage")
		sphere(root, Vector3(math.zero, c.head_y, c.hood_face_z), c.hood_face_radius, float(c.hood_face_radius) * math.double, "skin")
		tapered(root, Vector3(math.zero, float(c.head_y) + float(c.hood_height) * math.half, math.zero), c.head_radius, c.hat_height, "mage", math.zero)
	else:
		sphere(root, Vector3(math.zero, c.head_y, math.zero), c.head_radius, c.head_height, skin)
		sphere(root, Vector3(math.zero, c.hair_y, math.zero), c.hair_radius, c.hair_height, hair)
	var face_z: float = float(c.hood_face_z) + float(c.hood_face_radius) if kind == "white_mage" else float(c.eye_z)
	for side in [math.zero - math.one, math.one]:
		sphere(root, Vector3(side * float(c.eye_spacing), c.eye_y, face_z), c.eye_radius, float(c.eye_radius) * math.double, "void" if kind == "skeleton" else "eyes")
	sphere(root, Vector3(math.zero, float(c.eye_y) - float(c.eye_radius), face_z), c.nose_radius, c.nose_radius, skin)
	match kind:
		"warrior", "guard":
			for side in [math.zero - math.one, math.one]:
				sphere(root, Vector3(side * float(c.arm_spacing), c.shoulder_y, math.zero), c.shoulder_radius, float(c.shoulder_radius) * math.double, "silver")
			box(root, Vector3(math.zero, c.body_y, c.body_radius), Vector3(c.belt_width, c.arm_height, c.cape_depth), "silver")
			box(root, Vector3(c.sword_x, c.sword_y, math.zero), Vector3(c.sword_width, c.sword_height, c.sword_depth), "silver")
			box(root, Vector3(c.sword_x, float(c.sword_y) - float(c.sword_height) * math.half, math.zero), Vector3(c.sword_guard_width, c.belt_height, c.sword_depth), "gold")
			if kind == "guard":
				sphere(root, Vector3(math.zero, c.hair_y, math.zero), c.hat_radius, c.hair_height, "silver")
				box(root, Vector3(math.zero, float(c.hair_y) + float(c.hat_height), math.zero), Vector3(c.eye_radius, c.hat_height, c.hat_radius), "banner")
		"thief":
			tapered(root, Vector3(math.zero, c.hat_y, math.zero), c.hat_radius, c.hat_height, "thief", c.body_top_ratio)
			box(root, Vector3(math.zero, c.eye_y, face_z), Vector3(c.belt_width, c.belt_height, c.cape_depth), "thief_dark")
			rod(root, Vector3(c.hat_radius, c.hat_y, math.zero), Vector3(c.hat_radius, float(c.hat_y) + float(c.hat_height) * math.double, math.zero), c.eye_radius, "linen")
		"monk":
			box(root, Vector3(math.zero, c.body_y, c.body_radius), Vector3(c.belt_height, c.body_height, c.cape_depth), "linen")
			for side in [math.zero - math.one, math.one]:
				cylinder(root, Vector3(side * float(c.arm_spacing), c.hand_y, math.zero), c.hand_radius, c.belt_height, "linen")
		"white_mage":
			cylinder(root, Vector3(c.staff_x, c.staff_y, math.zero), c.staff_radius, c.staff_height, "wood_light")
			sphere(root, Vector3(c.staff_x, float(c.staff_y) + float(c.staff_height) * math.half, math.zero), c.staff_orb_radius, float(c.staff_orb_radius) * math.double, "gold")
			box(root, Vector3(math.zero, c.belt_y, c.body_radius), Vector3(c.belt_width, c.belt_height, c.cape_depth), "mage_trim")
		"king":
			cylinder(root, Vector3(math.zero, c.crown_y, math.zero), c.crown_radius, c.crown_height, "gold")
			for index in range(int(c.crown_point_count)):
				var angle: float = float(index) / float(c.crown_point_count) * deg_to_rad(float(math.full_turn))
				tapered(root, Vector3(cos(angle) * float(c.crown_radius), float(c.crown_y) + float(c.crown_height), sin(angle) * float(c.crown_radius)), c.crown_point_radius, c.crown_point_height, "gold", math.zero)
		"villager":
			cylinder(root, Vector3(math.zero, c.hat_y, math.zero), c.hat_radius, c.belt_height, "path_light")
			tapered(root, Vector3(math.zero, float(c.hat_y) + float(c.hat_height) * math.half, math.zero), c.head_radius, c.hat_height, "path_light", c.body_top_ratio)
			box(root, Vector3(math.zero, c.body_y, c.body_radius), Vector3(c.belt_width, c.body_height, c.cape_depth), "villager_apron")
		"skeleton":
			for index in range(int(c.rib_count)):
				box(root, Vector3(math.zero, float(c.rib_y) + float(index) * float(c.rib_spacing), c.body_radius), Vector3(c.rib_width, c.rib_height, c.cape_depth), "bone_dark")
			box(root, Vector3(c.sword_x, c.sword_y, math.zero), Vector3(c.sword_width, c.sword_height, c.sword_depth), "iron")
		"garland":
			sphere(root, Vector3(math.zero, c.head_y, math.zero), c.helmet_radius, c.helmet_height, "garland_armor")
			box(root, Vector3(math.zero, c.eye_y, float(c.helmet_radius) - float(c.cape_depth) * math.quarter), Vector3(c.visor_width, c.visor_height, c.cape_depth), "void")
			for side in [math.zero - math.one, math.one]:
				var horn: MeshInstance3D = tapered(root, Vector3(side * float(c.horn_spread), c.horn_y, math.zero), c.horn_radius, c.horn_height, "garland_trim", math.zero)
				horn.rotation.z = -side * float(c.horn_tilt)
				sphere(root, Vector3(side * float(c.arm_spacing), c.shoulder_y, math.zero), c.pauldron_radius, float(c.pauldron_radius) * math.double, "garland_trim")
			box(root, Vector3(math.zero, c.body_y, c.body_radius), Vector3(c.belt_width, c.arm_height, c.cape_depth), "garland_trim")
			var blade_y: float = float(c.sword_y) + (float(c.greatsword_height) - float(c.sword_height)) * math.half
			box(root, Vector3(c.sword_x, blade_y, math.zero), Vector3(c.greatsword_width, c.greatsword_height, c.sword_depth), "silver")
			box(root, Vector3(c.sword_x, blade_y - float(c.greatsword_height) * math.half, math.zero), Vector3(c.sword_guard_width, c.belt_height, c.sword_depth), "gold")
		"worker":
			cylinder(root, Vector3(math.zero, c.hat_y, math.zero), c.hat_radius, c.belt_height, "gold")
			sphere(root, Vector3(math.zero, c.hair_y, math.zero), c.hair_radius, c.hair_height, "gold")
			box(root, Vector3(math.zero, c.body_y, c.body_radius), Vector3(c.belt_width, c.body_height, c.cape_depth), "worker_trim")
		"smith":
			box(root, Vector3(math.zero, c.body_y, c.body_radius), Vector3(c.belt_width, float(c.body_height) * float(c.robe_bottom_ratio), c.cape_depth), "smith_trim")
			box(root, Vector3(c.sword_x, c.sword_y, math.zero), Vector3(c.sword_guard_width, c.belt_height, c.sword_depth), "iron")
		"healer", "elder":
			box(root, Vector3(math.zero, float(c.eye_y) - float(c.hood_face_radius), c.eye_z), Vector3(c.visor_width, c.hood_face_radius, c.cape_depth), "hair_white" if kind == "elder" else "healer_trim")
			cylinder(root, Vector3(c.staff_x, c.staff_y, math.zero), c.staff_radius, c.staff_height, "wood_light")
		"merchant":
			cylinder(root, Vector3(math.zero, c.hat_y, math.zero), c.hat_radius, c.belt_height, "merchant_trim")
			tapered(root, Vector3(math.zero, float(c.hat_y) + float(c.hat_height) * math.half, math.zero), c.head_radius, c.hat_height, "merchant", c.body_top_ratio)
		"dancer":
			sphere(root, Vector3(math.zero, float(c.hair_y) + float(c.hair_height) * math.half, -float(c.hair_radius) * math.half), c.tiara_gem_radius * math.double, float(c.tiara_gem_radius) * float(math.double + math.double), "hair_brown")
			box(root, Vector3(math.zero, c.belt_y, c.body_radius), Vector3(c.belt_width, c.belt_height, c.cape_depth), "gold")
		"sara":
			box(root, Vector3(math.zero, c.long_hair_y, c.long_hair_z), Vector3(c.long_hair_width, c.long_hair_height, c.long_hair_depth), "hair_gold")
			torus(root, Vector3(math.zero, c.tiara_y, math.zero), float(c.tiara_radius) - float(c.tiara_height), c.tiara_radius, "gold")
			sphere(root, Vector3(math.zero, float(c.tiara_y) + float(c.tiara_height), c.tiara_radius), c.tiara_gem_radius, float(c.tiara_gem_radius) * math.double, "flower_pink")
			box(root, Vector3(math.zero, c.belt_y, c.body_radius), Vector3(c.belt_width, c.belt_height, c.cape_depth), "sara_trim")
	if kind == "guard":
		cylinder(root, Vector3(c.staff_x, c.staff_y, math.zero), c.staff_radius, float(c.staff_height) * float(c.robe_bottom_ratio), "wood")
		tapered(root, Vector3(c.staff_x, float(c.staff_y) + float(c.staff_height), math.zero), c.staff_orb_radius, c.crown_height, "silver", math.zero)
	if kind in ["guard", "villager"]:
		root.scale = Vector3.ONE * float(c.npc_scale)
	elif kind == "king":
		root.scale = Vector3.ONE * float(c.king_scale)
	elif kind == "garland":
		root.scale = Vector3.ONE * float(c.garland_scale)
	elif kind == "sara":
		root.scale = Vector3.ONE * float(c.sara_scale)
	elif c.scales.has(kind):
		root.scale = Vector3.ONE * float(c.scales[kind])
	return root


func candle(parent: Node3D, position_value: Vector3) -> void:
	var i: Dictionary = geometry.interior
	cylinder(parent, position_value + Vector3(math.zero, float(i.candle_height) * math.half, math.zero), i.candle_radius, i.candle_height, "candle")
	sphere(parent, position_value + Vector3(math.zero, i.candle_height, math.zero), i.flame_radius, float(i.flame_radius) * math.double, "flame")


func furniture(parent: Node3D, definition: Dictionary, location: Dictionary) -> void:
	var i: Dictionary = geometry.interior
	var info: Dictionary = rectangle(definition.rect)
	var root: Node3D = group(parent, str(definition.type).capitalize(), info.center)
	var width: float = float(info.width) * math.half + float(i.table_leg_width)
	var depth: float = float(info.depth) * math.half + float(i.table_leg_width)
	match str(definition.type):
		"table":
			box(root, Vector3(math.zero, i.table_height, math.zero), Vector3(width, i.table_top_thickness, depth), "wood_light")
			for x in [math.zero - math.one, math.one]:
				for z in [math.zero - math.one, math.one]:
					box(root, Vector3(x * width * math.quarter, float(i.table_height) * math.half, z * depth * math.quarter), Vector3(i.table_leg_width, i.table_height, i.table_leg_width), "wood")
			candle(root, Vector3(math.zero, float(i.table_height) + float(i.table_top_thickness), math.zero))
		"bed":
			box(root, Vector3(math.zero, float(i.bed_height) * math.half, math.zero), Vector3(width, i.bed_height, depth), "wood")
			box(root, Vector3(math.zero, i.bed_height, math.zero), Vector3(width, i.mattress_height, depth), str(location.blanket))
			box(root, Vector3(math.zero, float(i.bed_height) + float(i.mattress_height), -depth * math.quarter), Vector3(width, i.pillow_height, float(depth) * math.half), "linen")
			box(root, Vector3(math.zero, i.bed_height, -depth * math.half), Vector3(width, i.table_height, i.table_top_thickness), "wood_light")
		"shelf":
			box(root, Vector3(math.zero, float(i.shelf_height) * math.half, math.zero), Vector3(width, i.shelf_height, i.shelf_depth), "wood_dark")
			for level in range(int(i.shelf_levels)):
				var y: float = float(i.shelf_height) * float(level) / float(int(i.shelf_levels) - int(math.one))
				box(root, Vector3(math.zero, y, float(i.shelf_depth) * math.half), Vector3(width, i.shelf_board_height, i.shelf_depth), "wood_light")
				if level < int(i.shelf_levels) - int(math.one):
					for book in range(int(i.book_count)):
						var x: float = (float(book) / float(int(i.book_count) - int(math.one)) - math.half) * width
						box(root, Vector3(x, y + float(i.book_height) * math.half, float(i.shelf_depth)), Vector3(i.book_width, i.book_height, i.book_depth), "royal" if book % int(math.double) == int(math.zero) else "banner")
		"plant":
			planter(root, Vector2i.ZERO)
		"rug":
			box(root, Vector3(math.zero, i.rug_height, math.zero), Vector3(info.width, i.rug_height, info.depth), str(location.rug_material))


func counter(parent: Node3D, rect: Dictionary) -> void:
	var i: Dictionary = geometry.interior
	var info: Dictionary = rectangle(rect)
	var root: Node3D = group(parent, "ServiceCounter", info.center)
	box(root, Vector3(math.zero, float(i.table_height) * math.half, math.zero), Vector3(info.width, i.table_height, info.depth), "wood")
	box(root, Vector3(math.zero, i.table_height, math.zero), Vector3(float(info.width) + float(i.table_top_thickness), i.table_top_thickness, float(info.depth) + float(i.table_top_thickness)), "wood_light")
	box(root, Vector3(math.zero, float(i.table_height) * math.half, float(info.depth) * math.half), Vector3(info.width, i.table_top_thickness, i.table_top_thickness), "gold")
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(side * float(info.width) * math.quarter, float(i.table_height) + float(i.candle_height) * math.half, math.zero), Vector3(i.book_width, i.candle_height, i.book_depth), "linen")


func scatter_grass(parent: Node3D, rect: Dictionary, can_plant: Callable) -> void:
	var info: Dictionary = rectangle(rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.settings.random_seed) + int(info.center.x) + int(info.center.z)
	var count: int = int(float(info.width) * float(info.depth) * float(geometry.grass_density))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(geometry.grass_width, math.one, geometry.grass_width)
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = count
	for index in range(count):
		var x: float = rng.randf_range(float(info.min_x), float(info.max_x))
		var z: float = rng.randf_range(float(info.min_z), float(info.max_z))
		var height: float = rng.randf_range(float(geometry.grass_min_height), float(geometry.grass_max_height))
		if not bool(can_plant.call(Vector2i(roundi(x / tile_size), roundi(z / tile_size)))):
			height = math.zero
		var basis := Basis(Vector3.UP, rng.randf_range(math.zero, deg_to_rad(float(math.full_turn))))
		basis = basis.scaled(Vector3(math.one, height, math.one))
		multi_mesh.set_instance_transform(index, Transform3D(basis, Vector3(x, height * math.half, z)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi_mesh
	instance.material_override = material("grass_light")
	parent.add_child(instance)


func omni(parent: Node3D, position_value: Vector3, color_name: String, energy: float, light_range: float) -> OmniLight3D:
	var result := OmniLight3D.new()
	result.position = position_value
	result.light_color = color(color_name)
	result.light_energy = energy
	result.omni_range = light_range
	result.omni_attenuation = float(geometry.dungeon.light_attenuation)
	parent.add_child(result)
	return result


func unshadowed(instance: MeshInstance3D) -> MeshInstance3D:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func fade(node: Node, value: float) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			child.transparency = value
		fade(child, value)


func flagstones(parent: Node3D, rect: Dictionary, material_name: String, seed_value: int) -> void:
	var d: Dictionary = geometry.dungeon
	var info: Dictionary = rectangle(rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(float(info.width) * float(info.depth) * float(d.flagstone_density))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = count
	for index in range(count):
		var width: float = rng.randf_range(float(d.flagstone_min_size), float(d.flagstone_max_size))
		var depth: float = rng.randf_range(float(d.flagstone_min_size), float(d.flagstone_max_size))
		var x: float = rng.randf_range(float(info.min_x) + width * math.half, float(info.max_x) - width * math.half)
		var z: float = rng.randf_range(float(info.min_z) + depth * math.half, float(info.max_z) - depth * math.half)
		var y: float = float(d.flagstone_height) * math.half + rng.randf_range(math.zero, float(d.flagstone_lift))
		var basis: Basis = Basis(Vector3.UP, rng.randf_range(-float(d.flagstone_turn), float(d.flagstone_turn))) * Basis.from_scale(Vector3(width, d.flagstone_height, depth))
		multi_mesh.set_instance_transform(index, Transform3D(basis, Vector3(x, y, z)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi_mesh
	instance.material_override = material(material_name)
	parent.add_child(instance)


func rubble(parent: Node3D, center: Vector3, spread: float, count: int, min_radius: float, max_radius: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(count):
		var radius: float = rng.randf_range(min_radius, max_radius)
		var offset := Vector3(rng.randf_range(-spread, spread), radius * math.quarter, rng.randf_range(-spread, spread))
		var stone: MeshInstance3D = sphere(parent, center + offset, radius, radius, "stone_dark" if index % int(math.double) == int(math.zero) else "shrine_stone")
		stone.rotation.y = rng.randf_range(math.zero, deg_to_rad(float(math.full_turn)))


func dungeon_wall(parent: Node3D, first: Vector2i, last: Vector2i, height: float) -> void:
	var d: Dictionary = geometry.dungeon
	var info: Dictionary = rectangle({"from": [first.x, first.y], "to": [last.x, last.y]})
	box(parent, info.center + Vector3.UP * height * math.half, Vector3(info.width, height, info.depth), "shrine_stone")
	box(parent, info.center + Vector3.UP * (height + float(d.cap_height) * math.half), Vector3(float(info.width) + float(d.cap_overhang), d.cap_height, float(info.depth) + float(d.cap_overhang)), "shrine_stone_dark")


func wall_face(parent: Node3D, from_x: float, to_x: float, face_z: float, rng: RandomNumberGenerator) -> void:
	var d: Dictionary = geometry.dungeon
	var x: float = from_x + rng.randf_range(float(d.pilaster_width), float(d.pilaster_spacing))
	while x < to_x - float(d.pilaster_width):
		box(parent, Vector3(x, float(d.wall_height) * math.half, face_z + float(d.pilaster_depth) * math.half), Vector3(d.pilaster_width, d.wall_height, d.pilaster_depth), "shrine_stone_dark")
		x += float(d.pilaster_spacing) + rng.randf_range(-float(d.pilaster_jitter), float(d.pilaster_jitter))
	var count: int = int((to_x - from_x) * float(d.rubble_per_meter))
	for index in range(count):
		var radius: float = rng.randf_range(float(d.rubble_min_radius), float(d.rubble_max_radius))
		var position_value := Vector3(rng.randf_range(from_x, to_x), radius * math.quarter, face_z + rng.randf_range(radius, float(d.rubble_spread)))
		sphere(parent, position_value, radius, radius, "shrine_stone_dark" if index % int(math.double) == int(math.zero) else "shrine_stone")


func torch(parent: Node3D, wall_cell: Vector2i) -> void:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "Torch", at(wall_cell, float(d.torch_y)) + Vector3.BACK * tile_size * math.half)
	var bracket: Vector3 = vector(d.torch_bracket)
	box(root, Vector3(math.zero, math.zero, bracket.z * math.half), bracket, "iron")
	cylinder(root, Vector3(math.zero, float(d.torch_handle_height) * math.half, bracket.z), d.torch_handle_radius, d.torch_handle_height, "wood_dark")
	unshadowed(sphere(root, Vector3(math.zero, float(d.torch_handle_height) + float(d.flame_height) * math.quarter, bracket.z), d.flame_radius, d.flame_height, "torch_flame"))
	omni(root, Vector3(math.zero, d.torch_handle_height, d.torch_light_offset), "torch_light", d.torch_light_energy, d.torch_light_range)


func brazier(parent: Node3D, position_cell: Vector2i) -> void:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "Brazier", at(position_cell, math.zero))
	cylinder(root, Vector3(math.zero, float(d.brazier_height) * math.half, math.zero), float(d.brazier_radius) * math.quarter, d.brazier_height, "iron")
	cylinder(root, Vector3(math.zero, float(d.brazier_bowl_height) * math.half, math.zero), float(d.brazier_radius) * math.half, d.brazier_bowl_height, "iron")
	tapered(root, Vector3(math.zero, d.brazier_height, math.zero), float(d.brazier_radius) * math.half, d.brazier_bowl_height, "iron", math.double)
	unshadowed(sphere(root, Vector3(math.zero, float(d.brazier_height) + float(d.brazier_bowl_height), math.zero), float(d.brazier_radius) * math.half, d.brazier_radius, "torch_flame"))
	omni(root, Vector3(math.zero, d.brazier_light_y, math.zero), "torch_light", d.brazier_light_energy, d.brazier_light_range)


func pillar(parent: Node3D, position_cell: Vector2i, broken: bool) -> void:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "Pillar", at(position_cell, math.zero))
	var base: Vector3 = vector(d.pillar_base)
	var capital: Vector3 = vector(d.pillar_capital)
	var height: float = float(d.pillar_broken_height) if broken else float(d.pillar_height)
	box(root, Vector3(math.zero, base.y * math.half, math.zero), base, "shrine_stone_dark")
	cylinder(root, Vector3(math.zero, (base.y + height) * math.half, math.zero), d.pillar_radius, height - base.y, "shrine_stone_light")
	if broken:
		var crown: MeshInstance3D = tapered(root, Vector3(math.zero, height, math.zero), d.pillar_radius, base.y, "shrine_stone_light", math.half)
		crown.rotation.z = float(d.flagstone_turn) * math.double
		rubble(root, Vector3(base.x * math.half, math.zero, base.z * math.half), d.rubble_spread, int(d.rubble_heap_count), d.rubble_min_radius, d.rubble_max_radius, position_cell.x * int(d.rubble_heap_count) + position_cell.y)
	else:
		box(root, Vector3(math.zero, height + capital.y * math.half, math.zero), capital, "shrine_stone_dark")


func statue(parent: Node3D, position_cell: Vector2i) -> void:
	var d: Dictionary = geometry.dungeon
	var ratio: float = float(geometry.character.body_top_ratio)
	var root: Node3D = group(parent, "ChaosIdol", at(position_cell, math.zero))
	var base: Vector3 = vector(d.statue_base)
	box(root, Vector3(math.zero, base.y * math.half, math.zero), base, "shrine_stone_dark")
	tapered(root, Vector3(math.zero, base.y + float(d.statue_body_height) * math.half, math.zero), d.statue_body_radius, d.statue_body_height, "shrine_stone_light", ratio)
	var head_y: float = base.y + float(d.statue_body_height) + float(d.statue_head_radius) * math.half
	sphere(root, Vector3(math.zero, head_y, math.zero), d.statue_head_radius, float(d.statue_head_radius) * math.double, "shrine_stone_light")
	for side in [math.zero - math.one, math.one]:
		var horn: MeshInstance3D = tapered(root, Vector3(side * float(d.statue_head_radius) * math.half, head_y + float(d.statue_head_radius), math.zero), d.statue_horn_radius, d.statue_horn_height, "shrine_stone", math.zero)
		horn.rotation.z = -side * float(d.statue_horn_tilt)
		var wing: MeshInstance3D = box(root, Vector3(side * float(d.statue_body_radius), base.y + float(d.statue_body_height) * math.half, -float(d.statue_body_radius) * math.half), vector(d.statue_wing), "shrine_stone")
		wing.rotation.y = side * float(d.statue_horn_tilt)
		unshadowed(sphere(root, Vector3(side * float(d.statue_eye_spacing), head_y, float(d.statue_head_radius) * ratio), d.statue_eye_radius, float(d.statue_eye_radius) * math.double, "chaos_glow"))


func bones(parent: Node3D, position_cell: Vector2i) -> void:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "Bones", at(position_cell, math.zero))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.settings.random_seed) + position_cell.x * int(d.bone_count) - position_cell.y
	var spread: float = float(d.rubble_spread)
	sphere(root, Vector3(rng.randf_range(-spread, spread), d.skull_radius, rng.randf_range(-spread, spread)), d.skull_radius, float(d.skull_radius) * math.double, "bone")
	for index in range(int(d.bone_count)):
		var start := Vector3(rng.randf_range(-spread, spread), d.bone_radius, rng.randf_range(-spread, spread))
		var angle: float = rng.randf_range(math.zero, deg_to_rad(float(math.full_turn)))
		var finish: Vector3 = start + Vector3(cos(angle), math.zero, sin(angle)) * float(d.bone_length)
		rod(root, start, finish, d.bone_radius, "bone" if index % int(math.double) == int(math.zero) else "bone_dark")


func rubble_heap(parent: Node3D, position_cell: Vector2i) -> void:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "Rubble", at(position_cell, math.zero))
	rubble(root, Vector3.ZERO, d.rubble_heap_spread, int(d.rubble_heap_count), d.rubble_heap_min, d.rubble_heap_max, position_cell.x - position_cell.y * int(d.rubble_heap_count))
	var block_size: Vector3 = vector(d.rubble_heap_block)
	var block: MeshInstance3D = box(root, Vector3(math.zero, block_size.y * math.half, math.zero), block_size, "shrine_stone")
	block.rotation = Vector3(d.rubble_heap_tilt, d.rubble_heap_tilt, math.zero)


func runes(parent: Node3D, position_cell: Vector2i) -> void:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "ChaosRunes", at(position_cell, float(d.rune_height)))
	var ring: MeshInstance3D = unshadowed(torus(root, Vector3.ZERO, d.rune_inner_radius, d.rune_outer_radius, "chaos_rune"))
	ring.scale.y = float(d.rune_height) / ((float(d.rune_outer_radius) - float(d.rune_inner_radius)) * math.half)
	unshadowed(cylinder(root, Vector3.ZERO, d.rune_core_radius, d.rune_height, "chaos_rune"))
	var length: float = float(d.rune_inner_radius) * math.double
	var thickness: float = float(d.bone_radius) * math.double
	for angle in [math.zero, float(math.right_angle) * math.half]:
		for dimensions in [Vector3(length, d.rune_height, thickness), Vector3(thickness, d.rune_height, length)]:
			var bar: MeshInstance3D = unshadowed(box(root, Vector3.UP * float(d.rune_height), dimensions, "chaos_glow"))
			bar.rotation.y = deg_to_rad(float(angle))
	omni(root, Vector3(math.zero, d.rune_light_y, math.zero), "chaos_light", d.rune_light_energy, d.rune_light_range)


func prison(parent: Node3D, position_cell: Vector2i, elevation: float) -> void:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "ChaosPrison", at(position_cell, elevation))
	unshadowed(cylinder(root, Vector3(math.zero, float(d.prison_height) * math.half, math.zero), d.prison_radius, d.prison_height, "prison"))
	for y in [math.zero, float(d.prison_height)]:
		unshadowed(torus(root, Vector3(math.zero, y, math.zero), d.prison_radius, float(d.prison_radius) + float(d.bone_radius) * math.double, "chaos_glow"))
	omni(root, Vector3(math.zero, float(d.prison_height) * math.half, float(d.prison_radius) * math.double), "chaos_light", d.rune_light_energy, d.rune_light_range)


func dais(parent: Node3D, rect: Dictionary) -> void:
	var d: Dictionary = geometry.dungeon
	var info: Dictionary = rectangle(rect)
	var root: Node3D = group(parent, "Dais", info.center)
	box(root, Vector3(math.zero, float(d.dais_height) * math.half, math.zero), Vector3(info.width, d.dais_height, info.depth), "shrine_stone_light")
	box(root, Vector3(math.zero, float(d.dais_height) * math.quarter, float(info.depth) * math.half + float(d.dais_step) * math.half), Vector3(float(info.width) - float(d.dais_step) * math.double, float(d.dais_height) * math.half, d.dais_step), "shrine_stone")
	var altar: Vector3 = vector(d.altar)
	var altar_z: float = -float(info.depth) * math.half + altar.z * math.half
	box(root, Vector3(math.zero, float(d.dais_height) + altar.y * math.half, altar_z), altar, "shrine_stone_dark")
	box(root, Vector3(math.zero, float(d.dais_height) + altar.y, altar_z), vector(d.altar_cloth), "chaos_banner")
	for side in [math.zero - math.one, math.one]:
		candle(root, Vector3(side * altar.x * math.quarter, float(d.dais_height) + altar.y, altar_z))


func exit_light(parent: Node3D, position_cell: Vector2i) -> void:
	var d: Dictionary = geometry.dungeon
	unshadowed(plane(parent, at(position_cell, d.exit_glow_height), tile_size, tile_size, "exit_light"))
	omni(parent, at(position_cell, d.exit_light_y), "exit_light", d.exit_light_energy, d.exit_light_range)


func stairs(parent: Node3D, position_cell: Vector2i, toward: Vector2i, rising: bool) -> void:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "Stairs", at(position_cell, math.zero))
	root.rotation.y = atan2(float(toward.x), float(toward.y))
	var count: int = int(d.stair_steps)
	var depth: float = tile_size / float(count)
	var width: float = tile_size - float(d.stair_side) * math.double
	var rise: float = float(d.stair_rise)
	var wall_height: float = float(d.wall_height)
	for index in range(count):
		var z: float = -tile_size * math.half + depth * (float(index) + math.half)
		var material_name: String = "shrine_stone_light" if index % int(math.double) == int(math.zero) else "shrine_stone"
		if rising:
			var height: float = rise * float(index + int(math.one))
			box(root, Vector3(math.zero, height * math.half, z), Vector3(width, height, depth), material_name)
		else:
			box(root, Vector3(math.zero, -rise * (float(index) + math.one + math.half), z), Vector3(width, rise, depth), material_name)
	if rising:
		var top_step: float = rise * float(count)
		box(root, Vector3(math.zero, wall_height - float(d.stair_lintel) * math.half, -tile_size * math.half + float(d.stair_lintel) * math.half), Vector3(tile_size, d.stair_lintel, d.stair_lintel), "shrine_stone_light")
		box(root, Vector3(math.zero, (top_step + wall_height) * math.half, (tile_size - float(d.stair_side)) * math.half), Vector3(width, wall_height - top_step, d.stair_side), "void")
	else:
		var bottom: float = -rise * float(count + int(math.one))
		for side in [math.zero - math.one, math.one]:
			box(root, Vector3(side * (tile_size - float(d.stair_side)) * math.half, bottom * math.half, math.zero), Vector3(d.stair_side, -bottom, tile_size), "shrine_stone_dark")
		box(root, Vector3(math.zero, bottom * math.half, (tile_size - float(d.stair_side)) * math.half), Vector3(width, -bottom, d.stair_side), "void")
		box(root, Vector3(math.zero, bottom, math.zero), Vector3(width, rise, tile_size), "void")


func chest(parent: Node3D, position_cell: Vector2i, opened: bool) -> Node3D:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "Chest", at(position_cell, math.zero))
	var size: Vector3 = vector(d.chest)
	var lid: Vector3 = vector(d.chest_lid)
	var band: float = float(d.chest_band)
	box(root, Vector3(math.zero, size.y * math.half, math.zero), size, "wood")
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(side * size.x * math.quarter, size.y * math.half, math.zero), Vector3(band, size.y + band * math.half, size.z + band * math.half), "iron")
	var pivot: Node3D = group(root, "LidPivot", Vector3(math.zero, size.y, -lid.z * math.half))
	box(pivot, Vector3(math.zero, lid.y * math.half, lid.z * math.half), lid, "wood_light")
	for side in [math.zero - math.one, math.one]:
		box(pivot, Vector3(side * size.x * math.quarter, lid.y * math.half, lid.z * math.half), Vector3(band, lid.y + band * math.half, lid.z + band * math.half), "iron")
	box(pivot, Vector3(math.zero, math.zero, lid.z), vector(d.chest_lock), "gold")
	var glint: MeshInstance3D = unshadowed(box(root, Vector3(math.zero, size.y, math.zero), vector(d.chest_glint), "key_gold"))
	glint.name = "Glint"
	glint.visible = false
	if opened:
		pivot.rotation.x = -float(d.chest_open_angle)
	return root


func dungeon_door(parent: Node3D, position_cell: Vector2i, opened: bool) -> Node3D:
	var d: Dictionary = geometry.dungeon
	var root: Node3D = group(parent, "LockedDoor", at(position_cell, math.zero))
	var leaf: Vector3 = vector(d.door_leaf)
	var post: Vector3 = vector(d.door_post)
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(side * (tile_size - post.x) * math.half, post.y * math.half, math.zero), post, "shrine_stone_light")
	box(root, Vector3(math.zero, (leaf.y + float(d.wall_height)) * math.half, math.zero), Vector3(tile_size, float(d.wall_height) - leaf.y, post.z), "shrine_stone_light")
	var pivot: Node3D = group(root, "LeafPivot", Vector3(-leaf.x * math.half, math.zero, math.zero))
	box(pivot, Vector3(leaf.x * math.half, leaf.y * math.half, math.zero), leaf, "wood_dark")
	var count: int = int(d.door_band_count)
	for index in range(count):
		var y: float = leaf.y * float(index + int(math.one)) / float(count + int(math.one))
		box(pivot, Vector3(leaf.x * math.half, y, leaf.z * math.half), Vector3(leaf.x, d.door_band, d.door_band), "iron")
	var lock: Vector3 = vector(d.door_lock)
	box(pivot, Vector3(leaf.x * (math.one - math.quarter), leaf.y * math.half, (leaf.z + lock.z) * math.half), lock, "gold")
	if opened:
		pivot.rotation.y = float(d.door_open_angle)
	return root


func shrine(parent: Node3D, rect: Dictionary, door_cell: Array) -> void:
	var s: Dictionary = geometry.shrine
	var d: Dictionary = geometry.dungeon
	var info: Dictionary = rectangle(rect)
	var root: Node3D = group(parent, "ChaosShrine", info.center)
	var width: float = float(info.width)
	var depth: float = float(info.depth)
	var front: float = depth * math.half
	var back: float = -front
	var base: float = float(s.foundation_height)
	var margin: float = float(s.foundation_margin)
	var frame: float = float(s.door_frame)
	var door_x: float = float(cell(door_cell).x) * tile_size - float(info.center.x)
	var cella_front: float = front - float(s.portico_depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.settings.random_seed) + int(info.center.z)
	box(root, Vector3(math.zero, base * math.half, -margin * math.half), Vector3(width + margin * math.double, base, depth + margin), "shrine_stone_dark")
	var steps: int = roundi(base / float(s.step_height)) - int(math.one)
	for index in range(steps):
		var top: float = base - float(s.step_height) * float(index + int(math.one))
		box(root, Vector3(door_x, top * math.half, front + float(s.step_depth) * (float(index) + math.half)), Vector3(s.step_width, top, s.step_depth), "shrine_stone")
	var section: float = float(s.door_section_width)
	var body_depth: float = cella_front - back
	var body_z: float = (cella_front + back) * math.half
	var spans: Array = [
		{"from": -width * math.half, "to": door_x - section * math.half, "height": float(s.body_height)},
		{"from": door_x - section * math.half, "to": door_x + section * math.half, "height": float(s.door_section_height)},
		{"from": door_x + section * math.half, "to": width * math.half, "height": float(s.ruin_height)}
	]
	for span in spans:
		var span_width: float = float(span.to) - float(span.from)
		var center_x: float = (float(span.from) + float(span.to)) * math.half
		box(root, Vector3(center_x, base + float(span.height) * math.half, body_z), Vector3(span_width, span.height, body_depth), "shrine_stone")
		var count: int = maxi(int(math.one), int(span_width / float(s.parapet_width)))
		for index in range(count):
			var height: float = rng.randf_range(float(s.parapet_min), float(s.parapet_max))
			var x: float = float(span.from) + span_width * (float(index) + math.half) / float(count)
			box(root, Vector3(x, base + float(span.height) + height * math.half, cella_front - float(s.parapet_width) * math.half), Vector3(float(s.parapet_width) * float(geometry.character.body_top_ratio), height, s.parapet_width), "shrine_stone_light")
	rubble(root, Vector3((door_x + section * math.half + width * math.half) * math.half, base + float(s.ruin_height), body_z), section * math.quarter, int(d.rubble_heap_count), d.rubble_heap_min, d.rubble_heap_max, int(info.center.x))
	var doorway: Vector3 = vector(s.doorway)
	var banner: Vector3 = vector(s.banner)
	box(root, Vector3(door_x, base + doorway.y * math.half, cella_front + doorway.z * math.half), doorway, "void")
	for side in [math.zero - math.one, math.one]:
		box(root, Vector3(door_x + side * (doorway.x + frame) * math.half, base + doorway.y * math.half, cella_front + frame * math.half), Vector3(frame, doorway.y, frame), "shrine_stone_light")
		box(root, Vector3(door_x + side * float(s.banner_x), s.banner_y, cella_front + banner.z), banner, "chaos_banner")
	box(root, Vector3(door_x, base + doorway.y + frame * math.half, cella_front + frame * math.half), Vector3(doorway.x + frame * math.double, frame, frame), "shrine_stone_light")
	unshadowed(box(root, Vector3(door_x, base + float(geometry.path_height), cella_front + float(s.glow_depth) * math.half), Vector3(doorway.x, geometry.path_height, s.glow_depth), "chaos_glow"))
	var emblem: MeshInstance3D = unshadowed(torus(root, Vector3(door_x, s.emblem_y, cella_front + frame), s.emblem_inner, s.emblem_outer, "chaos_glow"))
	emblem.rotation.x = deg_to_rad(float(math.right_angle))
	omni(root, Vector3(door_x, s.light_y, cella_front + float(s.portico_depth) * math.half), "chaos_light", s.light_energy, s.light_range)
	var column_z: float = front - float(s.column_inset)
	for index in range(s.column_x.size()):
		var x: float = float(s.column_x[index])
		var broken_index: int = s.broken_columns.find(index)
		var height: float = float(s.column_height) if broken_index < int(math.zero) else float(s.broken_heights[broken_index])
		box(root, Vector3(x, base + float(s.architrave_height) * math.quarter, column_z), Vector3(float(s.column_radius) * math.double + frame, float(s.architrave_height) * math.half, float(s.column_radius) * math.double + frame), "shrine_stone_dark")
		cylinder(root, Vector3(x, base + height * math.half, column_z), s.column_radius, height, "shrine_stone_light")
		if broken_index >= int(math.zero):
			var crown: MeshInstance3D = tapered(root, Vector3(x, base + height, column_z), s.column_radius, frame, "shrine_stone_light", math.half)
			crown.rotation.z = float(d.flagstone_turn) * math.double
	var architrave_from: float = -width * math.half
	var architrave_to: float = float(s.architrave_ruin_x)
	var architrave_y: float = base + float(s.column_height) + float(s.architrave_height) * math.half
	box(root, Vector3((architrave_from + architrave_to) * math.half, architrave_y, column_z), Vector3(architrave_to - architrave_from, s.architrave_height, s.architrave_depth), "shrine_stone")
	var pediment: Vector3 = vector(s.pediment)
	prism(root, Vector3(door_x, architrave_y + float(s.architrave_height) * math.half + pediment.y * math.half, column_z), pediment, "shrine_stone")
	var moss: Vector3 = vector(s.moss)
	for x in [architrave_from + moss.x, door_x - section * math.half, architrave_to - moss.x]:
		box(root, Vector3(x, architrave_y + float(s.architrave_height) * math.half, column_z), moss, "shrine_moss")
		box(root, Vector3(x * math.half, base, front), moss, "shrine_moss")
	var offset := Vector2(float(s.fallen_column_offset[int(math.zero)]), float(s.fallen_column_offset[int(math.one)]))
	var fallen: MeshInstance3D = cylinder(root, Vector3(offset.x, s.column_radius, front + offset.y), s.column_radius, s.fallen_column_length, "shrine_stone_light")
	fallen.rotation = Vector3(math.zero, float(d.flagstone_turn), deg_to_rad(float(math.right_angle)))
	rubble(root, Vector3(offset.x - float(s.fallen_column_length) * math.half, math.zero, front + offset.y), d.rubble_spread, int(d.rubble_heap_count), d.rubble_min_radius, d.rubble_heap_min, int(info.center.z))
