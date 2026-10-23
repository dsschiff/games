extends SceneTree
const A = preload("res://scripts/presentation/adapter.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const V = preload("res://scripts/presentation/settlement.gd")
const C = preload("res://scripts/campaign_rules.gd")
const Cat = preload("res://scripts/campaign_catalog.gd")
const L = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const Policy = preload("res://tests/campaign_policy.gd")
var checks := 0
var failures := 0
var folder := ""
var baseline := ""
var details: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--baseline-dir="):
			baseline = arg.trim_prefix("--baseline-dir=")
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)
	print("CHECK ", "PASS " if okay else "FAIL ", message)

func run() -> void:
	print("ISOLATED_USER_DATA ", OS.get_user_data_dir())
	for name in ["rules.gd", "campaign_rules.gd", "campaign_catalog.gd", "save_files.gd"]:
		check(FileAccess.get_file_as_string("res://scripts/" + name).replace("\r\n", "\n") == FileAccess.get_file_as_string(baseline + name).replace("\r\n", "\n"), "functional baseline exact source preserved: " + name)
	var current_store := FileAccess.get_file_as_string("res://scripts/save_store.gd").replace("\r\n", "\n")
	var old_store := FileAccess.get_file_as_string(baseline + "save_store.gd").replace("\r\n", "\n")
	check(current_store.get_slice("static func write(", 0) == old_store.get_slice("static func write(", 0), "save format/decoder/read baseline source preserved; destination transaction intentionally hardened")
	var state := C.fresh(Cat.definition(0))
	var adapter := A.new()
	adapter.reset(state, false)
	state.x = 1
	state.coins[0].value = 999
	check(is_equal_approx(adapter.current.actors.commander.position.x, 2.8) and adapter.current.coins[0].value == 3, "snapshots own deep values without rule aliases")
	state = C.fresh(Cat.definition(0))
	adapter.reset(state, false)
	state.time = .05
	state.x += .20
	adapter.ingest(state, false, .05)
	check(is_equal_approx(adapter.advance(.025), .5), "render interpolation has independent elapsed time")
	var event := {"kind": "shot", "pad": 1, "x": 1.0, "z": 2.0}
	check(adapter.accept(event) and not adapter.accept(event), "same tick event dedupes")
	state.time += .05
	adapter.ingest(state, false, .05)
	check(adapter.accept(event), "identical later attack is not lost")
	for i in 700:
		adapter.accept({"kind": "pickup", "id": i})
	check(adapter.seen.size() == 512, "transient cursor memory is bounded")
	var epoch: int = adapter.epoch
	adapter.ingest(state, true, 0)
	var held: float = adapter.elapsed
	adapter.advance(4)
	check(adapter.epoch == epoch + 1 and adapter.seen.is_empty() and adapter.elapsed == held, "pause clears events and holds render time")
	state.time = 0
	adapter.ingest(state, false, 0)
	check(adapter.current == adapter.previous, "Retry/reused IDs hydrate without interpolating the old run")
	for role in ["commander", "citizen", "defender", "raider", "runner", "armor", "swarm", "mender", "shade", "ram", "matriarch", "regent"]:
		var actor := Actor.new()
		root.add_child(actor)
		actor.configure(role)
		var meshes := find_meshes(actor.model)
		var weighted := 0
		var vertices := 0
		for mesh in meshes:
			if mesh.skin != null:
				weighted += 1
			for surface in mesh.mesh.get_surface_count():
				vertices += mesh.mesh.surface_get_array_len(surface)
		check(actor.rig != null and actor.bones.size() >= 18 and weighted >= 5 and vertices > 1000, "real modeled skin, weighted articulated skeleton: " + role)
		actor.pose(.1, Vector3(0, 0, -3), "playing")
		check(not actor.rig.get_bone_pose_rotation(actor.bones.ThighL).is_equal_approx(Quaternion.IDENTITY) and not actor.rig.get_bone_pose_rotation(actor.bones.ShinR).is_equal_approx(Quaternion.IDENTITY), "thigh, knee and ankle gait: " + role)
		actor.update_health(4, 10, true)
		actor.update_health(3, 10, false)
		check(actor.hit_left > 0 and actor.health.visible, "damage response from HP observation: " + role)
		actor.fire(Vector3(5, 0, -2))
		actor.pose(.10, Vector3.ZERO, "playing")
		check(actor.shot_left > 0 and not actor.rig.get_bone_pose_rotation(actor.bones.Weapon).is_equal_approx(Quaternion.IDENTITY), "articulated weapon attack: " + role)
		if role == "defender":
			actor.reset_transients()
			var cap := nearest_weapon_vertex(actor)
			check(cap.gap < .04, "socket is at actual visible weighted crossbow bolt geometry")
			var cap_local: Vector3 = actor.rig.get_bone_global_rest(actor.bones.Weapon).affine_inverse() * cap.point
			var socket_okay := true
			for target in [Vector3(5, 0, -1), Vector3(-4, 0, -2), Vector3(2, 0, 5)]:
				actor.fire(target)
				actor.pose(.08, Vector3.ZERO, "playing")
				var socket: Vector3 = actor.socket_position()
				var visible_cap: Vector3 = actor.rig.to_global(actor.rig.get_bone_global_pose(actor.bones.Weapon) * cap_local)
				socket_okay = socket_okay and socket.distance_to(visible_cap) < .04
			check(socket_okay, "same-call socket follows actual visible crossbow tip through three aim/recoil poses")
		actor.fall()
		actor.pose(.3, Vector3.ZERO, "defeat")
		check(absf(actor.model.rotation.x) > .5, "articulated fall remains separate from rule lifetime: " + role)
		actor.reset_transients()
		check(actor.shot_left == 0 and actor.hit_left == 0 and actor.death_time < 0, "hydration resets all local attack/hit/death clocks: " + role)
		actor.pose(.1, Vector3.ZERO, "victory")
		if role in ["commander", "citizen", "defender"]:
			check(absf(actor.rig.get_bone_pose_rotation(actor.bones.UpperArmL).get_euler().z) > 1, "jointed victory response: " + role)
		actor.queue_free()
		await process_frame
	for stage in 10:
		var s := C.fresh(Cat.definition(stage))
		var saved := s.duplicate(true)
		var view := V.new()
		root.add_child(view)
		view.set_process(false)
		view.build(s)
		check(C.equivalent(s, saved), "building regional presentation leaves entire save unchanged map " + str(stage + 1))
		var clear_bounds := true
		var protected := AABB(Vector3(-5.20, -.01, -7.99), Vector3(10.4, 3, 15.19))
		for record in view.bounds_records:
			if (record.bounds as AABB).intersects(protected):
				print("SCENERY_INTRUSION ", record.asset, " ", record.bounds)
				clear_bounds = false
		check(clear_bounds, "complete transformed opaque scenery bounds clear traversable actor bodies map " + str(stage + 1))
		var prices_okay := true
		for label in view.pad_labels:
			prices_okay = prices_okay and label.text.contains("9 GOLD")
		check(prices_okay and view.region.landmark.length() > 5 and view.civilians.size() == 6, "authored landmark, citizens and real minimum construction price map " + str(stage + 1))
		for size in [Vector2i(1080, 2400), Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1100, 1400), Vector2i(1600, 1000), Vector2i(2560, 1440)]:
			root.size = size
			await process_frame
			var logical := root.get_visible_rect().size
			var field := Rect2(Vector2(28, 228), Vector2(logical.x - 56, logical.y - 516))
			view.fit(field)
			var projected: Rect2 = view.projected_bounds(view.framing_points())
			check(field.grow(.2).encloses(projected), "real camera fits uniform actor/build/road bounds map %d at %s" % [stage + 1, size])
			var control_clear := true
			var forbidden := [Rect2(0, 0, logical.x, 210), Rect2(0, logical.y - 160, logical.x, 160), Rect2(38, logical.y - 378, 160, 160)]
			for record in view.bounds_records:
				var projected_prop: Rect2 = view.projected_bounds(bounds_points(record.bounds))
				for control_rect in forbidden:
					if projected_prop.intersects(control_rect):
						control_clear = false
						print("PROJECTED_CONTROL_INTRUSION map=", stage + 1, " profile=", size, " model=", record.asset, " rect=", projected_prop, " control=", control_rect)
			check(control_clear, "opaque modeled scenery clears projected HUD/action/stick rectangles map %d at %s" % [stage + 1, size])
		# All tower families, forks, projectile sockets and reset behavior use real nodes.
		if stage == 0:
			s.phase = "playing"
			for family in 3:
				s.towers[family].family = family
				s.towers[family].fork = family % 2 + 1
			view.synchronize(s, false, 0)
			for i in 3:
				var t: Dictionary = view.towers[i]
				var p := view.pad_point(i)
				var shot := {"kind": "shot", "pad": i, "family": i, "x": -p.x, "z": -p.y, "area": 1.0}
				view.queue_events([shot, shot], s.time)
				view.synchronize(s, false, 0)
				var bolt: Dictionary = view.effects.back()
				# Optional pulse may be last; identify the actual projectile.
				for effect in view.effects:
					if effect.family == i:
						bolt = effect
				check((bolt.from as Vector3).distance_to(t.tip.global_position) < .0001, "tower projectile originates at actual authored weapon tip family " + str(i))
				check(nearest_static_vertex(t.turret, t.tip.global_position) < .14, "authored tower socket touches modeled visible weapon family " + str(i))
				var visible_aims := true
				for yaw in [0.0, .9, -1.4]:
					t.turret.rotation.y = yaw
					view.present(.03)
					visible_aims = visible_aims and nearest_static_vertex(t.turret, t.tip.global_position) < .14
				check(visible_aims, "actual visible tower weapon socket remains on geometry through aim and recoil family " + str(i))
			check(view.attacks_emitted == 3, "duplicate observations cannot replay attacks")
			view.synchronize(s, true, 0)
			check(view.effects.is_empty() and view.corpses.is_empty(), "pause drains transient projectiles and corpse nodes")
			var resumed_shots: int = view.attacks_emitted
			s.time += .05
			view.queue_events([{"kind": "shot", "pad": 0, "x": 0.0, "z": 0.0}], s.time)
			view.synchronize(s, false, .05)
			check(view.attacks_emitted == resumed_shots + 1 and not view.effects.is_empty(), "first real resumed tick shot survives paused-to-running hydration")
			view.synchronize(s, true, 0)
			view.queue_events([{"kind": "shot", "pad": 0, "x": 0.0, "z": 1.0}], s.time - .05)
			view.synchronize(s, false, 0)
			check(view.attacks_emitted == resumed_shots + 1 and view.effects.is_empty(), "stale pre-boundary observations never replay after Resume")
			s.x -= .1
			s.time += .05
			view.synchronize(s, false, .05)
			view.present(.03)
			s.phase = "victory"
			view.synchronize(s, false, 0)
			var terminal_gait: float = view.units.commander.gait
			for frame in 120:
				view.present(1.0 / 60)
			check(view.units.commander.travel == 0 and view.units.commander.gait == terminal_gait, "terminal snapshot stops surviving actor gait despite retained prior movement delta")
			view.synchronize(s, true, 0)
			var before := S.encode(s, L.profile(), {"sound": true, "reduced_effects": false}, 1, true, C.profile())
			view.present(10)
			check(S.encode(s, L.profile(), {"sound": true, "reduced_effects": false}, 1, true, C.profile()) == before, "ten seconds presentation cannot mutate complete serialized save")
		view.queue_free()
		await process_frame
		await process_frame
	await baseline_equivalence()
	await input_boundaries()
	await legacy_boundaries()
	var report := {"checks": checks, "failures": failures, "details": details, "scope": "CPU import/skins/actual geometry/snapshot/rules/save/projection/input; no visual or phone acceptance"}
	var file := FileAccess.open(folder.path_join("presentation-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PRESENTATION_CHECKS ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func find_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(find_meshes(child))
	return found

func bounds_points(bounds: AABB) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in 8:
		points.append(bounds.get_endpoint(i))
	return points

func nearest_weapon_vertex(actor: Node3D) -> Dictionary:
	var tip: Vector3 = actor.rig.get_bone_global_rest(actor.bones.WeaponTip).origin
	var best := {"gap": INF, "point": Vector3.ZERO}
	for node in find_meshes(actor.model):
		if node.skin == null:
			continue
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for vertex in verts.size():
				var weapon := false
				for influence in 4:
					var bind: int = joints[vertex * 4 + influence]
					var bone: int = node.skin.get_bind_bone(bind)
					if bone < 0:
						bone = actor.rig.find_bone(node.skin.get_bind_name(bind))
					weapon = weapon or (weights[vertex * 4 + influence] > .99 and bone == actor.bones.Weapon)
				if weapon:
					var point: Vector3 = actor.rig.to_local(node.to_global(verts[vertex]))
					var gap := point.distance_to(tip)
					if gap < best.gap:
						best = {"gap": gap, "point": point}
	return best

func nearest_static_vertex(node: Node3D, tip: Vector3) -> float:
	var distance := INF
	for mesh in find_meshes(node):
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				distance = minf(distance, mesh.to_global(vertex).distance_to(tip))
	return distance

func baseline_equivalence() -> void:
	var old: Script = load(baseline + "campaign_rules.gd")
	for stage in [0, 5, 9]:
		var a: Dictionary = old.fresh(Cat.definition(stage, 51, -1, true))
		var b := C.fresh(Cat.definition(stage, 51, -1, true))
		a.phase = "playing"
		b.phase = "playing"
		var identical := true
		var adapter := A.new()
		adapter.reset(b, false)
		for frame in 1600:
			var plan := Policy.plan(a)
			if plan.pad >= 0 and plan.choice >= 0:
				old.action(a, plan.pad, plan.choice)
				C.action(b, plan.pad, plan.choice)
			var move: Vector2 = (plan.goal - C.position(a)).limit_length()
			var events_old: Array = old.tick(a, move, 1.0 / 60)
			var events_new := C.tick(b, move, 1.0 / 60)
			adapter.ingest(b, frame % 240 == 0, 1.0 / 60)
			for event in events_new:
				adapter.accept(event)
			adapter.advance(.01)
			identical = identical and C.equivalent(a, b) and C.equivalent(events_old, events_new)
		check(identical, "old/new entire state and exact events equal all 1600 policy ticks map " + str(stage + 1))
	var old_legacy: Script = load(baseline + "rules.gd")
	var a: Dictionary = old_legacy.fresh()
	var b := L.fresh()
	a.phase = "playing"
	b.phase = "playing"
	var identical := true
	for frame in 1000:
		var movement := Vector2(sin(frame * .01), -.2)
		old_legacy.tick(a, movement, .016)
		L.tick(b, movement, .016)
		identical = identical and C.equivalent(a, b)
	check(identical, "legacy complete saved-state meaning remains identical through 1000 ticks")

func input_boundaries() -> void:
	root.size = Vector2i(720, 1280)
	var app: Node = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var scene: Node = app.get_node("Battle")
	scene.set_physics_process(false)
	scene.begin()
	for size in [Vector2i(1080, 2400), Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1100, 1400), Vector2i(1600, 1000), Vector2i(2560, 1440)]:
		root.size = size
		await process_frame
		scene.layout()
		var safe: Rect2 = scene.safe_rect
		var contained := safe.encloses(scene.start_button.get_global_rect())
		for button in scene.action_buttons:
			contained = contained and safe.encloses(button.get_global_rect()) and button.size.y >= 96
		check(contained, "adaptive controls remain inside usable safe layout " + str(size))
		var transform: Transform2D = root.get_final_transform()
		var logical := safe.position + Vector2(100, 650)
		check((transform.affine_inverse() * (transform * logical)).distance_to(logical) < .001, "viewport inverse input transform round trip " + str(size))
		for modal in [scene.menu, scene.terminal, scene.transfer, scene.journey, scene.confirm_panel, scene.ending_panel]:
			check(safe.grow(.1).encloses(modal.get_global_rect()), "modal fits safe rect " + str(size) + " " + modal.name)
		await exercise_pointer(scene)
	var before: Dictionary = scene.state.duplicate(true)
	scene.toggle_pause()
	scene._physics_process(.05)
	check(C.equivalent(scene.state, before), "actual app pause holds complete state")
	scene.open_journey()
	scene.back()
	check(not scene.journey.visible and scene.menu.visible and scene.paused, "Back closes Journey then returns held watch")
	scene.open_transfer()
	var whole: Dictionary = scene.state.duplicate(true)
	scene.code_edit.text = "invalid"
	scene.import_code()
	check(scene.state == whole and scene.notice.text.contains("Invalid"), "invalid transfer keeps complete memory")
	scene.back()
	check(not scene.transfer.visible and scene.paused, "Back closes transfer before changing held battle")
	scene.retry()
	scene.sync_world(0)
	check(scene.state.time == 0 and scene.presenter.adapter.current == scene.presenter.adapter.previous and scene.presenter.effects.is_empty(), "actual Retry clears presentation and restocks the pinned definition")
	app.queue_free()
	await process_frame

func exercise_pointer(scene: Node) -> void:
	var start: Vector2 = C.position(scene.state)
	var origin: Vector2 = scene.safe_rect.position + Vector2(100, 650)
	var press := InputEventScreenTouch.new()
	press.index = 6
	press.position = root.get_final_transform() * origin
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 6
	drag.position = root.get_final_transform() * (origin + Vector2(65, 0))
	Input.parse_input_event(drag)
	await process_frame
	scene._physics_process(.05)
	print("INPUT_ADAPTIVE actual=", C.position(scene.state), " before=", start, " vector=", scene.input_vector, " held=", scene.paused, " safe=", scene.safe_rect, " logical=", root.get_visible_rect())
	check(is_equal_approx(scene.state.x - start.x, .24) and is_equal_approx(scene.state.z, start.y), "actual ScreenTouch/drag moves exact unchanged rule distance through adaptive input")
	press.pressed = false
	Input.parse_input_event(press)
	await process_frame
	check(scene.input_vector == Vector2.ZERO and scene.stick_id == -1, "actual pointer release stops movement")

func legacy_boundaries() -> void:
	# Synthetic fresh unit fixture only. Actual earned code1/2 native update and
	# historical legacy passage remain coordinator-owned, separately bound evidence.
	var state := L.fresh()
	var profile := L.profile()
	var settings := {"sound": false, "reduced_effects": true}
	check(S.write(state, profile, settings), "isolated fresh legacy unit fixture writes checked envelope")
	root.size = Vector2i(720, 1280)
	var app: Node = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var scene: Node = app.get_node("Battle")
	scene.set_physics_process(false)
	check(scene.state.schema == 1 and C.equivalent(scene.state, state) and scene.settings == settings, "normal bootstrap loads entire legacy fixture and settings into new presentation")
	check(scene.presenter.campaign == false and scene.presenter.pad_labels[0].text == "5 GOLD" and scene.presenter.pad_labels[1].text == "15 GOLD", "legacy retains both exact priced pads")
	scene.begin()
	var before: Dictionary = scene.state.duplicate(true)
	scene.toggle_pause()
	scene._physics_process(.05)
	check(C.equivalent(scene.state, before), "legacy pause still holds complete state")
	scene.open_campaign()
	await process_frame
	await process_frame
	scene = app.get_node("Battle")
	scene.set_physics_process(false)
	check(scene.state.schema == 2 and C.equivalent(scene.campaign_profile.legacy_snapshot, before) and C.equivalent(scene.profile, profile) and scene.settings == settings, "legacy-to-campaign routing parks every original field and preserves settings without invented clears")
	app.queue_free()
	await process_frame
