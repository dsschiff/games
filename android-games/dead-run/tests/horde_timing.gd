extends SceneTree
## Opt-in host timing of a heavy horde surge (DEVELOPMENT.md "Performance
## evidence"). Rendered 720x1280 window, vsync off, max_fps 0: render frames
## are unpaced; the rules still tick at 60 Hz physics. The road is advanced
## headlessly through the read-only policy to just before its surge, then the
## real scene hydrates it and plays on with policy steering. Host numbers only;
## they do not establish phone FPS.
const C = preload("res://scripts/campaign_rules.gd")
const Policy = preload("res://tests/campaign_policy.gd")
var folder := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func stats(values: Array) -> Dictionary:
	var v := values.duplicate()
	v.sort()
	if v.is_empty(): return {}
	var at := func(q: float) -> float: return v[mini(v.size() - 1, int(q * v.size()))]
	return {"count": v.size(), "median_ms": at.call(0.5), "p95_ms": at.call(0.95), "p99_ms": at.call(0.99), "max_ms": v[-1],
		"over_16_7ms": v.filter(func(x): return x > 16.7).size(), "over_33_3ms": v.filter(func(x): return x > 33.3).size()}

func measure(scene: Node, road: int, weapon: String, start: int, reduced: bool) -> Dictionary:
	var s := C.fresh(road, weapon)
	s.phase = "playing"
	while s.tick < start and s.phase == "playing":
		if s.tick % 15 == 0: C.steer(s, Policy.aim(s, "rescue"))
		C.step(s)
	scene.settings.reduced_effects = reduced
	scene.state = s
	scene.ctx.campaign = s
	scene.paused = false
	scene.journey_visible = false
	scene.build_world()
	scene.refresh()
	var frames: Array = []
	var steps: Array = []
	var live_peak := 0
	var crew_peak := 0
	var bullets_peak := 0
	var last := Time.get_ticks_usec()
	var warm := 0
	var last_tick: int = s.tick
	while scene.state.phase == "playing" and scene.state.tick < start + 720:
		if scene.state.tick % 15 == 0 and scene.state.tick != last_tick: C.steer(scene.state, Policy.aim(scene.state, "rescue"))
		last_tick = scene.state.tick
		await process_frame
		var now := Time.get_ticks_usec()
		warm += 1
		if warm > 60: frames.append((now - last) / 1000.0)
		last = now
		var live := 0
		for i in scene.state.enemies.size():
			if scene.state.tick >= scene.state.definition.enemies[i].born and not scene.state.enemies[i].resolved: live += 1
		live_peak = maxi(live_peak, live)
		crew_peak = maxi(crew_peak, scene.state.crew)
		bullets_peak = maxi(bullets_peak, scene.state.bullets.size())
	# Rule cost alone, same span, no renderer.
	var probe := C.fresh(road, weapon)
	probe.phase = "playing"
	while probe.tick < start + 720 and probe.phase == "playing":
		if probe.tick % 15 == 0: C.steer(probe, Policy.aim(probe, "rescue"))
		var t0 := Time.get_ticks_usec()
		C.step(probe)
		if probe.tick > start: steps.append((Time.get_ticks_usec() - t0) / 1000.0)
	var out := {"road": road + 1, "weapon": weapon, "reduced_effects": reduced, "ticks": [start, scene.state.tick], "warmup_frames_excluded": 60,
		"render_frame_intervals": stats(frames), "rule_step": stats(steps), "live_infected_peak": live_peak, "crew_peak": crew_peak, "bullets_peak": bullets_peak,
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "window": [root.size.x, root.size.y]}
	print("TIMING ", JSON.stringify(out))
	return out

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(720, 1280)
	var scene: Node = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	for i in 10: await process_frame
	var results: Array = []
	# Light baseline: the opening road, few infected, small crew.
	results.append(await measure(scene, 0, "rivet", 300, false))
	# Convoy Column (road 23): its blockade surge is the densest ordinary road.
	var d: Dictionary = C.fresh(22).definition
	var surge: int = int(d.boss.born) - 720
	results.append(await measure(scene, 22, "fan", surge, false))
	results.append(await measure(scene, 22, "fan", surge, true))
	results.append(await measure(scene, 22, "lance", surge, false))
	var f := FileAccess.open(folder.path_join("timing.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope": "Host desktop, unpaced render frames, not phone FPS.", "results": results}, "  "))
	f.close()
	scene.queue_free()
	await process_frame
	print("SUITE_COMPLETE: PASS")
	quit()
