extends RefCounted
## Shared, cached low-poly geometry. Every dimension and color lives in art.json.

var cache: Dictionary = {}
var meshes: Dictionary = {}

func material(color: String) -> StandardMaterial3D:
	if cache.has(color):
		return cache[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = GameState.art.surface.roughness
	cache[color] = mat
	return mat

func shape(parent: Node3D, kind: String, size: Vector3, pos: Vector3, color: String) -> MeshInstance3D:
	var key := kind + str(size)
	var mesh: PrimitiveMesh
	if meshes.has(key):
		mesh = meshes[key]
	else:
		match kind:
			"cylinder", "cone":
				var cylinder := CylinderMesh.new()
				cylinder.bottom_radius = size.x
				cylinder.top_radius = size.z
				cylinder.height = size.y
				cylinder.radial_segments = int(GameState.art.surface.segments)
				mesh = cylinder
			"sphere":
				var sphere := SphereMesh.new()
				sphere.radius = GameState.rules.n.one
				sphere.height = GameState.rules.n.two
				sphere.radial_segments = int(GameState.art.surface.segments)
				sphere.rings = int(GameState.art.surface.rings)
				mesh = sphere
			"roof":
				var prism := PrismMesh.new()
				prism.size = size
				mesh = prism
			_:
				var box := BoxMesh.new()
				box.size = size
				mesh = box
		meshes[key] = mesh
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = pos
	if kind == "sphere":
		instance.scale = size
	parent.add_child(instance)
	return instance

func part(parent: Node3D, spec: Dictionary, palette: Dictionary = {}) -> MeshInstance3D:
	var color: String = spec.color
	if palette.has(color):
		color = palette[color]
	elif GameState.art.palette.has(color):
		color = GameState.art.palette[color]
	var result := shape(parent, spec.get("kind", "box"), GameState.vec(spec.size), GameState.vec(spec.pos), color)
	if spec.has("name"):
		result.name = spec.name
	if spec.has("rotation"):
		result.rotation_degrees = GameState.vec(spec.rotation)
	return result

func assembly(parent: Node3D, parts: Array, palette: Dictionary = {}) -> void:
	for spec in parts:
		part(parent, spec, palette)

func actor(parent: Node3D, hero: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = hero.id
	parent.add_child(root)
	var skin: Dictionary = GameState.art.characters[hero.appearance]
	assembly(root, GameState.art.actor_base, skin)
	assembly(root, GameState.art.actor_details[hero.appearance], skin)
	return root

func fallen(root: Node3D, dead: bool, battle: bool = false) -> void:
	var key := str(dead) + str(battle)
	if root.get_meta("fallen_style", "") == key:
		return
	root.set_meta("fallen_style", key)
	for mesh in root.get_children():
		if not mesh is MeshInstance3D:
			continue
		if not mesh.has_meta("healthy_material"):
			mesh.set_meta("healthy_material", mesh.material_override)
		if dead:
			var shade: StandardMaterial3D = mesh.get_meta("healthy_material").duplicate()
			shade.albedo_color = Color(GameState.polish.actor.fallen_color)
			if not battle:
				shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				shade.albedo_color.a = GameState.polish.actor.ghost_alpha
			mesh.material_override = shade
		else:
			mesh.material_override = mesh.get_meta("healthy_material")
	if not battle:
		var marker := root.get_node_or_null("FallenMarker")
		if marker == null:
			marker = label(root, GameState.polish.actor.world_label, Vector3.UP * GameState.polish.actor.label_height, GameState.polish.actor.label_size)
			marker.name = "FallenMarker"
			marker.modulate = Color(GameState.polish.actor.label_color)
		marker.visible = dead
	elif root.has_node("FallenMarker"):
		root.get_node("FallenMarker").hide()

func lamp(parent: Node3D, at: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(GameState.polish.lighting.light_color)
	light.light_energy = GameState.polish.lighting.light_energy
	light.omni_range = GameState.polish.lighting.light_range
	parent.add_child(light)
	return light

func label(parent: Node3D, text: String, pos: Vector3, size: float) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = pos
	node.font_size = int(size)
	node.pixel_size = GameState.art.labels.pixel_size
	node.outline_size = int(GameState.art.labels.outline)
	node.modulate = Color(GameState.art.palette.ink)
	node.outline_modulate = Color(GameState.art.palette.parchment)
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	parent.add_child(node)
	return node
