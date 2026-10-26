class_name MeshLib
extends RefCounted
## Small procedural mesh/material toolkit. No external art assets are required.

static var _material_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func material(color_hex: String, roughness: float = 0.86, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "std:%s:%.2f:%.2f" % [color_hex, roughness, metallic]
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color_hex)
	mat.roughness = roughness
	mat.metallic = metallic
	mat.rim_enabled = true
	mat.rim = 0.16
	mat.rim_tint = 0.35
	_material_cache[key] = mat
	return mat


static func emissive(color_hex: String, energy: float = 1.6, unshaded: bool = false) -> StandardMaterial3D:
	var key := "emit:%s:%.2f:%s" % [color_hex, energy, str(unshaded)]
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color_hex)
	mat.emission_enabled = true
	mat.emission = Color(color_hex)
	mat.emission_energy_multiplier = energy
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = mat
	return mat


static func transparent(color_hex: String, alpha: float = 0.55, unshaded: bool = false) -> StandardMaterial3D:
	var c := Color(color_hex)
	c.a = alpha
	var key := "alpha:%s:%s" % [color_hex, str(unshaded)]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.18
	mat.metallic = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = mat
	return mat


static func add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, node_name: String = "Box", rot_degrees: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_degrees
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func add_cylinder(parent: Node3D, bottom_radius: float, top_radius: float, height: float, pos: Vector3, mat: Material, node_name: String = "Cylinder", segments: int = 16, rot_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_degrees
	parent.add_child(mi)
	return mi


static func add_sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, node_name: String = "Sphere", height: float = -1.0, segments: int = 16) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 if height < 0.0 else height
	mesh.radial_segments = segments
	mesh.rings = max(6, int(segments / 2.0))
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_plane(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, node_name: String = "Plane") -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_pyramid(parent: Node3D, base: Vector2, height: float, pos: Vector3, mat: Material, node_name: String = "HipRoof", rot_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := pyramid_mesh(base, height)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_degrees
	parent.add_child(mi)
	return mi


static func pyramid_mesh(base: Vector2, height: float) -> ArrayMesh:
	var key := "pyramid:%.3f:%.3f:%.3f" % [base.x, base.y, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var hx := base.x * 0.5
	var hz := base.y * 0.5
	var a := Vector3(-hx, 0.0, -hz)
	var b := Vector3(hx, 0.0, -hz)
	var c := Vector3(hx, 0.0, hz)
	var d := Vector3(-hx, 0.0, hz)
	var e := Vector3(0.0, height, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in [[d, c, e], [c, b, e], [b, a, e], [a, d, e]]:
		for v: Vector3 in tri:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func add_triangle_wall(parent: Node3D, width: float, height: float, depth: float, pos: Vector3, mat: Material, node_name: String = "Gable", rot_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var hx := width * 0.5
	var hz := depth * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front := [Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz), Vector3(0.0, height, hz)]
	var back := [Vector3(hx, 0.0, -hz), Vector3(-hx, 0.0, -hz), Vector3(0.0, height, -hz)]
	for tri: Array in [front, back]:
		for v: Vector3 in tri:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_degrees
	parent.add_child(mi)
	return mi


static func add_box_collider(parent: Node3D, size: Vector3, center: Vector3, node_name: String = "Solid", rot_degrees: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = _solid_layer()
	body.collision_mask = 0
	body.position = center
	body.rotation_degrees = rot_degrees
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


static func add_cylinder_collider(parent: Node3D, radius: float, height: float, center: Vector3, node_name: String = "RoundSolid") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = _solid_layer()
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	parent.add_child(body)
	return body


static func add_omni_light(parent: Node3D, pos: Vector3, color_hex: String = "#ffc57b", energy: float = 1.6, light_range: float = 7.0, shadows: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color(color_hex)
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadows
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_length = 25.0
	parent.add_child(light)
	return light


static func add_label3d(parent: Node3D, text: String, pos: Vector3, font_size: int = 40, color_hex: String = "#f5e6c4", node_name: String = "Label3D") -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.font_size = font_size
	label.modulate = Color(color_hex)
	label.outline_size = 8
	label.outline_modulate = Color("#20160f")
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.pixel_size = 0.006
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


static func _solid_layer() -> int:
	var layer := 1
	if GameState != null and not GameState.game.is_empty():
		layer = int(GameState.game["world"]["solid_layer"])
	return layer
