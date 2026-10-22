extends "res://tests/native_transfer.gd"
## Real engine input on a CPU display; Android dispatch/IME/fit remain untested.
const E = preload("res://scripts/engine.gd")

func run() -> void:
	root.size = Vector2i(720, 1280)
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for dimensions in [Vector2i(1080, 2400), Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1280, 1280), Vector2i(900, 1400), Vector2i(2400, 1080), Vector2i(720, 1280)]:
		await tap_button("PAUSE")
		var before: Dictionary = scene.state.duplicate(true)
		var profile_before: Dictionary = scene.profile.duplicate(true)
		var settings_before: Dictionary = scene.settings.duplicate(true)
		root.size = dimensions
		for i in 4:
			await process_frame
		check(scene.state == before and scene.profile == profile_before and scene.settings == settings_before, "paused resize retains whole saved meaning " + str(dimensions))
		var scale: Vector2 = root.get_final_transform().get_scale()
		var visible: Rect2 = root.get_visible_rect()
		check(absf(scale.x / scale.y - 1) <= 1.0 / visible.size.x, "uniform art and input scale " + str(dimensions))
		check(visible.encloses(scene.menu.get_global_rect()) and visible.encloses(scene.menu_button.get_global_rect()), "actual controller rectangles fit CPU viewport " + str(dimensions))
		check(scene.menu_button.size.y >= 100 and scene.buy_button.size.y >= 100, "touch targets remain 100 logical pixels " + str(dimensions))
		await tap_button("RESUME")
		check(not scene.paused, "resized actual Resume receives transformed touch " + str(dimensions))
		var point := Vector2(120, minf(900, visible.size.y - 450))
		var start: float = scene.state.x
		await finger_event(point, true, 7)
		var drag := InputEventScreenDrag.new()
		drag.index = 7
		drag.position = root.get_final_transform() * (point + Vector2(75, 0))
		drag.relative = Vector2(75, 0)
		Input.parse_input_event(drag)
		for i in 8:
			await physics_frame
		print("INPUT_RESIZE_DETAIL ", dimensions, " logical=", visible, " transform=", root.get_final_transform(), " drag=", scene.dragging, " move=", scene.movement, " from=", start, " to=", scene.state.x, " finger=", scene.finger, " point=", point)
		await finger_event(point + Vector2(75, 0), false, 7)
		await physics_frame
		await physics_frame
		check(scene.state.x > start + .2 and not scene.dragging, "resized drag/release use correct inverse mapping " + str(dimensions))
		var stopped: float = scene.state.x
		for i in 3:
			await physics_frame
		check(is_equal_approx(scene.state.x, stopped), "release leaves no residual world movement " + str(dimensions))
		# Release an owned gesture over the actual GUI, after its start in world.
		await finger_event(point, true, 7)
		await finger_event(scene.menu_button.get_global_rect().get_center(), false, 7)
		await physics_frame
		await physics_frame
		check(not scene.dragging and scene.finger == -1 and not scene.paused, "owned release over GUI stops without clicking it " + str(dimensions))
		var p: Vector3 = scene.presentation.player.target
		var projected: Vector2 = scene.camera.unproject_position(p + Vector3(0, 1, 0))
		check(projected.y > scene.top_panel.get_global_rect().end.y and projected.y < scene.bottom_panel.get_global_rect().position.y, "player projects between scene controller panels " + str(dimensions))
		var packet: Dictionary = scene.state.duplicate(true)
		scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		await process_frame
		check(scene.paused and scene.menu.visible and not scene.dragging and scene.state == packet, "Back pauses and retains state " + str(dimensions))
		check(scene.presentation.serial == 0 and scene.presentation.effects.is_empty(), "Back clears observational effects once " + str(dimensions))
		await tap_button("RESUME")
	# Save/import checks preserve the current active state, including all settings.
	await tap_button("PAUSE")
	await tap_button("EXPORT")
	var code: String = scene.transfer.text
	var decoded := S.decode(code)
	check(decoded.ok, "resized active save exports normally")
	var revision: int = S.read().revision
	await reveal_control(scene.transfer)
	await touch_at(scene.transfer.get_global_rect().get_center())
	await select_all()
	await type_unicode("INVALID Ω")
	await tap_button("IMPORT")
	check(scene.transfer_status.text.begins_with("Invalid") and S.read().revision == revision, "typed invalid resized import rejected without save write")
	# The long selected code typing path is covered separately by native_transfer.
	scene.transfer.text = code
	await tap_button("IMPORT")
	check(scene.state == decoded.state and scene.profile == decoded.profile and scene.settings == decoded.settings, "resized valid import retains complete context")
	check(scene.presentation.serial == 0 and scene.presentation.events.is_empty(), "import rebuild starts a fresh event epoch")
	var state_before: Dictionary = scene.state.duplicate(true)
	var settings: Dictionary = scene.settings.duplicate(true)
	var profile: Dictionary = scene.profile.duplicate(true)
	scene.free()
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.state == state_before and scene.settings == settings and scene.profile == profile and scene.paused, "cold scene restore retains full active data and paused lifecycle")
	check(scene.presentation.serial == 0, "cold hydration replays no attacks")
	if not capture_dir.is_empty():
		FileAccess.open(capture_dir.path_join("graphics-input-report.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "details": report, "events": events, "scope": "CPU actual Input.parse_input_event transformations; native Android/IME/clipboard/rendering not established"}, "  "))
	print("GRAPHICS_INPUT: ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	scene.free()
	await process_frame
	quit(0 if failures == 0 else 1)
