extends Control

var game
var dialog_open := false
var dialog: Dictionary = {}
var map_open := false
var fade: float
var serif := SystemFont.new()
var sans := SystemFont.new()
var portraits: Dictionary = {}
var u: Dictionary
var service
var gear

func _ready() -> void:
	u = GameState.rules.ui
	fade = GameState.rules.n.zero
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	sans.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "sans-serif"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hero in GameState.session.heroes:
		portraits[hero.id] = load("res://assets/" + hero.id + ".svg")
	service = preload("res://scripts/service_panel.gd").new()
	service.hud = self
	add_child(service)
	gear = preload("res://scripts/equipment_panel.gd").new()
	gear.hud = self
	add_child(gear)

func _point(values: Array) -> Vector2:
	return Vector2(values.front(), values.back())

func _rect(values: Array) -> Rect2:
	return Rect2(values[int(GameState.rules.n.zero)], values[int(GameState.rules.n.one)], values[int(GameState.rules.n.two)], values.back())

func _text(text: String, at: Vector2, size: float, color: String, heading: bool = false) -> void:
	draw_string(serif if heading else sans, at, text, HORIZONTAL_ALIGNMENT_LEFT, -GameState.rules.n.one, int(size), Color(color))

func _panel(rect: Rect2, color: String = "") -> void:
	draw_rect(rect, Color(u.panel if color.is_empty() else color))
	draw_rect(rect, Color(u.line), false, u.border_width)

func _draw() -> void:
	if u.is_empty() or not is_instance_valid(game.world):
		return
	_panel(_rect(u.title_panel))
	_text("F I N A L  F A N T A S Y   /   ПЕРВАЯ ГЛАВА", Vector2(u.margin, u.overline_y), u.small_size, u.gold)
	_text(game.location_title(), Vector2(u.margin, u.title_y), u.title_size, u.ink, true)
	_text(GameState.map[GameState.session.location].subtitle, Vector2(u.margin, u.subtitle_y), u.small_size, u.muted)
	_panel(_rect(u.quest_panel))
	_text("ПУТЕШЕСТВИЕ  /  ВОИНЫ СВЕТА", Vector2(u.margin + u.quest_padding.front(), u.quest_label_y), u.small_size, u.gold)
	_text(GameState.objective(), Vector2(u.margin + u.quest_padding.front(), u.quest_text_y), u.body_size, u.ink)
	_panel(_rect(u.economy_rect))
	var economy_text := economy_lines()
	_text(economy_text.front(), _point(u.economy_gold_pos), u.card_font, u.gold)
	var bag: String = economy_text.back()
	if bag.length() > u.economy_summary_length:
		bag = bag.left(int(u.economy_summary_length)) + "…"
	_text(bag, _point(u.economy_bag_pos), u.body_size, u.ink)
	_text("I  ·  Открыть инвентарь партии", _point(u.economy_hint_pos), u.small_size, u.muted)
	_draw_compass()
	_panel(_rect(u.map_rect), u.map_bg)
	_text("СВЯТИЛИЩЕ" if GameState.session.location.begins_with("chaos_") else "КОРНЕЛИЯ", _point(u.map_title), u.small_size, u.gold)
	_draw_map(_point(u.map_origin), u.map_scale, false)
	_draw_party()
	_panel(_rect(u.controls_rect))
	_text("WASD / ↑↓←→   Ходьба    E   Услуги / диалог", Vector2(u.control_line_x, u.control_line_y), u.control_size, u.ink)
	_text("M  Карта     Esc  Пауза     Колесо  Масштаб", Vector2(u.control_line_x, u.control_line_y + u.control_line_gap), u.control_size, u.muted)
	_text("I  Сумка    C  Снаряжение и ряды", Vector2(u.control_line_x, u.control_third_y), u.control_size, u.gold)
	_text("К О Р Н Е Л И Я   /   ЧЕТЫРЕ КРИСТАЛЛА · ОДИН ПУТЬ", _point(u.footer_pos), u.footer_size, u.ink)
	if not dialog_open and not map_open and not game.paused and not service.visible and not gear.visible:
		_draw_prompt()
	if dialog_open:
		_draw_dialog()
	if map_open:
		_draw_large_map()
	if game.paused:
		draw_rect(Rect2(Vector2.ZERO, Vector2(u.width, u.height)), Color(u.shadow))
		_panel(_rect(u.pause_rect))
		_text("Пауза", _point(u.pause_title), u.title_size, u.ink, true)
		var y: float = u.pause_body.back()
		for line in u.pause_lines:
			_text(line, Vector2(u.pause_body.front(), y), u.body_size, u.muted)
			y += u.pause_gap
	if fade > GameState.rules.n.zero:
		var shade := Color(u.fade_color)
		shade.a = fade
		draw_rect(Rect2(Vector2.ZERO, Vector2(u.width, u.height)), shade)

func _draw_compass() -> void:
	var center := _point(u.compass_center)
	draw_circle(center, u.compass_radius, Color(u.panel))
	draw_arc(center, u.compass_radius, GameState.rules.n.zero, TAU, int(GameState.art.surface.segments), Color(u.line), u.border_width, true)
	var up: Vector2 = Vector2.UP * u.compass_radius * GameState.rules.n.half
	draw_colored_polygon(PackedVector2Array([center + up, center + Vector2.LEFT * u.quest_icon_radius, center + Vector2.DOWN * u.quest_icon_radius, center + Vector2.RIGHT * u.quest_icon_radius]), Color(u.gold))
	_text("N", center + Vector2.UP * u.compass_y, u.compass_size, u.ink)

func _draw_party() -> void:
	var index := int(GameState.rules.n.zero)
	for hero in GameState.session.heroes:
		var x: float = u.margin + index * (u.card_width + u.card_gap)
		var card := Rect2(x, u.bottom_y, u.card_width, u.card_height)
		_panel(card)
		draw_line(card.position, card.position + Vector2.RIGHT * u.card_width, Color(hero.color), u.thick_border)
		var portrait_rect := Rect2(x + u.card_padding, u.bottom_y + u.portrait_top, u.portrait_size, u.portrait_size)
		draw_texture_rect(portraits[hero.id], portrait_rect, false)
		_text(hero.class, Vector2(x + u.portrait_text_x, u.bottom_y + u.card_name_y), u.card_font, u.ink, true)
		_text(hero.numeral + "  ·  " + hero.name, Vector2(x + u.portrait_text_x, u.bottom_y + u.card_class_y), u.small_size, u.gold if index == int(GameState.rules.n.zero) else u.muted)
		var health: String = "0 HP · ПАЛ" if hero.hp <= GameState.rules.n.zero else str(int(hero.hp)) + " / " + str(int(hero.max_hp)) + " HP"
		_text(health, Vector2(x + u.portrait_text_x, u.bottom_y + u.card_hp_y), u.small_size, u.health_color if hero.hp > GameState.rules.n.zero else u.lost_color)
		index += int(GameState.rules.n.one)

func economy_lines() -> Array[String]:
	return ["Золото: " + str(GameState.session.gold) + " G", GameState.inventory_summary()]

func _map_box(spec: Array, origin: Vector2, scale_value: float, color: String) -> void:
	var rect := _rect(spec)
	draw_rect(Rect2(origin + rect.position * scale_value, rect.size * scale_value), Color(color))

func _draw_map(origin: Vector2, scale_value: float, large: bool) -> void:
	if GameState.session.location.begins_with("chaos_"):
		_draw_dungeon_map(origin, scale_value, large)
		return
	_map_box(u.map_town_rect, origin, scale_value, "#7b8d6b")
	_map_box(u.map_water_rect, origin, scale_value, GameState.art.palette.map_water)
	_map_box(u.map_castle_rect, origin, scale_value, "#dfd3b3")
	_map_box(u.map_bridge_rect, origin, scale_value, "#dfd3b3")
	draw_circle(origin + _point(GameState.dungeon.entrance.cell) * scale_value, u.map_npc_radius, Color(u.gold))
	for house in GameState.map.town.houses:
		var position_on_map := origin + _point(house.cell) * scale_value
		_map_box(u.map_house_rect, position_on_map, scale_value, house.roof)
	for npc in GameState.map.npcs:
		if npc.location == "town":
			draw_circle(origin + _point(npc.cell) * scale_value, u.map_npc_radius, Color(u.gold))
	var at := GameState.leader()
	if GameState.session.location == "house":
		for house in GameState.map.town.houses:
			if house.id == GameState.session.house_id:
				at = GameState.cell(house.door)
	elif GameState.session.location == "throne":
		at = GameState.cell(GameState.rules.test.castle_door)
	var lead := origin + Vector2(at) * scale_value
	draw_circle(lead, u.map_hero_radius + (u.map_follower_radius if large else GameState.rules.n.zero), Color(u.ink))
	if large:
		for label in GameState.rules.map_labels:
			_text(label.text, origin + _point(label.cell) * scale_value, u.map_font_size, u.ink)

func _draw_prompt() -> void:
	var action: Dictionary = game.world.action_near(GameState.leader(), GameState.session.facing)
	if not action.is_empty():
		_panel(_rect(u.service_prompt_rect))
		_text("E  ·  " + action.name, _point(u.service_prompt_pos), u.body_size, u.ink)
		return
	var available: Dictionary = GameState.current_service()
	if not available.is_empty():
		_panel(_rect(u.service_prompt_rect))
		_text("E  ·  Услуги: " + available.name, _point(u.service_prompt_pos), u.body_size, u.ink)
		return
	var npc: Dictionary = game.world.npc_near(GameState.leader(), GameState.session.facing)
	if npc.is_empty():
		return
	var world_position: Vector3 = npc.node.global_position + Vector3.UP * GameState.art.labels.height
	var at: Vector2 = game.camera.unproject_position(world_position) + _point(u.prompt_offset)
	var rect := _rect(u.prompt_box)
	rect.position += at
	_panel(rect)
	_text("E  ·  Говорить", at + _point(u.prompt_text), u.prompt_size, u.ink)

func _draw_dialog() -> void:
	_panel(_rect(u.dialog_rect))
	_text(dialog.name + "  /  " + dialog.role, _point(u.dialog_name), u.body_size, u.gold)
	var words: PackedStringArray = dialog.text.split(" ")
	var line := ""
	var y: float = u.dialog_text.back()
	var max_width: float = _rect(u.dialog_rect).size.x - (u.dialog_text.front() - _rect(u.dialog_rect).position.x) * GameState.rules.n.two
	for word in words:
		var candidate := line + (" " if not line.is_empty() else "") + word
		if sans.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -GameState.rules.n.one, int(u.dialog_size)).x > max_width:
			_text(line, Vector2(u.dialog_text.front(), y), u.dialog_size, u.ink)
			y += u.dialog_line_height
			line = word
		else:
			line = candidate
	_text(line, Vector2(u.dialog_text.front(), y), u.dialog_size, u.ink)
	_text("E / Enter  ·  Закрыть", _point(u.dialog_footer), u.small_size, u.muted)

func _draw_large_map() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(u.width, u.height)), Color(u.shadow))
	_panel(_rect(u.large_map_rect))
	_text(game.location_title() if GameState.session.location.begins_with("chaos_") else "Корнелия и северный мост", _point(u.large_map_title), u.dialog_size, u.ink, true)
	_draw_map(_point(u.large_map_origin), u.large_map_scale, true)
	_text("Светлая точка — ваша партия     ·     M / Tab / Esc — закрыть", _point(u.large_map_footer), u.body_size, u.muted)

func _draw_dungeon_map(origin: Vector2, scale_value: float, large: bool) -> void:
	var layout: Dictionary = GameState.map[GameState.session.location]
	var pivot := _point(GameState.dungeon.visual.map_offset)
	for at in game.world.cells:
		draw_rect(Rect2(origin + (Vector2(at) + pivot) * scale_value, Vector2.ONE * scale_value), Color(GameState.dungeon.visual.floor_color))
	for portal in layout.portals:
		draw_circle(origin + (_point(portal.cell) + pivot) * scale_value, u.map_npc_radius, Color(u.gold))
	if GameState.session.location == "chaos_1":
		for spec in [GameState.dungeon.chest, GameState.dungeon.door]:
			draw_circle(origin + (_point(spec.cell) + pivot) * scale_value, u.map_npc_radius, Color(u.gold))
	var at := origin + (Vector2(GameState.leader()) + pivot) * scale_value
	draw_circle(at, u.map_hero_radius + (u.map_follower_radius if large else GameState.rules.n.zero), Color(u.ink))
