extends RefCounted
const Gear = preload("res://scripts/gear_rules.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const BLUE_GEAR = preload("res://art/gear_blue.svg")
const GOLD_GEAR = preload("res://art/gear_gold.svg")
const CREAM_GEAR = preload("res://art/gear_cream.svg")

static func board_origin(game: Variant) -> Vector2:
	return Vector2(100, 500 if game.state.phase == "ready" else 660)

static func buttons(game: Variant) -> Dictionary:
	var ready: bool = game.state.phase == "ready"
	var result := {"pause": Rect2(414, 8, 80, 64), "menu": Rect2(506, 8, 80, 64),
		"map": Rect2(8, 525 if ready else 690, 80, 80), "refit": Rect2(8, 635 if ready else 800, 80, 80),
		"help": Rect2(8, 745 if ready else 900, 80, 80), "begin": Rect2(400, 838 if ready else 600, 180, 80)}
	for lane in 3:
		result["gate%d" % lane] = Rect2(76 + lane * 184, 420 if ready else 525, 80, 80)
	for i in 5:
		result[["drive", "guard", "ranger", "mortar", "undo"][i]] = Rect2(10 + i * 118, 940 if ready else 986, 110, 80)
	if game.state.phase == "victory":
		result.next = Rect2(310, 425, 220, 80)
	elif game.state.phase == "battle":
		if game.state.boss_spawned:
			result.erase("begin")
		else:
			result.rally = Rect2(510, 800, 80, 80)
	return result

static func fitted(game: Variant, text: String, width: float, size: int) -> String:
	while game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and text.length() > 2:
		text = text.left(text.length() - (2 if text.ends_with("…") else 1)) + "…"
	return text

static func terrain(game: Variant) -> void:
	var act: int = game.state.config.act
	var ready: bool = game.state.phase == "ready"
	var bottom := 438.0 if ready else 548.0
	var land: Color = [Color("a8bc83"), Color("b5a282"), Color("9d9eac")][act - 1]
	game.draw_rect(Rect2(0, 76, 600, bottom - 76), land)
	game.draw_colored_polygon(PackedVector2Array([Vector2(0, 77), Vector2(600, 77), Vector2(600, 165), Vector2(420, 130), Vector2(220, 174), Vector2(0, 142)]), land.darkened(0.17))
	# Broad curved tracks converge on arches; they are terrain rather than lanes.
	for x in [116, 300, 484]:
		game.draw_polyline(PackedVector2Array([Vector2(x + 30, 155), Vector2(x - 22, 290), Vector2(x + 8, bottom - 80), Vector2(x, bottom)]), land.lightened(0.12), 40, true)
	for i in 21:
		var x := float((i * 137 + act * 37) % 578 + 11)
		var y := 185.0 + float((i * 79) % int(bottom - 220))
		game.draw_circle(Vector2(x, y), 3 + i % 3, land.darkened(0.12))
		game.draw_line(Vector2(x - 4, y), Vector2(x - 9, y - 5), land.darkened(0.28), 2)
	for side in [0, 1]:
		var x := 8.0 if side == 0 else 558.0
		game.draw_colored_polygon(PackedVector2Array([Vector2(x, 95), Vector2(x + 34, 82), Vector2(x + 37, 166), Vector2(x - 3, 171)]), Color("596b69"))
		game.draw_rect(Rect2(x + 5, 108, 23, 34), Color("35484d"))
		game.draw_rect(Rect2(x + 12, 116, 10, 18), game.GOLD)

static func wall(game: Variant) -> void:
	var ready: bool = game.state.phase == "ready"
	var top := 432.0 if ready else 537.0
	game.draw_rect(Rect2(0, top, 600, 56), Color("8b8173"))
	game.draw_rect(Rect2(0, top + 6, 600, 14), Color("d7c79c"))
	for x in range(0, 600, 36):
		game.draw_rect(Rect2(x, top - 12, 23, 18), Color("d7c79c"))
		game.draw_line(Vector2(x, top + 20), Vector2(x, top + 52), Color("655f59"), 2)
	var chosen: Dictionary = game.selected_piece()
	for lane in 3:
		var x := 116 + lane * 184
		var active: bool = chosen.get("kind", "") in Gear.BASE_RATES and int(chosen.get("lane", -1)) == lane
		game.draw_circle(Vector2(x, top + 20), 28, game.GOLD if active else Color("b5a584"))
		game.draw_rect(Rect2(x - 28, top + 20, 56, 36), game.GOLD if active else Color("b5a584"))
		game.draw_circle(Vector2(x, top + 22), 20, game.INK)
		game.draw_rect(Rect2(x - 20, top + 22, 40, 34), game.INK)
		game.label_at(str(lane + 1), Vector2(x, top + 29), 22, game.MINT if active else game.CREAM, true)
	game.draw_rect(Rect2(0, top + 55, 600, 5), Color("6d443f"))
	game.draw_rect(Rect2(0, top + 55, 600 * float(game.state.wall) / Battle.wall_limit(game.state), 5), game.MINT)

static func field_point(point: Vector2) -> Vector2:
	return Vector2(point.x, 160 + (point.y - 205) * 1.12)

static func unit_point(game: Variant, unit: Dictionary) -> Vector2:
	var remaining := float(unit.get("deploy_left", 0.0))
	if remaining <= 0:
		return field_point(Vector2(float(unit.x), float(unit.y)))
	var start: Vector2 = board_origin(game) + Vector2(float(unit.deploy_x) + 0.5, float(unit.deploy_y) + 0.5) * 80
	var gate := Vector2(116 + int(unit.lane) * 184, 532)
	var progress := 1.0 - remaining / float(unit.deploy_total)
	var bend := Vector2(gate.x, 628)
	return start.lerp(bend, progress / 0.65) if progress < 0.65 else bend.lerp(gate, (progress - 0.65) / 0.35)

static func gear(game: Variant, center: Vector2, piece: Dictionary, active: bool, ghost: bool = false) -> void:
	var kind: String = piece.kind
	var texture: Texture2D = GOLD_GEAR if kind == "core" else BLUE_GEAR if kind == "drive" else CREAM_GEAR
	var angle := 0.0
	if active and not game.paused and not game.settings.reduced_effects:
		angle = game.clock * 0.55 * (1 if (int(piece.x) + int(piece.y)) % 2 == 0 else -1)
	game.draw_set_transform(center, angle)
	game.draw_texture_rect(texture, Rect2(-42, -42, 84, 84), false, Color.WHITE if active else Color("8d817d"))
	game.draw_set_transform(Vector2.ZERO)
	if kind in Gear.BASE_RATES:
		game.draw_texture_rect(game.actor_art.textures[kind], Rect2(center - Vector2(22, 30), Vector2(44, 55)), false)
	elif kind == "drive":
		game.label_at(str(int(piece.level)), center + Vector2(0, 10), 31, game.CREAM, true)
	else:
		game.label_at("✦", center + Vector2(0, 12), 34, game.GOLD, true)
	if kind in Gear.BASE_RATES and not ghost:
		game.panel(Rect2(center + Vector2(-34, 21), Vector2(68, 21)), game.INK, Color.TRANSPARENT, 4)
		game.label_at("%.2f/s" % Gear.rate(game.state.board, int(piece.id), game.state.config) if active else "OFF", center + Vector2(0, 38), 17, game.MINT if active else game.RED, true)
		game.label_at(str(int(piece.lane) + 1), center + Vector2(27, -22), 16, game.INK, true)
	if int(piece.id) == game.selected and not ghost:
		game.draw_arc(center, 42, 0, TAU, 48, game.GOLD, 3, true)

static func board(game: Variant) -> void:
	var powered := Gear.powered(game.state.board)
	for y in 4:
		for x in 5:
			var center: Vector2 = game.cell_center(x, y)
			if Gear.cell_allowed(x, y, game.state.encounter, game.state.config):
				game.draw_circle(center, 18, Color("263841"))
				game.draw_circle(center, 4, Color("4c5b59"))
			else:
				game.draw_line(center - Vector2(8, 8), center + Vector2(8, 8), Color("4e4843"), 3)
	for piece in game.state.board:
		for other in game.state.board:
			if int(other.id) > int(piece.id) and powered.has(int(piece.id)) and powered.has(int(other.id)) and absi(int(piece.x) - int(other.x)) + absi(int(piece.y) - int(other.y)) == 1:
				game.draw_circle((game.cell_center(int(piece.x), int(piece.y)) + game.cell_center(int(other.x), int(other.y))) / 2, 7, game.MINT)
	for piece in game.state.board:
		gear(game, game.cell_center(int(piece.x), int(piece.y)), piece, powered.has(int(piece.id)))
	if game.dragging:
		var cell: Vector2i = game.cell_at(game.pointer)
		if Gear.cell_allowed(cell.x, cell.y, game.state.encounter, game.state.config):
			game.draw_arc(game.cell_center(cell.x, cell.y), 39, 0, TAU, 40, game.MINT, 3, true)

static func draw(game: Variant) -> void:
	var state: Dictionary = game.state
	var ready: bool = state.phase == "ready"
	var ui := buttons(game)
	game.draw_rect(Rect2(0, 0, 600, 1066), Color("25343b"))
	terrain(game)
	var current_wave: Dictionary = state.config.waves[maxi(0, int(state.wave) - 1)]
	game.label_at("GEAR BASTION" if ready else fitted(game, str(state.config.name), 380, 24), Vector2(18, 30), 24, game.GOLD)
	game.label_at(fitted(game, "%02d · %s" % [int(state.config.index) + 1, state.config.name] if ready else "%d / %d · %s" % [int(state.wave), state.config.waves.size(), current_wave.name], 380, 19), Vector2(18, 59), 19, game.CREAM)
	for key in ["pause", "menu"]:
		game.panel(ui[key], Color("3d5159"))
		game.label_at("Resume" if key == "pause" and game.paused else "Pause" if key == "pause" else "Menu", ui[key].get_center() + Vector2(0, 7), 19, game.CREAM, true)
	game.label_at("WALL %d" % ceili(float(state.wall)), Vector2(18, 104), 20, game.INK)
	game.label_at("%d / 120" % state.units.size(), Vector2(580, 104) - Vector2(game.font.get_string_size("%d / 120" % state.units.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 0), 20, game.INK)
	if ready:
		game.label_at("BUILD YOUR DEFENSE", Vector2(300, 184), 25, game.INK, true)
		var line := ""
		var y := 228
		for word in str(state.config.decision).split(" "):
			if game.font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x > 450:
				game.label_at(line, Vector2(300, y), 21, game.INK, true)
				y += 28
				line = ""
			line += word + " "
		game.label_at(line, Vector2(300, y), 21, game.INK, true)
		for i in state.config.allowed.size():
			var kind: String = state.config.allowed[i]
			var x: float = 300.0 + (i - (state.config.allowed.size() - 1) / 2.0) * 110
			game.draw_texture_rect(game.actor_art.textures[kind], Rect2(x - 24, 292, 48, 60), false)
			game.label_at(kind.capitalize(), Vector2(x, 379), 18, game.INK, true)
	else:
		var wave: Dictionary = state.config.waves[maxi(0, int(state.wave) - 1)]
		for unit in state.units:
			if float(unit.get("deploy_left", 0)) <= 0:
				game.actor_art.draw_unit(game, unit, true, unit_point(game, unit))
		for unit in state.enemies:
			game.actor_art.draw_unit(game, unit, false, unit_point(game, unit))
		if not game.settings.reduced_effects:
			for arrow in state.projectiles:
				game.draw_line(field_point(Vector2(arrow[0], arrow[1])), field_point(Vector2(arrow[2], arrow[3])), game.GOLD if arrow[4] else game.RED, 2)
		if ui.has("rally"):
			game.panel(ui.rally, Color("3d5159"))
			game.label_at("Rally", ui.rally.get_center() + Vector2(0, -4), 18, game.CREAM, true)
			game.label_at("Fast" if state.rally else "Normal", ui.rally.get_center() + Vector2(0, 22), 15, game.GOLD, true)
	wall(game)
	board(game)
	for unit in state.units:
		if float(unit.get("deploy_left", 0)) > 0:
			game.actor_art.draw_unit(game, unit, true, unit_point(game, unit))
	if not ready:
		game.panel(Rect2(10, 596, 205, 62), Color("25343b"), Color.TRANSPARENT, 4)
	game.label_at("%d brass" % int(state.gold), Vector2(20, 867 if ready else 620), 24, game.GOLD)
	game.label_at("%.2f troops/s" % Gear.total_rate(state.board, state.config), Vector2(20, 900 if ready else 650), 20, game.MINT)
	if ui.has("begin"):
		game.panel(ui.begin, game.MINT if ready else Color("405761"))
		game.label_at("Begin defense" if ready else "Retry" if state.phase in ["defeat", "victory"] else "Threat guide", ui.begin.get_center() + Vector2(0, 7), 22, game.INK if ready else game.CREAM, true)
	elif state.phase == "battle" and state.boss_spawned:
		for boss in state.enemies:
			if boss.kind in ["captain", "siege", "matriarch"]:
				game.panel(Rect2(220, 598, 365, 58), game.INK, game.GOLD, 5)
				game.label_at("%s · P%d · %d HP" % [str(boss.kind).capitalize(), int(state.boss_phase), ceili(float(boss.hp))], Vector2(402, 620), 20, game.GOLD, true)
				game.draw_rect(Rect2(226, 627, 353 * float(boss.hp) / float(boss.max_hp), 4), game.RED)
				var warning := "Enrage in %ds" % ceili(maxf(0, 60 - float(state.boss_total)))
				if boss.kind != "captain" or float(state.boss_total) >= 60:
					warning = "Volley %ds · %s" % [ceili(12 - float(state.boss_volley)), "ENRAGED" if float(state.boss_total) >= 60 else "enrage %ds" % ceili(60 - float(state.boss_total))]
				game.label_at(warning, Vector2(402, 650), 18, game.RED if float(state.boss_total) >= 60 else game.CREAM, true)
	for key in ["map", "refit", "help"]:
		game.panel(ui[key], Color("3d5159"))
		var text := "Map" if key == "map" else "Guide" if key == "help" else "Refit"
		game.label_at(text, ui[key].get_center() + Vector2(0, -2 if key == "refit" else 7), 19, game.CREAM, true)
		if key == "refit":
			var p: Dictionary = game.selected_piece()
			if p.get("kind", "") in state.config.allowed and state.config.allowed.size() > 1:
				var next: String = state.config.allowed[(state.config.allowed.find(p.kind) + 1) % state.config.allowed.size()]
				var cost: int = int(state.config.costs[next]) - int(state.config.costs[p.kind])
				game.label_at("%s %+d" % [next.left(1).to_upper(), cost], ui[key].get_center() + Vector2(0, 25), 17, game.GOLD, true)
	for key in ["drive", "guard", "ranger", "mortar", "undo"]:
		var available: bool = key in ["drive", "undo"] or key in state.config.allowed
		game.panel(ui[key], Color("405761") if available else Color("2d3d44"))
		game.label_at(key.capitalize() if available else "Locked", ui[key].get_center() + Vector2(0, -5), 19, game.CREAM if available else Color("83908c"), true)
		game.label_at(str(state.config.costs[key]) if key != "undo" else "move", ui[key].get_center() + Vector2(0, 22), 18, game.GOLD, true)
	if ready:
		game.label_at(fitted(game, game.message, 565, 17), Vector2(300, 1050), 17, game.MINT, true)
	elif state.phase == "battle":
		if not state.boss_spawned and game.clock < game.message_until:
			game.panel(Rect2(20, 484, 560, 36), game.INK, Color.TRANSPARENT, 5)
			game.label_at(fitted(game, game.message, 540, 17), Vector2(300, 509), 17, game.MINT, true)
	if game.paused or state.phase in ["victory", "defeat"]:
		game.panel(Rect2(70, 260, 460, 155), game.INK, game.GOLD)
		game.label_at("GATE HELD" if state.phase == "victory" else "WALL BREACHED" if state.phase == "defeat" else "PAUSED", Vector2(300, 307), 30, game.MINT if state.phase == "victory" else game.RED if state.phase == "defeat" else game.GOLD, true)
		game.label_at("%d built · %d raiders stopped" % [int(state.produced), int(state.kills)], Vector2(300, 351), 21, game.CREAM, true)
		game.label_at("%d troops lost · %d:%02d" % [int(state.losses), int(state.time) / 60, int(state.time) % 60] if state.phase in ["victory", "defeat"] else "Resume when ready", Vector2(300, 389), 21, game.GOLD, true)
		if state.phase == "victory":
			game.panel(ui.next, Color("32645b"), game.MINT)
			game.label_at("More trials" if bool(state.config.get("challenge", false)) else "Ending" if state.encounter == "camp_09" else "Next gate", ui.next.get_center() + Vector2(0, 8), 23, game.CREAM, true)
	if game.save_failed:
		game.panel(Rect2(20, 208, 560, 44), game.INK, game.RED)
		game.label_at("Save failed · Menu > Save offers export", Vector2(300, 237), 19, game.RED, true)
	if game.dragging:
		var piece: Dictionary = game.selected_piece() if game.drag_kind == "" else Gear.piece(0, game.drag_kind, 0, 0)
		if not piece.is_empty():
			gear(game, game.pointer - Vector2(0, 42), piece, true, true)
