extends RefCounted

const VERSION := 1
const CELLS := 12
const PRICE := 20

static func initial_state() -> Dictionary:
	return {"version": VERSION, "coins": 100, "health": 100, "wave": 0, "pads": [], "result": "building"}

static func place(state: Dictionary, cell: int) -> bool:
	if cell < 0 or cell >= CELLS or state["coins"] < PRICE or state["pads"].has(cell):
		return false
	state["coins"] -= PRICE
	state["pads"].append(cell)
	return true

static func run_wave(state: Dictionary) -> void:
	if state["result"] == "defeat" or state["result"] == "victory":
		return
	state["wave"] += 1
	var pressure: int = 12 + state["wave"] * 5
	var defense: int = state["pads"].size() * 11
	state["health"] = maxi(0, state["health"] - maxi(0, pressure - defense))
	state["coins"] += 24
	state["result"] = "defeat" if state["health"] == 0 else ("victory" if state["wave"] >= 8 else "building")

static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["version", "coins", "health", "wave", "pads", "result"]:
		if not value.has(key):
			return false
	if value["version"] != VERSION or not value["pads"] is Array:
		return false
	for key in ["coins", "health", "wave"]:
		if not (value[key] is int or value[key] is float) or value[key] < 0 or value[key] != int(value[key]):
			return false
	if value["health"] > 100 or value["wave"] > 8 or not value["result"] in ["building", "victory", "defeat"]:
		return false
	var seen := {}
	for cell in value["pads"]:
		if not (cell is int or cell is float) or cell != int(cell) or cell < 0 or cell >= CELLS or seen.has(int(cell)):
			return false
		seen[int(cell)] = true
	return true

static func restore(value: Variant) -> Dictionary:
	if not valid(value):
		return {}
	var state: Dictionary = value.duplicate(true)
	for key in ["version", "coins", "health", "wave"]:
		state[key] = int(state[key])
	for index in range(state["pads"].size()):
		state["pads"][index] = int(state["pads"][index])
	return state

