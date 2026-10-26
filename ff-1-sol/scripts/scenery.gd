extends RefCounted
## Decorative geometry stays inside occupied footprints or flat on the floor.
var v = preload("res://scripts/visuals.gd").new()

func town(world: Node3D) -> void:
	var art: Dictionary = GameState.polish.scenery
	v.assembly(world, art.town_parts)
	v.assembly(world, art.castle_detail)
	for house in GameState.map.town.houses:
		v.assembly(world.get_node(house.id), art.house_common, {"house_roof":house.roof})
	for at in art.bank_rocks:
		v.shape(world, "sphere", GameState.vec(art.rock_size), GameState.ground(GameState.cell(at)), art.rock_color)

func interior(world: Node3D) -> void:
	var art: Dictionary = GameState.polish.scenery
	if world.location_id == "throne":
		v.assembly(world, art.throne_parts)
		return
	v.assembly(world, art.room_counter)
	v.assembly(world, art.room_side_parts)
	if art.room_theme.has(world.house_id):
		v.assembly(world, art.room_theme[world.house_id])
	if world.house_id != "east_south":
		var clerk: Node3D = v.actor(world, {"id":"ServiceKeeper", "appearance":"healer" if world.house_id == "west_south" else "keeper"})
		clerk.position = GameState.vec(art.clerk_position)
	if world.house_id == "east_middle":
		var index := int(GameState.rules.n.zero)
		for x in art.bottle_x:
			v.shape(world, "cylinder", GameState.vec(art.bottle_size), Vector3(x, art.bottle_y, art.bottle_z), art.bottle_colors[index % art.bottle_colors.size()])
			index += int(GameState.rules.n.one)
	v.lamp(world, GameState.vec(art.room_light))

func dungeon(world: Node3D) -> void:
	var art: Dictionary = GameState.polish.scenery
	var rng := RandomNumberGenerator.new()
	rng.seed = int(art.seed)
	for index in range(int(art.dungeon_pavers)):
		var size := Vector3(rng.randf_range(art.dungeon_paver_size_min, art.dungeon_paver_size_max), art.dungeon_paver_height, rng.randf_range(art.dungeon_paver_size_min, art.dungeon_paver_size_max))
		var pos := Vector3(rng.randf_range(-art.dungeon_x, art.dungeon_x), art.dungeon_paver_y, rng.randf_range(art.dungeon_z_min, art.dungeon_z_max))
		v.shape(world, "box", size, pos, art.dungeon_colors[index % art.dungeon_colors.size()])
	v.assembly(world, art.dungeon_wall_parts)
	for at in world.layout.columns:
		var group := Node3D.new()
		group.position = GameState.ground(GameState.cell(at))
		world.add_child(group)
		v.assembly(group, art.column_cap)
	for at in GameState.dungeon.visual.braziers:
		v.lamp(world, GameState.ground(GameState.cell(at)) + Vector3.UP * GameState.polish.lighting.light_height)
	if world.location_id == "chaos_1":
		v.assembly(world, art.door_arch)
	else:
		v.assembly(world, art.altar_parts)

func arena(world: Node3D) -> void:
	var art: Dictionary = GameState.polish.scenery
	v.assembly(world, art.arena_inlays)
	for at in art.arena_columns:
		var group := Node3D.new()
		group.position = Vector3(at.front(), GameState.rules.n.zero, at.back())
		world.add_child(group)
		v.assembly(group, art.arena_column_parts)
	for at in art.arena_braziers:
		var group := Node3D.new()
		group.position = Vector3(at.front(), GameState.rules.n.zero, at.back())
		world.add_child(group)
		v.assembly(group, GameState.dungeon.visual.brazier_parts)
		v.lamp(group, Vector3.UP * GameState.polish.lighting.light_height)
	v.assembly(world, art.arena_center_parts)
