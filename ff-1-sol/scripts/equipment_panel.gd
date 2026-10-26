extends "res://scripts/service_panel.gd"
## Browsing never silently removes the current equipment.
var member_id := "warrior"
var row_button: Button
var best_button: Button
var remove_button: Button
var hero_buttons: Dictionary = {}
var layout: Dictionary

func _place(button: Button, rect: Array) -> void:
	button.position = Vector2(rect.front(), rect[int(GameState.rules.n.one)])
	button.size = Vector2(rect[int(GameState.rules.n.two)], rect.back())

func _ready() -> void:
	super._ready()
	layout = GameState.polish.gear
	cfg = cfg.duplicate(true)
	cfg.merge({"panel":layout.panel, "overline":layout.overline, "title":layout.title, "list_origin":layout.rows, "row_size":layout.row_size, "row_gap":layout.row_gap, "max_rows":layout.max_rows, "row_font_size":layout.row_font}, true)
	for button in get_children():
		if button is Button and button.text == "Закрыть":
			_place(button, layout.close)
	_place(buy_tab, layout.weapon)
	_place(sell_tab, layout.armor)
	_place(action_button, layout.action)
	for index in GameState.session.heroes.size():
		var member: Dictionary = GameState.session.heroes[index]
		var button := _button("", layout.hero_buttons[index])
		button.add_theme_font_size_override("font_size", int(layout.card_font))
		button.pressed.connect(select_hero.bind(member.id))
		hero_buttons[member.id] = button
	row_button = _button("", layout.row_button)
	row_button.pressed.connect(change_row)
	best_button = _button("Подобрать лучшее", layout.best)
	best_button.tooltip_text = "Подходящие вещи из общей сумки. Снаряжение других героев остаётся у них."
	best_button.pressed.connect(best_equipment)
	remove_button = _button("Снять из слота", layout.remove)
	remove_button.pressed.connect(remove_equipment)
	mode = "weapon"

func _default_selection() -> void:
	selected_id = "__current"
	if not GameState.hero(member_id).equipment[mode].is_empty():
		return
	for item_id in GameState.economy.items:
		var item: Dictionary = GameState.economy.items[item_id]
		if item.has("equipment") and item.equipment.slot == mode and item.equipment.classes.has(member_id) and GameState.owned(item_id) > GameState.rules.n.zero:
			selected_id = item_id
			break

func open_equipment() -> void:
	if GameState.in_battle():
		return
	message = "Выберите героя и слот. Сравните характеристики или подберите лучшее из сумки."
	result_ok = true
	_default_selection()
	refresh()
	show()

func select_hero(id: String) -> void:
	member_id = id
	_default_selection()
	refresh()

func set_mode(new_mode: String) -> void:
	mode = "weapon" if new_mode in ["buy", "weapon"] else "armor"
	_default_selection()
	refresh()

func refresh() -> void:
	if layout.is_empty():
		return
	entries.clear()
	for item_id in GameState.economy.items:
		var item: Dictionary = GameState.economy.items[item_id]
		if item.has("equipment") and item.equipment.slot == mode and item.equipment.classes.has(member_id) and GameState.owned(item_id) > GameState.rules.n.zero:
			entries.append(item_id)
	entries.append("__empty")
	if selected_id != "__current" and not entries.has(selected_id):
		selected_id = "__current"
	_build_rows()
	buy_tab.show()
	sell_tab.show()
	action_button.show()
	var member := GameState.hero(member_id)
	buy_tab.text = "Оружие: " + _gear_name(member.equipment.weapon)
	sell_tab.text = "Броня: " + _gear_name(member.equipment.armor)
	buy_tab.add_theme_stylebox_override("normal", _style(cfg.selected if mode == "weapon" else cfg.row_bg))
	sell_tab.add_theme_stylebox_override("normal", _style(cfg.selected if mode == "armor" else cfg.row_bg))
	for id in hero_buttons:
		var hero := GameState.hero(id)
		hero_buttons[id].text = hero.name + " · " + hero.class + "\n" + _gear_name(hero.equipment.weapon) + " / " + _gear_name(hero.equipment.armor) + "\n" + GameState.combat.rows[hero.row].name + " ряд"
		hero_buttons[id].add_theme_stylebox_override("normal", _style(cfg.selected if id == member_id else cfg.row_bg))
	row_button.text = "Ряд: " + GameState.combat.rows[member.row].name + " · сменить"
	row_button.tooltip_text = "Задний ряд: 60% ближнего урона в обе стороны. Заклинания работают в полную силу."
	action_button.text = "Уже надето" if selected_id == "__current" else ("Снять снаряжение" if selected_id == "__empty" else "Надеть: " + _gear_name(selected_id))
	action_button.disabled = selected_id == "__current" or (selected_id == "__empty" and member.equipment[mode].is_empty())
	remove_button.disabled = member.equipment[mode].is_empty()
	queue_redraw()

func _row_text(entry: String) -> String:
	var prefix := "›  " if entry == selected_id else "   "
	if entry == "__empty":
		return prefix + "Без снаряжения · снять из слота"
	return prefix + GameState.economy.items[entry].name + " · ×" + str(GameState.owned(entry))

func select_entry(entry: String) -> void:
	selected_id = entry
	refresh()

func activate() -> void:
	if selected_id == "__current":
		return
	var result := GameState.equip(member_id, "" if selected_id == "__empty" else selected_id, mode)
	message = result.message
	result_ok = result.ok
	selected_id = "__current"
	refresh()

func remove_equipment() -> void:
	selected_id = "__empty"
	activate()

func best_equipment() -> void:
	var result := GameState.equip_best(member_id)
	message = result.message
	result_ok = result.ok
	selected_id = "__current"
	refresh()

func change_row() -> void:
	var result := GameState.toggle_row(member_id)
	message = result.message
	result_ok = result.ok
	refresh()

func handle_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var keys := [KEY_1, KEY_2, KEY_3, KEY_4]
		if keys.has(event.physical_keycode):
			select_hero(GameState.session.heroes[keys.find(event.physical_keycode)].id)
			return
		if event.physical_keycode == KEY_R:
			best_equipment()
			return
		if event.physical_keycode == KEY_DELETE:
			remove_equipment()
			return
	if event.is_action_pressed("equipment"):
		close()
	else:
		super.handle_event(event)

func _gear_name(id: String) -> String:
	return "не надето" if id.is_empty() else GameState.economy.items[id].name

func _draw() -> void:
	if layout.is_empty():
		return
	var u: Dictionary = GameState.rules.ui
	var member := GameState.hero(member_id)
	draw_rect(Rect2(Vector2.ZERO, size), Color(u.shadow))
	_box(layout.panel, cfg.bg)
	_text("ПАРТИЯ / СНАРЯЖЕНИЕ", layout.overline, u.small_size, u.gold)
	_text("Подготовка к путешествию", layout.title, cfg.title_size, u.ink, true)
	_text(str(GameState.session.gold) + " G", layout.wallet, u.card_font, u.gold)
	_box(layout.detail_rect, cfg.row_bg)
	draw_texture_rect(hud.portraits[member_id], Rect2(layout.portrait.front(), layout.portrait[int(GameState.rules.n.one)], layout.portrait[int(GameState.rules.n.two)], layout.portrait.back()), false)
	_text(member.name + " · " + member.class, layout.name, u.card_font, u.gold, true)
	_text("Уровень " + str(member.level) + " · XP " + str(member.experience), layout.level, u.body_size, u.muted)
	var current: Dictionary = GameState.stats(member_id)
	var equipment: Dictionary = member.equipment.duplicate()
	if selected_id != "__current":
		equipment[mode] = "" if selected_id == "__empty" else selected_id
	var preview: Dictionary = GameState.stats(member_id, equipment)
	var index := int(GameState.rules.n.zero)
	for stat in GameState.combat.stat_names:
		var y: float = layout.stat_origin.back() + index * layout.stat_step
		var delta: int = preview[stat] - current[stat]
		var color: String = u.ink if delta == GameState.rules.n.zero else (layout.current_color if delta > GameState.rules.n.zero else layout.bad)
		_text(layout.stat_labels[stat], [layout.stat_origin.front(), y], u.body_size, u.muted)
		_text(str(current[stat]) + " → " + str(preview[stat]), [layout.stat_value_x, y], layout.stat_font, color)
		if delta != GameState.rules.n.zero:
			_text(("+" if delta > GameState.rules.n.zero else "") + str(delta), [layout.stat_delta_x, y], u.body_size, color)
		index += int(GameState.rules.n.one)
	_text("ДОСТУПНО В ОБЩЕЙ СУМКЕ", layout.list_label, u.small_size, u.gold)
	var description := "Выберите предмет, чтобы увидеть изменение характеристик."
	if selected_id == "__empty":
		description = "Текущий предмет вернётся в сумку."
	elif selected_id != "__current":
		description = GameState.economy.items[selected_id].description
	_wrap(description, layout.description, layout.description_width, layout.description_font, layout.description_line, u.muted)
	_wrap(message, layout.message, layout.message_width, layout.message_font, layout.message_line, cfg.good if result_ok else cfg.bad)
	_text("1–4 Герой · ←→ Слот · ↑↓ Вещь · E Надеть · R Подобрать · C / Esc Закрыть", layout.footer, u.small_size, u.muted)
