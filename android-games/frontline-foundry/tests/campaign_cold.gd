extends SceneTree
const S = preload("res://scripts/save_store.gd")
const D = preload("res://scripts/definitions.gd")
const Faults = preload("res://tests/fault_files.gd")
var app: Node
var scene: Node
var checks := 0
var failures := 0
var details: Array = []
var raw_inputs: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func whole() -> Dictionary:
	return {"state": scene.state.duplicate(true), "career": scene.career.duplicate(true), "profile": scene.profile.duplicate(true), "settings": scene.settings.duplicate(true)}

func disk() -> Dictionary:
	var result := {}
	for i in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(i) + suffix
			if FileAccess.file_exists(path):
				result[path] = FileAccess.get_file_as_string(path)
	return result

func tap(text: String) -> void:
	var target: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			target = b
	if target == null or target.disabled:
		check(false, "missing real control " + text)
		return
	await touch(target.get_global_rect().get_center(), text)

func touch(point: Vector2, target: String) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * point
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		raw_inputs.append({"frame": Engine.get_physics_frames(), "kind": "touch", "pressed": pressed, "target": target, "position": [e.position.x, e.position.y]})
		await process_frame

func key(code: int, ctrl: bool = false, unicode_value: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.ctrl_pressed = ctrl
		e.unicode = unicode_value
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		raw_inputs.append({"frame": Engine.get_physics_frames(), "kind": "key", "pressed": pressed, "key": code, "ctrl": ctrl, "unicode": unicode_value})
		await process_frame

func run() -> void:
	root.size = Vector2i(720, 1280)
	var saved := S.read()
	check(saved.ok and saved.state.catalog == 2 and saved.state.phase == "playing", "separate process receives genuine app-written active campaign run")
	if not saved.ok:
		quit(1)
		return
	app = load("res://boot.tscn").instantiate()
	root.add_child(app)
	for i in 30:
		await physics_frame
	scene = app.session
	check(D.same(scene.state, saved.state) and D.same(scene.career, saved.career) and D.same(scene.profile, saved.profile) and D.same(scene.settings, saved.settings), "whole state/definitions/career/legacy profile/settings preserved on cold launch")
	check(scene.paused and scene.menu.visible and S.read().revision > saved.revision, "cold active launch pauses and writes a fresh valid revision")
	check(scene.career.ending and scene.career.clears.size() == 12 and scene.career.skirmishes.size() > 0, "ending and independent seeded record survive cold launch")
	await tap("RESUME")
	for i in 80:
		await physics_frame
	check(scene.state.time > saved.state.time + 1 and not scene.paused, "actual Resume advances restored campaign with ordinary processing")
	await key(KEY_ESCAPE)
	check(scene.paused, "desktop Back equivalent pauses live campaign without exiting")
	await tap("SAVE / TRANSFER")
	var original: String = scene.code_edit.text
	check(S.decode(original).ok and D.same(S.decode(original).career, scene.career), "portable export contains complete career and pinned active definition")
	await touch(scene.code_edit.get_global_rect().position + Vector2(60, 60), "TextEdit")
	check(scene.code_edit.has_focus(), "actual touch focuses transfer TextEdit through mouse emulation")
	await key(KEY_END, true)
	await key(KEY_X, false, 88)
	check(scene.code_edit.text.ends_with("X") and scene.code_edit.text != original, "real keyboard edits actual touched transfer field")
	var before := whole()
	var bytes := disk()
	await tap("IMPORT")
	check(D.same(whole(), before) and disk() == bytes and scene.transfer.visible, "invalid Import retains every current memory/durable field")
	await touch(scene.code_edit.get_global_rect().position + Vector2(60, 60), "TextEdit refocus for Undo")
	await key(KEY_Z, true)
	check(scene.code_edit.text == original, "real Undo restores exported text without touching the global clipboard")
	var faults := Faults.new()
	faults.files = bytes.duplicate(true)
	faults.fail_rename = true
	scene.save_io = faults
	await tap("IMPORT")
	check(D.same(whole(), before) and disk() == bytes and scene.transfer.visible, "labelled synthetic rename fault preserves whole real progress and durable bytes")
	scene.save_io = null
	await tap("IMPORT")
	check(not scene.transfer.visible and scene.paused and D.same(whole(), before), "actual valid Import durably replaces whole code then remains paused")
	check(D.same(S.read().career, scene.career) and D.same(S.read().state, scene.state), "imported career and current run are durable, not staged-only progress")
	await tap("SAVE / TRANSFER")
	await tap("EXPORT")
	check(S.decode(scene.code_edit.text).ok and scene.notice.text.contains("Clipboard unavailable"), "headless Export gives honest unavailable-clipboard feedback and keeps a valid whole code")
	await key(KEY_ESCAPE)
	check(scene.paused and scene.menu.visible and not scene.transfer.visible, "Back closes transfer before resume")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			var path := arg.trim_prefix("--capture-dir=")
			var f := FileAccess.open(path.path_join("cold-report.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "before": saved, "after": S.read(), "raw_inputs": raw_inputs, "scope": "Separate desktop process from genuinely earned whole-save copy; actual GUI/key input, explicit synthetic storage adapter; global Windows clipboard deliberately unused."}, "  "))
	app.queue_free()
	await process_frame
	await process_frame
	print("FRONTLINE_CAMPAIGN_COLD ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
