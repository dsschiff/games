extends "res://tests/import_recovery.gd"

func run() -> void:
	root.size=Vector2i(720,1280)
	var cases := [
		{"name":"canonical_only","scores":{"1701:3":{"hits":1,"time":40.0,"rescues":1}}},
		{"name":"alias_only","scores":{"1701.0:3":{"hits":1,"time":40.0,"rescues":1}}},
		{"name":"canonical_better","scores":{"1701:3":{"hits":1,"time":60.0,"rescues":2},"1701.0:3":{"hits":5,"time":30.0,"rescues":3}}},
		{"name":"alias_better","scores":{"1701:3":{"hits":5,"time":60.0,"rescues":2},"1701.0:3":{"hits":1,"time":70.0,"rescues":3}}},
		{"name":"first_record","scores":{}}
	]
	for entry in cases:
		var context: Dictionary=contexts()[2]
		context.state=completed(11,true)
		context.state.time=50.0; context.state.hits=4; context.state.deaths=2
		context.profile.arena_scores=entry.scores.duplicate(true)
		context.profile.arena_scores["unrelated historical key"]={"hits":2,"time":18.0,"rescues":0,"extra":"keep whole entry"}
		var source := code(context)
		var decoded := S.decode(source)
		check(decoded.ok,"complete arena terminal fixture validates "+entry.name)
		var io := fresh_io(context)
		materialize(io)
		await reload_disk(decoded,"cold arena terminal "+entry.name)
		current_scene=scene
		check(scene.state.definition.seed is float and matches(whole(),decoded),"normal JSON cold restoration preserves complete context "+entry.name)
		var expected := whole()
		var before := whole()
		expected.state=expected.profile.ending.duplicate(true)
		expected.profile.ending={}
		if entry.name=="first_record": expected.profile.arena_scores["1701:3"]={"hits":4,"time":50.0,"rescues":2}
		await tap("RETURN TO HARBOR")
		check(scene.profile==expected.profile,"actual Continue keeps stable arena identity and whole historical profile "+entry.name)
		check(scene.state==expected.state and scene.settings==expected.settings,"actual Continue restores complete parked finale and settings "+entry.name)
		var saved := S.read()
		check(matches(saved,expected),"durable Continue context has stable score identity "+entry.name)
		observations.append({"case":entry.name,"source_code":source,"before":before,"expected":expected,"actual":whole(),"saved":saved})
		await tap("PAUSE")
		await tap("SAIL TO ARENA")
		var reentry := expected.duplicate(true)
		reentry.profile.ending=expected.state.duplicate(true)
		reentry.state=C.fresh(11,reentry.profile.arena_weapon,0,reentry.profile.arena_seed,true)
		check(whole()==reentry,"actual arena reentry preserves whole historical profile and parks exact finale "+entry.name)
		var cold_expected := S.decode(S.encode(reentry.state,reentry.settings,0,true,reentry.profile))
		check(matches(S.read(),cold_expected),"actual reentry disk equals entire owning-codec round trip "+entry.name)
		await reload_disk(cold_expected,"cold actual arena reentry "+entry.name)
		check(scene.paused and matches(whole(),cold_expected),"new arena stays whole/paused after normal cold reload "+entry.name)

	lookup_contracts()
	if is_instance_valid(scene): scene.free()
	await process_frame
	FileAccess.open(capture_dir.path_join("arena-score-key.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"observations":observations,"scope":"Synthetic validated complete arena terminal profiles normally written/materialized then cold-loaded through production decoder. Actual Continue touch input, whole profiles/settings/parked ending and durable readback. Headless/Dummy, not fresh earned arena victories or Android/native/cloud."},"  "))
	print("ARENA_SCORE_KEY ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)

func lookup_contracts() -> void:
	var context: Dictionary=contexts()[2]
	context.state=completed(11,true)
	for seed in [1,1701,999999]:
		for tier in [1,2,3]:
			var canonical := str(seed)+":"+str(tier)
			var alias := str(float(seed))+":"+str(tier)
			check(C.arena_key(seed,tier)==canonical,"numeric arena identity stable "+canonical)
			var profile_data: Dictionary=context.profile.duplicate(true)
			profile_data.arena_scores={alias:{"hits":2,"time":40.0,"rescues":8,"historical":"whole alias"}}
			var before: Dictionary=profile_data.duplicate(true)
			var selected := C.arena_best(profile_data,seed,tier)
			check(selected.found and selected.score==profile_data.arena_scores[alias] and profile_data==before,"alias-only best usable without migration "+canonical)
			selected.score.hits=999
			check(profile_data==before,"lookup cannot mutate retained whole entry "+canonical)
			profile_data.arena_scores[canonical]={"hits":3,"time":1.0,"rescues":0}
			check(C.arena_best(profile_data,seed,tier).score==profile_data.arena_scores[alias],"fewer hits outranks faster canonical "+canonical)
			profile_data.arena_scores[canonical]={"hits":2,"time":30.0,"rescues":9}
			check(C.arena_best(profile_data,seed,tier).score==profile_data.arena_scores[canonical],"time breaks equal-hit identity tie "+canonical)
			profile_data.arena_scores[canonical]={"hits":2,"time":40.0,"rescues":9,"canonical":"whole canonical"}
			check(C.arena_best(profile_data,seed,tier).score==profile_data.arena_scores[canonical],"equal ranking deterministically retains canonical whole entry "+canonical)
			check(not C.arena_best(profile_data,seed,1+tier%3).found,"distinct loadout never borrows score "+canonical)
	# An improved run updates one existing record and preserves every other
	# historical entry, including a full100-entry alias-only profile.
	for layout in ["alias_only","canonical_better","alias_better","full_alias"]:
		var profile_data: Dictionary=context.profile.duplicate(true)
		profile_data.arena_scores={"1701.0:3":{"hits":2,"time":40.0,"rescues":8,"note":"old alias"}}
		if layout=="canonical_better": profile_data.arena_scores["1701:3"]={"hits":1,"time":30.0,"rescues":1}
		if layout=="alias_better": profile_data.arena_scores["1701:3"]={"hits":4,"time":10.0,"rescues":0}
		if layout=="full_alias":
			for i in 99: profile_data.arena_scores["opaque historical "+str(i)]={"hits":i,"time":float(i),"rescues":i,"extra":"retain"}
		var old: Dictionary=profile_data.duplicate(true)
		var state: Dictionary=context.state.duplicate(true)
		state.hits=0; state.time=35.0; state.deaths=3
		var expected: Dictionary=old.duplicate(true)
		var target := "1701:3" if old.arena_scores.has("1701:3") else "1701.0:3"
		expected.arena_scores[target]={"hits":0,"time":35.0,"rescues":3}
		C.record(profile_data,state)
		check(profile_data==expected,"better run replaces only its existing whole best slot "+layout)
		check(C.valid_profile(profile_data) and S.decode(S.encode(state,context.settings,0,true,profile_data)).ok,"improved profile and parked finale remain decoder valid "+layout)
		var restored := S.decode(S.encode(state,context.settings,0,true,profile_data))
		var replay: Dictionary=restored.profile.duplicate(true)
		C.record(replay,restored.state)
		check(replay==restored.profile,"repeat JSON-restored identical record is idempotent "+layout)
		check(not C.arena_best(profile_data,1702,3).found,"different seed remains independent "+layout)

	for historical_key in ["1701:3","1701.0:3"]:
		var zero: Dictionary=context.profile.duplicate(true)
		zero.arena_scores={historical_key:{"hits":0,"time":0.0,"rescues":0}}
		var before_zero: Dictionary=zero.duplicate(true)
		var found := C.arena_best(zero,1701,3)
		check(found.found and found.score==zero.arena_scores[historical_key],"zero hits/time is a real found score "+historical_key)
		var worse: Dictionary=context.state.duplicate(true); worse.hits=0; worse.time=35.0
		C.record(zero,worse)
		check(zero==before_zero,"zero best is not overwritten as a missing sentinel "+historical_key)
