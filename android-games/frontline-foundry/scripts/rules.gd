extends RefCounted
# Catalog 1 is immutable: save states pin this finite, original siege definition.
const CATALOG := 1
const TOTAL := 10
const CAP := 4
const PADS := [Vector2(-2.5, 3.2), Vector2(2.5, 3.2)]
const COSTS := [8, 14]
const SPAWNS := [1.0, 5.0, 10.0, 14.0, 19.0, 23.0, 28.0, 33.0, 38.0, 43.0]

static func profile() -> Dictionary:
	return {"attempts": 0, "wins": 0, "best_kills": 0}

static func fresh() -> Dictionary:
	var recruits: Array = []
	for id in 4:
		recruits.append({"id": id, "role": "rifle" if id < 3 else "vehicle", "phase": "waiting", "x": -2.5 if id < 3 else 2.5, "z": 4.4 + (id % 3) * 0.5, "hp": 42 if id < 3 else 140, "clock": 0.0, "cooldown": 0.0, "shots": 0, "damage": 0.0})
	return {"catalog": CATALOG, "seed": 17, "phase": "ready", "time": 0.0, "x": 0.0, "z": 2.5, "hp": 100.0, "hq": 120.0, "wallet": 8, "spent": 0, "pads": [false, false], "stock": [0, 0], "consumed": [0, 0], "recruits": recruits, "spawned": 0, "enemies": [], "killed": [], "leaked": [], "coins": [{"id": 100, "x": 0.0, "z": 0.4, "value": 6}], "collected": [], "commander_cd": 0.0, "sentry_cd": 0.0, "commander_shots": 0, "sentry_shots": 0, "cause": "", "recorded": false}

static func position(s: Dictionary) -> Vector2:
	return Vector2(s.x, s.z)

static func nearby_pad(s: Dictionary) -> int:
	for i in 2:
		if position(s).distance_to(PADS[i]) <= 1.45:
			return i
	return -1

static func buy(s: Dictionary, pad: int) -> bool:
	if s.phase != "playing" or pad < 0 or pad > 1 or nearby_pad(s) != pad or s.pads[pad] or s.wallet < COSTS[pad] or (pad == 1 and not s.pads[0]):
		return false
	s.wallet -= COSTS[pad]
	s.spent += COSTS[pad]
	s.pads[pad] = true
	s.stock[pad] = 3 if pad == 0 else 1
	return true

static func target(enemies: Array, p: Vector2, reach: float) -> int:
	var chosen := -1
	var closest := reach
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		var d := p.distance_to(Vector2(e.x, e.z))
		if e.hp > 0 and d <= closest:
			closest = d
			chosen = i
	return chosen

static func hit(s: Dictionary, idx: int, p: Vector2, damage: float, owner: String, events: Array) -> float:
	var e: Dictionary = s.enemies[idx]
	var effective := damage * (0.38 if e.armored and owner != "vehicle" else 1.0)
	var actual := minf(e.hp, effective)
	e.hp -= actual
	events.append({"kind": "shot", "owner": owner, "from": [p.x, p.y], "to": [e.x, e.z], "enemy": e.id, "damage": actual})
	return actual

static func tick(s: Dictionary, movement: Vector2, delta: float) -> Array:
	var events: Array = []
	if s.phase != "playing":
		return events
	var dt := clampf(delta, 0, 0.05)
	s.time += dt
	var p := position(s) + movement.limit_length() * 3.4 * dt
	s.x = clampf(p.x, -4.5, 4.5)
	s.z = clampf(p.y, -5.7, 5.8)
	p = position(s)
	while s.spawned < TOTAL and s.time >= SPAWNS[s.spawned]:
		var id: int = s.spawned
		var armor := id >= 6
		s.enemies.append({"id": id, "x": [-1.7, 1.7, 0.0][id % 3], "z": -6.2, "hp": 150.0 if armor else 48.0, "armored": armor, "cooldown": 0.5})
		s.spawned += 1
	# Each station owns its queue and consumes exactly one physical equipment token.
	var active := 0
	for r in s.recruits:
		if r.phase in ["equipping", "deploying", "fighting"]:
			active += 1
	for r in s.recruits:
		var station := 0 if r.role == "rifle" else 1
		if r.phase == "waiting" and s.stock[station] > 0 and active < CAP:
			var busy := false
			for other in s.recruits:
				if other.id != r.id and other.role == r.role and other.phase == "equipping":
					busy = true
			if not busy:
				s.stock[station] -= 1
				s.consumed[station] += 1
				r.phase = "equipping"
				r.clock = 0.8
				active += 1
				events.append({"kind": "equip", "id": r.id, "role": r.role})
		elif r.phase == "equipping":
			r.clock = maxf(0, r.clock - dt)
			if r.clock <= 0:
				r.phase = "deploying"
		elif r.phase == "deploying":
			var destination := Vector2([-2.1, 0.0, 2.1, 0.0][r.id], -1.2 if station == 0 else -0.3)
			var q := Vector2(r.x, r.z).move_toward(destination, dt * (2.0 if station == 0 else 1.6))
			r.x = q.x
			r.z = q.y
			if q.distance_to(destination) < 0.01:
				r.phase = "fighting"
		elif r.phase == "fighting":
			r.cooldown = maxf(0, r.cooldown - dt)
			var idx := target(s.enemies, Vector2(r.x, r.z), 5.7 if station == 1 else 4.7)
			if idx >= 0 and r.cooldown <= 0:
				r.damage += hit(s, idx, Vector2(r.x, r.z), 28 if station == 1 else 9, r.role, events)
				r.shots += 1
				r.cooldown = 1.05 if station == 1 else 0.72
	s.commander_cd = maxf(0, s.commander_cd - dt)
	var idx := target(s.enemies, p, 3.6)
	if idx >= 0 and s.commander_cd <= 0:
		hit(s, idx, p, 6, "commander", events)
		s.commander_shots += 1
		s.commander_cd = 0.55
	s.sentry_cd = maxf(0, s.sentry_cd - dt)
	idx = target(s.enemies, Vector2(0, 0.6), 4.4)
	if idx >= 0 and s.sentry_cd <= 0:
		hit(s, idx, Vector2(0, 0.6), 3, "sentry", events)
		s.sentry_shots += 1
		s.sentry_cd = 0.95
	for e in s.enemies:
		if e.hp <= 0:
			continue
		e.cooldown = maxf(0, e.cooldown - dt)
		var q := Vector2(e.x, e.z)
		var victim: Dictionary = {}
		var nearest := 2.8
		for r in s.recruits:
			if r.phase in ["deploying", "fighting"]:
				var d := q.distance_to(Vector2(r.x, r.z))
				if d < nearest:
					nearest = d
					victim = r
		var commander_near := q.distance_to(p) < minf(nearest, 2.8)
		if commander_near or not victim.is_empty():
			if e.cooldown <= 0:
				var damage := 15.0 if e.armored else 8.0
				if commander_near:
					s.hp = maxf(0, s.hp - damage)
				else:
					victim.hp = maxf(0, victim.hp - damage)
					if victim.hp <= 0:
						victim.phase = "fallen"
				e.cooldown = 1.2
		else:
			e.z += dt * (0.43 if e.armored else 0.53)
	for i in range(s.enemies.size() - 1, -1, -1):
		var e: Dictionary = s.enemies[i]
		if e.hp <= 0:
			s.killed.append(e.id)
			s.coins.append({"id": e.id, "x": e.x, "z": e.z, "value": 5 if not e.armored else 8})
			s.enemies.remove_at(i)
		elif e.z >= 2.0:
			s.leaked.append(e.id)
			s.hq = maxf(0, s.hq - (50 if e.armored else 30))
			s.enemies.remove_at(i)
			events.append({"kind": "leak", "id": e.id})
	for i in range(s.coins.size() - 1, -1, -1):
		var c: Dictionary = s.coins[i]
		if p.distance_to(Vector2(c.x, c.z)) <= 1.35:
			s.wallet += c.value
			s.collected.append(c.id)
			s.coins.remove_at(i)
			events.append({"kind": "pickup", "id": c.id})
	if s.hp <= 0 or s.hq <= 0:
		s.phase = "defeat"
		s.cause = "Commander lost" if s.hp <= 0 else "HQ breached"
	elif s.killed.size() + s.leaked.size() == TOTAL:
		s.phase = "victory" if s.killed.size() >= 8 else "defeat"
		s.cause = "Siege broken" if s.phase == "victory" else "Too many drones escaped"
	return events

static func finish(s: Dictionary, p: Dictionary) -> void:
	if s.phase not in ["victory", "defeat"] or s.recorded:
		return
	s.recorded = true
	p.attempts += 1
	p.wins += 1 if s.phase == "victory" else 0
	p.best_kills = maxi(p.best_kills, s.killed.size())

static func number(v: Variant, low: float, high: float, integer: bool = false) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and v >= low and v <= high and (not integer or float(v) == floor(float(v)))

static func valid_profile(p: Variant) -> bool:
	return p is Dictionary and number(p.get("attempts"), 0, 1000000, true) and number(p.get("wins"), 0, p.attempts, true) and number(p.get("best_kills"), 0, TOTAL, true)

static func unique_ids(a: Variant, low: int, high: int) -> bool:
	if not a is Array:
		return false
	var seen := {}
	for id in a:
		if not number(id, low, high, true) or seen.has(int(id)):
			return false
		seen[int(id)] = true
	return true

static func valid(s: Variant) -> bool:
	if not s is Dictionary or s.get("catalog") != CATALOG or s.get("seed") != 17 or s.get("phase") not in ["ready", "playing", "victory", "defeat"] or not s.get("cause") is String or not s.get("recorded") is bool:
		return false
	for key in ["time", "hp", "hq", "x", "z", "commander_cd", "sentry_cd"]:
		var limits: Array = {"time": [0, 10000], "hp": [0, 100], "hq": [0, 120], "x": [-4.5, 4.5], "z": [-5.7, 5.8], "commander_cd": [0, 0.55], "sentry_cd": [0, 0.95]}[key]
		if not number(s.get(key), limits[0], limits[1]):
			return false
	for key in ["wallet", "spent", "spawned", "commander_shots", "sentry_shots"]:
		if not number(s.get(key), 0, 100000, true):
			return false
	if s.spawned > TOTAL or int(s.spent) not in [0, 8, 22] or not s.get("pads") is Array or s.pads.size() != 2 or not s.get("stock") is Array or s.stock.size() != 2 or not s.get("consumed") is Array or s.consumed.size() != 2:
		return false
	for i in 2:
		if not s.pads[i] is bool or not number(s.stock[i], 0, 3 if i == 0 else 1, true) or not number(s.consumed[i], 0, 3 if i == 0 else 1, true) or s.stock[i] + s.consumed[i] != ((3 if i == 0 else 1) if s.pads[i] else 0):
			return false
	if s.spent != (8 if s.pads[0] else 0) + (14 if s.pads[1] else 0) or (s.pads[1] and not s.pads[0]):
		return false
	if not unique_ids(s.get("killed"), 0, TOTAL - 1) or not unique_ids(s.get("leaked"), 0, TOTAL - 1) or not unique_ids(s.get("collected"), 0, 100) or not s.get("enemies") is Array or not s.get("coins") is Array or not s.get("recruits") is Array or s.recruits.size() != 4:
		return false
	var resolved: Array = s.killed + s.leaked
	var enemy_ids: Array = []
	for e in s.enemies:
		if not e is Dictionary or not number(e.get("id"), 0, TOTAL - 1, true) or not e.get("armored") is bool or e.armored != (e.id >= 6) or not number(e.get("hp"), 0.001, 150 if e.armored else 48) or not number(e.get("z"), -6.2, 2) or not number(e.get("x"), -1.7, 1.7) or e.x != [-1.7, 1.7, 0.0][int(e.id) % 3] or not number(e.get("cooldown"), 0, 1.2):
			return false
		enemy_ids.append(e.id)
	if not unique_ids(resolved + enemy_ids, 0, s.spawned - 1) or resolved.size() + enemy_ids.size() != s.spawned:
		return false
	var coin_ids: Array = []
	for c in s.coins:
		if not c is Dictionary or not number(c.get("id"), 0, 100, true) or not number(c.get("x"), -4.5, 4.5) or not number(c.get("z"), -6.2, 5.8) or c.get("value") != (6 if c.id == 100 else (5 if c.id < 6 else 8)):
			return false
		coin_ids.append(c.id)
	var rewards: Array = s.collected + coin_ids
	if not unique_ids(rewards, 0, 100) or rewards.size() != s.killed.size() + 1:
		return false
	for id in rewards:
		if id != 100 and id not in s.killed:
			return false
	var earned := 8
	for id in s.collected:
		earned += 6 if id == 100 else (5 if id < 6 else 8)
	if s.wallet + s.spent != earned:
		return false
	var used := [0, 0]
	for i in 4:
		var r: Variant = s.recruits[i]
		if not r is Dictionary or r.get("id") != i or r.get("role") != ("rifle" if i < 3 else "vehicle") or r.get("phase") not in ["waiting", "equipping", "deploying", "fighting", "fallen"] or not number(r.get("hp"), 0, 42 if i < 3 else 140) or not number(r.get("x"), -4.5, 4.5) or not number(r.get("z"), -2, 5.8) or not number(r.get("clock"), 0, 0.8) or not number(r.get("cooldown"), 0, 1.05) or not number(r.get("shots"), 0, 100000, true) or not number(r.get("damage"), 0, 2000):
			return false
		if (r.phase == "fallen") != (r.hp == 0) or (r.phase == "waiting" and (r.shots != 0 or r.damage != 0)):
			return false
		if r.phase != "waiting":
			used[0 if i < 3 else 1] += 1
	if used[0] != s.consumed[0] or used[1] != s.consumed[1]:
		return false
	if s.phase == "ready" and (s.time != 0 or s.spawned != 0 or s.spent != 0 or s.recorded):
		return false
	if s.phase == "playing" and (s.hp <= 0 or s.hq <= 0 or s.recorded or resolved.size() == TOTAL):
		return false
	if s.phase == "victory" and (s.hp <= 0 or s.hq <= 0 or s.killed.size() < 8 or resolved.size() != TOTAL or s.cause != "Siege broken"):
		return false
	if s.phase == "defeat" and s.hp > 0 and s.hq > 0 and not (resolved.size() == TOTAL and s.killed.size() < 8):
		return false
	return true
