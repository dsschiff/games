extends SceneTree
const S = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0
var details: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func tap(button: Button) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * button.get_global_rect().get_center()
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame

func run() -> void:
	root.size = Vector2i(720, 1280)
	var before := S.read()
	check(before.ok and before.state.phase == "playing", "separate process receives copied real app-written active save")
	if not before.ok:
		quit(1)
		return
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in 60:
		await physics_frame
	check(scene.state == before.state and scene.profile == before.profile and scene.settings == before.settings, "whole battle, earned profile and settings survive cold process launch")
	check(scene.paused and scene.menu.visible, "cold active launch pauses automatically")
	check(S.read().revision > before.revision, "new process creates fresh valid revision")
	check(not scene.settings.sound and scene.settings.reduced_effects and scene.profile.wins == 1 and scene.profile.attempts == 3, "three real outcomes and settings survived prior process exit")
	var resume: Button
	for b in scene.menu.get_children():
		if b is Button and b.text == "RESUME":
			resume = b
	await tap(resume)
	for i in 75:
		await physics_frame
	check(not scene.paused and scene.state.time > before.state.time + 1, "actual touch Resume advances ordinary cold-restored battle")
	check(S.read().state.time > before.state.time, "resumed process writes advanced state without test save calls")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			var f := FileAccess.open(arg.trim_prefix("--capture-dir=").path_join("restore-report.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "before": before, "after": S.read(), "scope": "Separate desktop process using copied prior app-written save; actual ScreenTouch Resume. Not native Android lifecycle proof."}, "  "))
	scene.queue_free()
	await process_frame
	await process_frame
	print("FRONTLINE_RESTORE ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
