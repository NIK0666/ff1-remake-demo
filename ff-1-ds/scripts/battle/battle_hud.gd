class_name BattleHUD
extends CanvasLayer
## Battle-only UI: party/enemy status, turn order, action menu, log and the
## victory / party-defeated overlays. The exploration HUD is hidden during battle.

const GOLD := Color("#d5b16b")
const GOLD_BRIGHT := Color("#f1d796")
const IVORY := Color("#ede5d4")
const MUTED := Color("#aab3b4")
const PANEL := Color(0.043, 0.086, 0.118, 0.92)
const PANEL_DEEP := Color(0.03, 0.06, 0.083, 0.97)
const BORDER := Color(0.58, 0.47, 0.3, 0.8)
const ENEMY_RED := Color("#df887a")

var _font_body: SystemFont
var _font_bold: SystemFont
var _ui: Control
var _heroes: Array[BattleUnit] = []
var _enemies: Array[BattleUnit] = []
var _party_list: VBoxContainer
var _enemy_list: VBoxContainer
var _turn_label: Label
var _title_label: Label
var _log_label: Label
var _action_panel: PanelContainer
var _action_label: Label
var _action_tween: Tween
var _menu_panel: PanelContainer
var _menu_title: Label
var _menu_list: VBoxContainer
var _menu_hint: Label
var _center_root: Control
var _center_title: Label
var _center_subtitle: Label
var _center_hint: Label
var _center_panel: PanelContainer
var _fade: ColorRect
var _log_lines: Array[String] = []


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_fonts()
	_build_root()


func _make_fonts() -> void:
	_font_body = SystemFont.new()
	_font_body.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "Noto Serif"])
	_font_body.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_font_body.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font_body.font_names
	_font_bold.font_weight = 700
	_font_bold.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_font_bold.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO


func _build_root() -> void:
	_ui = Control.new()
	_ui.name = "BattleUIRoot"
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = _font_body
	theme.default_font_size = 18
	_ui.theme = theme
	add_child(_ui)

	_build_party_panel()
	_build_enemy_panel()
	_build_center_top()
	_build_action_banner()
	_build_menu()
	_build_center_overlay()
	_build_fade()


func _build_party_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "HeroesPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 24.0
	panel.offset_top = 20.0
	panel.offset_right = 384.0
	panel.offset_bottom = 280.0
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, BORDER, 1, 4, 10))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var title := _label("ОТРЯД", 10, GOLD, true)
	vbox.add_child(title)
	_party_list = VBoxContainer.new()
	_party_list.add_theme_constant_override("separation", 3)
	_party_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_party_list)


func _build_enemy_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "EnemiesPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -384.0
	panel.offset_top = 20.0
	panel.offset_right = -24.0
	panel.offset_bottom = 280.0
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, BORDER, 1, 4, 10))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var title := _label("ВРАГИ", 10, ENEMY_RED, true)
	vbox.add_child(title)
	_enemy_list = VBoxContainer.new()
	_enemy_list.add_theme_constant_override("separation", 3)
	_enemy_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_enemy_list)


func _build_center_top() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_left = 0.0
	center.offset_top = 16.0
	center.offset_right = 0.0
	center.offset_bottom = 150.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	var title_panel := PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(620.0, 0.0)
	title_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_DEEP, Color(0.58, 0.47, 0.3, 0.5), 1, 3, 4))
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_panel)
	_title_label = _label("СЕВЕРНЫЙ МОСТ", 13, GOLD, true)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_panel.add_child(_title_label)
	var turn_panel := PanelContainer.new()
	turn_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.58, 0.47, 0.3, 0.4), 1, 3, 6))
	turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(turn_panel)
	_turn_label = _label("", 12, IVORY, false)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_label.custom_minimum_size = Vector2(620.0, 0.0)
	turn_panel.add_child(_turn_label)
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.055, 0.075, 0.84), Color(0.58, 0.47, 0.3, 0.3), 1, 3, 6))
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(log_panel)
	_log_label = _label("", 12, MUTED, false)
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(620.0, 34.0)
	log_panel.add_child(_log_label)


func _build_action_banner() -> void:
	var anchor := CenterContainer.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor.offset_top = 166.0
	anchor.offset_bottom = 212.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(anchor)
	_action_panel = PanelContainer.new()
	_action_panel.name = "BattleActionBanner"
	_action_panel.custom_minimum_size = Vector2(560.0, 0.0)
	var style := _panel_style(Color(0.03, 0.055, 0.075, 0.94), Color(0.76, 0.61, 0.35, 0.75), 1, 4, 8)
	_action_panel.add_theme_stylebox_override("panel", style)
	_action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel.visible = false
	anchor.add_child(_action_panel)
	_action_label = _label("", 16, GOLD_BRIGHT, true)
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_panel.add_child(_action_label)


func _build_menu() -> void:
	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 0.0
	bottom.offset_top = -244.0
	bottom.offset_right = 0.0
	bottom.offset_bottom = -18.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bottom)
	_menu_panel = PanelContainer.new()
	_menu_panel.name = "BattleMenuPanel"
	_menu_panel.custom_minimum_size = Vector2(760.0, 0.0)
	var style := _panel_style(PANEL_DEEP, Color(0.76, 0.61, 0.35, 0.95), 2, 5, 15)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 12
	_menu_panel.add_theme_stylebox_override("panel", style)
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_menu_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel.add_child(vbox)
	_menu_title = _label("", 18, GOLD_BRIGHT, true)
	vbox.add_child(_menu_title)
	_menu_list = VBoxContainer.new()
	_menu_list.add_theme_constant_override("separation", 2)
	_menu_list.custom_minimum_size = Vector2(0.0, 92.0)
	_menu_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_menu_list)
	_menu_hint = _label("", 11, MUTED, false)
	_menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_menu_hint)


func _build_center_overlay() -> void:
	_center_root = Control.new()
	_center_root.name = "BattleCenterOverlay"
	_center_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_root.visible = false
	_ui.add_child(_center_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.012, 0.018, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_root.add_child(center)
	_center_panel = PanelContainer.new()
	_center_panel.custom_minimum_size = Vector2(620.0, 0.0)
	var style := _panel_style(PANEL_DEEP, Color(0.76, 0.61, 0.35, 0.95), 2, 5, 26)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 20
	_center_panel.add_theme_stylebox_override("panel", style)
	_center_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_center_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_panel.add_child(vbox)
	_center_title = _label("", 34, GOLD_BRIGHT, true)
	_center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_center_title)
	_center_subtitle = _label("", 17, IVORY, false)
	_center_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_center_subtitle)
	_center_hint = _label("", 12, MUTED, false)
	_center_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_center_hint)


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.name = "BattleFade"
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.008, 0.012, 0.018, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


# ---------------------------------------------------------------------------
# Public presentation API
# ---------------------------------------------------------------------------

func setup(heroes: Array[BattleUnit], enemies: Array[BattleUnit], title: String) -> void:
	_heroes = heroes
	_enemies = enemies
	_title_label.text = title.to_upper()
	refresh_units(null)


func refresh_units(active_unit: BattleUnit) -> void:
	_rebuild_status_list(_party_list, _heroes, active_unit, false)
	_rebuild_status_list(_enemy_list, _enemies, active_unit, true)


func set_turn_order(order: Array[BattleUnit], current_index: int) -> void:
	var names: PackedStringArray = []
	for i in range(mini(current_index, order.size()), order.size()):
		var unit: BattleUnit = order[i]
		if unit == null or not unit.is_alive():
			continue
		var name := unit.display_name()
		if i == current_index:
			name = "▶ " + name
		names.append(name)
		if names.size() >= 7:
			break
	_turn_label.text = "ХОД: " + "  →  ".join(names)


func set_log_lines(lines: Array[String]) -> void:
	_log_lines.clear()
	var start := maxi(0, lines.size() - 3)
	for i in range(start, lines.size()):
		_log_lines.append(lines[i])
	_log_label.text = "\n".join(_log_lines)


func set_menu(title: String, entries: Array[String], selected: int, hint: String) -> void:
	_menu_panel.visible = true
	_menu_title.text = title
	_menu_hint.text = hint
	for child: Node in _menu_list.get_children():
		_menu_list.remove_child(child)
		child.queue_free()
	for i in entries.size():
		var selected_entry := i == selected
		var label := _label(("▶ " if selected_entry else "   ") + entries[i], 15, GOLD_BRIGHT if selected_entry else IVORY, selected_entry)
		label.custom_minimum_size = Vector2(0.0, 21.0)
		_menu_list.add_child(label)


func hide_menu() -> void:
	_menu_panel.visible = false


func show_action(text: String, accent: Color = GOLD_BRIGHT) -> void:
	if _action_panel == null or _action_label == null:
		return
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_label.text = text
	_action_label.add_theme_color_override("font_color", accent)
	_action_panel.visible = true
	_action_panel.modulate.a = 0.0
	_action_tween = create_tween()
	_action_tween.tween_property(_action_panel, "modulate:a", 1.0, 0.12)
	_action_tween.tween_interval(1.15)
	_action_tween.tween_property(_action_panel, "modulate:a", 0.0, 0.3)
	_action_tween.tween_callback(_action_panel.hide)


func hide_action() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	if _action_panel != null:
		_action_panel.visible = false


func get_action_text() -> String:
	return _action_label.text if _action_label != null else ""


func is_action_visible() -> bool:
	return _action_panel.visible if _action_panel != null else false


func show_center(title: String, subtitle: String, hint: String, accent: Color = GOLD_BRIGHT) -> void:
	hide_action()
	_center_root.visible = true
	_center_root.modulate.a = 0.0
	_center_title.text = title
	_center_title.add_theme_color_override("font_color", accent)
	_center_subtitle.text = subtitle
	_center_hint.text = hint
	create_tween().tween_property(_center_root, "modulate:a", 1.0, 0.24)


func hide_center() -> void:
	_center_root.visible = false


func fade_from_black(duration: float) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)
	await tw.finished
	_fade.visible = false


func fade_to_black(duration: float) -> void:
	_fade.visible = true
	_fade.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	await tw.finished


func get_center_title() -> String:
	return _center_title.text if _center_title != null else ""


func get_center_subtitle() -> String:
	return _center_subtitle.text if _center_subtitle != null else ""


func is_center_visible() -> bool:
	return _center_root.visible if _center_root != null else false


func get_menu_title() -> String:
	return _menu_title.text if _menu_title != null else ""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _rebuild_status_list(container: VBoxContainer, units: Array[BattleUnit], active_unit: BattleUnit, enemy: bool) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for unit: BattleUnit in units:
		var active := unit == active_unit
		var alive := unit.is_alive()
		var fallen_text := "ПОВЕРЖЕН" if enemy else "ПАЛ"
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0.0, 39.0)
		var style := _panel_style(
			Color(0.11, 0.16, 0.2, 0.97) if active else Color(0.035, 0.06, 0.077, 0.9),
			Color(0.8, 0.64, 0.37, 0.95) if active else Color(0.4, 0.35, 0.26, 0.4),
			2 if active else 1,
			3,
			5
		)
		style.content_margin_left = 7.0
		style.content_margin_right = 8.0
		style.content_margin_top = 3.0
		style.content_margin_bottom = 3.0
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(panel)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(vbox)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(top)
		var name_label := _label(("▶ " if active else ("✝ " if not alive else "")) + unit.display_name(), 13, IVORY if alive else Color("#837b72"), true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		var row_label := _label(fallen_text if not alive else _short_row(unit.row()), 9, Color("#b56c61") if not alive else (GOLD if alive else Color("#6f655d")), true)
		top.add_child(row_label)
		var hp := unit.hp()
		var max_hp := unit.max_hp()
		var hp_label := _label(fallen_text if not alive else "%d/%d" % [hp, max_hp], 11, Color("#a9695f") if not alive else MUTED, false)
		hp_label.custom_minimum_size = Vector2(62.0, 0.0)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(hp_label)
		var bar := ProgressBar.new()
		bar.max_value = float(max_hp)
		bar.value = float(hp)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 4.0)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.02, 0.035, 0.045, 0.9)
		bg.corner_radius_top_left = 2
		bg.corner_radius_top_right = 2
		bg.corner_radius_bottom_left = 2
		bg.corner_radius_bottom_right = 2
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#4d4742") if not alive else (Color("#b6655d") if enemy else Color("#7aa27d"))
		fill.corner_radius_top_left = 2
		fill.corner_radius_top_right = 2
		fill.corner_radius_bottom_left = 2
		fill.corner_radius_bottom_right = 2
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(bar)


func _short_row(row: String) -> String:
	return "ЗАДНИЙ" if row == "back" else "ПЕРЕДНИЙ"


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font_bold if bold else _font_body)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(bg: Color, border: Color, border_width: int = 1, radius: int = 3, margin: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = float(margin)
	style.content_margin_right = float(margin)
	style.content_margin_top = float(margin)
	style.content_margin_bottom = float(margin)
	return style
