extends Control
## Transaction UI only; all authoritative values and mutations live in GameState.

var hud
var cfg: Dictionary
var service: Dictionary = {}
var mode := "buy"
var selected_id := ""
var message := ""
var result_ok := true
var entries: Array[String] = []
var rows: Dictionary = {}
var buy_tab: Button
var sell_tab: Button
var action_button: Button
var previous_page: Button
var next_page: Button
var page_offset: int

func _ready() -> void:
	cfg = GameState.rules.ui.service
	size = Vector2(GameState.rules.ui.width, GameState.rules.ui.height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	page_offset = int(GameState.rules.n.zero)
	var close_button := _button("Закрыть", cfg.close)
	close_button.pressed.connect(close)
	buy_tab = _button("Купить", cfg.tab_buy)
	buy_tab.pressed.connect(set_mode.bind("buy"))
	sell_tab = _button("Продать", cfg.tab_sell)
	sell_tab.pressed.connect(set_mode.bind("sell"))
	previous_page = _button("‹", cfg.page_prev)
	previous_page.pressed.connect(_select_relative.bind(-int(cfg.max_rows)))
	next_page = _button("›", cfg.page_next)
	next_page.pressed.connect(_select_relative.bind(int(cfg.max_rows)))
	action_button = _button("", cfg.action)
	action_button.pressed.connect(activate)
	hide()

func _style(color: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.border_color = Color(cfg.line)
	style.set_border_width_all(int(cfg.border))
	style.set_corner_radius_all(int(cfg.corner))
	style.content_margin_left = cfg.button_padding
	style.content_margin_right = cfg.button_padding
	return style

func _button(text: String, rect: Array) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(rect.front(), rect[int(GameState.rules.n.one)])
	button.size = Vector2(rect[int(GameState.rules.n.two)], rect.back())
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", hud.sans)
	button.add_theme_font_size_override("font_size", int(cfg.button_font_size))
	button.add_theme_color_override("font_color", Color(GameState.rules.ui.ink))
	button.add_theme_stylebox_override("normal", _style(cfg.row_bg))
	button.add_theme_stylebox_override("hover", _style(cfg.hover))
	button.add_theme_stylebox_override("pressed", _style(cfg.selected))
	add_child(button)
	return button

func open_service() -> void:
	service = GameState.current_service()
	if service.is_empty():
		return
	mode = "buy" if service.kind == "shop" else service.kind
	selected_id = ""
	message = "Выберите товар или услугу. Плата списывается только при подтверждении."
	result_ok = true
	refresh()
	show()

func open_inventory() -> void:
	service = {}
	mode = "inventory"
	selected_id = ""
	message = "Общая сумка и золото сохраняются при входе в любой дом."
	result_ok = true
	refresh()
	show()

func close() -> void:
	hide()

func set_mode(new_mode: String) -> void:
	if service.get("kind", "") != "shop" or new_mode not in ["buy", "sell"]:
		return
	mode = new_mode
	selected_id = ""
	message = "Выберите товар. Каждое подтверждение — один предмет."
	result_ok = true
	refresh()

func refresh() -> void:
	entries.clear()
	if mode in ["buy", "sell"]:
		for item_id in service.stock:
			if mode == "buy" or GameState.owned(item_id) > GameState.rules.n.zero:
				entries.append(item_id)
	elif mode == "inventory":
		for item_id in GameState.economy.items:
			if GameState.owned(item_id) > GameState.rules.n.zero:
				entries.append(item_id)
	else:
		for hero in GameState.session.heroes:
			if mode == "inn" or hero.hp <= GameState.rules.n.zero:
				entries.append(hero.id)
	if not entries.has(selected_id):
		selected_id = "" if entries.is_empty() else entries.front()
	_build_rows()
	buy_tab.visible = service.get("kind", "") == "shop"
	sell_tab.visible = buy_tab.visible
	buy_tab.add_theme_stylebox_override("normal", _style(cfg.selected if mode == "buy" else cfg.row_bg))
	sell_tab.add_theme_stylebox_override("normal", _style(cfg.selected if mode == "sell" else cfg.row_bg))
	action_button.visible = mode != "inventory"
	match mode:
		"buy": action_button.text = "Купить · " + _price_text()
		"sell": action_button.text = "Продать · " + _price_text()
		"inn": action_button.text = "Переночевать · " + str(int(service.fee)) + " G"
		"clinic": action_button.text = "Вернуть в строй · " + str(int(service.fee)) + " G"
	queue_redraw()

func _price_text() -> String:
	if selected_id.is_empty():
		return "нет товара"
	var item: Dictionary = GameState.economy.items[selected_id]
	return str(int(item[mode])) + " G"

func _build_rows() -> void:
	for button in rows.values():
		remove_child(button)
		button.queue_free()
	rows.clear()
	var selected_index := entries.find(selected_id)
	page_offset = int(GameState.rules.n.zero) if selected_index < GameState.rules.n.zero else floori(float(selected_index) / cfg.max_rows) * int(cfg.max_rows)
	previous_page.visible = entries.size() > cfg.max_rows
	next_page.visible = previous_page.visible
	previous_page.disabled = page_offset == int(GameState.rules.n.zero)
	next_page.disabled = page_offset + int(cfg.max_rows) >= entries.size()
	for index in range(page_offset, mini(entries.size(), page_offset + int(cfg.max_rows))):
		var entry: String = entries[index]
		var y: float = cfg.list_origin.back() + (index - page_offset) * (cfg.row_size.back() + cfg.row_gap)
		var button := _button(_row_text(entry), [cfg.list_origin.front(), y, cfg.row_size.front(), cfg.row_size.back()])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", int(cfg.row_font_size))
		button.add_theme_stylebox_override("normal", _style(cfg.selected if entry == selected_id else cfg.row_bg))
		button.pressed.connect(select_entry.bind(entry))
		rows[entry] = button

func _row_text(entry: String) -> String:
	var prefix := "›  " if entry == selected_id else "   "
	if mode in ["buy", "sell", "inventory"]:
		var item: Dictionary = GameState.economy.items[entry]
		var price := "" if mode == "inventory" else "  ·  " + str(int(item[mode])) + " G"
		return prefix + item.name + price + "  ·  В сумке: " + str(GameState.owned(entry))
	for hero in GameState.session.heroes:
		if hero.id == entry:
			return prefix + hero.class + " · " + hero.name + "  /  " + GameState.hero_status(hero)
	return ""

func select_entry(entry: String) -> void:
	if not entries.has(entry):
		return
	selected_id = entry
	_build_rows()
	queue_redraw()

func _select_relative(delta: int) -> void:
	if entries.is_empty():
		return
	var index := clampi(entries.find(selected_id) + delta, int(GameState.rules.n.zero), entries.size() - int(GameState.rules.n.one))
	select_entry(entries[index])

func activate() -> void:
	var result: Dictionary
	match mode:
		"buy": result = GameState.buy_item(selected_id)
		"sell": result = GameState.sell_item(selected_id)
		"inn": result = GameState.rest_at_inn()
		"clinic": result = GameState.revive_hero(selected_id)
		_: return
	message = result.message
	result_ok = result.ok
	refresh()

func handle_event(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		close()
	elif event.is_action_pressed("north"):
		_select_relative(-int(GameState.rules.n.one))
	elif event.is_action_pressed("south"):
		_select_relative(int(GameState.rules.n.one))
	elif event.is_action_pressed("west"):
		set_mode("buy")
	elif event.is_action_pressed("east"):
		set_mode("sell")
	elif event.is_action_pressed("talk"):
		activate()

func _text(text: String, at: Array, font_size: float, color: String, heading: bool = false) -> void:
	draw_string(hud.serif if heading else hud.sans, Vector2(at.front(), at.back()), text, HORIZONTAL_ALIGNMENT_LEFT, -GameState.rules.n.one, int(font_size), Color(color))

func _box(rect: Array, color: String) -> void:
	var rectangle := Rect2(rect.front(), rect[int(GameState.rules.n.one)], rect[int(GameState.rules.n.two)], rect.back())
	draw_rect(rectangle, Color(color))
	draw_rect(rectangle, Color(cfg.line), false, cfg.border)

func _wrap(text: String, at: Array, width: float, font_size: float, line_height: float, color: String) -> void:
	var y: float = at.back()
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			var candidate: String = line + (" " if not line.is_empty() else "") + word
			if hud.sans.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -GameState.rules.n.one, int(font_size)).x > width:
				_text(line, [at.front(), y], font_size, color)
				y += line_height
				line = word
			else:
				line = candidate
		_text(line, [at.front(), y], font_size, color)
		y += line_height

func _draw() -> void:
	if cfg.is_empty():
		return
	var u: Dictionary = GameState.rules.ui
	draw_rect(Rect2(Vector2.ZERO, size), Color(u.shadow))
	_box(cfg.panel, cfg.bg)
	_text("КОРНЕЛИЯ  /  " + ("ОБЩАЯ СУМКА" if mode == "inventory" else service.tagline.to_upper()), cfg.overline, u.small_size, u.gold)
	_text(cfg.inventory_title if mode == "inventory" else service.name, cfg.title, cfg.title_size, u.ink, true)
	_text("Золото: " + str(GameState.session.gold) + " G", cfg.wallet, cfg.wallet_font_size, u.gold)
	_box(cfg.detail_rect, cfg.row_bg)
	if entries.is_empty():
		var empty := "Нет потерянных героев" if mode == "clinic" else ("Нет предметов для продажи" if mode == "sell" else "Сумка пуста")
		_text(empty, cfg.empty_pos, u.body_size, u.muted)
		_text("Всё в порядке", cfg.detail_title, u.card_font, u.gold)
	elif mode in ["buy", "sell", "inventory"]:
		var item: Dictionary = GameState.economy.items[selected_id]
		_text(item.name, cfg.detail_title, u.card_font, u.gold, true)
		var detail: String = item.description + "\nЦена покупки: " + str(int(item.buy)) + " G\nЦена продажи: " + str(int(item.sell)) + " G\nВ сумке: " + str(GameState.owned(selected_id))
		_wrap(detail, cfg.detail_text, cfg.detail_width, cfg.detail_font_size, cfg.detail_line_height, u.ink)
	else:
		_text("Вся партия" if mode == "inn" else "Один выбранный герой", cfg.detail_title, u.card_font, u.gold, true)
		_wrap(service.description, cfg.detail_text, cfg.detail_width, cfg.detail_font_size, cfg.detail_line_height, u.ink)
	if entries.size() > cfg.max_rows:
		var page := int(page_offset / int(cfg.max_rows)) + int(GameState.rules.n.one)
		_text(str(page) + " / " + str(ceili(float(entries.size()) / cfg.max_rows)), cfg.page_pos, u.body_size, u.muted)
	_wrap(message, cfg.message_pos, cfg.message_width, cfg.message_font_size, cfg.message_line_height, cfg.good if result_ok else cfg.bad)
	_text(cfg.help if service.get("kind", "") == "shop" else cfg.help_short, cfg.footer, u.small_size, u.muted)
