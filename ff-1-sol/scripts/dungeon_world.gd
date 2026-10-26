extends "res://scripts/world.gd"
## Dungeon occupancy and scenery read the same persistent quest flags.
var chest_node: Node3D
var door_node: Node3D
var chest_lid: Node3D

func _ready() -> void:
	layout = GameState.map[location_id]
	_build_occupancy()
	_build_dungeon()
	if location_id == "chaos_1":
		var chest: Dictionary = GameState.dungeon.chest
		chest_node = _group_at(GameState.ground(GameState.cell(chest.cell)), "KeyChest")
		for index in chest.parts.size():
			if index == int(GameState.rules.n.one):
				chest_lid = Node3D.new()
				chest_lid.position = GameState.vec(GameState.polish.scenery.chest_hinge)
				chest_node.add_child(chest_lid)
				var lid: Dictionary = chest.parts[index].duplicate(true)
				lid.pos = GameState.polish.scenery.chest_lid_local
				v.part(chest_lid, lid)
			else:
				v.part(chest_node, chest.parts[index])
		cells.erase(GameState.cell(chest.cell))
		door_node = _group_at(GameState.ground(GameState.cell(GameState.dungeon.door.cell)), "KeyDoor")
		v.assembly(door_node, GameState.dungeon.door.parts)
	else:
		for spec in [GameState.dungeon.boss, GameState.dungeon.sarah]:
			var npc: Dictionary = spec.duplicate(true)
			if npc.id == "sarah" and GameState.session.quest.sarah_rescued:
				npc.cell = GameState.dungeon.sarah.rescue_cell.duplicate()
			var actor: Node3D = v.actor(self, npc)
			actor.position = GameState.ground(GameState.cell(npc.cell))
			npc.node = actor
			npcs.append(npc)
			cells.erase(GameState.cell(npc.cell))
	refresh_progress()
	preload("res://scripts/scenery.gd").new().dungeon(self)

func _build_dungeon() -> void:
	var art: Dictionary = GameState.dungeon.visual
	var span: Array = layout.walkable.front()
	var unit: float = GameState.rules.movement.cell_size
	var width: float = (span[int(GameState.rules.n.two)] - span.front() + GameState.rules.n.one) * unit
	var depth: float = (span.back() - span[int(GameState.rules.n.one)] + GameState.rules.n.one) * unit
	var center := GameState.ground(Vector2i(GameState.rules.n.zero, GameState.rules.n.zero))
	center.z = (span.back() + span[int(GameState.rules.n.one)]) * unit * GameState.rules.n.half
	v.shape(self, "box", Vector3(width, art.floor_height, depth), center + Vector3.UP * art.floor_y, art.floor_color)
	# Boundary walls remain low enough for the overhead camera to see every corridor.
	for side in [GameState.rules.n.negative_one, GameState.rules.n.one]:
		v.shape(self, "box", Vector3(art.wall_thickness, art.wall_height, depth), center + Vector3(side * width * GameState.rules.n.half, art.wall_height * GameState.rules.n.half, GameState.rules.n.zero), art.wall_color)
		v.shape(self, "box", Vector3(width, art.wall_height, art.wall_thickness), center + Vector3(GameState.rules.n.zero, art.wall_height * GameState.rules.n.half, side * depth * GameState.rules.n.half), art.wall_color)
	for rect in layout.blocked:
		var size := Vector3((rect[int(GameState.rules.n.two)] - rect.front() + GameState.rules.n.one) * unit, art.wall_height, (rect.back() - rect[int(GameState.rules.n.one)] + GameState.rules.n.one) * unit)
		var pos := Vector3((rect.front() + rect[int(GameState.rules.n.two)]) * unit * GameState.rules.n.half, art.wall_height * GameState.rules.n.half, (rect[int(GameState.rules.n.one)] + rect.back()) * unit * GameState.rules.n.half)
		v.shape(self, "box", size, pos, art.wall_color)
	for at in layout.columns:
		var group := _group_at(GameState.ground(GameState.cell(at)), "RuinedColumn")
		v.shape(group, "cylinder", GameState.vec(art.column_size), GameState.vec(art.column_pos), art.column_color)
		v.shape(group, "box", GameState.vec(art.column_base_size), GameState.vec(art.column_base_pos), art.edge_color)
	for at in art.braziers:
		v.assembly(_group_at(GameState.ground(GameState.cell(at)), "Brazier"), art.brazier_parts)
	for stair in layout.stairs:
		var group := _group_at(GameState.ground(GameState.cell(stair.cell)), "Staircase")
		v.assembly(group, art.stair_parts)
		v.label(group, stair.text, Vector3.UP * art.label_height, art.sign_size)
	v.assembly(self, art.first_parts if location_id == "chaos_1" else art.second_parts)
	if location_id == "chaos_1":
		v.label(self, "ВЫХОД В КОРНЕЛИЮ ↓", GameState.ground(GameState.cell(layout.portals.front().cell)) + Vector3.UP * art.label_height, art.sign_size)

func refresh_progress() -> void:
	if location_id == "chaos_1":
		var door_at := GameState.cell(GameState.dungeon.door.cell)
		door_node.visible = not GameState.session.quest.door_open
		if GameState.session.quest.door_open:
			cells[door_at] = true
		else:
			cells.erase(door_at)
		chest_lid.rotation_degrees.x = GameState.dungeon.chest.lid_rotation if GameState.session.quest.key_taken else GameState.rules.n.zero
	else:
		for npc in npcs:
			if npc.id == "garland":
				npc.node.visible = not GameState.session.quest.garland_defeated
				if GameState.session.quest.garland_defeated:
					cells[GameState.cell(npc.cell)] = true
		for npc in npcs:
			if npc.node.visible:
				cells.erase(GameState.cell(npc.cell))

func npc_near(at: Vector2i, facing: Vector2i) -> Dictionary:
	var result: Dictionary = super.npc_near(at, facing)
	if result.get("id", "") == "garland" and GameState.session.quest.garland_defeated:
		return {}
	return result

func action_near(at: Vector2i, facing: Vector2i) -> Dictionary:
	if location_id != "chaos_1":
		return {}
	var fallback: Dictionary = {}
	for kind in ["chest", "door"]:
		if kind == "door" and GameState.session.quest.door_open:
			continue
		var spec: Dictionary = GameState.dungeon[kind]
		var offset: Vector2i = GameState.cell(spec.cell) - at
		if absi(offset.x) + absi(offset.y) <= GameState.rules.movement.interact_distance:
			var result := {"kind":kind, "name":spec.name, "role":spec.role, "id":kind}
			if offset == facing:
				return result
			fallback = result
	return fallback

func boss_at(at: Vector2i) -> bool:
	return location_id == "chaos_2" and not GameState.session.quest.garland_defeated and GameState.inside(at, GameState.dungeon.boss.trigger)

func release_sarah() -> void:
	refresh_progress()
	for npc in npcs:
		if npc.id != "sarah":
			continue
		cells[GameState.cell(npc.cell)] = true
		npc.cell = GameState.dungeon.sarah.rescue_cell.duplicate()
		cells.erase(GameState.cell(npc.cell))
		var seconds: float = GameState.dungeon.story.test_seconds if get_parent().testing else GameState.dungeon.story.travel_seconds
		var tween := create_tween()
		tween.tween_property(npc.node, "position", GameState.ground(GameState.cell(npc.cell)), seconds)
		await tween.finished
