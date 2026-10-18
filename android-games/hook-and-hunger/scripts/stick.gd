extends Control
var active := false
var origin := Vector2.ZERO
var direction := Vector2.ZERO

func _draw() -> void:
	var at := origin if active else Vector2(110, size.y - 245)
	draw_circle(at, 64, Color(0.04, 0.14, 0.2, 0.4))
	draw_arc(at, 64, 0, TAU, 40, Color(0.7, 0.92, 0.91, 0.55), 3)
	draw_circle(at + direction.limit_length() * 42, 24, Color(0.7, 0.94, 0.87, 0.75))
