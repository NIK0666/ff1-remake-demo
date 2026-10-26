class_name ClassIcon
extends Control

var class_id: String = "warrior"
var color: Color = Color("#c94f43")
var accent: Color = Color("#f1c27d")


func setup(new_class_id: String, new_color: Color, new_accent: Color) -> void:
	class_id = new_class_id
	color = new_color
	accent = new_accent
	custom_minimum_size = Vector2(38.0, 38.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, Color(0.035, 0.075, 0.105, 0.95))
	draw_arc(c, r - 1.0, 0.0, TAU, 32, color.darkened(0.1), 1.5, true)
	draw_arc(c, r - 4.0, -1.1, 1.35, 16, accent * Color(1.0, 1.0, 1.0, 0.55), 1.0, true)
	var s := r * 1.5
	match class_id:
		"warrior":
			# Sword and shield.
			draw_line(c + Vector2(-s * 0.28, s * 0.42), c + Vector2(s * 0.18, -s * 0.48), Color("#d9e2e8"), 2.2, true)
			draw_line(c + Vector2(-s * 0.38, s * 0.1), c + Vector2(s * 0.06, s * 0.28), accent, 1.8, true)
			draw_line(c + Vector2(s * 0.18, -s * 0.48), c + Vector2(s * 0.29, -s * 0.6), accent, 2.0, true)
			draw_arc(c + Vector2(-s * 0.28, -s * 0.02), s * 0.30, -1.2, 2.0, 12, Color("#8a95a3"), 2.0, true)
		"thief":
			# Paired daggers.
			draw_line(c + Vector2(-s * 0.48, s * 0.38), c + Vector2(s * 0.0, -s * 0.48), Color("#d9e2e8"), 1.8, true)
			draw_line(c + Vector2(s * 0.48, s * 0.38), c + Vector2(s * 0.0, -s * 0.48), Color("#d9e2e8"), 1.8, true)
			draw_circle(c + Vector2(0.0, -s * 0.52), 2.0, accent)
			draw_arc(c + Vector2(0.0, s * 0.05), s * 0.4, 0.4, 2.7, 12, Color("#4f7b63"), 1.5, true)
		"monk":
			# Wrapped fist.
			draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.2), Vector2(s * 0.75, s * 0.52)), accent, true)
			draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.2), Vector2(s * 0.86, s * 0.18)), color.darkened(0.25), true)
			for i in 4:
				draw_circle(c + Vector2(-s * 0.29 + float(i) * s * 0.18, -s * 0.22), s * 0.085, Color("#f0d9bb"))
			draw_line(c + Vector2(-s * 0.44, s * 0.07), c + Vector2(s * 0.42, s * 0.07), Color("#f0d9bb"), 1.2, true)
		"white_mage":
			# Staff with a radiant orb.
			draw_line(c + Vector2(-s * 0.15, s * 0.55), c + Vector2(s * 0.12, -s * 0.4), Color("#c7a55f"), 2.0, true)
			draw_circle(c + Vector2(s * 0.18, -s * 0.48), s * 0.18, accent)
			draw_circle(c + Vector2(s * 0.18, -s * 0.48), s * 0.08, Color("#eef6ff"))
			for i in 4:
				var a := TAU * float(i) / 4.0
				draw_line(c + Vector2(s * 0.18, -s * 0.48) + Vector2(cos(a), sin(a)) * s * 0.26, c + Vector2(s * 0.18, -s * 0.48) + Vector2(cos(a), sin(a)) * s * 0.37, accent, 1.2, true)
		_:
			draw_circle(c, s * 0.3, color)
