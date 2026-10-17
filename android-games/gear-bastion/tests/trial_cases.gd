extends RefCounted
const Battle = preload("res://scripts/battle_rules.gd")
const Gear = preload("res://scripts/gear_rules.gd")

static func purchase(state: Dictionary, kind: String, x: int, y: int, lane: int) -> void:
	var result := Gear.buy(state.board, kind, x, y, int(state.gold), int(state.next_id), "iron_trial")
	assert(result.ok)
	state.board = result.board
	state.board.back().lane = lane
	state.gold = result.gold
	state.next_id += 1
	state.spent += int(Gear.COSTS[kind])

static func build(strategy: String, seed_value: int = 1701) -> Dictionary:
	var state := Battle.initial(seed_value, "iron_trial")
	if strategy == "B":
		purchase(state, "guard", 1, 2, 0)
		purchase(state, "guard", 3, 2, 2)
		purchase(state, "guard", 2, 3, 1)
		purchase(state, "ranger", 1, 1, 0)
	elif strategy == "R":
		purchase(state, "ranger", 1, 2, 0)
		purchase(state, "ranger", 3, 2, 2)
		purchase(state, "ranger", 2, 3, 1)
		purchase(state, "drive", 1, 3, 1)
		purchase(state, "drive", 3, 3, 1)
	else:
		purchase(state, "guard", 1, 2, 0)
		purchase(state, "guard", 3, 2, 2)
		purchase(state, "guard" if strategy == "C" else "ranger", 1, 1, 0)
		purchase(state, "guard" if strategy == "C" else "ranger", 3, 1, 2)
	return state

static func repair(state: Dictionary) -> void:
	for id in [5, 6]:
		var result := Gear.refit(state.board, id, int(state.gold))
		assert(result.ok)
		state.board = result.board
		state.gold = result.gold
		state.spent += result.cost
