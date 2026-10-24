extends Node3D
## Read-only snapshots and transient observations. Never owns rule state or RNG.
const Rules = preload("res://scripts/engine.gd")
const Art = preload("res://scripts/art.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Pool = preload("res://scripts/presentation/pool.gd")
const Kit = preload("res://scripts/presentation/kit.gd")
const Island = preload("res://scripts/presentation/island.gd")
var kit := Kit.new()
var pool: RefCounted
var island := Island.new()
var player: Node3D
var actors := {}
var dying := {}
var drops := {}
var projectiles := {}
var effects: Array[Node3D] = []
var weapons: Array[Node3D] = []
var links: Array[Node3D] = []
var weapon_eyes: Array[Node3D] = []
var weapon_tips: Array[Node3D] = []
var reach: MeshInstance3D
var snapshot := {}
var epoch := 0
var serial := 0
var events: Array[Dictionary] = []
var event_counts := {}
var frozen := false
var reduced := false
var visual_strike := 0.0
var render_age := 0.0
var last_tier := -1
var sync_count := 0

func build(state: Dictionary) -> void:
	pool = Pool.new(self)
	island.build(self, kit, state)
	player = Actor.new()
	add_child(player)
	player.configure("diver", kit)
	for tier in 4:
		var weapon := kit.asset("weapon_" + str(tier))
		add_child(weapon)
		weapon.hide()
		weapons.append(weapon)
		weapon_eyes.append(weapon.find_child("ChainEye", true, false))
		weapon_tips.append(weapon.find_child("ContactTip", true, false))
	for i in 22:
		var link := kit.asset("chain_link")
		add_child(link)
		link.hide()
		links.append(link)
	reach = Art.ring(float(Rules.weapon(state).reach), Color("728f87"))
	Art.decal(reach, Color(1, .98, .9, .42))
	add_child(reach)
	hydrate(state)

func _actor(key: String, role: String) -> Node3D:
	var node: Node3D = pool.take(key)
	if node == null:
		node = Actor.new()
		add_child(node)
		node.configure(role, kit)
	node.reset_for_reuse()
	node.set_meta("pool_key", key)
	return node

func _object(key: String, asset: String) -> Node3D:
	var node: Node3D = pool.take(key)
	if node == null:
		node = kit.asset(asset) if not asset.is_empty() else Art.sphere(.18, Color("eda67d"))
		add_child(node)
	node.transform = Transform3D.IDENTITY
	node.set_meta("pool_key", key)
	return node

func _release(node: Node3D) -> void:
	pool.put(str(node.get_meta("pool_key")), node)

func hydrate(state: Dictionary) -> void:
	epoch += 1
	serial = 0
	events.clear()
	event_counts.clear()
	for group in [actors, dying, drops, projectiles]:
		for node in group.values():
			_release(node)
		group.clear()
	for node in effects:
		_release(node)
	effects.clear()
	player.reset_for_reuse()
	island.reset_transients()
	snapshot = {}
	visual_strike = 0
	render_age = 0
	for node in links:
		node.transform = Transform3D.IDENTITY
		node.hide()
	for node in weapons:
		node.transform = Transform3D.IDENTITY
		node.hide()
	last_tier = -1
	capture(state, true)
	present(0)

func observe(kind: String, payload: Dictionary) -> void:
	serial += 1
	var event := {"epoch": epoch, "serial": serial, "kind": kind, "data": payload.duplicate(true)}
	events.append(event)
	if events.size() > 128:
		events.pop_front()
	event_counts[kind] = int(event_counts.get(kind, 0)) + 1
	if not reduced and kind in ["contact", "blocked", "purchase", "hurt"]:
		var effect: Node3D = pool.take("effect:" + kind)
		if effect == null:
			effect = Art.impact(.45 if kind == "contact" else .7, Color("ffd36b") if kind == "contact" else Color("b7d2e8") if kind == "blocked" else (Color("7fe3c8") if kind == "purchase" else Color("ff6a4f")))
			add_child(effect)
		effect.set_meta("pool_key", "effect:" + kind)
		effect.set_meta("life", .20)
		effect.position = Vector3(payload.get("x", snapshot.get("x", 0)), .08, payload.get("z", snapshot.get("z", 0)))
		effect.scale = Vector3.ONE
		effects.append(effect)

func _resolve_feedback(before: Dictionary, current: Dictionary) -> void:
	# contact is the rule's resolution deadline, including misses. Only real
	# hull loss/death (or a hit flash followed by healing) earns a hit burst.
	var previous := {}
	for enemy in before.enemies: previous[int(enemy.id)] = enemy
	var hits: Array = []
	for enemy in current.enemies:
		var old: Dictionary = previous.get(int(enemy.id), {})
		if not old.is_empty() and (enemy.hp < old.hp or enemy.flash > old.flash): hits.append(enemy)
	for id in current.dead:
		if not id in before.dead and previous.has(int(id)): hits.append(previous[int(id)])
	var blocked: bool = float(current.get("blocked", 0)) > float(before.get("blocked", 0))
	if not hits.is_empty():
		observe("contact", {"target": hits[0].id, "x": hits[0].x, "z": hits[0].z, "hit_ids": hits.map(func(enemy): return int(enemy.id))})
	if blocked:
		observe("blocked", {"target": current.strike_id, "x": current.strike_x, "z": current.strike_z})
	elif hits.is_empty():
		observe("miss", {"target": current.strike_id})

func capture(state: Dictionary, reset: bool = false) -> void:
	var dt := float(state.time) - float(snapshot.get("time", state.time))
	if not reset and dt == 0 and not snapshot.is_empty() and state.phase == snapshot.phase and state.tier == snapshot.tier and state.hp == snapshot.hp:
		return
	var old := snapshot
	snapshot = state.duplicate(true)
	visual_strike = float(state.strike)
	render_age = 0
	sync_count += 1
	if not reset and not old.is_empty():
		if not old.contact and state.contact:
			_resolve_feedback(old, state)
		if state.strike > old.strike:
			observe("swing", {"target": state.strike_id})
		if state.tier != old.tier:
			observe("purchase", {"tier": state.tier, "x": state.x, "z": state.z})
		if state.hp < old.hp:
			observe("hurt", {"x": state.x, "z": state.z})
		if state.phase != old.phase:
			observe(state.phase, {})
	var pd := {"x": state.x, "z": state.z, "hp": state.hp}
	player.capture(pd, {"hp": 100}, reset, dt)
	var live := {}
	for data in Rules.active(state):
		var id := int(data.id)
		var definition: Dictionary = Rules.roster(state)[id]
		var key := "enemy:" + str(definition.role) + ":original"
		live[id] = true
		if not actors.has(id):
			actors[id] = _actor(key, str(definition.role))
			actors[id].identity = str(epoch) + ":" + str(id)
			actors[id].capture(data, definition, true, 0)
		var actor: Node3D = actors[id]
		var posed: Dictionary = data.duplicate(true)
		posed.facing = float(data.facing) + PI if state.schema == 2 else atan2(state.x - data.x, state.z - data.z) + PI
		actor.capture(posed, definition, reset, dt)
		_telegraph(actor, data, definition, state.schema == 1)
	for id in actors.keys():
		if not live.has(id):
			var actor: Node3D = actors[id]
			actors.erase(id)
			if not reset and id in state.dead:
				actor.fall()
				dying[id] = actor
				observe("fall", {"id": id})
			else:
				_release(actor)
	var drop_ids := {}
	for data in state.drops:
		var id := int(data.id)
		drop_ids[id] = true
		if not drops.has(id):
			drops[id] = _object("drop:salvage", "salvage")
		drops[id].position = Vector3(data.x, .035, data.z)
	for id in drops.keys():
		if not drop_ids.has(id):
			_release(drops[id])
			drops.erase(id)
	var shot_ids := {}
	for shot in state.get("projectiles", []):
		var id := int(shot.id)
		shot_ids[id] = true
		if not projectiles.has(id):
			projectiles[id] = _object("projectile:pearl", "")
		projectiles[id].position = Vector3(shot.x, .65, shot.z)
	for id in projectiles.keys():
		if not shot_ids.has(id):
			_release(projectiles[id])
			projectiles.erase(id)
	if last_tier != int(state.tier):
		last_tier = int(state.tier)
		for tier in weapons.size():
			weapons[tier].visible = tier == last_tier
		var shape := TorusMesh.new()
		shape.inner_radius = float(Rules.weapon(state).reach) - .018
		shape.outer_radius = float(Rules.weapon(state).reach) + .018
		shape.rings = 64
		shape.ring_segments = 6
		reach.mesh = shape
	reach.position = Vector3(state.x, .025, state.z)
	island.update(state, 0, reduced)

func _telegraph(actor: Node3D, data: Dictionary, definition: Dictionary, legacy: bool) -> void:
	var warning: Node3D = actor.warning
	warning.visible = data.mode == "wind"
	warning.global_position = Vector3(data.ax, .04, data.az)
	warning.global_rotation.y = atan2(float(data.get("tx", 0)), float(data.get("tz", 1)))
	var attack := "slam" if legacy else str(data.attack)
	_warning_ink(warning, attack, float(data.clock))
	for key in ["Solid", "Outer", "Inner", "Line", "Left", "Right"]:
		warning.get_node(key).hide()
	if attack == "slam":
		var solid := warning.get_node("Solid") as Node3D
		solid.show()
		var radius := float(definition.range) + .35 if legacy or not definition.get("boss", false) else 3.55
		solid.scale = Vector3(radius / 3.2, 1, radius / 3.2)
	elif attack == "ring":
		warning.get_node("Outer").show()
		warning.get_node("Inner").show()
	else:
		var length := 8.5 if definition.get("boss", false) else 5.3
		if attack == "charge":
			var envelope := _charge_envelope(snapshot, data)
			length = envelope.length
			if not envelope.straight:
				# Rocks and field clamping can redirect the committed charge.
				# Paint its conservative reachable box, rather than a safe-looking
				# strip beside a damaging deflected path.
				var bounds: Rect2 = envelope.bounds
				var line := warning.get_node("Line") as MeshInstance3D
				line.show()
				warning.global_rotation.y = 0
				line.position = Vector3(bounds.get_center().x - data.ax, .01, bounds.get_center().y - data.az)
				line.scale = Vector3(bounds.size.x / line.mesh.size.x, 1, bounds.size.y / line.mesh.size.z)
				_warning_rims(warning)
				return
		for key in ["Line", "Left", "Right"]:
			var line := warning.get_node(key) as Node3D
			line.visible = key == "Line" or attack == "burst" or definition.get("boss", false) and attack == "shot"
			# Rules test the diver centre against these widths; do not add the
			# body radius a second time or paint a falsely safe outside strip.
			var half_width := .8 if attack == "line" else .9 if attack == "charge" else .5
			line.scale.x = 2.0 * half_width / (line as MeshInstance3D).mesh.size.x
			# Segment collision includes round end caps. A conservative rectangle
			# covers them too, rather than ending before the damaging footprint.
			line.scale.z = (length + 2.0 * half_width) / 8.5
			var angle := -.32 if key == "Left" else (.32 if key == "Right" else 0.0)
			line.position = Vector3(sin(angle) * length * .5, .01, cos(angle) * length * .5)
	_warning_rims(warning)

## Keep border width constant in world space when a constrained charge widens
## its conservative box; inherited strip scale must not make a broad opaque rim.
func _warning_rims(warning: Node3D) -> void:
	for key in ["Line", "Left", "Right"]:
		var strip := warning.get_node(key) as MeshInstance3D
		if not strip.visible: continue
		for rim in strip.get_node("Boundary").get_children():
			var axis: int = rim.get_meta("rim_axis")
			var side: float = rim.get_meta("rim_side")
			var size: Vector3 = strip.mesh.size
			var width := minf(.075 / maxf(absf(strip.scale[axis]), .001), size[axis] * .5)
			size.y = .008
			size[axis] = width
			if rim.mesh.size != size: rim.mesh.size = size
			var point := Vector3(0, .026, 0)
			point[axis] = side * (strip.mesh.size[axis] - width) * .5
			rim.position = point

## Styling describes release urgency, never a successful impact. Projectiles
## can travel after this windup ends; no hit cue or safe-route advice is added.
func _warning_ink(warning: Node3D, attack: String, seconds: float) -> void:
	var urgency := 1.0 - clampf(seconds / .65, 0.0, 1.0)
	var base := Color("db9a58") if attack == "charge" else Color("d97576")
	var ink := base.lerp(Color("ffe2bc"), urgency * .55)
	var fill := Color(ink, .11 + .06 * urgency)
	var edge := Color(ink, .72 + .24 * urgency)
	# Assign absolute values on every capture so reused actors cannot retain
	# an imminent cue when their next, longer windup begins.
	var solid := warning.get_node("Solid")
	(solid.get_child(0).material_override as StandardMaterial3D).albedo_color = edge
	(solid.get_child(1).material_override as StandardMaterial3D).albedo_color = fill
	for key in ["Outer", "Inner"]:
		(warning.get_node(key).material_override as StandardMaterial3D).albedo_color = edge
	for key in ["Line", "Left", "Right"]:
		var strip := warning.get_node(key) as MeshInstance3D
		(strip.material_override as StandardMaterial3D).albedo_color = fill
		for rim in strip.get_node("Boundary").get_children():
			(rim.material_override as StandardMaterial3D).albedo_color = edge

# Pinned campaign charge: speed8, clock.85, step cap.05, enemy radius.6,
# hit radius.9. The final full step may overshoot the nominal6.8m route.
# An obstacle projection resets the centre anywhere on its expanded disk.
# Close over every intersected disk plus its maximum subsequent travel; this
# also covers repeated same-rock projections and several rocks in one tick.
func _charge_envelope(state: Dictionary, data: Dictionary) -> Dictionary:
	var start := Vector2(data.x, data.z)
	var travel := Vector2(data.tx, data.tz) * (8.0 * (.85 + .05))
	var field := Rect2(Vector2(-6.0, -12.0), Vector2(12.0, 15.9))
	var bounds := _charge_sweep(Rect2(start, Vector2.ZERO), travel)
	var straight := start.is_equal_approx(Vector2(data.ax, data.az)) and field.has_point(start) and field.has_point(start + travel)
	var rocks: Array = state.get("definition", {}).get("obstacles", [])
	# Projection away from a rock preserves the incoming coordinate side.
	# Revisit all disks as bounds expand: another rock can relax that side.
	for pass_index in rocks.size() * 4 + 4:
		var previous := bounds
		for rock in rocks:
			var disk := _charge_disk(rock)
			if not bounds.grow(.00001).intersects(disk, true): continue
			straight = false
			var low := disk.position
			var high := disk.end
			var center := Vector2(rock.x, rock.z)
			if bounds.end.x < center.x: high.x = clampf(bounds.end.x, low.x, high.x)
			elif bounds.position.x > center.x: low.x = clampf(bounds.position.x, low.x, high.x)
			if bounds.end.y < center.y: high.y = clampf(bounds.end.y, low.y, high.y)
			elif bounds.position.y > center.y: low.y = clampf(bounds.position.y, low.y, high.y)
			bounds = bounds.merge(_charge_sweep(Rect2(low, high - low), travel))
		if bounds == previous:
			return {"straight": straight, "bounds": bounds.grow(.9), "length": travel.length()}
	# Never use a partially converged refinement. Whole-disk closure remains a
	# conservative fallback if the bounded exact fixed-point search exhausts.
	var included := {}
	for pass_index in rocks.size() + 1:
		var changed := false
		for i in rocks.size():
			if included.has(i): continue
			var disk := _charge_disk(rocks[i])
			if not bounds.grow(.00001).intersects(disk, true): continue
			included[i] = true
			bounds = bounds.merge(_charge_sweep(disk, travel))
			changed = true
		if not changed: break
	return {"straight": false, "bounds": bounds.grow(.9), "length": travel.length()}

func _charge_disk(rock: Dictionary) -> Rect2:
	var radius := float(rock.radius) + .6
	return Rect2(Vector2(rock.x, rock.z) - Vector2.ONE * radius, Vector2.ONE * radius * 2)

func _charge_sweep(origins: Rect2, travel: Vector2) -> Rect2:
	# constrain clamps BEFORE obstacle projection. Keep the original disk
	# untrimmed: its post-projection points can lie beyond field bounds.
	var a := origins.position + travel
	var b := origins.end + travel
	a = Vector2(clampf(a.x, -6, 6), clampf(a.y, -12, 3.9))
	b = Vector2(clampf(b.x, -6, 6), clampf(b.y, -12, 3.9))
	return origins.merge(Rect2(a, b - a))

func set_paused(value: bool, state: Dictionary) -> void:
	if frozen != value:
		frozen = value
		hydrate(state)

func present(delta: float) -> void:
	if snapshot.is_empty():
		return
	var dt := 0.0 if frozen else delta
	visual_strike = maxf(0, float(snapshot.strike) - render_age)
	render_age += dt
	var aim := Vector3(snapshot.strike_x, 0, snapshot.strike_z)
	player.pose(dt, str(snapshot.phase), visual_strike, aim)
	for actor in actors.values():
		actor.pose(dt, str(snapshot.phase))
		actor.health_root.global_position = actor.position + Vector3(0, 2.03 * actor.scale_factor, 0)
		actor.health_root.global_rotation = island.camera.global_rotation
	for id in dying.keys():
		var actor: Node3D = dying[id]
		actor.pose(dt, str(snapshot.phase))
		if actor.fall_time >= .64:
			_release(actor)
			dying.erase(id)
	for node in effects.duplicate():
		var life := float(node.get_meta("life")) - dt
		node.set_meta("life", life)
		node.scale = Vector3.ONE * (1 + (.20 - life) * 3)
		if life <= 0 or reduced:
			_release(node)
			effects.erase(node)
	var hand: Vector3 = player.sync_socket()
	var end := hand + Vector3(.25, -.20, .20).rotated(Vector3.UP, player.rotation.y)
	if visual_strike > 0:
		var t := clampf((.36 - visual_strike) / .36, 0, 1)
		var extend := sin(t * PI)
		var destination := Vector3(snapshot.strike_x, .80, snapshot.strike_z)
		end = hand.lerp(destination, extend)
		# Sweep reaches the actual contact point at t=.5; no animation damage.
		var lateral := (destination - hand).cross(Vector3.UP).normalized()
		end += lateral * sin(t * TAU) * .32
	for i in weapons.size():
		weapons[i].visible = i == last_tier
		if i == last_tier:
			weapons[i].rotation.y = atan2(-(end.x - hand.x), -(end.z - hand.z))
			weapons[i].position = end - weapons[i].basis * weapon_tips[i].position
	var eye: Vector3 = weapon_eyes[last_tier].global_position
	for i in links.size():
		var alpha := float(i) / (links.size() - 1)
		links[i].visible = true
		links[i].position = hand.lerp(eye, alpha)
		links[i].position.y -= sin(alpha * PI) * (.055 if visual_strike > 0 else .12)
		links[i].rotation = Vector3(PI / 2, float(i % 2) * PI / 2, 0)
	island.update(snapshot, dt, reduced)

func _exit_tree() -> void:
	actors.clear()
	dying.clear()
	drops.clear()
	projectiles.clear()
	effects.clear()
	events.clear()
	if pool != null:
		pool.clear()
	kit.clear()
