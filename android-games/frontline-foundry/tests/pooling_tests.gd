extends SceneTree
## Synthetic CPU controls are separate from later authentic gameplay footage.
const V = preload("res://scripts/presentation/outpost.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0
var rows: Array = []
var folder := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(okay: bool, description: String) -> void:
	checks += 1
	rows.append({"pass": okay, "description": description})
	if not okay:
		failures += 1
		push_error(description)
	print("CHECK ", description, " ", "PASS" if okay else "FAIL")

func material_value(material: Material) -> Variant:
	if material is StandardMaterial3D:
		return [material.albedo_color, material.roughness, material.metallic, material.shading_mode, material.billboard_mode]
	return null

func fingerprint(actor: Node3D) -> Array:
	var result: Array = [actor.transform, actor.visible, actor.process_mode, actor.role, actor.team, actor.gait, actor.travel, actor.fire_left, actor.hit_left, actor.death_time, actor.armed, actor.action, actor.aim, actor.equipment_progress, actor.health_fraction, actor.torso_yaw, actor.repair_left, actor.repair_aim, actor.warning_left, actor.jammed, actor.status.text, actor.status.modulate, actor.status.font_size, actor.status.pixel_size, actor.status.outline_size]
	for entry in actor.rest_nodes:
		var node: Node3D = entry.node
		result.append([node.transform, node.visible])
		if node is GeometryInstance3D:
			result.append([material_value(node.material_override), material_value(node.material_overlay), node.transparency, node.layers])
		if node is MeshInstance3D:
			for surface in node.mesh.get_surface_count():
				result.append(material_value(node.get_surface_override_material(surface)))
	if actor.rig != null:
		for index in actor.rig.get_bone_count():
			result.append(actor.rig.get_bone_pose(index))
	result.append(actor.socket_position())
	return result

func contaminate(actor: Node3D) -> void:
	actor.fire(Vector3(5, 0, -2))
	actor.hit()
	actor.repair(Vector3(-5, 0, 2))
	actor.pose(.13, Vector3(2, 0, 3), true)
	actor.death_time = 1
	actor.pose(.1, Vector3.ZERO, false)
	actor.gait = 123
	actor.travel = 3
	actor.aim = Vector3.BACK
	actor.repair_aim = Vector3.RIGHT
	actor.warning_left = 3
	actor.jammed = true
	actor.armed = false
	actor.action = "fallen"
	actor.equipment_progress = .2
	actor.health_fraction = .1
	actor.status.text = "OLD ID"
	actor.status.modulate = Color.RED
	actor.status.font_size = 7
	actor.status.pixel_size = .1
	actor.status.outline_size = 0
	actor.transform = Transform3D(Basis.from_euler(Vector3(.3, .5, .2)).scaled(Vector3.ONE * .4), Vector3(3, 4, 5))
	var bad := Actor.material(Color.MAGENTA)
	for entry in actor.rest_nodes:
		var node: Node3D = entry.node
		node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * .1), Vector3(2, 3, 4))
		node.hide()
		if node is GeometryInstance3D:
			node.material_override = bad
			node.material_overlay = bad
			node.transparency = .9
			node.layers = 8
		if node is MeshInstance3D:
			for surface in node.mesh.get_surface_count():
				node.set_surface_override_material(surface, bad)
	if actor.rig != null:
		for index in actor.rig.get_bone_count():
			actor.rig.set_bone_pose(index, Transform3D(Basis.from_euler(Vector3(.4, .2, .8)).scaled(Vector3.ONE * .2), Vector3(2, 3, 4)))

func actor_controls(world: Node3D) -> void:
	for role in ["commander", "rifle", "runner", "breaker", "ranger", "bulwark", "mortar", "jammer", "sapper", "rover", "vehicle", "drill", "carrier", "storm"]:
		var team := "commander" if role == "commander" else ("ally" if role in ["rifle", "breaker", "ranger", "rover", "vehicle"] else "enemy")
		var actor: Node3D = world.acquire_actor(role, team, .375)
		var clean := fingerprint(actor)
		var id := actor.get_instance_id()
		var model_id: int = actor.model.get_instance_id()
		var rig_id: int = actor.rig.get_instance_id() if actor.rig != null else 0
		contaminate(actor)
		world.retire_actor(actor)
		check(not actor.visible and actor.process_mode == Node.PROCESS_MODE_DISABLED, role + " inactive actor is hidden and disabled")
		var reused: Node3D = world.acquire_actor(role, team, .375)
		check(reused.get_instance_id() == id and reused.model.get_instance_id() == model_id and (reused.rig.get_instance_id() if reused.rig != null else 0) == rig_id, role + " reuses the exact actor/model/rig instances")
		check(fingerprint(reused) == clean, role + " resets every captured transform, material, label, pose, aim, life/health and contact state")
		reused.fire(Vector3(5, 0, -2))
		reused.pose(.05, Vector3.FORWARD, false)
		var tip: Vector3 = reused.socket_position()
		var expected: Vector3
		if reused.rig != null:
			expected = reused.rig.to_global(reused.rig.get_bone_global_pose(reused.bones.PrimaryMuzzle).origin)
		else:
			var bounds: AABB = reused.barrel.mesh.get_aabb()
			expected = reused.barrel.to_global(Vector3(bounds.get_center().x, bounds.position.y - .015, bounds.get_center().z))
		check(tip.distance_to(expected) < .00001, role + " reused attack contact follows current bone or aimed/recoiling barrel in the same call")
		world.retire_actor(reused)
	var ally: Node3D = world.acquire_actor("rifle", "ally", 0)
	world.retire_actor(ally)
	var hostile: Node3D = world.acquire_actor("rifle", "enemy", 0)
	check(hostile != ally and hostile.team == "enemy", "side-incompatible material/health palette never shares an actor lease")
	var ranger: Node3D = world.acquire_actor("ranger", "ally", 0)
	check(ranger != ally and ranger.role_kit != null, "different authored weapon/loadout uses a different pool key")
	world.retire_actor(hostile)
	world.retire_actor(ranger)
	var active: Array = []
	for index in world.MAX_INACTIVE_ACTORS + 8:
		active.append(world.acquire_actor("rifle", "enemy", 0))
	check(active.size() > world.MAX_INACTIVE_ACTORS and active.all(func(node): return node.visible), "inactive reserve caps never cap visible logical actors")
	for actor in active:
		world.retire_actor(actor)
	check(world.actor_pool[world.pool_key("rifle", "enemy")].size() == world.MAX_INACTIVE_PER_ROLE_SIDE, "per-compatible-role/side inactive limit discards excess nodes")
	active.clear()
	for role in ["rifle", "runner", "bulwark", "mortar", "jammer", "sapper", "ranger", "rover"]:
		for index in 4:
			active.append(world.acquire_actor(role, "enemy", 0))
	for actor in active:
		world.retire_actor(actor)
	check(world.inactive_count(world.actor_pool) == world.MAX_INACTIVE_ACTORS and world.pool_stats.actors_discarded > 0, "global inactive actor reserve saturates at its cap and frees excess")

func effect_controls(world: Node3D) -> void:
	world.tracer(Vector3(1, .8, -2), Vector3(-3, .7, 4), "ffd36e")
	var first: MeshInstance3D = world.effects[0].node
	var id := first.get_instance_id()
	var mesh_id := first.mesh.get_instance_id()
	world._process(.06)
	check(world.effects.is_empty() and not first.visible, "expired real tracer enters inactive reserve")
	first.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 3), Vector3(5, 4, 3))
	first.material_overlay = Actor.material(Color.RED)
	first.transparency = .9
	first.layers = 16
	world.tracer(Vector3.ZERO, Vector3(2, 0, 0), "f5906a")
	var reused: MeshInstance3D = world.effects[0].node
	var half: float = reused.mesh.size.z * .5
	check(reused.get_instance_id() == id and reused.mesh.get_instance_id() == mesh_id, "tracer reuses exact node and mutable mesh")
	check(reused.global_position.distance_to(Vector3(1, 0, 0)) < .00001 and (reused.global_position + reused.global_basis.z * half).distance_to(Vector3.ZERO) < .00001 and (reused.global_position - reused.global_basis.z * half).distance_to(Vector3(2, 0, 0)) < .00001 and reused.scale.is_equal_approx(Vector3.ONE), "reused tracer resets length, transform, origin and endpoint")
	check(reused.material_overlay == null and reused.transparency == 0 and reused.layers == 1 and reused.material_override == world.mat("f5906a"), "reused effect resets material, side color, layers and visibility")
	world.clear_transients()
	world.pulse(Vector3.ONE, "91bf80", .35)
	var pulse: MeshInstance3D = world.effects[0].node
	check(pulse != reused and pulse.mesh is TorusMesh and is_equal_approx(pulse.mesh.outer_radius, .35), "incompatible pulse/tracer shapes never share a node or mutable mesh")
	world._process(.2)
	world.pulse(Vector3(2, 0, 1), "e06e43", .28)
	check(world.effects[0].node == pulse and is_equal_approx(pulse.mesh.outer_radius, .28) and pulse.scale.is_equal_approx(Vector3(1, .25, 1)), "reused pulse resets its own radius, location and flattened transform")
	world.clear_transients()
	for index in world.MAX_EFFECTS + 10:
		world.pulse(Vector3(index, 0, 0), "e06e43", .28)
	check(world.effects.size() == world.MAX_EFFECTS, "existing optional visible-effect cap is preserved")
	world._process(.2)
	check(world.effect_pool.pulse.size() == world.MAX_INACTIVE_PER_EFFECT and world.pool_stats.effects_discarded > 0, "expired compatible effect reserve saturates per-kind and frees excess")
	for index in world.MAX_EFFECTS:
		world.tracer(Vector3.ZERO, Vector3(1, 0, 0), "ffd36e")
	world.clear_transients()
	check(world.inactive_count(world.effect_pool) == world.MAX_INACTIVE_EFFECTS, "global inactive effect reserve reaches its bounded cap")
	var state := C.fresh(D.mission(11))
	for index in world.MAX_INACTIVE_EFFECTS + 6:
		state.marks.append({"source": 200 + index, "x": .1 * index, "z": -3.0, "remaining": 1.0})
	world.reduced = true
	world.sync_warnings(state)
	check(world.warnings.size() > world.MAX_INACTIVE_EFFECTS and world.warnings.values().all(func(node): return node.visible), "inactive effect caps never suppress essential reduced-effects warning nodes")
	state.marks.clear()
	world.sync_warnings(state)
	check(world.inactive_count(world.effect_pool) == world.MAX_INACTIVE_EFFECTS, "expired essential warnings also obey global inactive cap")

func fixture_enemy(id: int, role: String = "drone") -> Dictionary:
	return {"id": id, "role": role, "hp": 20.0, "x": 0.0, "z": -4.0, "telegraph": 0.0}

func integration_controls() -> void:
	var state := C.fresh(D.mission(11))
	state.phase = "playing"
	state.time = 1.0
	state.enemies = [fixture_enemy(10)]
	var world := V.new()
	root.add_child(world)
	world.build(state)
	world.set_process(false)
	var first: Node3D = world.units["enemy:10"]
	var rig_id: int = first.rig.get_instance_id()
	state.time += .05
	state.enemies = [fixture_enemy(11)]
	var before := state.duplicate(true)
	world.sync(state, false, false, .05)
	check(world.units["enemy:11"] == first and first.rig.get_instance_id() == rig_id and not world.units.has("enemy:10") and D.same(state, before), "a fresh authoritative ID reuses an escaped compatible actor without mutating whole state")
	state.time += .05
	state.killed.append(11)
	state.enemies = []
	world.sync(state, false, false, .05)
	check(world.corpses.size() == 1 and first.death_time == 0, "killed actor retains original corpse interval before reuse")
	world._process(.86)
	check(world.corpses.is_empty() and not first.visible, "expired corpse returns exact actor to reserve")
	state.time += .05
	state.enemies = [fixture_enemy(12)]
	world.sync(state, false, false, .05)
	check(world.units["enemy:12"] == first and first.death_time == -1 and first.model.rotation.is_equal_approx(Vector3.ZERO), "fresh living ID cannot inherit corpse pose or hidden health/status")
	var event := {"kind": "shot", "actor": "commander", "attack": "same:1", "enemy": 12, "from": [0, 1], "to": [0, -4]}
	world.queue_events([event, event])
	world.sync(state, false, false, .05)
	check(world.attacks_emitted == 1 and world.effects.size() == 1, "ID/epoch event dedupe remains separate from actor-node reuse")
	var epoch: int = world.adapter.epoch
	world.sync(state, true, true, 0)
	check(world.adapter.epoch > epoch and world.effects.is_empty() and world.pending.is_empty(), "pause clears active trails and dedupe epoch while retaining bounded reserves")
	var held := fingerprint(first)
	var paused_state := state.duplicate(true)
	world._process(20)
	check(fingerprint(first) == held and D.same(state, paused_state), "paused pooled actor and complete gameplay state remain frozen")
	state.marks = [{"source": 99, "x": 1.0, "z": -2.0, "remaining": 1.0}]
	world.sync(state, true, true, 0)
	var warning: MeshInstance3D = world.warnings.values()[0]
	state.marks = []
	world.sync(state, true, true, 0)
	state.marks = [{"source": 100, "x": -1.0, "z": -3.0, "remaining": 1.0}]
	world.sync(state, true, true, 0)
	check(world.warnings.values()[0] == warning and warning.visible and warning.position.is_equal_approx(Vector3(-1, .07, -3)), "new essential warning key reuses correct ring under reduced effects and pause")
	state.marks = []
	state.time = 0
	world.sync(state, false, false, 0)
	world.queue_events([event])
	world.sync(state, false, false, 0)
	check(world.attacks_emitted == 2 and world.effects.size() == 1 and first.death_time == -1, "rewound context starts a fresh event epoch without stale contact or death")
	state.time += .05
	state.enemies[0].role = "bulwark"
	world.sync(state, false, false, .05)
	check(world.units["enemy:12"] != first and world.units["enemy:12"].role == "bulwark" and not first.visible, "changed loadout under a stable ID obtains a compatible model instead of stale rig reuse")
	state.time += .05
	state.enemies.clear()
	for index in world.MAX_INACTIVE_ACTORS + 6:
		state.enemies.append(fixture_enemy(200 + index))
	var crowded := state.duplicate(true)
	world.sync(state, false, false, .05)
	check(world.units.size() == 13 + state.enemies.size() and world.units.values().all(func(node): return node.visible) and D.same(state, crowded), "actual snapshot synchronization renders every logical actor beyond the inactive cap")
	world.queue_free()
	await process_frame

func lifecycle_controls() -> void:
	var state := C.fresh(D.mission(0))
	check(S.write(state, R.profile(), {"sound": false, "reduced_effects": true}, S.PATH, null, true, C.career()), "write isolated complete CPU fixture")
	var app: Node = load("res://boot.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var scene: Node = app.session
	await tap(scene.start_button.get_global_rect().get_center())
	await tap(scene.pause_button.get_global_rect().get_center())
	var whole := {"state": scene.state.duplicate(true), "profile": scene.profile.duplicate(true), "settings": scene.settings.duplicate(true), "career": scene.career.duplicate(true)}
	var owner: Node3D = scene.presentation
	var reserve: Node3D = owner.acquire_actor("ranger", "enemy", 0)
	owner.retire_actor(reserve)
	owner.pulse(Vector3.ZERO, "e06e43", .28)
	owner.clear_transients()
	var effect: MeshInstance3D = owner.effect_pool.pulse[0]
	var actor_weak: WeakRef = weakref(reserve)
	var model_weak: WeakRef = weakref(reserve.model)
	var effect_weak: WeakRef = weakref(effect)
	var material_weak: WeakRef = weakref(owner.palette_materials.values()[0])
	var models: Dictionary = owner.model_resources
	var palettes: Dictionary = owner.palette_materials
	var saved := S.read()
	check(D.same(saved.state, whole.state) and D.same(saved.profile, whole.profile) and D.same(saved.settings, whole.settings) and D.same(saved.career, whole.career), "pool operations never alter complete durable gameplay context")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var other := V.new()
	viewport.add_child(other)
	other.build(C.fresh(D.mission(0)))
	other.set_process(false)
	var other_palette: WeakRef = weakref(other.palette_materials.values()[0])
	var other_held := fingerprint(other.units.commander)
	# Exercise actual existing Retry handler through GUI after a fixture terminal.
	scene.state.phase = "defeat"
	scene.paused = false
	scene.refresh()
	var retry: Button
	for node in scene.terminal.get_children():
		if node is Button and node.text == "RETRY SIEGE":
			retry = node
	await tap(retry.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(scene.state.phase == "ready" and scene.state.time == 0 and D.same(scene.profile, whole.profile) and D.same(scene.settings, whole.settings) and D.same(scene.career, whole.career), "actual Retry retains full profile/settings/career and fresh run meanings")
	check(actor_weak.get_ref() == null and model_weak.get_ref() == null and effect_weak.get_ref() == null and material_weak.get_ref() == null and models.is_empty() and palettes.is_empty(), "real owner replacement frees reserves and owner materials/models while viewport survives")
	check(other_palette.get_ref() != null and not other.palette_materials.is_empty() and fingerprint(other.units.commander) == other_held, "owner release never clears another live viewport's material cache or actor pose")
	viewport.queue_free()
	await process_frame
	await process_frame
	check(other_palette.get_ref() == null, "actual second viewport teardown releases its owner-local cached materials")
	check(scene.presentation.pool_snapshot().actors_reused == 0 and scene.presentation.effects.is_empty(), "new owner never inherits prior reserves, effects or observation counters")
	await tap(scene.start_button.get_global_rect().get_center())
	await tap(scene.pause_button.get_global_rect().get_center())
	var boundary := S.read()
	app.queue_free()
	await process_frame
	await process_frame
	app = load("res://boot.tscn").instantiate()
	root.add_child(app)
	await process_frame
	scene = app.session
	check(scene.paused and D.same(scene.state, boundary.state) and D.same(scene.profile, boundary.profile) and D.same(scene.settings, boundary.settings) and D.same(scene.career, boundary.career), "cold scene boot hydrates whole active saved context without pooled identity or epoch leakage")
	check(scene.presentation.effects.is_empty() and scene.presentation.pending.is_empty() and scene.presentation.inactive_count(scene.presentation.actor_pool) == 0, "cold load starts with no phantom effects or carried inactive nodes")
	app.queue_free()
	await process_frame

func consequential_controls() -> void:
	var state := C.fresh(D.mission(7))
	state.phase = "playing"
	var world := V.new()
	root.add_child(world)
	world.build(state)
	world.set_process(false)
	var identical := true
	for tick in 600:
		var reference := state.duplicate(true)
		var input := Vector2(sin(tick * .03), -.4)
		var expected := C.tick(reference, input, 1.0 / 60)
		var events := C.tick(state, input, 1.0 / 60)
		world.queue_events(events)
		world.sync(state, false, tick % 2 == 0, 1.0 / 60)
		world._process(1.0 / 60)
		identical = identical and D.same(state, reference) and D.same(events, expected)
	check(identical, "pooled presentation leaves complete state and consequential events identical on each of 600 actual rule ticks")
	world.queue_free()
	await process_frame

func tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 2
		touch.position = root.get_final_transform() * point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await process_frame

func run() -> void:
	root.size = Vector2i(720, 1280)
	var world := V.new()
	root.add_child(world)
	world.build(C.fresh(D.mission(0)))
	world.set_process(false)
	actor_controls(world)
	effect_controls(world)
	var snapshot: Dictionary = world.pool_snapshot()
	world.queue_free()
	await process_frame
	await integration_controls()
	await consequential_controls()
	await lifecycle_controls()
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join("pooling-report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "rows": rows, "pool": snapshot, "scope": "Synthetic CPU fixtures: actual actor/model/rig/effect reuse, complete rest reset/contact, caps, IDs/epoch, real Retry GUI, whole cold context and owner resource teardown. No rendered visual or performance claim."}, "  "))
	print("FRONTLINE_POOLING checks=", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
