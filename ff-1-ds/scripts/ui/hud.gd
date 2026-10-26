class_name GameHUD
extends CanvasLayer
## All UI is built in code: party roster, quest tracker, prompts, typewriter
## dialogue, location titles, toasts and the scene-transition fade.

signal dialogue_closed
signal story_finished
signal service_closed
signal equipment_closed

const GOLD := Color("#d5b16b")
const GOLD_BRIGHT := Color("#f1d796")
const IVORY := Color("#ede5d4")
const MUTED := Color("#aab3b4")
const INK := Color("#08121a")
const PANEL := Color(0.043, 0.086, 0.118, 0.9)
const PANEL_DEEP := Color(0.035, 0.068, 0.095, 0.96)
const BORDER := Color(0.58, 0.47, 0.3, 0.8)

var _font_body: SystemFont
var _font_bold: SystemFont
var _ui: Control
var _vignette: ColorRect
var _fade: ColorRect

var _objective_label: Label
var _objective_panel: PanelContainer
var _party_cards: Array[PanelContainer] = []
var _party_hp_labels: Array[Label] = []

var _wallet_panel: PanelContainer
var _wallet_gold_label: Label
var _wallet_items_label: Label

var _service_root: Control
var _service_dim: ColorRect
var _service_panel: PanelContainer
var _service_title: Label
var _service_subtitle: Label
var _service_gold: Label
var _service_tabs: HBoxContainer
var _service_tab_buy: Label
var _service_tab_sell: Label
var _service_columns: HBoxContainer
var _service_col_name: Label
var _service_col_price: Label
var _service_col_owned: Label
var _service_list: VBoxContainer
var _service_description: Label
var _service_message: Label
var _service_hint: Label
var _service_open: bool = false
var _service_id: String = ""
var _service_data: Dictionary = {}
var _service_mode: String = "buy"
var _service_index: int = 0
var _service_entries: Array[Dictionary] = []
var _service_lost_ids: Array[String] = []

var _equipment_root: Control
var _equipment_panel: PanelContainer
var _equipment_gold: Label
var _equipment_xp: Label
var _equipment_hero_list: VBoxContainer
var _equipment_hero_name: Label
var _equipment_hero_meta: Label
var _equipment_stats: Label
var _equipment_slots: VBoxContainer
var _equipment_slot_rows: Array[PanelContainer] = []
var _equipment_slot_values: Array[Label] = []
var _equipment_item_title: Label
var _equipment_item_list: VBoxContainer
var _equipment_detail: Label
var _equipment_message: Label
var _equipment_hint: Label
var _equipment_open: bool = false
var _equipment_hero_index: int = 0
var _equipment_slot_index: int = 0
var _equipment_picking: bool = false
var _equipment_item_index: int = 0
var _equipment_item_ids: Array[String] = []
var _equipment_current_entries: Array[Dictionary] = []

var _prompt_holder: CenterContainer
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _prompt_keycap: PanelContainer
var _prompt_tween: Tween
var _last_prompt: String = ""

var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

var _title_holder: CenterContainer
var _title_label: Label
var _subtitle_label: Label
var _title_tween: Tween
var _controls_hint: Label

var _dialogue_panel: PanelContainer
var _dialogue_name: Label
var _dialogue_role: Label
var _dialogue_line: Label
var _dialogue_continue: Label
var _dialogue_monogram: Label
var _dialogue_monogram_panel: PanelContainer
var _dialogue_open: bool = false
var _dialogue_full_text: String = ""
var _dialogue_typed: float = 0.0
var _dialogue_tween: Tween
var _dialogue_accent: Color = GOLD
var _story_mode: bool = false
var _story_lines: Array[Dictionary] = []
var _story_index: int = 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_fonts()
	_build_root()
	_build_vignette()
	_build_party()
	_build_objective()
	_build_controls_hint()
	_build_title()
	_build_toast()
	_build_prompt()
	_build_wallet()
	_build_dialogue()
	_build_service()
	_build_equipment()
	_build_fade()
	GameState.party_status_changed.connect(_on_party_status_changed)
	_refresh_party_status()
	_refresh_wallet()
	_update_objective(false)


func _process(delta: float) -> void:
	if _dialogue_open:
		if _dialogue_typed < float(_dialogue_full_text.length()):
			_dialogue_typed += float(GameState.game["dialogue"]["chars_per_second"]) * delta
			_dialogue_line.visible_characters = mini(int(_dialogue_typed), _dialogue_full_text.length())
			if _dialogue_typed >= float(_dialogue_full_text.length()):
				_dialogue_continue.modulate.a = 0.82
		else:
			_dialogue_continue.modulate.a = 0.55 + sin(Time.get_ticks_msec() * 0.004) * 0.25


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

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
	_ui.name = "UIRoot"
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = _font_body
	theme.default_font_size = 18
	_ui.theme = theme
	add_child(_ui)


func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	_vignette.material = mat
	_ui.add_child(_vignette)


func _build_party() -> void:
	var block := VBoxContainer.new()
	block.name = "PartyBlock"
	block.position = Vector2(28.0, 20.0)
	block.add_theme_constant_override("separation", 7)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(block)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(header)
	var caption := _label(GameState.ui_text("party_label", "ОТРЯД"), 13, GOLD, true)
	header.add_child(caption)
	var rule := ColorRect.new()
	rule.color = Color(0.58, 0.47, 0.3, 0.6)
	rule.custom_minimum_size = Vector2(156.0, 1.0)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(rule)

	var row := HBoxContainer.new()
	row.name = "PartyRow"
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(row)

	for i in GameState.party.size():
		var member: Dictionary = GameState.party[i]
		var card := _build_party_card(member, i == 0)
		row.add_child(card)
		_party_cards.append(card)


func _build_party_card(member: Dictionary, is_leader: bool) -> PanelContainer:
	var accent := Color(str(member["accent"]))
	var color := Color(str(member["color"]))
	var style := _panel_style(PANEL, accent if is_leader else BORDER, 2 if is_leader else 1, 4, 7)
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	var card := PanelContainer.new()
	card.name = "HeroCard_%s" % str(member["id"])
	card.custom_minimum_size = Vector2(196.0, 60.0)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 9)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var strip := ColorRect.new()
	strip.color = color
	strip.custom_minimum_size = Vector2(3.0, 0.0)
	strip.size_flags_vertical = Control.SIZE_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(strip)

	var icon := ClassIcon.new()
	icon.setup(str(member["class_id"]), color, accent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_row)
	var name_label := _label(str(member["name"]), 17, IVORY, true)
	name_row.add_child(name_label)
	if is_leader:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(spacer)
		var leader_diamond := _label("◆", 10, GOLD_BRIGHT, false)
		leader_diamond.modulate.a = 0.9
		name_row.add_child(leader_diamond)
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 5)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta_row)
	var class_label := _label(str(member["class_name"]).to_upper(), 11, MUTED, false)
	class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(class_label)
	var hp_label := _label("", 10, MUTED, false)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.name = "HP_%s" % str(member["id"])
	meta_row.add_child(hp_label)
	_party_hp_labels.append(hp_label)
	return card


func _build_objective() -> void:
	_objective_panel = PanelContainer.new()
	_objective_panel.name = "ObjectivePanel"
	_objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_objective_panel.offset_left = -392.0
	_objective_panel.offset_right = -26.0
	_objective_panel.offset_top = 22.0
	_objective_panel.offset_bottom = 132.0
	_objective_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, BORDER, 1, 4, 12))
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_objective_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	var diamond := _label("◇", 15, GOLD)
	header.add_child(diamond)
	var title := _label(GameState.ui_text("objective_title", "ПУТЬ ГЕРОЕВ"), 12, GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var chapter := _label("I", 12, MUTED, true)
	header.add_child(chapter)

	var divider := ColorRect.new()
	divider.color = Color(0.58, 0.47, 0.3, 0.45)
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	_objective_label = _label("", 15, IVORY, false)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(330.0, 0.0)
	_objective_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_objective_label)


func _build_controls_hint() -> void:
	_controls_hint = _label(GameState.ui_text("controls_hint", "WASD — движение   E — действие"), 13, MUTED, false)
	_controls_hint.name = "ControlsHint"
	_controls_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_controls_hint.offset_left = -470.0
	_controls_hint.offset_right = -28.0
	_controls_hint.offset_top = -36.0
	_controls_hint.offset_bottom = -16.0
	_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_controls_hint)
	var tween := create_tween()
	tween.tween_interval(float(GameState.game["ui"]["controls_hint_seconds"]))
	tween.tween_property(_controls_hint, "modulate:a", 0.0, 0.8)


func _build_title() -> void:
	_title_holder = CenterContainer.new()
	_title_holder.name = "LocationTitle"
	_title_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_holder.offset_top = 100.0
	_title_holder.offset_bottom = 252.0
	_title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_title_holder)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_holder.add_child(vbox)

	var top_ornament := _label("✦", 15, GOLD)
	top_ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(top_ornament)
	_title_label = _label("КОРНЕЛИЯ", 48, IVORY, true)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_constant_override("outline_size", 9)
	_title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.035, 0.05, 0.86))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(_title_label)
	var divider := ColorRect.new()
	divider.color = Color(0.65, 0.52, 0.33, 0.75)
	divider.custom_minimum_size = Vector2(300.0, 1.0)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)
	_subtitle_label = _label("Город у северного моста", 18, Color("#dccba9"), false)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_constant_override("outline_size", 5)
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.035, 0.8))
	vbox.add_child(_subtitle_label)
	_title_holder.modulate.a = 0.0
	_title_holder.visible = false


func _build_toast() -> void:
	var holder := CenterContainer.new()
	holder.name = "ToastHolder"
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -178.0
	holder.offset_bottom = -126.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	_toast_panel = PanelContainer.new()
	var style := _panel_style(PANEL_DEEP, Color(0.65, 0.52, 0.33, 0.85), 1, 3, 9)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	holder.add_child(_toast_panel)
	_toast_label = _label("", 15, IVORY, false)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)


func _build_prompt() -> void:
	_prompt_holder = CenterContainer.new()
	_prompt_holder.name = "PromptHolder"
	_prompt_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_holder.offset_top = -104.0
	_prompt_holder.offset_bottom = -48.0
	_prompt_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_prompt_holder)

	_prompt_panel = PanelContainer.new()
	var style := _panel_style(PANEL_DEEP, Color(0.68, 0.54, 0.32, 0.9), 1, 5, 8)
	style.content_margin_left = 12.0
	style.content_margin_right = 18.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	_prompt_panel.add_theme_stylebox_override("panel", style)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	_prompt_holder.add_child(_prompt_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_child(hbox)
	_prompt_keycap = PanelContainer.new()
	_prompt_keycap.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.17, 0.19, 0.95), GOLD, 1, 3, 4))
	_prompt_keycap.custom_minimum_size = Vector2(28.0, 26.0)
	_prompt_keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_prompt_keycap)
	var key_label := _label("E", 15, GOLD_BRIGHT, true)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_keycap.add_child(key_label)
	_prompt_label = _label("", 16, IVORY, false)
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_prompt_label)


func _build_dialogue() -> void:
	var holder := CenterContainer.new()
	holder.name = "DialogueHolder"
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -268.0
	holder.offset_bottom = -34.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)

	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.name = "DialoguePanel"
	_dialogue_panel.custom_minimum_size = Vector2(1010.0, 202.0)
	var style := _panel_style(PANEL_DEEP, Color(0.7, 0.56, 0.33, 0.95), 2, 5, 20)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 14
	_dialogue_panel.add_theme_stylebox_override("panel", style)
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_panel.visible = false
	_dialogue_panel.modulate.a = 0.0
	holder.add_child(_dialogue_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_panel.add_child(hbox)

	_dialogue_monogram_panel = PanelContainer.new()
	_dialogue_monogram_panel.custom_minimum_size = Vector2(104.0, 104.0)
	_dialogue_monogram_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dialogue_monogram_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_monogram_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.12, 0.15, 0.95), GOLD, 1, 3, 4))
	hbox.add_child(_dialogue_monogram_panel)
	_dialogue_monogram = _label("К", 46, GOLD_BRIGHT, true)
	_dialogue_monogram.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_monogram.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_monogram_panel.add_child(_dialogue_monogram)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 6)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(header)
	_dialogue_name = _label("Стражник", 25, GOLD_BRIGHT, true)
	header.add_child(_dialogue_name)
	_dialogue_role = _label("Стражник замка", 13, MUTED, false)
	_dialogue_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_dialogue_role)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_spacer)
	var ornament := _label("✦", 13, GOLD)
	header.add_child(ornament)

	var divider := ColorRect.new()
	divider.color = Color(0.58, 0.47, 0.3, 0.5)
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(divider)

	_dialogue_line = _label("", 21, IVORY, false)
	_dialogue_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_line.custom_minimum_size = Vector2(800.0, 72.0)
	_dialogue_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_line.add_theme_constant_override("line_spacing", 4)
	text_col.add_child(_dialogue_line)

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(footer)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)
	_dialogue_continue = _label(GameState.dialogue_ui("continue", "E — продолжить"), 12, MUTED, false)
	_dialogue_continue.modulate.a = 0.0
	footer.add_child(_dialogue_continue)


func _build_wallet() -> void:
	_wallet_panel = PanelContainer.new()
	_wallet_panel.name = "WalletPanel"
	_wallet_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_wallet_panel.offset_left = 28.0
	_wallet_panel.offset_right = 430.0
	_wallet_panel.offset_top = -134.0
	_wallet_panel.offset_bottom = -24.0
	var style := _panel_style(PANEL, BORDER, 1, 4, 10)
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	_wallet_panel.add_theme_stylebox_override("panel", style)
	_wallet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_wallet_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	var title := _label(GameState.service_ui("wallet_title", "КОШЕЛЁК"), 10, GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	_wallet_gold_label = _label("", 19, GOLD_BRIGHT, true)
	_wallet_gold_label.name = "WalletGold"
	_wallet_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_wallet_gold_label)

	_add_wallet_rule(vbox)
	_wallet_items_label = _label("", 12, MUTED, false)
	_wallet_items_label.name = "WalletItems"
	_wallet_items_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wallet_items_label.custom_minimum_size = Vector2(0.0, 30.0)
	_wallet_items_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_wallet_items_label)
	var equip_hint := _label("I — снаряжение", 9, MUTED, false)
	equip_hint.name = "WalletEquipmentHint"
	equip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(equip_hint)


func _add_wallet_rule(parent: VBoxContainer) -> void:
	var rule := ColorRect.new()
	rule.color = Color(0.58, 0.47, 0.3, 0.35)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)


func _build_service() -> void:
	_service_root = Control.new()
	_service_root.name = "ServiceRoot"
	_service_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_service_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_root.visible = false
	_ui.add_child(_service_root)

	_service_dim = ColorRect.new()
	_service_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_service_dim.color = Color(0.008, 0.018, 0.026, 0.66)
	_service_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_root.add_child(_service_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_root.add_child(center)

	_service_panel = PanelContainer.new()
	_service_panel.name = "ServicePanel"
	_service_panel.custom_minimum_size = Vector2(940.0, 0.0)
	var panel_style := _panel_style(PANEL_DEEP, Color(0.76, 0.61, 0.35, 0.98), 2, 6, 24)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	panel_style.shadow_size = 18
	_service_panel.add_theme_stylebox_override("panel", panel_style)
	_service_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_service_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	_service_title = _label("", 29, GOLD_BRIGHT, true)
	_service_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_service_title)
	var gold_box := VBoxContainer.new()
	gold_box.add_theme_constant_override("separation", 0)
	gold_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(gold_box)
	var gold_caption := _label(GameState.service_ui("gold", "ЗОЛОТО"), 10, GOLD, true)
	gold_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_box.add_child(gold_caption)
	_service_gold = _label("", 22, IVORY, true)
	_service_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_box.add_child(_service_gold)

	_service_subtitle = _label("", 14, MUTED, false)
	vbox.add_child(_service_subtitle)
	var rule := ColorRect.new()
	rule.color = Color(0.58, 0.47, 0.3, 0.55)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rule)

	_service_tabs = HBoxContainer.new()
	_service_tabs.add_theme_constant_override("separation", 18)
	_service_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_service_tabs)
	_service_tab_buy = _label(GameState.service_ui("buy_mode", "КУПИТЬ"), 15, GOLD_BRIGHT, true)
	_service_tabs.add_child(_service_tab_buy)
	_service_tab_sell = _label(GameState.service_ui("sell_mode", "ПРОДАТЬ"), 15, MUTED, true)
	_service_tabs.add_child(_service_tab_sell)
	var tab_spacer := Control.new()
	tab_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_tabs.add_child(tab_spacer)
	var tab_hint := _label("A/D", 11, MUTED, false)
	tab_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_tabs.add_child(tab_hint)

	_service_columns = HBoxContainer.new()
	_service_columns.add_theme_constant_override("separation", 8)
	_service_columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_service_columns)
	var arrow_space := Control.new()
	arrow_space.custom_minimum_size = Vector2(24.0, 0.0)
	arrow_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_columns.add_child(arrow_space)
	_service_col_name = _label("ТОВАР", 10, MUTED, true)
	_service_col_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_service_columns.add_child(_service_col_name)
	_service_col_price = _label(GameState.service_ui("price", "ЦЕНА"), 10, MUTED, true)
	_service_col_price.custom_minimum_size = Vector2(110.0, 0.0)
	_service_col_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_service_columns.add_child(_service_col_price)
	_service_col_owned = _label(GameState.service_ui("owned", "В СУМКЕ"), 10, MUTED, true)
	_service_col_owned.custom_minimum_size = Vector2(92.0, 0.0)
	_service_col_owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_service_columns.add_child(_service_col_owned)

	_service_list = VBoxContainer.new()
	_service_list.add_theme_constant_override("separation", 6)
	_service_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_list.custom_minimum_size = Vector2(0.0, 150.0)
	vbox.add_child(_service_list)

	_service_description = _label("", 13, MUTED, false)
	_service_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_service_description.custom_minimum_size = Vector2(0.0, 34.0)
	vbox.add_child(_service_description)

	_service_message = _label("", 15, GOLD_BRIGHT, false)
	_service_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_service_message.custom_minimum_size = Vector2(0.0, 24.0)
	vbox.add_child(_service_message)

	var footer_rule := ColorRect.new()
	footer_rule.color = Color(0.58, 0.47, 0.3, 0.35)
	footer_rule.custom_minimum_size = Vector2(0.0, 1.0)
	footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(footer_rule)
	_service_hint = _label("", 12, MUTED, false)
	_service_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_service_hint)


func _build_equipment() -> void:
	_equipment_root = Control.new()
	_equipment_root.name = "EquipmentRoot"
	_equipment_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_equipment_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_root.visible = false
	_ui.add_child(_equipment_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.018, 0.026, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_root.add_child(center)

	_equipment_panel = PanelContainer.new()
	_equipment_panel.name = "EquipmentPanel"
	_equipment_panel.custom_minimum_size = Vector2(1080.0, 610.0)
	var panel_style := _panel_style(PANEL_DEEP, Color(0.76, 0.61, 0.35, 0.98), 2, 6, 22)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	panel_style.shadow_size = 18
	_equipment_panel.add_theme_stylebox_override("panel", panel_style)
	_equipment_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_equipment_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	var title := _label("СНАРЯЖЕНИЕ", 28, GOLD_BRIGHT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var gold_box := VBoxContainer.new()
	gold_box.add_theme_constant_override("separation", 0)
	gold_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(gold_box)
	var gold_caption := _label("ЗОЛОТО", 10, GOLD, true)
	gold_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_box.add_child(gold_caption)
	_equipment_gold = _label("", 20, IVORY, true)
	_equipment_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_box.add_child(_equipment_gold)
	var xp_box := VBoxContainer.new()
	xp_box.add_theme_constant_override("separation", 0)
	xp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(xp_box)
	var xp_caption := _label("ОПЫТ", 10, GOLD, true)
	xp_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_box.add_child(xp_caption)
	_equipment_xp = _label("", 20, IVORY, true)
	_equipment_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_box.add_child(_equipment_xp)

	var subtitle := _label("Оружие и броня меняют атаку, защиту, ловкость и магию. Ряд влияет на урон и защиту от ближних атак.", 13, MUTED, false)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)
	var rule := ColorRect.new()
	rule.color = Color(0.58, 0.47, 0.3, 0.55)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rule)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(content)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430.0, 0.0)
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(left)
	var party_title := _label("ОТРЯД", 11, GOLD, true)
	left.add_child(party_title)
	_equipment_hero_list = VBoxContainer.new()
	_equipment_hero_list.add_theme_constant_override("separation", 6)
	_equipment_hero_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_hero_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_equipment_hero_list)

	var divider := ColorRect.new()
	divider.color = Color(0.58, 0.47, 0.3, 0.35)
	divider.custom_minimum_size = Vector2(1.0, 0.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(right)
	_equipment_hero_name = _label("", 22, IVORY, true)
	right.add_child(_equipment_hero_name)
	_equipment_hero_meta = _label("", 12, MUTED, false)
	right.add_child(_equipment_hero_meta)
	_equipment_stats = _label("", 15, GOLD_BRIGHT, false)
	right.add_child(_equipment_stats)

	_equipment_slots = VBoxContainer.new()
	_equipment_slots.add_theme_constant_override("separation", 5)
	_equipment_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_equipment_slots)
	var captions := ["ОРУЖИЕ", "БРОНЯ", "РЯД"]
	for i in captions.size():
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(0.0, 38.0)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_equipment_slots.add_child(slot_panel)
		_equipment_slot_rows.append(slot_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(row)
		var marker := _label("", 11, GOLD_BRIGHT, false)
		marker.custom_minimum_size = Vector2(20.0, 0.0)
		row.add_child(marker)
		var caption := _label(captions[i], 11, GOLD, true)
		caption.custom_minimum_size = Vector2(82.0, 0.0)
		row.add_child(caption)
		var value := _label("—", 15, IVORY, false)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(value)
		_equipment_slot_values.append(value)

	_equipment_item_title = _label("ДОСТУПНО", 11, GOLD, true)
	right.add_child(_equipment_item_title)
	_equipment_item_list = VBoxContainer.new()
	_equipment_item_list.add_theme_constant_override("separation", 4)
	_equipment_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_item_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_equipment_item_list)
	_equipment_detail = _label("", 12, MUTED, false)
	_equipment_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipment_detail.custom_minimum_size = Vector2(0.0, 58.0)
	right.add_child(_equipment_detail)
	_equipment_message = _label("", 13, GOLD_BRIGHT, false)
	_equipment_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipment_message.custom_minimum_size = Vector2(0.0, 20.0)
	right.add_child(_equipment_message)

	var footer_rule := ColorRect.new()
	footer_rule.color = Color(0.58, 0.47, 0.3, 0.35)
	footer_rule.custom_minimum_size = Vector2(0.0, 1.0)
	footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(footer_rule)
	_equipment_hint = _label("", 12, MUTED, false)
	_equipment_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_equipment_hint)


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.name = "FadeOverlay"
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.012, 0.018, 0.024, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


# ---------------------------------------------------------------------------
# Public API used by Main
# ---------------------------------------------------------------------------

func set_prompt(text: String) -> void:
	if _dialogue_open or _service_open or _equipment_open:
		text = ""
	if text == _last_prompt:
		return
	_last_prompt = text
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if text.strip_edges().is_empty():
		_prompt_tween = create_tween()
		_prompt_tween.tween_property(_prompt_panel, "modulate:a", 0.0, 0.12)
		_prompt_tween.tween_callback(_prompt_panel.hide)
		return
	var display := text
	if display.begins_with("E — "):
		display = display.substr(4)
	elif display.begins_with("E - "):
		display = display.substr(4)
	_prompt_label.text = display
	_prompt_panel.show()
	_prompt_panel.modulate.a = 0.0
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(_prompt_panel, "modulate:a", 1.0, 0.16)
	_prompt_tween.parallel().tween_property(_prompt_panel, "position:y", 0.0, 0.16)


func show_location_card(title: String, subtitle: String) -> void:
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()
	_title_label.text = title.to_upper()
	_subtitle_label.text = subtitle
	_title_holder.visible = true
	_title_holder.modulate.a = 0.0
	var fade := float(GameState.game["ui"]["title_fade"])
	var hold := float(GameState.game["ui"]["title_hold"])
	_title_tween = create_tween()
	_title_tween.tween_property(_title_holder, "modulate:a", 1.0, fade)
	_title_tween.tween_interval(hold)
	_title_tween.tween_property(_title_holder, "modulate:a", 0.0, fade)
	_title_tween.tween_callback(_title_holder.hide)


func show_toast(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = text
	_toast_panel.show()
	_toast_panel.modulate.a = 0.0
	var duration := float(GameState.game["ui"]["toast_duration"])
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.22)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(_toast_panel.hide)


func update_objective(animate: bool = true) -> void:
	_update_objective(animate)


func clear_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.hide()


func _update_objective(animate: bool) -> void:
	if _objective_label == null:
		return
	_objective_label.text = GameState.objective_text()
	if animate:
		_objective_label.modulate = GOLD_BRIGHT
		var tween := create_tween()
		tween.tween_property(_objective_label, "modulate", Color.WHITE, 0.65)


func _on_party_status_changed() -> void:
	_refresh_party_status()
	_refresh_wallet()
	if _service_open:
		_render_service()
	if _equipment_open:
		_render_equipment()


func _refresh_party_status() -> void:
	for i in GameState.party.size():
		if i >= _party_hp_labels.size():
			break
		var member: Dictionary = GameState.party[i]
		var hp := int(member.get("hp", 0))
		var max_hp := int(member.get("max_hp", 1))
		var label: Label = _party_hp_labels[i]
		if GameState.is_member_lost(member):
			label.text = "ПОТЕРЯН"
			label.add_theme_color_override("font_color", Color("#df887a"))
		else:
			label.text = "%d/%d" % [hp, max_hp]
			label.add_theme_color_override("font_color", MUTED if hp >= max_hp else Color("#e8bd79"))


func _refresh_wallet() -> void:
	if _wallet_gold_label == null:
		return
	_wallet_gold_label.text = "%d %s" % [GameState.gold, GameState.currency_short()]
	var entries := GameState.inventory_entries()
	if entries.is_empty():
		_wallet_items_label.text = GameState.service_ui("bag_empty", "Сумка пуста")
	else:
		_wallet_items_label.text = "%s: %s" % [GameState.service_ui("bag", "СУМКА"), GameState.get_inventory_summary_text()]


func get_wallet_gold_text() -> String:
	return _wallet_gold_label.text if _wallet_gold_label != null else ""


func get_wallet_inventory_text() -> String:
	return _wallet_items_label.text if _wallet_items_label != null else ""


# ---------------------------------------------------------------------------
# Equipment menu
# ---------------------------------------------------------------------------

func is_equipment_open() -> bool:
	return _equipment_open


func open_equipment() -> void:
	if _equipment_open:
		return
	_equipment_open = true
	_equipment_hero_index = 0
	_equipment_slot_index = 0
	_equipment_picking = false
	_equipment_item_index = 0
	_equipment_item_ids.clear()
	_equipment_current_entries.clear()
	_equipment_message.text = ""
	_equipment_root.visible = true
	_equipment_root.modulate.a = 1.0
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()
	_title_holder.hide()
	set_prompt("")
	_render_equipment()


func close_equipment(announce: bool = true) -> void:
	if not _equipment_open:
		return
	_equipment_open = false
	_equipment_root.visible = false
	if announce:
		equipment_closed.emit()


func equipment_move_vertical(delta: int) -> void:
	if not _equipment_open or delta == 0:
		return
	if _equipment_picking:
		if _equipment_item_ids.is_empty():
			return
		_equipment_item_index = wrapi(_equipment_item_index + delta, 0, _equipment_item_ids.size())
	else:
		if GameState.party.is_empty():
			return
		_equipment_hero_index = wrapi(_equipment_hero_index + delta, 0, GameState.party.size())
		_equipment_picking = false
		_equipment_message.text = ""
	_render_equipment()


func equipment_move_horizontal(delta: int) -> void:
	if not _equipment_open or _equipment_picking or delta == 0:
		return
	_equipment_slot_index = wrapi(_equipment_slot_index + delta, 0, 3)
	_equipment_message.text = ""
	_render_equipment()


func equipment_confirm() -> Dictionary:
	if not _equipment_open:
		return {"ok": false, "message": ""}
	var member_id := get_equipment_selected_member_id()
	if member_id.is_empty():
		return {"ok": false, "message": ""}
	if _equipment_picking:
		if _equipment_item_ids.is_empty():
			return {"ok": false, "message": ""}
		var item_id := _equipment_item_ids[_equipment_item_index]
		var slot_name := "weapon" if _equipment_slot_index == 0 else "armor"
		var result: Dictionary
		if item_id.is_empty():
			result = GameState.unequip_item(member_id, slot_name)
		else:
			result = GameState.equip_item(member_id, slot_name, item_id)
		_equipment_picking = false
		_equipment_message.text = str(result.get("message", ""))
		_set_equipment_message_color(bool(result.get("ok", false)))
		_render_equipment()
		return result
	if _equipment_slot_index == 2:
		var before := GameState.get_member_row(member_id)
		GameState.toggle_member_row(member_id)
		var after := GameState.get_member_row(member_id)
		_equipment_message.text = "Ряд: %s." % _equipment_row_name(after).to_lower()
		_set_equipment_message_color(true)
		_render_equipment()
		return {"ok": after != before, "message": _equipment_message.text}
	_rebuild_equipment_choices(member_id, _equipment_slot_index)
	if _equipment_item_ids.is_empty():
		_equipment_message.text = "В сумке нет подходящего снаряжения."
		_set_equipment_message_color(false)
		_render_equipment()
		return {"ok": false, "message": _equipment_message.text}
	_equipment_picking = true
	_equipment_item_index = 0
	_equipment_message.text = ""
	_render_equipment()
	return {"ok": true, "message": ""}


func equipment_cancel() -> void:
	if not _equipment_open:
		return
	if _equipment_picking:
		_equipment_picking = false
		_equipment_message.text = ""
		_render_equipment()
		return
	close_equipment()


func get_equipment_selected_member_id() -> String:
	if GameState.party.is_empty():
		return ""
	_equipment_hero_index = clampi(_equipment_hero_index, 0, GameState.party.size() - 1)
	return str(GameState.party[_equipment_hero_index].get("id", ""))


func get_equipment_slot_index() -> int:
	return _equipment_slot_index


func is_equipment_picking() -> bool:
	return _equipment_picking


func get_equipment_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id: String in _equipment_item_ids:
		result.append(item_id)
	return result


func get_equipment_item_index() -> int:
	return _equipment_item_index


func get_equipment_message_text() -> String:
	return _equipment_message.text if _equipment_message != null else ""


func get_equipment_detail_text() -> String:
	return _equipment_detail.text if _equipment_detail != null else ""


func _render_equipment() -> void:
	if not _equipment_open:
		return
	_equipment_gold.text = "%d %s" % [GameState.gold, GameState.currency_short()]
	_equipment_xp.text = str(GameState.experience)
	if GameState.party.is_empty():
		return
	_equipment_hero_index = clampi(_equipment_hero_index, 0, GameState.party.size() - 1)
	var member: Dictionary = GameState.party[_equipment_hero_index]
	var member_id := str(member.get("id", ""))
	var selected_row := GameState.get_member_row(member_id)
	_equipment_hero_name.text = str(member.get("name", ""))
	_equipment_hero_meta.text = "%s · %s" % [
		str(member.get("class_name", "")).to_upper(),
		_equipment_row_name(selected_row)
	]
	var stats := GameState.get_effective_stats(member_id)
	_equipment_stats.text = "АТК %d     ЗАЩ %d     ЛОВ %d     МАГ %d" % [
		int(stats.get("attack", 0)),
		int(stats.get("defense", 0)),
		int(stats.get("agility", 0)),
		int(stats.get("magic", 0))
	]
	_render_equipment_hero_cards()
	_render_equipment_slots(member_id)
	_equipment_hint.text = "W/S — предмет    E — надеть/снять    Esc — назад" if _equipment_picking else "W/S — герой    A/D — слот    E — выбрать снаряжение    Esc — закрыть"
	_render_equipment_items(member_id)


func _render_equipment_hero_cards() -> void:
	for child: Node in _equipment_hero_list.get_children():
		_equipment_hero_list.remove_child(child)
		child.queue_free()
	for i in GameState.party.size():
		var member: Dictionary = GameState.party[i]
		var member_id := str(member.get("id", ""))
		var stats := GameState.get_effective_stats(member_id)
		var selected := i == _equipment_hero_index
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0.0, 61.0)
		var style := _panel_style(
			Color(0.10, 0.15, 0.19, 0.96) if selected else Color(0.045, 0.075, 0.095, 0.9),
			GOLD_BRIGHT if selected else Color(0.4, 0.35, 0.26, 0.55),
			2 if selected else 1,
			3,
			7
		)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
		card.add_theme_stylebox_override("panel", style)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_equipment_hero_list.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(top)
		var name_label := _label(("▶ " if selected else "") + str(member.get("name", "")), 15, IVORY if selected else MUTED, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		var row_label := _label(_equipment_row_name(GameState.get_member_row(member_id)), 9, GOLD if selected else MUTED, true)
		top.add_child(row_label)
		var bottom := _label("%s · АТК %d · ЗАЩ %d · ЛОВ %d" % [
			str(member.get("class_name", "")),
			int(stats.get("attack", 0)),
			int(stats.get("defense", 0)),
			int(stats.get("agility", 0))
		], 11, MUTED, false)
		box.add_child(bottom)


func _render_equipment_slots(member_id: String) -> void:
	var equipped_weapon := GameState.get_equipped_item_id(member_id, "weapon")
	var equipped_armor := GameState.get_equipped_item_id(member_id, "armor")
	var values := [
		GameState.get_item_name(equipped_weapon) if not equipped_weapon.is_empty() else "—",
		GameState.get_item_name(equipped_armor) if not equipped_armor.is_empty() else "—",
		_equipment_row_description(GameState.get_member_row(member_id))
	]
	for i in _equipment_slot_rows.size():
		var selected := i == _equipment_slot_index
		var row := _equipment_slot_rows[i]
		row.add_theme_stylebox_override("panel", _service_row_style(selected))
		var hbox := row.get_child(0) as HBoxContainer
		var marker := hbox.get_child(0) as Label
		marker.text = "▶" if selected else ""
		var value: Label = _equipment_slot_values[i]
		value.text = str(values[i])
		value.add_theme_color_override("font_color", IVORY if selected else MUTED)


func _render_equipment_items(member_id: String) -> void:
	for child: Node in _equipment_item_list.get_children():
		_equipment_item_list.remove_child(child)
		child.queue_free()
	_equipment_item_ids.clear()
	_equipment_current_entries.clear()
	if _equipment_slot_index == 2:
		_equipment_item_title.text = "РЯД"
		var row_help := _label("Передний ряд наносит и получает полный урон. Задний ряд бьёт слабее, но получает меньше от ближних атак.", 13, MUTED, false)
		row_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_help.custom_minimum_size = Vector2(0.0, 54.0)
		_equipment_item_list.add_child(row_help)
		_equipment_detail.text = "E — переключить ряд. Задний ряд безопаснее для магов и лекарей."
		return
	var slot_name := "weapon" if _equipment_slot_index == 0 else "armor"
	var item_word := "ОРУЖИЕ" if slot_name == "weapon" else "БРОНЯ"
	_equipment_item_title.text = ("ВЫБЕРИТЕ: " + item_word) if _equipment_picking else (item_word + " В СУМКЕ")
	_rebuild_equipment_choices(member_id, _equipment_slot_index)
	if _equipment_current_entries.is_empty():
		var empty := _label("В сумке нет подходящего снаряжения.", 13, MUTED, false)
		_equipment_item_list.add_child(empty)
		_equipment_detail.text = "Купите снаряжение в лавке или снимите его с другого героя."
		return
	for i in _equipment_current_entries.size():
		var entry: Dictionary = _equipment_current_entries[i]
		var selected := _equipment_picking and i == _equipment_item_index
		var is_remove := str(entry.get("id", "")).is_empty()
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0.0, 38.0)
		panel.add_theme_stylebox_override("panel", _service_row_style(selected))
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_equipment_item_list.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var marker := _label("▶" if selected else "", 11, GOLD_BRIGHT, false)
		marker.custom_minimum_size = Vector2(20.0, 0.0)
		row.add_child(marker)
		var name_label := _label(str(entry.get("name", "")), 14, Color("#d8b8a1") if is_remove else IVORY, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var detail := _label(str(entry.get("detail", "")), 11, MUTED, false)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(detail)
	_update_equipment_detail(member_id, slot_name)


func _rebuild_equipment_choices(member_id: String, slot_index: int) -> void:
	_equipment_item_ids.clear()
	_equipment_current_entries.clear()
	if slot_index > 1:
		return
	var slot_name := "weapon" if slot_index == 0 else "armor"
	var equipped := GameState.get_equipped_item_id(member_id, slot_name)
	for entry: Dictionary in GameState.get_equipment_entries(slot_name):
		var item_id := str(entry.get("id", ""))
		var count := int(entry.get("count", 0))
		_equipment_item_ids.append(item_id)
		_equipment_current_entries.append({
			"id": item_id,
			"name": str(entry.get("name", item_id)),
			"description": str(entry.get("description", "")),
			"stats": (entry.get("stats", {}) as Dictionary).duplicate(true),
			"count": count,
			"detail": "×%d   %s" % [count, _equipment_stat_summary(entry.get("stats", {}))]
		})
	if not equipped.is_empty():
		_equipment_item_ids.append("")
		_equipment_current_entries.append({
			"id": "",
			"name": "— Снять —",
			"description": "Вернуть надетый предмет в сумку.",
			"stats": {},
			"count": 0,
			"detail": GameState.get_item_name(equipped)
		})
	if _equipment_picking and not _equipment_item_ids.is_empty():
		_equipment_item_index = clampi(_equipment_item_index, 0, _equipment_item_ids.size() - 1)


func _update_equipment_detail(member_id: String, slot_name: String) -> void:
	if _equipment_detail == null:
		return
	var current_id := GameState.get_equipped_item_id(member_id, slot_name)
	if _equipment_picking and not _equipment_current_entries.is_empty():
		var entry: Dictionary = _equipment_current_entries[clampi(_equipment_item_index, 0, _equipment_current_entries.size() - 1)]
		var candidate_id := str(entry.get("id", ""))
		var before := GameState.get_effective_stats(member_id)
		var after := _equipment_stats_with(member_id, slot_name, candidate_id)
		var delta := _equipment_delta_text(before, after)
		if candidate_id.is_empty():
			var current_name := GameState.get_item_name(current_id) if not current_id.is_empty() else "пусто"
			_equipment_detail.text = "Снять: %s. %s" % [current_name, delta]
		else:
			var description := str(entry.get("description", ""))
			if description.is_empty():
				description = "Без описания."
			_equipment_detail.text = "%s  ·  в сумке ×%d\n%s\n%s" % [
				str(entry.get("name", candidate_id)),
				int(entry.get("count", 1)),
				description,
				delta
			]
		return
	var current := GameState.get_item(current_id) if not current_id.is_empty() else {}
	if current.is_empty():
		_equipment_detail.text = "Слот пуст. Нажмите E, чтобы выбрать предмет из сумки."
	else:
		var description := str(current.get("description", ""))
		if description.is_empty():
			description = "Без описания."
		_equipment_detail.text = "Надето: %s\n%s\n%s" % [
			GameState.get_item_name(current_id),
			description,
			_equipment_stat_summary(current.get("stats", {}))
		]


func _equipment_stats_with(member_id: String, slot_name: String, item_id: String) -> Dictionary:
	var member := GameState.member_by_id(member_id)
	var result := {"attack": 0, "defense": 0, "agility": 0, "magic": 0}
	if member.is_empty():
		return result
	var base: Dictionary = member.get("base_stats", {})
	for key: String in result.keys():
		result[key] = int(base.get(key, 0))
	for slot: String in ["weapon", "armor"]:
		var equipped_id := item_id if slot == slot_name else GameState.get_equipped_item_id(member_id, slot)
		if equipped_id.is_empty():
			continue
		var item_stats: Dictionary = GameState.get_item(equipped_id).get("stats", {})
		for key: String in result.keys():
			result[key] = int(result[key]) + int(item_stats.get(key, 0))
	return result


func _equipment_delta_text(before: Dictionary, after: Dictionary) -> String:
	var labels := {"attack": "АТК", "defense": "ЗАЩ", "agility": "ЛОВ", "magic": "МАГ"}
	var parts: PackedStringArray = []
	for key: String in ["attack", "defense", "agility", "magic"]:
		var diff := int(after.get(key, 0)) - int(before.get(key, 0))
		if diff == 0:
			continue
		parts.append("%+d %s" % [diff, str(labels[key])])
	if parts.is_empty():
		return "характеристики не изменятся."
	return "изменение: " + "  ".join(parts)


func _equipment_stat_summary(stats: Dictionary) -> String:
	var parts: PackedStringArray = []
	var labels := {"attack": "АТК", "defense": "ЗАЩ", "agility": "ЛОВ", "magic": "МАГ"}
	for key: String in ["attack", "defense", "agility", "magic"]:
		var value := int(stats.get(key, 0))
		if value == 0:
			continue
		parts.append("%+d %s" % [value, str(labels[key])])
	if parts.is_empty():
		return "без бонусов"
	return "  ".join(parts)


func _equipment_row_name(row: String) -> String:
	return GameState.get_combat_ui("back" if row == "back" else "front", "ЗАДНИЙ" if row == "back" else "ПЕРЕДНИЙ")


func _equipment_row_description(row: String) -> String:
	var row_cfg: Dictionary = GameState.combat.get("row", {})
	var dealt: Dictionary = row_cfg.get("damage_dealt", {})
	var taken: Dictionary = row_cfg.get("melee_damage_taken", {})
	var dealt_mult := float(dealt.get(row, 1.0))
	var taken_mult := float(taken.get(row, 1.0))
	return "%s · урон %d%% · ближний %d%%" % [
		_equipment_row_name(row),
		roundi(dealt_mult * 100.0),
		roundi(taken_mult * 100.0)
	]


func _set_equipment_message_color(ok: bool) -> void:
	_equipment_message.add_theme_color_override("font_color", Color("#a9d492") if ok else Color("#e19a8b"))


# ---------------------------------------------------------------------------
# House services: inn, shops and clinic
# ---------------------------------------------------------------------------

func is_service_open() -> bool:
	return _service_open


func open_service(service_id: String) -> void:
	var service := GameState.get_service(service_id)
	if service.is_empty():
		return
	_service_open = true
	_service_id = service_id
	_service_data = service
	_service_mode = "buy"
	_service_index = 0
	_service_entries.clear()
	_service_lost_ids.clear()
	_service_title.text = str(service.get("title", "УСЛУГИ"))
	_service_subtitle.text = str(service.get("subtitle", service.get("description", "")))
	_service_message.text = ""
	var service_type := str(service.get("type", ""))
	_service_tabs.visible = service_type == "shop"
	_service_columns.visible = service_type == "shop"
	if service_type == "shop":
		_service_hint.text = GameState.service_ui("shop_hint", "↑/↓ — выбор    ←/→ — купить / продать    E — сделка    Esc — выйти")
	elif service_type == "clinic":
		_service_hint.text = GameState.service_ui("clinic_hint", "↑/↓ — выбрать героя    E — лечить    Esc — выйти")
	else:
		_service_hint.text = GameState.service_ui("inn_hint", "E — оплатить ночлег    Esc — выйти")
	_service_root.visible = true
	_service_root.modulate.a = 1.0
	_service_gold.text = "%d %s" % [GameState.gold, GameState.currency_short()]
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()
	_title_holder.hide()
	set_prompt("")
	_render_service()


func close_service(announce: bool = true) -> void:
	if not _service_open:
		return
	_service_open = false
	_service_root.visible = false
	if announce:
		service_closed.emit()


func service_move(delta: int) -> void:
	if not _service_open or delta == 0:
		return
	var service_type := str(_service_data.get("type", ""))
	if service_type == "shop":
		if _service_entries.is_empty():
			return
		_service_index = wrapi(_service_index + delta, 0, _service_entries.size())
		_render_service()
	elif service_type == "clinic":
		if _service_lost_ids.is_empty():
			return
		_service_index = wrapi(_service_index + delta, 0, _service_lost_ids.size())
		_render_service()


func service_toggle_mode() -> void:
	if not _service_open or str(_service_data.get("type", "")) != "shop":
		return
	_service_mode = "sell" if _service_mode == "buy" else "buy"
	_service_index = 0
	_service_message.text = ""
	_render_service()


func service_confirm() -> Dictionary:
	if not _service_open:
		return {"ok": false, "message": ""}
	var service_type := str(_service_data.get("type", ""))
	var result: Dictionary = {"ok": false, "message": ""}
	if service_type == "shop":
		if _service_entries.is_empty():
			var empty_text := GameState.service_ui("no_stock", "Нет товаров.") if _service_mode == "buy" else GameState.service_ui("no_sell_items", "Нечего продавать.")
			_set_service_message(empty_text, false)
			_render_service()
			return {"ok": false, "message": empty_text}
		var entry: Dictionary = _service_entries[_service_index]
		var item_id := str(entry.get("id", ""))
		if _service_mode == "buy":
			result = GameState.buy_item(_service_id, item_id)
		else:
			result = GameState.sell_item(_service_id, item_id)
		_set_service_message(str(result.get("message", "")), bool(result.get("ok", false)))
		_render_service()
	elif service_type == "inn":
		result = GameState.use_inn(_service_id)
		_set_service_message(str(result.get("message", "")), bool(result.get("ok", false)))
		_render_service()
	elif service_type == "clinic":
		if _service_lost_ids.is_empty():
			var no_lost := GameState.service_ui("no_lost", "В отряде нет потерянных героев.")
			_set_service_message(no_lost, false)
			_render_service()
			return {"ok": false, "message": no_lost}
		var member_id := _service_lost_ids[_service_index]
		result = GameState.use_clinic(_service_id, member_id)
		_set_service_message(str(result.get("message", "")), bool(result.get("ok", false)))
		_render_service()
	return result


func get_service_visible_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _service_entries:
		result.append(entry.duplicate(true))
	return result


func get_service_message_text() -> String:
	return _service_message.text


func get_service_index() -> int:
	return _service_index


func get_service_mode() -> String:
	return _service_mode


func _render_service() -> void:
	if not _service_open:
		return
	_service_gold.text = "%d %s" % [GameState.gold, GameState.currency_short()]
	var service_type := str(_service_data.get("type", ""))
	if service_type == "shop":
		_service_tab_buy.text = ("▶ " if _service_mode == "buy" else "   ") + GameState.service_ui("buy_mode", "КУПИТЬ")
		_service_tab_sell.text = ("▶ " if _service_mode == "sell" else "   ") + GameState.service_ui("sell_mode", "ПРОДАТЬ")
		_service_tab_buy.add_theme_color_override("font_color", GOLD_BRIGHT if _service_mode == "buy" else MUTED)
		_service_tab_sell.add_theme_color_override("font_color", GOLD_BRIGHT if _service_mode == "sell" else MUTED)
		_service_entries = GameState.get_shop_entries(_service_id, _service_mode)
		_clear_service_rows()
		if _service_entries.is_empty():
			_service_index = 0
			_add_empty_service_row(GameState.service_ui("no_stock", "Нет товаров.") if _service_mode == "buy" else GameState.service_ui("no_sell_items", "Нечего продавать."))
			_service_description.text = str(_service_data.get("description", ""))
		else:
			_service_index = clampi(_service_index, 0, _service_entries.size() - 1)
			for i in _service_entries.size():
				_add_shop_row(_service_entries[i], i == _service_index)
			var selected: Dictionary = _service_entries[_service_index]
			_service_description.text = str(selected.get("description", ""))
	elif service_type == "inn":
		_clear_service_rows()
		for member: Dictionary in GameState.party:
			_add_inn_row(member)
		var price := int(_service_data.get("price", 0))
		_service_description.text = "%s  Стоимость: %d %s." % [str(_service_data.get("description", "")), price, GameState.currency_short()]
	elif service_type == "clinic":
		var lost := GameState.get_lost_members()
		_service_lost_ids.clear()
		for member: Dictionary in lost:
			_service_lost_ids.append(str(member.get("id", "")))
		_clear_service_rows()
		if _service_lost_ids.is_empty():
			_service_index = 0
			_add_empty_service_row(GameState.service_ui("no_lost", "В отряде нет потерянных героев."))
		else:
			_service_index = clampi(_service_index, 0, _service_lost_ids.size() - 1)
			for i in _service_lost_ids.size():
				_add_clinic_row(GameState.member_by_id(_service_lost_ids[i]), i == _service_index)
		var price := int(_service_data.get("price", 0))
		_service_description.text = "%s  Лечение одного героя: %d %s." % [str(_service_data.get("description", "")), price, GameState.currency_short()]


func _set_service_message(text: String, ok: bool) -> void:
	_service_message.text = text
	_service_message.add_theme_color_override("font_color", Color("#a9d492") if ok else Color("#e19a8b"))


func _clear_service_rows() -> void:
	for child: Node in _service_list.get_children():
		_service_list.remove_child(child)
		child.queue_free()


func _service_row_style(selected: bool) -> StyleBoxFlat:
	var style := _panel_style(
		Color(0.10, 0.15, 0.19, 0.96) if selected else Color(0.045, 0.075, 0.095, 0.9),
		GOLD_BRIGHT if selected else Color(0.4, 0.35, 0.26, 0.55),
		1,
		3,
		6
	)
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _service_row_panel(selected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 38.0)
	panel.add_theme_stylebox_override("panel", _service_row_style(selected))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_list.add_child(panel)
	return panel


func _service_row_marker(parent: HBoxContainer, selected: bool) -> void:
	var marker := _label("▶" if selected else "", 11, GOLD_BRIGHT, false)
	marker.custom_minimum_size = Vector2(24.0, 0.0)
	parent.add_child(marker)


func _add_shop_row(entry: Dictionary, selected: bool) -> void:
	var panel := _service_row_panel(selected)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	_service_row_marker(row, selected)
	var name_label := _label(str(entry.get("name", "")), 16, IVORY, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var price_label := _label("%d %s" % [int(entry.get("price", 0)), GameState.currency_short()], 15, GOLD_BRIGHT, false)
	price_label.custom_minimum_size = Vector2(110.0, 0.0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_label)
	var owned_label := _label("×%d" % int(entry.get("owned", 0)), 12, MUTED, false)
	owned_label.custom_minimum_size = Vector2(92.0, 0.0)
	owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(owned_label)


func _add_inn_row(member: Dictionary) -> void:
	var panel := _service_row_panel(false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	_service_row_marker(row, false)
	var name_label := _label(str(member.get("name", "")), 16, IVORY, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var class_label := _label(str(member.get("class_name", "")).to_upper(), 11, MUTED, false)
	class_label.custom_minimum_size = Vector2(125.0, 0.0)
	row.add_child(class_label)
	var hp := int(member.get("hp", 0))
	var max_hp := int(member.get("max_hp", 1))
	var hp_label := _label("HP %d/%d" % [hp, max_hp], 13, MUTED if hp >= max_hp else Color("#e19a8b"), false)
	hp_label.custom_minimum_size = Vector2(120.0, 0.0)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(hp_label)


func _add_clinic_row(member: Dictionary, selected: bool) -> void:
	var panel := _service_row_panel(selected)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	_service_row_marker(row, selected)
	var name_label := _label(str(member.get("name", "")), 16, IVORY, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var class_label := _label(str(member.get("class_name", "")).to_upper(), 11, MUTED, false)
	class_label.custom_minimum_size = Vector2(125.0, 0.0)
	row.add_child(class_label)
	var status_label := _label("ПОТЕРЯН", 13, Color("#e19a8b"), true)
	status_label.custom_minimum_size = Vector2(120.0, 0.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(status_label)


func _add_empty_service_row(text: String) -> void:
	var panel := _service_row_panel(false)
	var label := _label(text, 14, MUTED, false)
	panel.add_child(label)


func is_dialogue_open() -> bool:
	return _dialogue_open


func is_story_open() -> bool:
	return _dialogue_open and _story_mode


func open_dialogue(data: Dictionary) -> void:
	if data.is_empty():
		return
	_story_mode = false
	_story_lines.clear()
	_story_index = 0
	_dialogue_open = true
	_present_dialogue(data)


func open_story(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		return
	_story_mode = true
	_story_lines.clear()
	for line: Dictionary in lines:
		_story_lines.append(line.duplicate(true))
	_story_index = 0
	_dialogue_open = true
	_present_dialogue(_story_lines[0])


func _present_dialogue(data: Dictionary) -> void:
	_dialogue_full_text = str(data.get("line", ""))
	_dialogue_typed = 0.0
	_dialogue_name.text = str(data.get("speaker", ""))
	_dialogue_role.text = str(data.get("role", ""))
	_dialogue_accent = Color(str(data.get("accent", "#d5b16b")))
	_dialogue_monogram.text = str(data.get("speaker", "?")).substr(0, 1)
	_dialogue_monogram.add_theme_color_override("font_color", _dialogue_accent)
	var portrait_style := _panel_style(Color(0.08, 0.12, 0.15, 0.95), _dialogue_accent, 2, 3, 4)
	_dialogue_monogram_panel.add_theme_stylebox_override("panel", portrait_style)
	_dialogue_name.add_theme_color_override("font_color", _dialogue_accent.lightened(0.22))
	_dialogue_line.text = _dialogue_full_text
	_dialogue_line.visible_characters = 0
	_dialogue_continue.modulate.a = 0.0
	_dialogue_panel.show()
	_dialogue_panel.modulate.a = 0.0
	if _dialogue_tween != null and _dialogue_tween.is_valid():
		_dialogue_tween.kill()
	_dialogue_tween = create_tween()
	_dialogue_tween.tween_property(_dialogue_panel, "modulate:a", 1.0, 0.2)
	set_prompt("")


func advance_dialogue() -> String:
	if not _dialogue_open:
		return "none"
	if _dialogue_line.visible_characters < _dialogue_full_text.length():
		_dialogue_typed = float(_dialogue_full_text.length())
		_dialogue_line.visible_characters = _dialogue_full_text.length()
		_dialogue_continue.modulate.a = 0.82
		return "revealed"
	if _story_mode:
		_story_index += 1
		if _story_index < _story_lines.size():
			_present_dialogue(_story_lines[_story_index])
			return "story"
		_close_dialogue(true)
		return "story_finished"
	_close_dialogue()
	return "closed"


func _close_dialogue(story: bool = false) -> void:
	_dialogue_open = false
	_story_mode = false
	_story_lines.clear()
	if _dialogue_tween != null and _dialogue_tween.is_valid():
		_dialogue_tween.kill()
	_dialogue_tween = create_tween()
	_dialogue_tween.tween_property(_dialogue_panel, "modulate:a", 0.0, 0.16)
	_dialogue_tween.tween_callback(_dialogue_panel.hide)
	if story:
		story_finished.emit()
	else:
		dialogue_closed.emit()


func fade_to_black(duration: float) -> void:
	_fade.visible = true
	if _fade_alpha() >= 0.999:
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration)
	await tween.finished


func fade_from_black(duration: float) -> void:
	_fade.visible = true
	if duration <= 0.0:
		_fade.color.a = 0.0
		_fade.hide()
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)
	await tween.finished
	_fade.hide()


func is_fading() -> bool:
	return _fade.visible and _fade.color.a > 0.01


# ---------------------------------------------------------------------------
# Small UI helpers
# ---------------------------------------------------------------------------

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
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", _font_bold if bold else _font_body)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _fade_alpha() -> float:
	return _fade.color.a if _fade != null else 0.0
