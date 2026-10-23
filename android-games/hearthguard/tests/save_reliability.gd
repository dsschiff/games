extends "res://tests/campaign_journey.gd"

class ReloadWatch extends "res://scripts/bootstrap.gd":
	var reloads := 0
	func reload_saved() -> void:
		reloads += 1
		super.reload_saved()

var fixtures := {}
var observations: Array = []

func run() -> void:
	root.size = Vector2i(720, 1280)
	fixtures = build_fixtures()
	check(fixtures.source.campaign.clears.size() == 1 and fixtures.source.profile.wins > 0, "synthetic fixtures carry real rule-derived nonempty campaign and legacy records")
	for mode in [1, 2]:
		for target_mode in [1, 2]:
			for fault in ["missing_destination", "corrupt_destination"]:
				await load_fixture(mode)
				await click("SAVE / TRANSFER")
				scene.code_edit.text = code_for(fixtures.incoming, target_mode)
				var io := fault_store(fault)
				scene.save_io = io
				var before := whole_memory()
				var old := S.read(S.PATH, io)
				var old_bytes: String = io.files[S.PATH + str(old.slot)]
				var reloads: int = game_root.reloads
				await click("IMPORT")
				await dwell(3)
				scene = game_root.get_node("Battle")
				check(whole_memory() == before, "failed import keeps complete live context %d->%d %s" % [mode, target_mode, fault])
				check(game_root.reloads == reloads and scene.notice.text.begins_with("Storage failed"), "failed import neither routes nor claims success %d->%d %s" % [mode, target_mode, fault])
				check(same_context(S.read(S.PATH, io), old) and io.files[S.PATH + str(old.slot)] == old_bytes, "failed import keeps newest checked old slot for cold recovery %d->%d %s" % [mode, target_mode, fault])
				observations.append({"mode":mode,"target":target_mode,"fault":fault,"live":whole_memory(),"cold":S.read(S.PATH,io)})
				materialize_fault(io)
				await cold_reload(old, "materialized failed import %d->%d %s" % [mode,target_mode,fault])
			await load_fixture(mode)
			await click("SAVE / TRANSFER")
			var expected := S.decode(code_for(fixtures.incoming, target_mode))
			scene.code_edit.text = code_for(fixtures.incoming, target_mode)
			await click("IMPORT")
			await dwell(3)
			scene = game_root.get_node("Battle")
			check(live_matches(expected), "successful import restores exact whole meaning %d->%d" % [mode,target_mode])
			await cold_reload(expected, "successful import %d->%d" % [mode,target_mode])
	for mode in [1, 2]:
		for fault in ["fail_write", "fail_rename", "missing_destination", "corrupt_destination"]:
			await load_fixture(mode)
			if mode == 2: await click("JOURNEY / REPLAY")
			var io := fault_store(fault)
			scene.save_io = io
			var before := whole_memory()
			var old := S.read(S.PATH, io)
			var reloads: int = game_root.reloads
			await click("RETURN TO LEGACY PASS" if mode == 2 else "OPEN EXPEDITION • KEEP LEGACY PASS")
			await dwell(3)
			scene = game_root.get_node("Battle")
			check(whole_memory() == before and game_root.reloads == reloads, "failed mode switch keeps live and both parked runs %d %s" % [mode,fault])
			check(scene.save_problem and scene.wave_label.text.begins_with("SAVE FAILED"), "failed mode switch surfaces storage failure %d %s" % [mode,fault])
			check(same_context(S.read(S.PATH, io), old), "failed mode switch keeps complete cold context %d %s" % [mode,fault])
			materialize_fault(io)
			await cold_reload(old, "materialized failed mode switch %d %s" % [mode,fault])
	for mode in [1, 2]:
		await load_fixture(mode)
		var before := whole_memory()
		if mode == 2: await click("JOURNEY / REPLAY")
		await click("RETURN TO LEGACY PASS" if mode == 2 else "OPEN EXPEDITION • KEEP LEGACY PASS")
		await dwell(3)
		scene = game_root.get_node("Battle")
		var expected := S.read()
		check(scene.state.schema == 3 - mode and live_matches(expected), "successful mode switch loads checked opposite mode " + str(mode))
		check(same_value(expected.campaign.parked if mode == 2 else expected.campaign.legacy_snapshot, before.state), "successful switch parks the exact outgoing watch " + str(mode))
		await cold_reload(expected, "successful mode switch " + str(mode))
	await check_return_phases()
	await shutdown()
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join("save-reliability.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details,"events":events,"observations":observations,"scope":"Synthetic rule-derived save fixtures and fault backend; actual engine ScreenTouch GUI import/switch actions; no clipboard, renderer, Android or human pacing evidence."},"  "))
	print("SAVE_RELIABILITY ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func build_fixtures() -> Dictionary:
	var legacy := R.fresh()
	legacy.phase = "playing"
	var legacy_profile := R.profile()
	for frame in 10000:
		if legacy.phase != "playing": break
		var goal := R.position(legacy)
		if not legacy.coins.is_empty(): goal = Vector2(legacy.coins[0].x, legacy.coins[0].z)
		for pad in 2:
			if legacy.pads[pad] == 0 and legacy.wallet >= R.COSTS[pad]:
				goal = R.PADS[pad]
				if R.position(legacy).distance_to(goal) <= R.BUILD_DISTANCE: R.buy(legacy,pad)
				break
		R.tick(legacy,(goal-R.position(legacy)).limit_length(),1.0/60)
	R.finish(legacy,legacy_profile)
	var completed := C.fresh(Cat.definition(0))
	completed.phase = "playing"
	var cp := C.profile()
	for frame in 20000:
		if completed.phase != "playing": break
		var plan := Policy.plan(completed)
		if plan.affordable and C.position(completed).distance_to(plan.goal) < 1.4: C.action(completed,plan.pad,plan.choice)
		C.tick(completed,(plan.goal-C.position(completed)).limit_length(),1.0/60)
	C.finish(completed,cp)
	var active := C.fresh(Cat.definition(1,173,1,true))
	active.phase = "playing"
	for frame in 240:
		var plan := Policy.plan(active)
		if plan.affordable and C.position(active).distance_to(plan.goal) < 1.4: C.action(active,plan.pad,plan.choice)
		C.tick(active,(plan.goal-C.position(active)).limit_length(),1.0/60)
	var old := R.fresh()
	old.phase = "playing"
	for frame in 70: R.tick(old,Vector2(0,-1),1.0/60)
	cp.legacy_snapshot = legacy.duplicate(true)
	cp.parked = completed.duplicate(true)
	var source := {"legacy":old,"active":active,"profile":legacy_profile,"campaign":cp,"settings":{"sound":false,"reduced_effects":true}}
	var incoming_cp := cp.duplicate(true)
	incoming_cp.legacy_snapshot = old.duplicate(true)
	incoming_cp.parked = active.duplicate(true)
	return {"source":source,"incoming":{"legacy":legacy,"active":completed,"profile":legacy_profile,"campaign":incoming_cp,"settings":{"sound":true,"reduced_effects":false}}}

func code_for(fixture: Dictionary, mode: int) -> String:
	return S.encode(fixture.legacy if mode == 1 else fixture.active,fixture.profile,fixture.settings,1,true,fixture.campaign)

func load_fixture(mode: int) -> void:
	await shutdown()
	var fixture: Dictionary = fixtures.source
	check(S.write(fixture.legacy if mode == 1 else fixture.active,fixture.profile,fixture.settings,S.PATH,null,false,fixture.campaign),"stage valid synthetic source mode " + str(mode))
	game_root = ReloadWatch.new()
	root.add_child(game_root)
	await dwell(3)
	scene = game_root.get_node("Battle")
	check(scene.paused and scene.state.phase == "playing", "ordinary source load pauses active mode " + str(mode))

func fault_store(fault: String) -> RefCounted:
	var io := Faults.new()
	for path in disk_bytes(): io.files[path] = FileAccess.get_file_as_string(path)
	io.set(fault,true)
	return io

func same_context(a: Dictionary,b: Dictionary) -> bool:
	return a.ok and b.ok and same_value(a.state,b.state) and same_value(a.profile,b.profile) and same_value(a.settings,b.settings) and same_value(a.campaign,b.campaign)

func live_matches(expected: Dictionary) -> bool:
	return expected.ok and same_value(scene.state,expected.state) and same_value(scene.profile,expected.profile) and same_value(scene.settings,expected.settings) and same_value(scene.campaign_profile,expected.campaign)

func cold_reload(expected: Dictionary,label: String) -> void:
	await shutdown()
	game_root = ReloadWatch.new()
	root.add_child(game_root)
	await dwell(3)
	scene = game_root.get_node("Battle")
	check(live_matches(expected) and scene.paused == (expected.state.phase == "playing"), "cold whole meaning retained: " + label)

func shutdown() -> void:
	if is_instance_valid(game_root):
		game_root.queue_free()
		await process_frame
		await process_frame

func materialize_fault(io: RefCounted) -> void:
	# Copy the fault result, including missing/torn slots and unpromoted staging,
	# into this run's isolated disk namespace before an ordinary application load.
	for path in disk_bytes():
		if not io.files.has(path): DirAccess.remove_absolute(path)
	for path in io.files:
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(io.files[path])
		file.flush()
		file.close()

func check_return_phases() -> void:
	for mode in [1,2]:
		for phase in ["ready","playing","victory","defeat"]:
			await shutdown()
			var fixture: Dictionary = fixtures.source
			var state: Dictionary = fixture.legacy.duplicate(true) if mode == 1 else fixture.active.duplicate(true)
			var legacy_profile: Dictionary = fixture.profile.duplicate(true)
			var cp: Dictionary = fixture.campaign.duplicate(true)
			if phase == "ready": state = R.fresh() if mode == 1 else C.fresh(Cat.definition(0))
			elif phase == "victory": state = fixtures.incoming.legacy.duplicate(true) if mode == 1 else fixtures.incoming.active.duplicate(true)
			elif phase == "defeat":
				state = R.fresh() if mode == 1 else C.fresh(Cat.definition(0))
				state.phase = "playing"
				for frame in 20000:
					if state.phase != "playing": break
					if mode == 1: R.tick(state,Vector2.ZERO,1.0/60)
					else: C.tick(state,Vector2.ZERO,1.0/60)
				if mode == 1: R.finish(state,legacy_profile)
				else: C.finish(state,cp)
			check(S.write(state,legacy_profile,fixture.settings,S.PATH,null,false,cp), "stage valid return phase %d %s" % [mode,phase])
			game_root = ReloadWatch.new()
			root.add_child(game_root)
			await dwell(3)
			scene = game_root.get_node("Battle")
			if phase == "playing": await click("RESUME")
			var before := whole_memory()
			# Synthetic lifecycle dispatch, separate from native Android Home evidence.
			scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			await dwell(3)
			check(scene.state == before.state and scene.profile == before.legacy_profile and scene.campaign_profile == before.campaign_profile and scene.settings == before.settings, "Home dispatch retains whole phase context %d %s" % [mode,phase])
			if phase == "playing":
				check(scene.paused and scene.menu.visible and scene.resume_button.text == "RESUME", "active Home dispatch offers real Resume " + str(mode))
				await click("RESUME")
				check(not scene.paused and scene.state.phase == "playing", "actual Resume returns to active watch " + str(mode))
				await click("II")
			elif phase == "ready":
				check(not scene.paused and not scene.menu.visible and scene.start_button.visible, "ready Home dispatch preserves the brief " + str(mode))
				await click("II")
				check(scene.resume_button.text == "BACK TO BRIEF", "ready log action names its destination " + str(mode))
				await click("BACK TO BRIEF")
			else:
				check(not scene.paused and not scene.menu.visible and scene.terminal.visible, "terminal Home dispatch keeps result and Retry available %d %s" % [mode,phase])
				await click("PAUSE / LOG")
				check(scene.resume_button.text == "BACK TO RESULT", "terminal log action names its destination %d %s" % [mode,phase])
				await click("BACK TO RESULT")
				check(scene.terminal.visible and not scene.paused, "actual result return preserves terminal %d %s" % [mode,phase])
			await cold_reload(S.read(),"return phase %d %s" % [mode,phase])

func same_value(a: Variant,b: Variant) -> bool:
	# Compare every serialized context value, normalizing only JSON number types.
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
