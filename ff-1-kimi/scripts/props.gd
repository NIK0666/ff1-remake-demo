extends "res://scripts/visuals.gd"

var props: Dictionary


func _init(config: Dictionary) -> void:
	super(config)
	props = geometry.props


func _sides() -> Array:
	return [math.zero - math.one, math.one]


func outer_ground(parent: Node3D, rect: Dictionary) -> void:
	var info: Dictionary = rectangle(rect)
	var depth: float = float(geometry.ground_depth)
	var drop: float = float(props.outer_drop)
	box(parent, info.center - Vector3.UP * (depth * math.half + drop * math.double), Vector3(info.width, depth, info.depth), "soil")
	plane(parent, info.center - Vector3.UP * drop, info.width, info.depth, "grass")


func forest(parent: Node3D, areas: Array, clear: Array, count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tones: Array = ["leaf", "leaf_dark", "leaf_light"]
	var placed: int = int(math.zero)
	var attempts: int = int(math.zero)
	while placed < count and attempts < count * int(props.forest_attempts):
		attempts += int(math.one)
		var area: Dictionary = areas[rng.randi_range(int(math.zero), areas.size() - int(math.one))]
		var first: Vector2i = cell(area.from)
		var last: Vector2i = cell(area.to)
		var point := Vector2i(rng.randi_range(first.x, last.x), rng.randi_range(first.y, last.y))
		var blocked: bool = false
		for rect in clear:
			var low: Vector2i = cell(rect.from)
			var high: Vector2i = cell(rect.to)
			if point.x >= low.x and point.x <= high.x and point.y >= low.y and point.y <= high.y:
				blocked = true
		if blocked:
			continue
		tree(parent, point, rng.randf_range(float(props.forest_min_scale), float(props.forest_max_scale)), str(tones[rng.randi_range(int(math.zero), tones.size() - int(math.one))]))
		placed += int(math.one)


func mountain(parent: Node3D, definition: Dictionary) -> void:
	var root: Node3D = group(parent, "Mountain", at(cell(definition.cell), math.zero))
	var radius: float = float(definition.radius)
	var height: float = float(definition.height)
	tapered(root, Vector3.UP * height * math.half, radius, height, "stone_dark", math.zero)
	tapered(root, Vector3.UP * height * (math.one - float(props.snow_ratio) * math.half), radius * float(props.snow_ratio), height * float(props.snow_ratio), "linen", math.zero)
	tapered(root, Vector3(radius * math.half, height * math.quarter, radius * math.quarter), radius * math.half, height * math.half, "stone", math.zero)


func lamp_post(parent: Node3D, position_cell: Vector2i) -> void:
	var p: Dictionary = props.lamp
	var root: Node3D = group(parent, "Lamp", at(position_cell, math.zero))
	cylinder(root, Vector3.UP * float(p.base_height) * math.half, p.base_radius, p.base_height, "stone_dark")
	cylinder(root, Vector3.UP * float(p.height) * math.half, p.pole_radius, p.height, "iron")
	var head: Vector3 = Vector3.UP * float(p.height)
	box(root, head, Vector3.ONE * float(p.lantern), "window")
	box(root, head + Vector3.UP * float(p.lantern) * math.half, Vector3(float(p.lantern) * float(p.cap_ratio), float(p.lantern) * math.quarter, float(p.lantern) * float(p.cap_ratio)), "iron")
	omni(root, head, "window", p.light_energy, p.light_range)


func stall(parent: Node3D, definition: Dictionary) -> void:
	var p: Dictionary = props.stall
	var info: Dictionary = rectangle(definition.rect)
	var root: Node3D = group(parent, "Stall", info.center)
	var width: float = float(info.width) * float(p.width_ratio)
	var depth: float = float(p.depth)
	box(root, Vector3.UP * float(p.counter_height) * math.half, Vector3(width, p.counter_height, depth), "wood")
	box(root, Vector3.UP * float(p.counter_height), Vector3(width + float(p.trim), p.trim, depth + float(p.trim)), "wood_light")
	for x in _sides():
		for z in _sides():
			cylinder(root, Vector3(x * width * math.half, float(p.post_height) * math.half, z * depth * math.half), p.post_radius, p.post_height, "wood_dark")
	var stripes: int = int(p.stripes)
	for index in range(stripes):
		var stripe_width: float = (width + float(p.overhang)) / float(stripes)
		var x: float = -(width + float(p.overhang)) * math.half + stripe_width * (float(index) + math.half)
		var stripe: MeshInstance3D = box(root, Vector3(x, float(p.post_height), math.zero), Vector3(stripe_width, p.trim, depth + float(p.overhang)), str(definition.awning) if index % int(math.double) == int(math.zero) else "linen")
		stripe.rotation.x = float(p.awning_tilt)
	var goods: Array = definition.goods
	for index in range(int(p.goods_count)):
		var x: float = -width * math.half + width * (float(index) + math.half) / float(p.goods_count)
		sphere(root, Vector3(x, float(p.counter_height) + float(p.good_radius), math.zero), p.good_radius, float(p.good_radius) * math.double, str(goods[index % goods.size()]))
	crate(root, Vector3(width * math.half + float(p.crate_offset), math.zero, depth * math.quarter))
	if definition.has("keeper"):
		var keeper: Node3D = character(root, str(definition.keeper))
		keeper.position = Vector3(math.zero, math.zero, -depth)
		keeper.rotation.y = math.zero


func crate(parent: Node3D, position_value: Vector3) -> void:
	var size: float = float(props.crate)
	var instance: MeshInstance3D = box(parent, position_value + Vector3.UP * size * math.half, Vector3.ONE * size, "wood_light")
	instance.rotation.y = float(props.crate_turn)
	var band: MeshInstance3D = box(parent, position_value + Vector3.UP * size * math.half, Vector3(size + float(props.band), float(props.band), size + float(props.band)), "wood_dark")
	band.rotation.y = float(props.crate_turn)


func barrel(parent: Node3D, position_value: Vector3) -> void:
	var radius: float = float(props.barrel_radius)
	var height: float = float(props.barrel_height)
	cylinder(parent, position_value + Vector3.UP * height * math.half, radius, height, "wood")
	for ratio in [math.quarter, math.one - math.quarter]:
		cylinder(parent, position_value + Vector3.UP * height * ratio, radius + float(props.band) * math.half, props.band, "iron")


func sack(parent: Node3D, position_value: Vector3) -> void:
	var radius: float = float(props.sack_radius)
	sphere(parent, position_value + Vector3.UP * radius, radius, radius * float(props.sack_height), "villager_apron")


func well(parent: Node3D, position_cell: Vector2i) -> void:
	var p: Dictionary = props.well
	var root: Node3D = group(parent, "Well", at(position_cell, math.zero))
	cylinder(root, Vector3.UP * float(p.wall_height) * math.half, p.radius, p.wall_height, "stone")
	cylinder(root, Vector3.UP * float(p.wall_height), float(p.radius) - float(p.wall_thickness), geometry.path_height, "fountain_water")
	torus(root, Vector3.UP * float(p.wall_height), float(p.radius) - float(p.wall_thickness), p.radius, "stone_light")
	for side in _sides():
		box(root, Vector3(side * float(p.radius), float(p.post_height) * math.half, math.zero), Vector3(p.post, p.post_height, p.post), "wood_dark")
	var roof: MeshInstance3D = prism(root, Vector3.UP * (float(p.post_height) + float(p.roof_height) * math.half), Vector3(float(p.radius) * float(p.roof_ratio), p.roof_height, float(p.radius) * float(p.roof_ratio)), "roof_red")
	roof.rotation.y = deg_to_rad(float(math.right_angle))
	cylinder(root, Vector3.UP * float(p.wall_height) * float(p.bucket_ratio), p.bucket, p.bucket, "wood")


func hedge(parent: Node3D, rect: Dictionary) -> void:
	var p: Dictionary = props.hedge
	var info: Dictionary = rectangle(rect)
	var root: Node3D = group(parent, "Hedge", info.center)
	box(root, Vector3.UP * float(p.height) * math.half, Vector3(float(info.width) - float(p.inset), p.height, float(info.depth) - float(p.inset)), "leaf_dark")
	var count: int = maxi(int(math.one), int(float(info.width) / float(p.bump_spacing)))
	for index in range(count):
		var x: float = -float(info.width) * math.half + float(info.width) * (float(index) + math.half) / float(count)
		sphere(root, Vector3(x, p.height, math.zero), p.bump_radius, float(p.bump_radius) * float(p.bump_flatten), "leaf")
		sphere(root, Vector3(x, float(p.height) + float(p.bump_radius) * math.half, float(p.bump_radius) * math.half), geometry.flower_radius, geometry.flower_radius, "flower_pink" if index % int(math.double) == int(math.zero) else "flower_white")


func flowerbed(parent: Node3D, rect: Dictionary) -> void:
	var p: Dictionary = props.flowerbed
	var info: Dictionary = rectangle(rect)
	var root: Node3D = group(parent, "Flowerbed", info.center)
	box(root, Vector3.UP * float(p.height) * math.half, Vector3(float(info.width) - float(p.inset), p.height, float(info.depth) - float(p.inset)), "stone_light")
	box(root, Vector3.UP * float(p.height), Vector3(float(info.width) - float(p.inset) * math.double, p.soil, float(info.depth) - float(p.inset) * math.double), "soil")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(info.center.x * float(math.percent)) + int(info.center.z)
	var colors: Array = ["flower_pink", "flower_yellow", "flower_white", "banner"]
	for index in range(int(p.flowers)):
		var x: float = rng.randf_range(-float(info.width) * math.half + float(p.inset), float(info.width) * math.half - float(p.inset))
		var z: float = rng.randf_range(-float(info.depth) * math.half + float(p.inset), float(info.depth) * math.half - float(p.inset))
		cylinder(root, Vector3(x, float(p.height) + float(p.stem) * math.half, z), geometry.grass_width, p.stem, "leaf")
		sphere(root, Vector3(x, float(p.height) + float(p.stem), z), p.flower_radius, p.flower_radius, str(colors[index % colors.size()]))


func bunting(parent: Node3D, definition: Dictionary) -> void:
	var p: Dictionary = props.bunting
	var start: Vector3 = at(cell(definition.from), p.height)
	var finish: Vector3 = at(cell(definition.to), p.height)
	rod(parent, start, finish, p.rope, "wood_dark")
	var length: float = start.distance_to(finish)
	var count: int = int(length / float(p.spacing))
	var colors: Array = definition.colors
	for index in range(count):
		var point: Vector3 = start.lerp(finish, (float(index) + math.half) / float(count))
		var flag: MeshInstance3D = prism(parent, point - Vector3.UP * float(p.flag_height) * math.half, Vector3(p.flag_width, p.flag_height, p.rope), str(colors[index % colors.size()]))
		flag.rotation = Vector3(PI, -atan2(finish.z - start.z, finish.x - start.x), math.zero)


func reeds(parent: Node3D, position_cell: Vector2i) -> void:
	var p: Dictionary = props.reeds
	var root: Node3D = group(parent, "Reeds", at(position_cell, float(geometry.water_level)))
	var rng := RandomNumberGenerator.new()
	rng.seed = position_cell.x * int(p.count) + position_cell.y
	for index in range(int(p.count)):
		var height: float = rng.randf_range(float(p.min_height), float(p.max_height))
		var stem: MeshInstance3D = cylinder(root, Vector3(rng.randf_range(-float(p.spread), float(p.spread)), height * math.half, rng.randf_range(-float(p.spread), float(p.spread))), p.radius, height, "leaf_light" if index % int(math.double) == int(math.zero) else "leaf")
		stem.rotation.z = rng.randf_range(-float(p.tilt), float(p.tilt))


func fireplace(parent: Node3D, position_value: Vector3) -> void:
	var p: Dictionary = props.fireplace
	var root: Node3D = group(parent, "Fireplace", position_value)
	var body: Vector3 = vector(p.body)
	box(root, Vector3.UP * body.y * math.half, body, "stone")
	var opening: Vector3 = vector(p.opening)
	box(root, Vector3(math.zero, opening.y * math.half, body.z * math.half - opening.z * math.half), opening, "void")
	box(root, Vector3(math.zero, body.y, math.zero), Vector3(body.x + float(p.mantle), p.mantle, body.z + float(p.mantle)), "wood_dark")
	box(root, Vector3(math.zero, body.y + float(p.chimney_height) * math.half, -body.z * math.quarter), Vector3(body.x * math.half, p.chimney_height, body.z * math.half), "stone")
	for index in range(int(p.flames)):
		var x: float = (float(index) - float(int(p.flames) - int(math.one)) * math.half) * float(p.flame_spacing)
		unshadowed(sphere(root, Vector3(x, float(p.flame_radius), body.z * math.half - opening.z * math.half), p.flame_radius, float(p.flame_radius) * float(p.flame_stretch), "torch_flame"))
	omni(root, Vector3(math.zero, opening.y, body.z), "torch_light", p.light_energy, p.light_range)


func weapon_rack(parent: Node3D, position_value: Vector3) -> void:
	var p: Dictionary = props.rack
	var root: Node3D = group(parent, "WeaponRack", position_value)
	var size: Vector3 = vector(p.frame)
	for side in _sides():
		box(root, Vector3(side * size.x * math.half, size.y * math.half, math.zero), Vector3(p.post, size.y, p.post), "wood_dark")
	for ratio in [float(p.low_bar), float(p.high_bar)]:
		box(root, Vector3(math.zero, size.y * ratio, math.zero), Vector3(size.x, p.post, p.post), "wood")
	var count: int = int(p.weapons)
	for index in range(count):
		var x: float = -size.x * math.half + size.x * (float(index) + math.half) / float(count)
		if index % int(math.double) == int(math.zero):
			box(root, Vector3(x, size.y * math.half, size.z * math.quarter), Vector3(p.blade_width, size.y * float(p.blade_ratio), p.post * math.half), "silver")
			box(root, Vector3(x, size.y * (math.half - float(p.blade_ratio) * math.half), size.z * math.quarter), Vector3(float(p.blade_width) * float(p.guard_ratio), p.post * math.half, p.post * math.half), "gold")
		else:
			rod(root, Vector3(x, math.zero, size.z * math.quarter), Vector3(x, size.y * float(p.spear_ratio), size.z * math.quarter), float(p.post) * math.quarter, "wood_light")
			tapered(root, Vector3(x, size.y * float(p.spear_ratio), size.z * math.quarter), float(p.blade_width) * math.half, p.spear_tip, "silver", math.zero)


func armor_stand(parent: Node3D, position_value: Vector3, color_name: String) -> void:
	var p: Dictionary = props.mannequin
	var root: Node3D = group(parent, "ArmorStand", position_value)
	cylinder(root, Vector3.UP * float(p.base_height) * math.half, p.base_radius, p.base_height, "wood_dark")
	cylinder(root, Vector3.UP * float(p.height) * math.half, p.pole, p.height, "wood")
	tapered(root, Vector3.UP * float(p.torso_y), p.torso_radius, p.torso_height, color_name, geometry.character.body_top_ratio)
	for side in _sides():
		sphere(root, Vector3(side * float(p.torso_radius), float(p.torso_y) + float(p.torso_height) * math.half, math.zero), p.shoulder, float(p.shoulder) * math.double, color_name)
	sphere(root, Vector3.UP * (float(p.torso_y) + float(p.torso_height) * math.half + float(p.helmet)), p.helmet, float(p.helmet) * float(p.helmet_stretch), color_name)
	var shield: MeshInstance3D = cylinder(root, Vector3(float(p.torso_radius) * math.double, float(p.torso_y), float(p.torso_radius) * math.half), p.shield, p.pole, "royal")
	shield.rotation.z = deg_to_rad(float(math.right_angle))


func potion_shelf(parent: Node3D, position_value: Vector3, width: float) -> void:
	var p: Dictionary = props.potions
	var root: Node3D = group(parent, "PotionShelf", position_value)
	var height: float = float(p.height)
	var depth: float = float(p.depth)
	box(root, Vector3(math.zero, height * math.half, -depth * math.half), Vector3(width, height, p.board), "wood_dark")
	var colors: Array = p.colors
	var levels: int = int(p.levels)
	for level in range(levels):
		var y: float = height * (float(level) + math.half) / float(levels)
		box(root, Vector3(math.zero, y, math.zero), Vector3(width, p.board, depth), "wood_light")
		for index in range(int(p.per_level)):
			var x: float = -width * math.half + width * (float(index) + math.half) / float(p.per_level)
			var color_name: String = str(colors[(index + level) % colors.size()])
			cylinder(root, Vector3(x, y + float(p.bottle) * math.half + float(p.board), math.zero), float(p.bottle) * math.quarter, p.bottle, color_name)
			sphere(root, Vector3(x, y + float(p.bottle) + float(p.board), math.zero), float(p.bottle) * math.quarter, float(p.bottle) * math.quarter, "linen")


func herbs(parent: Node3D, position_value: Vector3, width: float) -> void:
	var p: Dictionary = props.herbs
	var root: Node3D = group(parent, "Herbs", position_value)
	rod(root, Vector3(-width * math.half, p.height, math.zero), Vector3(width * math.half, p.height, math.zero), p.rod, "wood_dark")
	for index in range(int(p.bundles)):
		var x: float = -width * math.half + width * (float(index) + math.half) / float(p.bundles)
		var bundle: MeshInstance3D = tapered(root, Vector3(x, float(p.height) - float(p.bundle_height) * math.half, math.zero), p.bundle_radius, p.bundle_height, "leaf" if index % int(math.double) == int(math.zero) else "grass_light", math.zero)
		bundle.rotation.x = PI


func anvil(parent: Node3D, position_value: Vector3) -> void:
	var p: Dictionary = props.anvil
	var root: Node3D = group(parent, "Anvil", position_value)
	var stump: Vector3 = vector(p.stump)
	cylinder(root, Vector3.UP * stump.y * math.half, stump.x, stump.y, "wood")
	var top: Vector3 = vector(p.top)
	box(root, Vector3.UP * (stump.y + top.y * math.half), top, "iron")
	var horn: MeshInstance3D = tapered(root, Vector3(top.x * math.half + float(p.horn) * math.half, stump.y + top.y * math.half, math.zero), top.y * math.half, p.horn, "iron", math.zero)
	horn.rotation.z = deg_to_rad(-float(math.right_angle))


func table_lamp(parent: Node3D, position_value: Vector3) -> void:
	var p: Dictionary = props.lantern
	box(parent, position_value + Vector3.UP * float(p.size) * math.half, Vector3.ONE * float(p.size), "window")
	box(parent, position_value + Vector3.UP * float(p.size), Vector3(float(p.size) * float(p.cap_ratio), float(p.size) * math.quarter, float(p.size) * float(p.cap_ratio)), "iron")
	omni(parent, position_value + Vector3.UP * float(p.light_y), "window", p.light_energy, p.light_range)


func stained_window(parent: Node3D, position_value: Vector3) -> void:
	var p: Dictionary = props.stained
	var root: Node3D = group(parent, "StainedWindow", position_value)
	var size: Vector3 = vector(p.size)
	box(root, Vector3.ZERO, size + Vector3(float(p.frame), float(p.frame), math.zero), "stone_light")
	var columns: int = int(p.columns)
	var rows: int = int(p.rows)
	var colors: Array = p.colors
	for column in range(columns):
		for row in range(rows):
			var pane := Vector3(size.x / float(columns), size.y / float(rows), size.z)
			var x: float = -size.x * math.half + pane.x * (float(column) + math.half)
			var y: float = -size.y * math.half + pane.y * (float(row) + math.half)
			unshadowed(box(root, Vector3(x, y, size.z), pane - Vector3(float(p.lead), float(p.lead), math.zero), str(colors[(column + row * columns) % colors.size()])))
	prism(root, Vector3(math.zero, size.y * math.half + float(p.arch) * math.half, math.zero), Vector3(size.x + float(p.frame), p.arch, size.z), "stone_light")


func candelabra(parent: Node3D, position_cell: Vector2i) -> void:
	var p: Dictionary = props.candelabra
	var root: Node3D = group(parent, "Candelabra", at(position_cell, math.zero))
	cylinder(root, Vector3.UP * float(p.base) * math.half, p.base, p.base, "gold")
	cylinder(root, Vector3.UP * float(p.height) * math.half, p.pole, p.height, "gold")
	box(root, Vector3.UP * float(p.height), Vector3(p.span, p.pole, p.pole), "gold")
	for x in [-float(p.span) * math.half, math.zero, float(p.span) * math.half]:
		candle(root, Vector3(x, float(p.height), math.zero))
	omni(root, Vector3.UP * (float(p.height) + float(p.light_y)), "torch_light", p.light_energy, p.light_range)


func crest(parent: Node3D, position_value: Vector3) -> void:
	var p: Dictionary = props.crest
	unshadowed(cylinder(parent, position_value + Vector3.UP * float(p.height), p.radius, p.height, "royal"))
	var ring: MeshInstance3D = unshadowed(torus(parent, position_value + Vector3.UP * float(p.height) * math.double, float(p.radius) - float(p.ring), p.radius, "gold"))
	ring.scale.y = float(p.flatten)
	unshadowed(cylinder(parent, position_value + Vector3.UP * float(p.height) * float(math.double + math.one), p.core, p.height, "gold"))


func signpost(parent: Node3D, position_cell: Vector2i, label_text: String) -> void:
	var p: Dictionary = props.signpost
	var root: Node3D = group(parent, "Signpost", at(position_cell, math.zero))
	box(root, Vector3.UP * float(p.height) * math.half, Vector3(p.post, p.height, p.post), "wood_dark")
	var board: Vector3 = vector(p.board)
	box(root, Vector3(board.x * math.quarter, float(p.height) - board.y, math.zero), board, "wood_light")
	var sign := Label3D.new()
	sign.text = label_text
	sign.font_size = int(p.font_size)
	sign.pixel_size = float(p.pixel_size)
	sign.outline_size = int(geometry.house.sign_outline_size)
	sign.modulate = color("linen")
	sign.outline_modulate = color("wood_dark")
	sign.position = Vector3(board.x * math.quarter, float(p.height) - board.y, board.z)
	root.add_child(sign)


func tent(parent: Node3D, position_cell: Vector2i, color_name: String) -> void:
	var p: Dictionary = props.tent
	var root: Node3D = group(parent, "Tent", at(position_cell, math.zero))
	var size: Vector3 = vector(p.size)
	prism(root, Vector3.UP * size.y * math.half, size, color_name)
	box(root, Vector3(math.zero, size.y * math.quarter, size.z * math.half), Vector3(size.x * math.quarter, size.y * math.half, p.door), "wood_dark")


func plank_stack(parent: Node3D, position_cell: Vector2i) -> void:
	var p: Dictionary = props.planks
	var root: Node3D = group(parent, "PlankStack", at(position_cell, math.zero))
	var plank: Vector3 = vector(p.plank)
	for level in range(int(p.levels)):
		for index in range(int(p.per_level)):
			var x: float = (float(index) - float(int(p.per_level) - int(math.one)) * math.half) * plank.x * float(p.spacing)
			var piece: MeshInstance3D = box(root, Vector3(x, plank.y * (float(level) + math.half), math.zero), plank, "wood_light" if (index + level) % int(math.double) == int(math.zero) else "wood")
			piece.rotation.y = float(p.turn) * float(level % int(math.double))


func furniture(parent: Node3D, definition: Dictionary, location: Dictionary) -> void:
	var info: Dictionary = rectangle(definition.rect)
	var base: Vector3 = info.center
	match str(definition.type):
		"fireplace":
			fireplace(parent, Vector3(base.x, math.zero, float(info.min_z) - float(props.fireplace.wall_offset) + float(props.fireplace.body[int(math.double)]) * math.half))
		"weapon_rack":
			weapon_rack(parent, base)
		"armor_stand":
			armor_stand(parent, base, str(definition.get("color", "silver")))
		"potion_shelf":
			potion_shelf(parent, base, float(info.width) * float(props.potions.width_ratio))
		"herbs":
			herbs(parent, base, float(info.width))
		"anvil":
			anvil(parent, base)
		"barrel":
			barrel(parent, base)
		"crate":
			crate(parent, base)
		"sack":
			sack(parent, base)
		"lamp":
			table_lamp(parent, base + Vector3.UP * float(definition.get("height", math.zero)))
		"keeper":
			var keeper: Node3D = character(parent, str(definition.kind))
			keeper.position = base
		_:
			super(parent, definition, location)
