extends CanvasLayer

signal command_selected(command: String)
signal target_selected(hero_side: bool, index: int)
signal target_focused(hero_side: bool, index: int)
signal spell_selected(spell_id: String)
signal item_selected(item_id: String)
signal continue_selected

var data: Dictionary
var ui: Dictionary
var math: Dictionary
var colors: Dictionary
var root: Control
var ribbon_eyebrow: Label
var turn_label: Label
var caption: Panel
var caption_label: Label
var caption_tween: Tween
var enemy_box: VBoxContainer
var log_label: Label
var command_title: Label
var command_hint: Label
var commands: VBoxContainer
var choices: VBoxContainer
var party_box: HBoxContainer
var result: Panel
var lines: Array[String] = []


func _init(config: Dictionary) -> void:
	data = config
	ui = data.battle.interface
	math = data.settings.math
	colors = data.settings.interface.colors


func _style(background: String, border: String = "border", width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(str(colors[background]))
	style.border_color = Color.html(str(colors[border]))
	style.set_border_width_all(width)
	style.set_corner_radius_all(int(data.settings.interface.panel_radius))
	style.content_margin_left = float(ui.inner_margin)
	style.content_margin_right = float(ui.inner_margin)
	return style


func _label(parent: Control, text_value: String, size_value: int, color_name: String = "text") -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Color.html(str(colors[color_name])))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _panel(size_value: Vector2, left: float, top: float) -> Panel:
	var panel := Panel.new()
	panel.size = size_value
	panel.position = Vector2(left, top)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style("panel"))
	root.add_child(panel)
	return panel


func _button(parent: Control, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(math.zero, float(ui.row_height))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", int(ui.button_size))
	button.add_theme_color_override("font_color", Color.html(str(colors.text)))
	button.add_theme_color_override("font_hover_color", Color.html(str(colors.gold)))
	button.add_theme_color_override("font_focus_color", Color.html(str(colors.gold)))
	button.add_theme_color_override("font_disabled_color", Color.html(str(colors.muted)))
	button.add_theme_stylebox_override("normal", _style("panel_soft", "panel_soft"))
	button.add_theme_stylebox_override("hover", _style("panel", "gold"))
	button.add_theme_stylebox_override("pressed", _style("panel", "gold"))
	button.add_theme_stylebox_override("focus", _style("panel", "gold", int(ui.focus_border)))
	button.add_theme_stylebox_override("disabled", _style("panel_soft", "panel_soft"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _ready() -> void:
	layer = int(ui.layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var width: float = float(data.settings.interface.viewport_width)
	var height: float = float(data.settings.interface.viewport_height)
	var margin: float = float(data.settings.interface.margin)
	var inner: float = float(ui.inner_margin)
	var ribbon := _panel(Vector2(ui.ribbon_width, ui.ribbon_height), (width - float(ui.ribbon_width)) * math.half, margin)
	ribbon_eyebrow = _label(ribbon, "", int(data.settings.interface.eyebrow_size), "gold")
	ribbon_eyebrow.position = Vector2(inner, inner * math.half)
	ribbon_eyebrow.size = Vector2(float(ui.ribbon_width) - inner * math.double, data.settings.interface.eyebrow_size)
	ribbon_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label = _label(ribbon, "", int(ui.turn_size))
	turn_label.position = Vector2(inner, float(ui.ribbon_height) * math.half - inner * math.quarter)
	turn_label.size = Vector2(float(ui.ribbon_width) - inner * math.double, float(ui.ribbon_height) * math.half)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption = _panel(Vector2(ui.caption_width, ui.caption_height), (width - float(ui.caption_width)) * math.half, margin + float(ui.ribbon_height) + float(ui.bar_gap))
	caption.add_theme_stylebox_override("panel", _style("panel_soft", "gold"))
	caption_label = _label(caption, "", int(ui.button_size))
	caption_label.size = Vector2(ui.caption_width, ui.caption_height)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.modulate.a = math.zero
	var top: float = height - margin - float(ui.bar_height)
	var enemy_panel := _panel(Vector2(ui.enemy_width, ui.bar_height), margin, top)
	_label(enemy_panel, str(data.battle.text.enemies_title), int(data.settings.interface.eyebrow_size), "gold").position = Vector2(inner, inner * math.half)
	enemy_box = VBoxContainer.new()
	enemy_box.position = Vector2(inner, inner * math.double)
	enemy_box.size = Vector2(float(ui.enemy_width) - inner * math.double, float(ui.enemy_row_height) * float(ui.enemy_rows))
	enemy_box.add_theme_constant_override("separation", int(math.zero))
	enemy_panel.add_child(enemy_box)
	log_label = _label(enemy_panel, "", int(ui.log_size), "muted")
	log_label.position = Vector2(inner, float(ui.bar_height) - float(ui.log_height) - inner * math.half)
	log_label.size = Vector2(float(ui.enemy_width) - inner * math.double, ui.log_height)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var command_left: float = margin + float(ui.enemy_width) + float(ui.bar_gap)
	var command_panel := _panel(Vector2(ui.command_width, ui.bar_height), command_left, top)
	command_title = _label(command_panel, "", int(data.settings.interface.eyebrow_size), "gold")
	command_title.position = Vector2(inner, inner * math.half)
	command_title.size = Vector2(float(ui.command_width) - inner * math.double, data.settings.interface.eyebrow_size)
	command_title.clip_text = true
	command_hint = _label(command_panel, str(data.battle.text.back_hint), int(data.settings.interface.eyebrow_size), "muted")
	command_hint.position = command_title.position
	command_hint.size = command_title.size
	command_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	command_hint.hide()
	for container_name in ["commands", "choices"]:
		var box := VBoxContainer.new()
		box.position = Vector2(inner, inner * math.double)
		box.size = Vector2(float(ui.command_width) - inner * math.double, float(ui.bar_height) - inner * float(ui.choice_bottom))
		box.add_theme_constant_override("separation", int(ui.choice_gap))
		command_panel.add_child(box)
		set(container_name, box)
	var party_left: float = command_left + float(ui.command_width) + float(ui.bar_gap)
	var party_panel := _panel(Vector2(width - margin - party_left, ui.bar_height), party_left, top)
	party_box = HBoxContainer.new()
	party_box.position = Vector2(inner, inner)
	party_box.size = Vector2(width - margin - party_left - inner * math.double, float(ui.bar_height) - inner * math.double)
	party_box.add_theme_constant_override("separation", int(ui.card_gap))
	party_panel.add_child(party_box)
	commands.hide()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func clear_selection() -> void:
	_clear(choices)
	command_hint.hide()


func hide_commands() -> void:
	commands.hide()
	clear_selection()
	command_title.text = ""


func show_commands(names: Dictionary, allowed: Array, actor_name: String) -> void:
	clear_selection()
	_clear(commands)
	commands.show()
	command_title.text = str(data.battle.text.command_title) % actor_name.to_upper()
	for command in allowed:
		_button(commands, str(names[command]), func() -> void: command_selected.emit(command))
	commands.get_child(int(math.zero)).grab_focus()


func _choices(title_value: String) -> void:
	commands.hide()
	clear_selection()
	command_title.text = title_value.to_upper()
	command_hint.show()


func show_targets(title_value: String, entries: Array) -> void:
	_choices(title_value)
	for entry in entries:
		var hero_side: bool = bool(entry.hero_side)
		var index: int = int(entry.index)
		var button := _button(choices, str(entry.label), func() -> void: target_selected.emit(hero_side, index))
		button.disabled = not bool(entry.get("enabled", true))
		button.focus_entered.connect(func() -> void: target_focused.emit(hero_side, index))
		button.mouse_entered.connect(func() -> void: target_focused.emit(hero_side, index))
	_focus_choice()


func show_spells(title_value: String, entries: Array) -> void:
	_choices(title_value)
	for entry in entries:
		var spell_id: String = str(entry.id)
		var button := _button(choices, str(entry.label), func() -> void: spell_selected.emit(spell_id))
		button.disabled = not bool(entry.enabled)
	_focus_choice()


func show_items(title_value: String, entries: Array) -> void:
	_choices(title_value)
	if entries.is_empty():
		_label(choices, str(data.battle.text.no_items), int(ui.button_size), "muted")
	for entry in entries:
		var item_id: String = str(entry.id)
		var button := _button(choices, str(entry.label), func() -> void: item_selected.emit(item_id))
		button.disabled = not bool(entry.enabled)
	_focus_choice()


func _focus_choice() -> void:
	for child in choices.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return


func set_turn(round_number: int, actor_name: String, title_value: String) -> void:
	ribbon_eyebrow.text = title_value.to_upper()
	turn_label.text = str(data.battle.text.round) % [round_number, actor_name]


func show_caption(text_value: String) -> void:
	caption_label.text = text_value
	if caption_tween and caption_tween.is_valid():
		caption_tween.kill()
	caption.modulate.a = math.opacity
	caption_tween = create_tween()
	caption_tween.tween_interval(float(ui.caption_time))
	caption_tween.tween_property(caption, "modulate:a", math.zero, float(ui.caption_fade))


func add_log(text_value: String) -> void:
	lines.append(text_value)
	while lines.size() > int(ui.log_lines):
		lines.pop_front()
	log_label.text = "\n".join(lines)


func _bar(parent: Control, ratio: float, color_name: String, bar_width: float) -> void:
	var track := ColorRect.new()
	track.color = Color.html(str(colors.ink))
	track.custom_minimum_size = Vector2(bar_width, ui.hp_bar_height)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var fill := ColorRect.new()
	fill.color = Color.html(str(colors[color_name]))
	fill.size = Vector2(bar_width * clampf(ratio, math.zero, math.one), ui.hp_bar_height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)


func _health_color(ratio: float) -> String:
	if ratio <= float(ui.danger_ratio):
		return "danger"
	return "warning" if ratio <= float(ui.warning_ratio) else "health"


func refresh_enemies(enemies: Array) -> void:
	_clear(enemy_box)
	for enemy in enemies:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(math.zero, ui.enemy_row_height)
		row.add_theme_constant_override("separation", int(ui.card_gap))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_box.add_child(row)
		var name_label := _label(row, str(enemy.name), int(ui.button_size), "muted" if bool(enemy.fallen) else "text")
		name_label.custom_minimum_size = Vector2(ui.enemy_name_width, math.zero)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		if bool(enemy.fallen):
			_label(holder, str(data.battle.text.defeated), int(ui.log_size), "muted")
		else:
			var ratio: float = float(enemy.hp) / float(enemy.max_hp)
			_bar(holder, ratio, _health_color(ratio), float(ui.enemy_bar_width))


func refresh(party, heroes_name: Array, active_hero: int) -> void:
	_clear(party_box)
	for index in range(party.state.heroes.size()):
		var hero: Dictionary = party.state.heroes[index]
		var fallen: bool = bool(hero.fallen)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: StyleBoxFlat = _style("panel" if index == active_hero else "panel_soft", "gold" if index == active_hero else "panel_soft", int(ui.focus_border) if index == active_hero else int(math.one))
		style.content_margin_top = float(ui.inner_margin) * math.half
		card.add_theme_stylebox_override("panel", style)
		party_box.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", int(ui.card_line_gap))
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var marker: String = str(data.battle.text.active_marker) if index == active_hero else ""
		_label(box, marker + str(heroes_name[index]), int(ui.button_size), "muted" if fallen else ("gold" if index == active_hero else "text"))
		var ratio: float = float(hero.hp) / float(hero.max_hp)
		_label(box, str(data.economy.text.hp) % [int(hero.hp), int(hero.max_hp)], int(ui.log_size), "muted" if fallen else "text")
		_bar(box, ratio, _health_color(ratio), float(ui.card_bar_width))
		if fallen:
			_label(box, str(data.economy.text.fallen), int(ui.log_size), "danger")
		else:
			_label(box, str(data.battle.text.row_label) % str(data.battle.text[hero.row]), int(ui.log_size), "muted")
		if party.is_caster(index):
			_label(box, str(data.battle.text.charges) % [party.charge_count(index, int(math.one)), party.charge_count(index, int(math.double))], int(ui.log_size), "accent")


func show_result(title_value: String, detail: String, button_text: String) -> void:
	hide_commands()
	var width: float = float(data.settings.interface.viewport_width)
	var height: float = float(data.settings.interface.viewport_height)
	var inner: float = float(ui.inner_margin)
	result = _panel(Vector2(ui.result_width, ui.result_height), (width - float(ui.result_width)) * math.half, (height - float(ui.result_height)) * math.half - float(ui.bar_height) * math.quarter)
	result.add_theme_stylebox_override("panel", _style("panel", "gold", int(ui.focus_border)))
	var title_label := _label(result, title_value, int(ui.result_title_size), "gold")
	title_label.position = Vector2(inner * math.double, inner * math.double)
	title_label.size = Vector2(float(ui.result_width) - inner * float(math.double + math.double), ui.result_title_size)
	var detail_label := _label(result, detail, int(ui.button_size))
	detail_label.position = Vector2(inner * math.double, inner * math.double + float(ui.result_title_size) + inner * math.double)
	detail_label.size = Vector2(float(ui.result_width) - inner * float(math.double + math.double), float(ui.result_height) - float(ui.result_title_size) - float(ui.row_height) - inner * float(ui.choice_bottom))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button := _button(result, button_text, func() -> void: continue_selected.emit())
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.position = Vector2(inner * math.double, float(ui.result_height) - float(ui.row_height) - inner * math.double)
	button.size = Vector2(float(ui.result_width) - inner * float(math.double + math.double), ui.row_height)
	button.grab_focus()
