extends RefCounted
## Snapshot-driven presentation for one campaign road.
## sync(state) runs once per refresh (each rule tick and UI change): it places
## rule-owned roots and observes state differences exactly once to start
## cosmetic effects. frame(dt) poses rigs and advances effects; dt is zero
## while paused. Nothing here writes rule state, consumes rule RNG or feeds
## back into the simulation. A new adapter is created on every build_world
## (load, Retry, import, road change), which clears every transient.
const C = preload("res://scripts/campaign_rules.gd")
const Kit = preload("res://scripts/presentation/kit.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Street = preload("res://scripts/presentation/street.gd")
const Fx = preload("res://scripts/presentation/fx.gd")
const ROLE_SCALE := {"drifter": 1.02, "runner": 1.0, "plated": 1.04, "spitter": 1.04, "cluster": .95, "bulwark": 1.28}
const ROLE_BLOOD := {"drifter": Color("9bd16a"), "runner": Color("e0704f"), "plated": Color("ffe7a3"), "spitter": Color("d8ff4a"), "cluster": Color("c58cff"), "bulwark": Color("b98ad0")}
const CREW_SCALE := .84
const BOSS_KEYS := ["boss_blockade", "boss_matron", "boss_ram", "boss_bell", "boss_ferry"]
const BOSS_SCALE := [1.25, 2.3, 2.25, 1.6, 1.7]

var host: Node3D
var world: Node3D
var root: Node3D
var inactive: Node3D
var kit: RefCounted
var street: RefCounted
var fx: RefCounted
var actors: Dictionary
var crew: Array = []
var anchors: Array = []
var visuals := {}
var pool := {}
var dying: Array = []
var gates: Array = []
var sides: Array = []
var carts: Array = []
var hazards: Array = []
var boss: Node3D
var boss_visual: Node3D
var boss_arms: Array = []
var boss_wheels: Array = []
var boss_label: Label3D
var boss_bar: MeshInstance3D
var boss_bar_root: Node3D
var reduced := false
var hydrated := false
var clock := 0.0
var ground_speed := 1.9
var phase := "ready"
var last := {}
var lateral := 0.0
var boss_attack := 0.0
var ending_clock := -1.0
var footprint_glow: MeshInstance3D
var state: Dictionary
var label_font: Font

func build(owner: Node3D, parent: Node3D, registry: Dictionary, s: Dictionary) -> void:
	host = owner
	world = parent
	actors = registry
	state = s
	kit = Kit.new()
	root = Node3D.new()
	root.name = "Presentation"
	world.add_child(root)
	inactive = Node3D.new()
	inactive.name = "InactiveReserves"
	inactive.hide()
	inactive.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(inactive)
	var d: Dictionary = s.definition
	ground_speed = float(d.speed)
	street = Street.new()
	street.build(root, kit, int(d.index))
	street.finalize()
	fx = Fx.new()
	fx.build(root, s.weapon)
	label_font = SystemFont.new()
	label_font.font_names = PackedStringArray(["Arial Black", "Impact", "Segoe UI Black", "sans-serif"])
	label_font.font_weight = 900
	_build_crew()
	_build_enemies(d)
	_build_gates(d)
	_build_sides(d)
	_build_carts(d)
	_build_boss(d)
	var hz_mesh := BoxMesh.new()
	hz_mesh.size = Vector3.ONE
	var holder := Node3D.new()
	holder.name = "Telegraphs"
	root.add_child(holder)
	for i in 40:
		var h := MeshInstance3D.new()
		h.mesh = hz_mesh
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, .6, .15, .45)
		h.material_override = m
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.visible = false
		holder.add_child(h)
		hazards.append(h)

func label(parent: Node3D, text: String, pos: Vector3, size: int, color: Color = Color.WHITE, outline: Color = Color("10202c")) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = label_font
	l.font_size = size
	l.pixel_size = .010
	l.outline_size = maxi(8, size / 5)
	l.modulate = color
	l.outline_modulate = outline
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.position = pos
	parent.add_child(l)
	return l

func flat(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	if alpha < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func bar(parent: Node3D, pos: Vector3, width: float, color: Color) -> MeshInstance3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var back := MeshInstance3D.new()
	back.mesh = BoxMesh.new()
	back.mesh.size = Vector3(width + .06, .12, .03)
	back.material_override = flat(Color("10202c"))
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(back)
	var fill := MeshInstance3D.new()
	fill.mesh = BoxMesh.new()
	fill.mesh.size = Vector3(width, .08, .04)
	fill.material_override = flat(color)
	fill.position.z = .02
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.set_meta("width", width)
	holder.add_child(fill)
	return fill

static func set_fill(fill: MeshInstance3D, ratio: float) -> void:
	var r := clampf(ratio, .001, 1.0)
	fill.scale.x = r
	fill.position.x = -float(fill.get_meta("width")) * .5 * (1.0 - r)

# ------------------------------------------------------------------ building
func _build_crew() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = .20
	ring_mesh.outer_radius = .26
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 6
	var ring_material := flat(Color("ffe08a"), .8)
	for i in 20:
		var a := Actor.new()
		a.name = "Crew%d" % i
		a.phase_seed = float(i) * .9
		world.add_child(a)
		a.configure("actor_crew", kit, CREW_SCALE)
		var ring := MeshInstance3D.new()
		ring.name = "JoinRing"
		ring.mesh = ring_mesh
		ring.material_override = ring_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = .03
		ring.visible = false
		a.add_child(ring)
		a.visible = false
		a.set_meta("q", Vector2.INF)
		crew.append(a)
		actors["crew" + str(i)] = a

func _build_enemies(d: Dictionary) -> void:
	# Lightweight rule anchors; pooled skinned visuals attach only while live.
	# The hidden Bounds box carries each role's authored mesh envelope.
	var bounds := {}
	for role in ROLE_SCALE:
		var probe := _take(role)
		probe.rotation.y = PI
		root.add_child(probe)
		var box := Kit.bounds(probe, root)
		root.remove_child(probe)
		_put(role, probe)
		var mesh := BoxMesh.new()
		mesh.size = box.size
		bounds[role] = {"mesh": mesh, "center": box.get_center()}
	for i in d.enemies.size():
		var role: String = d.enemies[i].role
		var anchor := Node3D.new()
		anchor.name = "Infected%d" % i
		var hull := MeshInstance3D.new()
		hull.name = "Bounds"
		hull.mesh = bounds[role].mesh
		hull.position = bounds[role].center
		hull.visible = false
		anchor.add_child(hull)
		anchor.visible = false
		root.add_child(anchor)
		anchors.append(anchor)
		actors["enemy" + str(i)] = anchor

func _take(role: String) -> Node3D:
	if pool.has(role) and not pool[role].is_empty():
		var a: Node3D = pool[role].pop_back()
		inactive.remove_child(a)
		a.process_mode = Node.PROCESS_MODE_INHERIT
		a.show()
		return a
	var fresh := Actor.new()
	fresh.configure("actor_" + role, kit, ROLE_SCALE[role])
	var hp := bar(fresh, Vector3(0, 1.62 * ROLE_SCALE[role], 0), .62, Color("ffb35c"))
	hp.get_parent().name = "Health"
	return fresh

func _put(role: String, a: Node3D) -> void:
	if a.get_parent() != null: a.get_parent().remove_child(a)
	a.reset_for_reuse()
	a.transform = Transform3D.IDENTITY
	a.hide()
	if not pool.has(role): pool[role] = []
	if pool[role].size() >= 16:
		a.queue_free()
		return
	inactive.add_child(a)
	pool[role].append(a)

func _build_gates(d: Dictionary) -> void:
	for g in d.gates:
		var node := Node3D.new()
		node.name = "Gate%d" % g.id
		root.add_child(node)
		var frame: Node3D = kit.asset("gate")
		frame.scale = Vector3(g.width, 1, 1)
		node.add_child(frame)
		var panel := MeshInstance3D.new()
		panel.mesh = QuadMesh.new()
		panel.mesh.size = Vector2(g.width * 2.0 - .1, 1.9)
		panel.position = Vector3(0, 1.08, 0)
		var m := flat(Color("3aa0ff"), .42)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		panel.material_override = m
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(panel)
		var number := label(node, "", Vector3(0, 1.25, .05), 175)
		var caption := label(node, "CREW", Vector3(0, .42, .05), 50)
		gates.append({"node": node, "panel": panel, "number": number, "caption": caption, "pulse": 0.0})
		actors["gate" + str(g.id)] = node

func _build_sides(d: Dictionary) -> void:
	for t in d.sides:
		var node := Node3D.new()
		node.name = "Side%d" % t.id
		root.add_child(node)
		var truck: Node3D = kit.asset("pump_truck" if t.kind == "pump" else "rig_truck")
		node.add_child(truck)
		var mirror := 1.0 if t.x < 0 else -1.0
		truck.scale = Vector3(mirror, 1, 1)
		truck.position = Vector3(-3.35 * mirror, 0, -.55)
		var wheels: Array = []
		for wx in [-.78, .78]:
			for wz in [-1.3, 1.25]:
				var w: Node3D = kit.asset("wheel")
				w.position = truck.position + Vector3(wx, .40, wz)
				if wx < 0: w.rotation.y = PI
				node.add_child(w)
				wheels.append(w)
		var caption := label(node, "", Vector3(0, 2.75, 0), 40)
		var fill := bar(node, Vector3(0, 2.25, 0), 1.3, Color("7fe0ff") if t.kind == "pump" else Color("ffd060"))
		sides.append({"node": node, "wheels": wheels, "label": caption, "fill": fill, "kind": t.kind})
		actors["side" + str(t.id)] = node

func _build_carts(d: Dictionary) -> void:
	for o in d.obstacles:
		var node := Node3D.new()
		node.name = "Cart%d" % o.id
		root.add_child(node)
		var cart: Node3D = kit.asset("cart")
		cart.scale = Vector3(o.width, 1, 1)
		node.add_child(cart)
		for wx in [-.85, .85]:
			var w: Node3D = kit.asset("wheel")
			w.position = Vector3(wx * o.width, .40, -.1)
			w.rotation = Vector3(.3, PI if wx < 0 else 0.0, 0)
			node.add_child(w)
		label(node, "CART  −%d" % o.loss, Vector3(0, 2.1, 0), 40, Color("ffd9a0"))
		carts.append(node)
		actors["obstacle" + str(o.id)] = node

func _build_boss(d: Dictionary) -> void:
	var kind: int = d.boss.kind
	boss = Node3D.new()
	boss.name = "Boss"
	root.add_child(boss)
	actors.boss = boss
	var scale: float = BOSS_SCALE[kind]
	if kind in [1, 2]:
		var a := Actor.new()
		a.configure(BOSS_KEYS[kind], kit, scale)
		a.rotation.y = PI
		boss.add_child(a)
		boss_visual = a
	else:
		boss_visual = kit.asset(BOSS_KEYS[kind])
		boss_visual.scale = Vector3.ONE * scale
		if kind == 4:
			# Narrow the body so both rule-owned arms at x = +-2.3 stay visible.
			boss_visual.scale = Vector3(scale * .68, scale, scale)
		boss_visual.rotation.y = PI
		boss.add_child(boss_visual)
		if kind == 0:
			for wx in [-1.2, 1.2]:
				for wz in [-.3, .3]:
					var w: Node3D = kit.asset("wheel")
					w.position = Vector3(wx, .38, wz)
					w.scale = Vector3.ONE * .9
					if wx < 0: w.rotation.y = PI
					boss.add_child(w)
					boss_wheels.append(w)
		if kind == 4:
			# The Ferry Eater rides a surge of floodwater that keeps pace with it.
			var surge := MeshInstance3D.new()
			surge.mesh = CylinderMesh.new()
			surge.mesh.top_radius = 2.6
			surge.mesh.bottom_radius = 2.6
			surge.mesh.height = .16
			surge.mesh.radial_segments = 24
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color("2f86a3")
			wm.roughness = .2
			surge.material_override = wm
			surge.position.y = .05
			surge.scale = Vector3(1.9, 1, .9)
			boss.add_child(surge)
			var foam := MeshInstance3D.new()
			foam.mesh = TorusMesh.new()
			foam.mesh.inner_radius = 2.45
			foam.mesh.outer_radius = 2.75
			foam.mesh.rings = 24
			foam.mesh.ring_segments = 4
			foam.material_override = flat(Color("e8f6f2"), .75)
			foam.position.y = .12
			foam.scale = Vector3(1.9, .4, .9)
			boss.add_child(foam)
	var top: float = [2.6, 5.4, 4.0, 5.6, 6.4][kind]
	boss_label = label(boss, "", Vector3(0, top + .55, 0), 54, Color("ffe1c4"), Color("3a0d12"))
	boss_bar = bar(boss, Vector3(0, top, 0), 2.6 if kind else 1.8, Color("ff5a4a"))
	boss_bar_root = boss_bar.get_parent()
	if kind == 4:
		for i in 2:
			var arm: Node3D = kit.asset("boss_ferry_arm")
			arm.scale = Vector3.ONE * 1.7
			arm.rotation.y = PI
			arm.position.x = -.25 if i == 0 else .25
			var holder := Node3D.new()
			holder.name = "FerryArm%d" % i
			holder.add_child(arm)
			root.add_child(holder)
			var fill := bar(holder, Vector3(0, 3.6, 0), 1.2, Color("ff8a3a"))
			boss_arms.append({"node": holder, "model": arm, "fill": fill})
			actors["arm" + str(i)] = holder

# ---------------------------------------------------------------- per tick
func sync(s: Dictionary, settings: Dictionary) -> void:
	state = s
	reduced = bool(settings.get("reduced_effects", false))
	fx.reduced = reduced
	var d: Dictionary = s.definition
	var hydrate := not hydrated
	var ticked: bool = not hydrate and int(s.tick) != int(last.get("tick", -1))
	phase = s.phase
	street.scroll(float(s.tick) / 60.0 * ground_speed)
	if ticked: lateral = (float(s.x) - float(last.get("x", s.x))) * 60.0
	elif hydrate: lateral = 0.0
	_sync_crew(s, d, hydrate, ticked)
	_sync_enemies(s, d, hydrate)
	_sync_gates(s, d, hydrate)
	_sync_sides(s, d, hydrate)
	for i in carts.size():
		carts[i].visible = false
	for i in mini(carts.size(), s.obstacles.size()):
		var o: Dictionary = s.obstacles[i]
		carts[i].visible = s.tick >= d.obstacles[i].born and not o.crossed
		carts[i].position = Vector3(d.obstacles[i].x, 0, -o.z)
	_sync_boss(s, d, hydrate)
	_sync_hazards(s, d, hydrate)
	last.tick = s.tick
	last.x = s.x
	last.crew = s.crew
	last.hazards = s.hazards.size()
	hydrated = true

func _sync_crew(s: Dictionary, d: Dictionary, hydrate: bool, ticked: bool) -> void:
	var before := int(last.get("crew", s.crew))
	for i in 20:
		var a = crew[i]
		var live: bool = i < s.crew
		if live:
			var q := C.offset(i, s.crew)
			var old: Vector2 = a.get_meta("q")
			# Formation reflow eases only on real rule ticks; synthetic or paused
			# refreshes place the visual exactly on its rule slot.
			if ticked and a.visible and old != Vector2.INF and old != q:
				a.smooth += Vector3(old.x - q.x, 0, old.y - q.y)
			a.set_meta("q", q)
			a.position = Vector3(s.x + q.x, 0, q.y)
			if not a.visible and not hydrate and i >= before:
				a.spawn()
				a.get_node("JoinRing").set_meta("life", .9)
		else:
			a.set_meta("q", Vector2.INF)
		if not ticked:
			a.smooth = Vector3.ZERO
			a.model.position.x = 0
			a.model.position.z = 0
		a.visible = live
	if hydrate: return
	if s.crew < before:
		for i in range(s.crew, mini(before, 20)):
			var fallen: Node3D = _take("crew_fallen") if pool.has("crew_fallen") and not pool["crew_fallen"].is_empty() else null
			if fallen == null:
				fallen = Actor.new()
				fallen.configure("actor_crew", kit, CREW_SCALE)
			root.add_child(fallen)
			fallen.position = crew[i].position
			fallen.die()
			dying.append({"node": fallen, "role": "crew_fallen", "life": 0.0})
			fx.burst(crew[i].position + Vector3(0, .55, 0), Color("ff6a55"), 8, 2.0)
		fx.pop_text(Vector3(s.x, 1.9, .2), "%d" % (s.crew - before), Color("ff8a7a"))
		fx.kick_shake(.6)
	elif s.crew > before:
		fx.pop_text(Vector3(s.x, 1.9, .2), "+%d" % (s.crew - before), Color("9fe2ff"))
		fx.burst(Vector3(s.x, .3, .4), Color("8fd8ff"), 14, 2.4)
	if ticked and s.phase == "playing" and int(s.tick) % int(d.weapons[s.weapon].period) == 0:
		for i in mini(s.crew, 20):
			crew[i].kick()
			fx.muzzle(i, crew[i].muzzle())

func _sync_enemies(s: Dictionary, d: Dictionary, hydrate: bool) -> void:
	# Bounded by both sizes: a synthetic caller may restore a state for a
	# different road without rebuilding; extra nodes simply stay hidden.
	for i in range(s.enemies.size(), anchors.size()): anchors[i].visible = false
	for i in mini(s.enemies.size(), anchors.size()):
		var e: Dictionary = s.enemies[i]
		var ed: Dictionary = d.enemies[i]
		var anchor: Node3D = anchors[i]
		var live: bool = s.tick >= ed.born and not e.resolved
		anchor.visible = live
		anchor.position = Vector3(ed.x, 0, -e.z)
		var v = visuals.get(i)
		var toughness := int(e.hp) + int(e.armor)
		if live and v == null:
			v = _take(ed.role)
			v.phase_seed = float(i) * 1.73
			v.reset_for_reuse()
			v.rotation.y = PI
			anchor.add_child(v)
			if not hydrate: v.spawn()
			v.set_meta("tough", toughness)
			v.set_meta("spit", e.next_spit)
			visuals[i] = v
		if v == null: continue
		if live:
			var prior: int = v.get_meta("tough")
			if toughness < prior and not hydrate:
				v.flinch()
				var hit_at: Vector3 = anchor.position + Vector3(0, .85 * ROLE_SCALE[ed.role], .2)
				if int(e.armor) < int(v.get_meta("armor", ed.armor)):
					fx.burst(hit_at, Color("fff2c0"), 6, 2.8, .8)
				else:
					fx.burst(hit_at, ROLE_BLOOD[ed.role], 6, 2.0, .95)
			v.set_meta("armor", e.armor)
			v.set_meta("tough", toughness)
			var health: Node3D = v.get_node("Health")
			health.visible = toughness < int(ed.hp) + int(ed.armor)
			set_fill(health.get_child(1), float(toughness) / (int(ed.hp) + int(ed.armor)))
			if int(e.next_spit) != int(v.get_meta("spit")) and not hydrate:
				v.windup = 1.0
				fx.spit(anchor.position + Vector3(0, .8, 0), Vector3(s.x, .05, 0))
			v.set_meta("spit", e.next_spit)
		else:
			visuals.erase(i)
			v.get_node("Health").visible = false
			if e.dead and not hydrate:
				var at: Vector3 = anchor.position
				anchor.remove_child(v)
				root.add_child(v)
				v.position = at
				v.die()
				dying.append({"node": v, "role": ed.role, "life": 0.0})
				fx.burst(at + Vector3(0, .6, 0), ROLE_BLOOD[ed.role], 16, 3.0, 1.5)
				fx.pop(at + Vector3(0, .7, 0), ROLE_BLOOD[ed.role], 1.3 if ed.role != "bulwark" else 1.9)
				fx.splat(at, ROLE_BLOOD[ed.role].darkened(.35), .55 if ed.role != "bulwark" else .9)
			else:
				if not hydrate:
					fx.burst(Vector3(ed.x, .4, .6), Color("ff4a3a"), 10, 2.2)
					fx.kick_shake(.4)
				_put(ed.role, v)

func _sync_gates(s: Dictionary, d: Dictionary, hydrate: bool) -> void:
	for i in range(s.gates.size(), gates.size()): gates[i].node.visible = false
	for i in mini(gates.size(), s.gates.size()):
		var g: Dictionary = s.gates[i]
		var info: Dictionary = gates[i]
		var node: Node3D = info.node
		node.visible = s.tick >= d.gates[i].born and not g.crossed
		node.position = Vector3(d.gates[i].x, 0, -g.z)
		var positive: bool = g.value >= 0
		info.number.text = "%+d" % g.value if g.value != 0 else "0"
		info.number.outline_modulate = Color("0b3d8a") if positive else Color("7a1010")
		info.caption.text = "CREW"
		info.caption.outline_modulate = info.number.outline_modulate
		(info.panel.material_override as StandardMaterial3D).albedo_color = Color(Color("3aa0ff") if positive else Color("ff4a3a"), .42)
		if not hydrate and int(g.hits) > int(info.get("hits", g.hits)):
			info.pulse = .16
			fx.burst(node.position + Vector3(0, 1.1, .1), Color("bfe8ff") if positive else Color("ffc0b0"), 3, 1.4, .5)
		info.hits = g.hits

func _sync_sides(s: Dictionary, d: Dictionary, hydrate: bool) -> void:
	for i in range(s.sides.size(), sides.size()): sides[i].node.visible = false
	for i in mini(sides.size(), s.sides.size()):
		var t: Dictionary = d.sides[i]
		var side: Dictionary = s.sides[i]
		var info: Dictionary = sides[i]
		var node: Node3D = info.node
		node.visible = s.tick >= t.born and s.tick <= t.until and not side.claimed
		node.position = Vector3(t.x, 0, -t.z)
		info.label.text = ("FLOOD PUMP" if t.kind == "pump" else "RIGGING CRANE") + "\n%d / %d  ·  +%d CREW" % [side.hp, t.hp, t.reward]
		set_fill(info.fill, float(side.hp) / t.hp)
		if not hydrate:
			if int(side.hp) < int(info.get("hp", side.hp)) and not side.claimed:
				fx.burst(node.position + Vector3(0, 1.4, .2), Color("ffe08a"), 2, 1.6, .5)
			if side.claimed and not info.get("claimed", side.claimed):
				fx.burst(node.position + Vector3(0, 1.4, 0), Color("9fe2ff"), 22, 3.0, 1.2)
		info.hp = side.hp
		info.claimed = side.claimed

func _sync_boss(s: Dictionary, d: Dictionary, hydrate: bool) -> void:
	var b: Dictionary = s.boss
	var bd: Dictionary = d.boss
	var live: bool = s.tick >= bd.born and not b.dead
	boss.visible = live
	boss.position = Vector3(b.x, 0, -b.z)
	boss_label.text = "%s\n%d / %d" % [String(bd.title).to_upper(), b.hp, bd.hp]
	set_fill(boss_bar, float(b.hp) / maxf(1, bd.hp))
	if not hydrate and int(b.hp) < int(last.get("boss_hp", b.hp)):
		fx.burst(boss.position + Vector3(0, 1.6, .5), Color("ffd2a0"), 3, 2.0, .7)
		if boss_visual.has_method("flinch") and fmod(clock, .3) < .1: boss_visual.flinch()
	if not hydrate and b.dead and not bool(last.get("boss_dead", b.dead)):
		fx.burst(boss.position + Vector3(0, 1.5, 0), Color("ffb070"), 40, 4.0, 1.6)
		fx.pop(boss.position + Vector3(0, 2.0, 0), Color("ffb070"), 4.5)
		fx.kick_shake(.8)
	last["boss_hp"] = b.hp
	last["boss_dead"] = b.dead
	for i in boss_arms.size():
		var arm: Dictionary = boss_arms[i]
		var alive: bool = live and int(b.arms[i]) > 0
		if not hydrate and arm.node.visible and not alive and live:
			fx.burst(arm.node.position + Vector3(0, 1.5, 0), Color("ff8a3a"), 26, 3.4, 1.3)
		arm.node.visible = alive
		arm.node.position = Vector3(-2.3 if i == 0 else 2.3, 0, -b.z)
		set_fill(arm.fill, float(b.arms[i]) / maxf(1, bd.arms))
		if not hydrate and int(b.arms[i]) < int(arm.get("hp", b.arms[i])):
			fx.burst(arm.node.position + Vector3(0, 1.6, .5), Color("ffb070"), 2, 1.8, .6)
		arm.hp = b.arms[i]

func _sync_hazards(s: Dictionary, d: Dictionary, hydrate: bool) -> void:
	var count: int = int(last.get("hazards", s.hazards.size())) if not hydrate else s.hazards.size()
	for k in range(count, s.hazards.size()):
		if int(s.hazards[k].source) == -1: boss_attack = 1.0
	var active: Array = []
	for h in s.hazards:
		var fired: bool = s.tick >= h.fire
		if not h.resolved or (not h.cancelled and fired and s.tick - h.fire < 15):
			active.append(h)
		if not hydrate and fired and int(s.tick) == int(h.fire) and not h.cancelled and int(last.get("tick", -1)) != int(s.tick):
			fx.burst(Vector3(h.x, .2, -.4), Color("ff5a3a") if int(h.source) > -2 else Color("8fd8ff"), 14, 2.6, .9)
	for i in hazards.size():
		var node: MeshInstance3D = hazards[i]
		node.visible = i < active.size()
		if node.visible:
			var h: Dictionary = active[i]
			node.position = Vector3(h.x, .035, -.2)
			node.scale = Vector3(h.width * 2, .02, 3.9)
			var fired: bool = s.tick >= h.fire
			var pulse := 0.0 if reduced or fired else .12 * sin(float(s.tick) * .35)
			(node.material_override as StandardMaterial3D).albedo_color = Color(1, .14, .08, .66) if fired else Color(1, .58, .12, .40 + pulse)

# --------------------------------------------------------------- per frame
func frame(delta: float, frozen: bool) -> void:
	var dt := 0.0 if frozen else delta
	clock += dt
	var playing := phase == "playing"
	var ground := ground_speed * dt if playing else 0.0
	var forward := ground_speed if playing else 0.0
	for a in crew:
		if not a.visible: continue
		a.cheer = phase == "victory"
		a.pose_crew(dt, forward, lateral if playing else 0.0)
		var ring: MeshInstance3D = a.get_node("JoinRing")
		var life := float(ring.get_meta("life", 0.0)) - dt
		ring.set_meta("life", life)
		ring.visible = life > 0 and not reduced
		if ring.visible: ring.scale = Vector3.ONE * (1.0 + (.9 - life) * 1.4)
	var d: Dictionary = state.definition
	for i in visuals:
		var v = visuals[i]
		if i >= d.enemies.size(): continue
		var ed: Dictionary = d.enemies[i]
		v.windup = maxf(0, v.windup - dt * 2.2)
		v.pose_infected(dt, (float(ed.speed) - ground_speed) if playing else 0.0, ed.role, clock)
	var kept: Array = []
	for item in dying:
		item.life += dt
		var n: Node3D = item.node
		n.position.z += ground
		if item.role == "crew_fallen": n.pose_crew(dt, 0, 0)
		else: n.pose_infected(dt, 0, item.role, clock)
		# Bodies lie on the moving road, then shrink away; nothing sinks
		# through the surface.
		n.fade = 1.0 - smoothstep(1.0, 1.5, item.life)
		if item.life > 1.5 or n.position.z > 12:
			_put(item.role, n)
		else:
			kept.append(item)
	dying = kept
	boss_attack = maxf(0, boss_attack - dt * .8)
	_frame_boss(dt, playing)
	for info in gates:
		info.pulse = maxf(0, info.pulse - dt)
		var p: float = 1.0 + (0.0 if reduced else info.pulse / .16 * .22)
		info.number.scale = Vector3.ONE * p
	for info in sides:
		for w in info.wheels: w.rotation.x -= ground / .40
	if phase == "victory" and int(d.index) == 23 and not bool(d.replay):
		ending_clock = maxf(0, ending_clock) + dt
		street.ferry_depart(ending_clock)
	fx.update(dt, ground)
	var cam: Camera3D = host.camera
	if fx.shake > 0 and not frozen:
		cam.h_offset = sin(clock * 53.0) * fx.shake * .10
		cam.v_offset = cos(clock * 47.0) * fx.shake * .07
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	if not state.is_empty() and phase == "playing":
		fx.draw_tracers(state.bullets)
	elif not frozen:
		fx.draw_tracers([])

func _frame_boss(dt: float, playing: bool) -> void:
	if not boss.visible: return
	var kind: int = state.definition.boss.kind
	match kind:
		0:
			for w in boss_wheels: w.rotation.x += (dt * .55 / .4) if playing else 0.0
		1:
			boss_visual.position.y = .55 + sin(clock * 1.7) * .12
			boss_visual.pose_boss(dt, 0.0, "matron", clock, boss_attack)
		2:
			boss_visual.pose_boss(dt, -ground_speed if playing else 0.0, "ram", clock, boss_attack)
		3:
			boss_visual.position.y = .6 + sin(clock * 1.4) * .18
			boss_visual.rotation.y = PI + sin(clock * .6) * .25
		4:
			boss_visual.position.y = sin(clock * 1.1) * .08
			boss_visual.rotation.z = sin(clock * .7) * .03
			for i in boss_arms.size():
				var arm: Dictionary = boss_arms[i]
				arm.model.rotation.x = sin(clock * 1.6 + i * 1.9) * .18 - boss_attack * .45
				arm.model.rotation.z = (1.0 if i == 0 else -1.0) * (.12 + sin(clock * 1.2 + i) * .08)
