extends "res://tests/graphics_benchmark.gd"
## Genuine catalog-one restoration and explicit campaign entry via real GUI.

func run() -> void:
	root.size = Vector2i(720, 1280)
	if expected_start.is_empty():
		errors.append("Legacy passage requires an authentic app-written battle")
		await finish()
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_start))
	var actual := S.read()
	if not actual.ok or actual.state.catalog != 1 or not D.same(actual.state, expected.state) or not D.same(actual.profile, expected.profile) or not D.same(actual.settings, expected.settings):
		errors.append("Authentic complete legacy boundary failed before boot")
		await finish()
		return
	app = load("res://boot.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	for i in 5:
		await process_frame
	scene = app.session
	start_time = scene.state.time
	if not scene.paused or not D.same(scene.state, expected.state):
		errors.append("Legacy boot did not retain exact active battle paused")
	await snap("legacy-exact-paused-load")
	await click("RESUME")
	await dwell(3.0)
	await snap("legacy-real-resumed-play")
	await click("II")
	var retained: Dictionary = scene.state.duplicate(true)
	var retained_profile: Dictionary = scene.profile.duplicate(true)
	await click("BEGIN CAMPAIGN")
	for i in 5:
		await process_frame
	app = current_scene
	scene = app.session
	if scene.state.catalog != 2 or scene.state.phase != "ready" or not scene.career.clears.is_empty() or not D.same(scene.career.legacy_state, retained) or not D.same(scene.career.legacy_profile, retained_profile) or not D.same(scene.settings, expected.settings):
		errors.append("Explicit campaign entry failed exact legacy backup/settings retention")
	await snap("legacy-explicit-campaign-entry")
	await dwell(1.0)
	await click("LAUNCH SORTIE")
	await dwell(2.0)
	await snap("legacy-to-campaign-live")
	await click("II")
	observed["legacy"] = "Authentic earlier app-written battle restored exactly, resumed by GUI, then explicit Begin Campaign retains whole resumed legacy state/profile/settings without invented clears"
	await finish()

func dwell(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		elapsed += root.get_process_delta_time()

func snap(name: String) -> void:
	var row := {"name": name, "frame": Engine.get_physics_frames(), "state": scene.state.duplicate(true), "career": S.read().career, "actors": scene.presentation.units.size()}
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		row["image_error"] = root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	captures.append(row)
