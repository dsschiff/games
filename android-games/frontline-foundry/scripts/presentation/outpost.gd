extends Node3D
const Adapter = preload("res://scripts/presentation/adapter.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const D = preload("res://scripts/definitions.gd")
const R = preload("res://scripts/rules.gd")
var adapter := Adapter.new()
var camera: Camera3D
var units := {}
var corpses := {}
var pickups := {}
var warnings := {}
var stations: Array[Node3D] = []
var pad_labels: Array[Label3D] = []
var pads: Array[Node3D] = []
var relay_labels: Array[Label3D] = []
var effects: Array = []
var materials := {}
var reduced := false
var pending: Array = []
var campaign := true
var death_ids: Array = []
var available: Array = []
var hq: Node3D
var effects_emitted := 0
var attacks_emitted := 0
var attacks_seen := {}
var scene_hash := ""
var sentry: Node3D
var hq_hit_left := 0.0
var routed := {"projectile": 0, "ground": 0, "contact": 0, "blast": 0, "breach": 0, "repair": 0, "hq": 0}

func build(state: Dictionary) -> void:
	campaign = int(state.catalog) == 2
	adapter.reset(state, false)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c5d1cf")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dbe7e4")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -32, 0)
	sun.light_color = Color("fffbf0")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50
	sun.shadow_bias = 0.20
	sun.shadow_normal_bias = 2.0
	sun.shadow_opacity = .48
	sun.shadow_blur = 2.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38, 145, 0)
	fill.light_color = Color("cad9e0")
	fill.light_energy = .22
	fill.shadow_enabled = false
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = 80.0
	camera.position = Vector3(0, 20, 17)
	add_child(camera)
	camera.look_at(Vector3(0, 0, -0.2))
	camera.current = true
	# Continuous terrain beyond the authored rules rectangle; no floating board.
	box(Vector3(0, -.42, 0), Vector3(90, .8, 90), "c6c1b4")
	for spec in [[-3.5, -5.8, 1.6], [3.1, -3.8, 1.3], [0.8, -7.7, 1.1], [-4.0, 1.5, .9]]:
		var patch := cylinder(Vector3(spec[0], -.009, spec[1]), spec[2], .012, "c0bbad")
		patch.scale.z = .55
		patch.rotation.y = spec[1] * .3
	box(Vector3(0, .025, 3.1), Vector3(1.5, .035, 6.0), "d8cdb5")
	for side in [-1, 1]:
		for i in 3:
			var stone := asset("cliff", Vector3(side * 5.45, .03, -7.5 + i * 2.3))
			stone.scale = Vector3(.33, .40, .36)
			stone.rotation.y = i * 1.7
		for i in 10:
			var cliff := asset("cliff", Vector3(side * (6.7 + sin(i * 2.1) * .45), .45, -11.0 + i * 2.55))
			cliff.rotation.y = i * .57
			cliff.scale = Vector3(1.1 + (i % 3) * .2, 1.5 + (i % 2) * .6, 1.3)
		for i in 5:
			var bag := asset("sandbag", Vector3(side * (1.35 + i * .84), 0, -.30 + i * .10))
			bag.rotation.y = side * -.10
			if i % 2 == 0:
				asset("sandbag", bag.position + Vector3(.15 * side, .32, 0))
		for i in 4:
			var crate := asset("crate", Vector3(side * 5.35, 0, 1.2 + i * 1.1))
			crate.rotation.y = i * .35
		for i in 5:
			var tree := Node3D.new()
			add_child(tree)
			tree.position = Vector3(side * (8.2 + (i % 2) * 1.5), 0, -10 + i * 4.3)
			cylinder(tree.position + Vector3(0, .5, 0), .13, 1.0, "6c6e62")
			for tier in 3:
				var pine := CylinderMesh.new()
				pine.top_radius = 0.05
				pine.bottom_radius = 1.0 - tier * .22
				pine.height = 1.15
				var n := mesh(pine, tree.position + Vector3(0, 1.0 + tier * .7, 0), "a6b9b7" if tier < 2 else "d9e2de")
				n.rotation.y = i
	hq = asset("headquarters", Vector3(0, 0, 6.35))
	hq.rotation.y = PI
	sentry = asset("sentry", Vector3(0, 0, .6))
	var flagpole := cylinder(Vector3(-1.7, 1.25, 5.9), .045, 2.5, "666e64")
	flagpole.name = "BaseFlagpole"
	box(Vector3(-1.34, 2.2, 5.9), Vector3(.67, .40, .035), "e0b62a")
	var points: Array = state.definition.layout.pads if campaign else R.PADS.map(func(p): return [p.x, p.y])
	for i in points.size():
		var point := Vector3(points[i][0], 0, points[i][1])
		var pad := box(point + Vector3(0, .045, 0), Vector3(1.42, .07, 1.10), "667c58")
		pads.append(pad)
		var station := asset("equipment", point + Vector3(0, 0, -.22))
		stations.append(station)
		pad_labels.append(label3("", point + Vector3(0, .12, .62), 25))
		if i < 4:
			for j in 3:
				cylinder(point + Vector3(0, .02, .8 + j * .32), .065, .025, "818571")
	if campaign:
		for point in state.definition.relays:
			cylinder(Vector3(point[0], .04, point[1]), .75, .06, "759595")
			cylinder(Vector3(point[0], .8, point[1]), .055, 1.6, "727c6e")
			relay_labels.append(label3("RELAY", Vector3(point[0], 1.9, point[1]), 24))
	available = state.definition.available if campaign else ["rifle", "vehicle"]
	scene_hash = state.get("definition_hash", "legacy")
	sync(state, false, false, 0)

func mat(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		materials[color] = Actor.material(Color(color))
	return materials[color]

func mesh(shape: Mesh, point: Vector3, color: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.position = point
	n.material_override = mat(color)
	add_child(n)
	return n

func box(point: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(shape, point, color)

func cylinder(point: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	return mesh(shape, point, color)

func asset(id: String, point: Vector3) -> Node3D:
	var n := (load("res://art/models/" + id + ".glb") as PackedScene).instantiate() as Node3D
	Actor.finish_materials(n)
	add_child(n)
	n.position = point
	return n

func label3(text: String, point: Vector3, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = point
	l.font_size = size
	l.pixel_size = .009
	l.outline_size = 4
	l.modulate = Color("fff1c8")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)
	return l

func fit(view: Vector2) -> void:
	# Camera KEEP_HEIGHT preserves vertical composition; width expands on Fold.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = maxf(20.2, 11.9 * view.y / view.x)

func sync(state: Dictionary, is_paused: bool, reduced_effects: bool, dt: float) -> void:
	reduced = reduced_effects
	var was_paused: bool = adapter.paused
	var reset := adapter.ingest(state, is_paused, dt)
	if reset:
		# Production order is tick -> queue -> sync. Preserve only the newly earned
		# resume batch; pause sync has already discarded the previous epoch's queue.
		var earned_resume: Array = pending.duplicate(true) if was_paused and not is_paused else []
		clear_transients()
		pending = earned_resume
		for key in corpses:
			corpses[key].node.queue_free()
		corpses.clear()
	for key in adapter.current:
		var data: Dictionary = adapter.current[key]
		var created := false
		if not units.has(key):
			var unit := Actor.new()
			add_child(unit)
			unit.configure(data.role, data.team, float(key.hash() % 100) * .15)
			units[key] = unit
			unit.position = data.position
			created = true
		units[key].set_snapshot(data, reset or created)
		units[key].visible = data.team != "ally" or data.role in available
	for key in units.keys():
		if not adapter.current.has(key):
			var n: Node3D = units[key]
			var id := int(key.get_slice(":", 1))
			if key.begins_with("enemy:") and id in state.killed and not reset:
				n.death_time = 0
				corpses[str(adapter.epoch) + ":" + key] = {"node": n, "left": .85}
			else:
				n.queue_free()
			units.erase(key)
	for i in stations.size():
		var bought: bool = state.support != "none" if campaign and i == 4 else (state.bought[i] > 0 if campaign else state.pads[i])
		stations[i].visible = bought
		var price: int = (state.definition.support_cost if i == 4 else state.definition.unit[D.ROLES[i]].cost) if campaign else R.COSTS[i]
		var near: bool = Vector2(state.x, state.z).distance_to(Vector2(pads[i].position.x, pads[i].position.z)) < 1.6
		pad_labels[i].text = str(price) + " • " + (state.planned_support.to_upper() if i == 4 else D.ROLES[i].to_upper()) if campaign else str(price) + (" RIFLE" if i == 0 else " ROVER")
		pad_labels[i].visible = near and (not campaign or i == 4 or D.ROLES[i] in available)
	for i in relay_labels.size():
		relay_labels[i].text = "%d%%" % int(100 * state.captures[i] / state.definition.capture_seconds)
	sync_pickups(state)
	sync_warnings(state)
	if not is_paused:
		for event in pending:
			if adapter.accept(event):
				present_event(event)
	pending.clear()

func sync_pickups(state: Dictionary) -> void:
	var alive := {}
	for coin in state.coins:
		var id := int(coin.id)
		alive[id] = true
		if not pickups.has(id):
			var n := asset("crate", Vector3(coin.x, .015, coin.z)) if id >= 200 else cylinder(Vector3(coin.x, .13, coin.z), .20, .15, "eabe32")
			if id < 200:
				n.rotation_degrees.x = 65
			pickups[id] = n
	for id in pickups.keys():
		if not alive.has(id):
			pickups[id].queue_free()
			pickups.erase(id)

func sync_warnings(state: Dictionary) -> void:
	var live := {}
	for mark in state.get("marks", []):
		var key := "%s:%.4f:%.4f" % [mark.source, mark.x, mark.z]
		live[key] = true
		if not warnings.has(key):
			var ring := TorusMesh.new()
			ring.inner_radius = 1.14
			ring.outer_radius = 1.25
			ring.rings = 24
			ring.ring_segments = 8
			warnings[key] = mesh(ring, Vector3(mark.x, .07, mark.z), "e44d39")
		warnings[key].scale.y = .30
	for enemy in state.enemies:
		if enemy.get("role", "") == "drill" and enemy.get("telegraph", 0) > 0:
			var key := "drill:" + str(int(enemy.id))
			live[key] = true
			if not warnings.has(key):
				var ring := TorusMesh.new()
				ring.inner_radius = 1.90
				ring.outer_radius = 2.0
				ring.rings = 32
				ring.ring_segments = 8
				warnings[key] = mesh(ring, Vector3(enemy.x, .08, enemy.z + 1.8), "e44d39")
			warnings[key].scale.y = .25
	for key in warnings.keys():
		if not live.has(key):
			warnings[key].queue_free()
			warnings.erase(key)

func queue_events(events: Array) -> void:
	for event in events:
		pending.append(event.duplicate(true))

func present_event(event: Dictionary) -> void:
	if event.kind == "repair":
		routed.repair += 1
		pulse(Vector3(event.to[0], .3, event.to[1]), "91bf80", .35)
		return
	if event.kind not in ["shot", "incoming"]:
		return
	var subtype: String = event.get("effect", "projectile")
	routed[subtype] = int(routed.get(subtype, 0)) + 1
	var shooter: String = event.get("actor", "")
	var attack: String = str(adapter.epoch) + ":" + event.get("attack", "")
	var destination := Vector3(event.to[0], .75, event.to[1])
	if not attacks_seen.has(attack):
		attacks_seen[attack] = true
		if attacks_seen.size() > 256:
			attacks_seen.erase(attacks_seen.keys()[0])
		attacks_emitted += 1
		if units.has(shooter) and subtype == "projectile":
			units[shooter].fire(destination)
		if not reduced and subtype == "projectile":
			var origin := Vector3(event.from[0], .8, event.from[1])
			if units.has(shooter):
				# Apply aim before sampling the weapon socket, without advancing time.
				units[shooter].pose(0, Vector3.ZERO, false)
				if units[shooter].rig != null:
					units[shooter].rig.force_update_all_bone_transforms()
				origin = units[shooter].muzzle.global_position
			elif shooter == "sentry":
				sentry.rotation.y = atan2(-(destination.x - sentry.position.x), -(destination.z - sentry.position.z))
				origin = sentry.to_global(Vector3(0, .61, -.66))
			tracer(origin, destination, "ffd36e" if event.kind == "shot" else "f5906a")
		elif subtype != "projectile":
			pulse(Vector3(event.to[0], .10, event.to[1]), "e06e43", .28)
	if event.kind == "incoming" and int(event.recipient) == -2:
		hq_hit_left = .22
		routed.hq += 1
		pulse(Vector3(0, .15, 5.4), "e7a556", .3)
		return
	var victim: String = "enemy:" + str(int(event.enemy)) if event.kind == "shot" else ("commander" if int(event.recipient) == -1 else "recruit:" + str(int(event.recipient)))
	if units.has(victim):
		units[victim].hit()
	# A killed target is already removed by authoritative rules; its retained rig reacts.
	var corpse_key := str(adapter.epoch) + ":" + victim
	if corpses.has(corpse_key):
		corpses[corpse_key].node.hit()

func pulse(point: Vector3, color: String, radius: float) -> void:
	if effects.size() >= 36:
		return
	var ring := TorusMesh.new()
	ring.inner_radius = radius * .75
	ring.outer_radius = radius
	ring.rings = 16
	ring.ring_segments = 6
	var n := mesh(ring, point, color)
	n.scale.y = .25
	effects.append({"node": n, "left": .18})
	effects_emitted += 1

func tracer(from: Vector3, to: Vector3, color: String) -> void:
	if effects.size() >= 36 or from.distance_squared_to(to) < .01:
		return
	var shape := BoxMesh.new()
	shape.size = Vector3(.025, .025, from.distance_to(to))
	var n := mesh(shape, (from + to) * .5, color)
	n.look_at(to)
	effects.append({"node": n, "left": .055})
	effects_emitted += 1

func clear_transients() -> void:
	pending.clear()
	attacks_seen.clear()
	hq_hit_left = 0
	hq.rotation.z = 0
	for effect in effects:
		effect.node.queue_free()
	effects.clear()
	for key in units:
		units[key].reset_transients()

func _process(dt: float) -> void:
	var alpha := adapter.advance(dt)
	if adapter.paused:
		return
	hq_hit_left = maxf(0, hq_hit_left - dt)
	hq.rotation.z = sin(hq_hit_left / .22 * PI) * .025
	for key in units:
		if not adapter.current.has(key):
			continue
		var current: Dictionary = adapter.current[key]
		var previous: Dictionary = adapter.previous.get(key, current)
		var velocity: Vector3 = (current.position - previous.position) / adapter.interval
		if adapter.phase != "playing":
			velocity = Vector3.ZERO
		units[key].position = previous.position.lerp(current.position, alpha)
		units[key].pose(dt, velocity, adapter.phase == "victory" and current.team != "enemy")
	for key in corpses.keys():
		corpses[key].node.pose(dt, Vector3.ZERO, false)
		corpses[key].left -= dt
		if corpses[key].left <= 0:
			corpses[key].node.queue_free()
			corpses.erase(key)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].left -= dt
		if effects[i].left <= 0:
			effects[i].node.queue_free()
			effects.remove_at(i)
