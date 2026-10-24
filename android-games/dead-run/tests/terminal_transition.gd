extends "res://tests/terminal_design.gd"
## Bounded fixed-canvas review movie; provenance boundaries are visible.
var caption_layer: CanvasLayer
var caption: Label
var timeline: Array = []

func run() -> void:
	root.size = Vector2i(720, 1280)
	var loaded := Store.read()
	check(loaded.ok and loaded.context.campaign.phase == "defeat" and loaded.context.campaign.crew == 0, "input is a checked prior app-written depleted defeat")
	if not loaded.ok or loaded.context.campaign.phase != "defeat":
		print("SUITE_COMPLETE: FAIL")
		quit(1)
		return
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	add_caption()
	await dwell(5)
	check(Data.same(scene.state, loaded.context.campaign) and scene.retry_button.visible and not scene.resume_button.visible, "whole prior defeat restores with actionable Retry and no dead Resume")
	segment("restored-prior-defeat", "RESTORED PRIOR LOSS | Genuine app-written defeat
This clip begins after the earlier play session.")
	await pixel("transition-restored-prior-defeat")
	await hold_frames(120)
	segment("new-actual-retry-drag", "ACTUAL NEW INPUT | Retry Road, then sideways drag
Normal engine processing; no injected play state.")
	await click("RETRY ROAD")
	check(scene.state.phase == "playing" and not scene.paused and scene.state.crew == 5, "actual Retry immediately starts the selected road")
	drive(1.8)
	await hold_frames(75)
	check(scene.state.x > 1.0 and scene.state.tick >= 70, "actual right drag moves the crew while the road advances")
	drive(-1.8)
	await hold_frames(75)
	check(scene.state.x < -1.0 and scene.state.phase == "playing", "actual left drag moves the crew during active play")
	await release()
	await pixel("transition-actual-retry-drag")
	await click("II")
	check(scene.paused, "actual Pause ends the new input segment")
	scene.set_physics_process(false)
	for road in [11, 23]:
		var fixture := C.fresh(road, "fan")
		fixture.phase = "playing"
		for frame in 6600:
			if fixture.tick % 12 == 0: C.steer(fixture, Policy.aim(fixture))
			C.step(fixture)
			if fixture.tick >= fixture.definition.boss.born and fixture.hazards.any(func(h): return not h.resolved): break
			if fixture.phase != "playing": break
		check(C.valid(fixture) and fixture.tick >= fixture.definition.boss.born and fixture.hazards.any(func(h): return not h.resolved), "synthetic rule-policy late warning fixture is valid on road %d" % (road + 1))
		scene.state = fixture
		scene.paused = false
		scene.journey_visible = false
		scene.build_world()
		scene.refresh()
		segment("synthetic-warning-road-%02d" % (road + 1), "SYNTHETIC WARNING FIXTURE | Road %02d, frozen
Rule-policy state; no UI-earned late progression." % (road + 1))
		var before: Dictionary = scene.state.duplicate(true)
		await hold_frames(240)
		await pixel("transition-fixture-warning-road-%02d" % (road + 1))
		check(Data.same(scene.state, before), "warning review hold leaves whole fixture state unchanged")
	scene.state = C.fresh(0, "rivet")
	scene.state.crew = 49
	scene.state.phase = "defeat"
	scene.state.tick = scene.state.definition.boss.born
	scene.state.boss.z = 0.0
	scene.build_world()
	scene.refresh()
	scene.overlay.hide()
	segment("synthetic-49-crew-geometry", "SYNTHETIC GEOMETRY FIXTURE | 49 crew, frozen
Terminal blockade clearance; no earned progress.")
	var before: Dictionary = scene.state.duplicate(true)
	await hold_frames(150)
	await pixel("transition-fixture-49-crew-clearance")
	check(Data.same(scene.state, before), "geometry review hold leaves whole fixture state unchanged")
	timeline.append({"kind": "end", "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames()})
	write("transition-timeline.json", {"fixed_fps": 60, "canvas": [720, 1280], "segments": timeline, "scope": "Restored prior app-written natural defeat followed by actual new Retry/drag. Frozen late-warning and 49-crew states are explicitly synthetic. Not uninterrupted fresh play, new victory, native Android, measured FPS, audible sound or human pacing/fun."})
	write_report_campaign("Bounded silent 1x fixed-60 review capture. See transition-timeline.json for provenance boundaries; synthetic fixtures are never saved.")
	caption_layer.queue_free()
	caption = null
	caption_layer = null
	call_deferred("complete_design")

func add_caption() -> void:
	caption_layer = CanvasLayer.new()
	caption_layer.layer = 100
	root.add_child(caption_layer)
	var background := ColorRect.new()
	background.position = Vector2(0, 1206)
	background.size = Vector2(720, 74)
	background.color = Color(0.02, 0.04, 0.06, 0.94)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_layer.add_child(background)
	caption = Label.new()
	caption.position = Vector2(10, 1210)
	caption.size = Vector2(700, 66)
	caption.add_theme_font_size_override("font_size", 18)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_layer.add_child(caption)

func segment(kind: String, text: String) -> void:
	caption.text = text
	timeline.append({"kind": kind, "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(), "road": scene.state.definition.index + 1, "tick": scene.state.tick, "phase": scene.state.phase, "crew": scene.state.crew, "warning": scene.warning.text})
	print("TRANSITION_SEGMENT ", kind, " process_frame=", Engine.get_process_frames())

func hold_frames(count: int) -> void:
	for frame in count: await process_frame
