extends RefCounted
const Gear = preload("res://scripts/gear_rules.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const BLUE_GEAR = preload("res://art/gear_blue.svg")
const GOLD_GEAR = preload("res://art/gear_gold.svg")
const CREAM_GEAR = preload("res://art/gear_cream.svg")

static func board_origin(game: Variant) -> Vector2:
	return game.layout.board.position

static func buttons(game: Variant) -> Dictionary:
	return game.layout.game_buttons(game)

static func fitted(game: Variant, text: String, width: float, size: int) -> String:
	while game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and text.length() > 2:
		text = text.left(text.length() - (2 if text.ends_with("…") else 1)) + "…"
	return text

static func unit_point(game: Variant, unit: Dictionary) -> Vector2:
	var remaining := float(unit.get("deploy_left", 0.0))
	if remaining <= 0:
		return game.layout.field_point(Vector2(float(unit.x), float(unit.y)))
	var start: Vector2 = game.cell_center(int(unit.deploy_x), int(unit.deploy_y))
	var gate := Vector2(game.layout.gate_x(int(unit.lane)), game.layout.wall.position.y)
	var progress := 1.0 - remaining / float(unit.deploy_total)
	var bend := Vector2(gate.x, game.layout.board.position.y - 16)
	return start.lerp(bend, progress / 0.65) if progress < 0.65 else bend.lerp(gate, (progress - 0.65) / 0.35)

static func terrain(game: Variant) -> void:
	var field: Rect2 = game.layout.field
	var act: int = game.state.config.get("act", 1)
	var land: Color = [Color("a8bc83"), Color("b5a282"), Color("9d9eac")][act - 1]
	game.draw_rect(field, land)
	game.draw_rect(Rect2(field.position, Vector2(field.size.x, 68)), land.darkened(0.17))
	for lane in 3:
		var x: float = game.layout.gate_x(lane)
		game.draw_polyline(PackedVector2Array([Vector2(x + 30, field.position.y + 65), Vector2(x - 22, field.get_center().y), Vector2(x + 8, field.end.y - 80), Vector2(x, field.end.y)]), land.lightened(0.12), 40, true)
	for i in maxi(21, int(field.size.x * field.size.y / 10000)):
		var x := fmod(float(i * 137 + act * 37), field.size.x - 20) + 10
		var y := field.position.y + 80 + fmod(float(i * 79), maxf(1, field.size.y - 90))
		game.draw_circle(Vector2(x, y), 3 + i % 3, land.darkened(0.12))
		game.draw_line(Vector2(x - 4, y), Vector2(x - 9, y - 5), land.darkened(0.28), 2)
	for side in [0, 1]:
		var x: float = 8 if side == 0 else field.size.x - 42
		game.draw_rect(Rect2(x, field.position.y + 8, 34, 70), Color("596b69"))
		game.draw_rect(Rect2(x + 5, field.position.y + 22, 23, 34), Color("35484d"))
		game.draw_rect(Rect2(x + 12, field.position.y + 30, 10, 18), game.GOLD)

static func wall(game: Variant) -> void:
	var box: Rect2 = game.layout.wall
	game.draw_rect(box, Color("8b8173"))
	game.draw_rect(Rect2(box.position + Vector2(0, 6), Vector2(box.size.x, 14)), Color("d7c79c"))
	for x in range(0, int(box.size.x), 36):
		game.draw_rect(Rect2(x, box.position.y - 12, 23, 18), Color("d7c79c"))
	var chosen: Dictionary = game.selected_piece()
	for lane in 3:
		var x: float = game.layout.gate_x(lane)
		var active: bool = chosen.get("kind", "") in Gear.BASE_RATES and int(chosen.get("lane", -1)) == lane
		game.draw_circle(Vector2(x, box.position.y + 20), 28, game.GOLD if active else Color("b5a584"))
		game.draw_rect(Rect2(x - 28, box.position.y + 20, 56, 36), game.GOLD if active else Color("b5a584"))
		game.draw_circle(Vector2(x, box.position.y + 22), 20, game.INK)
		game.draw_rect(Rect2(x - 20, box.position.y + 22, 40, 34), game.INK)
		game.label_at(str(lane + 1), Vector2(x, box.position.y + 29), 22, game.MINT if active else game.CREAM, true)
	game.draw_rect(Rect2(0, box.end.y - 5, box.size.x, 5), Color("6d443f"))
	game.draw_rect(Rect2(0, box.end.y - 5, box.size.x * float(game.state.wall) / Battle.wall_limit(game.state), 5), game.MINT)

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
	var layout: RefCounted = game.layout
	var size: Vector2 = layout.size
	var ready: bool = state.phase == "ready"
	var ui := buttons(game)
	var config: Dictionary = state.config
	var allowed: Array = config.get("allowed", ["guard", "ranger"])
	game.draw_rect(Rect2(Vector2.ZERO, size), Color("25343b"))
	terrain(game)
	var waves: Array = Battle.run_waves(state)
	var wave: Dictionary = waves[maxi(0, int(state.wave) - 1)]
	var title: String = config.get("name", "Iron Trial" if state.encounter == "iron_trial" else "Practice foundry")
	game.label_at(fitted(game, title, size.x - 222, 24), Vector2(18, 30), 24, game.GOLD)
	game.label_at(fitted(game, "Prepare your defense" if ready else "%d / %d · %s" % [int(state.wave), waves.size(), wave.name], size.x - 222, 19), Vector2(18, 59), 19, game.CREAM)
	for key in ["pause", "menu"]:
		game.panel(ui[key], Color("3d5159"))
		game.label_at("Resume" if key == "pause" and game.paused else "Pause" if key == "pause" else "Menu", ui[key].get_center() + Vector2(0, 7), 19, game.CREAM, true)
	if ready:
		var brief := Rect2(36, layout.field.position.y + 85, size.x - 72, layout.field.size.y - 95)
		game.label_at("BUILD YOUR DEFENSE", Vector2(size.x / 2, brief.position.y + 25), 25, game.INK, true)
		var line := ""
		var y: float = brief.position.y + 65
		var decision: String = config.get("decision", "Connect gears to the brass core. Drives speed adjacent troop gears.")
		for word in decision.split(" "):
			if game.font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x > minf(720, brief.size.x):
				game.label_at(line, Vector2(size.x / 2, y), 21, game.INK, true)
				y += 28
				line = ""
			line += word + " "
		game.label_at(line, Vector2(size.x / 2, y), 21, game.INK, true)
		if config.is_empty():
			for key in ["tutorial", "trial"]:
				game.panel(ui[key], game.INK)
				game.label_at("Practice" if key == "tutorial" else "Iron Trial", ui[key].get_center() + Vector2(0, 8), 23, game.CREAM, true)
	else:
		for unit in state.units:
			if float(unit.get("deploy_left", 0)) <= 0:
				game.actor_art.draw_unit(game, unit, true, unit_point(game, unit))
		for unit in state.enemies:
			game.actor_art.draw_unit(game, unit, false, unit_point(game, unit))
		if not game.settings.reduced_effects:
			for arrow in state.projectiles:
				game.draw_line(layout.field_point(Vector2(arrow[0], arrow[1])), layout.field_point(Vector2(arrow[2], arrow[3])), game.GOLD if arrow[4] else game.RED, 2)
	wall(game)
	game.panel(layout.board.grow(8), Color("1e3038"), Color("516365"))
	board(game)
	for unit in state.units:
		if float(unit.get("deploy_left", 0)) > 0:
			game.actor_art.draw_unit(game, unit, true, unit_point(game, unit))
	var summary: Rect2 = layout.summary
	game.panel(summary, game.INK, Color.TRANSPARENT, 4)
	game.label_at("%d brass · %.2f troops/s" % [int(state.gold), Gear.total_rate(state.board, config)], summary.position + Vector2(12, 25), 21, game.GOLD)
	game.label_at("Wall %d · Army %d / 120" % [ceili(float(state.wall)), state.units.size()], summary.position + Vector2(12, 48), 18, game.MINT)
	for key in ["map", "refit", "help", "begin", "rally"]:
		if not ui.has(key):
			continue
		game.panel(ui[key], game.MINT if key == "begin" and ready else Color("3d5159"))
		var text: String = {"map": "Map", "refit": "Refit", "help": "Guide", "begin": "Begin defense" if ready else "Retry" if state.phase in ["victory", "defeat"] else "Threat guide", "rally": "Rally: fast" if state.rally else "Rally"}[key]
		game.label_at(text, ui[key].get_center() + Vector2(0, -2 if key == "refit" else 7), 19, game.INK if ready and key == "begin" else game.CREAM, true)
		if key == "refit":
			var piece: Dictionary = game.selected_piece()
			if piece.get("kind", "") in allowed and allowed.size() > 1:
				var next: String = allowed[(allowed.find(piece.kind) + 1) % allowed.size()]
				var costs: Dictionary = config.get("costs", Gear.COSTS)
				game.label_at("%s %+d" % [next.left(1).to_upper(), int(costs[next]) - int(costs[piece.kind])], ui[key].get_center() + Vector2(0, 25), 17, game.GOLD, true)
	for key in ["drive", "guard", "ranger", "mortar", "undo"]:
		if not ui.has(key):
			continue
		var available: bool = key in ["drive", "undo"] or key in allowed
		game.panel(ui[key], Color("405761") if available else Color("2d3d44"))
		game.label_at(key.capitalize() if available else "Locked", ui[key].get_center() + Vector2(0, -5), 19, game.CREAM if available else Color("83908c"), true)
		game.label_at(str(config.get("costs", Gear.COSTS)[key]) if key != "undo" else "move", ui[key].get_center() + Vector2(0, 22), 18, game.GOLD, true)
	game.label_at(fitted(game, game.message, size.x - 30, 17), Vector2(size.x / 2, size.y - 10), 17, game.MINT, true)
	if not ready and state.boss_spawned:
		for boss in state.enemies:
			if boss.kind in ["captain", "siege", "matriarch"]:
				var box := Rect2(48, layout.field.position.y + 66, size.x - 96, 64)
				game.panel(box, game.INK, game.GOLD, 5)
				var warning := "Enrage in %ds" % ceili(maxf(0, 60 - float(state.boss_total)))
				if boss.kind != "captain" or float(state.boss_total) >= 60:
					warning = "Volley %ds · %s" % [ceili(12 - float(state.boss_volley)), "ENRAGED" if float(state.boss_total) >= 60 else "enrage %ds" % ceili(60 - float(state.boss_total))]
				game.label_at("%s · P%d · %d HP · %s" % [str(boss.kind).capitalize(), int(state.boss_phase), ceili(float(boss.hp)), warning], box.get_center() + Vector2(0, 3), 18, game.GOLD, true)
				game.draw_rect(Rect2(box.position + Vector2(8, 52), Vector2((box.size.x - 16) * float(boss.hp) / float(boss.max_hp), 4)), game.RED)
	if game.paused or state.phase in ["victory", "defeat"]:
		var center: Vector2 = layout.field.get_center()
		game.panel(Rect2(center - Vector2(230, 100), Vector2(460, 155)), game.INK, game.GOLD)
		game.label_at("GATE HELD" if state.phase == "victory" else "WALL BREACHED" if state.phase == "defeat" else "PAUSED", center + Vector2(0, -53), 30, game.MINT if state.phase == "victory" else game.RED if state.phase == "defeat" else game.GOLD, true)
		game.label_at("%d built · %d raiders stopped" % [int(state.produced), int(state.kills)], center + Vector2(0, -9), 21, game.CREAM, true)
		game.label_at("%d troops lost · %d:%02d" % [int(state.losses), int(state.time) / 60, int(state.time) % 60] if state.phase in ["victory", "defeat"] else "Resume when ready", center + Vector2(0, 29), 21, game.GOLD, true)
		if ui.has("next"):
			game.panel(ui.next, Color("32645b"), game.MINT)
			game.label_at("More trials" if bool(config.get("challenge", false)) else "Ending" if state.encounter == "camp_09" else "Next gate", ui.next.get_center() + Vector2(0, 8), 23, game.CREAM, true)
	if game.save_failed:
		game.panel(Rect2(20, 84, size.x - 40, 50), game.INK, game.RED)
		game.label_at("Save failed · Menu > Save offers export", Vector2(size.x / 2, 116), 19, game.RED, true)
	if game.dragging:
		var piece: Dictionary = game.selected_piece() if game.drag_kind == "" else Gear.piece(0, game.drag_kind, 0, 0)
		if not piece.is_empty():
			gear(game, game.pointer - Vector2(0, 42), piece, true, true)
