extends "res://tests/playthrough.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Adapter = preload("res://scripts/presentation/adapter.gd")
var observations: Array = []

func run() -> void:
	root.size = Vector2i(720,1280)
	# This fresh-opening probe must not inherit another suite's active save.
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(4)
	await steer(Vector2(0,-1))
	for frame in 600:
		await physics_frame
		if scene.state.strike > .30 and not scene.state.contact: break
	check(scene.state.strike > .30 and scene.state.strike_id >= 0, "actual joystick approach launches automatic chain at an in-range creature")
	var target_id: int = scene.state.strike_id
	var target := enemy_by_id(scene.state,target_id)
	var hp_before: float = target.hp
	var impacts: int = scene.presentation.event_counts.get("contact",0)
	await steer((R.position(scene.state)-Vector2(target.x,target.z)).normalized())
	for frame in 30:
		await physics_frame
		if scene.state.contact: break
	await release()
	target = enemy_by_id(scene.state,target_id)
	check(scene.state.contact and not target.is_empty() and target.hp == hp_before, "actual retreat before chain contact makes the first attack miss without fabricated outcome")
	check(scene.presentation.event_counts.get("contact",0) == impacts, "a resolved miss produces no successful-hit impact")
	observations.append({"case":"input_retreat_miss","hp_before":hp_before,"hp_after":target.hp,"events":scene.presentation.event_counts.duplicate()})
	# Re-approach and hold: only genuine enemy hull loss should produce contact.
	for frame in 900:
		target = enemy_by_id(scene.state,target_id)
		if target.is_empty() or target.hp < hp_before: break
		await steer(policy(scene.state))
		await physics_frame
	await release()
	target = enemy_by_id(scene.state,target_id)
	check(target.is_empty() or target.hp < hp_before, "actual re-approach produces genuine enemy damage")
	check(scene.presentation.event_counts.get("contact",0) > impacts, "genuine damage retains successful-hit feedback")
	check(scene.presentation.event_counts.get("miss",0) > 0 and scene.presentation.event_counts.get("swing",0) > 0, "miss keeps the visible chain launch without claiming successful contact")
	await resolution_fixtures()
	await paint_checks()
	if not capture_dir.is_empty():
		FileAccess.open(capture_dir.path_join("contact-feedback-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"observations":observations,"events":events,"scope":"Actual engine joystick approach/retreat/re-approach; explicitly synthetic warning geometry fixtures; no Android/render quality acceptance"},"  "))
	scene.queue_free()
	await process_frame
	print("CONTACT_FEEDBACK ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func enemy_by_id(state: Dictionary,id: int) -> Dictionary:
	for enemy in state.enemies:
		if int(enemy.id) == id: return enemy
	return {}

func paint_checks() -> void:
	var fixture := C.fresh(2,1,0)
	var view := Adapter.new()
	root.add_child(view)
	view.build(fixture)
	var enemy: Dictionary = C.active(fixture)[0]
	var definition: Dictionary = fixture.definition.roster[int(enemy.id)]
	var actor: Node3D = view.actors[int(enemy.id)]
	for attack in ["line","charge","shot","burst"]:
		enemy.mode = "wind"
		enemy.attack = attack
		enemy.ax = 0.0; enemy.az = 0.0; enemy.tx = 0.0; enemy.tz = 1.0
		var before := fixture.duplicate(true)
		view._telegraph(actor,enemy,definition,false)
		check(fixture == before, attack + ": warning geometry never writes the authoritative state")
		var strip: MeshInstance3D = actor.warning.get_node("Line")
		var painted_half: float = strip.mesh.size.x * absf(strip.scale.x) / 2.0
		var damaging_half := .8 if attack == "line" else .9 if attack == "charge" else .5
		check(painted_half >= damaging_half - .00001, attack + ": painted ground strip covers damaging player-centre footprint")
		observations.append({"case":"paint_fixture","attack":attack,"painted_half":painted_half,"damaging_half":damaging_half})
		if attack == "burst":
			for branch in ["Left","Right"]:
				var side: MeshInstance3D = actor.warning.get_node(branch)
				check(side.mesh.size.x * absf(side.scale.x) / 2.0 >= .5 - .00001, branch + ": projectile branch covers collision radius")
	# Sample the line-damage capsule; charge_footprint uses actual constrained
	# C.step routes instead of assuming a straight charge. Include line caps
	# and a rotated aim. The rule tests player centres, not an added body radius.
	for attack in ["line"]:
		for boss in [false,true]:
			var spec := definition.duplicate(true)
			spec.boss = boss
			for axis in [Vector2(0,1),Vector2(.6,.8)]:
				enemy.attack = attack
				enemy.tx = axis.x; enemy.tz = axis.y
				view._telegraph(actor,enemy,spec,false)
				var strip: MeshInstance3D = actor.warning.get_node("Line")
				var length := 6.8 if attack == "charge" else 8.5 if boss else 5.3
				var radius := .89 if attack == "charge" else .79
				var side := Vector2(-axis.y,axis.x)
				for point in [-axis * radius, axis * (length + radius), axis * (length / 2) + side * radius, axis * (length / 2) - side * radius]:
					var local := strip.to_local(Vector3(point.x,.04,point.y))
					var half: Vector3 = strip.mesh.size / 2
					check(absf(local.x) <= half.x + .00001 and absf(local.z) <= half.z + .00001, attack + " damage centre and endcaps are inside paint for boss=" + str(boss) + " aim=" + str(axis))
	view.free()
	await process_frame

func resolution_fixtures() -> void:
	var fixture := C.fresh(2,1,0)
	var view := Adapter.new()
	root.add_child(view)
	view.build(fixture)
	var target: Dictionary = C.active(fixture)[0]
	fixture.strike_id = target.id
	fixture.strike_x = target.x; fixture.strike_z = target.z
	fixture.strike = .36; fixture.contact = false; fixture.time += .02
	view.capture(fixture)
	fixture.strike = .18; fixture.contact = true; fixture.blocked = .4; fixture.time += .18
	var held := fixture.duplicate(true)
	view.capture(fixture)
	check(view.event_counts.get("blocked",0) == 1 and view.event_counts.get("contact",0) == 0, "frontal armor gets distinct blocked feedback without successful-hit gold")
	check(fixture == held, "feedback classification leaves every rule/save field unchanged")
	var serial: int = view.serial
	for i in 4: view.capture(fixture)
	check(view.serial == serial, "blocked result is observed once across repeated UI refreshes")
	view.hydrate(fixture)
	check(view.events.is_empty() and view.effects.is_empty(), "cold/hydrated resolved strike replays no result effect")
	# Hit flash proves a hit even when a tender heals the lost hull in that tick.
	fixture.contact = false; fixture.strike = .36; fixture.time += .5
	view.capture(fixture)
	target.flash = .16; fixture.contact = true; fixture.strike = .18; fixture.time += .18
	view.capture(fixture)
	check(view.event_counts.get("contact",0) == 1, "same-tick healed hit still has genuine contact feedback")
	view.free()
	await process_frame
