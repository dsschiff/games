class_name GearRules
extends RefCounted
## Deterministic socket graph. No path accumulation or cyclic multiplication.

const WIDTH := 5
const HEIGHT := 4
const COSTS := {"drive": 6, "guard": 12, "ranger": 14}
const BASE_RATES := {"guard": 0.72, "ranger": 0.52}

static func initial_board() -> Array:
	return [piece(1, "core", 2, 2), piece(2, "guard", 1, 2, 1, 0),
		piece(3, "ranger", 3, 2, 1, 2), piece(4, "drive", 2, 1),
		piece(5, "drive", 2, 0)]

static func piece(id: int, kind: String, x: int, y: int, level: int = 1, lane: int = 1) -> Dictionary:
	return {"id": id, "kind": kind, "x": x, "y": y, "level": level, "lane": lane}

static func at(board: Array, x: int, y: int) -> int:
	for i in board.size():
		if int(board[i].x) == x and int(board[i].y) == y:
			return i
	return -1

static func powered(board: Array) -> Dictionary:
	var result: Dictionary = {}
	var frontier: Array = []
	for i in board.size():
		if board[i].kind == "core":
			result[int(board[i].id)] = 0
			frontier.append(i)
	while not frontier.is_empty():
		var index: int = frontier.pop_front()
		var p: Dictionary = board[index]
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := at(board, int(p.x) + delta.x, int(p.y) + delta.y)
			if neighbor >= 0 and not result.has(int(board[neighbor].id)):
				result[int(board[neighbor].id)] = int(result[int(p.id)]) + 1
				frontier.append(neighbor)
	return result

static func rate(board: Array, id: int) -> float:
	return float(rates(board).get(id, 0.0))

static func rates(board: Array) -> Dictionary:
	var network := powered(board)
	var result: Dictionary = {}
	for p in board:
		if not network.has(int(p.id)) or not BASE_RATES.has(p.kind):
			continue
		var adjacent_levels := 0
		for other in board:
			if other.kind == "drive" and network.has(int(other.id)):
				if absi(int(p.x) - int(other.x)) + absi(int(p.y) - int(other.y)) == 1:
					adjacent_levels += int(other.level)
		result[int(p.id)] = float(BASE_RATES[p.kind]) * minf(3.0, 1.0 + 0.25 * adjacent_levels)
	return result

static func total_rate(board: Array) -> float:
	var result := 0.0
	for value in rates(board).values():
		result += float(value)
	return result

static func move(board: Array, id: int, x: int, y: int) -> Dictionary:
	var unchanged := {"ok": false, "board": board.duplicate(true), "message": "Move cancelled · board retained"}
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return unchanged
	var source := -1
	for i in board.size():
		if int(board[i].id) == id:
			source = i
	if source < 0 or board[source].kind == "core":
		return unchanged
	var copy: Array = board.duplicate(true)
	var target := at(copy, x, y)
	if target == source:
		return unchanged
	if target >= 0:
		if copy[source].kind != "drive" or copy[target].kind != "drive" or int(copy[source].level) != int(copy[target].level) or int(copy[source].level) >= 4:
			return unchanged
		copy[target].level = int(copy[target].level) + 1
		copy.remove_at(source)
		return {"ok": true, "board": copy, "message": "Equal drives merged · Undo restores both"}
	copy[source].x = x
	copy[source].y = y
	return {"ok": true, "board": copy, "message": "Network changed · Undo available"}

static func buy(board: Array, kind: String, x: int, y: int, gold: int, next_id: int) -> Dictionary:
	if not COSTS.has(kind) or x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT or at(board, x, y) >= 0:
		return {"ok": false, "message": "Choose an empty socket"}
	if gold < int(COSTS[kind]):
		return {"ok": false, "message": "Need %d brass" % int(COSTS[kind])}
	var copy := board.duplicate(true)
	copy.append(piece(next_id, kind, x, y))
	return {"ok": true, "board": copy, "gold": gold - int(COSTS[kind]), "message": "Installed · connect to the core"}

static func valid_board(board: Array) -> bool:
	if board.size() > WIDTH * HEIGHT or board.is_empty():
		return false
	var cells: Dictionary = {}
	var ids: Dictionary = {}
	var cores := 0
	for p in board:
		if not p is Dictionary:
			return false
		for key in ["id", "kind", "x", "y", "level", "lane"]:
			if not p.has(key):
				return false
		for key in ["id", "x", "y", "level", "lane"]:
			if not (p[key] is int or p[key] is float) or not is_finite(float(p[key])) or absf(float(p[key])) > 100000000 or float(p[key]) != int(p[key]):
				return false
		if not str(p.kind) in ["core", "drive", "guard", "ranger"]:
			return false
		if float(p.x) != int(p.x) or float(p.y) != int(p.y) or int(p.x) < 0 or int(p.x) >= WIDTH or int(p.y) < 0 or int(p.y) >= HEIGHT:
			return false
		if int(p.level) < 1 or int(p.level) > 4 or int(p.lane) < 0 or int(p.lane) > 2 or int(p.id) <= 0:
			return false
		var key := "%d,%d" % [int(p.x), int(p.y)]
		if cells.has(key) or ids.has(int(p.id)):
			return false
		cells[key] = true
		ids[int(p.id)] = true
		if p.kind == "core":
			cores += 1
	return cores == 1
