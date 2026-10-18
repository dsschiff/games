extends RefCounted
const Kit = preload("res://scripts/presentation/kit.gd")
const Art = preload("res://scripts/art.gd")
const Rules = preload("res://scripts/engine.gd")
const PASSAGES := [
	["Buoy Channel", "buoy", "palm", "boat"],
	["Broken Causeway", "rock", "buoy", "wreck"],
	["Saltglass Beacon", "beacon", "palm", "rock"],
	["Kiln Landing", "kiln_arch", "coral", "boat"],
	["Crabworks", "forge", "kiln_arch", "coral"],
	["Cinder Beacon", "beacon", "kiln_arch", "rock"],
	["Lantern Sound", "buoy", "wreck", "palm"],
	["Split Hulls", "wreck", "boat", "buoy"],
	["Wreck Beacon", "beacon", "wreck", "buoy"],
	["Crown Approach", "crystal_spire", "rock", "boat"],
	["Crystal Choir", "crystal_spire", "buoy", "coral"],
	["Glasswater Crown", "beacon", "crystal_spire", "boat"]
]
const CLUSTERS := [
	[[-9.4, -7, .3], [10.2, -2, -.5], [-10, 5, .1]],
	[[9.7, -7.6, -.6], [-9.6, -1.2, .3], [10.5, 5, .7]],
	[[-10, -8, .1], [10.7, -3.1, -.4], [-10.3, 4.2, .4]],
	[[10, -7, .4], [-10.2, -.9, -.4], [10, 5.5, .1]],
	[[-9.7, -6.8, -.5], [10.5, -2.6, .2], [-10, 4.8, .6]],
	[[10, -7.8, -.2], [-10, -1.4, .6], [10.2, 4.5, -.4]],
	[[-10, -7.5, .5], [10, -2, -.6], [-10, 5, -.3]],
	[[10, -6.4, -.7], [-10, -2.5, .4], [10.4, 5, .3]],
	[[-10, -8.4, .4], [10.5, -1.5, -.4], [-10.1, 4.3, .1]],
	[[10, -7, -.3], [-10, -1.1, .5], [10.3, 5, -.5]],
	[[-10, -6.8, .2], [10.5, -2.3, -.3], [-10, 4.2, .6]],
	[[10, -8, -.4], [-10, -2.0, .4], [10.3, 5, .2]]
]
var host: Node3D
var kit: RefCounted
var scenic: Array[Node3D] = []
var clearance := AABB()
var beacon_lenses: Array[Node3D] = []
var fleet: Array[Node3D] = []
var fleet_rest: Array[Transform3D] = []
var beacon_lights: Array[Node3D] = []
var ending_clock := 0.0
var stage := -1
var gate: Node3D
var preview: Node3D
var pad: MeshInstance3D
var camera: Camera3D
var dock_label: Label3D

func build(owner: Node3D, assets: RefCounted, state: Dictionary) -> void:
	host = owner
	kit = assets
	stage = int(state.definition.stage) if state.schema == 2 else -1
	var region := int(stage / 3) if stage >= 0 else 0
	var palette := ["74b9b3", "81b8b2", "79acb8", "9ac0c6"]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c7dbd6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d0ded3")
	env.environment.ambient_light_energy = .64
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	host.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -32, -15)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	sun.shadow_bias = .04
	host.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	camera.far = 150
	host.add_child(camera)
	var ocean := Art.box(Vector3(150, .20, 160), Color(palette[region]), Vector3(0, -1.18, -15))
	host.add_child(ocean)
	var terrain: Node3D = kit.asset("terrain_" + str(region))
	terrain.position.z = -2 if stage >= 0 else -6
	if stage < 0:
		terrain.scale.z = 1.40
	host.add_child(terrain)
	# Rule centers extend to x=6.0 for enemies; allow a conservative 2.6m
	# articulated boss envelope, including the longest raised lance and crown.
	clearance = AABB(Vector3(-8.6, -.02, -14.6), Vector3(17.2, 8, 24.6)) if stage >= 0 else AABB(Vector3(-7.8, -.02, -22), Vector3(15.6, 8, 32))
	for b in Rules.obstacles(state):
		var rock: Node3D = kit.asset("rock")
		rock.position = Vector3(b.x, .0, b.y)
		rock.scale = Vector3.ONE * b.z / .80
		host.add_child(rock)
	for side in [-1, 1]:
		# Low inlaid navigation edge marks the unchanged invisible rule boundary.
		host.add_child(Art.box(Vector3(.035, .015, 21 if stage >= 0 else 29), Color("9faca2"), Vector3(side * (6.6 if stage >= 0 else 6), .012, -2 if stage >= 0 else -6)))
	var low := -12 if stage >= 0 else -19
	for side in [-1, 1]:
		for z in range(low, 9, 2):
			var fence: Node3D = kit.asset("fence")
			fence.position = Vector3(side * (9.05 if stage >= 0 else 8.2), 0, z)
			fence.rotation.y = PI / 2
			host.add_child(fence)
		for i in 6:
			outside("coral" if region == 1 else "palm", Vector3(side * (9.0 + .4 * (i % 3)), -.7, -13 + i * 4.1), .45 + .11 * (i % 3), i * .8)
	var row: Array = PASSAGES[maxi(0, stage)]
	var clusters: Array = CLUSTERS[maxi(0, stage)]
	for i in 3:
		var c: Array = clusters[i]
		outside(str(row[i + 1]), Vector3(c[0], -.05, c[1]), 1, c[2])
	# Far silhouettes provide depth without placing opaque scenery across combat.
	for i in 4:
		outside(["beacon", "kiln_arch", "wreck", "crystal_spire"][region], Vector3(-17 + i * 11, -.60, low - 6.5 - (i % 2) * 3), .80 + .17 * i, -.4 + i * .37)
	if stage < 0:
		for side in [-1, 1]:
			for x in [3.6, 5.4]:
				var divider: Node3D = kit.asset("fence")
				divider.position = Vector3(side * x, 0, -6.5)
				host.add_child(divider)
	gate = Node3D.new()
	gate.position.z = 4.85 if stage >= 0 else -6.5
	host.add_child(gate)
	var door: Node3D = kit.asset("door")
	door.scale.x = 4.3 if stage >= 0 else 1.0
	gate.add_child(door)
	var power := int(state.definition.weapons[int(state.definition.required_tier)].power) if stage >= 0 else 200
	gate.add_child(Art.label("POWER " + str(power), Vector3(0, 1.9, 0), 30))
	var forge: Node3D = kit.asset("forge")
	forge.position = Vector3(0, 0, 6.8)
	host.add_child(forge)
	pad = Art.ring(1.55, Color("69c6a9"))
	pad.position = Vector3(0, .045, 6.8)
	host.add_child(pad)
	var tier := int(state.definition.offer) if stage >= 0 and state.definition.offer > 0 else maxi(1, int(state.tier))
	preview = kit.asset("weapon_" + str(tier))
	preview.position = Vector3(0, 1.12, 6.8)
	preview.rotation_degrees.x = 40
	host.add_child(preview)
	dock_label = Art.label("FORGE / REPAIR", Vector3(-3.4, .65, 7.5), 21)
	host.add_child(dock_label)
	if stage == 11:
		for i in 4:
			var beacon := outside("beacon", Vector3(-13.5 + i * 9, 0, -19), .8, 0)
			beacon_lenses.append(beacon)
			var light := Art.sphere(.25, Color("efca8b"), Vector3(0, 1.65, 0))
			light.material_override = Art.material(Color("efca8b"), true)
			beacon.add_child(light)
			light.hide()
			beacon_lights.append(light)
		for i in 3:
			fleet.append(outside("boat", Vector3(11 + i * 2, -.65, 2 - i * 4), .8, .4))
			fleet_rest.append(fleet[-1].transform)

func outside(key: String, at: Vector3, size: float, yaw: float) -> Node3D:
	var node: Node3D = kit.asset(key)
	host.add_child(node)
	node.position = at
	node.scale = Vector3.ONE * size
	node.rotation.y = yaw
	var bounds := Kit.bounds(node, host)
	# Whole transformed bounds, including crowns/sails, must clear every actor.
	if bounds.intersects(clearance):
		if absf(at.x) > 6:
			var shift := clearance.end.x - bounds.position.x + .25 if at.x > 0 else clearance.position.x - bounds.end.x - .25
			node.position.x += shift
		else:
			node.position.z -= bounds.end.z - clearance.position.z + .25
	assert(not Kit.bounds(node, host).intersects(clearance))
	node.set_meta("scenic_key", key)
	scenic.append(node)
	return node

func update(state: Dictionary, dt: float, reduced: bool) -> void:
	gate.visible = state.tier == 0 if state.schema == 1 else state.tier < state.definition.required_tier
	preview.visible = state.tier == 0 if state.schema == 1 else Rules.cost(state) > 0
	if not reduced:
		preview.rotation.y += dt * .65
	dock_label.text = "FORGE • " + str(Rules.cost(state)) if Rules.cost(state) > 0 else "DOCK • FREE REPAIR"
	if stage == 11:
		ending_clock = ending_clock + dt if state.phase == "victory" else 0.0
		for light in beacon_lights:
			light.visible = state.phase == "victory"
		for i in fleet.size():
			fleet[i].position = fleet_rest[i].origin + Vector3(minf(7, ending_clock * .35), 0, -minf(5, ending_clock * .28))

func reset_transients() -> void:
	ending_clock = 0
	preview.rotation.y = 0
	for i in fleet.size():
		fleet[i].transform = fleet_rest[i]
	for light in beacon_lights:
		light.hide()
