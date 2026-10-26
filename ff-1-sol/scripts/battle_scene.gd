extends Node3D
## Separate arena; the persistent party nodes remain owned by the main scene.
signal action_impact(event)
var game
var camera: Camera3D
var ui
var busy := false
var actors: Dictionary = {}
var ring: MeshInstance3D
var target_ring: MeshInstance3D
var labels: Dictionary = {}
var display_actor := ""
var action_text := ""
var selected_target := ""
var impact_done := true
var effect_nodes: Array[Node] = []
var v = preload("res://scripts/visuals.gd").new()

func _ready() -> void:
	var visual: Dictionary = GameState.combat.visual.duplicate(true)
	if GameState.session.battle.location.begins_with("chaos_"):
		visual.merge(GameState.dungeon.visual.battle, true)
		var backdrop := Node3D.new()
		backdrop.name = "ChaosShrineArena"
		add_child(backdrop)
		v.assembly(backdrop, GameState.dungeon.visual.arena_parts)
		for at in GameState.dungeon.visual.braziers:
			var group := Node3D.new()
			group.position = GameState.ground(GameState.cell(at))
			backdrop.add_child(group)
			v.assembly(group, GameState.dungeon.visual.brazier_parts)
		preload("res://scripts/scenery.gd").new().arena(backdrop)
	else:
		var backdrop = preload("res://scenes/town.tscn").instantiate()
		backdrop.name = "SameCorneliaBridge"
		add_child(backdrop)
		for node in backdrop.get_children():
			if node is Label3D:
				node.hide()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = visual.camera_size
	add_child(camera)
	var center := GameState.vec(visual.center)
	var aim := center + GameState.vec(visual.camera_target_offset)
	camera.position = aim + GameState.vec(visual.camera_offset)
	camera.look_at(aim, Vector3.RIGHT)
	camera.make_current()
	for index in game.actors.size():
		var member: Dictionary = GameState.session.heroes[index]
		var actor: Node3D = game.actors[index]
		actor.position = Vector3(center.x + visual.hero_slots[index], GameState.rules.n.zero, visual.hero_z[member.row])
		actor.rotation_degrees.y = visual.hero_rotation
		actor.scale = Vector3.ONE * GameState.polish.battle.actor_scale
		actors[member.id] = actor
	for index in GameState.session.battle.enemies.size():
		var enemy: Dictionary = GameState.session.battle.enemies[index]
		var actor: Node3D = v.actor(self, enemy)
		var count: int = GameState.session.battle.enemies.size()
		var slots: Array = GameState.polish.battle.live_slots.one if count == int(GameState.rules.n.one) else (GameState.polish.battle.live_slots.two if count == int(GameState.rules.n.two) else GameState.polish.battle.live_slots.three)
		actor.position = Vector3(center.x + slots[index], GameState.rules.n.zero, visual.enemy_z[enemy.row])
		actor.rotation_degrees.y = visual.enemy_rotation
		actor.scale = Vector3.ONE * (GameState.polish.battle.boss_scale if enemy.get("boss", false) else GameState.polish.battle.actor_scale)
		actors[enemy.id] = actor
	ring = v.shape(self, "cylinder", GameState.vec(GameState.polish.battle.focus_ring), center, visual.ring_color)
	target_ring = v.shape(self, "cylinder", GameState.vec(GameState.polish.battle.target_ring), center, GameState.polish.battle.target_color)
	target_ring.hide()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = preload("res://scripts/battle_hud.gd").new()
	ui.hud = game.hud
	ui.controller = self
	canvas.add_child(ui)
	for id in actors:
		labels[id] = _screen_label("", GameState.polish.battle.name_font, GameState.rules.ui.ink)
		labels[id].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	refresh_view()
	_drive.call_deferred()

func refresh_view() -> void:
	var model = GameState.battle_system
	for id in actors:
		var actor: Node3D = actors[id]
		var dead: bool = model.unit(id).hp <= GameState.rules.n.zero
		if busy and not impact_done:
			for effect in model.state().get("last_action", {}).get("effects", []):
				if effect.id == id and effect.fell:
					dead = false
		actor.visible = not dead or model.is_hero(id)
		var factor: float = GameState.polish.battle.boss_scale if model.unit(id).get("boss", false) else GameState.polish.battle.actor_scale
		actor.scale = Vector3.ONE * factor
		actor.rotation_degrees.x = GameState.polish.actor.fall_angle if dead else GameState.rules.n.zero
		actor.position.y = GameState.polish.actor.fall_height if dead else GameState.rules.n.zero
		v.fallen(actor, dead, true)
		labels[id].text = model.unit(id).name + (" · ПАЛ" if dead else "")
		labels[id].position = camera.unproject_position(actor.position) + Vector2(GameState.polish.battle.name_offset.front(), GameState.polish.battle.name_offset.back())
		labels[id].visible = actor.visible and not busy and model.state().phase == "turn"
		labels[id].modulate = Color(GameState.polish.battle.dead_color if dead else GameState.rules.ui.ink)
	var active: String = active_actor()
	ring.visible = actors.has(active)
	if ring.visible:
		ring.position = actors[active].position
	select_target(selected_target)
	ui.refresh()

func _screen_label(text: String, font_size: float, color: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size = Vector2(GameState.polish.battle.label_width, GameState.polish.battle.label_height_px)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", game.hud.sans)
	label.add_theme_font_size_override("font_size", int(font_size))
	label.add_theme_color_override("font_color", Color(color))
	label.add_theme_color_override("font_outline_color", Color(GameState.rules.ui.panel))
	label.add_theme_constant_override("outline_size", int(GameState.polish.battle.text_outline))
	ui.add_child(label)
	return label

func _process(_delta: float) -> void:
	if not is_instance_valid(ui):
		return
	for id in labels:
		labels[id].position = camera.unproject_position(actors[id].position) + Vector2(GameState.polish.battle.name_offset.front(), GameState.polish.battle.name_offset.back())
	var active := active_actor()
	if actors.has(active):
		ring.position = actors[active].position

func active_actor() -> String:
	return display_actor if busy and not display_actor.is_empty() else GameState.battle_system.current()

func select_target(id: String) -> void:
	selected_target = id
	if is_instance_valid(target_ring):
		target_ring.visible = not busy and actors.has(id) and actors[id].visible
		if target_ring.visible:
			target_ring.position = actors[id].position

func _delay(enemy: bool = false) -> float:
	if game.testing:
		return GameState.polish.battle.test_seconds
	return GameState.combat.visual.enemy_seconds if enemy else GameState.polish.battle.action_seconds

func _clear_effects() -> void:
	for node in effect_nodes:
		if is_instance_valid(node):
			node.queue_free()
	effect_nodes.clear()

func _animate(event: Dictionary) -> void:
	var fx: Dictionary = GameState.polish.battle
	action_text = event.title
	var actor: Node3D = actors[event.actor]
	var origin := actor.position
	var target_position: Vector3 = origin
	if not event.effects.is_empty():
		target_position = actors[event.effects.front().id].position
	var tween := create_tween()
	if event.command == "attack":
		var direction := (target_position - origin).normalized()
		tween.tween_property(actor, "position", origin + direction * GameState.combat.visual.lunge, _delay())
		tween.tween_property(actor, "position", origin, _delay())
	elif event.command in ["spell", "item"] and not event.effects.is_empty():
		var color: String = fx.magic if event.command == "spell" else fx.heal
		var orb := v.shape(self, "sphere", GameState.vec(fx.projectile_size), origin + Vector3.UP * fx.projectile_height, color)
		effect_nodes.append(orb)
		tween.tween_property(orb, "position", target_position + Vector3.UP * fx.projectile_height, _delay())
	else:
		tween.tween_interval(_delay())
	ui.queue_redraw()
	await tween.finished
	for effect in event.effects:
		var target: Node3D = actors[effect.id]
		var color: String = fx.damage if effect.kind == "damage" else (fx.guard if effect.kind == "guard" else fx.heal)
		var pulse := v.shape(self, "cylinder", GameState.vec(fx.effect_ring), target.position, color)
		effect_nodes.append(pulse)
		var number: String = ("−" if effect.kind == "damage" else "+") + str(effect.amount)
		if effect.kind == "guard":
			number = "ЗАЩИТА +" + str(effect.amount)
		elif effect.kind == "revive":
			number = "В СТРОЮ +" + str(effect.amount)
		if effect.fell:
			number += " · ПАЛ"
		var label: Label = _screen_label(number, fx.number_font, color)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.position = camera.unproject_position(target.position) + Vector2(fx.number_offset.front(), fx.number_offset.back())
		effect_nodes.append(label)
		var flash := v.lamp(self, target.position + Vector3.UP * fx.projectile_height)
		flash.light_color = Color(color)
		flash.light_energy = fx.flash_energy
		flash.omni_range = fx.flash_range
		effect_nodes.append(flash)
		var effect_tween := create_tween().set_parallel(true)
		var duration: float = fx.test_seconds if game.testing else fx.impact_seconds
		effect_tween.tween_property(pulse, "scale", GameState.vec(fx.effect_scale), duration)
		effect_tween.tween_property(label, "position:y", label.position.y - fx.float_pixels, duration)
	impact_done = true
	refresh_view()
	action_impact.emit(event)
	await get_tree().create_timer(fx.test_seconds if game.testing else fx.hold_seconds).timeout
	_clear_effects()

func player_action(command: String, ability: String = "", target: String = "") -> Dictionary:
	var model = GameState.battle_system
	if busy or not model.is_hero(model.current()):
		return GameState._result(false, "Дождитесь хода героя.")
	var actor: String = model.current()
	busy = true
	display_actor = actor
	impact_done = false
	var result: Dictionary = model.act(command, ability, target)
	ui.notice = "" if result.ok else result.message
	if not result.ok:
		busy = false
		display_actor = ""
		impact_done = true
		refresh_view()
		return result
	refresh_view()
	await _animate(model.state().last_action)
	await _drive()
	return result

func _drive() -> void:
	var model = GameState.battle_system
	while model.state().phase == "turn" and not model.is_hero(model.current()):
		busy = true
		display_actor = model.current()
		action_text = model.unit(display_actor).name + " готовится к действию"
		impact_done = false
		refresh_view()
		await get_tree().create_timer(_delay(true)).timeout
		model.enemy_turn()
		await _animate(model.state().last_action)
	busy = false
	display_actor = ""
	action_text = ""
	refresh_view()

func finish() -> void:
	if busy or GameState.session.battle.phase != "result":
		return
	game.return_from_battle()

func handle_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not busy:
		var keys := [KEY_1, KEY_2, KEY_3, KEY_4]
		if keys.has(event.physical_keycode):
			ui.choose_command(["attack", "spell", "item", "escape"][keys.find(event.physical_keycode)])
			return
	if event.is_action_pressed("pause"):
		ui.choose_command("attack")
	elif event.is_action_pressed("talk"):
		if GameState.session.battle.phase == "result":
			finish()
		else:
			ui.confirm_default()
