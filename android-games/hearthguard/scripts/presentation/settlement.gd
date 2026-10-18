extends Node3D
const Adapter = preload("res://scripts/presentation/adapter.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Regions = preload("res://scripts/presentation/regions.gd")
const C = preload("res://scripts/campaign_rules.gd")
const Cat = preload("res://scripts/campaign_catalog.gd")
const L = preload("res://scripts/rules.gd")
const NodePool = preload("res://scripts/presentation/node_pool.gd")
const ACTOR_ROLE_RESERVE := 4
const ACTOR_TOTAL_RESERVE := 24
const EFFECT_KIND_RESERVE := 16
const EFFECT_TOTAL_RESERVE := 64
var actor_pool: RefCounted
var effect_pool: RefCounted
var adapter := Adapter.new()
var camera: Camera3D
var units := {}
var corpses: Array = []
var civilians: Array = []
var towers: Array = []
var pads: Array[Node3D] = []
var pad_labels: Array[Label3D] = []
var pickups := {}
var effects: Array = []
var pending: Array = []
var bounds_records: Array = []
var region := {}
var definition := {}
var campaign := true
var reduced := false
var presented := false
var range_ring: MeshInstance3D
var field_rect := Rect2()
var effects_emitted := 0
var attacks_emitted := 0
var decor_time := 0.0
var target_phase := "ready"
var gate: Node3D
var gate_hit := 0.0
var previous_integrity := -1
var manifest := {}
var scenic_bounds: Array = []

func build(state: Dictionary) -> void:
	actor_pool = NodePool.new(self, "InactiveActors", ACTOR_ROLE_RESERVE, ACTOR_TOTAL_RESERVE)
	effect_pool = NodePool.new(self, "InactiveEffects", EFFECT_KIND_RESERVE, EFFECT_TOTAL_RESERVE)
	campaign = state.schema == 2
	definition = state.definition.duplicate(true) if campaign else {}
	region = Regions.describe(state)
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://art/manifest.json"))
	for spec in manifest.models:
		var lo: Array = spec.bounds_blender.min
		var hi: Array = spec.bounds_blender.max
		manifest[spec.name] = AABB(Vector3(lo[0], lo[2], -hi[1]), Vector3(hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]))
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(region.sky).srgb_to_linear()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dce6de").srgb_to_linear()
	env.ambient_light_energy = .28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = .85
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-57, -29, 0)
	sun.light_color = Color("fff8ed")
	sun.light_energy = .70
	sun.shadow_enabled = true
	sun.shadow_opacity = .40
	sun.shadow_blur = 2
	sun.shadow_normal_bias = .6
	sun.directional_shadow_max_distance = 60
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color("bfdde4")
	fill.light_energy = .16
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = .5
	camera.far = 100
	camera.position = Vector3(0, 24, 17)
	add_child(camera)
	camera.look_at(Vector3(0, 0, -.5))
	camera.current = true
	# Continuous ground; road strips sit above it with no coplanar deck faces.
	box(Vector3(0, -.24, 0), Vector3(80, .45, 80), region.ground)
	if region.region == 1:
		box(Vector3(-7.4, -.03, -2), Vector3(2.7, .018, 21), region.water)
		box(Vector3(7.6, -.03, -1), Vector3(2.3, .018, 21), region.water)
	for lane in (int(definition.lanes) if campaign else 1):
		road(lane)
	for side in [-1, 1]:
		for j in 13:
			place("wall", Vector3(side * 5.55, 0, -8.7 + j * 1.15), 0, .85, true)
	for j in region.clusters.size():
		var cluster: Array = region.clusters[j]
		var side := signf(cluster[0])
		place(region.house, Vector3(cluster[0], 0, cluster[1]), cluster[2], cluster[3], true)
		place(region.tree, Vector3(side * 7.0, 0, cluster[1] + cluster[4]), cluster[2] + .7, .68 + j * .07, true)
		place(region.props[j], Vector3(side * 6.22, 0, cluster[1] + 1.40), -cluster[2], .62, true)
		place("lantern", Vector3(side * 5.72, 0, cluster[1] - .92), 0, .64, true)
	# Gate piers sit beyond the complete traversable/body rectangle.
	gate = Node3D.new()
	add_child(gate)
	var keep := place(region.house, Vector3(0, 0, 9.8), 0, .85, true)
	keep.set_meta("gate", true)
	for x in [-1.7, 1.7]:
		place("banner", Vector3(x, 0, 9.6), 0, .85, true)
	for x in [-1.8, -.6, .6, 1.8]:
		var wall := place("wall", Vector3(x, 0, 9.1), PI / 2, 1, true)
		wall.reparent(gate)
	label("HEARTH REFUGE", Vector3(0, 1.5, 9.1), "fff0c4", 30)
	label(region.landmark.to_upper(), Vector3(0, .18, -10.5), "fff0c4", 28)
	var count: int = definition.pads.size() if campaign else 2
	for i in count:
		var p := pad_point(i)
		var pad := Node3D.new()
		pad.position = Vector3(p.x, .015, p.y)
		add_child(pad)
		pads.append(pad)
		var outer := cylinder(Vector3(p.x, .04, p.y), .70, .08, "e4b75e")
		outer.name = "PadRim%d" % i
		cylinder(Vector3(p.x, .09, p.y), .61, .045, "576e68")
		for j in 4:
			var a := j * TAU / 4
			var mark := box(Vector3(p.x + sin(a) * .57, .13, p.y + cos(a) * .57), Vector3(.15, .035, .07), "f7dfa0")
			mark.rotation.y = a
		var price := label("", Vector3(p.x, .62, p.y), "ffe1a0", 40)
		price.pixel_size = .012
		pad_labels.append(price)
		towers.append({"family": -1, "fork": -1, "node": null, "operator": null, "turret": null, "tip": null, "recoil": 0.0, "construction": 1.0, "aim": Vector3.FORWARD})
	var ring := TorusMesh.new()
	ring.inner_radius = 4.96
	ring.outer_radius = 5
	ring.rings = 64
	ring.ring_segments = 6
	range_ring = MeshInstance3D.new()
	range_ring.mesh = ring
	range_ring.material_override = Actor.material("e2d595")
	add_child(range_ring)
	range_ring.hide()
	for i in 6:
		var cluster: Array = region.clusters[i / 2]
		var side := signf(cluster[0])
		var worker := i % 2 == 0
		var citizen := take_actor("citizen" if worker else "defender", i * 1.7)
		citizen.position = Vector3(side * (6.22 if worker else 6.94), .02, cluster[1] + (2.12 if worker else 1.10))
		if not worker:
			citizen.rotation.y = side * PI / 2
		civilians.append({"actor": citizen, "home": citizen.position, "last": citizen.position})
	adapter.reset(state, false)
	synchronize(state, false, 0)

func take_actor(role: String, phase: float = 0, mounted: bool = false) -> Node3D:
	var actor: Node3D = actor_pool.take(role)
	if actor == null:
		actor = Actor.new()
		add_child(actor)
		actor.configure(role, phase)
	actor.reset_for_reuse(phase, mounted)
	return actor

func return_actor(actor: Node3D) -> void:
	actor.reset_for_reuse()
	actor_pool.put(actor.role, actor)

func take_effect(key: String) -> Node3D:
	var node: Node3D = effect_pool.take(key)
	if node == null:
		if key == "coin":
			node = Actor.asset("coin")
			add_child(node)
			Actor.finish_materials(node)
		elif key == "coin_label":
			node = label("", Vector3.ZERO, "ffe1a0", 25)
		else:
			var mesh := MeshInstance3D.new()
			if key == "projectile":
				mesh.mesh = BoxMesh.new()
			else:
				var torus := TorusMesh.new()
				torus.rings = 32
				torus.ring_segments = 5
				mesh.mesh = torus
			mesh.material_override = Actor.material("ffffff")
			node = mesh
			add_child(node)
	node.set_meta("effect_pool_key", key)
	return node

func return_effect(node: Node3D) -> void:
	var key: String = node.get_meta("effect_pool_key")
	if node is Label3D:
		node.text = ""
		node.modulate = Color.WHITE
	elif node is MeshInstance3D:
		(node.material_override as StandardMaterial3D).albedo_color = Color.WHITE
		if node.mesh is BoxMesh:
			node.mesh.size = Vector3.ONE
		elif node.mesh is TorusMesh:
			node.mesh.inner_radius = .95
			node.mesh.outer_radius = 1
	effect_pool.put(key, node)

func _exit_tree() -> void:
	if actor_pool != null:
		actor_pool.clear()
	if effect_pool != null:
		effect_pool.clear()

func pad_point(index: int) -> Vector2:
	return C.pad_point(definition, index) if campaign else L.PADS[index]

func place(asset: String, at: Vector3, yaw: float, size: float, scenery: bool = false) -> Node3D:
	var node := Actor.asset(asset)
	add_child(node)
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	Actor.finish_materials(node)
	if scenery:
		# Transform all eight corners, not just model origin or unrotated half extents.
		var complete: AABB = node.transform * (manifest[asset] as AABB)
		bounds_records.append({"asset": asset, "bounds": complete, "node": node})
	return node

func road(lane: int) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in 97:
		var z := -11.0 + i * 22.0 / 96
		var x := Cat.road_x(definition, lane, z) if campaign else L.road_x(z)
		var width := .62 if campaign and definition.lanes == 2 else .80
		for side in [-1, 1]:
			verts.append(Vector3(x + side * width, .012, z))
			normals.append(Vector3.UP)
		if i > 0:
			var n := i * 2
			# Match Godot's clockwise front faces, keeping upward lighting normals.
			indices.append_array(PackedInt32Array([n - 2, n - 1, n, n - 1, n + 1, n]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var n := MeshInstance3D.new()
	n.name = "RoadLane%d" % lane
	n.mesh = mesh
	n.material_override = Actor.material(region.road)
	add_child(n)
	# Sparse inset pavers stay below the actor soles, away from raised deck faces.
	for i in 14:
		var z := -9.5 + i * 1.35
		var x := Cat.road_x(definition, lane, z) if campaign else L.road_x(z)
		var paver := box(Vector3(x, .025, z), Vector3(.50, .025, .24), "baa47e" if region.region == 0 else "aebbb1")
		paver.rotation.y = sin(i * .7) * .18

func box(at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = Actor.material(color)
	add_child(node)
	return node

func cylinder(at: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = at
	node.material_override = Actor.material(color)
	add_child(node)
	return node

func label(text: String, at: Vector3, color: String, size: int) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = at
	node.font_size = size
	node.pixel_size = .010
	node.outline_size = 5
	node.modulate = Color(color)
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(node)
	return node

func queue_events(events: Array, observed_time: float) -> void:
	for e in events:
		pending.append({"event": e.duplicate(true), "time": observed_time})

func synchronize(state: Dictionary, held: bool, dt: float, reduced_effects: bool = false) -> void:
	reduced = reduced_effects
	var hydrated := adapter.ingest(state, held, dt)
	if hydrated:
		for e in effects:
			return_effect(e.node)
		effects.clear()
		for corpse in corpses:
			return_actor(corpse.node)
		corpses.clear()
		for actor in units.values():
			actor.reset_transients()
		for t in towers:
			if t.family >= 0:
				t.recoil = 0.0
				t.construction = 1.0
				t.operator.reset_transients()
		# Rules may already have advanced the first Resume tick. Retain observations
		# stamped by that exact tick while discarding pre-boundary stale batches.
		pending = pending.filter(func(batch: Dictionary) -> bool: return not held and batch.time == state.time)
	var snap: Dictionary = adapter.current
	target_phase = snap.phase
	for key in snap.actors:
		var data: Dictionary = snap.actors[key]
		if units.has(key) and units[key].role != data.role:
			return_actor(units[key])
			units.erase(key)
		var fresh := not units.has(key)
		if fresh:
			var actor := take_actor(data.role, float(key.hash() % 100) * .13)
			actor.position = data.position
			actor.rotation.y = PI if key != "commander" else 0
			units[key] = actor
		units[key].update_health(data.hp, data.max_hp, hydrated or fresh)
	for key in units.keys():
		if not snap.actors.has(key):
			var actor: Node3D = units[key]
			var id := int(str(key).trim_prefix("enemy:"))
			if not hydrated and snap.killed.has(id):
				actor.fall()
				corpses.append({"node": actor, "left": .85})
			elif not hydrated and snap.leaked.has(id):
				actor.fire(Vector3(actor.position.x, .6, 9.1))
				corpses.append({"node": actor, "left": .40})
			else:
				return_actor(actor)
			units.erase(key)
	for i in snap.towers.size():
		var spec: Dictionary = snap.towers[i]
		var t: Dictionary = towers[i]
		if t.family != spec.family or t.fork != spec.fork:
			rebuild_tower(i, spec, hydrated or not presented)
		pad_labels[i].visible = spec.family < 0
		pad_labels[i].text = "PAD %d\nFROM %d GOLD" % [i + 1, int(definition.families[2].price)] if campaign else "%d GOLD" % L.COSTS[i]
		if t.family >= 0:
			var title: Label3D = t.title
			title.text = "SILENCED" if spec.jam > 0 else (Cat.FAMILIES[int(spec.family)] if spec.fork == 0 else Cat.FORKS[int(spec.family)][int(spec.fork) - 1])
			if not campaign:
				title.text = "BOLT" if i == 0 else "HEAVY"
			title.modulate = Color("ff927b" if spec.jam > 0 else ["ffe2a0", "ffbf91", "c4fff0"][int(spec.family)])
	var near := C.nearby(state) if campaign else L.nearby_pad(state)
	range_ring.visible = campaign and near >= 0 and snap.towers[near].family >= 0 and not held
	if range_ring.visible:
		var stats: Dictionary = definition.families[int(snap.towers[near].family)].stats[int(snap.towers[near].fork)]
		range_ring.scale = Vector3.ONE * float(stats.range) / 5
		var p := pad_point(near)
		range_ring.position = Vector3(p.x, .10, p.y)
	var drops := {}
	for coin in snap.coins:
		var key := str(int(coin.id))
		drops[key] = true
		if not pickups.has(key):
			var node := take_effect("coin")
			node.position = Vector3(coin.x, .35, coin.z)
			var value := take_effect("coin_label") as Label3D
			value.text = str(int(coin.value))
			value.modulate = Color("ffe1a0")
			value.position = Vector3(coin.x, .80, coin.z)
			pickups[key] = {"node": node, "label": value, "at": node.position, "phase": float(coin.id) * .7}
	for key in pickups.keys():
		if not drops.has(key):
			if not hydrated and not reduced:
				var coin: Node3D = pickups[key].node
				effects.append({"node": coin, "from": coin.position, "to": units.commander.position + Vector3(0, .9, 0), "left": .17, "duration": .17, "family": 4})
			else:
				return_effect(pickups[key].node)
			return_effect(pickups[key].label)
			pickups.erase(key)
	if previous_integrity >= 0 and snap.integrity < previous_integrity and not hydrated:
		gate_hit = .35
	previous_integrity = snap.integrity
	for batch in pending:
		if adapter.accept(batch.event):
			observe(batch.event)
	pending.clear()
	presented = true
	if hydrated:
		present(0)

func rebuild_tower(index: int, spec: Dictionary, hydrated: bool) -> void:
	var t: Dictionary = towers[index]
	for key in ["node", "operator", "title"]:
		if t.get(key) != null:
			if key == "operator":
				return_actor(t[key])
			else:
				t[key].queue_free()
			t[key] = null
	t.family = spec.family
	t.fork = spec.fork
	t.recoil = 0.0
	t.construction = 1.0 if hydrated else 0.0
	if spec.family < 0:
		return
	var p := pad_point(index)
	t.node = place("tower_" + ["bolt", "mortar", "beacon"][int(spec.family)], Vector3(p.x, .015, p.y), 0, 1)
	t.turret = t.node.find_child("Turret", true, false)
	t.tip = t.node.find_child("AuthoredWeaponTip", true, false)
	t.rest = t.turret.position
	t.operator = take_actor("defender", 0, true)
	t.operator.scale = Vector3.ONE * .67
	t.operator.position = Vector3(p.x - .20, 1.21, p.y + .17)
	t.title = label("", Vector3(p.x, 2.74, p.y), "ffe2a0", 38)
	t.title.pixel_size = .012
	if spec.fork > 0:
		for side in [-1, 1]:
			var plate := place("banner", Vector3(p.x + side * .44, .10, p.y + .20), 0, .40)
			plate.reparent(t.node)
	if not hydrated:
		units.commander.work_left = .6
		pulse(Vector3(p.x, .12, p.y), .75, "e9d18b", .35)

func observe(event: Dictionary) -> void:
	if event.kind == "shot":
		var index := int(event.pad)
		var t: Dictionary = towers[index]
		if t.family < 0:
			return
		var target := Vector3(event.get("x", L.road_x(event.z)), .72, event.z)
		var p := pad_point(index)
		t.aim = target - Vector3(p.x, 0, p.y)
		t.turret.rotation.y = atan2(-t.aim.x, -t.aim.z)
		t.recoil = .28
		t.operator.fire(target)
		# The visible weapon belongs to the authored turret, not a generic pad origin.
		var origin: Vector3 = t.tip.global_position
		var bolt := take_effect("projectile") as MeshInstance3D
		(bolt.mesh as BoxMesh).size = Vector3(.055, .055, .35 if t.family == 0 else .10)
		(bolt.material_override as StandardMaterial3D).albedo_color = Color(["ffe3a0", "e8ae73", "a3ebe1"][int(t.family)]).srgb_to_linear()
		bolt.position = origin
		if not origin.is_equal_approx(target):
			bolt.look_at(target)
		effects.append({"node": bolt, "from": origin, "to": target, "left": .22, "duration": .22, "family": int(t.family)})
		attacks_emitted += 1
		if event.get("area", 0) > 0 and not reduced:
			pulse(target * Vector3(1, 0, 1) + Vector3(0, .10, 0), minf(event.area, 1.6), "dcb991" if t.family == 1 else "96dcd0", .24)
	elif event.kind == "heal":
		for key in units:
			if units[key].role in ["mender", "matriarch"] and units[key].position.distance_to(Vector3(event.x, 0, event.z)) < .25:
				units[key].fire(units[key].position + Vector3.FORWARD)
		if not reduced:
			pulse(Vector3(event.x, .10, event.z), 1, "b4d788", .4)
	elif event.kind == "leak":
		var key := "enemy:" + str(int(event.id))
		# Contact response is observational. Integrity was already changed by rules.
		gate_hit = .35
		if not reduced:
			pulse(Vector3(0, .12, 8.3), .9, "df9b78", .25)

func pulse(at: Vector3, radius: float, color: String, duration: float) -> void:
	if reduced:
		return
	var node := take_effect("pulse") as MeshInstance3D
	var shape := node.mesh as TorusMesh
	shape.inner_radius = maxf(.02, radius - .055)
	shape.outer_radius = radius
	(node.material_override as StandardMaterial3D).albedo_color = Color(color).srgb_to_linear()
	node.position = at
	effects.append({"node": node, "from": at, "to": at, "left": duration, "duration": duration, "family": 3})
	effects_emitted += 1

func _process(dt: float) -> void:
	present(dt)

func present(dt: float) -> void:
	if adapter.current.is_empty():
		return
	var alpha := adapter.advance(dt)
	var step := 0.0 if adapter.paused else dt
	var snap: Dictionary = adapter.current
	for key in snap.actors:
		var to: Dictionary = snap.actors[key]
		var from: Dictionary = adapter.previous.actors.get(key, to)
		var node: Node3D = units[key]
		node.position = (from.position as Vector3).lerp(to.position, alpha) + Vector3(0, .03, 0)
		var velocity: Vector3 = (to.position - from.position) / adapter.interval if not adapter.paused and target_phase == "playing" else Vector3.ZERO
		node.pose(step, velocity, target_phase)
	for i in range(corpses.size() - 1, -1, -1):
		var corpse: Dictionary = corpses[i]
		corpse.left -= step
		corpse.node.pose(step, Vector3.ZERO, target_phase)
		if corpse.left <= 0:
			return_actor(corpse.node)
			corpses.remove_at(i)
	decor_time += step
	for i in civilians.size():
		var c: Dictionary = civilians[i]
		var at: Vector3 = c.home
		# Citizens remain outside the traversable/body rectangle and keep their own
		# deterministic local clock, without consuming the game's seeded RNG.
		if c.actor.role == "citizen" and target_phase == "playing":
			at.z += sin(decor_time * .45 + i) * .55
		var v: Vector3 = (at - c.last) / maxf(step, .001)
		c.actor.position = at
		c.actor.pose(step, v, target_phase)
		c.last = at
		if c.actor.role == "citizen" and target_phase == "playing" and fmod(decor_time + i, 4.2) < step:
			c.actor.work_left = .6
	for t in towers:
		if t.family < 0:
			continue
		t.construction = minf(1, t.construction + step * 3.2)
		t.node.scale = Vector3.ONE * lerpf(.82, 1, smoothstep(0, 1, t.construction))
		t.node.position.y = .015 - (1 - t.construction) * .15
		t.recoil = maxf(0, t.recoil - step)
		var recoil := sin(PI * t.recoil / .28) * .10
		t.turret.position = t.rest + Vector3(sin(t.turret.rotation.y), 0, cos(t.turret.rotation.y)) * recoil
		t.operator.pose(step, Vector3.ZERO, target_phase)
	for coin in pickups.values():
		coin.node.rotation.y = decor_time * 1.3 + coin.phase
		coin.node.position.y = coin.at.y + (.035 * sin(decor_time * 3 + coin.phase) if not reduced else 0.0)
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e.left -= step
		if e.left <= 0:
			return_effect(e.node)
			effects.remove_at(i)
		else:
			var f: float = 1 - e.left / e.duration
			e.node.position = (e.from as Vector3).lerp(e.to, f)
			if e.family == 1:
				e.node.position.y += sin(f * PI) * 1.3
			elif e.family == 3:
				e.node.scale = Vector3.ONE * lerpf(.8, 1.1, f)
	gate_hit = maxf(0, gate_hit - step)
	gate.rotation.z = .015 * sin(gate_hit * 60) if not reduced else 0.0

func framing_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for x in [-5.1, 5.1]:
		for z in [-9.7, 8.4]:
			for y in [0.0, 2.7]:
				points.append(Vector3(x, y, z))
	# Include complete transformed silhouettes, rather than fitting only the road.
	for record in bounds_records:
		for corner in 8:
			points.append((record.bounds as AABB).get_endpoint(corner))
	for c in civilians:
		var silhouette: AABB = c.actor.transform * c.actor.model.transform * (manifest["actor_" + c.actor.role] as AABB)
		for corner in 8:
			points.append(silhouette.grow(.55).get_endpoint(corner))
	return points

func fit(rect: Rect2) -> void:
	field_rect = rect
	camera.size = 24
	camera.h_offset = 0
	camera.v_offset = 0
	var projected := projected_bounds(framing_points())
	var factor := minf(rect.size.x / projected.size.x, rect.size.y / projected.size.y)
	camera.size /= factor
	projected = projected_bounds(framing_points())
	var center := projected.get_center()
	var ppm := camera.unproject_position(Vector3.ZERO).distance_to(camera.unproject_position(camera.global_basis.x))
	camera.h_offset = (center.x - rect.get_center().x) / ppm
	camera.v_offset = -(center.y - rect.get_center().y) / ppm

func projected_bounds(points: Array[Vector3]) -> Rect2:
	var first := camera.unproject_position(points[0])
	var rect := Rect2(first, Vector2.ZERO)
	for p in points:
		rect = rect.expand(camera.unproject_position(p))
	return rect
