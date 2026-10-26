extends "res://scripts/service_panel.gd"
var controller
var layout: Dictionary
var command := "attack"
var ability := ""
var last_actor := ""
var notice := ""
var command_buttons: Dictionary = {}
var option_buttons: Dictionary = {}
var target_buttons: Dictionary = {}
var transient: Array[Button] = []
var result_button: Button

func _ready() -> void:
	cfg = GameState.rules.ui.service
	layout = GameState.combat.ui
	size = Vector2(GameState.rules.ui.width, GameState.rules.ui.height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var names := {"attack":"Атака", "spell":"Заклинание", "item":"Предмет", "escape":"Бегство"}
	var index := int(GameState.rules.n.zero)
	for id in names:
		var y: float = layout.commands_origin.back() + index * (layout.command_size.back() + layout.command_gap)
		var button := _button(names[id], [layout.commands_origin.front(), y, layout.command_size.front(), layout.command_size.back()])
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(choose_command.bind(id))
		command_buttons[id] = button
		index += int(GameState.rules.n.one)
	result_button = _button("Продолжить", layout.result_button)
	result_button.focus_mode = Control.FOCUS_ALL
	result_button.pressed.connect(controller.finish)
	refresh()

func _choice(text: String, origin: Array, dimensions: Array, gap: float, index: int) -> Button:
	var y: float = origin.back() + index * (dimensions.back() + gap)
	var button := _button(text, [origin.front(), y, dimensions.front(), dimensions.back()])
	button.focus_mode = Control.FOCUS_ALL
	transient.append(button)
	return button

func refresh() -> void:
	if layout.is_empty():
		return
	var focus := get_viewport().gui_get_focus_owner()
	var focus_key: String = focus.get_meta("battle_choice", "") if is_instance_valid(focus) else ""
	for button in transient:
		remove_child(button)
		button.queue_free()
	transient.clear()
	option_buttons.clear()
	target_buttons.clear()
	var model = GameState.battle_system
	var s: Dictionary = model.state()
	var actor: String = model.current()
	var player: bool = model.is_hero(actor) and s.phase == "turn" and not controller.busy
	for id in command_buttons:
		command_buttons[id].visible = s.phase == "turn"
		command_buttons[id].disabled = not player
		command_buttons[id].add_theme_stylebox_override("normal", _style(cfg.selected if id == command else cfg.row_bg))
	command_buttons.spell.disabled = not player or model.spells(actor).is_empty() if player else true
	command_buttons.spell.tooltip_text = "Этот герой не владеет магией." if player and model.spells(actor).is_empty() else "Заклинания расходуют заряд своего уровня."
	result_button.visible = s.phase == "result" and not controller.busy
	result_button.disabled = controller.busy
	result_button.text = "Вернуться к последнему ночлегу" if s.result == "defeat" else ("Освободить Сару" if s.kind == "garland" and s.result == "victory" else ("Вернуться в святилище" if s.location.begins_with("chaos_") else "Вернуться на мост"))
	if not player:
		queue_redraw()
		return
	if last_actor != actor:
		last_actor = actor
		command = "attack"
		ability = ""
	var options: Array = []
	if command == "spell":
		options = model.spells(actor)
	elif command == "item":
		for id in GameState.combat.items:
			if GameState.owned(id) > GameState.rules.n.zero:
				options.append(id)
	if not options.has(ability):
		ability = "" if options.is_empty() else options.front()
	var index := int(GameState.rules.n.zero)
	for id in options:
		var text: String
		if command == "spell":
			var spell: Dictionary = GameState.combat.spells[id]
			var school := "Белая" if spell.school == "white" else "Чёрная"
			text = spell.name + " · " + school + " · ур. " + spell.level + " · " + str(int(model.unit(actor).charges.get(spell.level, GameState.rules.n.zero))) + "/" + str(int(GameState.combat.classes[actor].charges[spell.level]))
		else:
			text = GameState.economy.items[id].name + " ×" + str(GameState.owned(id))
		var button := _choice(text, layout.options_origin, layout.option_size, layout.option_gap, index)
		button.set_meta("battle_choice", "option:" + id)
		if command == "spell":
			var spell: Dictionary = GameState.combat.spells[id]
			button.disabled = int(model.unit(actor).charges.get(spell.level, GameState.rules.n.zero)) <= GameState.rules.n.zero
			button.tooltip_text = "Нет зарядов уровня " + spell.level + ". Восстановите их в постоялом дворе." if button.disabled else spell.name
		button.add_theme_stylebox_override("normal", _style(cfg.selected if id == ability else cfg.row_bg))
		button.pressed.connect(choose_ability.bind(id))
		option_buttons[id] = button
		index += int(GameState.rules.n.one)
	var candidates: Array[String] = model.targets(command, ability)
	if command in ["spell", "item"] and ability.is_empty():
		candidates.clear()
	var all_targets: bool = command == "spell" and not ability.is_empty() and GameState.combat.spells[ability].target.begins_with("all_")
	if all_targets and not candidates.is_empty():
		var button := _choice("Все подходящие цели", layout.target_origin, layout.target_size, layout.target_gap, int(GameState.rules.n.zero))
		button.pressed.connect(choose_target.bind("all"))
		target_buttons["all"] = button
	else:
		index = int(GameState.rules.n.zero)
		for id in candidates:
			var target: Dictionary = model.unit(id)
			var button := _choice(target.name + " · " + str(int(target.hp)) + " / " + str(int(target.max_hp)) + " HP", layout.target_origin, layout.target_size, layout.target_gap, index)
			button.pressed.connect(choose_target.bind(id))
			button.mouse_entered.connect(controller.select_target.bind(id))
			button.focus_entered.connect(controller.select_target.bind(id))
			button.set_meta("battle_choice", "target:" + id)
			if command == "item" or (command == "spell" and not ability.is_empty() and GameState.combat.spells[ability].effect == "heal"):
				button.disabled = target.hp >= target.max_hp
				button.tooltip_text = "Здоровье уже полное." if button.disabled else "Восстановить HP"
			target_buttons[id] = button
			index += int(GameState.rules.n.one)
	for button in transient:
		if not focus_key.is_empty() and button.get_meta("battle_choice", "") == focus_key and not button.disabled:
			button.grab_focus.call_deferred()
	queue_redraw()

func choose_command(value: String) -> void:
	if controller.busy or GameState.session.battle.phase != "turn":
		return
	if value == "escape":
		controller.player_action("escape")
		return
	command = value
	ability = ""
	refresh()

func choose_ability(id: String) -> void:
	ability = id
	refresh()

func choose_target(id: String) -> void:
	controller.player_action(command, ability, id)

func confirm_default() -> void:
	if target_buttons.has(controller.selected_target) and not target_buttons[controller.selected_target].disabled:
		choose_target(controller.selected_target)
		return
	for id in target_buttons:
		if not target_buttons[id].disabled:
			choose_target(id)
			return

func _card(actor: Dictionary, position: Array, active: String) -> void:
	var u: Dictionary = GameState.rules.ui
	_box([position.front(), position.back(), layout.card_size.front(), layout.card_size.back()], cfg.selected if actor.id == active else cfg.bg)
	var name_at := [position.front() + layout.card_name_offset.front(), position.back() + layout.card_name_offset.back()]
	_text(actor.name, name_at, u.card_font, u.gold if actor.id == active else u.ink, true)
	_text(str(int(actor.hp)) + " / " + str(int(actor.max_hp)) + " HP", [position.front() + layout.card_hp_offset.front(), position.back() + layout.card_hp_offset.back()], u.body_size, u.ink)
	var is_member: bool = GameState.battle_system.is_hero(actor.id)
	var caption: String = GameState.combat.rows[actor.row].name + " ряд"
	if actor.hp <= GameState.rules.n.zero:
		caption = "ПАЛ · воскрешение / ночлег" if is_member else "ПОВЕРЖЕН"
	elif is_member:
		caption += " · ур. " + str(actor.level) + " · XP " + str(actor.experience)
	_text(caption, [position.front() + layout.card_row_offset.front(), position.back() + layout.card_row_offset.back()], u.small_size, GameState.polish.battle.dead_color if actor.hp <= GameState.rules.n.zero else u.muted)
	var bar := Rect2(position.front() + layout.bar_offset.front(), position.back() + layout.bar_offset.back(), layout.bar_size.front(), layout.bar_size.back())
	draw_rect(bar, Color(layout.bar_bg))
	bar.size.x *= float(actor.hp) / actor.max_hp
	draw_rect(bar, Color(GameState.polish.battle.damage if actor.hp < actor.max_hp * GameState.polish.battle.low_hp else (layout.hero_bar if is_member else layout.enemy_bar)))

func _draw() -> void:
	if layout.is_empty():
		return
	var u: Dictionary = GameState.rules.ui
	var model = GameState.battle_system
	var s: Dictionary = model.state()
	_box(layout.header, cfg.bg)
	var shrine: bool = s.location.begins_with("chaos_")
	_text("СВЯТИЛИЩЕ ХАОСА / ПОШАГОВЫЙ БОЙ" if shrine else "СЕВЕРНЫЙ МОСТ / ПОШАГОВЫЙ БОЙ", layout.overline, u.small_size, u.gold)
	_text("Гарланд" if s.kind == "garland" else ("Схватка во тьме" if shrine else "Схватка на мосту"), layout.title, layout.title_size, u.ink, true)
	_box(layout.queue_box, cfg.bg)
	_text("ПОРЯДОК ПО ЛОВКОСТИ · РАУНД " + str(s.round), layout.queue_label, u.small_size, u.gold)
	var order: PackedStringArray = []
	for index in range(int(s.cursor), mini(s.queue.size(), int(s.cursor) + int(layout.queue_limit))):
		if model.unit(s.queue[index]).hp > GameState.rules.n.zero:
			order.append(model.unit(s.queue[index]).name)
	_text(" → ".join(order), layout.queue_text, layout.queue_font, u.ink)
	var index := int(GameState.rules.n.zero)
	for enemy in s.enemies:
		_card(enemy, [layout.enemy_origin.front(), layout.enemy_origin.back() + index * (layout.card_size.back() + layout.card_gap)], controller.active_actor())
		index += int(GameState.rules.n.one)
	index = int(GameState.rules.n.zero)
	for member in GameState.session.heroes:
		_card(member, [layout.hero_origin.front(), layout.hero_origin.back() + index * (layout.card_size.back() + layout.card_gap)], controller.active_actor())
		index += int(GameState.rules.n.one)
	_box(layout.panel, cfg.bg)
	var actor: String = controller.active_actor()
	var turn_text: String = "Ваш ход: " + model.unit(actor).name if model.is_hero(actor) else "Ход врагов"
	_text("Бой завершён" if s.phase == "result" else turn_text, layout.turn_title, u.body_size, u.gold)
	_text("Команда / заклинание / предмет", layout.options_label, u.small_size, u.muted)
	_text("ВЫБЕРИТЕ ЦЕЛЬ", layout.targets_label, u.small_size, u.gold)
	if command == "attack":
		_wrap("Ближняя атака. Задний ряд наносит меньше урона и слабее страдает от ближних ударов.", layout.empty_pos, layout.option_size.front(), u.body_size, cfg.detail_line_height, u.muted)
	elif option_buttons.is_empty():
		_text("Нет доступных заклинаний или предметов", layout.empty_pos, u.body_size, u.muted)
	_box(layout.log_rect, cfg.bg)
	var y: float = layout.log_origin.back()
	var log: Array = s.log
	for log_index in range(maxi(int(GameState.rules.n.zero), log.size() - int(GameState.polish.battle.log_limit)), log.size()):
		_text(str(log[log_index]).left(int(GameState.polish.battle.log_chars)), [layout.log_origin.front(), y], layout.log_font, u.ink)
		y += layout.log_line
	if not notice.is_empty():
		_text(notice, [layout.log_origin.front(), y], layout.log_font, cfg.bad)
	if not controller.action_text.is_empty():
		_box(GameState.polish.battle.action_rect, cfg.bg)
		_text(controller.action_text, GameState.polish.battle.action_text, GameState.polish.battle.action_font, u.gold)
	_text(layout.hint, layout.hint_pos, u.small_size, u.ink)
	if s.phase == "result" and not controller.busy:
		draw_rect(Rect2(Vector2.ZERO, size), Color(u.shadow))
		_box(layout.result_panel, cfg.bg)
		var title := "Победа" if s.result == "victory" else ("Партия погибла" if s.result == "defeat" else "Удалось убежать")
		_text(title, layout.result_title, u.title_size, u.gold if s.result == "victory" else u.ink, true)
		var text: String
		if s.result == "victory":
			text = "+" + str(s.reward_gold) + " G партии\n+" + str(s.reward_experience) + " опыта каждому выжившему\nЗолото, опыт, предметы и заряды остаются в состоянии партии."
		elif s.result == "defeat":
			text = "Контрольная точка: " + GameState.session.checkpoint.title + "\nБудет восстановлено состояние партии на момент последнего ночлега."
		else:
			text = "Партия возвращается к месту встречи без награды. Потраченное зелье и заряды не восстанавливаются."
		_wrap(text, layout.result_text, layout.result_width, u.dialog_size, layout.result_line, u.ink)
