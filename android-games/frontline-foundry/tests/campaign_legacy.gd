extends SceneTree
const S = preload("res://scripts/save_store.gd")
const D = preload("res://scripts/definitions.gd")
var checks := 0
var failures := 0
var details: Array = []
var events: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func touch(scene: Node, text: String) -> void:
	var b: Button
	for child in scene.find_children("*", "Button", true, false):
		if child.text == text and child.is_visible_in_tree():
			b = child
	if b == null or b.disabled:
		check(false, "missing real legacy control " + text)
		return
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * b.get_global_rect().get_center()
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"kind": "touch", "pressed": pressed, "target": text, "position": [e.position.x, e.position.y], "frame": Engine.get_physics_frames()})
		await process_frame

func run() -> void:
	root.size = Vector2i(720, 1280)
	var before := S.read()
	check(before.ok and before.state.catalog == 1 and before.state.phase == "playing", "genuine earlier app-written desktop prototype battle supplied; no injected state")
	if not before.ok:
		quit(1)
		return
	var app: Node = load("res://boot.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	for i in 20:
		await physics_frame
	var scene: Node = app.session
	check(scene.paused and D.same(scene.state, before.state), "catalog1 entire active entities/cooldowns/equipment/wallet/ledgers stay exact on new launch")
	check(D.same(scene.profile, before.profile) and D.same(scene.settings, before.settings), "whole legacy earned profile and settings stay exact")
	check(S.read().version == 2 and D.same(S.read().state, before.state), "new schema2 writes preserve every old battle field")
	check(S.read().career.clears.is_empty() and not S.read().career.ending, "old prototype win never fabricates campaign progress")
	await touch(scene, "RESUME")
	for i in 90:
		await physics_frame
	check(scene.state.time > before.state.time + 1 and scene.state.catalog == 1, "actual Resume continues original catalog1 rules rather than starting campaign")
	await touch(scene, "II")
	var retained: Dictionary = scene.state.duplicate(true)
	var profile: Dictionary = scene.profile.duplicate(true)
	await touch(scene, "BEGIN CAMPAIGN")
	for i in 8:
		await process_frame
	app = current_scene
	scene = app.session
	check(scene.state.catalog == 2 and scene.state.phase == "ready" and scene.state.definition.index == 0, "explicit actual Begin Campaign starts first district")
	check(scene.career.clears.is_empty() and scene.career.attempts == 0 and D.same(scene.career.legacy_state, retained) and D.same(scene.career.legacy_profile, profile), "campaign entry retains whole resumed prototype as backup without inventing clears")
	check(D.same(scene.settings, before.settings) and S.read().ok, "settings and complete legacy backup durably preserved after explicit transition")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			var f := FileAccess.open(arg.trim_prefix("--capture-dir=").path_join("legacy-report.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "before": before, "retained_legacy": retained, "after": S.read(), "raw_inputs": events, "scope": "Genuinely earned original desktop catalog1 active save; actual native Android rev213 install-r update remains coordinator-owned."}, "  "))
	app.queue_free()
	await process_frame
	await process_frame
	print("FRONTLINE_CAMPAIGN_LEGACY ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
