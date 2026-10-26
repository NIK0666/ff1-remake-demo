extends CanvasLayer

const SLOTS: Array = ["weapon", "armor"]
const STATS: Array = ["attack", "defense", "agility"]

var data: Dictionary
var ui: Dictionary
var math: Dictionary
var text: Dictionary
var party
var service_id: String = ""
var mode: String = "buy"
var view: String = ""
var focus_item: String = ""
var selected_hero: int = -1
var selected_slot: String = ""
var root: Control
var panel: Panel
var title: Label
var subtitle: Label
var gold: Label
var tabs: HBoxContainer
var scroll: ScrollContainer
var content: VBoxContainer
var status: Label
var pending_focus: Control


func _init(config: Dictionary) -> void:
	data = config
	ui = data.settings.interface
	math = data.settings.math
	text = data.economy.text


func _style(background: String, border: String = "border", width: int = int(ui.panel_border)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(str(ui.colors[background]))
	style.set_corner_radius_all(int(ui.panel_radius))
	style.set_border_width_all(width)
	style.border_color = Color.html(str(ui.colors[border]))
	style.content_margin_left = float(ui.small_margin)
	style.content_margin_right = float(ui.small_margin)
	style.content_margin_top = float(ui.small_margin) * math.half
	style.content_margin_bottom = float(ui.small_margin) * math.half
	return style


func _label(parent: Control, text_value: String, font_size: float, color_name: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(font_size))
	label.add_theme_color_override("font_color", Color.html(str(ui.colors[color_name])))
	parent.add_child(label)
	return label


func _ready() -> void:
	layer = int(math.double)
	root = Control.new()
	root.name = "Services"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color.html(str(ui.colors.scrim))
	scrim.color.a = float(ui.service_scrim_alpha)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var width: float = float(ui.service_width)
	var height: float = float(ui.service_height)
	var margin: float = float(ui.margin)
	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -width * math.half
	panel.offset_right = width * math.half
	panel.offset_top = -height * math.half
	panel.offset_bottom = height * math.half
	panel.add_theme_stylebox_override("panel", _style("panel"))
	root.add_child(panel)
	title = _label(panel, "", ui.title_size, "gold")
	title.position = Vector2(margin, ui.small_margin)
	title.size = Vector2(width - margin * math.double - float(ui.service_button_width), float(ui.title_size) + float(ui.small_margin))
	subtitle = _label(panel, "", ui.small_size, "muted")
	subtitle.position = Vector2(margin, float(ui.small_margin) * math.double + float(ui.title_size))
	subtitle.size = Vector2(width - margin * math.double, ui.subtitle_size)
	gold = _label(panel, "", ui.title_size, "gold")
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold.position = Vector2(width - margin - float(ui.service_button_width), ui.small_margin)
	gold.size = Vector2(ui.service_button_width, float(ui.title_size) + float(ui.small_margin))
	tabs = HBoxContainer.new()
	tabs.position = Vector2(margin, ui.service_header_height)
	tabs.size = Vector2(width - margin * math.double, ui.service_tab_height)
	tabs.add_theme_constant_override("separation", int(ui.service_gap))
	panel.add_child(tabs)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(ui.service_row_gap))
	scroll.add_child(content)
	status = _label(panel, "", ui.body_size, "accent")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.position = Vector2(margin, height - float(ui.service_status_height) - float(ui.small_margin))
	status.size = Vector2(width - margin * math.double, ui.service_status_height)
	root.hide()


func is_open() -> bool:
	return root.visible


func open_service(location: Dictionary, party_state) -> void:
	party = party_state
	service_id = str(location.service)
	mode = "buy"
	_open(str(location.title), str(location.subtitle))


func open_inventory(party_state) -> void:
	party = party_state
	service_id = "inventory"
	mode = "equipment"
	_open(str(text.inventory), str(text.inventory_hint))


func _open(title_value: String, subtitle_value: String) -> void:
	title.text = title_value
	subtitle.text = subtitle_value + "   ·   " + str(text.close)
	status.text = ""
	view = ""
	selected_hero = -int(math.one)
	selected_slot = ""
	root.show()
	_rebuild()


func close() -> void:
	root.hide()
	service_id = ""
	party = null


func back() -> bool:
	if not view.is_empty():
		view = ""
		_rebuild()
		return true
	if not selected_slot.is_empty():
		selected_slot = ""
		_rebuild()
		return true
	return false


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _apply_button_style(button: Button) -> void:
	button.add_theme_font_size_override("font_size", int(ui.body_size))
	button.add_theme_color_override("font_color", Color.html(str(ui.colors.text)))
	button.add_theme_color_override("font_hover_color", Color.html(str(ui.colors.gold)))
	button.add_theme_color_override("font_focus_color", Color.html(str(ui.colors.gold)))
	button.add_theme_color_override("font_disabled_color", Color.html(str(ui.colors.muted)))
	button.add_theme_stylebox_override("normal", _style("panel_soft", "panel_soft"))
	button.add_theme_stylebox_override("hover", _style("panel", "gold"))
	button.add_theme_stylebox_override("pressed", _style("panel", "gold"))
	button.add_theme_stylebox_override("focus", _style("panel", "gold", int(ui.focus_border)))
	button.add_theme_stylebox_override("disabled", _style("panel_soft", "panel_soft"))


func _button(parent: Control, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = float(ui.service_tab_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	_apply_button_style(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _row(cells: Array, action: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = float(ui.service_row_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not enabled
	_apply_button_style(button)
	button.pressed.connect(action)
	content.add_child(button)
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = float(ui.small_margin) + float(ui.service_gap) * math.half
	line.offset_right = -float(ui.small_margin) - float(ui.service_gap) * math.half
	line.add_theme_constant_override("separation", int(ui.service_gap))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	for cell in cells:
		var label := _label(line, str(cell.text), float(cell.get("size", ui.body_size)), "muted" if not enabled else str(cell.get("color", "text")))
		if float(cell.get("width", math.zero)) > float(math.zero):
			label.custom_minimum_size.x = float(cell.width)
		else:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if str(cell.get("align", "left")) == "right" else HORIZONTAL_ALIGNMENT_LEFT
		label.clip_text = true
	return button


func _header(cells: Array) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", int(ui.service_gap))
	line.custom_minimum_size.y = float(ui.service_heading_height)
	content.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = float(ui.small_margin) * math.half
	line.add_child(spacer)
	for cell in cells:
		var label := _label(line, str(cell.text), ui.small_size, "gold")
		if float(cell.get("width", math.zero)) > float(math.zero):
			label.custom_minimum_size.x = float(cell.width)
		else:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if str(cell.get("align", "left")) == "right" else HORIZONTAL_ALIGNMENT_LEFT
	line.add_child(spacer.duplicate())


func _heading(text_value: String) -> void:
	var label := _label(content, text_value, ui.small_size, "gold")
	label.custom_minimum_size.y = float(ui.service_heading_height)


func _description(text_value: String) -> void:
	var label := _label(content, text_value, ui.body_size, "text")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = float(ui.service_status_height)


func _layout_body(with_tabs: bool) -> void:
	tabs.visible = with_tabs
	var top: float = float(ui.service_header_height) + (float(ui.service_tab_height) + float(ui.service_gap) if with_tabs else math.zero)
	scroll.position = Vector2(ui.margin, top)
	scroll.size = Vector2(float(ui.service_width) - float(ui.margin) * math.double, float(ui.service_height) - top - float(ui.service_status_height) - float(ui.small_margin) * math.double)


func _rebuild() -> void:
	gold.text = "%d G" % int(party.state.gold)
	pending_focus = null
	_clear(tabs)
	_clear(content)
	match service_id:
		"weapons", "armor", "items":
			_build_shop()
		"inn":
			_layout_body(false)
			_build_inn()
		"clinic":
			_layout_body(false)
			_build_clinic()
		_:
			_build_inventory()
	if is_instance_valid(pending_focus):
		pending_focus.grab_focus()
	else:
		_focus_first_button(content)


func _focus_first_button(parent: Node) -> bool:
	for child in parent.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return true
		if _focus_first_button(child):
			return true
	return false


func _tab(label_text: String, tab_mode: String) -> void:
	var tab := _button(tabs, label_text, func() -> void:
		mode = tab_mode
		view = ""
		selected_slot = ""
		_rebuild()
	)
	if mode == tab_mode:
		tab.add_theme_stylebox_override("normal", _style("panel", "gold", int(ui.focus_border)))
		tab.add_theme_color_override("font_color", Color.html(str(ui.colors.gold)))


func _effect_text(definition: Dictionary) -> String:
	if not definition.has("slot"):
		return str(definition.get("info", ""))
	var parts: Array = []
	for stat in STATS:
		if int(definition.get(stat, int(math.zero))) != int(math.zero):
			parts.append(str(text.stat_bonus) % [str(text[stat]), int(definition[stat])])
	return " · ".join(parts)


func _stat_after(hero_index: int, item_id: String, stat: String) -> int:
	var definition: Dictionary = party.item(item_id)
	var current: Dictionary = party.item(str(party.state.heroes[hero_index].equipment[definition.slot]))
	return party.hero_stat(hero_index, stat) - int(current.get(stat, int(math.zero))) + int(definition.get(stat, int(math.zero)))


func _comparison(hero_index: int, item_id: String) -> Dictionary:
	var definition: Dictionary = party.item(item_id)
	var parts: Array = []
	var score: int = int(math.zero)
	for stat in STATS:
		var before: int = party.hero_stat(hero_index, stat)
		var after: int = _stat_after(hero_index, item_id, stat)
		if before != after or int(definition.get(stat, int(math.zero))) != int(math.zero):
			parts.append(str(text.stat_change) % [str(text[stat]), before, after])
			score += after - before
	var color_name: String = "health" if score > int(math.zero) else ("danger" if score < int(math.zero) else "muted")
	return {"text": " · ".join(parts), "color": color_name}


func _free_copies(item_id: String, hero_index: int) -> int:
	var hero_has: int = int(math.zero)
	for slot in SLOTS:
		if str(party.state.heroes[hero_index].equipment[slot]) == item_id:
			hero_has += int(math.one)
	return party.item_count(item_id) - party.equipped_count(item_id) + hero_has


func _build_shop() -> void:
	_layout_body(view.is_empty())
	if view == "fit":
		_build_fit()
		return
	_tab(str(text.buy), "buy")
	_tab(str(text.sell), "sell")
	if mode == "buy":
		_header([{"text": str(text.column_item), "width": ui.service_name_width}, {"text": str(text.column_effect)}, {"text": str(text.column_price), "width": ui.service_price_width, "align": "right"}, {"text": str(text.column_owned), "width": ui.service_count_width, "align": "right"}])
		for definition in data.economy.catalogs[service_id]:
			var item_id: String = str(definition.id)
			var affordable: bool = int(party.state.gold) >= int(definition.buy)
			_row([{"text": str(definition.name), "width": ui.service_name_width}, {"text": _effect_text(definition), "color": "muted"}, {"text": "%d G" % int(definition.buy), "width": ui.service_price_width, "color": "gold", "align": "right"}, {"text": "×%d" % party.item_count(item_id), "width": ui.service_count_width, "align": "right"}], func() -> void:
				if definition.has("slot"):
					focus_item = item_id
					view = "fit"
					_rebuild()
				else:
					status.text = party.buy_item(item_id)
					_rebuild()
			, affordable)
		return
	var entries: int = int(math.zero)
	for catalog in data.economy.catalogs.values():
		for definition in catalog:
			var item_id: String = str(definition.id)
			if party.item_count(item_id) <= int(math.zero) or bool(definition.get("key", false)):
				continue
			entries += int(math.one)
			var spare: int = party.item_count(item_id) - party.equipped_count(item_id)
			var owned: String = str(text.owned_equipped) % [party.item_count(item_id), party.equipped_count(item_id)] if party.equipped_count(item_id) > int(math.zero) else "×%d" % party.item_count(item_id)
			_row([{"text": str(definition.name), "width": ui.service_name_width}, {"text": owned, "color": "muted"}, {"text": "+%d G" % int(definition.sell), "width": ui.service_price_width, "color": "gold", "align": "right"}], func() -> void:
				status.text = party.sell_item(item_id)
				_rebuild()
			, spare > int(math.zero))
	if entries == int(math.zero):
		_description(str(text.empty_inventory))


func _build_fit() -> void:
	var definition: Dictionary = party.item(focus_item)
	var item_id: String = focus_item
	_heading(str(text.fit_title) % [str(definition.name), int(definition.buy), _effect_text(definition)])
	var affordable: bool = int(party.state.gold) >= int(definition.buy)
	for index in range(party.state.heroes.size()):
		var hero_index: int = index
		var current: String = str(party.item(str(party.state.heroes[index].equipment[definition.slot])).get("name", text.empty_slot))
		var comparison: Dictionary = _comparison(index, item_id)
		_row([{"text": str(data.party.heroes[index].name), "width": ui.service_name_width}, {"text": str(text.now_wearing) % current, "width": ui.service_current_width, "color": "muted"}, {"text": str(comparison.text), "color": str(comparison.color)}, {"text": str(text.buy_and_equip), "width": ui.service_action_width, "color": "gold", "align": "right"}], func() -> void:
			var message: String = party.buy_item(item_id)
			if party.item_count(item_id) > party.equipped_count(item_id) and message != str(text.no_gold):
				party.equip_item(hero_index, item_id)
				message = str(text.bought_equipped) % [str(definition.name), str(data.party.heroes[hero_index].name)]
			status.text = message
			view = ""
			_rebuild()
		, affordable)
	_row([{"text": str(text.buy_only)}, {"text": "%d G" % int(definition.buy), "width": ui.service_price_width, "color": "gold", "align": "right"}], func() -> void:
		status.text = party.buy_item(item_id)
		view = ""
		_rebuild()
	, affordable)
	_row([{"text": str(text.back)}], func() -> void:
		view = ""
		_rebuild()
	)


func _build_inn() -> void:
	_description(str(text.inn_description))
	_row([{"text": str(text.inn_action) % int(data.economy.inn_price)}], func() -> void:
		status.text = party.rest()
		_rebuild()
	, int(party.state.gold) >= int(data.economy.inn_price))


func _build_clinic() -> void:
	_description(str(text.clinic_description) % int(data.economy.clinic_price))
	var fallen_count: int = int(math.zero)
	for index in range(party.state.heroes.size()):
		if bool(party.state.heroes[index].fallen):
			fallen_count += int(math.one)
			var hero_index: int = index
			_row([{"text": str(data.party.heroes[index].name), "width": ui.service_name_width}, {"text": str(text.fallen), "color": "danger"}, {"text": str(text.clinic_action) % int(data.economy.clinic_price), "width": ui.service_action_width, "color": "gold", "align": "right"}], func() -> void:
				status.text = party.revive(hero_index)
				_rebuild()
			, int(party.state.gold) >= int(data.economy.clinic_price))
	if fallen_count == int(math.zero):
		_description(str(text.clinic_none))


func _build_inventory() -> void:
	_layout_body(true)
	_tab(str(text.equipment), "equipment")
	_tab(str(text.items), "items")
	if mode == "items":
		if view == "use":
			_build_use()
		else:
			_build_items()
	else:
		_build_equipment()


func _build_items() -> void:
	var count: int = int(math.zero)
	for catalog in data.economy.catalogs.values():
		for definition in catalog:
			var item_id: String = str(definition.id)
			var quantity: int = party.item_count(item_id)
			if quantity <= int(math.zero):
				continue
			count += int(math.one)
			var usable: bool = definition.has("effect")
			_row([{"text": str(definition.name), "width": ui.service_name_width}, {"text": _effect_text(definition), "color": "muted"}, {"text": "×%d" % quantity, "width": ui.service_count_width, "align": "right"}, {"text": str(text.use) if usable else "", "width": ui.service_action_width, "color": "gold", "align": "right"}], func() -> void:
				if usable:
					focus_item = item_id
					view = "use"
					_rebuild()
			, true)
	if count == int(math.zero):
		_description(str(text.empty_inventory))


func _build_use() -> void:
	var definition: Dictionary = party.item(focus_item)
	var item_id: String = focus_item
	_heading(str(text.use_title) % [str(definition.name), party.item_count(item_id)])
	for index in range(party.state.heroes.size()):
		var hero: Dictionary = party.state.heroes[index]
		var hero_index: int = index
		_row([{"text": str(data.party.heroes[index].name), "width": ui.service_name_width}, {"text": str(text.fallen) if bool(hero.fallen) else str(text.hp) % [int(hero.hp), int(hero.max_hp)], "color": "danger" if bool(hero.fallen) else "text"}], func() -> void:
			var amount: int = party.use_item(item_id, hero_index)
			status.text = str(text.item_applied) % [str(definition.name), str(data.party.heroes[hero_index].name)] if amount >= int(math.zero) else ""
			if party.item_count(item_id) <= int(math.zero):
				view = ""
			_rebuild()
		, party.can_use_item(item_id, index))
	_row([{"text": str(text.back)}], func() -> void:
		view = ""
		_rebuild()
	)


func _build_equipment() -> void:
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", int(ui.service_gap))
	content.add_child(cards)
	for index in range(party.state.heroes.size()):
		_hero_card(cards, index)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", int(ui.service_gap))
	content.add_child(tools)
	var hint := _label(tools, str(text.slot_hint) if selected_slot.is_empty() else str(text.slot_title) % [str(data.party.heroes[selected_hero].name), str(text[selected_slot])], ui.small_size, "gold")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var best := _button(tools, str(text.best_all), func() -> void:
		for hero_index in range(party.state.heroes.size()):
			_equip_best(hero_index)
		status.text = str(text.best_done)
		_rebuild()
	)
	best.size_flags_horizontal = Control.SIZE_SHRINK_END
	best.custom_minimum_size.x = float(ui.service_button_width)
	if selected_slot.is_empty():
		return
	var hero: Dictionary = party.state.heroes[selected_hero]
	var equipped: String = str(hero.equipment[selected_slot])
	if not equipped.is_empty():
		pending_focus = _row([{"text": str(text.unequip), "width": ui.service_name_width}, {"text": str(text.now_wearing) % str(party.item(equipped).name), "color": "muted"}], func() -> void:
			party.unequip(selected_hero, selected_slot)
			_rebuild()
		)
	var options: int = int(math.zero)
	var focus_chosen: bool = false
	for catalog in data.economy.catalogs.values():
		for definition in catalog:
			var item_id: String = str(definition.id)
			if str(definition.get("slot", "")) != selected_slot or _free_copies(item_id, selected_hero) <= int(math.zero):
				continue
			options += int(math.one)
			var worn: bool = item_id == equipped
			var comparison: Dictionary = _comparison(selected_hero, item_id)
			var option: Button = _row([{"text": str(definition.name), "width": ui.service_name_width}, {"text": str(comparison.text), "color": str(comparison.color)}, {"text": str(text.worn_mark) if worn else str(text.equip), "width": ui.service_action_width, "color": "muted" if worn else "gold", "align": "right"}], func() -> void:
				party.equip_item(selected_hero, item_id)
				status.text = str(text.equipped_now) % [str(definition.name), str(data.party.heroes[selected_hero].name)]
				_rebuild()
			, not worn)
			if not worn and not focus_chosen:
				pending_focus = option
				focus_chosen = true
	if options == int(math.zero) and equipped.is_empty():
		_description(str(text.no_spare))


func _hero_card(parent: Control, index: int) -> void:
	var hero: Dictionary = party.state.heroes[index]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chosen: bool = index == selected_hero and not selected_slot.is_empty()
	card.add_theme_stylebox_override("panel", _style("panel_soft", "gold" if chosen else "border", int(ui.focus_border) if chosen else int(ui.panel_border)))
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(ui.service_card_gap))
	card.add_child(box)
	var name_label := _label(box, str(data.party.heroes[index].name), ui.body_size, "gold")
	name_label.add_theme_color_override("font_color", Color.html(str(data.palette[data.party.heroes[index].color])).lightened(float(ui.name_lighten)))
	var fallen: bool = bool(hero.fallen)
	_label(box, str(text.card_level) % [int(hero.level), int(hero.hp), int(hero.max_hp)], ui.small_size, "danger" if fallen else "muted")
	_label(box, str(text.stats) % [party.hero_stat(index, "attack"), party.hero_stat(index, "defense"), party.hero_stat(index, "agility")], ui.small_size, "text")
	var hero_index: int = index
	_card_button(box, str(text.row) + ": " + str(data.battle.text[hero.row]), func() -> void:
		party.toggle_row(hero_index)
		_rebuild()
	)
	for slot in SLOTS:
		var slot_name: String = slot
		var worn: String = str(party.item(str(hero.equipment[slot])).get("name", text.empty_slot))
		var button := _card_button(box, "%s: %s" % [str(text[slot]), worn], func() -> void:
			selected_hero = hero_index
			selected_slot = slot_name
			_rebuild()
		)
		if chosen and slot == selected_slot:
			button.add_theme_stylebox_override("normal", _style("panel", "gold", int(ui.focus_border)))
			pending_focus = button
	_card_button(box, str(text.best_one), func() -> void:
		_equip_best(hero_index)
		status.text = str(text.best_done)
		_rebuild()
	)


func _card_button(parent: Control, text_value: String, action: Callable) -> Button:
	var button := _button(parent, text_value, action)
	button.add_theme_font_size_override("font_size", int(ui.small_size))
	button.custom_minimum_size.y = float(ui.service_card_button)
	return button


func _equip_best(hero_index: int) -> void:
	for slot in SLOTS:
		var key_stat: String = "attack" if slot == "weapon" else "defense"
		var best_id: String = str(party.state.heroes[hero_index].equipment[slot])
		var best_value: int = int(party.item(best_id).get(key_stat, int(math.zero))) if not best_id.is_empty() else -int(math.one)
		for catalog in data.economy.catalogs.values():
			for definition in catalog:
				var item_id: String = str(definition.id)
				if str(definition.get("slot", "")) != slot or _free_copies(item_id, hero_index) <= int(math.zero):
					continue
				if int(definition.get(key_stat, int(math.zero))) > best_value:
					best_value = int(definition.get(key_stat, int(math.zero)))
					best_id = item_id
		if not best_id.is_empty():
			party.equip_item(hero_index, best_id)
