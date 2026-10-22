extends RefCounted
## District environment: sky, fog, lighting, water and scrolling street dressing.
## Scenery is drawn with one MultiMesh per kit mesh and scrolls with the rule
## road speed, so gates, carts and planted feet share the same moving ground.
## Placement is a fixed authored table plus a local integer hash; no RNG.
const LOOP := 140.0
const NEAR := 16.0
# Compatibility draws a shadowed sun as a second additive pass summed after
# sRGB encoding (see Hook and Hunger GRAPHICS_PRODUCTION.md). Ambient and sun
# therefore add in display space; Linear tonemap with these energies keeps the
# brightest lit surfaces below white.
const AMBIENT_ENERGY := .42
const SUN_ENERGY := .30
const SKY := [["4f9cc4", "d4e6e4"], ["c9866a", "f3d6b2"], ["4d86c0", "cfe0ea"], ["d77a5a", "f6cf98"]]
const WATER := ["3f8f8c", "", "3a7fa6", "2f86a3"]
const GROUND := ["9a9a92", "b89c82", "8fa39a", "c8b48e"]
var host: Node3D
var kit: RefCounted
var district := 0
var layers := {}
var ripples: MultiMeshInstance3D
var ripple_base: Array = []
var dashes: MultiMeshInstance3D
var dash_base: Array = []
var ferry: Node3D
var ferry_rest := Vector3.ZERO
var sun: DirectionalLight3D
var environment: Environment

func build(owner: Node3D, assets: RefCounted, index: int) -> void:
	host = owner
	kit = assets
	district = clampi(index / 6, 0, 3)
	var env := WorldEnvironment.new()
	environment = Environment.new()
	env.environment = environment
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(SKY[district][0])
	sky_material.sky_horizon_color = Color(SKY[district][1])
	sky_material.ground_horizon_color = Color(SKY[district][1])
	sky_material.ground_bottom_color = Color(SKY[district][0]).darkened(.3)
	sky_material.sun_angle_max = 1
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e4ecf2").lerp(Color(SKY[district][1]), .35)
	environment.ambient_light_energy = AMBIENT_ENERGY
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(SKY[district][1])
	environment.fog_light_energy = 1.0
	environment.fog_density = 1.0
	environment.fog_depth_begin = 38.0
	environment.fog_depth_end = 150.0
	environment.fog_depth_curve = 1.6
	environment.fog_sky_affect = 0.0
	host.add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 32 if district != 1 else -28, 0)
	sun.light_color = Color("fff1dc") if district != 3 else Color("ffe0b8")
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.shadow_opacity = .85
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 46
	sun.shadow_bias = .04
	sun.shadow_normal_bias = 1.0
	host.add_child(sun)
	_ground()
	_road()
	match district:
		0: _canal()
		1: _viaduct()
		2: _reservoir()
		3: _ferry_approach()

func plain(color: Color, unshaded: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = .9
	if alpha < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func slab(size: Vector3, pos: Vector3, material: Material, shadow: bool = false) -> MeshInstance3D:
	# Large flat environment slabs are PlaneMesh/BoxMesh with z extents far
	# larger than the 0.15 m rescue-line marker, so they never alias it.
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node

func _ground() -> void:
	var low := -3.4 if district == 1 else (-1.25 if district in [0, 2, 3] else -.2)
	var base := Color(GROUND[district])
	if district == 1:
		slab(Vector3(160, .4, 220), Vector3(0, -3.6, -60), plain(base.darkened(.12)))
	else:
		var water := plain(Color(WATER[district]))
		water.roughness = .25
		water.metallic_specular = .7
		slab(Vector3(200, .2, 240), Vector3(0, low, -60), water)
	if district == 0:
		# Far quay and the working apron on the right of the road.
		slab(Vector3(60, .5, 240), Vector3(38, -.30, -60), plain(base))
		slab(Vector3(40, 1.2, 240), Vector3(-46, -.70, -60), plain(base.darkened(.08)))
	if district in [0, 2, 3]:
		ripples = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var strip := BoxMesh.new()
		strip.size = Vector3(1.6, .02, .14)
		mm.mesh = strip
		var spots: Array = []
		for i in 90:
			var side := -1.0 if i % 2 == 0 else 1.0
			if district == 0 and side > 0: continue
			var x := side * (10.5 + float(_hash(i, 3) % 220) / 10.0)
			spots.append(Vector3(x, low + .12, -float(_hash(i, 5) % 1400) / 10.0))
		mm.instance_count = spots.size()
		ripples.multimesh = mm
		ripples.material_override = plain(Color("e8f6f2"), true, .55)
		ripples.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ripple_base = spots
		host.add_child(ripples)

func _road() -> void:
	for i in 14: place(["road_cross", "road_tile", "road_mark", "road_tile"][i % 4], 0, -i * 10.0)
	_skyline()
	# Static painted edge lines; lane dashes scroll with the road.
	for x in [-4.48, 4.48]:
		slab(Vector3(.16, .02, 150), Vector3(x, .012, -55), plain(Color("f2d27a")))
	dashes = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dash := BoxMesh.new()
	dash.size = Vector3(.14, .02, 1.6)
	mm.mesh = dash
	for x in [-1.33, 1.33]:
		for i in 35: dash_base.append(Vector3(x, .012, -i * 4.0))
	mm.instance_count = dash_base.size()
	dashes.multimesh = mm
	dashes.material_override = plain(Color("f3ead0"))
	dashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(dashes)
	for side in [-1.0, 1.0]:
		for i in 12:
			place("streetlight", side * 7.45, -i * 12.0 - (6.0 if side > 0 else 0.0), 0.0 if side < 0 else PI)

func _canal() -> void:
	for i in 14: place("seawall", -8.6, -i * 10.0)
	for i in 13:
		var z := -i * 11.0
		place("warehouse" if i % 3 != 1 else "apartment", 14.5 + (i % 2) * 1.5, z, PI if i % 3 != 1 else PI, 1.0)
		place("warehouse", -30.0 - (i % 2) * 2.0, z - 4.0, 0.0, 1.1)
		if i % 2 == 0: place("container", 9.8, z - 5.0, 0.0)
		if i % 3 == 2: place("dock_crane", -24.0, z - 2.0, PI * .5, .8)
		if i % 4 == 1: place("crates", 7.35, z - 2.0, .3)
		if i % 4 == 3: place("barrier", 7.45, z - 7.0, PI * .5)
		if i % 5 == 2: place("van", 8.0, z - 8.0, .08)
		if i % 2 == 1: place("cone", 7.3, z - 3.0, 0.0)
	for i in 6: place("container", -19.5, -i * 23.0 - 6.0, 0.0, 1.0)

func _viaduct() -> void:
	for side in [-1.0, 1.0]:
		for i in 28: place("guardrail", side * 7.75, -i * 5.0)
		for i in 14: place("viaduct_pier", side * 4.6, -i * 10.0, 0.0, 1.0, Vector3.ZERO, .58)
		for i in 12:
			var z := -i * 12.0 - (6.0 if side > 0 else 0.0)
			place("apartment", side * (21.0 + (i % 3) * 2.5), z, 0.0 if side < 0 else PI, 1.0, Vector3(0, -3.4, 0), 1.5)
			place("market_stall", side * 12.0, z - 3.0, 0.0 if side < 0 else PI, 1.0, Vector3(0, -3.4, 0))
			place("market_stall", side * 14.5, z - 7.0, 0.0 if side < 0 else PI, 1.0, Vector3(0, -3.4, 0))
			if i % 3 == 0: place("car", side * 10.5, z - 4.0, .12 * side, 1.0, Vector3(0, -3.4, 0))
			if i % 4 == 2: place("crates", side * 7.25, z - 9.0, .4)
			if i % 3 == 1: place("shrub", side * 10.0, z, 0.0, 1.0, Vector3(0, -3.4, 0))

func _reservoir() -> void:
	for side in [-1.0, 1.0]:
		for i in 14: place("seawall", side * 8.6, -i * 10.0)
		for i in 14: place("pipes", side * 7.0, -i * 10.0 - 2.0)
		for i in 8:
			var z := -i * 18.0 - (9.0 if side > 0 else 0.0)
			place("tank", side * (20.0 + (i % 2) * 4.0), z, 0.0, 1.0, Vector3(0, -1.0, 0))
			if i % 2 == 0: place("warehouse", side * 13.5, z - 6.0, 0.0 if side < 0 else PI, .7, Vector3(0, -1.0, 0))
			if i % 3 == 1: place("barrier", side * 7.45, z - 3.0, PI * .5)

func _ferry_approach() -> void:
	for side in [-1.0, 1.0]:
		for i in 14: place("seawall", side * 8.6, -i * 10.0)
		for i in 16:
			var z := -i * 9.0 - (4.5 if side > 0 else 0.0)
			place("palm", side * 7.35, z, float(_hash(i, int(side) + 7) % 628) / 100.0, .8 + float(_hash(i, 2) % 30) / 100.0)
			if i % 3 == 1: place("lifebuoy", side * 7.8, z - 3.0, 0.0 if side < 0 else PI)
			if i % 4 == 2: place("sandbags", side * 7.3, z - 5.0, PI * .5)
			if i % 5 == 3: place("dock_crane", side * 22.0, z, PI * (.5 if side < 0 else 1.5), .9, Vector3(0, -1.2, 0))
		for i in 5: place("terminal", side * 26.0, -i * 28.0, PI * (.5 if side < 0 else -.5), 1.0, Vector3(0, -1.2, 0))
	ferry = kit.asset("ferry")
	ferry_rest = Vector3(14.0, -1.2, -78.0)
	ferry.position = ferry_rest
	ferry.rotation.y = .25
	ferry.scale = Vector3.ONE * 1.4
	host.add_child(ferry)

## Static horizon silhouettes and clouds beyond the fog. They ignore fog
## and are pre-tinted toward the horizon colour to read as distant.
func _skyline() -> void:
	var horizon := Color(SKY[district][1])
	var tint := horizon.lerp(Color(["5d7f8f", "8a6a62", "5a7894", "7e6a74"][district]), .42)
	var far := plain(tint, true)
	far.disable_fog = true
	var near := plain(horizon.lerp(tint, .55), true)
	near.disable_fog = true
	for i in 26:
		var x := -130.0 + i * 10.4 + float(_hash(i, 11) % 40) / 10.0
		var h := 4.0 + float(_hash(i, 13) % 220) / 10.0
		var w := 5.0 + float(_hash(i, 17) % 90) / 10.0
		match district:
			2:
				_far_shape(SphereMesh, Vector3(w * 2.4, h * 1.2, 20), Vector3(x, -h * .3, -205), far)
			3:
				if i % 4 == 0: _far_shape(SphereMesh, Vector3(w * 3.0, h * .55, 18), Vector3(x, -h * .15, -215), far)
			_:
				_far_shape(BoxMesh, Vector3(w, h * (1.6 if district == 1 else 1.0), 6), Vector3(x, h * (.8 if district == 1 else .5), -200), far)
				if i % 3 == 1: _far_shape(BoxMesh, Vector3(w * .7, h * .6, 6), Vector3(x + 4, h * .3, -185), near)
		if district == 0 and i % 6 == 2:
			_far_shape(BoxMesh, Vector3(.9, 26, 1), Vector3(x, 13, -192), far)
			_far_shape(BoxMesh, Vector3(18, 1.2, 1.2), Vector3(x - 7, 25, -192), far)
	var cloud := plain(Color("ffffff"), true, .72)
	cloud.disable_fog = true
	for i in 7:
		var x := -110.0 + i * 36.0 + float(_hash(i, 23) % 120) / 10.0
		_far_shape(SphereMesh, Vector3(34 + float(_hash(i, 29) % 200) / 10.0, 6, 14), Vector3(x, 52 + (i % 3) * 9.0, -260), cloud)

func _far_shape(kind, size: Vector3, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh = kind.new()
	if mesh is BoxMesh: mesh.size = Vector3.ONE
	else:
		mesh.radius = .5
		mesh.height = 1.0
		mesh.radial_segments = 16
		mesh.rings = 8
	node.mesh = mesh
	node.scale = size
	node.position = pos
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)

## Register one scenery instance on its key's MultiMesh layer.
func place(key: String, x: float, z: float, yaw: float = 0.0, scale: float = 1.0, offset: Vector3 = Vector3.ZERO, height: float = 1.0) -> void:
	if not layers.has(key):
		var nodes: Array = []
		for part in kit.parts(key):
			var mmi := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part.mesh
			mmi.multimesh = mm
			mmi.material_override = part.material
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if part.material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			host.add_child(mmi)
			nodes.append({"node": mmi, "local": part.transform})
		layers[key] = {"parts": nodes, "items": []}
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale * height, scale))
	layers[key].items.append(Transform3D(basis, Vector3(x, 0, z) + offset))

func finalize() -> void:
	for key in layers:
		for part in layers[key].parts:
			part.node.multimesh.instance_count = layers[key].items.size()
	scroll(0.0)

## distance: metres the convoy has advanced (rule tick / 60 * road speed).
func scroll(distance: float) -> void:
	for key in layers:
		var items: Array = layers[key].items
		for part in layers[key].parts:
			var mm: MultiMesh = part.node.multimesh
			for i in items.size():
				var t: Transform3D = items[i]
				t.origin.z = wrapf(t.origin.z + distance, NEAR - LOOP, NEAR)
				mm.set_instance_transform(i, t * part.local)
	if dashes != null:
		for i in dash_base.size():
			var p: Vector3 = dash_base[i]
			p.z = wrapf(p.z + distance, NEAR - LOOP, NEAR)
			dashes.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	if ripples != null:
		for i in ripple_base.size():
			var p: Vector3 = ripple_base[i]
			p.z = wrapf(p.z + distance * .92, NEAR - LOOP, NEAR)
			ripples.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))

## Final evacuation: the ferry casts off after the last road is restored.
func ferry_depart(seconds: float) -> void:
	if ferry == null: return
	var t := clampf(seconds / 9.0, 0, 1)
	ferry.position = ferry_rest + Vector3(-6.0 * t, 0, -18.0 * t * t)
	ferry.rotation.y = .25 - .35 * t

static func _hash(a: int, b: int) -> int:
	var v := (a * 73856093) ^ (b * 19349663)
	v = (v ^ (v >> 13)) * 1274126177
	return absi(v ^ (v >> 16))
