extends "res://tests/campaign_cold.gd"
var destination := false
var folder := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--clipboard-destination":
			destination = true
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	app = load("res://boot.tscn").instantiate()
	root.add_child(app)
	for i in 8:
		await physics_frame
	scene = app.session
	if destination:
		check(scene.state.phase == "ready" and scene.career.clears.is_empty(), "separate fresh destination app has no earned campaign progress")
		await tap("II")
	else:
		check(scene.paused and scene.career.ending and scene.career.clears.size() == 12, "source uses genuine completed campaign and active cold-restored save")
	var before := whole()
	await tap("SAVE / TRANSFER")
	if destination:
		await tap("PASTE")
		var incoming := S.decode(scene.code_edit.text)
		check(incoming.ok and incoming.career.ending and incoming.career.clears.size() == 12, "real Windows Paste retrieves source's whole earned campaign code in fresh app")
		await tap("IMPORT")
		check(not scene.transfer.visible and scene.paused and D.same(scene.career, incoming.career) and D.same(scene.state, incoming.state) and D.same(scene.settings, incoming.settings) and D.same(scene.profile, incoming.profile), "actual fresh Import preserves all exported state/career/profile/settings")
		check(D.same(S.read().career, incoming.career) and D.same(S.read().state, incoming.state), "fresh imported progress is durably committed")
		await key(KEY_ESCAPE)
		check(not scene.paused, "Back resumes imported active run without exiting")
		for i in 35:
			await physics_frame
		check(scene.state.time > incoming.state.time, "fresh imported active run actually continues")
	else:
		await tap("EXPORT")
		for i in 10:
			await physics_frame
		var text: String = scene.code_edit.text
		check(S.decode(text).ok and DisplayServer.clipboard_get() == text and scene.notice.text == "Code copied.", "real Windows Export directly copies complete code with verified honest feedback")
		var f := FileAccess.open(folder.path_join("clipboard-export.txt"), FileAccess.WRITE)
		f.store_string(text)
		await touch(scene.code_edit.get_global_rect().position + Vector2(60, 60), "TextEdit")
		check(scene.code_edit.has_focus(), "actual ScreenTouch focuses TextEdit in interactive Windows")
		await key(KEY_END, true)
		await key(KEY_X, false, 88)
		check(scene.code_edit.text.ends_with("X") and scene.code_edit.text != text, "actual keyboard edits the touched interactive field")
		var bytes := disk()
		await tap("IMPORT")
		check(D.same(whole(), before) and disk() == bytes, "invalid interactive import retains whole career/run/profile/settings and all durable bytes")
		await tap("PASTE")
		check(scene.code_edit.text == text, "actual Windows Paste restores exact exported text")
		await tap("IMPORT")
		check(not scene.transfer.visible and scene.paused and D.same(whole(), before), "interactive valid Import restores whole code and stays paused")
		check(DisplayServer.clipboard_get() == text, "source leaves the exact exported code available for fresh destination")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("clipboard-destination.png" if destination else "clipboard-source.png"))
	var f := FileAccess.open(folder.path_join("clipboard-report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "destination": destination, "before": before, "after": S.read(), "raw_inputs": raw_inputs, "scope": "Reserved exclusive interactive Windows Copy/Paste window; no native Android/IME claims. Fresh Import is transfer validation, never evidence of earned campaign clears."}, "  "))
	app.queue_free()
	await process_frame
	await process_frame
	print("FRONTLINE_CLIPBOARD ", "destination" if destination else "source", " checks=", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
