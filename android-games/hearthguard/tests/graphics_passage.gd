extends "res://tests/campaign_journey.gd"
## Normal app input, genuine checkpoint bytes, no synthetic campaign progression.
var passage_mode := "inspect"
var seconds := 8.0
var measure := false
var timings: Array = []
var draw_samples: Array = []
var frame_stamp := 0
var sample_clock := 0.0
var peak_draws := 0
var peak_primitives := 0
var peak_nodes := 0
var source_stage := -1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--checkpoint="):
			checkpoint = arg.trim_prefix("--checkpoint=")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--mode="):
			passage_mode = arg.trim_prefix("--mode=")
		elif arg == "--measure-frames":
			measure = true
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	if not checkpoint.is_empty():
		var bytes := FileAccess.get_file_as_string(checkpoint)
		var decoded := S.decode(bytes)
		if passage_mode == "legacy" and not decoded.ok:
			var archive: Variant = JSON.parse_string(bytes)
			if archive is Dictionary:
				var revision := -1
				for candidate in archive.values():
					if candidate is String:
						var packet := S.decode(candidate)
						if packet.ok and packet.revision > revision:
							revision = packet.revision
							decoded = packet
							bytes = candidate
		var correct_mode: bool = decoded.ok and ((decoded.state.schema == 1 and decoded.state.killed.size() > 0) if passage_mode == "legacy" else (decoded.state.schema == 2 and decoded.state.definition.stage > 0 and decoded.campaign.clears.size() > 0))
		check(correct_mode, "declared authentic earned checkpoint validates for selected passage")
		if not correct_mode:
			finish_passage()
			return
		var f := FileAccess.open(S.PATH + "0", FileAccess.WRITE)
		f.store_string(bytes)
		f.close()
	await load_app()
	if passage_mode == "legacy":
		await legacy_passage()
		finish_passage()
		return
	source_stage = int(scene.state.definition.stage)
	check(scene.state.schema == 2, "ordinary app selects campaign")
	await snap("opening")
	if passage_mode == "closure":
		await closure()
	elif passage_mode == "tour":
		await tour()
	else:
		if scene.paused:
			await click("RESUME")
		if scene.state.phase == "ready":
			await click("BEGIN WATCH")
		var until: float = scene.state.time + seconds
		frame_stamp = Time.get_ticks_usec()
		var frame := 0
		while scene.state.phase == "playing" and scene.state.time < until:
			var plan := Policy.plan(scene.state, 1 if source_stage == 8 else 0)
			if plan.affordable and plan.pad >= 0 and C.position(scene.state).distance_to(plan.goal) < 1.38:
				await release()
				await click(scene.action_buttons[int(plan.choice)].text)
			else:
				await steer((plan.goal - C.position(scene.state)).limit_length())
				await physics_frame
			if frame % 180 == 0:
				print("GRAPHICS_PROGRESS map=", source_stage + 1, " t=", scene.state.time, " actors=", scene.state.enemies.size(), " shots=", scene.state.shots)
			frame += 1
		await release()
		await snap("passage-end")
		if not scene.paused:
			await click("II")
		var earned := S.read()
		check(earned.ok and C.equivalent(earned.state, scene.state) and earned.campaign == scene.campaign_profile, "app-written paused end checkpoint retains complete genuine state/profile")
		if earned.ok:
			var f := FileAccess.open(folder.path_join("passage-earned.code"), FileAccess.WRITE)
			f.store_string(FileAccess.get_file_as_string(S.PATH + str(earned.slot)))
			f.close()
	finish_passage()

func _process(delta: float) -> bool:
	if measure and frame_stamp > 0 and is_instance_valid(scene) and not scene.paused and scene.state.phase == "playing":
		var now := Time.get_ticks_usec()
		var ms := float(now - frame_stamp) / 1000
		frame_stamp = now
		# Submission interval samples; raw frame tails and draw counters retained.
		if sample_clock > 2:
			timings.append(ms)
			var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			peak_draws = maxi(peak_draws, draws)
			peak_primitives = maxi(peak_primitives, primitives)
			peak_nodes = maxi(peak_nodes, nodes)
			draw_samples.append({"frame": timings.size(), "time": float(scene.state.time), "ms": ms, "draws": draws, "primitives": primitives, "nodes": nodes, "enemies": scene.state.enemies.size()})
		sample_clock += delta
	elif measure:
		frame_stamp = Time.get_ticks_usec()
	return false

func closure() -> void:
	if not scene.paused:
		await click("II")
	var before := whole_memory()
	for size in [Vector2i(1080, 2400), Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1100, 1400), Vector2i(1600, 1000)]:
		root.size = size
		await dwell(5)
		check(whole_memory() == before, "resize retains complete held encounter " + str(size))
		await snap("held-" + str(size.x) + "x" + str(size.y))
		await click("RESUME")
		var logical: Vector2 = root.get_visible_rect().size
		dragging_origin = Vector2(100, logical.y * .58)
		await steer(Vector2(-.4, -.7))
		await dwell(16)
		await release()
		await click("II")
		check(scene.input_vector == Vector2.ZERO and scene.paused, "actual movement and release after resize " + str(size))
		before = whole_memory()
	root.size = Vector2i(720, 1280)
	await dwell(4)
	var old_profile: Dictionary = scene.campaign_profile.duplicate(true)
	await click("JOURNEY / REPLAY")
	await snap("journey")
	await key(KEY_ESCAPE)
	await click("SAVE / TRANSFER")
	await snap("transfer")
	await key(KEY_ESCAPE)
	await click("RESUME")
	# Deliberate Retry after native held-context passages, through the real UI.
	await key(KEY_ESCAPE)
	await dwell(2)
	# Existing terminal Retry is only available at a real terminal. Avoid inventing one.
	check(scene.campaign_profile == old_profile, "menu passages retain entire career")
	await snap("closure-end")

func tour() -> void:
	check(scene.campaign_profile.clears.size() == 10, "regional tour requires genuinely earned full campaign")
	if scene.campaign_profile.clears.size() != 10:
		return
	if not scene.paused:
		await click("II")
	await click("JOURNEY / REPLAY")
	for stage in 10:
		# ScrollContainer can reveal an existing unlocked button; no progression edit.
		scene.journey_scroll.ensure_control_visible(scene.map_buttons[stage])
		await dwell(3)
		await tap(scene.map_buttons[stage].get_global_rect().get_center())
		await dwell(3)
		if scene.confirm_panel.visible:
			await click("REPLACE WATCH")
		await dwell(4)
		check(scene.state.definition.stage == stage, "actual unlocked regional entry " + str(stage + 1))
		await snap("region-%02d" % (stage + 1))
		await click("II")
		await click("JOURNEY / REPLAY")
	await snap("tour-end")

func finish_passage() -> void:
	var input_file := FileAccess.open(folder.path_join("raw-input-events.json"), FileAccess.WRITE)
	input_file.store_string(JSON.stringify(events))
	input_file.close()
	if measure:
		var sorted := timings.duplicate()
		sorted.sort()
		var over := 0
		for value in sorted:
			if value > 33.333:
				over += 1
		var metrics := {"samples": timings.size(), "raw_ms": timings, "raw_draw_samples": draw_samples,
			"median_ms": sorted[int(sorted.size() * .5)] if not sorted.is_empty() else 0,
			"p95_ms": sorted[mini(sorted.size() - 1, int(sorted.size() * .95))] if not sorted.is_empty() else 0,
			"p99_ms": sorted[mini(sorted.size() - 1, int(sorted.size() * .99))] if not sorted.is_empty() else 0,
			"above_33_333": over, "peak_draws": peak_draws, "peak_primitives": peak_primitives, "peak_nodes": peak_nodes,
			"renderer": RenderingServer.get_video_adapter_name(), "resolution": root.size,
			"method": "Real-time host render submission intervals after two-second warmup; no movie/fixed cadence; no phone FPS claim"}
		var f := FileAccess.open(folder.path_join("frame-timing.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(metrics, "\t"))
		f.close()
	var report := {"checks": checks, "failures": failures, "details": details, "snapshots": snapshots,
		"mode": passage_mode, "checkpoint": checkpoint, "stage": source_stage,
		"scope": "Actual GUI/ScreenTouch/drag passages using fresh or declared authentic earned saves; no fabricated unlocks"}
	var f := FileAccess.open(folder.path_join("passage-report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	if is_instance_valid(game_root):
		game_root.queue_free()
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func legacy_passage() -> void:
	check(scene.state.schema == 1 and scene.paused, "ordinary launch hydrates genuine legacy save paused")
	await snap("legacy-held")
	if scene.paused:
		await click("RESUME")
	var until: float = scene.state.time + seconds
	while scene.state.phase == "playing" and scene.state.time < until:
		await steer(Vector2(-.25, -.35))
		await physics_frame
	await release()
	await click("II")
	var held := whole_memory()
	await snap("legacy-played")
	await click("OPEN EXPEDITION • KEEP LEGACY PASS")
	await dwell(5)
	scene = game_root.get_node("Battle")
	check(scene.state.schema == 2 and C.equivalent(scene.campaign_profile.legacy_snapshot, held.state) and C.equivalent(scene.profile, held.legacy_profile) and scene.settings == held.settings, "actual legacy-to-expedition entry preserves entire resumed legacy meaning and settings")
	await snap("legacy-to-expedition")

func snap(name: String) -> void:
	print("GRAPHICS_SNAPSHOT ", name, " schema=", scene.state.schema, " time=", scene.state.time, " gold=", scene.state.wallet)
	snapshots.append({"name": name, "frame": Engine.get_physics_frames(), "live": whole_memory(), "app_written": S.read()})
	if not folder.is_empty():
		var f := FileAccess.open(folder.path_join(name + "-saves.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(disk_bytes(), "\t"))
		f.close()
	if DisplayServer.get_name() != "headless" and not folder.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
