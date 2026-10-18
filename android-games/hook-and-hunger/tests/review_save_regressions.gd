extends "res://tests/playthrough.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Policy = preload("res://tests/campaign_policy.gd")
var boundary_report := {}

func run() -> void:
	root.size = Vector2i(720, 1280)
	# Completed-voyage fixture only unlocks the real arena controls. All movement,
	# the heavy selection, the first strike and lifecycle saves use the real scene.
	var ending := C.fresh(11, 3, 5000)
	ending.time = 60.0
	ending.wave = int(ending.definition.waves) - 1
	ending.wave_times = [10.0,20.0,30.0,40.0,50.0,60.0]
	ending.phase = "victory"
	for spec in ending.definition.roster:
		ending.dead.append(int(spec.id))
		ending.collected.append(int(spec.id))
		ending.wallet += int(spec.reward)
	ending.enemies.clear()
	var profile := C.profile()
	profile.stage = 11
	profile.completed = true
	for stage in range(-1, 12):
		profile.clears.append(stage)
	var settings := {"sound": false, "reduced_effects": true}
	for path in [S.PATH, "user://review-heavy-boundary"]:
		for slot in 2:
			for suffix in ["", ".tmp"]:
				var file: String = path + str(slot) + suffix
				if FileAccess.file_exists(file):
					DirAccess.remove_absolute(file)
	check(C.valid(ending) and C.valid_profile(profile), "completed-voyage setup fixture validates")
	check(S.write(ending, settings, S.PATH, null, false, profile), "setup stored through ordinary save boundary")
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await click("HARBOR / REPLAY")
	for attempt in 3:
		if int(scene.profile.arena_weapon) == 2:
			break
		await click(scene.arena_weapon_button.text)
	await click("SAIL TO ARENA")
	check(scene.state.definition.arena and scene.state.tier == 2, "actual arena controls select heavy refit")
	var found := false
	for frame in 1200:
		if scene.state.phase != "playing":
			break
		if scene.state.cooldown == 0 and scene.state.strike == 0:
			# Arm the normal autosave clock before the first Rules.step launch.
			scene.save_clock = 2.0
		await steer(Policy.direction(scene.state))
		await physics_frame
		await process_frame
		if scene.state.strike > 0 and scene.state.cooldown > 0.9:
			scene.set_physics_process(false)
			found = true
			break
	check(found, "real heavy strike exposes the greater-than0.9 cooldown window")
	if found:
		var state: Dictionary = scene.state
		var period: float = C.weapon(state).period
		check(period == 0.95 and state.cooldown <= period, "first strike uses pinned heavy period0.95")
		check(C.valid(state), "immediate actual post-strike state validates")
		check(S.decode(S.encode(state, scene.settings, 0, true, scene.profile)).ok, "immediate post-strike export decodes")
		check(scene.save_error.is_empty(), "armed normal autosave succeeds inside the heavy cooldown window")
		var saved := S.read()
		check(saved.ok and saved.state.cooldown > 0.9, "actual primary save contains the just-launched heavy cooldown")
		check(S.write(state, scene.settings, "user://review-heavy-boundary", null, false, scene.profile), "real filesystem Store.write accepts immediate heavy strike")
		var direct := S.read("user://review-heavy-boundary")
		check(direct.ok and direct.state.cooldown > 0.9, "direct write readback retains heavy strike")
		var exact := state.duplicate(true)
		exact.cooldown = period
		check(C.valid(exact), "exact selected period is a valid upper boundary")
		exact.cooldown = period + 0.0000001
		check(C.valid(exact), "tiny numeric roundtrip tolerance is accepted")
		exact.cooldown = period + 0.001
		check(not C.valid(exact), "cooldown clearly beyond selected period is rejected")
		exact.cooldown = -0.001
		check(not C.valid(exact), "negative cooldown is rejected")
		exact.cooldown = 0.95
		exact.tier = 3
		exact.starting_tier = 3
		check(not C.valid(exact), "short Storm weapon cannot inherit the heavy cooldown bound")
		var before := JSON.stringify(state)
		var revision: int = S.read().get("revision", 0)
		# This exercises the real native notification handler; Android background
		# dispatch remains a separate coordinator/device check.
		scene.notification(NOTIFICATION_APPLICATION_PAUSED)
		var after := S.read()
		check(scene.paused and scene.menu.visible, "application-pause notification pauses the live scene")
		check(scene.save_error.is_empty() and after.ok and int(after.revision) > revision, "lifecycle handler commits a fresh save in the heavy window")
		check(JSON.stringify(state) == before, "lifecycle handler preserves the whole active strike state")
		check(after.ok and after.state.cooldown > 0.9 and after.state.strike > 0, "lifecycle saved state retains strike and cooldown")
		boundary_report = {"captured_state": state.duplicate(true), "saved": after, "period": period, "scope": "Validated completed-voyage setup; actual controls/movement/strike, armed normal autosave, real filesystem and native application-pause notification. No Android dispatch claim."}
		await snap("heavy-post-strike-paused")
		scene.queue_free()
		await process_frame
		scene = load("res://main.tscn").instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		check(scene.state.schema == 2 and scene.state.tier == 2 and scene.state.cooldown > 0.9 and scene.paused, "ordinary cold scene reload preserves heavy strike paused")
	# This is a labelled synthetic malformed import, never a natural play state:
	# all first-wave rewards accounted, but progression was not advanced.
	var stranded := C.fresh(0, 1, 63)
	for e in C.active(stranded):
		stranded.dead.append(int(e.id))
		stranded.collected.append(int(e.id))
		stranded.wallet += int(stranded.definition.roster[int(e.id)].reward)
	stranded.enemies = stranded.enemies.filter(func(e: Dictionary) -> bool: return not int(e.id) in stranded.dead)
	var import_profile := C.profile()
	import_profile.stage = 0
	import_profile.clears = [-1]
	var synthetic_before := {"valid": C.valid(stranded), "wallet": stranded.wallet, "wave": stranded.wave, "active_enemies": C.active(stranded).size(), "enemies": stranded.enemies.size(), "phase": stranded.phase}
	check(not C.valid(stranded), "reject synthetic playing state with exhausted current wave")
	var variant := stranded.duplicate(true)
	variant.phase = "defeat"
	variant.hp = 0.0
	check(not C.valid(variant), "reject synthetic defeat with exhausted current wave")
	variant = ending.duplicate(true)
	variant.phase = "playing"
	variant.wave_times.pop_back()
	check(not C.valid(variant), "reject all-waves-exhausted playing state")
	check(C.valid(ending), "coherent final victory with every wave exhausted remains valid")
	var different_settings := {"sound": not scene.settings.sound, "reduced_effects": not scene.settings.reduced_effects}
	var malformed_source := S.encode(stranded, different_settings, 0, true, import_profile)
	check(not S.decode(malformed_source).ok, "checked save decoder rejects exhausted-wave import")
	if not scene.menu.visible:
		await click("PAUSE")
	var before_state := JSON.stringify(scene.state)
	var before_profile := JSON.stringify(scene.profile)
	var before_settings := JSON.stringify(scene.settings)
	var before_disk := S.read()
	scene.transfer.text = malformed_source
	await click("IMPORT")
	check(scene.transfer_status.text.begins_with("Invalid save"), "actual Import UI rejects synthetic exhausted-wave packet")
	check(JSON.stringify(scene.state) == before_state, "rejected import retains whole in-memory active state")
	check(JSON.stringify(scene.profile) == before_profile, "rejected import retains whole in-memory profile")
	check(JSON.stringify(scene.settings) == before_settings, "rejected import retains in-memory settings")
	var after_disk := S.read()
	check(after_disk.ok and before_disk.ok and after_disk.state == before_disk.state and after_disk.profile == before_disk.profile and after_disk.settings == before_disk.settings, "rejected import retains whole on-disk state/profile/settings")
	boundary_report["synthetic_exhausted_wave"] = synthetic_before
	await snap("rejected-empty-wave-import")
	if not capture_dir.is_empty():
		var f := FileAccess.open(capture_dir.path_join("save-regressions.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"checks": checks, "failures": failures, "checks_detail": report, "boundary": boundary_report, "events": events}, "  "))
		f.close()
	print("REVIEW_SAVE_REGRESSIONS: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
