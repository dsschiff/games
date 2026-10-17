extends SceneTree

const Rules = preload("res://rules.gd")
var failures := 0

func _initialize() -> void:
	var state: Dictionary = Rules.initial_state()
	_check(Rules.valid(state), "fresh state validates")
	Rules.step(state, Vector2(100, 100), 0.1)
	_check(Vector2(state["x"], state["z"]).length() <= 0.421, "input cannot exceed movement speed")
	for index in range(100):
		Rules.step(state, Vector2(1, 0), 0.1)
	_check(state["x"] <= 6.5, "movement remains inside arena")
	var encoded := JSON.stringify(state)
	var restored: Dictionary = Rules.restore(JSON.parse_string(encoded))
	_check(Rules.valid(restored), "moving encounter JSON restores")
	Rules.step(state, Vector2(0, 1), 0.05)
	Rules.step(restored, Vector2(0, 1), 0.05)
	_check(is_equal_approx(state["x"], restored["x"]) and is_equal_approx(state["z"], restored["z"]) and state["kills"] == restored["kills"], "resumed encounter preserves position and outcome")
	_check(state["enemies"].size() == restored["enemies"].size(), "resumed encounter preserves enemy count")
	for index in range(state["enemies"].size()):
		_check(is_equal_approx(state["enemies"][index]["x"], restored["enemies"][index]["x"]) and is_equal_approx(state["enemies"][index]["z"], restored["enemies"][index]["z"]), "restored enemies take same movement step")
	state = Rules.initial_state()
	state["enemies"] = [{"id": 1, "x": 0.0, "z": 0.0}]
	state["serial"] = 1
	state["shot"] = 10.0
	state["spawn"] = 10.0
	for index in range(60):
		Rules.step(state, Vector2.ZERO, 0.1)
	_check(state["result"] == "defeat" and state["health"] == 0, "close enemies can cause defeat")
	var completed := JSON.stringify(state)
	Rules.step(state, Vector2.ONE, 0.1)
	_check(completed == JSON.stringify(state), "defeat freezes encounter")
	state = Rules.initial_state()
	state["kills"] = 29
	state["enemies"] = [{"id": 1, "x": 1.0, "z": 0.0}]
	state["serial"] = 1
	state["spawn"] = 10.0
	Rules.step(state, Vector2.ZERO, 0.1)
	_check(state["result"] == "victory", "thirtieth kill completes run")
	state["health"] = -1
	_check(not Rules.valid(state), "negative health save rejected")
	_check(not Rules.valid({"version": 1}), "partial save rejected")
	print("PROBE_3D_TESTS: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
