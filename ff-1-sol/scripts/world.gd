extends Node3D
## A loaded location owns scenery and occupancy, never the party.

@export var location_id: String = "town"
var house_id: String = ""
var cells: Dictionary = {}
var portals: Dictionary = {}
var npcs: Array = []
var v = preload("res://scripts/visuals.gd").new()
var rng := RandomNumberGenerator.new()
var layout: Dictionary
var bridge_root: Node3D

func _ready() -> void:
	layout = GameState.map[location_id]
	_build_occupancy()
	if location_id == "town":
		_build_town()
	else:
		_build_interior()
	_build_npcs()
	var details = preload("res://scripts/scenery.gd").new()
	if location_id == "town":
		details.town(self)
	else:
		details.interior(self)

func _rectangle(rect: Array, value: bool) -> void:
	for x in range(int(rect.front()), int(rect[int(GameState.rules.n.two)]) + int(GameState.rules.n.one)):
		for z in range(int(rect[int(GameState.rules.n.one)]), int(rect.back()) + int(GameState.rules.n.one)):
			var key := Vector2i(x, z)
			if value:
				cells[key] = true
			else:
				cells.erase(key)

func _build_occupancy() -> void:
	for rect in layout.walkable:
		_rectangle(rect, true)
	for rect in layout.blocked:
		_rectangle(rect, false)
	for portal in layout.portals:
		portals[GameState.cell(portal.cell)] = portal.duplicate(true)
	if location_id == "town":
		for house in layout.houses:
			var at := GameState.cell(house.cell)
			var radius := int(GameState.rules.n.two)
			_rectangle([at.x - radius, at.y - radius, at.x + radius, at.y + radius], false)
			portals[GameState.cell(house.door)] = {"to":"house", "house_id":house.id, "spawn":GameState.map.house.spawn}
		for tree in layout.trees:
			cells.erase(GameState.cell(tree))
		for category in ["lamps", "benches", "flowerbeds"]:
			for prop in layout[category]:
				cells.erase(GameState.cell(prop))
	for spec in GameState.map.npcs:
		if spec.location == location_id:
			cells.erase(GameState.cell(spec.cell))

func can_walk(at: Vector2i) -> bool:
	return cells.has(at)

func action_near(_at: Vector2i, _facing: Vector2i) -> Dictionary:
	return {}

func boss_at(_at: Vector2i) -> bool:
	return false

func portal_at(at: Vector2i) -> Dictionary:
	return portals.get(at, {})

func npc_near(at: Vector2i, facing: Vector2i) -> Dictionary:
	var fallback: Dictionary = {}
	for npc in npcs:
		if not npc.node.visible:
			continue
		var offset: Vector2i = GameState.cell(npc.cell) - at
		if absi(offset.x) + absi(offset.y) <= GameState.rules.movement.interact_distance:
			if offset == facing:
				return GameState.npc_dialog(npc)
			fallback = npc
	return GameState.npc_dialog(fallback) if not fallback.is_empty() else {}

func _group_at(at: Vector3, label: String) -> Node3D:
	var group := Node3D.new()
	group.name = label
	group.position = at
	add_child(group)
	return group

func _palette(name: String) -> String:
	return GameState.art.palette[name]

func _build_town() -> void:
	var art: Dictionary = GameState.art
	rng.seed = int(art.pavers.seed)
	v.assembly(self, art.town_ground)
	# Replace the river material with a world-space moving water shader.
	for node in get_children():
		if node is MeshInstance3D and node.material_override.albedo_color == Color(_palette("water")):
			var water := ShaderMaterial.new()
			water.shader = preload("res://shaders/water.gdshader")
			for key in art.water:
				var value = art.water[key]
				water.set_shader_parameter(key, Color(value) if value is String else value)
			node.material_override = water
	for path in layout.paths:
		v.shape(self, "box", GameState.vec(path.size), GameState.vec(path.pos), _palette("road"))
	v.shape(self, "cylinder", GameState.vec(art.plaza.outer), GameState.vec(art.plaza.pos), _palette("stone_dark"))
	v.shape(self, "cylinder", GameState.vec(art.plaza.inner), GameState.vec(art.plaza.inner_pos), _palette("stone_light"))
	for house in layout.houses:
		var root := _group_at(GameState.ground(GameState.cell(house.cell)), house.id)
		v.assembly(root, art.house_parts, {"house_roof":house.roof,"walls":house.walls})
		v.label(self, house.get("sign", "⌂"), GameState.ground(GameState.cell(house.door)) + Vector3.UP * art.labels.height, art.labels.house_size)
	v.assembly(self, art.castle_parts)
	for at in art.tower.positions:
		v.assembly(_group_at(GameState.vec(at), "CastleTower"), art.tower.parts)
	for wall in art.wall.segments:
		v.shape(self, "box", GameState.vec(wall.size), GameState.vec(wall.pos), _palette("stone"))
		var size := GameState.vec(wall.size)
		var horizontal := size.x > size.z
		var length: float = size.x if horizontal else size.z
		var cursor: float = -length * GameState.rules.n.half
		while cursor < length * GameState.rules.n.half:
			var pos := GameState.vec(wall.pos)
			pos.y = art.wall.crenel_y
			if horizontal:
				pos.x += cursor
			else:
				pos.z += cursor
			v.shape(self, "box", GameState.vec(art.wall.crenel_size), pos, _palette("stone_light"))
			cursor += art.wall.crenel_step
	for at in art.wall.gate_towers:
		var root := _group_at(GameState.vec(at), "NorthGateTower")
		root.scale = GameState.vec(art.wall.gate_scale)
		v.assembly(root, art.tower.parts)
	build_bridge(GameState.session.quest.bridge_built)
	# Riverbank and city scenery share the same bridge throughout the demo.
	for at in layout.trees:
		var root := _group_at(GameState.ground(GameState.cell(at)), "Linden")
		root.scale *= rng.randf_range(art.tree.scale_min, art.tree.scale_max)
		v.assembly(root, art.tree.parts)
	for at in layout.lamps:
		v.assembly(_group_at(GameState.ground(GameState.cell(at)), "Lantern"), art.lamp.parts)
	for at in layout.benches:
		v.assembly(_group_at(GameState.ground(GameState.cell(at)), "Bench"), art.bench.parts)
	for at in layout.flowerbeds:
		var root := _group_at(GameState.ground(GameState.cell(at)), "Flowers")
		var garden: Dictionary = art.garden
		v.shape(root, "box", GameState.vec(garden.base_size), GameState.vec(garden.base_pos), _palette("stone"))
		v.shape(root, "box", GameState.vec(garden.leaf_size), GameState.vec(garden.leaf_pos), _palette("hedge"))
		for flower in range(int(garden.flower_count)):
			var color: String = garden.colors[flower % garden.colors.size()]
			var pos := Vector3(rng.randf_range(-garden.flower_x, garden.flower_x), garden.flower_y, rng.randf_range(-garden.flower_z, garden.flower_z))
			v.shape(root, "sphere", Vector3.ONE * garden.flower_radius, pos, color)
	var fountain := _group_at(GameState.vec(art.plaza.center), "Fountain")
	v.assembly(fountain, art.fountain.parts)
	for stream in range(int(art.fountain.streams)):
		var angle: float = TAU * stream / art.fountain.streams
		var pos := Vector3(sin(angle) * art.fountain.stream_radius, art.fountain.stream_y, cos(angle) * art.fountain.stream_radius)
		v.shape(fountain, "cylinder", GameState.vec(art.fountain.stream_size), pos, "#aad5cf")
	for at in art.flags.poles:
		var flag := _group_at(GameState.vec(at), "RoyalBanner")
		v.shape(flag, "cylinder", GameState.vec(art.flags.pole_size), GameState.vec(art.flags.pole_pos), _palette("gold"))
		v.shape(flag, "box", GameState.vec(art.flags.cloth_size), GameState.vec(art.flags.cloth_pos), _palette("roof"))
		var diamond = v.shape(flag, "box", GameState.vec(art.flags.diamond_size), GameState.vec(art.flags.diamond_pos), _palette("gold"))
		diamond.rotation_degrees = GameState.vec(art.flags.diamond_rotation)
	for spec in layout.signs:
		v.label(self, spec.text, GameState.ground(GameState.cell(spec.cell)) + Vector3.UP * art.labels.height, art.labels.sign_size)
	v.assembly(self, GameState.dungeon.entrance.parts)
	v.label(self, GameState.dungeon.entrance.label, GameState.ground(GameState.cell(GameState.dungeon.entrance.cell)) + Vector3.UP * art.labels.height, art.labels.sign_size)
	for paver in range(int(art.pavers.count)):
		var pos := Vector3(rng.randf_range(art.pavers.x_min, art.pavers.x_max), art.pavers.y, rng.randf_range(art.pavers.z_min, art.pavers.z_max))
		var size := Vector3(rng.randf_range(art.pavers.size_min, art.pavers.size_max), art.pavers.height, rng.randf_range(art.pavers.depth_min, art.pavers.depth_max))
		v.shape(self, "box", size, pos, art.pavers.colors[paver % art.pavers.colors.size()])
	rng.seed = int(art.grass.seed)
	for tuft in range(int(art.grass.count)):
		var pos := Vector3(rng.randf_range(art.grass.x_min, art.grass.x_max), GameState.rules.n.zero, rng.randf_range(art.grass.z_min, art.grass.z_max))
		var on_road := false
		for path in layout.paths:
			var center := GameState.vec(path.pos)
			var half_size: Vector3 = GameState.vec(path.size) * GameState.rules.n.half
			if absf(pos.x - center.x) < half_size.x and absf(pos.z - center.z) < half_size.z:
				on_road = true
		if not on_road:
			v.assembly(_group_at(pos, "Grass"), art.grass.tuft_parts)

func build_bridge(finished: bool) -> void:
	if is_instance_valid(bridge_root):
		remove_child(bridge_root)
		bridge_root.queue_free()
	bridge_root = _group_at(Vector3.ZERO, "BridgeStructure")
	bridge_root.set_meta("finished", finished)
	var art: Dictionary = GameState.art
	if not finished:
		v.assembly(bridge_root, GameState.polish.ending.wood_parts)
		for x in art.bridge.post_x:
			for z in art.bridge.post_z:
				v.shape(bridge_root, "box", GameState.vec(GameState.polish.ending.wood_post_size), Vector3(x, art.bridge.post_y, z), GameState.polish.ending.wood_color)
		var z: float = art.bridge.tile_z_start
		while z < art.bridge.tile_z_end:
			v.shape(bridge_root, "box", GameState.vec(GameState.polish.ending.wood_plank_size), Vector3(GameState.polish.ending.bridge_x, art.bridge.tile_y, z), GameState.polish.ending.wood_plank_color)
			z += art.bridge.tile_z_step
		return
	v.assembly(bridge_root, art.bridge.parts)
	for x in art.bridge.post_x:
		for z in art.bridge.post_z:
			v.shape(bridge_root, "box", GameState.vec(art.bridge.post_size), Vector3(x, art.bridge.post_y, z), _palette("stone"))
			v.shape(bridge_root, "box", GameState.vec(art.bridge.cap_size), Vector3(x, art.bridge.cap_y, z), _palette("stone_light"))
	for x in art.bridge.pier_x:
		for z in art.bridge.pier_z:
			v.shape(bridge_root, "box", GameState.vec(art.bridge.pier_size), Vector3(x, art.bridge.pier_y, z), _palette("stone_dark"))
	var tile_z: float = art.bridge.tile_z_start
	while tile_z < art.bridge.tile_z_end:
		for x in art.bridge.tile_x:
			v.shape(bridge_root, "box", GameState.vec(art.bridge.tile_size), Vector3(x, art.bridge.tile_y, tile_z), _palette("stone_light"))
		tile_z += art.bridge.tile_z_step

func _build_interior() -> void:
	var art: Dictionary = GameState.art.interior
	var throne := location_id == "throne"
	v.part(self, art.floor_throne if throne else art.floor_house)
	v.assembly(self, art.throne_walls if throne else art.house_walls)
	v.assembly(self, art.floor_throne_tiles if throne else art.floor_house_planks)
	if throne:
		v.part(self, art.carpet)
		v.assembly(self, art.carpet_edges)
		v.assembly(self, art.dais)
		v.assembly(self, art.throne)
		for at in art.columns:
			v.assembly(_group_at(GameState.vec(at), "Column"), art.column_parts)
		for x in art.window_x:
			v.shape(self, "box", GameState.vec(art.window_size), Vector3(x, art.window_pos_y, art.window_z), _palette("roof_light"))
		for x in art.banner_x:
			v.shape(self, "box", GameState.vec(art.banner_size), Vector3(x, art.banner_pos_y, art.banner_z), _palette("roof"))
	else:
		v.assembly(self, GameState.polish.scenery.room_shelf)
	v.label(self, art.exit_text, GameState.vec(art.exit_label_pos if throne else art.house_exit_label_pos), GameState.art.labels.sign_size)

func _build_npcs() -> void:
	for spec in GameState.map.npcs:
		if spec.location != location_id:
			continue
		var npc: Dictionary = spec.duplicate(true)
		var actor: Node3D = v.actor(self, npc)
		actor.position = GameState.ground(GameState.cell(npc.cell))
		npc.node = actor
		npcs.append(npc)
		v.label(actor, "◇", Vector3.UP * GameState.art.labels.height, GameState.art.labels.sign_size)
