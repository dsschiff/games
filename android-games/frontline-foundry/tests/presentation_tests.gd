extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
const R = preload("res://scripts/rules.gd")
const A = preload("res://scripts/presentation/adapter.gd")
const V = preload("res://scripts/presentation/outpost.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const P = preload("res://tests/policy.gd")
const S = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, description: String) -> void:
	checks += 1
	if not okay:
		failures += 1
		push_error(description)
	print("CHECK ", description, " ", "PASS" if okay else "FAIL")

func run() -> void:
	var s := C.fresh(D.mission(0))
	var original := s.duplicate(true)
	var adapter := A.new()
	adapter.reset(s, false)
	s.x = 1.0
	check(adapter.current.commander.position.x == 0, "snapshot owns immutable values")
	s = original.duplicate(true)
	s.phase = "playing"
	adapter.reset(s, false)
	s.time = .05
	s.x = .19
	adapter.ingest(s, false, .05)
	check(adapter.advance(.025) > .49 and adapter.advance(0) < .51, "interpolation uses independent render time")
	var event := {"kind": "shot", "actor": "recruit:9", "attack": "recruit:9:1", "enemy": 1}
	check(adapter.accept(event) and not adapter.accept(event), "same attack impact is delivered once")
	event.enemy = 2
	check(adapter.accept(event), "one attack can have a second target impact")
	for i in 800:
		adapter.accept({"kind": "pickup", "id": i, "attack": str(i)})
	check(adapter.seen.size() <= 512, "dedupe memory is bounded")
	var epoch: int = adapter.epoch
	adapter.ingest(s, true, 0)
	check(adapter.epoch == epoch + 1 and adapter.seen.is_empty(), "pause clears transient cursors and interpolation")
	var held: float = adapter.elapsed
	adapter.advance(20)
	check(adapter.elapsed == held, "paused presentation time freezes")
	s.time = 0
	adapter.ingest(s, false, 0)
	check(adapter.current.commander.position == adapter.previous.commander.position, "reused IDs hydrate without travel after retry/load")
	var view := V.new()
	root.add_child(view)
	view.build(original)
	view.set_process(false)
	check(view.units.size() == 13, "real imported actor interface covers commander and twelve finite recruits")
	var actor: Node3D = view.units.commander
	check(actor.rig != null and actor.rig.get_bone_count() >= 16, "GLB imports a real jointed skeleton")
	check(actor.bones.has("ThighL") and actor.bones.has("ShinR") and actor.bones.has("Weapon"), "leg joints and weapon attachment survive import")
	var meshes := find_meshes(actor.model)
	var weighted := 0
	var vertex_count := 0
	for n in meshes:
		if n.skin != null:
			weighted += 1
		for i in n.mesh.get_surface_count():
			vertex_count += n.mesh.surface_get_array_len(i)
	check(weighted == 7 and vertex_count > 1000, "seven consolidated sculpted material surfaces retain skin bindings")
	actor.pose(.07, Vector3(0, 0, -3.8), false)
	check(not actor.rig.get_bone_pose_rotation(actor.bones.ThighL).is_equal_approx(Quaternion.IDENTITY), "travel rotates articulated thigh")
	check(not actor.rig.get_bone_pose_rotation(actor.bones.ShinR).is_equal_approx(Quaternion.IDENTITY), "travel bends a knee")
	actor.fire(Vector3(0, 0, -5))
	actor.pose(.05, Vector3.ZERO, false)
	check(actor.fire_left > 0 and not actor.rig.get_bone_pose_rotation(actor.bones.Weapon).is_equal_approx(Quaternion.IDENTITY), "real shot drives weapon recoil pose")
	actor.hit()
	actor.pose(.05, Vector3.ZERO, false)
	check(actor.hit_left > 0, "damage has a local reaction timer")
	actor.pose(.05, Vector3.ZERO, true)
	check(absf(actor.rig.get_bone_pose_rotation(actor.bones.UpperArmL).get_euler().z) > 1, "victory raises an articulated arm")
	actor.rig.force_update_all_bone_transforms()
	check(actor.muzzle.get_parent() is BoneAttachment3D and actor.muzzle.get_parent().bone_name == "PrimaryMuzzle" and actor.rig.get_bone_global_rest(actor.bones.PrimaryMuzzle).origin.z < -.55, "authored primary muzzle bone follows the actual weapon tip")
	actor.fire(Vector3(5, 0, -2))
	actor.pose(0, Vector3.ZERO, false)
	actor.rig.force_update_all_bone_transforms()
	var current_tip: Vector3 = actor.rig.to_global(actor.rig.get_bone_global_pose(actor.bones.PrimaryMuzzle).origin)
	var same_call_gap: float = actor.socket_position().distance_to(current_tip)
	print("SAME_CALL_BONE_ATTACHMENT_GAP ", same_call_gap)
	check(same_call_gap < .00001, "same-call turned shot marker matches current weapon bone tip without a process-frame delay")
	# Geometry fixture: hull keeps traveling forward while the turret aims sideways.
	var rover := Actor.new()
	root.add_child(rover)
	rover.configure("rover", "ally", 0)
	var barrel_bounds := (rover.barrel as MeshInstance3D).mesh.get_aabb()
	var barrel_tip := Vector3(barrel_bounds.get_center().x, barrel_bounds.position.y - .015, barrel_bounds.get_center().z)
	rover.fire(Vector3(5, 0, 0))
	rover.pose(0, Vector3.FORWARD, false)
	var sideways: Vector3 = rover.muzzle.global_position
	var aimed_tip: Vector3 = rover.barrel.to_global(barrel_tip)
	rover.pose(.16, Vector3.FORWARD, false)
	var recoiled: Vector3 = rover.muzzle.global_position
	check(rover.muzzle.get_parent() == rover.barrel and sideways.distance_to(aimed_tip) < .00001 and sideways.x > .9 and absf(sideways.z - .14) < .001 and recoiled.distance_to(rover.barrel.to_global(barrel_tip)) < .00001 and recoiled.x < sideways.x - .05 and absf(rover.rotation.y) < .001, "sideways vehicle socket stays at animated barrel tip through turret aim and recoil while hull faces forward")
	print("VEHICLE_SOCKET_GEOMETRY ", JSON.stringify({"sideways": [sideways.x, sideways.y, sideways.z], "recoiled": [recoiled.x, recoiled.y, recoiled.z], "hull_yaw": rover.rotation.y}))
	rover.queue_free()
	var role_models := {}
	for role in ["runner", "breaker", "ranger", "bulwark", "mortar", "jammer", "sapper", "drill", "carrier", "storm"]:
		var specialist := Actor.new()
		root.add_child(specialist)
		specialist.configure(role, "enemy", 0)
		role_models[role] = specialist.model.scene_file_path
		if role == "ranger":
			var front := weapon_front(specialist)
			var tip: Vector3 = specialist.rig.get_bone_global_rest(specialist.bones.PrimaryMuzzle).origin
			print("RANGER_VISIBLE_TIP ", front, " socket ", tip, " gap ", tip.distance_to(front))
			check(tip.distance_to(front) < .01 and front.z < -1.1, "Ranger socket touches actual Weapon-weighted visible long-rifle cap geometry")
			var cap_local: Vector3 = specialist.rig.get_bone_global_rest(specialist.bones.Weapon).affine_inverse() * front
			var aimed_cap := true
			for target in [Vector3(5, 0, -2), Vector3(-3, 0, -5), Vector3(0, 0, -5)]:
				specialist.fire(target)
				specialist.pose(.05, Vector3.ZERO, false)
				var socket: Vector3 = specialist.socket_position()
				var skinned_cap: Vector3 = specialist.rig.to_global(specialist.rig.get_bone_global_pose(specialist.bones.Weapon) * cap_local)
				aimed_cap = aimed_cap and socket.distance_to(skinned_cap) < .01
			check(aimed_cap, "same-call Ranger socket follows actual skinned barrel cap through three aim/recoil poses")
		if specialist.rig != null:
			specialist.rig.force_update_all_bone_transforms()
			check(specialist.bones.has("PrimaryMuzzle") and specialist.muzzle.get_parent().bone_name == "PrimaryMuzzle", "specialist " + role + " retains authored articulated weapon tip")
		else:
			check(specialist.turret != null and specialist.barrel != null and specialist.wheels.size() == 6, "boss " + role + " imports articulated turret, barrel and six animated wheels")
		specialist.queue_free()
	check(role_models.values().size() == 10 and role_models.values().all(func(path): return role_models.values().count(path) == 1), "ten specialists use distinct authored model resources")
	var landmarks := {}
	for index in 12:
		var district := C.fresh(D.mission(index))
		var before_district := district.duplicate(true)
		var region: Dictionary = preload("res://scripts/presentation/regions.gd").describe(district)
		landmarks[region.landmark] = true
		check(FileAccess.file_exists("res://art/models/" + region.landmark + ".glb") and D.same(district, before_district), "district %d regional art resolves without editing its definition or state" % (index + 1))
		var world := V.new()
		root.add_child(world)
		world.build(district)
		world.set_process(false)
		var clear := true
		var count := 0
		for node in world.get_children():
			if not node is Node3D or not node.has_meta("regional_placement"):
				continue
			var bounds := V.geometry_bounds(node)
			clear = clear and (bounds.position.x >= 4.975 or bounds.end.x <= -4.975 or bounds.end.z <= -6.475)
			count += 1
		check(clear and count >= 3, "all %d actual transformed regional placements clear commander center bounds plus .275 body radius in district %d" % [count, index + 1])
		world.queue_free()
		await process_frame
	check(landmarks.size() == 12, "all twelve districts have a distinct authored landmark")
	for style in ["mixed", "flank", "siege"]:
		var seeded := C.fresh(D.skirmish(137, style))
		var unchanged := seeded.duplicate(true)
		var world := V.new()
		root.add_child(world)
		world.build(seeded)
		world.set_process(false)
		var clear := true
		for node in world.get_children():
			if node is Node3D and node.has_meta("regional_placement"):
				var bounds := V.geometry_bounds(node)
				clear = clear and (bounds.position.x >= 4.975 or bounds.end.x <= -4.975 or bounds.end.z <= -6.475)
		check(clear and D.same(seeded, unchanged), "seeded " + style + " scenery clears complete transformed bounds without definition/state changes")
		world.queue_free()
		await process_frame
	var before: String = JSON.stringify(original)
	for i in 120:
		view.sync(original, true, true, 0)
	check(JSON.stringify(original) == before, "presentation never mutates full gameplay state")
	check(view.effects.is_empty() and view.pending.is_empty(), "loaded/paused hydration has no phantom attacks")
	# Same event batch twice, one splash attack, two victims: one recoil/tracer.
	var playing := original.duplicate(true)
	playing.phase = "playing"
	view.sync(playing, false, false, 0)
	var splash := [{"kind": "shot", "owner": "rover", "actor": "recruit:9", "attack": "recruit:9:12", "enemy": 0, "damage": 10, "from": [0, 0], "to": [0, -3]}, {"kind": "shot", "owner": "rover", "actor": "recruit:9", "attack": "recruit:9:12", "enemy": 1, "damage": 6, "from": [0, 0], "to": [1, -3]}]
	view.queue_events(splash)
	view.queue_events(splash)
	view.sync(playing, false, false, .05)
	check(view.attacks_emitted == 1 and view.effects.size() == 1, "multi-target duplicate batch yields one weapon attack")
	view.sync(playing, true, false, 0)
	check(view.effects.is_empty() and view.attacks_seen.is_empty(), "pause discards pending trails and recoil")
	var resumed := C.fresh(D.mission(0))
	resumed.phase = "playing"
	resumed.time = 2.0
	resumed.x = -3.5
	resumed.z = -3.0
	view.sync(resumed, true, false, 0)
	var before_attacks: int = view.attacks_emitted
	var earned := C.tick(resumed, Vector2.ZERO, .05)
	view.queue_events(earned)
	view.sync(resumed, false, false, .05)
	check(view.attacks_emitted > before_attacks and view.units.commander.fire_left > 0, "actual tick-queue-sync first resume preserves newly earned attacks")
	var hydrated := C.fresh(D.mission(0))
	hydrated.recruits[1].phase = "equipping"
	hydrated.recruits[1].clock = .4
	hydrated.recruits[2].phase = "fallen"
	hydrated.recruits[2].hp = 0
	view.sync(hydrated, true, false, 0)
	var waiting: Node3D = view.units["recruit:0"]
	var arming: Node3D = view.units["recruit:1"]
	var fallen: Node3D = view.units["recruit:2"]
	check(waiting.rig.get_bone_pose_scale(waiting.bones.Weapon).x < .01 and arming.rig.get_bone_pose_scale(arming.bones.Weapon).x < .01, "paused load immediately hides unearned waiting/equipping weapons")
	check(fallen.death_time >= 1.0 and absf(fallen.model.rotation.x) > 1, "paused load immediately settles fallen pose without replay")
	var terminal_state := C.fresh(D.mission(0))
	terminal_state.phase = "playing"
	terminal_state.time = .1
	view.sync(terminal_state, false, false, .05)
	terminal_state.time = .15
	terminal_state.z -= .19
	terminal_state.phase = "victory"
	view.sync(terminal_state, false, false, .05)
	var gait: float = view.units.commander.gait
	for i in 60:
		view._process(1.0 / 60)
	check(view.units.commander.gait == gait, "moving-to-terminal transition stops gait while victory pose remains")
	view.clear_transients()
	for effect in ["ground", "contact", "blast", "breach"]:
		view.queue_events([{"kind": "incoming", "actor": "enemy:20", "attack": effect + ":15", "effect": effect, "recipient": -1, "from": [0, -4], "to": [0, 1], "damage": 5}])
	view.queue_events([{"kind": "incoming", "actor": "enemy:20", "attack": "hq:15", "effect": "breach", "recipient": -2, "from": [0, 2], "to": [0, 5.4], "damage": 5}, {"kind": "repair", "actor": "enemy:21", "attack": "repair:15", "enemy": 20, "from": [0, -4], "to": [1, -4], "healed": 5}])
	view.sync(terminal_state, false, true, 0)
	check(view.routed.ground == 1 and view.routed.contact == 1 and view.routed.blast == 1 and view.routed.breach == 2 and view.routed.hq == 1 and view.routed.repair == 1, "ground/contact/blast/breach/HQ/repair events take separate visual routes")
	check(view.sentry != null and view.hq_hit_left > 0, "autonomous sentry is modeled and HQ damage responds locally")
	var warning := C.fresh(D.mission(11))
	warning.marks.append({"x": 1.0, "z": -2.0, "source": 20, "remaining": 1.0})
	view.sync(warning, true, true, 0)
	var marker_id: int = view.warnings.values()[0].get_instance_id()
	for i in 80:
		view.sync(warning, true, true, 0)
	check(view.warnings.size() == 1 and view.warnings.values()[0].get_instance_id() == marker_id, "essential warning survives reduced effects and stays keyed while paused")
	warning.enemies.append({"id": 30, "role": "drill", "hp": 620, "x": -2.0, "z": -4.0, "telegraph": 1.1})
	view.sync(warning, true, true, 0)
	check(view.warnings.has("drill:30") and view.warnings["drill:30"].position.is_equal_approx(Vector3(-2, .08, -2.2)), "drill warning covers exact two-meter destination area during real telegraph")
	view.queue_free()
	await process_frame
	# Both actual boot paths must instantiate with valid saved state.
	for state in [R.fresh(), original]:
		check(S.write(state, R.profile(), {"sound": false, "reduced_effects": false}, S.PATH, null, true, C.career()), "write isolated original catalog save " + str(state.catalog))
		var boot: Node = load("res://boot.tscn").instantiate()
		root.add_child(boot)
		await process_frame
		check(boot.session.state.catalog == state.catalog and boot.session.presentation.units.has("commander"), "real boot retains catalog and hydrated renderer " + str(state.catalog))
		if state.catalog == 2:
			await input_layout_checks(boot.session)
		boot.queue_free()
		await process_frame
	await camera_checks()
	baseline_replay()
	print("FRONTLINE_PRESENTATION checks=", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func camera_checks() -> void:
	# Follow camera keeps the commander inside the usable play region on every
	# fold profile (logical sizes after canvas_items/expand stretch), and wider
	# windows reveal more world width instead of stretching the art.
	var s := C.fresh(D.mission(11))
	s.phase = "playing"
	var world := V.new()
	root.add_child(world)
	world.build(s)
	world.set_process(false)
	var widths := {}
	var framed := true
	var original_size := root.size
	for logical in [Vector2(720, 1680), Vector2(1153, 1280), Vector2(720, 1600), Vector2(720, 1280)]:
		root.size = Vector2i(logical)
		await process_frame
		world.fit(root.get_visible_rect().size)
		widths[logical] = world.visible_half_width()
		for corner in [Vector2(-4.7, -6.2), Vector2(4.7, -6.2), Vector2(-4.7, 5.9), Vector2(4.7, 5.9), Vector2(0, 1.5)]:
			world.units.commander.position = Vector3(corner.x, 0, corner.y)
			world.update_camera(0, true)
			var screen: Vector2 = world.camera.unproject_position(world.units.commander.position + Vector3(0, .7, 0))
			var inside: bool = screen.x > 0 and screen.x < logical.x and screen.y > world.safe_top and screen.y < logical.y - world.safe_bottom + 60
			if not inside:
				print("CAMERA_FRAMING_MISS ", logical, " ", corner, " ", screen)
			framed = framed and inside
	check(framed, "follow camera keeps the commander inside the usable play region on cover, inner, native and baseline profiles")
	check(widths[Vector2(1153, 1280)] > widths[Vector2(720, 1280)] * 1.5 and is_equal_approx(widths[Vector2(720, 1680)], widths[Vector2(720, 1280)]), "inner fold reveals wider world; tall cover keeps baseline world width")
	root.size = original_size
	await process_frame
	world.fit(root.get_visible_rect().size)
	var threat := s.duplicate(true)
	threat.x = 1.0
	threat.z = -6.0
	threat.time = 1.0
	threat.spawned = 2
	threat.enemies.append({"id": 0, "role": "sapper", "hp": 40, "x": 2.0, "z": 5.6, "telegraph": 0.0})
	threat.enemies.append({"id": 1, "role": "runner", "hp": 40, "x": 0.5, "z": -5.4, "telegraph": 0.0})
	world.sync(threat, false, true, 0)
	world.update_camera(0, true)
	world.update_cues()
	var below := 0
	for mark in world.cues.marks:
		if mark.direction.y > .5 and mark.point.y >= root.get_visible_rect().size.y - world.safe_bottom - 19:
			below += 1
	check(world.cues.marks.size() == 1 and below == 1, "off-screen sapper behind the controls gets one edge cue; on-screen runner gets none")
	check(world.cues.marks[0].color.a == 1.0, "reduced effects holds edge cues steady without pulsing")
	world.sync(threat, true, true, 0)
	world.update_cues()
	check(world.cues.marks.is_empty(), "paused presentation draws no edge cues")
	var perimeter := 0
	var clear := true
	for node in world.scenery:
		perimeter += 1
		var bounds := V.geometry_bounds(node)
		clear = clear and node.has_meta("regional_placement") and (bounds.position.x >= 4.975 or bounds.end.x <= -4.975 or bounds.end.z <= -6.475)
	check(perimeter >= 40 and clear, "%d perimeter boulders, trees and barriers frame the field outside commander bounds" % perimeter)
	world.queue_free()
	await process_frame

func find_meshes(node: Node) -> Array:
	var result: Array = [node] if node is MeshInstance3D else []
	for child in node.get_children():
		result.append_array(find_meshes(child))
	return result

func weapon_front(actor: Node3D) -> Vector3:
	var nearest := INF
	var front: Array[Vector3] = []
	for node in find_meshes(actor.model):
		if node.skin == null:
			continue
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for vertex in vertices.size():
				var weapon := false
				for influence in 4:
					var bind: int = indices[vertex * 4 + influence]
					var bone: int = node.skin.get_bind_bone(bind)
					if bone < 0:
						bone = actor.rig.find_bone(node.skin.get_bind_name(bind))
					if weights[vertex * 4 + influence] > .99 and bone == actor.bones.Weapon:
						weapon = true
				if not weapon:
					continue
				var point: Vector3 = actor.rig.to_local(node.to_global(vertices[vertex]))
				if point.z < nearest - .00001:
					nearest = point.z
					front = [point]
				elif absf(point.z - nearest) < .00001:
					front.append(point)
	var center := Vector3.ZERO
	for point in front:
		center += point
	return center / maxf(1, front.size())

func tap(point: Vector2, index: int = 2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.position = root.get_final_transform() * point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await process_frame

func input_layout_checks(scene: Node) -> void:
	await process_frame
	var support_rect: Rect2 = scene.briefing.get_children().filter(func(node): return node is Button)[0].get_global_rect()
	check(scene.brief_scroll.get_global_rect().end.y < support_rect.position.y and scene.brief_forecast.autowrap_mode != TextServer.AUTOWRAP_OFF and scene.brief_rules.get_parent() is VBoxContainer, "briefing prose uses a wrapping scroll body separated from fixed support action")
	await tap(scene.start_button.get_global_rect().get_center())
	check(scene.state.phase == "playing" and not scene.paused, "real Launch GUI input enters unchanged campaign")
	await tap(scene.pause_button.get_global_rect().get_center())
	check(scene.paused, "real Pause GUI input holds campaign for resize")
	for dimensions in [Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1080, 2400), Vector2i(1280, 720), Vector2i(900, 1100)]:
		var before: Dictionary = scene.state.duplicate(true)
		root.size = dimensions
		await process_frame
		await process_frame
		check(D.same(scene.state, before), "whole paused state survives viewport " + str(dimensions))
		var viewport := root.get_visible_rect().size
		check(scene.pause_button.get_global_rect().end.x <= viewport.x and scene.build_button.get_global_rect().end.y <= viewport.y, "touch controls remain inside viewport " + str(dimensions))
		var resume: Button
		for button in scene.menu.get_children():
			if button is Button and button.text == "RESUME":
				resume = button
		await tap(resume.get_global_rect().get_center())
		var start_z: float = scene.state.z
		var origin := Vector2(110, viewport.y - 110)
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = root.get_final_transform() * origin
		press.pressed = true
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = root.get_final_transform() * (origin + Vector2(0, -45))
		Input.parse_input_event(drag)
		Input.flush_buffered_events()
		for i in 3:
			await physics_frame
		check(scene.state.z < start_z and scene.input_vector.y < -.6, "transformed actual joystick input moves commander after resize " + str(dimensions))
		press.pressed = false
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		await tap(scene.pause_button.get_global_rect().get_center())
		check(scene.paused and scene.input_vector == Vector2.ZERO, "actual pause clears stick input after resize " + str(dimensions))

func baseline_replay() -> void:
	var baseline_dir := "res://.artifacts/baseline/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-dir="):
			baseline_dir = arg.trim_prefix("--baseline-dir=")
	if not FileAccess.file_exists(baseline_dir + "campaign_rules.gd"):
		check(false, "baseline rule source required; extract original rules with git show")
		return
	var old: Script = load(baseline_dir + "campaign_rules.gd")
	for index in [0, 11]:
		var a: Dictionary = old.fresh(D.mission(index))
		var b := C.fresh(D.mission(index))
		a.phase = "playing"
		b.phase = "playing"
		var identical := true
		var count := 0
		for frame in 2400:
			var choice := P.decide(a)
			if choice.station >= 0 and old.can_buy(a, choice.station):
				old.buy(a, choice.station)
				C.buy(b, choice.station)
			var movement: Vector2 = (choice.goal - C.position(a)).limit_length()
			old.tick(a, movement, 1.0 / 60)
			var events := C.tick(b, movement, 1.0 / 60)
			for event in events:
				if event.kind in ["shot", "incoming"]:
					identical = identical and event.has("actor") and not event.actor.is_empty() and event.has("attack")
			identical = identical and D.same(a, b)
			count += 1
		check(identical, "baseline/new complete state equal each of %d ticks district %d; observational attack metadata present" % [count, index])
	var legacy: Script = load(baseline_dir + "rules.gd")
	var a: Dictionary = legacy.fresh()
	var b := R.fresh()
	a.phase = "playing"
	b.phase = "playing"
	var identical := true
	for i in 900:
		var movement := Vector2(sin(i * .01), -0.3)
		legacy.tick(a, movement, 1.0 / 60)
		R.tick(b, movement, 1.0 / 60)
		identical = identical and D.same(a, b)
	check(identical, "legacy complete state remains equal for identical 900-tick replay")
