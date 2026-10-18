extends Node3D
const Adapter = preload("res://scripts/presentation/adapter.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const D = preload("res://scripts/definitions.gd")
const R = preload("res://scripts/rules.gd")
const Regions = preload("res://scripts/presentation/regions.gd")
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
var region := {}
var relay_rings: Array[MeshInstance3D] = []
var visual_steps: Array = []
var hq_socket: Marker3D

func build(state: Dictionary) -> void:
	campaign = int(state.catalog) == 2
	region = Regions.describe(state)
	adapter.reset(state, false)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c5d1cf")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dbe7e4")
	env.ambient_light_energy = .38 if region.terrain == "night" else .30
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
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = .65
	sun.shadow_opacity = .48
	sun.shadow_blur = 2.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38, 145, 0)
	fill.light_color = Color("a9c5dd") if region.terrain == "night" else Color("cad9e0")
	fill.light_energy = .22
	fill.shadow_enabled = false
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = 80.0
	camera.position = Vector3(0, 20, 17)
	add_child(camera)
	camera.look_at(Vector3(0, 0, .35))
	camera.current = true
	# Continuous terrain beyond the authored rules rectangle; no floating board.
	box(Vector3(0, -.42, 0), Vector3(90, .8, 90), region.ground)
	for spec in [[-3.5, -5.8, 1.6], [3.1, -3.8, 1.3], [0.8, -7.7, 1.1], [-4.0, 1.5, .9]]:
		var patch := cylinder(Vector3(spec[0], -.009, spec[1]), spec[2], .012, Color(region.ground).darkened(.045).to_html(false))
		patch.scale.z = .55
		patch.rotation.y = spec[1] * .3
	box(Vector3(0, .001, 3.1), Vector3(1.5, .012, 6.0), region.path)
	build_region()
	for side in [-1, 1]:
		for i in 3:
			var stone := asset("cliff", Vector3(side * 5.45, .03, -7.5 + i * 2.3))
			stone.scale = Vector3(.33, .40, .36)
			stone.rotation.y = i * 1.7
		for i in 8:
			var cliff := asset("cliff", Vector3(side * (6.7 + sin(i * 2.1) * .45), .45, -11.0 + i * 2.55))
			cliff.rotation.y = i * .57
			cliff.scale = Vector3(1.1 + (i % 3) * .2, 1.5 + (i % 2) * .6, 1.3)
		for i in 5:
			var bag := asset("sandbag", Vector3(side * (1.35 + i * .84), 0, -.30 + i * .10))
			bag.rotation.y = side * -.10
			if i % 2 == 0:
				asset("sandbag", bag.position + Vector3(.15 * side, .32, 0))
			visual_steps.append({"point": Vector2(bag.position.x, bag.position.z), "height": .72 if i % 2 == 0 else .40, "extent": Vector2(.44, .24)})
		for i in 4:
			var crate := asset("crate", Vector3(side * 5.35, 0, 1.2 + i * 1.1))
			crate.rotation.y = i * .35
		for i in (4 if region.terrain in ["snow", "ridge", "night"] else 0):
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
	hq = asset("headquarters", Vector3(0, 0, 7.2))
	hq.rotation.y = PI
	hq_socket = Marker3D.new()
	hq.add_child(hq_socket)
	hq_socket.position = Vector3(0, .6, .45)
	sentry = asset("sentry", Vector3(0, 0, .6))
	var flagpole := cylinder(Vector3(-1.7, 1.25, 5.9), .045, 2.5, "666e64")
	flagpole.name = "BaseFlagpole"
	box(Vector3(-1.34, 2.2, 5.9), Vector3(.67, .40, .035), "e0b62a")
	var points: Array = state.definition.layout.pads if campaign else R.PADS.map(func(p): return [p.x, p.y])
	for i in points.size():
		var point := Vector3(points[i][0], 0, points[i][1])
		var pad := asset("station_pad", point)
		pads.append(pad)
		var role: String = (D.ROLES[i] if i < 4 else state.planned_support) if campaign else ("rifle" if i == 0 else "rover")
		var station := asset("station_" + role, point + Vector3(0, 0, -.65))
		station.set_meta("role", role)
		stations.append(station)
		pad_labels.append(label3("", point + Vector3(0, .12, .62), 25))
		if i < 4:
			for j in 3:
				cylinder(point + Vector3(0, .02, .8 + j * .32), .065, .025, "818571")
	if campaign:
		for point in state.definition.relays:
			var ring := TorusMesh.new()
			ring.inner_radius = .66
			ring.outer_radius = .74
			ring.rings = 24
			ring.ring_segments = 6
			var n := mesh(ring, Vector3(point[0], .035, point[1]), region.accent)
			n.scale.y = .25
			relay_rings.append(n)
			cylinder(Vector3(point[0], .8, point[1]), .055, 1.6, "727c6e")
			relay_labels.append(label3("RELAY", Vector3(point[0], 1.9, point[1]), 24))
	available = state.definition.available if campaign else ["rifle", "vehicle"]
	scene_hash = state.get("definition_hash", "legacy")
	sync(state, false, false, 0)

func build_region() -> void:
	# All opaque landmarks stay outside the existing playable rectangle. Low
	# painted tracks/deck lines remain traversable; they never add collision.
	for side in [-1, 1]:
		var landmark := asset(region.landmark, Vector3(side * 5.9, 0, -4.5 if side < 0 else 1.0))
		landmark.rotation.y = side * .45
		if region.landmark in ["bridge_arch", "floodgate", "quarry_crane", "repair_gantry"]:
			landmark.scale = Vector3.ONE * .75
	var horizon := asset(region.landmark, Vector3(-3.4, 0, -7.4))
	horizon.rotation.y = -.35
	horizon.scale = Vector3.ONE * .72
	if region.terrain == "rail":
		for x in [-2.7, 2.7]:
			for offset in [-.23, .23]:
				box(Vector3(x + offset, .004, -4.9), Vector3(.055, .015, 7.0), "83918a")
			for j in 9:
				box(Vector3(x, .002, -7.9 + j * .75), Vector3(.8, .008, .12), "929381")
	elif region.terrain in ["bridge", "causeway"]:
		for side in [-1, 1]:
			box(Vector3(side * 8.8, -.06, -.2), Vector3(5.0, .08, 23), "7faaa7")
		for j in 11:
			box(Vector3(0, .002, -6.8 + j * .85), Vector3(9.7, .007, .045), Color(region.path).darkened(.12).to_html(false))
	elif region.terrain in ["depot", "supply", "foundry"]:
		for side in [-1, 1]:
			for j in 3:
				var crate := asset("crate", Vector3(side * 5.5, .0, -5.5 + j * 1.0))
				crate.rotation.y = j * .2
	elif region.terrain == "orchard":
		for side in [-1, 1]:
			for j in 3:
				var tree := asset("orchard_tree", Vector3(side * 6.5, 0, -9.0 + j * 3))
				tree.scale = Vector3.ONE * .8
	if region.style == "siege":
		for side in [-1, 1]:
			asset("watchtower", Vector3(side * 7.5, 0, -8.0))
	elif region.style == "flank":
		for side in [-1, 1]:
			asset("relay_mast", Vector3(side * 7.0, 0, -7.0))

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
	var n := Actor.instantiate_model("res://art/models/" + id + ".glb")
	Actor.finish_materials(n, {"Rock": Color(region.rock), "Snow": Color(region.cap), "WorldStone": Color(region.rock)})
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
		if reset or created:
			units[key].position = data.position
			units[key].position.y = ground_height(units[key].position)
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
		if campaign and i == 4 and stations[i].get_meta("role") != state.planned_support:
			stations[i].queue_free()
			stations[i] = asset("station_" + state.planned_support, pads[i].position + Vector3(0, 0, -.65))
			stations[i].set_meta("role", state.planned_support)
			stations[i].visible = bought
		var stock: int = state.stock[i] if i < state.stock.size() else 0
		for token in stations[i].find_children("SupplyToken*", "MeshInstance3D", true, false):
			token.visible = int(str(token.name).trim_prefix("SupplyToken")) < stock
		var price: int = (state.definition.support_cost if i == 4 else state.definition.unit[D.ROLES[i]].cost) if campaign else R.COSTS[i]
		var near: bool = Vector2(state.x, state.z).distance_to(Vector2(pads[i].position.x, pads[i].position.z)) < 1.6
		pad_labels[i].text = str(price) + " • " + (state.planned_support.to_upper() if i == 4 else D.ROLES[i].to_upper()) if campaign else str(price) + (" RIFLE" if i == 0 else " ROVER")
		pad_labels[i].visible = false
	for i in relay_labels.size():
		relay_labels[i].text = "%d%%" % int(100 * state.captures[i] / state.definition.capture_seconds)
		relay_labels[i].visible = Vector2(state.x, state.z).distance_to(Vector2(state.definition.relays[i][0], state.definition.relays[i][1])) < 1.4
		relay_rings[i].material_override = mat("95bb71" if state.captures[i] >= state.definition.capture_seconds else region.accent)
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
			var n := asset("crate" if id >= 200 else "scrap_coin", Vector3(coin.x, .015, coin.z))
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
		var source: String = event.get("actor", "")
		if units.has(source):
			units[source].repair(Vector3(event.to[0], .7, event.to[1]))
		pulse(Vector3(event.to[0], .3, event.to[1]), "91bf80", .35)
		return
	if event.kind not in ["shot", "incoming"]:
		return
	var subtype: String = event.get("effect", "projectile")
	routed[subtype] = int(routed.get(subtype, 0)) + 1
	var shooter: String = event.get("actor", "")
	var attack: String = str(adapter.epoch) + ":" + event.get("attack", "")
	var destination := hq_socket.global_position if event.kind == "incoming" and int(event.recipient) == -2 else Vector3(event.to[0], .75, event.to[1])
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
		pulse(hq_socket.global_position, "e7a556", .3)
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
		units[key].position.y = ground_height(units[key].position)
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

func ground_height(point: Vector3) -> float:
	var height := 0.0
	for pad in pads:
		var x := absf(point.x - pad.position.x)
		var z := absf(point.z - pad.position.z)
		height = maxf(height, .086 * (1 - smoothstep(.55, .73, x)) * (1 - smoothstep(.38, .58, z)))
	for step in visual_steps:
		var distance: Vector2 = Vector2(point.x, point.z) - step.point
		var weight := (1 - smoothstep(step.extent.x, step.extent.x + .25, absf(distance.x))) * (1 - smoothstep(step.extent.y, step.extent.y + .35, absf(distance.y)))
		height = maxf(height, float(step.height) * weight)
	return height
