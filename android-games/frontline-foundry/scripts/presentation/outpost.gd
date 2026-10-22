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
# Longer-lived than the shake so an off-screen HQ hit can still be pointed at.
var hq_alert_left := 0.0
var routed := {"projectile": 0, "ground": 0, "contact": 0, "blast": 0, "breach": 0, "repair": 0, "hq": 0}
var region := {}
var relay_rings: Array[MeshInstance3D] = []
var visual_steps: Array = []
var hq_socket: Marker3D
const MAX_INACTIVE_ACTORS := 24
const MAX_INACTIVE_PER_ROLE_SIDE := 4
const MAX_EFFECTS := 36
const MAX_INACTIVE_EFFECTS := 36
const MAX_INACTIVE_PER_EFFECT := 18
var actor_pool := {}
var effect_pool := {}
var model_resources := {}
var palette_materials := {}
var pool_stats := {"actors_created": 0, "actors_reused": 0, "actors_retired": 0, "actors_discarded": 0, "effects_created": 0, "effects_reused": 0, "effects_retired": 0, "effects_discarded": 0}
# Follow camera: a tilted perspective view that frames the commander and leads
# toward the front. Presentation only; rules own every coordinate.
const PITCH_DEGREES := 50.0
const DISTANCE := 16.0
const VIEW_WIDTH := 11.4
const REFERENCE_ASPECT := 720.0 / 1280.0
const PLAY_HALF_WIDTH := 5.4
var view_size := Vector2(720, 1280)
var camera_focus := Vector3(0, 0, 0)
var camera_focus_ready := false
var commander_ring: MeshInstance3D
var cue_layer: CanvasLayer
var cues: Control
var scenery: Array[Node3D] = []
# Logical HUD insets: threats hidden under the header or behind controls are cued.
var safe_top := 186.0
var safe_bottom := 300.0
# Linear albedo scale so the open sand sits at a mid-light value under the sun.
const GROUND_TONE := .86
const GROUND_SHADER := preload("res://scripts/presentation/ground.gdshader")

class EdgeCues extends Control:
	## Off-screen threat chevrons drawn at the edge of the usable play region.
	var marks: Array = []

	func _draw() -> void:
		for mark in marks:
			var point: Vector2 = mark.point
			var direction: Vector2 = mark.direction
			var color: Color = mark.color
			var size: float = mark.size
			var side := Vector2(-direction.y, direction.x)
			# Arrowhead with a notched back so the pointing direction is unambiguous.
			var tip := point + direction * size
			var wing := point - direction * size * .9
			var notch := point - direction * size * .45
			var arrow := PackedVector2Array([tip, wing + side * size * .52, notch, wing - side * size * .52])
			var halo := PackedVector2Array([tip + direction * 4, wing + side * (size * .52 + 4) - direction * 2, notch - direction * 3, wing - side * (size * .52 + 4) - direction * 2])
			draw_colored_polygon(halo, Color(.12, .10, .08, .6 * color.a))
			draw_colored_polygon(arrow, color)
			if mark.count > 1:
				var badge := point - direction * size * 1.25
				draw_circle(badge, size * .5, Color(.12, .10, .08, .65 * color.a))
				draw_string(ThemeDB.fallback_font, badge + Vector2(-size * .5, size * .24), str(mark.count), HORIZONTAL_ALIGNMENT_CENTER, size, int(size * .7), Color(1, .94, .86, color.a))

func _exit_tree() -> void:
	# Every reserve node remains a child and dies with this owner. Resource
	# dictionaries are owner-local, including when the viewport itself survives.
	actor_pool.clear()
	effect_pool.clear()
	model_resources.clear()
	palette_materials.clear()
	materials.clear()

func pool_key(role: String, team: String) -> String:
	# Role includes the authored primary weapon and attached loadout. Team fixes
	# the material/health-bar palette; authoritative IDs never enter this key.
	return role + ":" + team

func inactive_count(pool: Dictionary) -> int:
	var count := 0
	for reserve in pool.values():
		count += reserve.size()
	return count

func acquire_actor(role: String, team: String, phase: float) -> Node3D:
	var key := pool_key(role, team)
	var reserve: Array = actor_pool.get(key, [])
	var actor: Node3D
	if reserve.is_empty():
		actor = Actor.new()
		add_child(actor)
		actor.configure(role, team, phase, model_resources, palette_materials)
		pool_stats.actors_created += 1
	else:
		actor = reserve.pop_back()
		assert(actor.role == role and actor.team == team)
		actor.reset_for_reuse(phase)
		pool_stats.actors_reused += 1
	if reserve.is_empty():
		actor_pool.erase(key)
	return actor

func retire_actor(actor: Node3D) -> void:
	pool_stats.actors_retired += 1
	var key := pool_key(actor.role, actor.team)
	var reserve: Array = actor_pool.get(key, [])
	if reserve.size() >= MAX_INACTIVE_PER_ROLE_SIDE or inactive_count(actor_pool) >= MAX_INACTIVE_ACTORS:
		pool_stats.actors_discarded += 1
		actor.free()
		return
	actor.reset_for_reuse(0)
	actor.hide()
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	reserve.append(actor)
	actor_pool[key] = reserve

func acquire_effect(kind: String, point: Vector3, color: String) -> MeshInstance3D:
	var reserve: Array = effect_pool.get(kind, [])
	var node: MeshInstance3D
	if reserve.is_empty():
		node = MeshInstance3D.new()
		node.mesh = BoxMesh.new() if kind == "tracer" else TorusMesh.new()
		add_child(node)
		pool_stats.effects_created += 1
	else:
		node = reserve.pop_back()
		pool_stats.effects_reused += 1
	if reserve.is_empty():
		effect_pool.erase(kind)
	node.transform = Transform3D.IDENTITY
	node.position = point
	node.material_override = mat(color)
	node.material_overlay = null
	node.transparency = 0
	node.layers = 1
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.set_meta("effect_kind", kind)
	if kind != "tracer":
		var ring := node.mesh as TorusMesh
		ring.rings = 32 if kind == "warning_drill" else (24 if kind == "warning_storm" else 16)
		ring.ring_segments = 6 if kind == "pulse" else 8
		ring.inner_radius = 1.90 if kind == "warning_drill" else 1.14
		ring.outer_radius = 2.0 if kind == "warning_drill" else 1.25
	node.show()
	return node

func retire_effect(node: MeshInstance3D, kind: String) -> void:
	pool_stats.effects_retired += 1
	var reserve: Array = effect_pool.get(kind, [])
	if reserve.size() >= MAX_INACTIVE_PER_EFFECT or inactive_count(effect_pool) >= MAX_INACTIVE_EFFECTS:
		pool_stats.effects_discarded += 1
		node.free()
		return
	node.transform = Transform3D.IDENTITY
	node.material_override = null
	node.material_overlay = null
	node.hide()
	node.process_mode = Node.PROCESS_MODE_DISABLED
	reserve.append(node)
	effect_pool[kind] = reserve

func pool_snapshot() -> Dictionary:
	var result := pool_stats.duplicate()
	result.merge({"inactive_actors": inactive_count(actor_pool), "inactive_effects": inactive_count(effect_pool), "active_actors": units.size(), "corpses": corpses.size(), "active_effects": effects.size(), "essential_warnings": warnings.size(), "inactive_actor_cap": MAX_INACTIVE_ACTORS, "per_role_side_cap": MAX_INACTIVE_PER_ROLE_SIDE, "inactive_effect_cap": MAX_INACTIVE_EFFECTS, "per_effect_cap": MAX_INACTIVE_PER_EFFECT, "active_effect_cap": MAX_EFFECTS, "model_resources": model_resources.size(), "palette_materials": palette_materials.size()})
	return result

func build(state: Dictionary) -> void:
	campaign = int(state.catalog) == 2
	region = Regions.describe(state)
	adapter.reset(state, false)
	var night: bool = region.terrain == "night"
	var haze := Color(region.haze)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = haze
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d4e2") if night else Color("eef0f0")
	env.ambient_light_energy = .34 if night else .30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = .74
	# Soft distance haze: the clearing stays crisp, the perimeter recedes.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = haze
	env.fog_density = .38
	env.fog_depth_begin = DISTANCE + 1.0
	env.fog_depth_end = DISTANCE + 15.0
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 1.0
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -38, 0)
	sun.light_color = Color("dfe6ff") if night else Color("fff8ee")
	sun.light_energy = .66 if night else .74
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = .7
	sun.shadow_opacity = .52
	sun.shadow_blur = 2.4
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38, 145, 0)
	fill.light_color = Color("a9c5dd") if night else Color("d6e2ea")
	fill.light_energy = .20
	fill.shadow_enabled = false
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 2.0
	camera.far = 90.0
	add_child(camera)
	camera.current = true
	camera_focus_ready = false
	# One continuous warm ground: soft clearing, gentle value drift, painted
	# gate-to-HQ track. Shader only colors; it adds no collision or height.
	var ground := PlaneMesh.new()
	ground.size = Vector2(140, 140)
	var ground_node := MeshInstance3D.new()
	ground_node.name = "Ground"
	ground_node.mesh = ground
	ground_node.position.y = -.004
	ground_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ground_material := ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("sand", Color(region.ground).srgb_to_linear() * GROUND_TONE)
	ground_material.set_shader_parameter("clearing", Color(region.clearing).srgb_to_linear() * GROUND_TONE)
	ground_material.set_shader_parameter("rim", Color(region.rim).srgb_to_linear() * GROUND_TONE)
	ground_material.set_shader_parameter("track", Color(region.path).srgb_to_linear() * GROUND_TONE)
	ground_node.material_override = ground_material
	add_child(ground_node)
	build_region()
	frame_playfield()
	for side in [-1, 1]:
		for i in 5:
			var bag := asset("sandbag", Vector3(side * (1.35 + i * .84), 0, -.30 + i * .10))
			bag.rotation.y = side * -.10
			if i % 2 == 0:
				asset("sandbag", bag.position + Vector3(.15 * side, .32, 0))
			visual_steps.append({"point": Vector2(bag.position.x, bag.position.z), "height": .72 if i % 2 == 0 else .40, "extent": Vector2(.44, .24)})
	commander_ring = MeshInstance3D.new()
	var ring_shape := TorusMesh.new()
	ring_shape.inner_radius = .46
	ring_shape.outer_radius = .53
	ring_shape.rings = 32
	ring_shape.ring_segments = 4
	commander_ring.mesh = ring_shape
	commander_ring.scale.y = .12
	commander_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	commander_ring.material_override = mat("f3d564")
	add_child(commander_ring)
	cue_layer = CanvasLayer.new()
	cue_layer.layer = 0
	add_child(cue_layer)
	cues = EdgeCues.new()
	cues.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cues.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cue_layer.add_child(cues)
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
	update_camera(0, true)

func frame_playfield() -> void:
	# Perimeter dressing sits outside the commander rectangle (+/-4.7 plus body
	# radius) and behind the enemy spawn edge; place_landmark enforces bounds.
	var snowy: bool = region.terrain in ["snow", "ridge", "night", "glass"]
	var wooded: bool = region.terrain in ["snow", "ridge", "night", "glass", "bridge", "rail"]
	var rock_kind := "snow_rock" if snowy else "boulder_large"
	var tall_kind := "snow_rock_tall" if snowy else "boulder_small"
	var tree_kind := "pine" if snowy else "pine_bare"
	for side: int in [-1, 1]:
		var phase := 0 if side < 0 else 1
		# Inner edge: low barriers and sawhorses read as the outpost boundary.
		for i in 3:
			var z := -3.6 + i * 4.4 + phase * .8
			var kind := "barrier" if (i + phase) % 2 == 0 else "sawhorse"
			perimeter(kind, Vector3(side * 5.3, 0, z), PI * .5 + side * .12 * (i % 2), 1.0, side)
		# Main rock wall: large soft boulders hugging the edge between barriers.
		for i in 9:
			var z := -14.2 + i * 3.1 + phase * 1.2
			var kind := rock_kind if (i + phase) % 3 != 1 else "rock_outcrop"
			var size := .95 + .15 * float((i * 7 + phase * 3) % 4)
			perimeter(kind, Vector3(side * (5.9 + float((i * 5 + phase) % 3) * .5), 0, z), float(i) * 1.37 + phase, size, side)
			perimeter("boulder_small" if i % 2 == phase else tall_kind, Vector3(side * 8.6, 0, z + 1.5), float(i) * .9, .9 + .1 * float(i % 3), side)
		# Outer band: trees and tall rocks fade into the haze.
		for i in 8:
			var z := -17.0 + i * 3.7 + phase * 1.6
			var x := side * (9.6 + float((i * 3 + phase) % 4) * .9)
			if wooded:
				perimeter("pine_tall" if (i + phase) % 3 == 0 else tree_kind, Vector3(x, 0, z), float(i), 1.0 + .12 * float(i % 3), side)
				perimeter(tree_kind, Vector3(x + side * 2.2, 0, z + 1.6), float(i) * 2.1, 1.1, side)
			else:
				perimeter(tall_kind, Vector3(x, 0, z), float(i) * 1.1, 1.2 + .15 * float(i % 3), side)
		perimeter("fuel_drum", Vector3(side * 5.5, 0, 6.6 + phase * .5), 0, 1.0, side)
		# Stacked supply crates beside the base apron.
		for j in 3:
			var crate := perimeter("crate", Vector3(side * 5.45, 0, 3.6 + float(j % 2) * .62 + phase * .3), float(j) * .4 + side * .2, 1.0, side)
			if j == 2:
				crate.position += Vector3(0, .56, -.3)
	# Far side beyond the enemy spawn edge: a broken ridge of rock and trees.
	for i in 8:
		var x := -10.5 + i * 3.0 + float(i % 2) * .7
		var z := -10.4 - float((i * 3) % 4) * .9
		var kind := "boulder_small" if i % 3 == 1 else (rock_kind if i % 2 == 0 else "rock_outcrop")
		perimeter(kind, Vector3(x, 0, z), float(i) * 1.9, .9 + .12 * float(i % 3), 0)
		if wooded:
			perimeter(tree_kind if i % 2 == 0 else "pine_tall", Vector3(x + 1.3, 0, z - 2.4), float(i), 1.1, 0)
	# Foreground corners frame the base without crossing the HQ apron.
	for side: int in [-1, 1]:
		perimeter(rock_kind, Vector3(side * 7.4, 0, 10.6), side * .8, 1.45, side)
		perimeter("rock_outcrop", Vector3(side * 6.4, 0, 13.6), side * 2.0, 1.3, side)

func perimeter(id: String, point: Vector3, yaw: float, scale_factor: float, side: int) -> Node3D:
	var node := place_landmark(id, point, yaw, scale_factor, side)
	node.set_meta("perimeter", true)
	# Distant dressing does not need to cast into the shadow map.
	var far := absf(node.position.x) > 9.0 or node.position.z < -10.0 or node.position.z > 11.0
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	scenery.append(node)
	return node

func build_region() -> void:
	# All opaque landmarks stay outside the existing playable rectangle. Low
	# painted tracks/deck lines remain traversable; they never add collision.
	for side in [-1, 1]:
		var scale := .75 if region.landmark in ["bridge_arch", "floodgate", "quarry_crane", "repair_gantry"] else 1.0
		place_landmark(region.landmark, Vector3(side * 5.9, 0, -4.5 if side < 0 else 1.0), side * .45, scale, side)
	place_landmark(region.landmark, Vector3(-3.4, 0, -7.4), -.35, .72, 0)
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
				place_landmark("orchard_tree", Vector3(side * 6.5, 0, -9.0 + j * 3), 0, .8, side)
	if region.style == "siege":
		for side in [-1, 1]:
			place_landmark("watchtower", Vector3(side * 7.5, 0, -8.0), 0, 1, side)
	elif region.style == "flank":
		for side in [-1, 1]:
			place_landmark("relay_mast", Vector3(side * 7.0, 0, -7.0), 0, 1, side)

func place_landmark(id: String, point: Vector3, yaw: float, scale_factor: float, side: int) -> Node3D:
	var node := asset(id, point)
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_factor
	var bounds := geometry_bounds(node)
	# Includes full mesh-node hierarchy, authored scale, runtime yaw and overhangs.
	# Commander center x is bounded to +/-4.7 with .275 body clearance. Rear
	# scenery also clears the actual enemy spawn edge (-6.75 minus body radius).
	if side > 0:
		node.position.x += maxf(0, 5.1 - bounds.position.x)
	elif side < 0:
		node.position.x -= maxf(0, bounds.end.x + 5.1)
	else:
		node.position.z -= maxf(0, bounds.end.z + 7.1)
	node.set_meta("regional_placement", true)
	return node

static func geometry_bounds(node: Node3D) -> AABB:
	var found := false
	var bounds := AABB()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var local := instance.mesh.get_aabb()
		for index in 8:
			var point: Vector3 = instance.to_global(local.get_endpoint(index))
			if found:
				bounds = bounds.expand(point)
			else:
				bounds = AABB(point, Vector3.ZERO)
				found = true
	return bounds

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
	var n := Actor.instantiate_model("res://art/models/" + id + ".glb", model_resources)
	Actor.finish_materials(n, {"Rock": Color(region.rock), "Snow": Color(region.cap), "WorldStone": Color(region.rock), "Sandbag": Color("98a777"), "Seam": Color("7d8a5f"), "WorldIvory": Color("d2cab6")}, "prop", palette_materials)
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
	# Portrait phones keep a fixed world width; wider Fold/landscape windows keep
	# the reference height and reveal more of the surrounding world instead.
	view_size = view
	var aspect := view.x / maxf(1.0, view.y)
	var half := VIEW_WIDTH * .5 / DISTANCE
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = rad_to_deg(2.0 * atan(half / minf(aspect, REFERENCE_ASPECT)))
	update_camera(0, true)

func visible_half_width() -> float:
	var aspect := view_size.x / maxf(1.0, view_size.y)
	return tan(deg_to_rad(camera.fov) * .5) * aspect * DISTANCE

func update_camera(dt: float, snap: bool) -> void:
	if camera == null:
		return
	var anchor := Vector3(0, 0, 1.5)
	if units.has("commander"):
		anchor = units.commander.position
	elif adapter.current.has("commander"):
		anchor = adapter.current.commander.position
	var margin := maxf(0.0, PLAY_HALF_WIDTH - visible_half_width())
	# Lead toward the front: the view sits ahead of the commander so arriving
	# enemies, relays and the gate stay in frame while the base remains near.
	var target := Vector3(clampf(anchor.x * .6, -margin, margin), 0, clampf(anchor.z * .55 - .9, -3.4, 1.8))
	# Near the base the commander is closer to the lens, where the view is
	# narrower: keep the whole body inside the frustum at its own depth.
	var pitch := deg_to_rad(PITCH_DEGREES)
	var depth := DISTANCE - (anchor.z - target.z) * cos(pitch)
	var reach := maxf(0.0, visible_half_width() * depth / DISTANCE - .75)
	target.x = clampf(target.x, anchor.x - reach, anchor.x + reach)
	if snap or not camera_focus_ready:
		camera_focus = target
		camera_focus_ready = true
	else:
		camera_focus = camera_focus.lerp(target, 1.0 - exp(-dt * 3.0))
	camera.position = camera_focus + Vector3(0, sin(pitch), cos(pitch)) * DISTANCE
	camera.look_at(camera_focus)

func update_cues() -> void:
	if cues == null:
		return
	var marks: Array = []
	if not adapter.paused and adapter.phase == "playing" and camera != null:
		var top := safe_top + 26.0
		var bottom := view_size.y - safe_bottom - 18.0
		var rect := Rect2(Vector2(26, top), Vector2(view_size.x - 52, maxf(10.0, bottom - top)))
		var center := rect.get_center()
		for key in adapter.current:
			var data: Dictionary = adapter.current[key]
			if data.team != "enemy":
				continue
			var point: Vector3 = data.position + Vector3(0, .6, 0)
			var screen := camera.unproject_position(point)
			if camera.is_position_behind(point) or rect.has_point(screen):
				continue
			var boss: bool = data.role in ["drill", "carrier", "storm"]
			var urgent: bool = float(data.get("warning", 0.0)) > 0
			# Clamp along the ray from the play center so the chevron points at the threat.
			var direction := (screen - center).normalized()
			var edge := clamp_to_rect(center, direction, rect)
			var merged := false
			for existing in marks:
				if existing.point.distance_to(edge) < 46.0:
					existing.count += 1
					existing.size = maxf(existing.size, 30.0 if boss else 22.0)
					merged = true
					break
			if merged:
				continue
			var color := Color("ff6a4d") if urgent else (Color("ff7b3a") if boss else Color("e8573f"))
			if not reduced:
				color.a = .8 + .2 * sin(Time.get_ticks_msec() * .008)
			marks.append({"point": edge, "direction": direction, "color": color, "size": 30.0 if boss else 22.0, "count": 1})
		if hq_alert_left > 0 and hq_socket != null:
			var hq_screen := camera.unproject_position(hq_socket.global_position)
			if not rect.has_point(hq_screen):
				var toward := (hq_screen - center).normalized()
				marks.append({"point": clamp_to_rect(center, toward, rect), "direction": toward, "color": Color("f2b44c"), "size": 28.0, "count": 1})
	cues.marks = marks
	cues.queue_redraw()

static func clamp_to_rect(origin: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
	var t := INF
	if absf(direction.x) > .0001:
		t = minf(t, ((rect.end.x if direction.x > 0 else rect.position.x) - origin.x) / direction.x)
	if absf(direction.y) > .0001:
		t = minf(t, ((rect.end.y if direction.y > 0 else rect.position.y) - origin.y) / direction.y)
	return origin + direction * (0.0 if t == INF else t)

func sync(state: Dictionary, is_paused: bool, reduced_effects: bool, dt: float) -> void:
	reduced = reduced_effects
	var was_paused: bool = adapter.paused
	var old_time: float = adapter.last_time
	var reset := adapter.ingest(state, is_paused, dt)
	if reset:
		# Production order is tick -> queue -> sync. Preserve only the newly earned
		# resume batch; pause sync has already discarded the previous epoch's queue.
		var earned_resume: Array = pending.duplicate(true) if was_paused and not is_paused else []
		clear_transients()
		pending = earned_resume
		for key in corpses:
			retire_actor(corpses[key].node)
		corpses.clear()
	for key in units.keys():
		if not adapter.current.has(key):
			var n: Node3D = units[key]
			var id := int(key.get_slice(":", 1))
			if key.begins_with("enemy:") and id in state.killed and not reset:
				n.death_time = 0
				corpses[str(adapter.epoch) + ":" + key] = {"node": n, "left": .85}
			else:
				retire_actor(n)
			units.erase(key)
	for key in adapter.current:
		var data: Dictionary = adapter.current[key]
		var created := false
		if units.has(key) and (units[key].role != data.role or units[key].team != data.team):
			retire_actor(units[key])
			units.erase(key)
		if not units.has(key):
			var unit := acquire_actor(data.role, data.team, float(key.hash() % 100) * .15)
			units[key] = unit
			unit.position = data.position
			created = true
		elif reset and (state.time < old_time or (units[key].death_time >= 0 and data.phase != "fallen")):
			units[key].reset_for_reuse(float(key.hash() % 100) * .15)
		units[key].set_snapshot(data, reset or created)
		if reset or created:
			units[key].position = data.position
			units[key].position.y = ground_height(units[key].position)
		units[key].visible = data.team != "ally" or data.role in available
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
	if units.has("commander") and commander_ring != null:
		commander_ring.visible = adapter.current.commander.phase != "fallen"
		if reset:
			commander_ring.position = units.commander.position + Vector3(0, .025, 0)
	if reset:
		update_camera(0, true)
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
			warnings[key] = acquire_effect("warning_storm", Vector3(mark.x, .07, mark.z), "e44d39")
		warnings[key].scale.y = .30
	for enemy in state.enemies:
		if enemy.get("role", "") == "drill" and enemy.get("telegraph", 0) > 0:
			var key := "drill:" + str(int(enemy.id))
			live[key] = true
			if not warnings.has(key):
				warnings[key] = acquire_effect("warning_drill", Vector3(enemy.x, .08, enemy.z + 1.8), "e44d39")
			warnings[key].scale.y = .25
	for key in warnings.keys():
		if not live.has(key):
			retire_effect(warnings[key], warnings[key].get_meta("effect_kind"))
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
				origin = units[shooter].socket_position()
			elif shooter == "sentry":
				sentry.rotation.y = atan2(-(destination.x - sentry.position.x), -(destination.z - sentry.position.z))
				origin = sentry.to_global(Vector3(0, .61, -.66))
			tracer(origin, destination, "ffd36e" if event.kind == "shot" else "f5906a")
		elif subtype != "projectile":
			pulse(Vector3(event.to[0], .10, event.to[1]), "e06e43", .28)
	if event.kind == "incoming" and int(event.recipient) == -2:
		hq_hit_left = .22
		hq_alert_left = 1.4
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
	if effects.size() >= MAX_EFFECTS:
		return
	var n := acquire_effect("pulse", point, color)
	var ring := n.mesh as TorusMesh
	ring.inner_radius = radius * .75
	ring.outer_radius = radius
	n.scale.y = .25
	effects.append({"node": n, "left": .18, "kind": "pulse"})
	effects_emitted += 1

func tracer(from: Vector3, to: Vector3, color: String) -> void:
	if effects.size() >= MAX_EFFECTS or from.distance_squared_to(to) < .01:
		return
	var n := acquire_effect("tracer", (from + to) * .5, color)
	var shape := n.mesh as BoxMesh
	shape.size = Vector3(.025, .025, from.distance_to(to))
	n.look_at(to)
	effects.append({"node": n, "left": .055, "kind": "tracer"})
	effects_emitted += 1

func clear_transients() -> void:
	pending.clear()
	attacks_seen.clear()
	hq_hit_left = 0
	hq_alert_left = 0
	hq.rotation.z = 0
	for effect in effects:
		retire_effect(effect.node, effect.kind)
	effects.clear()
	for key in units:
		units[key].reset_transients()

func _process(dt: float) -> void:
	var alpha := adapter.advance(dt)
	if adapter.paused:
		update_cues()
		return
	hq_hit_left = maxf(0, hq_hit_left - dt)
	hq_alert_left = maxf(0, hq_alert_left - dt)
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
	if units.has("commander"):
		commander_ring.visible = adapter.current.commander.phase != "fallen"
		commander_ring.position = units.commander.position + Vector3(0, .025, 0)
	update_camera(dt, false)
	update_cues()
	for key in corpses.keys():
		corpses[key].node.pose(dt, Vector3.ZERO, false)
		corpses[key].left -= dt
		if corpses[key].left <= 0:
			retire_actor(corpses[key].node)
			corpses.erase(key)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].left -= dt
		if effects[i].left <= 0:
			retire_effect(effects[i].node, effects[i].kind)
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
