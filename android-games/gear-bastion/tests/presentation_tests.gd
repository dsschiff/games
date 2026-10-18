extends SceneTree
const Battle = preload("res://scripts/battle_rules.gd")
const Policy = preload("res://tests/campaign_policies.gd")
const Adapter = preload("res://scripts/presentation/adapter.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Foundry = preload("res://scripts/presentation/foundry.gd")
const Layout = preload("res://scripts/window_layout.gd")
var checks := 0
var failures: Array[String] = []
var event_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func run() -> void:
	var baseline = load("res://.artifacts/graphics-production/baseline_battle.gd")
	check(baseline != null, "Immutable code7 rule baseline is available")
	if baseline == null:
		quit(1)
		return
	for id in ["camp_04", "camp_09", "iron_trial"]:
		var original := Battle.initial(1701,id)
		if id != "iron_trial":
			Policy.apply(original,"A")
		var current: Dictionary = original.duplicate(true)
		Battle.start(original)
		Battle.start(current)
		var grouped := false
		for i in (900 if id == "iron_trial" else 1800):
			var events: Array = []
			baseline.tick(original,Battle.STEP)
			Battle.tick(current,Battle.STEP,events)
			check(current == original,id + " whole state exactly equal at tick " + str(i))
			event_count += events.size()
			var attacks: Dictionary = {}
			for event in events:
				check(event.has("actor") and event.has("target") and event.has("attack"),"Exact actor/target/attack metadata")
				if attacks.has(event.attack):
					grouped = true
				attacks[event.attack] = true
		if id == "camp_04":
			check(grouped,"Dense encounter emits shared attack identities across splash recipients")
	for id in ["camp_03","camp_06","camp_09"]:
		var original := Battle.initial(1701,id)
		Battle.start(original)
		original.boss_spawned = true
		original.boss_total = 61
		original.boss_volley = 11.99
		var boss: Dictionary = Battle.make_unit(original,original.config.boss,1,false)
		boss.hp = original.config.boss_hp
		boss.max_hp = boss.hp
		original.enemies.append(boss)
		var current: Dictionary = original.duplicate(true)
		var events: Array = []
		baseline.tick(original,Battle.STEP)
		Battle.tick(current,Battle.STEP,events)
		check(current == original,id + " isolated enrage/volley fixture retains exact old state")
		check(events.any(func(item): return item.kind == "volley" and item.target == "wall" and item.actor == "enemy:"+str(int(boss.id))),id + " exact boss identity routes authoritative wall volley")
	var state := Battle.initial(1701,"camp_09")
	Policy.apply(state,"A")
	Battle.start(state)
	for i in 180:
		Battle.tick(state,Battle.STEP)
	var adapter := Adapter.new()
	adapter.reset(state,false)
	var frozen := adapter.current.duplicate(true)
	state.units[0].x += 1
	check(adapter.current == frozen,"Snapshot owns copied scalar/vector values, no rule references")
	var event := {"kind":"attack","attack":"2:1","actor":"ally:2","target":"enemy:3"}
	check(adapter.accept(event) and not adapter.accept(event),"One transient accepted once per attempt")
	var old_epoch := adapter.epoch
	adapter.reset(state,true)
	check(adapter.epoch > old_epoch and adapter.accept(event),"Reset namespaces reused IDs and clears dedupe")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600,1066)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var world := Foundry.new()
	viewport.add_child(world)
	var layout := Layout.new()
	layout.arrange(Vector2(600,1066))
	world.build(layout,Vector2(600,1066))
	world.hydrate(state,false)
	await process_frame
	for role in ["guard","ranger","mortar","beetle","shell","skitter","spitter","swarm","carapace","captain","siege","matriarch"]:
		var actor := Actor.new()
		world.add_child(actor)
		actor.configure(role,role in ["guard","ranger","mortar"],.3)
		check(actor.rig.get_bone_count() >= 16,role + " imported rigid-weight skeletal rig")
		check(actor.bones.has("Weapon") and actor.muzzle.get_parent() is BoneAttachment3D,role + " socket inherits actual animated weapon joint")
		actor.pose(.12,Vector3(.8,0,-.5),false)
		var before: Quaternion = actor.rig.get_bone_pose_rotation(actor.bones["ThighL" if actor.humanoid else "LegL0"])
		actor.pose(.18,Vector3(.8,0,-.5),false)
		check(not before.is_equal_approx(actor.rig.get_bone_pose_rotation(actor.bones["ThighL" if actor.humanoid else "LegL0"])),role + " genuine limb articulation")
		actor.fire(Vector3(5,0,0))
		check(actor.fire_left > 0 and absf(actor.torso_yaw) > .1,role + " attack aims separate torso/weapon")
		var analytic_tip: Vector3 = actor.rig.global_transform * actor.rig.get_bone_global_pose(actor.bones.Weapon) * actor.muzzle.position
		check(analytic_tip.distance_to(actor.muzzle.global_position) < .0001,role + " actual muzzle follows aimed and recoiling authored bone")
		actor.hit()
		actor.pose(.05,Vector3.ZERO,false)
		check(actor.hit_left > 0,role + " local damage reaction")
		actor.death_time = 0
		actor.pose(.30,Vector3.ZERO,false)
		check(absf(actor.model.rotation.z) > .1,role + " authored jointed defeat")
		actor.reset_transients()
		check(actor.death_time < 0 and actor.fire_left == 0 and actor.hit_left == 0,role + " hydration clears defeat/shot/hit")
		actor.free()
	var counted_attacks: Dictionary = {}
	var counted_impacts: Dictionary = {}
	var before_attacks := world.attacks_emitted
	var before_impacts := world.impacts_emitted
	for i in 120:
		var events: Array = []
		Battle.tick(state,Battle.STEP,events)
		for item in events:
			counted_attacks[item.attack] = true
			counted_impacts[str(item.attack)+":"+str(item.kind)+":"+str(item.target)] = true
		world.sync(state,events)
		world.sync(state,events)
		world.step(Battle.STEP,false,false)
	check(world.attacks_emitted-before_attacks == counted_attacks.size(),"Multiple real simulation substeps and duplicate batches emit one recoil per attack")
	check(world.impacts_emitted-before_impacts == counted_impacts.size(),"Grouped attack retains every distinct authoritative splash/contact recipient exactly once")
	for dimensions in [Vector2(600,1400),Vector2(960,1066),Vector2(1183,1066),Vector2(600,1066)]:
		layout.arrange(dimensions)
		viewport.size = Vector2i(dimensions)
		world.fit(layout,dimensions)
		world.sync(state,[])
		for y in 4:
			for x in 5:
				var point := layout.board.position + Vector2(x+.5,y+.5)*80
				check(world.world_to_canvas(world.canvas_to_world(point)).distance_to(point) < .01,"Actual camera projection round-trips board cell at " + str(dimensions))
		check(world.arches.size() == 3,"Exactly three modeled open arches at " + str(dimensions))
	var before_time := world.presentation_time
	var before_pose: Transform3D = world.actors.values()[0].model.transform
	world.step(1,true,false)
	check(world.presentation_time == before_time and world.actors.values()[0].model.transform == before_pose,"Pause freezes presentation time and model pose")
	world.step(.10,false,true)
	check(world.presentation_time > before_time,"Reduced effects retains actual articulation/time")
	world.hydrate(Battle.initial(1701,"tutorial"),true)
	check(world.actors.is_empty() and world.corpses.is_empty() and world.effects.is_empty(),"Legacy hydration clears actors/corpses/transients with no phantom shot")
	viewport.free()
	var report := {"checks":checks,"failures":failures,"event_count":event_count,"scope":"CPU source/rig/projection/invariance; no visible quality or FPS claim"}
	var file := FileAccess.open("res://.artifacts/graphics-production/cpu-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("PRESENTATION_CHECKS: %d checks, %d failures, %d real event recipients" % [checks,failures.size(),event_count])
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
