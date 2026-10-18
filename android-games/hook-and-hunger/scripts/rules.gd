extends RefCounted
## All combat and economy run here, without rendering or wall-clock randomness.

const WEAPONS := [
	{"name": "RUST ANCHOR", "power": 100, "damage": 12.0, "reach": 2.5, "period": 0.8, "cleave": 0.1, "color": "f4b579"},
	{"name": "TIDECUTTER", "power": 200, "damage": 32.0, "reach": 3.6, "period": 0.67, "cleave": 1.1, "color": "7ef3cd"}
]
const COST := 36
const PAD := Vector2(0, 6.8)
const OBSTACLES := [Vector3(-3.8, 0, 0.95), Vector3(3.8, -2, 0.95), Vector3(-3.5, -12, 1.15), Vector3(3.5, -16, 1.15)]
const ROSTER := [
	{"id": 0, "role": "skitter", "x": -2.8, "z": 2.0, "hp": 24.0, "speed": 1.65, "range": 1.05, "damage": 12.0, "wind": 0.65, "recovery": 1.3, "reward": 7, "pen": 0},
	{"id": 1, "role": "skitter", "x": 2.8, "z": 1.4, "hp": 24.0, "speed": 1.65, "range": 1.05, "damage": 12.0, "wind": 0.65, "recovery": 1.3, "reward": 7, "pen": 0},
	{"id": 2, "role": "skitter", "x": -2.5, "z": -2.9, "hp": 24.0, "speed": 1.8, "range": 1.05, "damage": 12.0, "wind": 0.65, "recovery": 1.3, "reward": 7, "pen": 0},
	{"id": 3, "role": "skitter", "x": 2.5, "z": -3.0, "hp": 24.0, "speed": 1.8, "range": 1.05, "damage": 12.0, "wind": 0.65, "recovery": 1.3, "reward": 7, "pen": 0},
	{"id": 4, "role": "lancer", "x": 0.0, "z": -3.8, "hp": 48.0, "speed": 1.1, "range": 2.5, "damage": 22.0, "wind": 1.0, "recovery": 1.9, "reward": 14, "pen": 0},
	{"id": 5, "role": "lancer", "x": -2.5, "z": -10.5, "hp": 64.0, "speed": 1.3, "range": 2.5, "damage": 22.0, "wind": 0.85, "recovery": 1.9, "reward": 14, "pen": 1},
	{"id": 6, "role": "skitter", "x": 2.3, "z": -11.0, "hp": 48.0, "speed": 2.1, "range": 1.05, "damage": 15.0, "wind": 0.6, "recovery": 1.25, "reward": 7, "pen": 1},
	{"id": 7, "role": "bellkeeper", "x": 0.0, "z": -17.0, "hp": 480.0, "speed": 1.2, "range": 3.2, "damage": 42.0, "wind": 1.2, "recovery": 2.2, "reward": 36, "pen": 1}
]

static func fresh() -> Dictionary:
	var enemies: Array = []
	for spec in ROSTER:
		enemies.append({"id": spec.id, "x": spec.x, "z": spec.z, "hp": spec.hp, "mode": "idle", "clock": 0.0, "ax": spec.x, "az": spec.z, "flash": 0.0})
	return {"schema": 1, "x": 0.0, "z": 6.8, "hp": 100.0, "tier": 0, "wallet": 0, "collected": [], "dead": [], "drops": [], "enemies": enemies, "phase": "playing", "time": 0.0, "deaths": 0, "hits": 0, "cooldown": 0.0, "strike": 0.0, "strike_id": -1, "strike_x": 0.0, "strike_z": 0.0, "contact": false, "notice": "Drag to move. Your anchor strikes nearby creatures.", "notice_left": 6.0}

static func position(s: Dictionary) -> Vector2:
	return Vector2(s.x, s.z)

static func weapon(s: Dictionary) -> Dictionary:
	return WEAPONS[int(s.tier)]

static func notify(s: Dictionary, message: String) -> void:
	s.notice = message
	s.notice_left = 4.0

static func constrain(p: Vector2, radius: float, low_z: float, high_z: float) -> Vector2:
	p.x = clampf(p.x, -6.0 + radius, 6.0 - radius)
	p.y = clampf(p.y, low_z + radius, high_z - radius)
	for obstacle in OBSTACLES:
		var center := Vector2(obstacle.x, obstacle.y)
		var minimum: float = obstacle.z + radius
		if p.distance_to(center) < minimum:
			p = center + (p - center).normalized() * minimum if p != center else center + Vector2(minimum, 0)
	return p

static func line_clear(a: Vector2, b: Vector2) -> bool:
	for obstacle in OBSTACLES:
		var center := Vector2(obstacle.x, obstacle.y)
		if Geometry2D.get_closest_point_to_segment(center, a, b).distance_to(center) < obstacle.z + 0.12:
			return false
	return true

static func purchase(s: Dictionary) -> bool:
	if s.phase != "playing" or s.tier != 0 or position(s).distance_to(PAD) > 1.8 or int(s.wallet) < COST:
		return false
	s.wallet -= COST
	s.tier = 1
	s.hp = 100.0
	s.cooldown = 0.0
	notify(s, "TIDECUTTER • power 200 • hull restored • gate open")
	return true

static func retry(s: Dictionary) -> bool:
	if s.phase != "defeat":
		return false
	s.phase = "playing"
	s.hp = 100.0
	s.x = PAD.x
	s.z = PAD.y
	s.deaths += 1
	s.cooldown = 0.0
	s.strike = 0.0
	s.strike_id = -1
	# Defeated IDs and their single drops survive; only surviving foes reset.
	for e in s.enemies:
		var spec: Dictionary = ROSTER[int(e.id)]
		e.x = spec.x
		e.z = spec.z
		e.hp = spec.hp
		e.mode = "idle"
		e.clock = 0.0
	notify(s, "Recovered at dock. Salvage, weapon and defeated foes retained.")
	return true

static func target(s: Dictionary) -> int:
	var best := -1
	var distance: float = weapon(s).reach
	var p := position(s)
	for e in s.enemies:
		if int(ROSTER[int(e.id)].pen) != (0 if s.z > -6.5 else 1):
			continue
		var q := Vector2(e.x, e.z)
		var d := p.distance_to(q)
		if d <= distance and line_clear(p, q):
			best = int(e.id)
			distance = d
	return best

static func _kill(s: Dictionary, e: Dictionary) -> void:
	var id := int(e.id)
	if id in s.dead:
		return
	s.dead.append(id)
	s.drops.append({"id": id, "x": e.x, "z": e.z})
	if id == 7:
		# Boss clear sweeps existing earned drops into the wallet exactly once.
		for drop in s.drops:
			if not int(drop.id) in s.collected:
				s.collected.append(int(drop.id))
				s.wallet += int(ROSTER[int(drop.id)].reward)
		s.drops.clear()
		s.phase = "victory"
		notify(s, "The Bellkeeper falls. The first beacon is lit.")

static func step(s: Dictionary, movement: Vector2, delta: float) -> void:
	if s.phase != "playing" or not is_finite(delta) or delta <= 0:
		return
	var dt := minf(delta, 0.05)
	s.time += dt
	s.notice_left = maxf(0, s.notice_left - dt)
	s.cooldown = maxf(0, s.cooldown - dt)
	var p := constrain(position(s) + movement.limit_length() * dt * 4.0, 0.4, -20.0 if s.tier > 0 else -6.4, 8.8)
	# The pen divider is solid except for its clearly marked central opening.
	if (s.z + 6.5) * (p.y + 6.5) < 0 and absf(p.x) > 1.6:
		p.y = -6.0 if s.z > -6.5 else -7.0
	s.x = p.x
	s.z = p.y
	for drop in s.drops.duplicate():
		if p.distance_to(Vector2(drop.x, drop.z)) < 1.35:
			s.wallet += int(ROSTER[int(drop.id)].reward)
			s.collected.append(int(drop.id))
			s.drops.erase(drop)
	if s.strike > 0:
		var before: float = s.strike
		s.strike = maxf(0, s.strike - dt)
		if before > 0.18 and s.strike <= 0.18 and not s.contact:
			s.contact = true
			var impact := Vector2(s.strike_x, s.strike_z)
			for e in s.enemies:
				var q := Vector2(e.x, e.z)
				if (int(e.id) == int(s.strike_id) or q.distance_to(impact) <= float(weapon(s).cleave)) and p.distance_to(q) <= float(weapon(s).reach) + 0.25 and q.distance_to(impact) < 1.3 and line_clear(p, q):
					e.hp = maxf(0, e.hp - float(weapon(s).damage))
					e.flash = 0.16
					if e.hp <= 0:
						_kill(s, e)
			s.enemies = s.enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if s.phase != "playing":
		return
	if s.cooldown <= 0 and s.strike <= 0:
		var chosen := target(s)
		if chosen >= 0:
			for e in s.enemies:
				if int(e.id) == chosen:
					s.strike_id = chosen
					s.strike_x = e.x
					s.strike_z = e.z
					s.strike = 0.36
					s.contact = false
					s.cooldown = float(weapon(s).period)
	for e in s.enemies:
		var spec: Dictionary = ROSTER[int(e.id)]
		e.flash = maxf(0, e.flash - dt)
		if int(spec.pen) != (0 if p.y > -6.5 else 1) or p.y > 5.0:
			continue
		var q := Vector2(e.x, e.z)
		var dist := p.distance_to(q)
		if e.mode == "wind":
			e.clock -= dt
			if e.clock <= 0:
				if p.distance_to(Vector2(e.ax, e.az)) <= float(spec.range) + 0.35 and line_clear(Vector2(e.ax, e.az), p):
					s.hp = maxf(0, s.hp - float(spec.damage))
					s.hits += 1
				e.mode = "recover"
				e.clock = spec.recovery
		elif e.mode == "recover":
			e.clock = maxf(0, e.clock - dt)
			if e.clock <= 0:
				e.mode = "idle"
		elif dist <= float(spec.range):
			e.mode = "wind"
			e.clock = spec.wind
			e.ax = e.x
			e.az = e.z
		elif dist < (9.0 if int(spec.pen) == 0 else 13.0):
			q = constrain(q.move_toward(p, float(spec.speed) * dt), 0.45, -6.1 if int(spec.pen) == 0 else -19.5, 4.5 if int(spec.pen) == 0 else -7.0)
			e.x = q.x
			e.z = q.y
	if s.hp <= 0:
		s.phase = "defeat"
		notify(s, "Hull breached. Your earned salvage and weapon are safe.")

static func numeric(v: Variant, lo: float, hi: float, whole: bool = false) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and v >= lo and v <= hi and (not whole or float(v) == int(v))

static func valid(v: Variant) -> bool:
	if not v is Dictionary:
		return false
	for key in fresh():
		if not v.has(key):
			return false
	if v.schema != 1 or not numeric(v.tier, 0, 1, true) or not numeric(v.wallet, 0, 1000, true) or not numeric(v.x, -5.601, 5.601) or not numeric(v.z, -19.601 if v.tier == 1 else -6.001, 8.401) or not numeric(v.hp, 0, 100):
		return false
	for key in ["time", "notice_left", "cooldown", "strike"]:
		if not numeric(v[key], 0, 1000000):
			return false
	if v.cooldown > 0.801 or v.strike > 0.361 or v.notice_left > 6.001:
		return false
	for key in ["deaths", "hits"]:
		if not numeric(v[key], 0, 1000000, true):
			return false
	if not v.phase in ["playing", "defeat", "victory"] or not v.contact is bool or not v.notice is String or v.notice.length() > 200 or not numeric(v.strike_id, -1, 7, true) or not numeric(v.strike_x, -10, 10) or not numeric(v.strike_z, -22, 10):
		return false
	for group in [v.dead, v.collected]:
		if not group is Array or group.size() > ROSTER.size():
			return false
		var seen := []
		for id in group:
			if not numeric(id, 0, 7, true) or int(id) in seen:
				return false
			seen.append(int(id))
	var dead_ids: Array = v.dead.map(func(id: Variant) -> int: return int(id))
	var collected_ids: Array = v.collected.map(func(id: Variant) -> int: return int(id))
	if (v.hp == 0) != (v.phase == "defeat") or (7 in dead_ids) != (v.phase == "victory"):
		return false
	if not v.enemies is Array or not v.drops is Array or v.enemies.size() > 8 or v.drops.size() > 8:
		return false
	var ids := []
	for e in v.enemies:
		if not e is Dictionary or not numeric(e.get("id"), 0, 7, true):
			return false
		var id := int(e.id)
		if id in ids or id in dead_ids or not numeric(e.get("hp"), 0.001, float(ROSTER[id].hp)) or not e.get("mode") in ["idle", "wind", "recover"] or not numeric(e.get("clock"), 0, 3) or not numeric(e.get("flash"), 0, 0.2):
			return false
		for key in ["x", "ax"]:
			if not numeric(e.get(key), -6, 6):
				return false
		for key in ["z", "az"]:
			if not numeric(e.get(key), -20, 5):
				return false
		if not numeric(e.z, -5.652 if int(ROSTER[id].pen) == 0 else -19.052, 4.052 if int(ROSTER[id].pen) == 0 else -7.448):
			return false
		ids.append(id)
	if ids.size() + v.dead.size() != 8:
		return false
	var accounted: Array = collected_ids.duplicate()
	for id in collected_ids:
		if not id in dead_ids:
			return false
	for d in v.drops:
		if not d is Dictionary or not numeric(d.get("id"), 0, 7, true) or int(d.id) in accounted or not int(d.id) in dead_ids or not numeric(d.get("x"), -6, 6) or not numeric(d.get("z"), -20, 5):
			return false
		if not numeric(d.z, -5.652 if int(ROSTER[int(d.id)].pen) == 0 else -19.052, 4.052 if int(ROSTER[int(d.id)].pen) == 0 else -7.448):
			return false
		accounted.append(int(d.id))
	if accounted.size() != v.dead.size():
		return false
	var earned := 0
	for id in v.collected:
		earned += int(ROSTER[int(id)].reward)
	return int(v.wallet) + (COST if int(v.tier) == 1 else 0) == earned

static func restore(v: Variant) -> Dictionary:
	if not valid(v):
		return {}
	var s: Dictionary = v.duplicate(true)
	for key in ["schema", "tier", "wallet", "deaths", "hits", "strike_id"]:
		s[key] = int(s[key])
	for group in [s.dead, s.collected]:
		for i in group.size():
			group[i] = int(group[i])
	for group in [s.enemies, s.drops]:
		for e in group:
			e.id = int(e.id)
	return s
