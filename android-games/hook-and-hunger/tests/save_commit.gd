extends "res://tests/playthrough.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Fault = preload("res://tests/fault_files.gd")

class ImportWatch extends "res://scripts/main.gd":
	var rebuilds := 0
	func _rebuild() -> void:
		rebuilds += 1
		super._rebuild()

var fixtures: Array = []
var observations: Array = []

func run() -> void:
	root.size = Vector2i(720,1280)
	fixtures = contexts()
	for context in fixtures:
		check(S.decode(code(context)).ok,"labelled rule-derived fixture validates " + context.name)
	for source in fixtures:
		for incoming in fixtures:
			for fault in ["fail_write","fail_rename","missing_destination","corrupt_destination","wrong_destination"]:
				var io := seeded(source)
				await load_live(io)
				if not scene.paused: await click("PAUSE")
				var before := whole()
				var old := S.read(S.PATH,io)
				var old_path: String = S.PATH + str(old.slot) + (".tmp" if old.recovered else "")
				var old_bytes: String = io.files[old_path]
				io.set(fault,true)
				io.replacement_text = io.files[S.PATH + str(1-int(old.slot))]
				scene.transfer.text = code(incoming)
				var rebuilds: int = scene.rebuilds
				await click("IMPORT")
				check(whole() == before,"failed GUI import retains full live context %s→%s %s" % [source.name,incoming.name,fault])
				check(scene.rebuilds == rebuilds and scene.transfer_status.text.begins_with("Storage failed"),"failed GUI import reports storage failure without rebuilding %s→%s %s" % [source.name,incoming.name,fault])
				check(S.read(S.PATH,io).source == old.source and io.files[old_path] == old_bytes,"failed import retains newest old slot exact %s→%s %s" % [source.name,incoming.name,fault])
				observations.append({"source":source.name,"target":incoming.name,"fault":fault,"live_unchanged":whole()==before,"cold":S.read(S.PATH,io),"status":scene.transfer_status.text})
				materialize(io)
				await reload_disk(old,"failed import %s→%s %s" % [source.name,incoming.name,fault])
			var io := seeded(source)
			await load_live(io)
			if not scene.paused: await click("PAUSE")
			var old := S.read(S.PATH,io)
			var expected := S.decode(code(incoming))
			scene.transfer.text = code(incoming)
			await click("IMPORT")
			check(matches(whole(),expected) and scene.transfer_status.text.begins_with("Imported"),"successful GUI import restores all fields %s→%s" % [source.name,incoming.name])
			var saved := S.read(S.PATH,io)
			check(matches(saved,expected) and saved.revision == old.revision+1 and saved.source == S.encode(expected.state,expected.settings,old.revision+1,false,expected.profile),"successful import confirms exact complete destination %s→%s" % [source.name,incoming.name])
			materialize(io)
			await reload_disk(expected,"successful import %s→%s" % [source.name,incoming.name])
	for context in fixtures:
		for recovered in [false,true]:
			for fault in ["missing_destination","corrupt_destination","wrong_destination"]:
				var io := seeded(context,recovered)
				var old := S.read(S.PATH,io)
				var old_path: String = S.PATH + str(old.slot) + (".tmp" if old.recovered else "")
				var old_bytes: String = io.files[old_path]
				io.set(fault,true)
				io.replacement_text = S.encode(context.state,context.settings,1,true,context.profile)
				check(not S.write(context.state,context.settings,S.PATH,io,false,context.profile),"owning Store rejects false rename success %s recovered%s %s" % [context.name,recovered,fault])
				check(S.read(S.PATH,io).source == old.source and io.files[old_path] == old_bytes,"normal failed write retains newest stable/recovery slot %s %s %s" % [context.name,recovered,fault])
	if is_instance_valid(scene): scene.free()
	await process_frame
	FileAccess.open(capture_dir.path_join("save-commit-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"observations":observations,"scope":"Labelled rule-derived synthetic context matrix; actual Input.parse_input_event Import clicks with owning Store/fault backend. Materialized disk and normal scene rebuilds within the same headless engine process, not process-kill/Android/clipboard/render proof."},"  "))
	print("SAVE_COMMIT ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func completed(stage: int,arena: bool = false) -> Dictionary:
	var tier := 1 if stage < 3 else 2 if stage < 6 else 3
	var state := C.fresh(stage,tier,5000,1701,arena)
	state.phase = "victory"; state.wave = int(state.definition.waves)-1
	state.time = float(state.definition.waves)*10
	for wave in int(state.definition.waves): state.wave_times.append((wave+1)*10.0)
	for spec in state.definition.roster:
		state.dead.append(int(spec.id)); state.collected.append(int(spec.id)); state.wallet += int(spec.reward)
	state.enemies.clear()
	return state

func contexts() -> Array:
	var legacy := R.fresh()
	for tick in 45: R.step(legacy,Vector2(1,0),1.0/60)
	var empty := C.profile()
	var profile := C.profile()
	profile.clears = [-1]
	profile.medals["-1"] = 2
	for stage in 9:
		profile.stage = stage
		C.record(profile,completed(stage))
	profile.stage = 9
	var campaign := C.fresh(9,3,876,1704)
	for tick in 24: C.step(campaign,Vector2(-1,0),1.0/60)
	var arena_profile := profile.duplicate(true)
	for stage in range(9,12):
		arena_profile.stage = stage
		C.record(arena_profile,completed(stage))
	arena_profile.ending = completed(11)
	C.record(arena_profile,completed(11,true))
	var arena := C.fresh(11,2,1234,1702,true)
	for tick in 18: C.step(arena,Vector2(1,0),1.0/60)
	return [{"name":"legacy","state":legacy,"profile":empty,"settings":{"sound":false,"reduced_effects":true}},{"name":"campaign","state":campaign,"profile":profile,"settings":{"sound":true,"reduced_effects":false}},{"name":"arena_parked_ending","state":arena,"profile":arena_profile,"settings":{"sound":false,"reduced_effects":false}}]

func code(context: Dictionary) -> String:
	return S.encode(context.state,context.settings,0,true,context.profile)

func seeded(context: Dictionary,recovered: bool = false) -> RefCounted:
	var io := Fault.new()
	check(S.write(context.state,context.settings,S.PATH,io,false,context.profile),"seed first complete context")
	check(S.write(context.state,context.settings,S.PATH,io,false,context.profile),"seed newest complete context")
	if recovered:
		var best := S.read(S.PATH,io)
		io.files[S.PATH+str(best.slot)+".tmp"] = S.encode(context.state,context.settings,8,true,context.profile)
	return io

func load_live(io: RefCounted) -> void:
	if is_instance_valid(scene): scene.free()
	scene = ImportWatch.new()
	scene.save_io = io
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	check(matches(whole(),S.read(S.PATH,io)),"normal owning controller load retains all fields")

func whole() -> Dictionary:
	return {"state":scene.state.duplicate(true),"profile":scene.profile.duplicate(true),"settings":scene.settings.duplicate(true)}

func matches(a: Dictionary,b: Dictionary) -> bool:
	return a.state == b.state and a.profile == b.profile and a.settings == b.settings

func materialize(io: RefCounted) -> void:
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
			if io.files.has(path):
				var file := FileAccess.open(path,FileAccess.WRITE)
				file.store_string(io.files[path]); file.flush(); file.close()

func reload_disk(expected: Dictionary,message: String) -> void:
	if is_instance_valid(scene): scene.free()
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	check(matches(whole(),expected),"materialized disk reload preserves full context: " + message)
