extends "res://scripts/service_panel.gd"
var controller
var layout: Dictionary
var continue_button: Button

func _ready() -> void:
	cfg = GameState.rules.ui.service
	layout = GameState.polish.ending
	size = Vector2(GameState.rules.ui.width, GameState.rules.ui.height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button = _button(layout.continue_text, layout.button)
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.pressed.connect(controller.finish)
	continue_button.hide()

func show_complete() -> void:
	continue_button.show()
	continue_button.grab_focus.call_deferred()
	queue_redraw()

func _draw() -> void:
	if layout.is_empty():
		return
	var u: Dictionary = GameState.rules.ui
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, layout.letterbox)), Color(layout.background))
	draw_rect(Rect2(Vector2(GameState.rules.n.zero, size.y - layout.letterbox), Vector2(size.x, layout.letterbox)), Color(layout.background))
	if controller.phase == "complete":
		draw_rect(Rect2(Vector2.ZERO, size), Color(u.shadow))
		_box(layout.title_rect, cfg.bg)
		_text("FINAL FANTASY · ПЕРВАЯ ГЛАВА", layout.overline_pos, u.small_size, u.gold)
		_text(layout.end_title, layout.title_pos, layout.title_size, u.ink, true)
		_wrap(layout.end_body, layout.body_pos, layout.body_width, u.dialog_size, layout.body_line, u.ink)
		_text(layout.end_footer, layout.footer_pos, u.body_size, u.gold)
	else:
		_box(layout.caption_rect, cfg.bg)
		_wrap(layout.stages[controller.stage], layout.caption_pos, layout.caption_width, layout.caption_size, layout.caption_line, u.ink)
