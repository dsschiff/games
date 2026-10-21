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

## Flat ground marking: unshaded, translucent and never casting a shadow.
static func decal(node: GeometryInstance3D, color: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

## Pooled impact burst: flat ring plus upward-tilted shards, all unshaded so
## the hit flash stays bright under the compatibility lighting sum.
static func impact(radius: float, color: Color) -> Node3D:
	var root := Node3D.new()
	var r := ring(radius, color)
	decal(r, Color(color, .9))
	root.add_child(r)
	for i in 7:
		var a := float(i) * TAU / 7.0
		var shard := box(Vector3(.07, .07, radius * .9), color)
		decal(shard, Color(color.lightened(.35), .95))
		shard.position = Vector3(sin(a), .35, cos(a)) * radius * .8
		shard.rotation = Vector3(-.5, a, 0)
		root.add_child(shard)
	var flash := sphere(radius * .45, color)
	decal(flash, Color(1, .97, .85, .75))
	flash.position.y = .45
	root.add_child(flash)
	return root

static func label(text: String, at: Vector3, size: int = 42) -> Label3D:
	var l := Label3D.new()
	l.text = text
	# Same default UI face and ink as the HUD, rendered at high resolution so
	# it never reads as a pixel font; navy outline matches the HUD panels.
	l.font_size = size * 3
	l.pixel_size = 0.013 / 3.0
	l.outline_size = 18
	l.outline_modulate = Color("102d40")
	l.modulate = Color("fff0d5")
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.position = at
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l

static func warning() -> Node3D:
	var root := Node3D.new()
	for key in ["Solid", "Outer", "Inner"]:
		var n: Node3D = ring(3.2 if key == "Solid" else (6.35 if key == "Outer" else 2.0), Color("dc816d"))
		if key == "Solid":
			var outline := n
			n = Node3D.new()
			n.add_child(outline)
			var fill := cylinder(3.2, .012, Color("dc816d"))
			var m := material(Color(.93, .35, .25, .22))
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fill.material_override = m
			fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(fill)
		if key != "Solid":
			decal(n, Color(.93, .30, .22, .85))
		else:
			decal(n.get_child(0), Color(.93, .30, .22, .85))
		n.name = key
		root.add_child(n)
	var line := box(Vector3(1.15, 0.035, 8.5), Color("e48e79"), Vector3(0, 0, 4.25))
	line.name = "Line"
	decal(line, Color(.93, .33, .25, .45))
	root.add_child(line)
	for side in [-1, 1]:
		var angle: float = side * 0.32
		var branch := box(Vector3(0.5, 0.03, 8.5), Color("e48e79"), Vector3(sin(angle) * 4.25, 0, cos(angle) * 4.25))
		branch.name = "Left" if side < 0 else "Right"
		branch.rotation.y = angle
		decal(branch, Color(.93, .33, .25, .45))
		root.add_child(branch)
	return root
