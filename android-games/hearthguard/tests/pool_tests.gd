extends "res://tests/presentation_tests.gd"
## Focused synthetic presentation fixtures, not fabricated earned progression.
## No full campaign, renderer, clipboard or device execution.

func run() -> void:
	print("ISOLATED_USER_DATA ", OS.get_user_data_dir())
	for name in ["rules.gd", "campaign_rules.gd", "campaign_catalog.gd", "save_store.gd", "save_files.gd"]:
		check(FileAccess.get_file_as_string("res://scripts/" + name).replace("\r\n", "\n") == FileAccess.get_file_as_string(baseline + name).replace("\r\n", "\n"), "pooling preserves baseline rules/save source: " + name)
	var state := C.fresh(Cat.definition(0))
	state.phase = "playing"
	for tick in 220:
		C.tick(state, Vector2.ZERO, .05)
	check(not state.enemies.is_empty(), "bounded eleven-second rule fixture supplies actual stable enemy IDs")
	var view := V.new()
	root.add_child(view)
	view.set_process(false)
	view.build(state)
	var whole := state.duplicate(true)
	var enemy: Dictionary = state.enemies[0].duplicate(true)
	var key := "enemy:" + str(int(enemy.id))
	var actor: Node3D = view.units[key]
	var actor_id := actor.get_instance_id()
	actor.fire(Vector3(4, 0, 6))
	actor.update_health(1, 6, false)
	actor.pose(.15, Vector3(2, 0, 1), "playing")
	state.enemies.remove_at(0)
	state.killed.append(enemy.id)
	state.time += .05
	view.synchronize(state, false, .05)
	check(view.corpses.size() == 1 and view.corpses[0].node.get_instance_id() == actor_id and actor.death_time == 0, "real snapshot removal retains same actor for authored death interval")
	view.present(.86)
	check(view.corpses.is_empty() and actor.get_parent() == view.actor_pool.inactive and not actor.visible and not actor.is_queued_for_deletion(), "expired corpse is inactive and reusable rather than freed")
	check(actor.death_time < 0 and actor.gait == 0 and actor.shot_left == 0 and actor.hit_left == 0 and actor.travel == 0 and actor.hp == 1, "corpse return clears gait, contact/death, shot, hit, travel and health")
	state = whole.duplicate(true)
	state.time = 0
	view.synchronize(state, false, 0)
	check(view.units[key].get_instance_id() == actor_id, "Retry/load hydration actually reuses the expired role-matched instance")
	actor = view.units[key]
	check(actor.hp == enemy.hp and actor.max_hp == state.definition.roster[int(enemy.id)].hp and not actor.health_root.visible and actor.death_time < 0 and not actor.mounted, "reused stable ID receives current HP and no corpse, health-bar or mounted state")
	check(view.adapter.current == view.adapter.previous and view.effects.is_empty() and view.corpses.is_empty(), "Retry/load resets snapshot interpolation and transient lists with pools intact")
	# A contact animation is a separate lifetime and returns through the same pool.
	state.enemies.erase(state.enemies[0])
	state.leaked.append(enemy.id)
	state.time += .05
	view.synchronize(state, false, .05)
	check(view.corpses.size() == 1 and view.corpses[0].node.shot_left > 0, "leaked actor retains its observational contact animation")
	view.synchronize(state, true, 0)
	check(view.corpses.is_empty() and actor.get_parent() == view.actor_pool.inactive and actor.shot_left == 0 and actor.death_time < 0, "pause retires contact actor with no stale attack clock")
	var returned := view.take_actor(actor.role, .35)
	check(returned.get_instance_id() == actor_id, "contact-retired role instance is reused")
	view.return_actor(returned)
	# Deliberately dirty every class of pose/health/root state that used to persist.
	var defender := view.take_actor("defender", 1.0, true)
	var defender_id := defender.get_instance_id()
	defender.position = Vector3(5, 3, 4)
	defender.rotation = Vector3(.3, .8, .5)
	defender.scale = Vector3.ONE * .67
	defender.update_health(2, 40, false)
	defender.fire(Vector3(-4, 0, 1))
	defender.work_left = .6
	defender.pose(.15, Vector3(2, 0, -1), "playing")
	defender.fall()
	defender.pose(.2, Vector3.ZERO, "defeat")
	defender.rig.set_bone_pose_position(defender.bones.HandL, Vector3(1, 2, 3))
	defender.rig.set_bone_pose_scale(defender.bones.ForearmR, Vector3.ONE * .2)
	defender.health_root.position += Vector3.ONE
	defender.health.position += Vector3.ONE
	defender.muzzle.position = Vector3.ONE
	view.return_actor(defender)
	var fresh := Actor.new()
	root.add_child(fresh)
	fresh.configure("defender", .35)
	var reused := view.take_actor("defender", .35)
	check(reused.get_instance_id() == defender_id and reused.transform == Transform3D.IDENTITY and not reused.mounted, "mounted defender reuse restores root transform and handheld equipment mode")
	check(reused.model.transform.is_equal_approx(fresh.model.transform) and reused.health.transform.is_equal_approx(fresh.health.transform) and reused.health_root.transform.is_equal_approx(fresh.health_root.transform) and not reused.health_root.visible, "model and both health transforms match fresh authored instance")
	var all_bones := true
	for i in fresh.rig.get_bone_count():
		all_bones = all_bones and reused.rig.get_bone_pose(i).is_equal_approx(fresh.rig.get_bone_pose(i))
	check(all_bones and reused.socket_position().is_equal_approx(fresh.socket_position()), "every bone pose/scale/position and same-call visible weapon socket reset to fresh pose")
	check(reused.gait == .35 and reused.travel == 0 and reused.shot_left == 0 and reused.hit_left == 0 and reused.work_left == 0 and reused.death_time < 0 and reused.aim == Vector3.FORWARD and reused.hp == 1 and reused.max_hp == 1, "all reusable actor animation/health values reset")
	fresh.queue_free()
	view.return_actor(reused)
	# Pause→Resume must retain first tick's attack, even if its effect is pooled.
	state.towers[0].family = 0
	view.synchronize(state, true, 0)
	var attacks: int = view.attacks_emitted
	state.time += .05
	var shot := {"kind": "shot", "pad": 0, "family": 0, "x": 0.0, "z": 0.0, "area": 0.0}
	view.queue_events([shot, shot], state.time)
	view.synchronize(state, false, .05)
	check(view.attacks_emitted == attacks + 1 and view.effects.size() == 1, "pooled Resume preserves first shot and dedupes duplicate observation")
	var projectile: MeshInstance3D = view.effects[0].node
	var projectile_id := projectile.get_instance_id()
	var mesh_id := projectile.mesh.get_instance_id()
	var material_id := projectile.material_override.get_instance_id()
	projectile.scale = Vector3.ONE * 2
	projectile.rotation.z = .4
	view.present(1)
	check(not projectile.visible and projectile.transform == Transform3D.IDENTITY and projectile.mesh.size == Vector3.ONE and projectile.material_override.albedo_color == Color.WHITE, "projectile expiry resets transform, compatible mesh and material in inactive reserve")
	state.towers[0].family = 1
	state.time += .05
	view.queue_events([{"kind": "shot", "pad": 0, "family": 1, "x": 1.0, "z": 2.0, "area": 0.0}], state.time)
	view.synchronize(state, false, .05)
	var second: MeshInstance3D
	for effect in view.effects:
		if effect.family == 1:
			second = effect.node
	check(second.get_instance_id() == projectile_id and second.mesh.get_instance_id() == mesh_id and second.material_override.get_instance_id() == material_id, "different compatible projectile family reuses actual node, mesh and material instances")
	check(second.scale == Vector3.ONE and second.mesh.size.is_equal_approx(Vector3(.055, .055, .10)) and second.material_override.albedo_color.is_equal_approx(Color("e8ae73").srgb_to_linear()), "reused mortar restores original geometry, scale and palette without bolt residue")
	view.synchronize(state, true, 0)
	view.queue_events([shot], state.time - .05)
	view.synchronize(state, false, 0)
	check(view.effects.is_empty() and view.attacks_emitted == attacks + 2, "pooled hydration clears projectiles and rejects stale pre-boundary observations")
	view.pulse(Vector3(1, .1, 2), .4, "abcdef", .2)
	var pulse: MeshInstance3D = view.effects.back().node
	var pulse_id := pulse.get_instance_id()
	view.present(.3)
	check(pulse.transform == Transform3D.IDENTITY and not pulse.visible, "pulse expiry resets animated expansion and position")
	view.pulse(Vector3(-2, .12, 4), 1.5, "96dcd0", .2)
	var pulse_again: MeshInstance3D = view.effects.back().node
	check(pulse_again.get_instance_id() == pulse_id and pulse_again.position == Vector3(-2, .12, 4) and pulse_again.scale == Vector3.ONE and is_equal_approx(pulse_again.mesh.outer_radius, 1.5) and is_equal_approx(pulse_again.mesh.inner_radius, 1.445) and pulse_again.material_override.albedo_color.is_equal_approx(Color("96dcd0").srgb_to_linear()), "compatible pulse node reuses identity while restoring requested radius, palette and transform")
	# Actual pickup removal flows through fly-to-wallet then the same coin reserve.
	var coin: Dictionary = state.coins[0].duplicate(true)
	var coin_key := str(int(coin.id))
	var coin_id: int = view.pickups[coin_key].node.get_instance_id()
	var label_id: int = view.pickups[coin_key].label.get_instance_id()
	state.coins.remove_at(0)
	state.time += .05
	view.synchronize(state, false, .05)
	view.present(.3)
	state.coins.append({"id": 999, "x": -2.0, "z": 1.0, "value": 7})
	state.time += .05
	view.synchronize(state, false, .05)
	check(view.pickups["999"].node.get_instance_id() == coin_id and view.pickups["999"].label.get_instance_id() == label_id, "coin fly expiry and value label actually reuse their instances for a new stable ID")
	check(view.pickups["999"].node.rotation == Vector3.ZERO and view.pickups["999"].node.scale == Vector3.ONE and view.pickups["999"].label.text == "7" and view.pickups["999"].label.modulate == Color("ffe1a0"), "coin reuse has no old spin/scale/value/palette state")
	# A terminal snapshot retains its last movement delta, but pooled units stop.
	state.x -= .1
	state.time += .05
	view.synchronize(state, false, .05)
	view.present(.03)
	state.phase = "victory"
	view.synchronize(state, false, 0)
	var gait: float = view.units.commander.gait
	for tick in 120:
		view.present(1.0 / 60)
	check(view.units.commander.gait == gait and view.units.commander.travel == 0, "terminal gait remains stopped with pooled actor path")
	var before := S.encode(state, L.profile(), {"sound": true, "reduced_effects": false}, 1, true, C.profile())
	view.synchronize(state, true, 0)
	view.present(10)
	check(before == S.encode(state, L.profile(), {"sound": true, "reduced_effects": false}, 1, true, C.profile()), "pooling/pause/terminal do not mutate complete saved-state meaning")
	# Reserves are bounded globally as well as per role/type. Active nodes are not.
	for role in ["raider", "runner", "armor", "swarm", "mender", "shade", "ram", "matriarch", "regent"]:
		var batch: Array[Node3D] = []
		for i in V.ACTOR_ROLE_RESERVE + 2:
			batch.append(view.take_actor(role))
		for node in batch:
			view.return_actor(node)
		check((view.actor_pool.reserves.get(role, []) as Array).size() <= V.ACTOR_ROLE_RESERVE, "inactive role reserve cap: " + role)
	check(view.actor_pool.reserve_count == V.ACTOR_TOTAL_RESERVE and view.actor_pool.reserves.size() <= V.ACTOR_TOTAL_RESERVE, "global inactive actor reserve reaches and respects fixed cap")
	for kind in ["projectile", "pulse", "coin", "coin_label"]:
		var batch: Array[Node3D] = []
		for i in V.EFFECT_KIND_RESERVE + 2:
			batch.append(view.take_effect(kind))
		for node in batch:
			view.return_effect(node)
		check((view.effect_pool.reserves.get(kind, []) as Array).size() <= V.EFFECT_KIND_RESERVE, "compatible inactive effect cap: " + kind)
	check(view.effect_pool.reserve_count == V.EFFECT_TOTAL_RESERVE, "global inactive effect reserve reaches and respects fixed cap")
	await process_frame
	check(view.actor_pool.inactive.get_child_count() == V.ACTOR_TOTAL_RESERVE and view.effect_pool.inactive.get_child_count() == V.EFFECT_TOTAL_RESERVE, "overflow instances are actually released, not hidden beyond the reserve counts")
	var inactive_okay := true
	for pool in [view.actor_pool, view.effect_pool]:
		for node in pool.inactive.get_children():
			inactive_okay = inactive_okay and not node.visible and node.process_mode == Node.PROCESS_MODE_DISABLED and node.transform == Transform3D.IDENTITY
	check(inactive_okay, "every retained inactive instance is hidden, disabled and neutrally transformed")
	var actor_pool: RefCounted = view.actor_pool
	var effect_pool: RefCounted = view.effect_pool
	var actor_branch: Node = actor_pool.inactive
	var effect_branch: Node = effect_pool.inactive
	var held_node: Node = actor_branch.get_child(0)
	view.queue_free()
	await process_frame
	await process_frame
	check(actor_pool.reserve_count == 0 and effect_pool.reserve_count == 0 and actor_pool.reserves.is_empty() and effect_pool.reserves.is_empty(), "scene teardown clears both reserve indexes")
	check(not is_instance_valid(actor_branch) and not is_instance_valid(effect_branch) and not is_instance_valid(held_node), "scene teardown releases inactive branches and actual retained nodes")
	var file := FileAccess.open(folder.path_join("pool-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "scope": "Focused synthetic pool/reset/epoch/effect fixtures; eleven rule seconds only; no earned progress, rendering or device claims"}, "\t"))
	file.close()
	print("POOL_CHECKS ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
