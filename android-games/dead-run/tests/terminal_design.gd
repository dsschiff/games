extends "res://tests/campaign_input.gd"
const Kit = preload("res://scripts/presentation/kit.gd")
var observed_geometry_fonts: Array[WeakRef] = []

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	if "--scenario=warnings" in OS.get_cmdline_user_args():
		scene.set_physics_process(false)
		await warning_pixels()
		write_report_campaign("Explicit rule-policy warning fixtures only; no earned progression, natural outcomes or Android evidence.")
		call_deferred("complete_design")
		return
	await click(scene.stage_buttons[0].text)
	check(not scene.resume_button.visible, "ready road offers Start without Resume")
	await click("START RESCUE")
	while scene.state.phase == "playing": await physics_frame
	check(scene.state.phase == "defeat" and scene.state.crew == 0, "unattended road earns actual depleted-crew defeat")
	await pixel("earned-depleted-defeat")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(720, 1680)
		await dwell(3)
		await pixel("earned-depleted-defeat-cover")
		root.size = Vector2i(720, 1280)
		await dwell(3)
	await terminal_checks("natural defeat")
	await click("RETRY ROAD")
	check(scene.state.phase == "playing" and scene.state.crew == 5 and not scene.paused, "touch Retry immediately restarts actual defeat")
	await pixel("actual-retry-playing")
	await click("II")
	check(scene.paused and scene.resume_button.visible, "active Pause still offers Resume")
	await click("RESUME")
	check(not scene.paused, "actual Resume continues active road")
	check(await play_road(), "actual drag policy earns road victory")
	await pixel("earned-first-victory")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1000, 1110)
		await dwell(3)
		await pixel("earned-first-victory-inner")
		root.size = Vector2i(720, 1280)
		await dwell(3)
	await terminal_checks("natural victory")
	var saved: Dictionary = Store.read().context
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(Data.same(scene.state, saved.campaign) and scene.state.phase == "victory" and not scene.resume_button.visible, "cold terminal restore preserves whole won road with no Resume")
	await click("NEXT ROAD")
	check(scene.state.phase == "ready" and scene.state.definition.index == 1 and not scene.resume_button.visible, "Next Road presents Start without stale pause")
	await legacy_terminal_checks()
	warning_checks()
	# Geometry fixture only: frozen blockade and crew placement, never persisted
	# or used as earned play/save evidence.
	scene.set_physics_process(false)
	for count in [5, 25, 49]:
		scene.state = C.fresh(0, "rivet")
		scene.state.crew = count
		scene.state.phase = "defeat"
		scene.state.tick = scene.state.definition.boss.born
		scene.state.boss.z = 0.0
		scene.journey_visible = false
		scene.build_world()
		scene.refresh()
		var p: RefCounted = scene.presentation
		observed_geometry_fonts.append(weakref(p.label_font))
		var barrier := Kit.bounds(p.boss_visual, scene.world)
		var front := INF
		for i in count:
			var body := Kit.bounds(p.crew[i].model, scene.world)
			front = minf(front, body.position.z)
		print("BLOCKADE_GEOMETRY crew=", count, " body_front=", front, " barrier_end=", barrier.end.z, " gap=", front - barrier.end.z)
		check(barrier.end.z + 0.2 <= front, "terminal blockade stays ahead of all %d crew including equipment" % count)
		var before: Dictionary = scene.state.duplicate(true)
		scene.refresh()
		check(Data.same(scene.state, before), "terminal clearance leaves the entire authoritative state unchanged")
		if count == 49:
			scene.overlay.hide()
			scene.notice.text = "GEOMETRY FIXTURE - 49 crew / frozen blockade. Not earned progress."
			await pixel("fixture-49-crew-terminal-clearance")
			scene.refresh()
		scene.state.phase = "playing"
		scene.state.boss.z = 2.0
		scene.refresh()
		check(p.boss.position == Vector3(scene.state.boss.x, 0, -scene.state.boss.z), "active blockade keeps original visual-to-projectile relation for %d crew" % count)
		check(Kit.bounds(p.boss_visual, scene.world).end.z > -2.0, "active modeled target is not shifted by terminal clearance")
	await warning_pixels()
	write_report_campaign("Actual Godot GUI touch/drag Start, natural defeat, Retry and victory. Synthetic Home/close notifications and desktop cold restoration are distinct from Android lifecycle. Terminal blockade geometry uses explicitly synthetic nonpersistent states; no rendered/phone acceptance.")
	call_deferred("complete_design")

func complete_design() -> void:
	# Return from the scenario first so local adapter/font references release
	# before the renderer shuts down. Flush the queued world release too.
	scene.queue_free()
	scene = null
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	await process_frame
	print("TERMINAL_OWNERSHIP resources=", Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " surviving_geometry_fonts=", observed_geometry_fonts.map(func(reference): return reference.get_ref() != null))
	print("TERMINAL_DESIGN ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func terminal_checks(label: String) -> void:
	var before: Dictionary = scene.state.duplicate(true)
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await dwell(3)
	check(not scene.resume_button.visible and scene.retry_button.visible, label + ": Home retains Retry without dead Resume")
	await click("SAVE / TRANSFER")
	await click("CLOSE TRANSFER")
	check(not scene.resume_button.visible, label + ": transfer close cannot resume a finished road")
	scene.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await dwell(3)
	check(not scene.resume_button.visible and Data.same(scene.state, before), label + ": close notification preserves whole terminal state")
	await key(KEY_ESCAPE)
	check(not scene.resume_button.visible and scene.overlay.visible, label + ": Back keeps terminal result actionable")

func legacy_terminal_checks() -> void:
	await click("EVACUATION MAP")
	await click("LEGACY CANAL BRIDGE")
	var host := scene
	scene = host.legacy_view
	await dwell(4)
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(scene.state.phase == "ready" and not scene.resume_button.visible, "legacy ready Home keeps Start without Resume")
	await click("START RESCUE")
	while scene.state.phase == "playing": await physics_frame
	check(scene.state.phase == "defeat", "legacy route naturally loses without injected progress")
	var before: Dictionary = scene.state.duplicate(true)
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await click("SAVE / TRANSFER")
	await click("CLOSE TRANSFER")
	await key(KEY_ESCAPE)
	check(not scene.resume_button.visible and scene.retry_button.visible and Data.same(scene.state, before), "legacy loss Home/transfer/Back retain Retry with no terminal Resume")
	await click("RETRY BRIDGE")
	check(scene.state.phase == "playing" and not scene.paused, "legacy touch Retry restarts immediately")
	await click("II")
	await click("EVACUATION MAP")
	scene = host
	await dwell(4)

func warning_checks() -> void:
	# Pure presentation fixtures: no simulation or stored progress is injected.
	scene.set_physics_process(false)
	for road in [11, 23]:
		scene.state = C.fresh(road, "rivet")
		scene.state.phase = "playing"
		scene.state.tick = scene.state.definition.boss.born
		scene.state.hazards = [
			{"label": "near strike", "fire": scene.state.tick + 30, "loss": 4, "resolved": false},
			{"label": "later strike", "fire": scene.state.tick + 120, "loss": 4, "resolved": false}]
		var before: Dictionary = scene.state.duplicate(true)
		check(scene.road_warning().begins_with("NEAR STRIKE in 0.5s"), "boss %d cannot overwrite earliest hazard warning" % scene.state.definition.boss.kind)
		scene.state.hazards.reverse()
		check(scene.road_warning().begins_with("NEAR STRIKE"), "hazard priority ignores array order")
		scene.state.hazards.reverse()
		check(Data.same(scene.state, before), "warning selection never changes authoritative state")
		scene.state.hazards[0].resolved = true
		check(scene.road_warning().begins_with("LATER STRIKE"), "resolved hazard yields next unresolved countdown")
		scene.state.hazards[1].resolved = true
		check(scene.road_warning().begins_with("TOLL RAM" if road == 11 else "FERRY EATER"), "all resolved hazards restore boss tactic")
		scene.state.gates[0].crossed = false
		scene.state.gates[0].z = 1.0
		check(scene.road_warning().begins_with("GATE"), "near gate takes priority over boss tactic")
		if not scene.state.obstacles.is_empty():
			scene.state.obstacles[0].z = 0.5
			scene.state.obstacles[0].crossed = false
			check(scene.road_warning().begins_with("CART in"), "nearer cart takes priority over gate in array")
			scene.state.obstacles[0].crossed = true
			check(scene.road_warning().begins_with("GATE"), "crossed cart yields remaining gate warning")

func pixel(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	print("DESIGN_PIXEL ", name)

func warning_pixels() -> void:
	if DisplayServer.get_name() == "headless": return
	# Valid rule-policy states for representative late warning layouts only.
	# They are not UI-earned progression and are never written to save slots.
	for road in [11, 23]:
		var fixture := C.fresh(road, "fan")
		fixture.phase = "playing"
		for frame in 6600:
			if fixture.tick % 12 == 0: C.steer(fixture, Policy.aim(fixture))
			C.step(fixture)
			if fixture.tick >= fixture.definition.boss.born and fixture.hazards.any(func(h): return not h.resolved): break
			if fixture.phase != "playing": break
		check(C.valid(fixture) and fixture.tick >= fixture.definition.boss.born and fixture.hazards.any(func(h): return not h.resolved), "rule-policy fixture reaches genuine late lane countdown on road %d" % (road + 1))
		scene.state = fixture
		scene.paused = false
		scene.journey_visible = false
		scene.build_world()
		for size in [Vector2i(720, 1680), Vector2i(1000, 1110)]:
			root.size = size
			scene.refresh()
			await dwell(3)
			await pixel("fixture-road-%02d-warning-%dx%d" % [road + 1, size.x, size.y])
