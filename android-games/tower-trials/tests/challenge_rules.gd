extends SceneTree
const Cases = preload("res://tests/challenge_cases.gd")
func _initialize() -> void:
	var result := Cases.new().run_suite()
	if result.failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if result.failures.is_empty() else 1)
