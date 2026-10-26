extends Node3D

signal finished(outcome: String)

const BattleUIScript = preload("res://scripts/battle_ui.gd")
const BattleFxScript = preload("res://scripts/battle_fx.gd")

var data: Dictionary
var math: Dictionary
var visuals
var party
var ui
var fx
var effects: Dictionary
var text: Dictionary
var encounter: Dictionary = {}
var group: Array = []
var enemies: Array = []
var hero_models: Array = []
var enemy_models: Array = []
var enemy_labels: Array = []
var hero_homes: Array = []
var enemy_homes: Array = []
var rng := RandomNumberGenerator.new()
var order: Array = []
var turn_index: int = 0
var round_number: int = 0
var active_side: String = ""
var active_index: int = -1
var pending: String = ""
var selected_spell: String = ""
var selected_item: String = ""
var outcome: String = ""
var busy: bool = false


func _init(config: Dictionary = {}, factory = null, party_state = null) -> void:
	if not config.is_empty():
		data = config
		visuals = factory
		party = party_state


func _ready() -> void:
	name = "Battle"
	math = data.settings.math
	effects = data.battle.effects
	text = data.battle.text
	rng.seed = int(data.battle.random_seed) + int(party.state.heroes.front().experience)
	fx = BattleFxScript.new(data, visuals)
	add_child(fx)
	_build_arena()
	_build_actors()
	ui = BattleUIScript.new(data)
	add_child(ui)
	ui.command_selected.connect(_on_command)
	ui.target_selected.connect(_on_target)
	ui.target_focused.connect(_on_target_focused)
	ui.spell_selected.connect(_on_spell)
	ui.item_selected.connect(_on_item)
	ui.continue_selected.connect(func() -> void: finished.emit(outcome))
	_refresh()
	_start_round()


func _hero_names() -> Array:
	return data.party.heroes.map(func(hero: Dictionary) -> String: return str(hero.name))


func _refresh() -> void:
	ui.refresh(party, _hero_names(), active_index if active_side == "hero" and not busy else -int(math.one))
	ui.refresh_enemies(enemies)


func _commands() -> Array:
	var result: Array = ["attack"]
	if active_side == "hero" and active_index >= int(math.zero) and party.is_caster(active_index):
		result.append("spell")
	result.append("item")
	if bool(encounter.flee):
		result.append("flee")
	return result


func _build_arena() -> void:
	if str(encounter.arena) == "bridge":
		_build_bridge_arena()
	else:
		_build_shrine_arena(data.battle.arenas[str(encounter.arena)])
	var camera := Camera3D.new()
	camera.name = "BattleCamera"
	camera.fov = float(data.battle.camera_fov)
	camera.near = float(data.settings.camera.near)
	camera.far = float(data.settings.camera.far)
	add_child(camera)
	camera.position = visuals.vector(data.battle.camera_target) + visuals.vector(data.battle.camera_offset)
	camera.look_at(visuals.vector(data.battle.camera_target), Vector3.UP)
	camera.current = true


func _build_bridge_arena() -> void:
	var g: Dictionary = data.settings.geometry
	var scenery: Dictionary = data.battle.bridge_scenery
	var river: Dictionary = visuals.rectangle(data.battle.river)
	visuals.box(self, river.center - Vector3.UP * (float(g.riverbed_depth) + float(g.ground_depth) * math.half), Vector3(river.width, g.ground_depth, river.depth), "riverbed")
	visuals.plane(self, river.center + Vector3.UP * float(g.water_level), river.width, river.depth, "water")
	visuals.bridge(self, data.battle.bridge)
	for rect in scenery.banks:
		var info: Dictionary = visuals.rectangle(rect)
		visuals.box(self, info.center - Vector3.UP * float(g.ground_depth) * math.half, Vector3(info.width, g.ground_depth, info.depth), "soil")
		visuals.plane(self, info.center + Vector3.UP * float(g.path_height) * math.half, info.width, info.depth, "grass")
		visuals.scatter_grass(self, rect, func(point: Vector2i) -> bool: return true)
	for tree in scenery.trees:
		visuals.tree(self, visuals.cell(tree.cell), tree.scale, tree.tone)
	for point in scenery.rocks:
		visuals.rock(self, visuals.cell(point))
	for glint in scenery.glints:
		visuals.plane(self, visuals.at(visuals.cell(glint.cell), float(g.water_level) + float(g.path_height)), glint.length, g.path_border_width, "water_glint")


func _build_shrine_arena(arena: Dictionary) -> void:
	var d: Dictionary = data.settings.geometry.dungeon
	var tile: float = float(data.settings.tile_size)
	var info: Dictionary = visuals.rectangle(arena.floor)
	visuals.box(self, info.center - Vector3.UP * float(d.floor_depth) * math.half, Vector3(info.width, d.floor_depth, info.depth), "shrine_floor")
	visuals.flagstones(self, arena.floor, "shrine_floor_light", int(data.battle.random_seed))
	var wall_from: Vector2i = visuals.cell(arena.back_wall.from)
	var wall_to: Vector2i = visuals.cell(arena.back_wall.to)
	var decor_rng := RandomNumberGenerator.new()
	decor_rng.seed = int(data.battle.random_seed)
	visuals.dungeon_wall(self, wall_from, wall_to, float(d.wall_height))
	visuals.wall_face(self, (float(wall_from.x) - math.half) * tile, (float(wall_to.x) + math.half) * tile, (float(wall_from.y) + math.half) * tile, decor_rng)
	for point in arena.pillars:
		visuals.pillar(self, visuals.cell(point), false)
	for point in arena.broken_pillars:
		visuals.pillar(self, visuals.cell(point), true)
	for point in arena.torches:
		visuals.torch(self, visuals.cell(point))
	for point in arena.braziers:
		visuals.brazier(self, visuals.cell(point))
	for point in arena.runes:
		visuals.runes(self, visuals.cell(point))
	for point in arena.bones:
		visuals.bones(self, visuals.cell(point))
	visuals.omni(self, visuals.vector(arena.light.position), "exit_light", arena.light.energy, arena.light.range)


func _build_actors() -> void:
	for index in range(party.state.heroes.size()):
		var hero: Dictionary = party.state.heroes[index]
		var cells: Array = data.battle.hero_back if str(hero.row) == "back" else data.battle.hero_front
		var model: Node3D = visuals.character(self, str(hero.id))
		var home: Vector3 = visuals.at(visuals.cell(cells[index]), math.zero)
		model.rotation.y = -PI * math.half
		hero_models.append(model)
		hero_homes.append(home)
		_pose(index, bool(hero.fallen))
	var cells: Array = encounter.get("enemy_cells", data.battle.enemy_cells)
	var totals: Dictionary = {}
	for enemy_id in group:
		totals[enemy_id] = int(totals.get(enemy_id, int(math.zero))) + int(math.one)
	var seen: Dictionary = {}
	for index in range(group.size()):
		var enemy_id: String = str(group[index])
		var definition: Dictionary = data.battle.bestiary[enemy_id]
		var enemy: Dictionary = definition.duplicate(true)
		enemy["hp"] = int(definition.max_hp)
		enemy["fallen"] = false
		if int(totals[enemy_id]) > int(math.one):
			enemy["name"] = "%s %s" % [str(definition.name), str(text.letters[int(seen.get(enemy_id, int(math.zero)))])]
			seen[enemy_id] = int(seen.get(enemy_id, int(math.zero))) + int(math.one)
		enemies.append(enemy)
		var model: Node3D = visuals.character(self, str(definition.model))
		model.position = visuals.at(visuals.cell(cells[index]), math.zero)
		model.rotation.y = PI * math.half
		if definition.has("scale"):
			model.scale = Vector3.ONE * float(definition.scale)
		enemy_models.append(model)
		enemy_homes.append(model.position)
		var label := Label3D.new()
		label.text = str(enemy.name)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = int(effects.name_size)
		label.pixel_size = float(effects.number_pixel)
		label.outline_size = int(effects.number_outline)
		label.modulate = visuals.color("linen")
		label.outline_modulate = visuals.color("shadow")
		label.position = model.position + Vector3.UP * float(effects.name_height) * model.scale.y
		add_child(label)
		enemy_labels.append(label)


func _pose(index: int, fallen: bool) -> void:
	var model: Node3D = hero_models[index]
	model.position = hero_homes[index] + (Vector3.UP * float(effects.fallen_lift) if fallen else Vector3.ZERO)
	model.rotation.z = float(effects.fallen_angle) if fallen else math.zero
	visuals.fade(model, float(data.settings.spirit_transparency) if fallen else math.zero)


func _model(hero_side: bool, index: int) -> Node3D:
	return hero_models[index] if hero_side else enemy_models[index]


func _home(hero_side: bool, index: int) -> Vector3:
	return hero_homes[index] if hero_side else enemy_homes[index]


func _living_enemies() -> Array:
	var result: Array = []
	for index in range(enemies.size()):
		if not bool(enemies[index].fallen):
			result.append(index)
	return result


func _living_heroes() -> Array:
	var result: Array = []
	for index in range(party.state.heroes.size()):
		if not bool(party.state.heroes[index].fallen):
			result.append(index)
	return result


func _start_round() -> void:
	round_number += int(math.one)
	turn_index = int(math.zero)
	order.clear()
	for index in range(party.state.heroes.size()):
		order.append({"side": "hero", "index": index, "agility": party.hero_stat(index, "agility"), "tie": index})
	for index in range(enemies.size()):
		order.append({"side": "enemy", "index": index, "agility": int(enemies[index].agility), "tie": index + party.state.heroes.size()})
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.agility) == int(b.agility):
			return int(a.tie) < int(b.tie)
		return int(a.agility) > int(b.agility)
	)
	_next_turn()


func _next_turn() -> void:
	if not outcome.is_empty():
		return
	if _living_enemies().is_empty():
		_finish("victory")
		return
	if _living_heroes().is_empty():
		_finish("defeat")
		return
	if turn_index >= order.size():
		_start_round()
		return
	var actor: Dictionary = order[turn_index]
	turn_index += int(math.one)
	active_side = str(actor.side)
	active_index = int(actor.index)
	var hero_side: bool = active_side == "hero"
	if (party.state.heroes[active_index].fallen if hero_side else enemies[active_index].fallen):
		_next_turn()
		return
	fx.mark_active(_model(hero_side, active_index))
	ui.set_turn(round_number, _actor_name(hero_side, active_index), str(encounter.title))
	_refresh()
	if hero_side:
		ui.show_commands(text, _commands(), _actor_name(true, active_index))
		return
	ui.hide_commands()
	busy = true
	await get_tree().create_timer(float(data.battle.action_delay)).timeout
	await _enemy_action()
	busy = false
	_refresh()
	await get_tree().create_timer(float(data.battle.action_delay)).timeout
	_next_turn()


func _actor_name(hero_side: bool, index: int) -> String:
	return str(data.party.heroes[index].name) if hero_side else str(enemies[index].name)


func _awaiting_input() -> bool:
	return active_side == "hero" and outcome.is_empty() and not busy


func _on_command(command: String) -> void:
	if not _awaiting_input():
		return
	pending = command
	match command:
		"attack":
			_show_enemy_targets()
		"spell":
			var entries: Array = []
			for spell_id in party.spells(active_index):
				var spell: Dictionary = data.battle.spells[spell_id]
				var charges: int = party.charge_count(active_index, int(spell.level))
				entries.append({"id": str(spell_id), "label": str(text.spell_entry) % [str(spell.name), str(text.levels[int(spell.level) - int(math.one)]), charges], "enabled": charges > int(math.zero)})
			ui.show_spells(str(text.choose_spell), entries)
		"item":
			var entries: Array = []
			for definition in party.usable_items():
				entries.append({"id": str(definition.id), "label": str(text.item_entry) % [str(definition.name), party.item_count(str(definition.id))], "enabled": _item_targets(str(definition.id)).size() > int(math.zero)})
			ui.show_items(str(text.choose_item), entries)
		"flee":
			if bool(encounter.flee):
				_execute("flee", -int(math.one))


func _show_enemy_targets() -> void:
	var entries: Array = []
	for index in _living_enemies():
		entries.append({"hero_side": false, "index": index, "label": str(enemies[index].name)})
	ui.show_targets(str(text.target_enemy), entries)


func _show_hero_targets(indices: Array) -> void:
	var entries: Array = []
	for index in indices:
		var hero: Dictionary = party.state.heroes[index]
		entries.append({"hero_side": true, "index": index, "label": str(text.ally_entry) % [_actor_name(true, index), int(hero.hp), int(hero.max_hp)]})
	ui.show_targets(str(text.target_ally), entries)


func _item_targets(item_id: String) -> Array:
	var result: Array = []
	for index in range(party.state.heroes.size()):
		if party.can_use_item(item_id, index):
			result.append(index)
	return result


func _on_spell(spell_id: String) -> void:
	if not _awaiting_input():
		return
	selected_spell = spell_id
	var target: String = str(data.battle.spells[spell_id].target)
	if target == "enemy":
		_show_enemy_targets()
	elif target == "enemies":
		_execute("spell", -int(math.one))
	elif target == "fallen":
		_show_hero_targets(range(party.state.heroes.size()).filter(func(index: int) -> bool: return bool(party.state.heroes[index].fallen)))
	else:
		_show_hero_targets(_living_heroes())


func _on_item(item_id: String) -> void:
	if not _awaiting_input():
		return
	selected_item = item_id
	_show_hero_targets(_item_targets(item_id))


func _on_target_focused(hero_side: bool, index: int) -> void:
	if _awaiting_input():
		fx.point(_model(hero_side, index))


func _on_target(hero_side: bool, index: int) -> void:
	if not _awaiting_input():
		return
	var wants_hero: bool = pending == "item" or (pending == "spell" and str(data.battle.spells[selected_spell].target) in ["ally", "fallen"])
	if hero_side != wants_hero:
		return
	_execute(pending, index)


func _execute(kind: String, target: int) -> void:
	busy = true
	ui.hide_commands()
	fx.clear_cursor()
	_refresh()
	match kind:
		"attack":
			await _attack(true, active_index, target)
		"spell":
			await _cast(target)
		"item":
			await _use_item(target)
		"flee":
			await _try_flee()
	busy = false
	_refresh()
	if not outcome.is_empty():
		return
	await get_tree().create_timer(float(data.battle.action_delay)).timeout
	_next_turn()


func _physical_damage(hero_attacker: bool, attacker_index: int, defender_index: int) -> int:
	var attacker: Dictionary = party.state.heroes[attacker_index] if hero_attacker else enemies[attacker_index]
	var defender: Dictionary = enemies[defender_index] if hero_attacker else party.state.heroes[defender_index]
	var attack: float = float(party.hero_stat(attacker_index, "attack")) if hero_attacker else float(attacker.attack)
	var defense: float = float(defender.defense) if hero_attacker else float(party.hero_stat(defender_index, "defense"))
	var formulas: Dictionary = data.battle.formulas
	var damage: float = maxf(float(formulas.minimum_damage), attack * float(formulas.attack_multiplier) - defense * float(formulas.defense_multiplier))
	damage *= rng.randf_range(float(formulas.variance_min), float(formulas.variance_max))
	damage *= float(formulas.back_damage_multiplier) if str(attacker.row) == "back" else float(formulas.front_damage_multiplier)
	damage *= float(formulas.back_melee_taken_multiplier) if str(defender.row) == "back" else float(formulas.front_taken_multiplier)
	return maxi(int(math.one), roundi(damage))


func _attack(hero_attacker: bool, attacker_index: int, defender_index: int) -> void:
	var model: Node3D = _model(hero_attacker, attacker_index)
	var target: Node3D = _model(not hero_attacker, defender_index)
	var home: Vector3 = _home(hero_attacker, attacker_index)
	ui.show_caption(str(text.attack_caption) % [_actor_name(hero_attacker, attacker_index), _actor_name(not hero_attacker, defender_index)])
	await fx.move(model, home.lerp(target.position, float(effects.lunge_ratio)), float(effects.lunge_time)).finished
	var dealt: int = _physical_damage(hero_attacker, attacker_index, defender_index)
	ui.add_log(str(text.physical) % [_actor_name(hero_attacker, attacker_index), _actor_name(not hero_attacker, defender_index), dealt])
	_damage(not hero_attacker, defender_index, dealt)
	await fx.move(model, home, float(effects.return_time)).finished


func _damage(hero_target: bool, index: int, amount: int) -> void:
	var target: Dictionary = party.state.heroes[index] if hero_target else enemies[index]
	var model: Node3D = _model(hero_target, index)
	target.hp = maxi(int(math.zero), int(target.hp) - amount)
	fx.float_text(model.position, str(amount), "number_hurt" if hero_target else "number_damage")
	if int(target.hp) > int(math.zero):
		fx.shake(model, _home(hero_target, index))
		fx.blink(model)
		_refresh()
		return
	target.fallen = true
	ui.add_log(str(text.fell) % _actor_name(hero_target, index))
	fx.float_text(model.position + Vector3.UP * float(effects.number_rise), str(text.fell_tag), "number_info")
	if hero_target:
		_pose(index, true)
	else:
		fx.vanish(model)
		enemy_labels[index].hide()
	_refresh()


func _heal(index: int, amount: int, color_name: String) -> void:
	var model: Node3D = hero_models[index]
	fx.sparkles(model.position, color_name)
	fx.float_text(model.position, str(text.heal_tag) % amount, "number_heal")


func _stand(index: int) -> void:
	_pose(index, false)
	fx.column(hero_models[index].position, "magic_white")
	fx.float_text(hero_models[index].position, str(text.revive_tag), "number_heal")


func _cast(target_index: int) -> void:
	var spell: Dictionary = data.battle.spells[selected_spell]
	if not party.spend_charge(active_index, int(spell.level)):
		ui.add_log(str(text.no_charges))
		return
	var caster: String = _actor_name(true, active_index)
	ui.show_caption(str(text.cast_caption) % [caster, str(spell.name)])
	await fx.hop(hero_models[active_index], hero_homes[active_index]).finished
	match str(spell.effect):
		"damage_all":
			for index in _living_enemies():
				fx.bolt(enemy_models[index].position)
				_spell_damage(caster, index, spell)
				await get_tree().create_timer(float(effects.chain_delay)).timeout
		"damage":
			fx.burst(enemy_models[target_index].position, "magic_fire")
			_spell_damage(caster, target_index, spell)
		"revive":
			var hero: Dictionary = party.state.heroes[target_index]
			hero.fallen = false
			hero.hp = maxi(int(math.one), roundi(float(hero.max_hp) * float(data.battle.formulas.revive_hp_ratio)))
			_stand(target_index)
			ui.add_log(str(text.revive) % [caster, _actor_name(true, target_index)])
		_:
			var hero: Dictionary = party.state.heroes[target_index]
			var amount: int = mini(int(hero.max_hp) - int(hero.hp), int(spell.power))
			hero.hp += amount
			_heal(target_index, amount, "magic_white")
			ui.add_log(str(text.heal) % [caster, _actor_name(true, target_index), amount])
	await get_tree().create_timer(float(effects.effect_time)).timeout


func _spell_damage(caster: String, target_index: int, spell: Dictionary) -> void:
	var amount: int = maxi(int(math.one), roundi(float(spell.power) * rng.randf_range(float(data.battle.formulas.variance_min), float(data.battle.formulas.variance_max))))
	ui.add_log(str(text.spell_damage) % [caster, str(spell.name), _actor_name(false, target_index), amount])
	_damage(false, target_index, amount)


func _use_item(target_index: int) -> void:
	var definition: Dictionary = party.item(selected_item)
	var user: String = _actor_name(true, active_index)
	ui.show_caption(str(text.item_caption) % [user, str(definition.name), _actor_name(true, target_index)])
	await fx.hop(hero_models[active_index], hero_homes[active_index]).finished
	var amount: int = party.use_item(selected_item, target_index)
	if amount < int(math.zero):
		return
	match str(definition.effect):
		"heal":
			_heal(target_index, amount, "magic_white")
		"revive":
			_stand(target_index)
		_:
			fx.sparkles(hero_models[target_index].position, "magic_lightning")
			fx.float_text(hero_models[target_index].position, str(text.charges_tag), "number_info")
	ui.add_log(str(text.item_used) % [user, str(definition.name), _actor_name(true, target_index)])
	await get_tree().create_timer(float(effects.effect_time)).timeout


func _enemy_action() -> void:
	var living: Array = _living_heroes()
	if living.is_empty():
		return
	var target: int = int(living[rng.randi_range(int(math.zero), living.size() - int(math.one))])
	var enemy: Dictionary = enemies[active_index]
	if not enemy.spells.is_empty() and int(enemy.charges.get("1", int(math.zero))) > int(math.zero):
		var spell: Dictionary = data.battle.spells[str(enemy.spells.front())]
		enemy.charges["1"] = int(enemy.charges["1"]) - int(math.one)
		ui.show_caption(str(text.cast_caption) % [str(enemy.name), str(spell.name)])
		await fx.hop(enemy_models[active_index], enemy_homes[active_index]).finished
		fx.burst(hero_models[target].position, "magic_fire")
		var amount: int = maxi(int(math.one), roundi(float(spell.power) * rng.randf_range(float(data.battle.formulas.variance_min), float(data.battle.formulas.variance_max))))
		ui.add_log(str(text.spell_damage) % [str(enemy.name), str(spell.name), _actor_name(true, target), amount])
		_damage(true, target, amount)
		await get_tree().create_timer(float(effects.effect_time)).timeout
	else:
		await _attack(false, active_index, target)


func _try_flee() -> void:
	var hero_agility: float = math.zero
	for index in _living_heroes():
		hero_agility += float(party.hero_stat(index, "agility"))
	hero_agility /= maxf(math.one, float(_living_heroes().size()))
	var enemy_agility: float = math.zero
	for index in _living_enemies():
		enemy_agility += float(enemies[index].agility)
	enemy_agility /= maxf(math.one, float(_living_enemies().size()))
	var formulas: Dictionary = data.battle.formulas
	var chance: float = clampf(float(formulas.flee_base) + (hero_agility - enemy_agility) * float(formulas.flee_agility_factor), float(formulas.flee_minimum), float(formulas.flee_maximum))
	ui.show_caption(str(text.flee_caption))
	await get_tree().create_timer(float(effects.effect_time)).timeout
	if rng.randf() <= chance:
		ui.add_log(str(encounter.escape))
		_finish("escape")
	else:
		ui.add_log(str(text.escape_failed))
		ui.show_caption(str(text.escape_failed))


func _finish(result: String) -> void:
	outcome = result
	fx.clear_active()
	fx.clear_cursor()
	active_index = -int(math.one)
	_refresh()
	var title_value: String
	var detail: String
	var button_text: String = str(text.continue)
	if result == "victory":
		var experience: int = int(math.zero)
		var gold: int = int(math.zero)
		for enemy in enemies:
			experience += int(enemy.experience)
			gold += int(enemy.gold)
		var rewards: Dictionary = party.gain_rewards(experience, gold)
		title_value = str(text.victory)
		detail = str(text.rewards) % [int(rewards.share), gold]
		for line in rewards.level_ups:
			detail += "\n" + str(line)
		_refresh()
	elif result == "defeat":
		title_value = str(text.defeat)
		detail = str(text.defeat_hint)
		button_text = str(text.return_inn)
	else:
		title_value = str(encounter.escape)
		detail = ""
	ui.show_result(title_value, detail, button_text)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") and _awaiting_input():
		fx.clear_cursor()
		ui.show_commands(text, _commands(), _actor_name(true, active_index))
		get_viewport().set_input_as_handled()
