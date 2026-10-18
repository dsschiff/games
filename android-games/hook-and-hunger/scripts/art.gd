extends RefCounted
## Original procedural low-poly salvage equipment and crystal sea life.

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.72
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.5
	return m

static func mesh(shape: Mesh, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = material(color)
	return n

static func box(size: Vector3, color: Color, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var n := mesh(shape, color)
	n.position = at
	return n

static func sphere(radius: float, color: Color, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 12
	shape.rings = 6
	var n := mesh(shape, color)
	n.position = at
	return n

static func cylinder(radius: float, height: float, color: Color, at: Vector3 = Vector3.ZERO, top: float = -1) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top < 0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 8
	var n := mesh(shape, color)
	n.position = at
	return n

static func ring(radius: float, color: Color) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - 0.045
	shape.outer_radius = radius + 0.045
	shape.rings = 32
	shape.ring_segments = 6
	return mesh(shape, color)

static func label(text: String, at: Vector3, size: int = 42) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.013
	l.outline_size = 8
	l.modulate = Color("fff1d7")
	l.position = at
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l

static func diver() -> Node3D:
	var n := Node3D.new()
	n.add_child(cylinder(0.34, 0.68, Color("f5bb69"), Vector3(0, 0.88, 0)))
	n.add_child(sphere(0.4, Color("ffe0a5"), Vector3(0, 1.5, 0)))
	n.add_child(box(Vector3(0.57, 0.26, 0.17), Color("123b4b"), Vector3(0, 1.51, 0.32)))
	n.add_child(box(Vector3(0.39, 0.08, 0.03), Color("8ef4e2"), Vector3(0, 1.56, 0.42)))
	n.add_child(cylinder(0.19, 0.7, Color("33596a"), Vector3(0, 0.9, -0.35)))
	for side in [-1, 1]:
		n.add_child(box(Vector3(0.2, 0.38, 0.22), Color("223e50"), Vector3(side * 0.2, 0.35, 0)))
		n.add_child(box(Vector3(0.25, 0.12, 0.55), Color("f4bd6d"), Vector3(side * 0.2, 0.12, 0.13)))
		n.add_child(sphere(0.17, Color("f5bb69"), Vector3(side * 0.42, 0.9, 0.12)))
	return n

static func creature(role: String) -> Node3D:
	var n := Node3D.new()
	var boss := role == "bellkeeper"
	var color := Color("e397cf") if boss else (Color("8c9ee5") if role == "lancer" else Color("5ec7bf"))
	var radius := 0.88 if boss else 0.43
	n.add_child(cylinder(radius, radius * 1.8, color, Vector3(0, radius, 0), radius * 0.55))
	for i in (7 if boss else 4):
		var a := float(i) * TAU / (7 if boss else 4)
		var shard := cylinder(radius * 0.26, radius * 1.8, color.lightened(0.22), Vector3(cos(a) * radius * 0.6, radius * 1.9, sin(a) * radius * 0.6), 0)
		shard.rotation.z = sin(a) * 0.4
		n.add_child(shard)
	for side in [-1, 1]:
		n.add_child(sphere(radius * 0.14, Color("162f45"), Vector3(side * radius * 0.4, radius * 1.1, radius * 0.8)))
		n.add_child(box(Vector3(radius * 0.7, 0.16, radius * 0.4), color.darkened(0.2), Vector3(side * radius, 0.16, 0)))
	if role == "lancer":
		n.add_child(cylinder(0.17, 1.3, Color("d2e8ff"), Vector3(0.55, 1.1, 0), 0))
	if boss:
		n.add_child(ring(1.0, Color("f5d095")))
	return n

static func blade(tier: int) -> Node3D:
	var n := Node3D.new()
	var color := Color("f4b579") if tier == 0 else Color("7ef3cd")
	var scale_factor := 0.75 if tier == 0 else 1.25
	n.add_child(box(Vector3(0.16, 0.13, 0.85) * scale_factor, Color("254c5b")))
	var cross := box(Vector3(0.8, 0.16, 0.23) * scale_factor, color, Vector3(0, 0, 0.25 * scale_factor))
	cross.rotation.y = 0.2
	n.add_child(cross)
	for side in [-1, 1]:
		var tip := box(Vector3(0.23, 0.17, 0.48) * scale_factor, color.lightened(0.12), Vector3(side * 0.36 * scale_factor, 0, 0.11 * scale_factor))
		tip.rotation.y = side * -0.4
		n.add_child(tip)
	return n
