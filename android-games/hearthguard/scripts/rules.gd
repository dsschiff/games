extends RefCounted

const PADS := [Vector2(2.7, -2.5), Vector2(-3.0, 2.7)]
const COSTS := [5, 15]
const TOTAL := 20
const PICKUP := 1.25
const BUILD_DISTANCE := 1.65
const SPEED := 4.2

static func road_x(z: float) -> float:
	return -0.55 + sin(z * 0.42) * 0.95

static func position(s: Dictionary) -> Vector2:
	return Vector2(s.x, s.z)

static func fresh() -> Dictionary:
	var s := {"schema": 1, "phase": "ready", "time": 0.0, "x": 2.4, "z": 4.8, "wallet": 0, "integrity": 8, "spawned": 0, "killed": [], "leaked": [], "collected": [], "pads": [0, 0], "cooldowns": [0.0, 0.0], "enemies": [], "coins": [], "shots": 0, "spent": 0}
	for i in 5:
		s.coins.append({"id": i, "x": 2.4, "z": 3.5 - i * 1.05, "value": 1})
	return s

static func profile() -> Dictionary:
	return {"attempts": 0, "wins": 0, "best_kills": 0, "no_leak": false}

static func enemy_hp(id: int) -> int:
	return 2 if id < 10 else 4

static func spawn_time(id: int) -> float:
	return 5.0 + id * 1.65

static func nearby_pad(s: Dictionary) -> int:
	var best := -1
	var dist := BUILD_DISTANCE
	for i in PADS.size():
		var d := position(s).distance_to(PADS[i])
		if d <= dist:
			dist = d
			best = i
	return best

static func buy(s: Dictionary, pad: int) -> bool:
	if s.phase != "playing" or pad < 0 or pad >= PADS.size() or s.pads[pad] != 0 or position(s).distance_to(PADS[pad]) > BUILD_DISTANCE or s.wallet < COSTS[pad]:
		return false
	s.wallet -= COSTS[pad]
	s.spent += COSTS[pad]
	s.pads[pad] = 1
	return true

static func target(s: Dictionary, pad: int) -> int:
	var selected := -1
	var furthest := -INF
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		if Vector2(road_x(e.z), e.z).distance_to(PADS[pad]) <= 4.8 and e.z > furthest:
			selected = i
			furthest = e.z
	return selected

static func tick(s: Dictionary, direction: Vector2, delta: float) -> Array:
	var events: Array = []
	if s.phase != "playing":
		return events
	var dt := clampf(delta, 0, 0.05)
	s.time += dt
	var movement := direction.limit_length() * SPEED * dt
	s.x = clampf(s.x + movement.x, -4.4, 4.4)
	s.z = clampf(s.z + movement.y, -7.5, 6.5)
	for i in range(s.coins.size() - 1, -1, -1):
		var coin: Dictionary = s.coins[i]
		if position(s).distance_to(Vector2(coin.x, coin.z)) <= PICKUP:
			s.wallet += coin.value
			s.collected.append(coin.id)
			s.coins.remove_at(i)
			events.append({"kind": "pickup", "id": coin.id, "value": coin.value, "wallet": s.wallet})
	while s.spawned < TOTAL and s.time >= spawn_time(s.spawned):
		var id: int = s.spawned
		s.enemies.append({"id": id, "z": -9.0, "hp": enemy_hp(id)})
		s.spawned += 1
	for e in s.enemies:
		e.z += dt * (0.85 if e.id < 10 else 1.0)
	for pad in PADS.size():
		s.cooldowns[pad] = maxf(0, s.cooldowns[pad] - dt)
		if s.pads[pad] == 0 or s.cooldowns[pad] > 0:
			continue
		var selected := target(s, pad)
		if selected == -1:
			continue
		var e: Dictionary = s.enemies[selected]
		e.hp -= 1 if pad == 0 else 2
		s.shots += 1
		s.cooldowns[pad] = 0.72 if pad == 0 else 0.85
		events.append({"kind": "shot", "pad": pad, "z": e.z, "id": e.id})
		if e.hp <= 0:
			s.killed.append(e.id)
			s.coins.append({"id": e.id + 5, "x": road_x(e.z), "z": e.z, "value": 3})
			s.enemies.remove_at(selected)
			events.append({"kind": "kill", "id": e.id})
	for i in range(s.enemies.size() - 1, -1, -1):
		var e: Dictionary = s.enemies[i]
		if e.z >= 8.0:
			s.leaked.append(e.id)
			s.integrity = maxi(0, s.integrity - 2)
			s.enemies.remove_at(i)
			events.append({"kind": "leak", "id": e.id})
	if s.integrity <= 0:
		s.phase = "defeat"
	elif s.spawned == TOTAL and s.enemies.is_empty():
		s.phase = "victory"
	return events

static func finish(s: Dictionary, p: Dictionary) -> void:
	p.attempts += 1
	p.best_kills = maxi(p.best_kills, s.killed.size())
	if s.phase == "victory":
		p.wins += 1
		p.no_leak = p.no_leak or s.leaked.is_empty()

static func number(v: Variant, low: float, high: float, integer: bool = false) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and v >= low and v <= high and (not integer or float(v) == floor(float(v)))

static func ids(v: Variant, low: int, high: int) -> bool:
	if not v is Array:
		return false
	var seen := {}
	for id in v:
		if not number(id, low, high, true) or seen.has(int(id)):
			return false
		seen[int(id)] = true
	return true

static func valid_profile(p: Variant) -> bool:
	return p is Dictionary and number(p.get("attempts"), 0, 1000000, true) and number(p.get("wins"), 0, p.attempts, true) and number(p.get("best_kills"), 0, TOTAL, true) and p.get("no_leak") is bool and (not p.no_leak or p.wins > 0)

static func valid(s: Variant) -> bool:
	if not s is Dictionary or s.get("schema") != 1 or not s.get("phase") in ["ready", "playing", "victory", "defeat"]:
		return false
	for spec in [["time", 0, 600, false], ["x", -4.4, 4.4, false], ["z", -7.5, 6.5, false], ["wallet", 0, 65, true], ["integrity", 0, 8, true], ["spawned", 0, TOTAL, true], ["shots", 0, 2000, true], ["spent", 0, 20, true]]:
		if not number(s.get(spec[0]), spec[1], spec[2], spec[3]):
			return false
	if not ids(s.get("killed"), 0, TOTAL - 1) or not ids(s.get("leaked"), 0, TOTAL - 1) or not ids(s.get("collected"), 0, TOTAL + 4):
		return false
	if not s.get("pads") is Array or s.pads.size() != 2 or not s.get("cooldowns") is Array or s.cooldowns.size() != 2 or not s.get("enemies") is Array or not s.get("coins") is Array:
		return false
	var spent := 0
	for i in 2:
		if not number(s.pads[i], 0, 1, true) or not number(s.cooldowns[i], 0, 0.85):
			return false
		if s.pads[i] == 1:
			spent += COSTS[i]
		elif s.cooldowns[i] != 0:
			return false
	if spent != s.spent:
		return false
	var resolved := {}
	for id in s.killed + s.leaked:
		if int(id) >= s.spawned or resolved.has(int(id)):
			return false
		resolved[int(id)] = true
	for e in s.enemies:
		if not e is Dictionary or not number(e.get("id"), 0, s.spawned - 1, true) or not number(e.get("z"), -9, 8) or not number(e.get("hp"), 1, enemy_hp(int(e.id)), true) or resolved.has(int(e.id)):
			return false
		resolved[int(e.id)] = true
	if resolved.size() != s.spawned or s.integrity != maxi(0, 8 - 2 * s.leaked.size()):
		return false
	var supply := {}
	var earned := 0
	for id in s.collected:
		if id >= 5 and not s.killed.has(id - 5):
			return false
		supply[int(id)] = true
		earned += 1 if id < 5 else 3
	for c in s.coins:
		if not c is Dictionary or not number(c.get("id"), 0, TOTAL + 4, true) or not number(c.get("x"), -4.4, 4.4) or not number(c.get("z"), -9, 8) or supply.has(int(c.id)):
			return false
		if c.get("value") != (1 if c.id < 5 else 3) or (c.id >= 5 and not s.killed.has(c.id - 5)):
			return false
		if c.id < 5 and (not is_equal_approx(float(c.x), 2.4) or not is_equal_approx(float(c.z), 3.5 - c.id * 1.05)):
			return false
		if c.id >= 5 and (not number(c.z, -7, 7.9999) or not is_equal_approx(float(c.x), road_x(c.z))):
			return false
		supply[int(c.id)] = true
	if supply.size() != 5 + s.killed.size() or s.wallet + s.spent != earned:
		return false
	if s.phase == "ready" and (s.time != 0 or s.spawned != 0 or s.spent != 0 or s.wallet != 0 or not s.collected.is_empty()):
		return false
	if s.phase == "victory" and (s.spawned != TOTAL or not s.enemies.is_empty() or s.integrity <= 0):
		return false
	if (s.phase == "defeat") != (s.integrity == 0):
		return false
	return true
