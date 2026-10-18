extends SceneTree
const S = preload("res://scripts/save_store.gd")
const C = preload("res://scripts/campaign_rules.gd")
var folder := ""
var path := ""
var checks := 0
var failures := 0
var details: Array = []
var events: Array = []
var app: Node
var scene: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--checkpoint="):
			path = arg.trim_prefix("--checkpoint=")
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(720, 1280)
	var old_bytes := FileAccess.get_file_as_string(path)
	var archive: Dictionary = JSON.parse_string(old_bytes)
	var selected := {"ok": false, "revision": -1}
	var original_code := ""
	for code in archive.values():
		var decoded := S.decode(code)
		if decoded.ok and decoded.revision > selected.revision:
			selected = decoded
			original_code = code
	check(selected.ok and selected.state.schema == 1 and selected.state.killed.size() > 0, "genuine archived code1 desktop active save selected; not a fabricated device fixture")
	if not selected.ok:
		quit(1)
		return
	var original: Dictionary = JSON.parse_string(JSON.parse_string(original_code).payload)
	check(C.equivalent(selected.state, original.state) and C.equivalent(selected.profile, original.profile) and selected.settings == original.settings, "new decoder preserves entire real old desktop state/profile/settings")
	var file := FileAccess.open(S.PATH + "0", FileAccess.WRITE)
	file.store_string(original_code)
	file.close()
	file = FileAccess.open(folder.path_join("loaded-old-save.json"), FileAccess.WRITE)
	file.store_string(old_bytes)
	file.close()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await frames(5)
	scene = app.get_node("Battle")
	check(scene.state.schema == 1 and scene.paused, "ordinary new-app launch selects legacy mode and pauses active battle")
	check(C.equivalent(scene.state, original.state) and C.equivalent(scene.profile, original.profile) and scene.settings == original.settings, "new-app write retains every old state/profile/settings value")
	check(scene.campaign_profile.clears.is_empty(), "old results invent no expedition clears")
	await frames(60)
	check(C.equivalent(scene.state, original.state), "old active run never advances without Resume")
	await snap("legacy-active-preserved")
	await click("OPEN EXPEDITION • KEEP LEGACY PASS")
	await frames(5)
	scene = app.get_node("Battle")
	check(scene.state.schema == 2 and scene.campaign_profile.clears.is_empty(), "real GUI opens fresh expedition without invented progress")
	check(C.equivalent(scene.campaign_profile.legacy_snapshot, original.state) and C.equivalent(scene.profile, original.profile), "opening expedition parks exact old run and original profile")
	await click("II")
	await click("JOURNEY / REPLAY")
	await click("RETURN TO LEGACY PASS")
	await frames(5)
	scene = app.get_node("Battle")
	check(scene.state.schema == 1 and scene.paused and C.equivalent(scene.state, original.state), "real return control restores same legacy active run")
	check(C.equivalent(scene.profile, original.profile) and scene.campaign_profile.parked.schema == 2 and scene.campaign_profile.clears.is_empty(), "both parked modes and old earned meaning coexist")
	await snap("legacy-return-preserved")
	file = FileAccess.open(folder.path_join("legacy-compatibility.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "events": events, "source_archive": path, "source_archive_sha256": old_bytes.sha256_text(), "scope": "Actual new-app loading of a genuinely earned archived code1 desktop envelope, then real GUI switching between parked modes. This is not the coordinator's actual Android code1-to2 update fixture."}, "  "))
	file.close()
	print("LEGACY_COMPATIBILITY: ",checks," checks, failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")
	app.queue_free()
	await frames(3)
	quit(0 if failures == 0 else 1)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func click(text: String) -> void:
	var target: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			target = b
	if target == null:
		check(false, "missing visible control " + text)
		return
	var scroll: ScrollContainer = scene.get("journey_scroll")
	if scroll != null and scroll.is_ancestor_of(target):
		for attempt in 40:
			if scroll.get_global_rect().encloses(target.get_global_rect()):
				break
			var wheel := InputEventMouseButton.new()
			wheel.position = root.get_final_transform() * scroll.get_global_rect().get_center()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			Input.parse_input_event(wheel)
			Input.flush_buffered_events()
			await frames(1)
			wheel.pressed = false
			Input.parse_input_event(wheel)
			Input.flush_buffered_events()
			await frames(1)
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = root.get_final_transform() * target.get_global_rect().get_center()
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"kind": "touch", "target": text, "pressed": pressed, "position": [e.position.x, e.position.y]})
		await frames(1)

func snap(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
