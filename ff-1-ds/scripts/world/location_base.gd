class_name LocationBase
extends Node3D
## Shared base for every playable location. Handles the environment, grid collision
## probes, interaction anchors and location metadata.

var data: Dictionary = {}
var interactables: Array[Interactable] = []
var title: String = ""
var subtitle: String = ""
var variant: String = ""
var is_ready_for_party: bool = false

var _step: float = 2.0
var _party_radius: float = 0.36
var _probe_height: float = 0.65
var _probe_size: float = 1.4
var _solid_layer: int = 1
var _max_hits: int = 8
var _walk_min: Vector2i = Vector2i(-999, -999)
var _walk_max: Vector2i = Vector2i(999, 999)


func setup(location_data: Dictionary, new_variant: String = "") -> void:
	data = location_data
	variant = new_variant
	_step = GameState.step_size()
	var world_cfg: Dictionary = GameState.game["world"]
	_party_radius = float(world_cfg["party_radius"])
	_probe_height = float(world_cfg["probe_height"])
	_probe_size = float(world_cfg["probe_height_size"])
	_solid_layer = int(world_cfg["solid_layer"])
	_max_hits = int(world_cfg["max_physics_hits"])
	title = str(location_data.get("title", ""))
	subtitle = str(location_data.get("subtitle", ""))
	_read_walk_bounds()
	_apply_environment(location_data.get("environment", {}))


func build() -> void:
	pass


func finalize() -> void:
	is_ready_for_party = true


func _read_walk_bounds() -> void:
	var bounds: Dictionary = data.get("walk_bounds", {})
	_walk_min = GameState.to_cell(bounds.get("min", [-999, -999]))
	_walk_max = GameState.to_cell(bounds.get("max", [999, 999]))


func get_spawn(spawn_name: String) -> Dictionary:
	var spawns: Dictionary = data.get("spawns", {})
	return spawns.get(spawn_name, {})


func add_interactable(kind: String, prompt: String, payload: Dictionary, world_pos: Vector3) -> Interactable:
	var point := Interactable.new()
	point.name = "Interactable_%s_%d" % [kind, interactables.size()]
	point.setup(kind, prompt, payload, world_pos)
	add_child(point)
	interactables.append(point)
	return point


func nearest_interactable(from_world: Vector3, max_distance: float) -> Interactable:
	var best: Interactable = null
	var best_distance := max_distance * max_distance
	for point: Interactable in interactables:
		if not is_instance_valid(point) or not point.enabled:
			continue
		var d := from_world.distance_squared_to(point.global_position)
		if d < best_distance:
			best_distance = d
			best = point
	return best


func can_party_stand(cell: Vector2i) -> bool:
	if cell.x < _walk_min.x or cell.y < _walk_min.y or cell.x > _walk_max.x or cell.y > _walk_max.y:
		return false
	if not inside_walkable_region(cell):
		return false
	var world_pos := cell_to_world(cell)
	var space := get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = _party_radius
	shape.height = _probe_size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), world_pos + Vector3(0.0, _probe_height, 0.0))
	query.collision_mask = _solid_layer
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits := space.intersect_shape(query, _max_hits)
	return hits.is_empty()


func inside_walkable_region(_cell: Vector2i) -> bool:
	return true


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * _step, 0.0, float(cell.y) * _step)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / _step), roundi(pos.z / _step))


func get_walk_bounds() -> Rect2i:
	return Rect2i(_walk_min, _walk_max - _walk_min + Vector2i.ONE)


func playable_center() -> Vector3:
	return Vector3.ZERO


# ---------------------------------------------------------------------------
# Environment and shared set dressing
# ---------------------------------------------------------------------------

func _apply_environment(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	var env := Environment.new()
	if str(cfg.get("background", "sky")) == "sky":
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(str(cfg["sky_top_color"]))
		sky_mat.sky_horizon_color = Color(str(cfg["sky_horizon_color"]))
		sky_mat.ground_horizon_color = Color(str(cfg["ground_horizon_color"]))
		sky_mat.ground_bottom_color = Color(str(cfg["ground_bottom_color"]))
		sky_mat.sun_angle_max = 28.0
		sky_mat.sun_curve = 0.12
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(str(cfg.get("background_color", "#1b1722")))
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	env.ambient_light_color = Color(str(cfg.get("ambient_color", "#ffffff")))
	env.ambient_light_energy = float(cfg.get("ambient_energy", 0.5))
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(cfg.get("exposure", 1.0))
	env.glow_enabled = true
	env.glow_intensity = float(cfg.get("glow", 0.3))
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = bool(cfg.get("fog_enabled", false))
	env.fog_light_color = Color(str(cfg.get("fog_color", "#c9b99c")))
	env.fog_density = float(cfg.get("fog_density", 0.0))
	env.fog_sky_affect = 0.35
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	env.adjustment_brightness = 1.0

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	if cfg.has("sun_color"):
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		sun.light_color = Color(str(cfg["sun_color"]))
		sun.light_energy = float(cfg.get("sun_energy", 1.2))
		sun.rotation_degrees = GameState.vec3_from_array(cfg.get("sun_rotation", [-45.0, -120.0, 0.0]))
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 90.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.shadow_bias = 0.035
		add_child(sun)


func add_ground_disc(center: Vector3, radius: float, mat: Material, node_name: String = "Disc") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	mesh.radial_segments = 48
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func add_boundary_wall(size: Vector3, center: Vector3, node_name: String = "Boundary") -> void:
	MeshLib.add_box_collider(self, size, center, node_name)
