extends SceneTree

const Rules = preload("res://rules.gd")
var failures := 0

func _initialize() -> void:
	var state: Dictionary = Rules.initial_state()
	_check(Rules.valid(state), "fresh state validates")
	_check(not Rules.place(state, -1), "negative placement rejected")
	_check(not Rules.place(state, 12), "outside placement rejected")
	_check(state["coins"] == 100, "invalid placement does not charge")
	_check(Rules.place(state, 0), "valid placement accepted")
	_check(not Rules.place(state, 0), "duplicate placement rejected")
	_check(state["coins"] == 80, "duplicate does not double charge")
	for cell in range(1, 5):
		Rules.place(state, cell)
	_check(not Rules.place(state, 5), "unaffordable placement rejected")
	for wave in range(8):
		Rules.run_wave(state)
	_check(state["result"] == "victory", "defense can win a complete run")
	_check(state["health"] == 100, "sufficient defense protects base")
	var before: String = JSON.stringify(state)
	Rules.run_wave(state)
	_check(JSON.stringify(state) == before, "completed run cannot farm rewards")
	var restored: Dictionary = Rules.restore(JSON.parse_string(before))
	_check(Rules.valid(restored), "JSON roundtrip validates")
	_check(restored["pads"] == state["pads"], "placements survive roundtrip")
	_check(not Rules.place(restored, 0), "restored placement still blocks duplicates")
	state = Rules.initial_state()
	for wave in range(8):
		Rules.run_wave(state)
	_check(state["result"] == "defeat", "undefended base loses")
	_check(state["health"] == 0, "health clamps at zero")
	_check(not Rules.valid({"version": 1}), "incomplete save rejected")
	state = Rules.initial_state()
	state["pads"] = [1, 1]
	_check(not Rules.valid(state), "duplicate save placements rejected")
	state["pads"] = [1.5]
	_check(not Rules.valid(state), "fractional save placements rejected")
	print("PROBE_2D_TESTS: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
