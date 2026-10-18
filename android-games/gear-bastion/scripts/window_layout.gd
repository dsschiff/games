extends RefCounted
## Geometry shared by drawing and picking; simulation coordinates never change.

var size := Vector2(600, 1066)
var wide := false
var board := Rect2()
var field := Rect2()
var wall := Rect2()
var summary := Rect2()
var controls: Dictionary = {}

func arrange(available: Vector2) -> void:
	size = available
	wide = size.x >= 820
	board = Rect2((size.x - 400) / 2, size.y - (390 if wide else 450), 400, 320)
	wall = Rect2(0, board.position.y - 184, size.x, 64)
	field = Rect2(0, 84, size.x, wall.position.y - 84)
	summary = Rect2(board.position.x, board.position.y - 100, 400, 62) if wide else Rect2(16, 86, size.x - 32, 50)
	controls = {"pause": Rect2(size.x - 188, 0, 80, 80), "menu": Rect2(size.x - 96, 0, 80, 80)}
	for lane in 3:
		controls["gate%d" % lane] = Rect2(gate_x(lane) - 40, wall.position.y, 80, 80)
	var tools := ["map", "refit", "help", "begin", "rally"]
	var shop := ["drive", "guard", "ranger", "mortar", "undo"]
	if wide:
		var side_width := minf(260, (size.x - 448) / 2)
		for i in 5:
			controls[tools[i]] = Rect2(16, size.y - 468 + i * 88, side_width, 80)
			controls[shop[i]] = Rect2(size.x - side_width - 16, size.y - 468 + i * 88, side_width, 80)
	else:
		for i in 3:
			controls[tools[i]] = Rect2(12 + i * 90, board.position.y - 100, 80, 80)
		controls.begin = Rect2(286, board.position.y - 100, size.x - 298, 80)
		controls.rally = Rect2(controls.begin.position, controls.begin.size)
		var width := (size.x - 32) / 5
		for i in 5:
			controls[shop[i]] = Rect2(12 + i * (width + 2), size.y - 112, width - 4, 80)

func gate_x(lane: int) -> float:
	return size.x * float(116 + lane * 184) / 600.0

func field_point(point: Vector2) -> Vector2:
	# Reposition actors over the expanded terrain without stretching their art.
	return Vector2(point.x / 600.0 * size.x, field.position.y + 80 + (point.y - 205) / 332.0 * (field.size.y - 86))

func game_buttons(game: Variant) -> Dictionary:
	var result := controls.duplicate()
	if game.state.phase != "battle":
		result.erase("rally")
	elif not game.state.config.is_empty():
		if game.state.boss_spawned:
			result.erase("begin")
			result.erase("rally")
		else:
			result.rally = result.begin
			result.erase("begin")
	else:
		result.erase("rally")
	if game.state.config.is_empty():
		result.erase("mortar")
		if game.state.phase == "ready":
			result.tutorial = Rect2(size.x / 2 - 210, field.get_center().y + 50, 200, 80)
			result.trial = Rect2(size.x / 2 + 10, field.get_center().y + 50, 200, 80)
	if game.state.phase == "victory" and not game.state.config.is_empty():
		result.next = Rect2(size.x / 2 + 10, field.get_center().y + 60, 220, 80)
	return result
