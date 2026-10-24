extends "res://tests/import_recovery.gd"

class Observing extends Faults:
	var terminal_writes: Array=[]
	var owner: WeakRef
	var original_profile := {}
	func write_text(path: String,text: String) -> bool:
		var decoded := S.decode(text)
		if path.begins_with(S.PATH) and decoded.ok and decoded.state.phase=="victory":
			var live: Node=owner.get_ref()
			var expected: Dictionary=original_profile.duplicate(true)
			C.record(expected,live.state)
			var canonical := S.decode(S.encode(live.state,live.settings,0,true,expected))
			terminal_writes.append({"actual":decoded,"expected":canonical})
		return super.write_text(path,text)

func run() -> void:
	root.size=Vector2i(720,1280)
	for arena in [false,true]:
		var context: Dictionary=contexts()[2 if arena else 1]
		context.state=completed(11 if arena else 9,arena)
		if arena: context.profile.arena_scores={}
		var state: Dictionary=context.state
		var spec: Dictionary=state.definition.roster.back()
		var enemy := C.actor(spec)
		enemy.x=0.0; enemy.z=2.0; enemy.hp=1.0
		state.dead.erase(int(spec.id)); state.collected.erase(int(spec.id)); state.wallet-=int(spec.reward)
		state.enemies=[enemy]; state.phase="playing"; state.wave_times.pop_back()
		state.x=0.0; state.z=2.0; state.strike=.19; state.strike_id=int(spec.id); state.strike_x=0.0; state.strike_z=2.0
		check(S.decode(code(context)).ok,"valid pre-winning-step fixture arena="+str(arena))
		var io := Observing.new(); io.files[S.PATH+"0"]=code(context)
		await open_owner(io)
		io.original_profile=scene.profile.duplicate(true)
		io.owner=weakref(scene)
		scene.save_clock=2.0
		scene.set_physics_process(true)
		await tap("RESUME")
		for frame in 60:
			if scene.state.phase=="victory": break
			await physics_frame
		scene.set_physics_process(false)
		check(scene.state.phase=="victory" and not io.terminal_writes.is_empty(),"actual Resume earns winning strike while autosave due")
		for candidate in io.terminal_writes:
			check(matches(candidate.actual,candidate.expected),"every durable terminal candidate already contains complete new record arena="+str(arena))
		observations.append({"arena":arena,"written_terminal_contexts":io.terminal_writes})
	if is_instance_valid(scene): scene.free()
	await process_frame
	FileAccess.open(capture_dir.path_join("terminal-commit.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"observations":observations,"scope":"Synthetic valid pre-winning snapshots; actual Resume input and normal winning physics step with due autosave. All Store-written terminal envelopes observed. Headless/Dummy only."},"  "))
	print("TERMINAL_COMMIT ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
