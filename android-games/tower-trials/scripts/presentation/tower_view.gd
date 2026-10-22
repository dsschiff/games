extends Node3D
## Tower Trials 3D presentation adapter.
## sync() reads main's existing level/state/selection snapshot after every
## redraw request and places original Blender models behind the unchanged 2D
## labels and buttons. It never writes rules, saves, input or level data.
## One world unit is 100 design pixels. The camera looks straight down -Z at
## the z = 0 plane, so room fronts on that plane map affinely onto the same
## letterboxed 600x1066 board the 2D layer uses; depth shows as parallax.
##
## Encounters are driven by main's rule-timed beat (the existing 0.9 s pending
## window): the courier dashes from the watch into the chosen chamber, strikes
## each enemy in the rule's left-to-right order, defeated enemies topple and
## dissolve into light that the courier absorbs. Everything after the rule
## resolves (power pop, light sent home, the new watch floor rising, the
## courier's return leap) runs on this node's own clock and never delays or
## blocks input: a new move simply starts from the watch anchor.

const U := 0.01
const FOV := 38.0
const SEA_Y := -7.46
const TINT_OPEN := Color.WHITE
const TINT_BLOCKED := Color("9aaab8")
const TINT_CLAIMED := Color("a6e8da")
const TINT_COLLAPSED := Color("33465a")
const TINT_SELECTED := Color(1.18, 1.08, .86)
const TRAVEL := .30
const ABSORB := .84
const RETURN_TIME := .42
const GROW_DELAY := .22
const GROW_TIME := .5
const COURIER_SCALE := 1.1
const ROOM_DEPTH := -.34
const GOLD := Color("ffd17d")
const TEAL := Color("63e0bf")
const RED := Color("ff7a6b")
const INK := Color("0b1c2c")
## Chapter looks: sky top, horizon, ground, ambient, sun, sea, fog, stone tint.
const LOOKS := [
	{"name": "Lantern Coast", "top": "0a182e", "horizon": "3d6f80", "ground": "0b2236", "ambient": "c4d6e6", "sun": "e8eef6", "sea": "173f55", "fog": "23475a", "stone": "ffffff", "rock": "ffffff", "disc": "f2ead2", "stars": true},
	{"name": "Salt Archives", "top": "2b1f45", "horizon": "e2905e", "ground": "3a2430", "ambient": "f0d2bc", "sun": "ffd2a6", "sea": "5b3f55", "fog": "7a4a58", "stone": "ffe6c8", "rock": "e8c0a0", "disc": "ffb070", "stars": false},
	{"name": "Glass March", "top": "16394a", "horizon": "a6e0c8", "ground": "1d4040", "ambient": "d6f2ea", "sun": "f0fff6", "sea": "2e6f6a", "fog": "5e9f96", "stone": "e2fff4", "rock": "a8e0cc", "disc": "e6fff4", "stars": false},
	{"name": "Last Meridian", "top": "120a28", "horizon": "c99a52", "ground": "2a1838", "ambient": "d0c0ee", "sun": "ffe2b0", "sea": "2a2050", "fog": "3a2a5a", "stone": "d6c8ff", "rock": "b8a0e6", "disc": "ffe6b0", "stars": true},
	{"name": "All lanterns rise", "top": "1e2858", "horizon": "ffb46e", "ground": "2a2040", "ambient": "e6daf2", "sun": "fff0d0", "sea": "3a3a6e", "fog": "5a4a78", "stone": "ffffff", "rock": "c8b8f0", "disc": "fff0c8", "stars": true}]

var camera := Camera3D.new()
var scenes := {}
var materials := {}
var board := Node3D.new()
var finale := Node3D.new()
var courier := Node3D.new()
var courier_turn := Node3D.new()
var courier_hip := Node3D.new()
var courier_legs: Array = []
var courier_arm := Node3D.new()
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
var screen := "game"
var chapter := -1
var factor := 1.0
var offset := Vector2.ZERO
# Environment handles, recoloured per chapter.
var sky_material := ProceduralSkyMaterial.new()
var env := Environment.new()
var sun := DirectionalLight3D.new()
var water := StandardMaterial3D.new()
var props := {}
var disc: Node3D
var stars: Array = []
var auroras: Array = []
# Encounter state (read-only copies of what main already shows).
var encounter := {}
var level_id := ""
var shown_floors := 0
var grow := {"index": -1, "t": 1.0}
var roof_from := 0.0
var returning := {"t": 1.0, "from": Vector3.ZERO}
var celebrate := 0.0
var lanterns: Array = []
# Effects pools.
var sparks: Array = []
var rings: Array = []
var orbs: Array = []
var pops: Array = []
var hud_pulse := 0.0
var hud_gain := 0
var overlay := CanvasLayer.new()
var fx := Node2D.new()
var font: Font = ThemeDB.fallback_font

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
	add_child(finale)
	_courier_rig()
	_pools()
	overlay.layer = 1
	add_child(overlay)
	overlay.add_child(fx)
	fx.draw.connect(_draw_fx)
	_set_chapter(0)

## Matches main.layout(): uniform fit of the 600x1066 board, centred.
func frame(area: Vector2) -> void:
	factor = minf(area.x / 600.0, area.y / 1066.0)
	offset = (area - Vector2(600, 1066) * factor) * 0.5
	fx.position = offset
	fx.scale = Vector2.ONE * factor
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

## Board-pixel position of a world point (for the 2D effect overlay).
func board_point(world: Vector3) -> Vector2:
	return (camera.unproject_position(world) - offset) / factor

# ------------------------------------------------------------------ kit
func asset(key: String) -> Node3D:
	if not scenes.has(key):
		scenes[key] = load("res://art/models/" + key + ".glb") as PackedScene
	var node: Node3D = scenes[key].instantiate()
	_finish(node, Color.WHITE)
	return node

func material(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind + str(tint)
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

func _flat(color: Color, alpha: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# ------------------------------------------------------------ environment
func _environment() -> void:
	var holder := WorldEnvironment.new()
	var sky := Sky.new()
	sky_material.sun_angle_max = 1
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	# Compatibility adds each shadowed directional light in a second pass after
	# sRGB encoding, so ambient and light sum in display space. These energies
	# are calibrated for that sum (as on Hook and Hunger); a linear tonemap
	# avoids a second curve. Higher values clip plaster to flat white.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = .42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_density = .0045
	holder.environment = env
	add_child(holder)
	sun.light_energy = .34
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-28), 0)
	sun.shadow_enabled = true
	sun.shadow_opacity = .85
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40
	sun.shadow_bias = .03
	sun.shadow_normal_bias = 1.0
	add_child(sun)

func _place(key: String, position_value: Vector3, scale_value: Vector3 = Vector3.ONE, parent: Node = self) -> Node3D:
	var node := asset(key)
	node.position = position_value
	node.scale = scale_value
	parent.add_child(node)
	return node

func _backdrop() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 200)
	sea.mesh = plane
	water.roughness = .35
	water.metallic_specular = .8
	sea.material_override = water
	sea.position = Vector3(3, SEA_Y - .12, -100)
	add_child(sea)
	# Stone quay the towers stand on; its front face hides under the HUD panel.
	var quay := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(40, 4, 3)
	quay.mesh = slab
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("2c4b5a")
	stone.roughness = .9
	quay.material_override = stone
	quay.position = Vector3(3, SEA_Y - 2, -0.6)
	add_child(quay)
	disc = _place("moon", Vector3(14, 6, -60), Vector3(6, 6, 6))
	for i in 30:
		var star := _place("moon", Vector3(fmod(i * 7.3 + 1.1, 60) - 27, 1 + fmod(i * 3.7, 16), -70), Vector3.ONE * (.16 + (i % 3) * .06))
		star.rotation.z = i
		stars.append(star)
	# Chapter prop sets (fixed authored placements, wide enough for landscape).
	for index in 5:
		props[index] = Node3D.new()
		add_child(props[index])
	var coast: Node3D = props[0]
	_place("cliff", Vector3(-6, SEA_Y, -30), Vector3(2.4, 2.4, 2.4), coast)
	_place("cliff", Vector3(14, SEA_Y, -36), Vector3(2.8, 2.0, 2.4), coast)
	_place("cliff", Vector3(-22, SEA_Y, -40), Vector3(2.6, 2.2, 2.4), coast)
	beacon = _place("lighthouse", Vector3(7.3, SEA_Y + 2.8, -36), Vector3(2.2, 2.2, 2.2), coast)
	for i in 12:
		# Village behind the rule towers and off the left edge, never behind your watch.
		var x := (2.4 + i * 1.15) if i < 8 else (-4.5 - (i - 8) * 1.5)
		_place("cottage", Vector3(x, SEA_Y + .02, -6 - (i % 3) * 1.4), Vector3.ONE * (1.0 + (i % 2) * .15), coast)
	var salt: Node3D = props[1]
	for i in 5:
		_place("cliff", Vector3(-24 + i * 12, SEA_Y, -42 - (i % 2) * 6), Vector3(2.4, 1.4 + (i % 3) * .4, 2.0), salt)
	for i in 6:
		var stack := _place("archive", Vector3(-7 + i * 3.1, SEA_Y + .02, -9 - (i % 3) * 3.5), Vector3.ONE * (1.3 + (i % 2) * .5), salt)
		stack.rotation.y = (i % 3 - 1) * .25
	var glass: Node3D = props[2]
	for i in 4:
		_place("cliff", Vector3(-22 + i * 14, SEA_Y, -40 - (i % 2) * 5), Vector3(2.4, 1.6 + (i % 2) * .5, 2.0), glass)
	for i in 11:
		var cluster := _place("crystal", Vector3(-8 + i * 2.1, SEA_Y + .02, -5 - (i % 4) * 2.4), Vector3.ONE * (1.1 + (i % 3) * .55), glass)
		cluster.rotation.y = i * .9
	var meridian: Node3D = props[3]
	var ring := _place("meridian", Vector3(4, SEA_Y, -34), Vector3(6, 6, 6), meridian)
	ring.rotation.y = -.15
	for i in 4:
		_place("cliff", Vector3(-24 + i * 15, SEA_Y, -44), Vector3(2.4, 1.8, 2.0), meridian)
	for i in 3:
		var band := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(80, .5 + i * .2, .1)
		band.mesh = box
		band.material_override = _flat(Color(.55, 1.0, .82, .16 - i * .03), true)
		band.position = Vector3(3, 4.5 + i * 1.6, -66)
		band.rotation.z = -.08 + i * .05
		meridian.add_child(band)
		auroras.append(band)
	var ending: Node3D = props[4]
	# Low behind the answering watches so it never sits under the ending text.
	_place("meridian", Vector3(3, -12.8, -40), Vector3(5, 5, 5), ending)
	for i in 4:
		_place("cliff", Vector3(-22 + i * 14, SEA_Y, -44), Vector3(2.4, 1.6, 2.0), ending)
	_finale()

func _set_chapter(index: int) -> void:
	index = clampi(index, 0, LOOKS.size() - 1)
	if index == chapter:
		return
	chapter = index
	var look: Dictionary = LOOKS[index]
	sky_material.sky_top_color = Color(look.top)
	sky_material.sky_horizon_color = Color(look.horizon)
	sky_material.ground_horizon_color = Color(look.horizon)
	sky_material.ground_bottom_color = Color(look.ground)
	env.ambient_light_color = Color(look.ambient)
	env.fog_light_color = Color(look.fog)
	sun.light_color = Color(look.sun)
	water.albedo_color = Color(look.sea)
	for key in props:
		props[key].visible = key == index
	for star in stars:
		star.visible = bool(look.stars)
	for mesh in disc.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material_flat(Color(look.disc))
	disc.position = Vector3(14, 6, -60) if index != 1 else Vector3(10, -4.6, -60)
	disc.scale = Vector3.ONE * (6.0 if index != 1 else 10.0)
	_finish(props[index], Color(look.rock))
	board_key = -1

# ------------------------------------------------------------------ courier
func _courier_rig() -> void:
	add_child(courier)
	courier.scale = Vector3.ONE * COURIER_SCALE
	courier.add_child(courier_turn)
	courier_hip.position = Vector3(0, .2, 0)
	courier_turn.add_child(courier_hip)
	courier_hip.add_child(asset("courier_body"))
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * .055, 0, 0)
		pivot.add_child(asset("courier_leg"))
		courier_hip.add_child(pivot)
		courier_legs.append(pivot)
	courier_arm.position = Vector3(-.13, .19, 0)
	courier_arm.add_child(asset("courier_arm"))
	courier_hip.add_child(courier_arm)

## Procedural pose on the jointed courier. `kind`: idle, run, leap, strike,
## recoil, absorb, slump. `t` is the pose's own 0..1 progress.
func _pose(kind: String, t: float, facing: float) -> void:
	courier_turn.rotation = Vector3(0, facing, 0)
	var lean := 0.0
	var arm := 0.0
	var legs := 0.0
	var hop := 0.0
	match kind:
		"run":
			legs = sin(t * TAU) * .75
			lean = .18
			arm = -.5 + sin(t * TAU) * .3
			hop = absf(sin(t * TAU)) * .03
		"leap":
			legs = .5
			lean = .25
			arm = -1.2
		"strike":
			# Wind up behind the head, then slam the lantern staff forward.
			arm = lerpf(-2.5, 1.2, smoothstep(.35, .6, t)) if t > .35 else lerpf(0.0, -2.5, t / .35)
			lean = lerpf(-.12, .32, smoothstep(.35, .6, t))
			legs = .35
		"recoil":
			lean = -.45 * (1.0 - t * .4)
			arm = -1.6
			legs = -.4
			hop = sin(t * PI) * .05
		"absorb":
			arm = -2.9
			lean = -.08
			hop = .04 + sin(t * TAU) * .02
		"slump":
			lean = .6
			arm = .5
			legs = .2
		_:
			arm = -.3 + sin(t * TAU) * .05
			hop = absf(sin(t * PI)) * .015
	courier_hip.rotation = Vector3(lean, 0, 0)
	courier_hip.position = Vector3(0, .2 + hop, 0)
	courier_arm.rotation = Vector3(arm, 0, 0)
	courier_legs[0].rotation = Vector3(legs, 0, 0)
	courier_legs[1].rotation = Vector3(-legs, 0, 0)

# ------------------------------------------------------------------ board
## Called from main after every state/selection/layout change and each
## animated frame. `view` is a read-only dictionary built by main.
func sync(view: Dictionary) -> void:
	synced += 1
	reduced = bool(view.reduced)
	frozen = bool(view.frozen)
	if view.screen != screen and view.screen != "game":
		_reset_effects()
		level_id = ""
	screen = view.screen
	_set_chapter(4 if screen == "ending" else int(view.get("chapter", 0)))
	board.visible = screen == "game"
	finale.visible = screen == "ending"
	courier.visible = board.visible or finale.visible
	fx.visible = courier.visible and not frozen
	fx.queue_redraw()
	if screen == "ending":
		courier.position = at(Vector2(300, 760), .6)
		courier.scale = Vector3.ONE * COURIER_SCALE * 1.6
		_pose("absorb", fmod(clock, 1.0), deg_to_rad(10))
		return
	courier.scale = Vector3.ONE * COURIER_SCALE
	if not board.visible:
		return
	var level: Dictionary = view.level
	var state: Dictionary = view.state
	if level.get("id", "") != level_id:
		level_id = level.get("id", "")
		_reset_effects()
		shown_floors = state.claimed.size() + 1
	var key := hash([level.get("id", ""), level.rooms, view.rects, camera.position, chapter])
	if key != board_key:
		_rebuild(view)
		board_key = key
	var pending_room: String = view.get("pending_room", "")
	if pending_room != "" and (encounter.is_empty() or encounter.room != pending_room):
		_begin(view, pending_room)
	elif pending_room == "" and not encounter.is_empty():
		_resolve(view)
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
		entry.banner.visible = claimed
		if entry.cage != null:
			entry.cage.visible = not claimed
			entry.keeper.visible = not collapsed
			entry.keeper.position = entry.cage.position + (Vector3(0, absf(sin(clock * 5.0)) * .12, .1) if claimed and celebrate > 0.0 else Vector3.ZERO)
		var spirit_tint := Color.WHITE if not blocked else Color("8a8fa6")
		var fighting: bool = not encounter.is_empty() and encounter.room == room.id
		for spirit in entry.spirits:
			spirit.node.visible = not claimed and not collapsed
			if not fighting:
				spirit.node.scale = Vector3.ONE * float(spirit.size)
				spirit.node.rotation = Vector3(0, spirit.turn, 0)
				if reduced:
					spirit.node.position = spirit.base
			if spirit.tint != spirit_tint:
				_finish(spirit.node, spirit_tint)
				spirit.tint = spirit_tint
	_home(view)
	courier_base = at(view.courier + Vector2(0, 32), .3)
	flight = float(view.flight)
	if not encounter.is_empty():
		_play_encounter(flight)
	elif returning.t < 1.0:
		_place_return()
	else:
		courier.position = courier_base
		courier.rotation = Vector3.ZERO
		_pose("idle", fmod(clock * .8, 1.0), deg_to_rad(40))

func _rebuild(view: Dictionary) -> void:
	for child in board.get_children():
		child.queue_free()
		board.remove_child(child)
	room_nodes.clear()
	spirits.clear()
	home_nodes.clear()
	var level: Dictionary = view.level
	var stone_tint := Color(LOOKS[chapter].stone)
	for column in [1, 2]:
		var top := INF
		for room in level.rooms:
			if int(room.column) == column:
				top = minf(top, (view.rects[room.id] as Rect2).position.y)
		if top < INF:
			var x: float = 182.0 + float(int(column) - 1) * 200.0 + 90.0
			var shaft := _place("tower_column", at(Vector2(x, 742)), Vector3(1, (742.0 - top) / 100.0, 1), board)
			_finish(shaft, stone_tint)
			# Flush masonry wherever this column has no chamber.
			var spans: Array = []
			for room in level.rooms:
				if int(room.column) == column:
					var r: Rect2 = view.rects[room.id]
					spans.append(Vector2(r.position.y - 6.0, r.end.y + 8.0))
			var bottom := 742.0
			while bottom > top + 1.0:
				var covered := false
				for span in spans:
					if bottom > span.x and bottom <= span.y + .5:
						bottom = span.x
						covered = true
				if covered:
					continue
				var ceiling := top
				for span in spans:
					if span.y < bottom and span.y > ceiling:
						ceiling = span.y
				var height := minf(50.0, bottom - ceiling)
				if height < 1.0:
					break
				var segment := _place("tower_segment", at(Vector2(x, bottom)), Vector3(1, height / 50.0, 1), board)
				_finish(segment, stone_tint)
				bottom -= height
			var roof := _place("tower_roof", at(Vector2(x, top - 6)), Vector3.ONE, board)
			_finish(roof, stone_tint)
	for room in level.rooms:
		var rect: Rect2 = view.rects[room.id]
		var node := _place("room", at(rect.get_center()), Vector3(rect.size.x / 180.0, rect.size.y / 100.0, 1), board)
		var flag := _place("banner", Vector3(0, .36, -.62), Vector3.ONE, node)
		var entry := {"node": node, "tint": Color.WHITE, "spirits": [], "banner": flag, "cage": null, "keeper": null}
		var count: int = room.enemies.size()
		var compact: bool = rect.size.y < 120
		if bool(room.get("rescue", false)) or bool(room.get("keeper", false)):
			var spot := _floor_point(rect, 156.0, ROOM_DEPTH - .2)
			entry.keeper = _place("keeper", spot, Vector3.ONE * (.78 if compact else .9), board)
			entry.keeper.rotation.y = deg_to_rad(-30)
			entry.cage = _place("cage", spot, Vector3.ONE * (.78 if compact else .9), board)
		for i in count:
			var value: int = int(room.enemies[i])
			var kind := "spirit" if value < 10 else ("spirit_knight" if value < 100 else "spirit_golem")
			var size := (.98 if compact else 1.16) * (1.0 if count < 3 else .84)
			var base := _floor_point(rect, (i + 1) * 180.0 / (count + 1), ROOM_DEPTH)
			var spirit := _place(kind, base, Vector3.ONE * size, board)
			spirit.rotation.y = deg_to_rad(-34 + i * 6)
			var record := {"turn": spirit.rotation.y, "node": spirit, "base": base, "size": size, "phase": float(i) * 1.7 + float(rect.position.x) * .01, "tint": Color.WHITE, "room": room.id, "index": i}
			entry.spirits.append(record)
			spirits.append(record)
		room_nodes[room.id] = entry
	home_roof = _place("home_roof", Vector3.ZERO, Vector3.ONE, board)

## World point on a chamber's floor, `x` design pixels from the room's left.
func _floor_point(rect: Rect2, x: float, depth: float) -> Vector3:
	var floor_y := rect.size.y * .5 + 28.0 * rect.size.y / 100.0
	return Vector3((rect.position.x + x) * U, -(rect.position.y + floor_y) * U, depth)

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
			var height := (stride - 2.0) / 98.0
			var k := 1.0
			if i == grow.index and grow.t < 1.0:
				k = _elastic(grow.t)
			node.scale = Vector3(1, height * k, 1)
	var roof_y := 692.0 - (floors - 1) * stride
	if grow.index == floors - 1 and grow.t < 1.0:
		roof_y = lerpf(roof_from, roof_y, clampf(_elastic(grow.t), 0.0, 1.2))
	home_roof.position = at(Vector2(89, roof_y), .05)
	shown_floors = floors

static func _elastic(t: float) -> float:
	if t <= 0.0: return 0.001
	if t >= 1.0: return 1.0
	return maxf(.001, 1.0 - pow(2.0, -10.0 * t) * cos(t * TAU * 1.5))

# --------------------------------------------------------------- encounter
## The order of strikes in the chosen room, read from the visible numbers
## exactly as the forecast describes them (trap first, then left to right).
static func plan(room: Dictionary, state: Dictionary) -> Array:
	var power := int(state.power)
	var slots: Array = []
	if int(room.trap) > 0:
		if int(state.shields) > 0:
			slots.append({"kind": "shield", "value": int(room.trap), "index": -1})
		else:
			power -= int(room.trap)
			slots.append({"kind": "trap", "value": int(room.trap), "index": -1})
			if power <= 0:
				return slots
	for i in room.enemies.size():
		var enemy := int(room.enemies[i])
		if power <= enemy:
			slots.append({"kind": "lose", "index": i, "value": enemy, "before": power})
			return slots
		slots.append({"kind": "win", "index": i, "value": enemy, "before": power})
		power += enemy
	return slots

func _begin(view: Dictionary, room_id: String) -> void:
	var room: Dictionary = {}
	for item in view.level.rooms:
		if item.id == room_id:
			room = item
	var rect: Rect2 = view.rects[room_id]
	var slots := plan(room, view.state)
	var count: int = room.enemies.size()
	var stands: Array = []
	for slot in slots:
		var x := 30.0
		if int(slot.index) >= 0:
			x = maxf(26.0, (int(slot.index) + 1) * 180.0 / (count + 1) - 40.0)
		stands.append(_floor_point(rect, x, ROOM_DEPTH + .1))
	if stands.is_empty():
		stands.append(_floor_point(rect, 40.0, ROOM_DEPTH + .1))
	returning.t = 1.0
	encounter = {"room": room_id, "rect": rect, "slots": slots, "stands": stands, "moves": int(view.state.moves),
		"power": int(view.state.power), "last": 0.0, "home": at(view.courier + Vector2(0, 32), .3), "win": bool(view.get("pending_win", true))}

## Strike impact time (in rule-beat fraction) of slot `s`.
func _impact(s: int) -> float:
	var n: int = maxi(1, encounter.slots.size())
	return TRAVEL + (float(s) + .55) / n * (ABSORB - TRAVEL)

func _play_encounter(f: float) -> void:
	var slots: Array = encounter.slots
	var stands: Array = encounter.stands
	var n: int = maxi(1, slots.size())
	var last: float = encounter.last
	if reduced:
		courier.position = courier_base
		_pose("idle", 0.0, deg_to_rad(40))
		encounter.last = f
		return
	var position_value: Vector3
	var facing := deg_to_rad(70)
	if f < TRAVEL:
		var t := smoothstep(0.0, 1.0, f / TRAVEL)
		var from: Vector3 = encounter.home
		var to: Vector3 = stands[0]
		position_value = from.lerp(to, t) + Vector3(0, sin(t * PI) * .9, sin(t * PI) * .7)
		if t < .85:
			_pose("leap" if t > .12 and t < .78 else "run", f / TRAVEL * 2.0, facing if to.x >= from.x else -facing)
		else:
			_pose("run", fmod(f * 9.0, 1.0), facing)
	elif f < ABSORB:
		var local := (f - TRAVEL) / (ABSORB - TRAVEL) * n
		var s := mini(n - 1, int(local))
		var st := local - s
		var previous: Vector3 = stands[maxi(0, s - 1)] if s > 0 else stands[0]
		position_value = previous.lerp(stands[mini(s, stands.size() - 1)], smoothstep(0.0, .35, st))
		var kind: String = slots[s].kind if s < slots.size() else "win"
		if st < .35 and s > 0:
			_pose("run", st / .35, facing)
		elif kind in ["lose", "trap"] and st > .55:
			_pose("recoil", (st - .55) / .45, facing)
			position_value += Vector3(-.28 * smoothstep(.55, 1.0, st), 0, 0)
		else:
			_pose("strike", clampf((st - .1) / .7, 0, 1), facing)
	else:
		var t := (f - ABSORB) / (1.0 - ABSORB)
		var final_kind: String = slots[slots.size() - 1].kind if not slots.is_empty() else "win"
		position_value = stands[stands.size() - 1]
		if final_kind in ["lose", "trap"]:
			position_value += Vector3(-.28, 0, 0)
			_pose("slump", t, facing)
		else:
			_pose("absorb", t, facing)
	courier.position = position_value
	courier.rotation = Vector3.ZERO
	# Enemy reactions and one-shot effects at each strike.
	for s in slots.size():
		var slot: Dictionary = slots[s]
		var hit := _impact(s)
		if last < hit and f >= hit:
			_strike_effects(slot)
		if int(slot.index) >= 0:
			var record := _spirit_record(encounter.room, int(slot.index))
			if record.is_empty():
				continue
			var node: Node3D = record.node
			var base: Vector3 = record.base
			if f >= hit and slot.kind == "win":
				var k := clampf((f - hit) / .13, 0.0, 1.0)
				node.position = base + Vector3(.32 * k, sin(k * PI) * .28 - .2 * k * k, .45 * k)
				node.rotation = Vector3(0, float(record.turn), -k * 2.4)
				node.scale = Vector3.ONE * float(record.size) * (1.0 - k * .95)
			elif f >= hit:
				var shake := sin((f - hit) * 160.0) * .03 * maxf(0.0, 1.0 - (f - hit) * 6.0)
				node.position = base + Vector3(shake, 0, 0)
			elif f >= hit - .05:
				node.position = base + Vector3(.02, 0, 0)
	encounter.last = f

func _spirit_record(room_id: String, index: int) -> Dictionary:
	if not room_nodes.has(room_id):
		return {}
	var list: Array = room_nodes[room_id].spirits
	return list[index] if index < list.size() else {}

func _strike_effects(slot: Dictionary) -> void:
	var where: Vector3 = courier.position + Vector3(.3, .28, .05)
	if int(slot.index) >= 0:
		var record := _spirit_record(encounter.room, int(slot.index))
		if not record.is_empty():
			where = record.base + Vector3(0, .25, .05)
	match slot.kind:
		"win":
			_burst(where, GOLD, 12, 1.0)
			_ring(where, Color(1, .86, .5, .9), .5)
			_pop("+%d" % int(slot.value), board_point(where) + Vector2(0, -40), 40, GOLD, .9)
			for i in 6:
				_orb(where + Vector3(randf_range(-.08, .08), randf_range(-.05, .1), 0), i * .035, Color("ffe7a0"))
		"lose":
			_burst(where, RED, 14, 1.0)
			_ring(where, Color(1, .4, .35, .9), .5)
			_pop("EQUAL LOSES" if int(slot.before) == int(slot.value) else "TOO STRONG", board_point(where) + Vector2(0, -40), 30, RED, 1.1)
		"trap":
			var feet: Vector3 = courier.position
			for i in 5:
				_burst(feet + Vector3(-.15 + i * .08, .02, 0), Color("bff3ff"), 3, .8)
			_ring(feet + Vector3(0, .05, 0), Color(1, .4, .35, .8), .45)
			_pop("TRAP -%d" % int(slot.value), board_point(feet) + Vector2(0, -70), 32, RED, 1.0)
		"shield":
			var body: Vector3 = courier.position + Vector3(0, .3, 0)
			_ring(body, Color(.55, .9, 1, .9), .7)
			_burst(body, Color("9fe8ff"), 10, .8)
			_pop("SHIELD", board_point(body) + Vector2(0, -50), 30, Color("9fe8ff"), 1.0)

func _resolve(view: Dictionary) -> void:
	var state: Dictionary = view.state
	var room_id: String = encounter.room
	var resolved: bool = int(state.moves) == int(encounter.moves) + 1
	var start: Vector3 = courier.position
	if resolved and room_id in state.claimed:
		var gain := int(state.power) - int(encounter.power)
		var rect: Rect2 = encounter.rect
		_pop(("+%d" % gain) if gain >= 0 else str(gain), Vector2(rect.get_center().x, rect.position.y + 4), 54, GOLD, 1.3, true)
		hud_pulse = 1.0
		hud_gain = gain
		if not reduced:
			_ring(start + Vector3(0, .3, 0), Color(.45, 1, .85, .9), .9)
			var top := at(Vector2(89, 692.0 - state.claimed.size() * float(view.home_stride)), .05)
			for i in 12:
				_orb(start + Vector3(randf_range(-.2, .2), .3 + randf_range(0, .2), 0), .05 + i * .03, Color("8ff5d6"), top + Vector3(0, .3, .1), .55)
			grow = {"index": state.claimed.size(), "t": -GROW_DELAY / GROW_TIME}
			roof_from = 692.0 - (state.claimed.size() - 1) * float(view.home_stride)
		if state.status == "won":
			celebrate = 2.2 if not reduced else 0.0
			_pop("KEEPER RESCUED", Vector2(300, 300), 44, TEAL, 2.0, true)
	elif resolved and state.status == "lost":
		_pop("LANTERN OUT", board_point(start + Vector3(0, .7, 0)), 40, RED, 1.4, true)
	encounter = {}
	if not reduced and start.distance_to(courier_base) > .05:
		returning = {"t": 0.0, "from": start}

func _place_return() -> void:
	var t := smoothstep(0.0, 1.0, returning.t)
	var from: Vector3 = returning.from
	courier.position = from.lerp(courier_base, t) + Vector3(0, sin(t * PI) * .8, sin(t * PI) * .7)
	_pose("leap" if t < .85 else "idle", t, deg_to_rad(-70) if courier_base.x < from.x else deg_to_rad(70))

## True once every post-move animation has finished (used by tests).
func settled() -> bool:
	return encounter.is_empty() and returning.t >= 1.0 and grow.t >= 1.0

func _reset_effects() -> void:
	encounter = {}
	returning.t = 1.0
	grow = {"index": -1, "t": 1.0}
	celebrate = 0.0
	hud_pulse = 0.0
	pops.clear()
	for list in [sparks, rings, orbs]:
		for item in list:
			item.life = 0.0
			item.node.visible = false

# ------------------------------------------------------------------ effects
func _pools() -> void:
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(.045, .045, .045)
	for i in 64:
		var node := MeshInstance3D.new()
		node.mesh = spark_mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		sparks.append({"node": node, "life": 0.0, "max": 1.0, "velocity": Vector3.ZERO})
	var torus := TorusMesh.new()
	torus.inner_radius = .95
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	for i in 8:
		var node := MeshInstance3D.new()
		node.mesh = torus
		node.rotation.x = PI / 2
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override = _flat(Color.WHITE, true)
		node.visible = false
		add_child(node)
		rings.append({"node": node, "life": 0.0, "max": .5, "size": .5, "color": Color.WHITE})
	var sphere := SphereMesh.new()
	sphere.radius = .045
	sphere.height = .09
	sphere.radial_segments = 8
	sphere.rings = 4
	for i in 40:
		var node := MeshInstance3D.new()
		node.mesh = sphere
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		orbs.append({"node": node, "life": 0.0, "max": .4, "delay": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "target": null})
	for i in 34:
		var node := MeshInstance3D.new()
		node.mesh = sphere
		node.scale = Vector3.ONE * 3.0
		node.material_override = _flat(Color("ffd98a"))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		finale.add_child(node)
		lanterns.append({"node": node, "x": 30.0 + fmod(i * 97.0, 540.0), "speed": .5 + fmod(i * .37, .6), "phase": fmod(i * .29 + i * .013, 1.0)})

func _take(pool: Array) -> Dictionary:
	var oldest: Dictionary = pool[0]
	for item in pool:
		if item.life <= 0.0:
			return item
		if item.life < oldest.life:
			oldest = item
	return oldest

func _burst(where: Vector3, color: Color, count: int, power: float) -> void:
	if reduced:
		return
	for i in count:
		var item := _take(sparks)
		var angle := float(i) / count * TAU + randf() * .4
		item.velocity = Vector3(cos(angle), sin(angle) * .8 + .6, randf_range(.1, .6)) * randf_range(1.2, 2.4) * power
		item.life = randf_range(.3, .45)
		item.max = item.life
		item.node.position = where
		item.node.material_override = material_flat(color)
		item.node.visible = true

func material_flat(color: Color) -> StandardMaterial3D:
	var key := "flat" + color.to_html()
	if not materials.has(key):
		materials[key] = _flat(color)
	return materials[key]

func _ring(where: Vector3, color: Color, size: float) -> void:
	if reduced:
		return
	var item := _take(rings)
	item.life = .38
	item.max = .38
	item.size = size
	item.color = color
	item.node.position = where
	item.node.visible = true

func _orb(from: Vector3, delay: float, color: Color, to: Variant = null, duration: float = .32) -> void:
	if reduced:
		return
	var item := _take(orbs)
	item.from = from
	item.target = to
	item.delay = delay
	item.life = duration + delay
	item.max = duration
	item.node.material_override = material_flat(color)
	item.node.position = from
	item.node.visible = false

func _pop(text: String, where: Vector2, size: int, color: Color, life: float, big: bool = false) -> void:
	pops.append({"text": text, "at": where, "size": size, "color": color, "t": 0.0, "life": life, "big": big})
	if pops.size() > 12:
		pops.pop_front()

func _process(delta: float) -> void:
	if frozen or not courier.visible:
		return
	clock += delta
	if not reduced:
		for record in spirits:
			if not encounter.is_empty() and record.room == encounter.room:
				continue
			var node: Node3D = record.node
			node.position = record.base + Vector3(0, absf(sin(clock * 2.6 + record.phase)) * .03, 0)
			node.rotation.z = sin(clock * 1.7 + record.phase) * .06
		if beacon:
			beacon.rotation.y = clock * .8
		for i in auroras.size():
			auroras[i].position.x = 3 + sin(clock * .3 + i) * 2.0
	if returning.t < 1.0:
		returning.t = minf(1.0, returning.t + delta / RETURN_TIME)
		if encounter.is_empty() and board.visible:
			_place_return()
	elif encounter.is_empty() and board.visible and not reduced:
		_pose("idle", fmod(clock * .8, 1.0), deg_to_rad(40))
	if grow.t < 1.0:
		grow.t = minf(1.0, grow.t + delta / GROW_TIME)
		if grow.t >= 0.0 and grow.t - delta / GROW_TIME < 0.0 and home_roof:
			_burst(home_roof.position + Vector3(0, .3, .1), Color("8ff5d6"), 14, 1.0)
			_ring(home_roof.position + Vector3(0, .2, .1), Color(.5, 1, .85, .9), .9)
		var parent := get_parent()
		if parent is CanvasItem:
			parent.queue_redraw()
	if celebrate > 0.0:
		var before := celebrate
		celebrate -= delta
		if int(before * 4.0) != int(celebrate * 4.0) and home_roof:
			var where := Vector3(randf_range(1.0, 5.0), randf_range(-3.5, -1.0), .3)
			var colors := [GOLD, TEAL, Color("ff9ad5"), Color("9fe8ff")]
			var color: Color = colors[int(celebrate * 4.0) % 4]
			_burst(where, color, 16, 1.2)
			_ring(where, Color(color, .9), .8)
	for item in sparks:
		if item.life > 0.0:
			item.life -= delta
			item.velocity.y -= 5.5 * delta
			item.node.position += item.velocity * delta
			item.node.scale = Vector3.ONE * maxf(.05, item.life / item.max)
			item.node.visible = item.life > 0.0
	for item in rings:
		if item.life > 0.0:
			item.life -= delta
			var k: float = 1.0 - item.life / item.max
			item.node.scale = Vector3.ONE * item.size * (.3 + k)
			(item.node.material_override as StandardMaterial3D).albedo_color = Color(item.color, item.color.a * (1.0 - k))
			item.node.visible = item.life > 0.0
	for item in orbs:
		if item.life > 0.0:
			item.life -= delta
			var elapsed: float = item.max - item.life
			if elapsed < 0.0:
				continue
			var k := clampf(elapsed / item.max, 0.0, 1.0)
			var target: Vector3 = item.target if item.target != null else courier.position + Vector3(0, .32, .05)
			item.node.position = item.from.lerp(target, k * k) + Vector3(0, sin(k * PI) * .35, 0)
			item.node.scale = Vector3.ONE * (1.4 - k * .6)
			item.node.visible = item.life > 0.0
	if finale.visible:
		for lantern in lanterns:
			var k := fmod(clock * lantern.speed * .12 + lantern.phase, 1.0)
			lantern.node.position = at(Vector2(lantern.x + sin(clock + lantern.phase * 6.0) * 8.0, 720.0 - k * 340.0), -1.0)
			lantern.node.scale = Vector3.ONE * (3.6 * (1.0 - k * .55))
		_pose("absorb", fmod(clock, 1.0), deg_to_rad(10))
	hud_pulse = maxf(0.0, hud_pulse - delta / 1.1)
	for pop in pops:
		pop.t += delta
	pops = pops.filter(func(pop): return pop.t < pop.life)
	fx.queue_redraw()

func _draw_fx() -> void:
	if hud_pulse > 0.0 and screen == "game":
		var glow := Color(1, .85, .45, hud_pulse * .9)
		var rect := Rect2(24, 146, 260, 72).grow(4.0 + (1.0 - hud_pulse) * 6.0)
		fx.draw_rect(rect, glow, false, 4.0)
		var text := "+%d" % hud_gain
		var y := 205.0 - (1.0 - hud_pulse) * 18.0
		fx.draw_string_outline(font, Vector2(196, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(INK, hud_pulse))
		fx.draw_string(font, Vector2(196, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(GOLD, hud_pulse))
	for pop in pops:
		var k: float = pop.t / pop.life
		var grow_scale := 1.0 + (.5 * (1.0 - smoothstep(0.0, .18, k)) if pop.big else 0.0)
		var size := int(pop.size * grow_scale)
		var alpha := 1.0 - smoothstep(.7, 1.0, k)
		var rise := (60.0 if pop.big else 46.0) * (1.0 - pow(1.0 - minf(1.0, k * 1.6), 2.0))
		var width := font.get_string_size(pop.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var where: Vector2 = pop.at + Vector2(-width * .5, -rise)
		where.x = clampf(where.x, 8.0, 592.0 - width)
		fx.draw_string_outline(font, where, pop.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(6, size / 5), Color(INK, alpha))
		fx.draw_string(font, where, pop.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(pop.color, alpha))

# ------------------------------------------------------------------ ending
func _finale() -> void:
	# Twelve answering watches along the quay, back row smaller.
	for i in 12:
		var back := i >= 6
		var x := 50.0 + (i % 6) * 100.0 + (50.0 if back else 0.0)
		var floors := 2 + (i * 5 + 3) % 4 + (0 if back else 1)
		var depth := -2.2 if back else -.6
		var size := .62 if back else .74
		for f in floors:
			var node := _place("home_floor", Vector3.ZERO, Vector3(size, size * .62, size), finale)
			node.position = Vector3(x * U, SEA_Y + f * .62 * size, depth)
		var roof := _place("home_roof", Vector3(x * U, SEA_Y + floors * .62 * size, depth), Vector3.ONE * size, finale)
		roof.rotation.y = (i % 3 - 1) * .12
