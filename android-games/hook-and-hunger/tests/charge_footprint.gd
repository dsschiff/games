extends "res://tests/contact_feedback.gd"
## Synthetic arrangements exercised by actual pinned campaign step().
func run() -> void:
	for dt in [1.0/60,1.0/30,.05,.041,.017]:
		await path_case(Vector2(-1.4,-7),Vector2(0,1),2,dt,true)
		await path_case(Vector2(0,-10),Vector2(0,1),1,dt,false)
	for layout in 3:
		for start in [Vector2(-5.8,-10),Vector2(5.8,3.5),Vector2(-1.4,-7),Vector2(0,-10)]:
			for axis in [Vector2(0,1),Vector2(0,-1),Vector2(1,0),Vector2(-1,0),Vector2(.6,.8),Vector2(-.6,.8),Vector2(.6,-.8),Vector2(-.6,-.8),Vector2(1,1),Vector2.ZERO,Vector2(.2,.4)]:
				for dt in [1.0/60,1.0/30,.05,.017,-1.0,.08]:
					await path_case(start,axis,layout,dt,false)
	# Explicit synthetic overlapping rocks exercise revisits/side relaxation;
	# these are not authored saves or earned progression.
	for rocks in [
		[{"x":0.0,"z":-2.5,"radius":1.2},{"x":-1.5,"z":-2.5,"radius":1.2}],
		[{"x":-1.5,"z":-2.5,"radius":1.2},{"x":0.0,"z":-2.5,"radius":1.2}],
		[{"x":0.0,"z":-2.5,"radius":1.2},{"x":-1.5,"z":-2.5,"radius":1.2},{"x":1.4,"z":-1.0,"radius":1.0}]]:
		for dt in [1.0/60,1.0/30,.05,-1.0]:
			await path_case(Vector2(-1.4,-7),Vector2(0,1),2,dt,false,rocks)
	if not capture_dir.is_empty():
		FileAccess.open(capture_dir.path_join("charge-footprint-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"observations":observations,"scope":"Synthetic starting arrangements; actual C.step with pinned layouts, no earned progression."},"  "))
	print("CHARGE_FOOTPRINT ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func fixture(start: Vector2,axis: Vector2,layout: int) -> Dictionary:
	var state := C.fresh(9,3,0,layout + 3)
	var enemy: Dictionary = {}
	for candidate in C.active(state):
		if state.definition.roster[int(candidate.id)].role == "charger": enemy = candidate; break
	state.enemies = [enemy]
	enemy.x = start.x; enemy.z = start.y; enemy.ax = start.x; enemy.az = start.y
	enemy.mode = "wind"; enemy.attack = "charge"; enemy.tx = axis.x; enemy.tz = axis.y; enemy.clock = .001
	state.x = -2.4 if layout == 2 else 5.0
	state.z = -2.515 if layout == 2 else 2.0
	state.cooldown = 20.0
	return state

func painted(strip: MeshInstance3D,point: Vector2) -> bool:
	var local := strip.to_local(Vector3(point.x,strip.global_position.y,point.y))
	var half: Vector3 = strip.mesh.size / 2
	return absf(local.x) <= half.x + .0001 and absf(local.z) <= half.z + .0001

func path_case(start: Vector2,axis: Vector2,layout: int,dt: float,known_hit: bool, custom_rocks: Array = []) -> void:
	var state := fixture(start,axis,layout)
	if not custom_rocks.is_empty(): state.definition.obstacles = custom_rocks.duplicate(true)
	var enemy: Dictionary = state.enemies[0]
	var view := Adapter.new()
	root.add_child(view)
	view.build(state)
	var actor: Node3D = view.actors[int(enemy.id)]
	var strip: MeshInstance3D = actor.warning.get_node("Line")
	var held := state.duplicate(true)
	view._telegraph(actor,enemy,state.definition.roster[int(enemy.id)],false)
	check(state == held,"charge warning leaves authoritative state unchanged")
	var route: Array = []
	var route_bounds := Rect2(start,Vector2.ZERO)
	C.step(state,Vector2.ZERO,dt if dt > 0 else .05)
	var covers := true
	var frames := 0
	while enemy.mode == "charge" and frames < 100:
		var old := Vector2(enemy.x,enemy.z)
		C.step(state,Vector2.ZERO,dt if dt > 0 else [.007,.05,.021,.033][frames % 4])
		var point := Vector2(enemy.x,enemy.z)
		route.append([point.x,point.y])
		route_bounds = route_bounds.expand(point)
		for center in [old,old.lerp(point,.5),point]:
			for i in 12:
				var side := Vector2.from_angle(i * TAU / 12) * .8999
				if not painted(strip,center+side): covers = false
		frames += 1
	check(covers,"actual charge sweep/endcap centres covered for layout%d dt%.6f axis%s" % [layout,dt,axis])
	if known_hit:
		check(state.hp < held.hp,"actual rock-deflected charge hits previously unpainted diver at dt"+str(dt))
		check(painted(strip,Vector2(held.x,held.z)),"that damaged diver centre is inside warning at dt"+str(dt))
		check(not painted(strip,Vector2(2.4,-2.515)),"opposite side of exact left-deflected rock charge stays visibly safe at dt"+str(dt))
	observations.append({"layout":layout,"custom_rocks":custom_rocks,"dt":dt,"start":start,"axis":axis,"route":route,"hp_before":held.hp,"hp_after":state.hp,"warning_transform":str(strip.global_transform),"covered":covers,"conservative_envelope":str(view._charge_envelope(held,held.enemies[0])),"actual_route_box_area":route_bounds.grow(.9).get_area()})
	view.free()
	await process_frame
