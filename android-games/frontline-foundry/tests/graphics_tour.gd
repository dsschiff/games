extends "res://tests/graphics_benchmark.gd"
## Real UI replay tour from an authentically earned twelve-clear profile.
## This demonstrates regional presentation, never a new campaign completion.

func run() -> void:
	root.size = Vector2i(720, 1280)
	if expected_start.is_empty():
		errors.append("Replay tour requires an authentic earned boundary")
		await finish()
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_start))
	var actual := S.read()
	if not actual.ok or not D.same(actual.state, expected.state) or not D.same(actual.profile, expected.profile) or not D.same(actual.settings, expected.settings) or not D.same(actual.career, expected.career) or actual.career.clears.size() != 12:
		errors.append("Authentic complete earned boundary failed before boot")
		await finish()
		return
	app = load("res://boot.tscn").instantiate()
	root.add_child(app)
	for i in 5:
		await process_frame
	scene = app.session
	start_time = scene.state.time
	var earned: Dictionary = scene.career.duplicate(true)
	await snap("00-authentic-earned-ending")
	for index in 12:
		await click("II")
		await click("JOURNEY / RECORDS")
		if index == 0:
			await snap("earned-liberation-journal")
		var target := await mission_button(index)
		if target == null:
			errors.append("Unable to scroll to unlocked mission " + str(index + 1))
			break
		await click(target.text)
		for i in 3:
			await process_frame
		if scene.state.definition.index != index or scene.state.phase != "ready":
			errors.append("Real Journey button selected wrong definition")
			break
		await snap("region-%02d-brief" % (index + 1))
		if index == 0:
			await click("SORTIE KIT / SUPPORT")
			await snap("support-selection")
			await click("WARD")
		await click("LAUNCH SORTIE")
		await dwell(2.8)
		await snap("region-%02d-live" % (index + 1))
		if not D.same(scene.career, earned):
			errors.append("Early replay unexpectedly changed earned career")
			break
	await click("II")
	await click("SEEDED SKIRMISH")
	await click("SEED +1")
	await click("FLANK")
	await snap("seeded-flank-menu")
	await click("START SKIRMISH")
	await snap("seeded-flank-brief")
	await click("LAUNCH SORTIE")
	await dwell(3.0)
	await snap("seeded-flank-live")
	await click("II")
	if not D.same(scene.career, earned):
		errors.append("Replay tour changed earned campaign career")
	observed["scope"] = "Twelve genuinely unlocked Journey replays plus support and seeded menus, selected by touch and mouse-wheel UI events. Brief and first 2.8 seconds only per region, not campaign progression evidence."
	await finish()

func dwell(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		elapsed += root.get_process_delta_time()

func mission_button(index: int) -> Button:
	for i in 3:
		await process_frame
	var target: Button
	for child in scene.journey_list.get_children():
		if child is Button and child.text.contains(D.TITLES[index]):
			target = child
	if target == null or target.disabled:
		return null
	var scroll: ScrollContainer = scene.journey_list.get_parent()
	for attempt in 40:
		var bounds: Rect2 = scroll.get_global_rect()
		var button_bounds := target.get_global_rect()
		if bounds.encloses(button_bounds):
			return target
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if button_bounds.end.y > bounds.end.y else MOUSE_BUTTON_WHEEL_UP
		wheel.position = root.get_final_transform() * bounds.get_center()
		wheel.pressed = true
		Input.parse_input_event(wheel)
		Input.flush_buffered_events()
		inputs.append({"kind": "gui_wheel", "direction": wheel.button_index, "position": wheel.position, "frame": Engine.get_physics_frames()})
		await process_frame
	return null
