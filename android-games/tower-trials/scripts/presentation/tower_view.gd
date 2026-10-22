extends Node3D
## Tower Trials 3D presentation adapter.
## sync() reads main's existing level/state/selection snapshot after every
## redraw request and places original Blender models behind the unchanged 2D
## labels and buttons. It never writes rules, saves, input or level data.
## One world unit is 100 design pixels. The camera looks straight down -Z at
## the z = 0 plane, so room fronts on that plane map affinely onto the same
## letterboxed 600x1066 board the 2D layer uses; depth shows as parallax.

const U := 0.01
const FOV := 38.0
const SEA_Y := -7.46
const NIGHT_TOP := Color("0a182e")
const NIGHT_HORIZON := Color("3d6f80")
const TINT_OPEN := Color.WHITE
const TINT_BLOCKED := Color("8aa0aa")
const TINT_CLAIMED := Color("3e8696")
const TINT_COLLAPSED := Color("2c4256")
const TINT_SELECTED := Color("fff2cf")

var camera := Camera3D.new()
var scenes := {}
var materials := {}
var board := Node3D.new()
var courier: Node3D
var board_key := -1
var room_nodes := {}
var spirits: Array = []
var home_nodes: Array = []
var home_roof: Node3D
var beacon: Node3D
var clock := 0.0
var frozen := false
var reduced := false
var flight := 0.0
var courier_base := Vector3.ZERO
var synced := 0

func _ready() -> void:
	camera.fov = FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.5
	camera.far = 220.0
	camera.current = true
	add_child(camera)
	_environment()
	_backdrop()
	add_child(board)
	courier = asset("courier")
	add_child(courier)

## Matches main.layout(): uniform fit of the 600x1066 board, centred.
func frame(area: Vector2) -> void:
	var factor := minf(area.x / 600.0, area.y / 1066.0)
	var height := area.y / factor * U
	camera.position = Vector3(3.0, -5.33, height * 0.5 / tan(deg_to_rad(FOV * 0.5)))
	camera.rotation = Vector3.ZERO

func at(point: Vector2, z: float = 0.0) -> Vector3:
	var flat := Vector3(point.x * U, -point.y * U, 0.0)
	if is_zero_approx(z):
		return flat
	# Pull a raised point toward the camera axis so it projects onto the same
	# board pixel as the 2D anchor despite perspective parallax.
	var eye := camera.position
	var k := (eye.z - z) / eye.z
	return Vector3(eye.x + (flat.x - eye.x) * k, eye.y + (flat.y - eye.y) * k, z)

# ------------------------------------------------------------------ kit
func asset(key: String) -> Node3D:
	if not scenes.has(key):
		scenes[key] = load("res://art/models/" + key + ".glb") as PackedScene
	var node: Node3D = scenes[key].instantiate()
	_finish(node, Color.WHITE)
	return node

func material(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind + tint.to_html()
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.albedo_color = tint
		m.roughness = .86
		if kind == "Glow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[key] = m
	return materials[key]

func _finish(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(i)
			var glow: bool = source != null and source.resource_name == "Glow"
			node.set_surface_override_material(i, material("Glow" if glow else "Palette", Color.WHITE if glow else tint))
	for child in node.get_children():
		_finish(child, tint)

# ------------------------------------------------------------ environment
func _environment() -> void:
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = NIGHT_TOP
	sky_material.sky_horizon_color = NIGHT_HORIZON
	sky_material.ground_horizon_color = NIGHT_HORIZON
	sky_material.ground_bottom_color = Color("0b2236")
	sky_material.sun_angle_max = 1
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9cfe0")
	env.ambient_light_energy = .5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("23475a")
	env.fog_density = .0045
	holder.environment = env
	add_child(holder)
	var moonlight := DirectionalLight3D.new()
	moonlight.light_color = Color("e8eef6")
	moonlight.light_energy = .62
	moonlight.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-30), 0)
	moonlight.shadow_enabled = true
	moonlight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moonlight.directional_shadow_max_distance = 40
	add_child(moonlight)

func _place(key: String, position_value: Vector3, scale_value: Vector3 = Vector3.ONE, parent: Node = self) -> Node3D:
	var node := asset(key)
	node.position = position_value
	node.scale = scale_value
	parent.add_child(node)
	return node

func _backdrop() -> void:
	# Sea: a dark plane from the quay to the horizon.
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 200)
	sea.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("173f55")
	water.roughness = .35
	water.metallic_specular = .8
	sea.material_override = water
	sea.position = Vector3(3, SEA_Y - .12, -100)
	add_child(sea)
	# Stone quay the towers stand on; front face hides under the HUD panel.
	var quay := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(30, 4, 3)
	quay.mesh = slab
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("2c4b5a")
	stone.roughness = .9
	quay.material_override = stone
	quay.position = Vector3(3, SEA_Y - 2, -0.6)
	add_child(quay)
	# Far headland, lighthouse and village (fixed authored placements).
	_place("cliff", Vector3(-6, SEA_Y, -30), Vector3(2.4, 2.4, 2.4))
	_place("cliff", Vector3(14, SEA_Y, -36), Vector3(-2.8, 2.0, 2.4))
	beacon = _place("lighthouse", Vector3(10.5, SEA_Y + 3.8, -34), Vector3(2.2, 2.2, 2.2))
	for i in 7:
		_place("cottage", Vector3(-1.8 + i * 1.25, SEA_Y + .02, -6 - (i % 3) * 1.4), Vector3.ONE * (1.0 + (i % 2) * .15))
	_place("moon", Vector3(14, 6, -60), Vector3(6, 6, 6))
	for i in 22:
		var star := _place("moon", Vector3(fmod(i * 7.3 + 1.1, 46) - 20, 2 + fmod(i * 3.7, 14), -70), Vector3.ONE * (.18 + (i % 3) * .06))
		star.rotation.z = i

# ------------------------------------------------------------------ board
## Called from main after every state/selection/layout change and each
## animated frame. `view` is a read-only dictionary built by main.
func sync(view: Dictionary) -> void:
	synced += 1
	reduced = bool(view.reduced)
	frozen = bool(view.frozen)
	board.visible = view.screen == "game"
	courier.visible = board.visible
	if not board.visible:
		return
	var level: Dictionary = view.level
	var state: Dictionary = view.state
	var key := hash([level.get("id", ""), level.rooms, view.rects, camera.position])
	if key != board_key:
		_rebuild(view)
		board_key = key
	for room in level.rooms:
		var entry: Dictionary = room_nodes[room.id]
		var claimed: bool = room.id in state.claimed
		var collapsed: bool = room.id in state.collapsed and not claimed
		var blocked: bool = view.blocked.get(room.id, "") != ""
		var tint := TINT_OPEN
		if blocked: tint = TINT_BLOCKED
		if claimed: tint = TINT_CLAIMED
		if collapsed: tint = TINT_COLLAPSED
		if view.selected == room.id and not claimed and not collapsed: tint = TINT_SELECTED
		if entry.tint != tint:
			_finish(entry.node, tint)
			entry.tint = tint
		var rect: Rect2 = view.rects[room.id]
		entry.node.position = at(rect.get_center(), 0.0) + (Vector3(0, -.12, -.25) if collapsed else Vector3.ZERO)
		entry.node.rotation.z = deg_to_rad(-4.0) if collapsed else 0.0
		var spirit_tint := Color.WHITE if not blocked else Color("7d93a3")
		for spirit in entry.spirits:
			spirit.node.visible = not claimed and not collapsed
			if spirit.tint != spirit_tint:
				_finish(spirit.node, spirit_tint)
				spirit.tint = spirit_tint
	_home(view)
	var hero: Vector2 = view.courier
	courier_base = at(hero + Vector2(0, 32), .3)
	flight = float(view.flight)
	courier.position = courier_base
	courier.rotation = Vector3(0, deg_to_rad(18), sin(flight * PI) * -.35)

func _rebuild(view: Dictionary) -> void:
	for child in board.get_children():
		child.queue_free()
		board.remove_child(child)
	room_nodes.clear()
	spirits.clear()
	home_nodes.clear()
	var level: Dictionary = view.level
	for column in [1, 2]:
		var top := INF
		for room in level.rooms:
			if int(room.column) == column:
				top = minf(top, (view.rects[room.id] as Rect2).position.y)
		if top < INF:
			var x: float = 182.0 + float(int(column) - 1) * 200.0 + 90.0
			_place("tower_column", at(Vector2(x, 742)), Vector3(1, (742.0 - top) / 100.0, 1), board)
			_place("tower_roof", at(Vector2(x, top)), Vector3.ONE, board)
	for room in level.rooms:
		var rect: Rect2 = view.rects[room.id]
		var node := _place("room", at(rect.get_center()), Vector3(rect.size.x / 180.0, rect.size.y / 100.0, 1), board)
		var entry := {"node": node, "tint": Color.WHITE, "spirits": []}
		var count: int = room.enemies.size()
		var compact: bool = rect.size.y < 120
		for i in count:
			var point: Vector2 = rect.position + Vector2((i + 1) * 180.0 / (count + 1), (67 if compact else 77) + 15)
			var spirit := _place("spirit", at(point, .12), Vector3.ONE * (.75 if compact else 1.0), board)
			spirit.rotation.y = deg_to_rad(-12 + i * 9)
			var record := {"node": spirit, "base": spirit.position, "phase": float(i) * 1.7 + float(rect.position.x) * .01, "tint": Color.WHITE}
			entry.spirits.append(record)
			spirits.append(record)
		room_nodes[room.id] = entry
	home_roof = _place("home_roof", Vector3.ZERO, Vector3.ONE, board)

func _home(view: Dictionary) -> void:
	var floors: int = view.state.claimed.size() + 1
	var stride: float = view.home_stride
	while home_nodes.size() < floors:
		home_nodes.append(_place("home_floor", Vector3.ZERO, Vector3.ONE, board))
	for i in home_nodes.size():
		var node: Node3D = home_nodes[i]
		node.visible = i < floors
		if node.visible:
			node.position = at(Vector2(89, 692.0 - i * stride + stride - 2.0), .05)
			node.scale = Vector3(1, (stride - 2.0) / 98.0, 1)
	home_roof.position = at(Vector2(89, 692.0 - (floors - 1) * stride), .05)

func _process(delta: float) -> void:
	if frozen or reduced or not board.visible:
		return
	clock += delta
	for record in spirits:
		var node: Node3D = record.node
		node.position = record.base + Vector3(0, sin(clock * 2.2 + record.phase) * .025, 0)
	courier.position = courier_base + Vector3(0, absf(sin(clock * 3.0)) * .02, 0)
	if beacon:
		beacon.rotation.y = clock * .8
