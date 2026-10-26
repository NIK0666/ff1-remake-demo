extends CanvasLayer

var data: Dictionary
var ui: Dictionary
var math: Dictionary
var root: Control
var location_title: Label
var location_subtitle: Label
var objective: Label
var objective_hint: Label
var prompt: Panel
var prompt_text: Label
var dialogue: Panel
var dialogue_eyebrow: Label
var dialogue_name: Label
var dialogue_text: Label
var dialogue_hint: Label
var banner: Panel
var banner_title: Label
var banner_subtitle: Label
var banner_tween: Tween
var scrim: ColorRect
var resource_label: Label
var hero_hp_labels: Array = []
var end_card: Control


func _init(config: Dictionary) -> void:
	data = config
	ui = data.settings.interface
	math = data.settings.math


func _style(background: String, bordered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(str(ui.colors[background]))
	style.set_corner_radius_all(int(ui.panel_radius))
	style.set_border_width_all(int(ui.panel_border) if bordered else int(math.zero))
	style.border_color = Color.html(str(ui.colors.border))
	style.shadow_color = Color.html(str(ui.colors.ink))
	style.shadow_color.a = float(math.shadow_alpha)
	style.shadow_size = int(ui.small_margin)
	style.shadow_offset = Vector2i(int(math.zero), int(ui.party_stripe_width))
	return style


func _panel(parent: Control, position_value: Vector2, dimensions: Vector2, background: String, bordered: bool) -> Panel:
	var panel := Panel.new()
	panel.position = position_value
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(background, bordered))
	parent.add_child(panel)
	return panel


func _label(parent: Control, text: String, position_value: Vector2, dimensions: Vector2, font_size: float, color_name: String) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_value
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(font_size))
	label.add_theme_color_override("font_color", Color.html(str(ui.colors[color_name])))
	parent.add_child(label)
	return label


func _ready() -> void:
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_location()
	_build_quest()
	_build_party()
	_build_controls()
	_build_prompt()
	_build_dialogue()
	_build_banner()
	scrim = ColorRect.new()
	scrim.color = Color.html(str(ui.colors.scrim))
	scrim.modulate.a = math.zero
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	_build_end_card()


func _build_location() -> void:
	var dimensions := Vector2(ui.location_width, ui.location_height)
	var panel: Panel = _panel(root, Vector2.ONE * float(ui.margin), dimensions, "panel", true)
	_label(panel, "FINAL FANTASY I", Vector2(ui.small_margin, ui.small_margin), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.eyebrow_size), ui.eyebrow_size, "gold")
	location_title = _label(panel, "", Vector2(ui.small_margin, float(ui.small_margin) + float(ui.eyebrow_size)), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.title_size), ui.title_size, "text")
	location_subtitle = _label(panel, "", Vector2(ui.small_margin, dimensions.y - float(ui.small_margin) - float(ui.subtitle_size)), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.subtitle_size), ui.subtitle_size, "muted")


func _build_quest() -> void:
	var dimensions := Vector2(ui.quest_width, ui.quest_height)
	var panel: Panel = _panel(root, Vector2.ZERO, dimensions, "panel", true)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -dimensions.x - float(ui.margin)
	panel.offset_right = -float(ui.margin)
	panel.offset_top = float(ui.margin)
	panel.offset_bottom = dimensions.y + float(ui.margin)
	_label(panel, "ЛЕТОПИСЬ ПУТИ", Vector2(ui.small_margin, ui.small_margin), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.eyebrow_size), ui.eyebrow_size, "gold")
	objective = _label(panel, str(data.objective.initial), Vector2(ui.small_margin, float(ui.small_margin) + float(ui.eyebrow_size)), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.title_size), ui.body_size, "text")
	objective_hint = _label(panel, str(data.objective.hint), Vector2(ui.small_margin, dimensions.y - float(ui.small_margin) - float(ui.subtitle_size)), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.subtitle_size), ui.small_size, "muted")


func _build_party() -> void:
	var resource_panel: Panel = _panel(root, Vector2(float(ui.margin), float(ui.margin) + float(ui.location_height) + float(ui.small_margin)), Vector2(ui.resource_width, ui.resource_height), "panel", true)
	resource_label = _label(resource_panel, "", Vector2(ui.small_margin, math.zero), Vector2(float(ui.resource_width) - float(ui.small_margin) * math.double, ui.resource_height), ui.body_size, "gold")
	var chip_width: float = float(ui.party_chip_width)
	var width: float = chip_width * float(data.party.heroes.size()) + float(ui.party_gap) * float(data.party.heroes.size() - int(math.one)) + float(ui.small_margin) * math.double
	var dimensions := Vector2(width, ui.party_height)
	var panel: Panel = _panel(root, Vector2.ZERO, dimensions, "panel", true)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = float(ui.margin)
	panel.offset_right = width + float(ui.margin)
	panel.offset_top = -dimensions.y - float(ui.margin)
	panel.offset_bottom = -float(ui.margin)
	_label(panel, "ОТРЯД СВЕТА", Vector2(ui.small_margin, float(ui.small_margin) * math.half), Vector2(width, ui.eyebrow_size), ui.eyebrow_size, "gold")
	for index in range(data.party.heroes.size()):
		var hero: Dictionary = data.party.heroes[index]
		var x: float = float(ui.small_margin) + float(index) * (chip_width + float(ui.party_gap))
		var y: float = float(ui.small_margin) * math.double + float(ui.eyebrow_size) * math.half
		var chip: Panel = _panel(panel, Vector2(x, y), Vector2(chip_width, ui.party_chip_height), "panel_soft", false)
		var stripe: Panel = _panel(chip, Vector2.ZERO, Vector2(ui.party_stripe_width, ui.party_chip_height), "panel_soft", false)
		var stripe_style := _style("panel_soft", false)
		stripe_style.bg_color = Color.html(str(data.palette[hero.color]))
		stripe.add_theme_stylebox_override("panel", stripe_style)
		_label(chip, str(hero.rank), Vector2(ui.small_margin, math.zero), Vector2(float(ui.small_margin) * math.double, ui.party_chip_height), ui.body_size, "gold")
		_label(chip, str(hero.name), Vector2(float(ui.small_margin) * (math.one + math.double), math.zero), Vector2(chip_width - float(ui.small_margin) * (math.one + math.double), ui.party_name_height), ui.body_size, "text")
		var hp: Label = _label(chip, "", Vector2(float(ui.small_margin) * (math.one + math.double), ui.party_name_height), Vector2(chip_width - float(ui.small_margin) * (math.one + math.double), ui.party_hp_height), ui.small_size, "muted")
		hero_hp_labels.append(hp)


func _build_controls() -> void:
	var dimensions := Vector2(ui.service_width, ui.controls_height)
	var label: Label = _label(root, "WASD / стрелки — идти    E — действие    I — инвентарь", Vector2.ZERO, dimensions, ui.small_size, "muted")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -dimensions.x - float(ui.margin)
	label.offset_right = -float(ui.margin)
	label.offset_top = -dimensions.y - float(ui.margin)
	label.offset_bottom = -float(ui.margin)


func _build_prompt() -> void:
	var dimensions := Vector2(ui.prompt_width, ui.prompt_height)
	prompt = _panel(root, Vector2.ZERO, dimensions, "panel", true)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -dimensions.x * math.half
	prompt.offset_right = dimensions.x * math.half
	prompt.offset_top = -float(ui.dialogue_offset) - dimensions.y
	prompt.offset_bottom = -float(ui.dialogue_offset)
	prompt_text = _label(prompt, "", Vector2(ui.small_margin, math.zero), Vector2(dimensions.x - float(ui.small_margin) * math.double, dimensions.y), ui.body_size, "text")
	prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.hide()


func _build_dialogue() -> void:
	var dimensions := Vector2(ui.dialogue_width, ui.dialogue_height)
	dialogue = _panel(root, Vector2.ZERO, dimensions, "panel", true)
	dialogue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue.offset_left = -dimensions.x * math.half
	dialogue.offset_right = dimensions.x * math.half
	dialogue.offset_top = -float(ui.dialogue_offset) - dimensions.y
	dialogue.offset_bottom = -float(ui.dialogue_offset)
	dialogue_eyebrow = _label(dialogue, str(data.dialogue.talk_eyebrow), Vector2(ui.small_margin, ui.small_margin), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.eyebrow_size), ui.eyebrow_size, "gold")
	dialogue_name = _label(dialogue, "", Vector2(ui.small_margin, float(ui.small_margin) + float(ui.eyebrow_size)), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.dialogue_name_height), ui.title_size, "text")
	dialogue_text = _label(dialogue, "", Vector2(ui.small_margin, float(ui.small_margin) * math.double + float(ui.dialogue_name_height)), Vector2(ui.dialogue_text_width, float(ui.dialogue_name_height) * math.double), ui.body_size, "text")
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_hint = _label(dialogue, str(data.dialogue.close_hint), Vector2(ui.small_margin, dimensions.y - float(ui.small_margin) * math.double), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.small_size), ui.small_size, "muted")
	dialogue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue.hide()


func _build_banner() -> void:
	var dimensions := Vector2(ui.location_banner_width, ui.location_banner_height)
	banner = _panel(root, Vector2.ZERO, dimensions, "panel_soft", true)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -dimensions.x * math.half
	banner.offset_right = dimensions.x * math.half
	banner.offset_top = float(ui.margin)
	banner.offset_bottom = dimensions.y + float(ui.margin)
	banner_title = _label(banner, "", Vector2(ui.small_margin, ui.small_margin), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.title_size), ui.title_size, "text")
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_subtitle = _label(banner, "", Vector2(ui.small_margin, dimensions.y - float(ui.small_margin) - float(ui.subtitle_size)), Vector2(dimensions.x - float(ui.small_margin) * math.double, ui.subtitle_size), ui.subtitle_size, "muted")
	banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func set_location(location: Dictionary) -> void:
	location_title.text = str(location.title)
	location_subtitle.text = str(location.subtitle)


func _build_end_card() -> void:
	end_card = Control.new()
	end_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(end_card)
	var shade := ColorRect.new()
	shade.color = Color.html(str(ui.colors.scrim))
	shade.color.a = float(ui.end_scrim_alpha)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_card.add_child(shade)
	var dimensions := Vector2(ui.end_width, ui.end_height)
	var panel: Panel = _panel(end_card, Vector2.ZERO, dimensions, "panel", true)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -dimensions.x * math.half
	panel.offset_right = dimensions.x * math.half
	panel.offset_top = -dimensions.y * math.half
	panel.offset_bottom = dimensions.y * math.half
	var inner: float = float(ui.margin)
	var width: float = dimensions.x - inner * math.double
	var eyebrow: Label = _label(panel, str(data.dialogue.end_eyebrow), Vector2(inner, inner), Vector2(width, ui.eyebrow_size), ui.eyebrow_size, "gold")
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var heading: Label = _label(panel, str(data.dialogue.end_title), Vector2(inner, inner + float(ui.eyebrow_size) + float(ui.small_margin)), Vector2(width, ui.end_title_size), ui.end_title_size, "gold")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body_top: float = inner + float(ui.eyebrow_size) + float(ui.end_title_size) + float(ui.small_margin) * math.double
	var body: Label = _label(panel, str(data.dialogue.end_body), Vector2(inner, body_top), Vector2(width, dimensions.y - body_top - inner * math.double), ui.body_size, "text")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = inner
	body.offset_right = -inner
	body.offset_top = body_top
	body.offset_bottom = -inner * math.double
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var hint: Label = _label(panel, str(data.dialogue.end_hint), Vector2(inner, dimensions.y - inner - float(ui.small_size)), Vector2(width, ui.small_size), ui.small_size, "muted")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_card.hide()


func show_end_card() -> void:
	close_dialogue()
	end_card.modulate.a = math.zero
	end_card.show()
	create_tween().tween_property(end_card, "modulate:a", math.opacity, float(ui.end_fade))


func hide_end_card() -> void:
	end_card.hide()


func end_card_open() -> bool:
	return end_card.visible


func show_location(location: Dictionary) -> void:
	set_location(location)
	banner_title.text = str(location.title)
	banner_subtitle.text = str(location.banner)
	banner.show()
	banner.modulate.a = math.opacity
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_interval(float(data.settings.location_banner_duration))
	banner_tween.tween_property(banner, "modulate:a", math.zero, float(ui.toast_fade))
	banner_tween.tween_callback(banner.hide)


func refresh(world, party) -> void:
	resource_label.text = str(data.economy.text.resources) % [int(party.state.gold), party.item_count("potion")]
	for index in range(hero_hp_labels.size()):
		var hero: Dictionary = party.state.heroes[index]
		hero_hp_labels[index].text = str(data.economy.text.fallen) if bool(hero.fallen) else str(data.economy.text.hp_progress) % [int(hero.hp), int(hero.max_hp), int(hero.level), int(hero.experience)]
		hero_hp_labels[index].add_theme_color_override("font_color", Color.html(str(ui.colors.danger if bool(hero.fallen) else ui.colors.muted)))
	var target: Dictionary = world.nearest_npc(party.leader_cell())
	if target.is_empty():
		target = world.nearest_service(party.leader_cell())
	if target.is_empty():
		target = world.nearest_prop(party.leader_cell())
	var available: bool = not target.is_empty() and party.is_idle() and not dialogue.visible
	prompt.visible = available
	if available:
		prompt_text.text = "E / Enter · " + str(target.name)


func show_dialogue(entry: Dictionary, eyebrow: String = "talk_eyebrow", hint: String = "close_hint") -> void:
	dialogue_eyebrow.text = str(data.dialogue[eyebrow])
	dialogue_name.text = str(entry.name)
	dialogue_text.text = str(entry.line)
	dialogue_hint.text = str(data.dialogue[hint])
	dialogue.show()
	prompt.hide()


func close_dialogue() -> void:
	dialogue.hide()


func dialogue_open() -> bool:
	return dialogue.visible


func update_objective(flags: Dictionary) -> void:
	objective.text = str(data.objective.initial)
	objective_hint.text = str(data.objective.hint)
	for stage in data.objective.stages:
		if bool(flags.get(str(stage.flag), false)):
			objective.text = str(stage.text)
			objective_hint.text = str(stage.hint)
			return


func fade_to(alpha: float, duration: float) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_property(scrim, "modulate:a", alpha, duration)
	return tween
