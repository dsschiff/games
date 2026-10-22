extends RefCounted
## Bounded, pooled transient effects. Every effect is cosmetic, derived from
## rule-state changes the adapter observed once, and freezes while paused.
## Reduced effects keeps tracers and telegraphs; it drops flashes, sparks,
## splats, pulses and shake.
const MAX_PARTICLES := 320
const MAX_SPLATS := 36
const MAX_TRACERS := 600
const MAX_FLOATS := 8
var host: Node3D
var tracers: MultiMeshInstance3D
var tracer_material: StandardMaterial3D
var particles: MultiMeshInstance3D
var parts: Array = []
var splats: MultiMeshInstance3D
var splat_list: Array = []
var flashes: Array[MeshInstance3D] = []
var flash_life: Array[float] = []
var floats: Array[Label3D] = []
var float_life: Array[float] = []
var globs: Array = []
var shake := 0.0
var reduced := false

func build(owner: Node3D, weapon: String) -> void:
	host = owner
	tracers = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var streak := BoxMesh.new()
	var lance := weapon == "lance"
	streak.size = Vector3(.10 if lance else .075, .10 if lance else .075, 1.5 if lance else 1.1)
	mm.mesh = streak
	mm.instance_count = MAX_TRACERS
	mm.visible_instance_count = 0
	tracers.multimesh = mm
	tracer_material = _glow({"rivet": Color("bff8ff"), "lance": Color("e7c8ff"), "fan": Color("ffd38a")}.get(weapon, Color.WHITE))
	tracers.material_override = tracer_material
	tracers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(tracers)
	particles = MultiMeshInstance3D.new()
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.use_colors = true
	var chip := BoxMesh.new()
	chip.size = Vector3(.10, .10, .10)
	pm.mesh = chip
	pm.instance_count = MAX_PARTICLES
	pm.visible_instance_count = 0
	particles.multimesh = pm
	var pmat := _glow(Color.WHITE)
	pmat.vertex_color_use_as_albedo = true
	particles.material_override = pmat
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(particles)
	splats = MultiMeshInstance3D.new()
	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_3D
	sm.use_colors = true
	var disc := CylinderMesh.new()
	disc.top_radius = .5
	disc.bottom_radius = .5
	disc.height = .01
	disc.radial_segments = 10
	disc.rings = 1
	sm.mesh = disc
	sm.instance_count = MAX_SPLATS
	sm.visible_instance_count = 0
	splats.multimesh = sm
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splats.material_override = smat
	splats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(splats)
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = .5
	flash_mesh.height = 1.0
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	var flash_material := _glow(Color("fff2b0"), .9)
	for i in 20:
		var f := MeshInstance3D.new()
		f.mesh = flash_mesh
		f.material_override = flash_material
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.visible = false
		host.add_child(f)
		flashes.append(f)
		flash_life.append(0.0)
	for i in MAX_FLOATS:
		var l := Label3D.new()
		l.font_size = 72
		l.pixel_size = .012
		l.outline_size = 18
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.visible = false
		host.add_child(l)
		floats.append(l)
		float_life.append(0.0)
	var glob_mesh := SphereMesh.new()
	glob_mesh.radius = .16
	glob_mesh.height = .32
	glob_mesh.radial_segments = 8
	glob_mesh.rings = 4
	var glob_material := _glow(Color("c8ff4a"))
	for i in 6:
		var g := MeshInstance3D.new()
		g.mesh = glob_mesh
		g.material_override = glob_material
		g.visible = false
		host.add_child(g)
		globs.append({"node": g, "life": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO})

func _glow(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

func clear() -> void:
	parts.clear()
	splat_list.clear()
	particles.multimesh.visible_instance_count = 0
	splats.multimesh.visible_instance_count = 0
	tracers.multimesh.visible_instance_count = 0
	for i in flashes.size():
		flashes[i].visible = false
		flash_life[i] = 0
	for i in floats.size():
		floats[i].visible = false
		float_life[i] = 0
	for g in globs:
		g.node.visible = false
		g.life = 0
	shake = 0

## Rule bullets drawn as streaks at their exact rule positions.
## Rounds rise gently from muzzle height near the squad to head height far
## down the road, where elevated cages and pumps hang over the lanes.
func draw_tracers(bullets: Array) -> void:
	var mm := tracers.multimesh
	var n := mini(bullets.size(), MAX_TRACERS)
	for i in n:
		var b: Dictionary = bullets[i]
		var dir := Vector3(b.dx, .02, -.48).normalized()
		var basis := Basis.looking_at(dir, Vector3.UP)
		var y := lerpf(.75, 1.15, clampf((float(b.z) - 3.0) / 10.0, 0, 1))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(b.x, y, -b.z + .3)))
	mm.visible_instance_count = n

func muzzle(slot: int, at: Vector3) -> void:
	if reduced or slot >= flashes.size(): return
	flashes[slot].position = at
	flashes[slot].scale = Vector3(.22, .22, .32) * (.85 + .1 * (slot % 4))
	flashes[slot].visible = true
	flash_life[slot] = .06

func burst(at: Vector3, color: Color, count: int, power: float = 2.2, size: float = 1.0) -> void:
	if reduced: return
	for i in count:
		if parts.size() >= MAX_PARTICLES: parts.pop_front()
		var a := float(i) / count * TAU + float(parts.size()) * .37
		var up := .6 + fmod(float(i) * .618, 1.0) * 1.4
		parts.append({"p": at, "v": Vector3(cos(a) * power, up * power, sin(a) * power * .6), "life": .38, "max": .38, "c": color, "s": size * (.7 + fmod(float(i) * .41, .6))})

func splat(at: Vector3, color: Color, radius: float) -> void:
	if reduced: return
	if splat_list.size() >= MAX_SPLATS: splat_list.pop_front()
	splat_list.append({"p": Vector3(at.x, .02, at.z), "life": 2.2, "c": color, "r": radius})

func pop_text(at: Vector3, text: String, color: Color) -> void:
	var best := 0
	for i in floats.size():
		if float_life[i] < float_life[best]: best = i
	floats[best].text = text
	floats[best].modulate = color
	floats[best].outline_modulate = Color(0.05, 0.08, 0.12, 1)
	floats[best].position = at
	floats[best].visible = true
	float_life[best] = 1.1

func spit(from: Vector3, to: Vector3) -> void:
	for g in globs:
		if g.life <= 0:
			g.from = from
			g.to = to
			g.life = .55
			g.node.visible = true
			return

func kick_shake(amount: float) -> void:
	if not reduced: shake = maxf(shake, amount)

## dt is zero while paused; ground: metres the road moved this frame.
func update(dt: float, ground: float) -> void:
	var pm := particles.multimesh
	var alive: Array = []
	for p in parts:
		p.life -= dt
		if p.life <= 0: continue
		p.v.y -= 9.0 * dt
		p.p += p.v * dt
		p.p.z += ground
		if p.p.y < .03:
			p.p.y = .03
			p.v *= .4
		alive.append(p)
	parts = alive
	for i in parts.size():
		var p: Dictionary = parts[i]
		var s: float = p.s * clampf(p.life / p.max * 1.6, 0, 1)
		pm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p.p))
		pm.set_instance_color(i, p.c)
	pm.visible_instance_count = parts.size()
	var sm := splats.multimesh
	var kept: Array = []
	for s in splat_list:
		s.life -= dt
		s.p.z += ground
		if s.life > 0 and s.p.z < 14: kept.append(s)
	splat_list = kept
	for i in splat_list.size():
		var s: Dictionary = splat_list[i]
		sm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s.r, 1, s.r * .8)), s.p))
		sm.set_instance_color(i, Color(s.c, clampf(s.life / 1.2, 0, .75)))
	sm.visible_instance_count = splat_list.size()
	for i in flashes.size():
		if flash_life[i] > 0:
			flash_life[i] -= dt
			flashes[i].visible = flash_life[i] > 0
	for i in floats.size():
		if float_life[i] > 0:
			float_life[i] -= dt
			floats[i].position.y += dt * 1.2
			floats[i].modulate.a = clampf(float_life[i] / .4, 0, 1)
			floats[i].outline_modulate.a = floats[i].modulate.a
			floats[i].visible = float_life[i] > 0
	for g in globs:
		if g.life > 0:
			g.life -= dt
			var t := 1.0 - clampf(g.life / .55, 0, 1)
			g.node.position = g.from.lerp(g.to, t) + Vector3(0, sin(t * PI) * 2.2, 0)
			g.node.visible = g.life > 0
	shake = maxf(0, shake - dt * 2.5)
