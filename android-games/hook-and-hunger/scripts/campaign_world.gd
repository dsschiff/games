extends RefCounted
const Art = preload("res://scripts/art.gd")

static func build(host: Node3D, state: Dictionary) -> Dictionary:
	var d: Dictionary = state.definition
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("0b293b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("bdd7df")
	env.environment.ambient_light_energy = 0.4
	host.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, -10)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	host.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.7
	host.add_child(camera)
	host.add_child(Art.box(Vector3(100, 0.2, 110), Color("16495f"), Vector3(0, -1.2, 0)))
	host.add_child(Art.box(Vector3(14, 1, 22), Color("2c4b5d"), Vector3(0, -0.5, -2)))
	for x in 7:
		for z in 11:
			var color := Color(d.color).darkened(0.045 if (x + z) % 2 == 0 else 0)
			host.add_child(Art.box(Vector3(1.98, 0.2, 1.98), color, Vector3(-6 + x * 2, 0, -12 + z * 2)))
	for b in d.obstacles:
		host.add_child(Art.cylinder(b.radius, 0.9, Color(d.color).darkened(0.33), Vector3(b.x, 0.45, b.z), b.radius * 0.72))
		var crystal := Art.cylinder(0.26, 1.2, Color("8ce4de"), Vector3(b.x, 1.0, b.z), 0)
		crystal.rotation.z = 0.25
		host.add_child(crystal)
	for side in [-1, 1]:
		for z in range(-12, 9, 2):
			host.add_child(Art.box(Vector3(0.2, 0.7, 0.2), Color("486879"), Vector3(side * 6.8, 0.4, z)))
			host.add_child(Art.cylinder(0.35, 1.2, Color(d.color).darkened(0.3), Vector3(side * 8.4, -0.2, z), 0.05))
		host.add_child(Art.box(Vector3(0.1, 0.1, 21), Color("81969a"), Vector3(side * 6.8, 0.65, -2)))
		for i in 3:
			var fin := Art.box(Vector3(0.4, 2 + i, 2.2), Color(d.color).darkened(0.35), Vector3(side * (8.5 + i * 0.4), 0, -5 - i * 3))
			fin.rotation.z = side * 0.3
			host.add_child(fin)
	host.add_child(Art.box(Vector3(13, 0.12, 3.2), Color("4e7279"), Vector3(0, 0.15, 7)))
	var gate := Node3D.new()
	gate.position.z = 4.85
	host.add_child(gate)
	for x in [-3.5, 0, 3.5]:
		gate.add_child(Art.box(Vector3(0.2, 1.5, 0.2), Color("f3b484"), Vector3(x, 0.8, 0)))
	gate.add_child(Art.box(Vector3(13, 0.18, 0.18), Color("f3b484"), Vector3(0, 1.3, 0)))
	gate.add_child(Art.label("POWER " + str(d.weapons[int(d.required_tier)].power), Vector3(0, 2.0, 0), 34))
	var pad := Art.ring(1.5, Color("8bedd5"))
	pad.position = Vector3(0, 0.25, 6.8)
	host.add_child(pad)
	host.add_child(Art.cylinder(0.75, 0.35, Color("2b5062"), Vector3(0, 0.3, 6.8)))
	var tier: int = int(d.offer) if d.offer > 0 else int(state.tier)
	var preview := Art.blade(tier)
	preview.position = Vector3(0, 1.05, 6.8)
	preview.rotation_degrees.x = 60
	host.add_child(preview)
	host.add_child(Art.label("FORGE / REPAIR", Vector3(-3.2, 1.0, 7), 23))
	var player := Art.diver()
	host.add_child(player)
	var reach := Art.ring(3.6, Color("a9c6b4"))
	host.add_child(reach)
	var chain: Array[MeshInstance3D] = []
	for i in 18:
		var link := Art.ring(0.095, Color("223e52"))
		link.rotation_degrees.x = 90
		host.add_child(link)
		chain.append(link)
	return {"camera": camera, "gate": gate, "pad": pad, "preview": preview, "player": player, "reach": reach, "chain": chain}
