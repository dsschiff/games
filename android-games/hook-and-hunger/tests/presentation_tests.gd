extends SceneTree
## Synthetic invariant fixtures only. These checks establish no earned passage,
## visual quality, real display fit, native Android input or frame performance.
const Adapter = preload("res://scripts/presentation/adapter.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Kit = preload("res://scripts/presentation/kit.gd")
const E = preload("res://scripts/engine.gd")
const C = preload("res://scripts/campaign_rules.gd")
const P = preload("res://tests/campaign_policy.gd")
var checks := 0
var failures := 0
var rows: Array[Dictionary] = []
var capture_dir := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(okay: bool, text: String) -> void:
	checks += 1
	rows.append({"passed": okay, "text": text})
	if not okay:
		failures += 1
		push_error(text)

func run() -> void:
	check(DisplayServer.get_name() == "headless", "CPU-only display")
	await asset_checks()
	for stage in range(-1, 12):
		await map_checks(stage)
	await event_pool_checks()
	await owner_checks()
	var output := {"checks": checks, "failures": failures, "details": rows, "scope": "CPU import/skin/socket/scenery/immutable-state/event/pool fixtures; no graphics acceptance or earned progression"}
	if not capture_dir.is_empty():
		FileAccess.open(capture_dir.path_join("presentation-report.json"), FileAccess.WRITE).store_string(JSON.stringify(output, "  "))
	print("PRESENTATION_CHECKS: ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func asset_checks() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/manifest.json"))
	check(manifest.assets.size() == 35, "35 original asset records")
	var kit := Kit.new()
	for record in manifest.assets:
		var asset: Node3D = kit.asset(str(record.name))
		root.add_child(asset)
		var meshes := asset.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), "real imported mesh " + str(record.name))
		if str(record.name).begins_with("actor_"):
			var rig := Kit.skeleton(asset)
			check(rig != null and rig.get_bone_count() == 18, "18 imported joints " + str(record.name))
			var skinned := 0
			for mesh in meshes:
				if mesh.skin != null:
					skinned += 1
			check(skinned > 0, "real imported skin " + str(record.name))
			var players := asset.find_children("*", "AnimationPlayer", true, false)
			check(players.size() == 1 and players[0].get_animation_list().size() > 0, "authored animation imports " + str(record.name))
		asset.free()
	kit.clear()
	var actor := Actor.new()
	root.add_child(actor)
	actor.configure("diver", kit)
	actor.capture({"x": 0, "z": 0, "hp": 100}, {"hp": 100}, true, 0)
	actor.pose(0, "playing")
	var idle := actor.sync_socket()
	actor.pose(0, "playing", .18, Vector3(0, 0, -3))
	var swung := actor.sync_socket()
	var expected: Vector3 = actor.rig.global_transform * actor.rig.get_bone_global_pose(actor.bones.ChainSocket).origin
	check(swung.distance_to(expected) < .00001, "same-call BoneAttachment samples current rig global pose")
	check(swung.distance_to(idle) > .1, "hand socket moves with actual articulated swing")
	actor.velocity = Vector3(0, 0, -4)
	actor.pose(.05, "playing")
	check(actor.rig.get_bone_pose_rotation(actor.bones.ThighL) != Quaternion.IDENTITY and actor.rig.get_bone_pose_rotation(actor.bones.ShinR) != Quaternion.IDENTITY, "walking articulates thigh and knee")
	actor.hit_left = .20
	actor.pose(0, "playing")
	check(actor.rig.get_bone_pose_rotation(actor.bones.Torso) != Quaternion.IDENTITY, "hit has articulated response")
	actor.fall()
	actor.pose(.40, "playing")
	check(absf(actor.model.rotation.x) > .8, "fall is a modeled collapse")
	actor.reset_for_reuse()
	check(actor.fall_time == -1 and actor.gait == 0 and actor.travel == 0 and actor.hit_left == 0 and actor.snapshot.is_empty() and actor.identity.is_empty(), "reuse clears all actor cursors")
	check(actor.transform == Transform3D.IDENTITY and actor.model.transform == actor.model_rest and not actor.warning.visible and not actor.health_root.visible, "reuse resets model/health/warning transforms")
	actor.free()
	for role in ["skitter", "lancer", "spitter", "shield", "charger", "tender", "bellkeeper", "warden", "kiln", "twin_sun", "twin_moon", "crown"]:
		actor = Actor.new()
		root.add_child(actor)
		actor.configure(role, kit)
		var spec := {"hp": 100, "wind": 1, "recovery": 2}
		var data := {"x": 1, "z": -3, "hp": 100, "facing": 0, "mode": "wind", "attack": "slam", "clock": .15}
		actor.capture(data, spec, true, 0)
		actor.pose(.1, "playing")
		var wind: Quaternion = actor.rig.get_bone_pose_rotation(actor.bones.ArmR)
		data.mode = "recover"
		data.clock = 1.8
		actor.capture(data, spec, false, .1)
		actor.pose(.1, "playing")
		check(wind != actor.rig.get_bone_pose_rotation(actor.bones.ArmR), "wind and impact/recoil use distinct limb poses " + role)
		actor.fall()
		actor.pose(.5, "playing")
		check(actor.model.rotation.x < -1, "authored creature collapse " + role)
		actor.reset_for_reuse()
		check(actor.model.transform == actor.model_rest and actor.fall_time == -1 and actor.snapshot.is_empty(), "all role poses reset " + role)
		actor.free()
	kit.clear()

func map_checks(stage: int) -> void:
	var s: Dictionary = E.fresh() if stage < 0 else C.fresh(stage, 1 if stage < 3 else (2 if stage < 6 else 3), 1200)
	if stage >= 0 and C.cost(s) > 0:
		C.purchase(s)
	var untouched := s.duplicate(true)
	var view := Adapter.new()
	root.add_child(view)
	view.build(s)
	check(s == untouched, "building presentation retains full state " + str(stage))
	check(view.island.scenic.size() >= 19, "complete tropical composition " + str(stage))
	var clear := true
	for node in view.island.scenic:
		clear = clear and not Kit.bounds(node, view).intersects(view.island.clearance)
	check(clear, "whole transformed scenic bounds outside actors " + str(stage))
	var baseline := s.duplicate(true)
	var equivalent := true
	var immutable := true
	for frame in 360:
		var move := Vector2(0, -1) if stage < 0 else P.direction(s)
		E.step(s, move, 1.0 / 60)
		E.step(baseline, move, 1.0 / 60)
		var before := s.duplicate(true)
		view.capture(s)
		view.present(1.0 / 60)
		immutable = immutable and before == s
		equivalent = equivalent and baseline == s
	check(equivalent, "360 whole-state rule steps identical with presentation " + str(stage))
	check(immutable, "snapshot/event/pose never writes state " + str(stage))
	var copied: float = view.snapshot.x
	s.x += .1
	check(view.snapshot.x == copied, "presentation snapshot never aliases rule dictionary " + str(stage))
	view.free()
	await process_frame

func event_pool_checks() -> void:
	var s := C.fresh(11, 3, 0)
	var view := Adapter.new()
	root.add_child(view)
	view.build(s)
	# Explicitly synthetic contact fixture for observer boundaries.
	s.strike = .36
	s.contact = false
	s.time += .016
	view.capture(s)
	s.strike = .18
	s.strike_x = 0
	s.strike_z = 3.0
	s.contact = true
	s.enemies[0].hp -= 1
	s.enemies[0].flash = .16
	s.time += .18
	view.capture(s)
	view.present(0)
	var serial: int = view.serial
	for i in 5:
		view.capture(s)
		view.present(0)
	check(view.event_counts.get("contact") == 1 and view.serial == serial, "contact is grouped once across repeated render/sync calls")
	check(view.weapon_tips[3].global_position.distance_to(Vector3(0, .8, 3)) < .00001, "weapon reaches actual rule contact point at half swing")
	var hand: Vector3 = view.player.sync_socket()
	check(view.links[0].position.distance_to(hand) < .00001 and view.links[-1].position.distance_to(view.weapon_eyes[3].global_position) < .00001, "chain joins current hand and actual weapon")
	var before_ending := s.duplicate(true)
	var boat_before: Vector3 = view.island.fleet[0].position
	s.phase = "victory"
	s.time += .016
	view.capture(s)
	view.present(.5)
	check(view.island.beacon_lights.all(func(light: Node3D) -> bool: return light.visible), "four dimensional harbor beacon lights mark the ending")
	check(view.island.fleet[0].position.distance_to(boat_before) > .1, "harbor fleet sails on presentation time after rule victory")
	s = before_ending
	view.hydrate(s)
	check(view.island.ending_clock == 0 and view.island.fleet[0].position == boat_before, "hydrate resets harbor motion independently of saved progress")
	var first_id := int(C.active(s)[0].id)
	var original: Node3D = view.actors[first_id]
	var identity := original.get_instance_id()
	original.hit_left = 1
	original.fall()
	original.pose(.3, "playing")
	view.hydrate(s)
	var reused := false
	var reset := true
	for actor in view.actors.values():
		reused = reused or actor.get_instance_id() == identity
		reset = reset and actor.fall_time == -1 and actor.hit_left == 0 and actor.gait == 0 and actor.model.transform == actor.model_rest
	check(reused and reset, "hydrate reuses compatible actor instances with clean bones/pose/cursors")
	check(view.serial == 0 and view.events.is_empty() and view.effects.is_empty(), "hydrate clears effects and event cursors without replay")
	check(view.pool.count <= view.pool.total, "inactive reserve is bounded")
	var epoch: int = view.epoch
	view.set_paused(true, s)
	view.present(.5)
	check(view.epoch == epoch + 1 and view.frozen and view.serial == 0, "pause starts a clean observation epoch")
	view.set_paused(false, s)
	check(view.serial == 0 and view.events.is_empty(), "resume does not replay contact from restored snapshot")
	view.reduced = true
	s.time += .016
	s.contact = false
	s.strike = .36
	view.capture(s)
	s.time += .18
	s.contact = true
	s.strike = .18
	view.capture(s)
	view.present(0)
	check(view.effects.is_empty() and view.links[0].visible and view.reach.visible, "reduced effects retains essential chain/reach without optional impact")
	var key := "drop:salvage"
	var drop: Node3D = view._object(key, "salvage")
	var drop_id := drop.get_instance_id()
	drop.position = Vector3(50, 8, 4)
	drop.scale = Vector3.ONE * 7
	view._release(drop)
	drop = view._object(key, "salvage")
	check(drop.get_instance_id() == drop_id and drop.transform == Transform3D.IDENTITY, "salvage compatible pool resets transforms and preserves identity")
	view._release(drop)
	for i in 90:
		var node: Node3D = view._object("stress:" + str(i), "salvage")
		view._release(node)
	check(view.pool.count <= 64, "many role keys cannot grow reserve beyond global bound")
	view.free()
	await process_frame

func owner_checks() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var first := Adapter.new()
	var second := Adapter.new()
	root.add_child(first)
	viewport.add_child(second)
	first.build(E.fresh())
	second.build(E.fresh())
	var weak_first: WeakRef = weakref(first)
	var material_count: int = second.kit.materials.size()
	var resource: Material = second.kit.materials.values()[0]
	first.free()
	check(weak_first.get_ref() == null, "owner adapter frees completely")
	check(second.kit.materials.size() == material_count and is_instance_valid(resource), "freeing one viewport does not clear another owner's materials")
	second.present(.016)
	check(second.actors.size() == 8 and second.player.rig.get_bone_count() == 18, "other viewport remains functional after first teardown")
	viewport.free()
	await process_frame
