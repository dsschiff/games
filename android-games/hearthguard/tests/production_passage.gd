extends "res://tests/graphics_passage.gd"
## Production evidence only: app-written inputs, actual GUI, bounded passages.
var production_stage := "opening"
var expected_code := ""
var lead_in := 0.0
var timing_open := false
var recording := false
var start_context := {}
var slot_snapshots := {}
var observed := preload("res://tests/production_observer.gd").new()
var sampler := preload("res://tests/frame_sampler.gd").new()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--stage="):
			production_stage = arg.trim_prefix("--stage=")
		elif arg.begins_with("--expected-code="):
			expected_code = arg.trim_prefix("--expected-code=")
		elif arg.begins_with("--lead-in="):
			lead_in = float(arg.trim_prefix("--lead-in="))
		elif arg == "--native-frames":
			native_frames = true
	passage_mode = "closure" if production_stage == "lifecycle" else production_stage
	call_deferred("run")

func context_matches(packet: Dictionary) -> bool:
	return C.equivalent(scene.state, packet.state) and C.equivalent(scene.profile, packet.profile) and C.equivalent(scene.campaign_profile, packet.campaign) and scene.settings == packet.settings

func run() -> void:
	root.size = Vector2i(720, 1280)
	if not expected_code.is_empty():
		var expected := S.decode(FileAccess.get_file_as_string(expected_code))
		var actual := S.read()
		check(expected.ok and actual.ok and actual.revision == expected.revision and actual.committed == expected.committed and actual.version == expected.version and C.equivalent(actual.state, expected.state) and C.equivalent(actual.profile, expected.profile) and C.equivalent(actual.campaign, expected.campaign) and actual.settings == expected.settings, "whole authentic start agrees before boot can write anything")
		if failures > 0:
			finish_production()
			return
	await load_app()
	if not expected_code.is_empty():
		check(context_matches(S.decode(FileAccess.get_file_as_string(expected_code))), "ordinary app boot preserves every authenticated state/profile/settings/legacy field")
	else:
		check(scene.state.schema == 2 and scene.state.phase == "ready" and scene.campaign_profile.clears.is_empty() and scene.profile.attempts == 0, "fresh production opening invents no earned progression")
	if failures > 0:
		finish_production()
		return
	start_context = whole_memory()
	source_stage = int(scene.state.definition.stage) if scene.state.schema == 2 else -1
	await snap("loaded-boundary")
	if lead_in > 0:
		await start_playing()
		await play_for(lead_in)
		await hold()
		await retain_slots("after-declared-real-input-lead-in")
		await snap("lead-in-boundary")
	if native_frames:
		if production_stage == "lifecycle":
			native_canvas = Vector2i(1968, 2520)
		DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
		recording = true
		RenderingServer.frame_post_draw.connect(capture_native_frame)
	match production_stage:
		"retry":
			await retry_passage()
		"lifecycle":
			await lifecycle_passage()
		"restore":
			await restore_passage()
		"legacy":
			await legacy_passage()
		"tour":
			await region_tour()
		_:
			await start_playing()
			if production_stage == "timing":
				check(not native_frames and Engine.get_write_movie_path().is_empty(), "timing excludes native readback and movie writer")
				check(Engine.max_fps == 0 and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "declared unpaced timing actually disables VSync and FPS cap")
				if failures > 0:
					finish_production()
					return
				sampler.start(root, scene)
				timing_open = true
				RenderingServer.frame_post_draw.connect(sample_timing_frame)
			await play_for(seconds)
			if timing_open:
				timing_open = false
				RenderingServer.frame_post_draw.disconnect(sample_timing_frame)
				var f := FileAccess.open(folder.path_join("frame-timing.json"), FileAccess.WRITE)
				var report: Dictionary = sampler.stop()
				check(report.all_frames.frames > 0 and report.heavy_frames.frames > 0, "real-time run contains eligible warmed active and declared-heavy samples")
				f.store_string(JSON.stringify(report, "\t"))
				f.close()
	await hold()
	await retain_slots("final")
	await snap("final-held-boundary")
	finish_production()

func _process(_delta: float) -> bool:
	return false

func start_playing() -> void:
	if scene.paused:
		await click("RESUME")
	if scene.state.phase == "ready":
		await click("BEGIN WATCH")
	check(scene.state.phase == "playing" and not scene.paused, "actual Start/Resume reaches active encounter")

func hold() -> void:
	await release()
	if not scene.paused:
		await click("II")
	check(scene.paused, "actual Pause holds the encounter")

func play_for(duration: float) -> void:
	var until: float = scene.state.time + duration
	var wall := Time.get_ticks_msec()
	while scene.state.phase == "playing" and scene.state.time < until:
		if Time.get_ticks_msec() - wall > (duration * (5 if native_frames else 1) + 45) * 1000:
			check(false, "bounded passage exceeded wall-clock safety limit; no time compensation")
			break
		var plan := Policy.plan(scene.state, 1 if int(scene.state.definition.stage) == 8 else 0)
		if plan.affordable and plan.pad >= 0 and C.position(scene.state).distance_to(plan.goal) < 1.38:
			await release()
			await click(scene.action_buttons[int(plan.choice)].text)
		else:
			await steer((plan.goal - C.position(scene.state)).limit_length())
			await physics_frame
	await release()

func retain_slots(label: String) -> void:
	assert(not timing_open)
	check(scene.paused or scene.state.phase != "playing", "raw slots are observed only at held/terminal boundary: " + label)
	var packet := S.read()
	check(packet.ok and context_matches(packet), "complete app-written envelope matches held memory: " + label)
	var directory := folder.path_join("slots").path_join(label)
	DirAccess.make_dir_recursive_absolute(directory)
	var files := {}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var source := ProjectSettings.globalize_path(S.PATH + str(slot) + suffix)
			if FileAccess.file_exists(source):
				var name := "hearth-save-%d%s" % [slot, suffix]
				var target := directory.path_join(name)
				check(DirAccess.copy_absolute(source, target) == OK and FileAccess.get_sha256(source) == FileAccess.get_sha256(target), "retain exact app-written slot " + label + "/" + name)
				files[name] = {"path": "slots/" + label + "/" + name, "sha256": FileAccess.get_sha256(target)}
	slot_snapshots[label] = {"files": files, "selected_slot": packet.get("slot", -1), "revision": packet.get("revision", -1), "whole": whole_memory()}

func retry_passage() -> void:
	check(scene.state.phase in ["defeat", "victory"], "Retry starts from genuine app-written terminal; no manufactured outcome")
	await retain_slots("before-retry")
	await snap("real-terminal")
	var career: Dictionary = scene.campaign_profile.duplicate(true)
	var legacy: Dictionary = scene.profile.duplicate(true)
	var definition: Dictionary = scene.state.definition.duplicate(true)
	await click("RETRY PASS")
	await hold()
	var supply := int(scene.state.wallet)
	for coin in scene.state.coins:
		supply += int(coin.value)
	check(scene.state.phase == "playing" and scene.state.time < 1 and scene.state.enemies.is_empty() and scene.state.spent == 0 and scene.state.ledger.is_empty() and supply == definition.supply, "real Retry restores finite supply and clean encounter")
	check(C.equivalent(scene.state.definition, definition) and scene.campaign_profile == career and scene.profile == legacy, "Retry retains entire pinned definition and both profiles")
	check(scene.presenter.effects.is_empty() and scene.presenter.corpses.is_empty(), "Retry drains old transient nodes before IDs are reused")
	await snap("actual-retry-held")
	await start_playing()
	await play_for(seconds)

func lifecycle_passage() -> void:
	check(scene.state.phase == "playing", "lifecycle starts from authentic active save")
	await hold()
	for size in [Vector2i(1080, 2400), Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1100, 1400), Vector2i(1600, 1000)]:
		var whole := whole_memory()
		root.size = size
		await dwell(5)
		check(whole_memory() == whole, "complete paused context survives resize " + str(size))
		await snap("paused-" + str(size.x) + "x" + str(size.y))
		await start_playing()
		var before := C.position(scene.state)
		dragging_origin = Vector2(100, root.get_visible_rect().size.y * .58)
		await steer(Vector2(-.4, -.7))
		await dwell(16)
		await hold()
		check(C.position(scene.state).distance_to(before) > .05 and scene.input_vector == Vector2.ZERO, "actual inverse-transformed movement/release after resize " + str(size))
	root.size = Vector2i(720, 1280)
	await dwell(4)
	var settings_before: Dictionary = scene.settings.duplicate(true)
	var context_before := whole_memory()
	await click(scene.effects_button.text)
	check(scene.settings.reduced_effects != settings_before.reduced_effects and C.equivalent(scene.state, context_before.state) and scene.campaign_profile == context_before.campaign_profile, "real reduced-effects switch changes only its setting while paused")
	await start_playing()
	await play_for(6)
	await hold()
	await snap("alternate-effects-held")
	await click(scene.effects_button.text)
	check(scene.settings == settings_before, "real effects pair restores entire original settings")
	await click("JOURNEY / REPLAY")
	await snap("journey-menu")
	await key(KEY_ESCAPE)
	await click("SAVE / TRANSFER")
	await snap("transfer-menu-no-clipboard")
	await key(KEY_ESCAPE)
	await retain_slots("restore-source")
	var held := whole_memory()
	var raw := disk_bytes()
	await dwell(60)
	check(whole_memory() == held and disk_bytes() == raw, "held lifecycle endpoint keeps complete memory and both raw slots unchanged")

func restore_passage() -> void:
	check(scene.state.phase == "playing" and scene.paused, "new Godot process cold-restores active app-written slots paused")
	var before := whole_memory()
	var raw := disk_bytes()
	await dwell(60)
	check(whole_memory() == before and disk_bytes() == raw, "cold-held state/settings/profiles/raw slots do not advance")
	await start_playing()
	await play_for(seconds)

func region_tour() -> void:
	check(scene.campaign_profile.clears.size() == 10 and scene.campaign_profile.ending, "regional tour requires genuine full earned campaign")
	var career: Dictionary = scene.campaign_profile.duplicate(true)
	await hold()
	await click("JOURNEY / REPLAY")
	for stage in 10:
		await click(scene.map_buttons[stage].text)
		if scene.confirm_panel.visible:
			await click("REPLACE WATCH")
		await dwell(30)
		check(scene.state.definition.stage == stage and scene.state.phase == "ready" and scene.campaign_profile == career, "actual unlocked regional entry retains entire earned career " + str(stage + 1))
		await snap("region-%02d" % (stage + 1))
		await click("II")
		await click("JOURNEY / REPLAY")
	await click("THE TEN BEACONS / ENDING")
	await snap("earned-ending")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(scene.paused and scene.campaign_profile == career, "actual Back returns from earned ending and Journey without profile drift")

func capture_native_frame() -> void:
	if not recording:
		return
	# Legacy routing replaces Battle synchronously. Rebind before the next drawn
	# frame so the native stream never skips frames while an old node is freed.
	if is_instance_valid(game_root) and game_root.has_node("Battle"):
		scene = game_root.get_node("Battle")
	var before := native_inventory.size()
	super.capture_native_frame()
	if native_inventory.size() > before:
		observed.record_frame(scene, native_inventory.size() - 1)

func sample_timing_frame() -> void:
	if timing_open:
		sampler.sample(scene)

func snap(name: String) -> void:
	assert(not timing_open, "Frame readback is forbidden during timing")
	await super.snap(name)

func finish_production() -> void:
	var coverage := observed.report()
	var f := FileAccess.open(folder.path_join("production-report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage": production_stage, "checks": checks, "failures": failures, "details": details,
		"start_context": start_context, "end_context": whole_memory() if is_instance_valid(scene) else {}, "expected_code": expected_code,
		"declared_lead_in_simulation_seconds": lead_in, "native_frame_count": native_inventory.size(),
		"raw_slot_snapshots": slot_snapshots, "coverage": coverage,
		"limits": "Actual input passages from fresh or authenticated earned bytes. Optional lead-in is normal real input before contiguous movie recording, never accelerated. Model coverage is projected observation, not independent visual acceptance. Cold restore is a separate process with prior raw slots. Fixed-cadence footage is not FPS."}, "\t"))
	f.close()
	# The parent writes native inventory, complete input trace and standard report.
	# Its old timing path stays disabled; this harness uses the proven frame sampler.
	measure = false
	super.finish_passage()
