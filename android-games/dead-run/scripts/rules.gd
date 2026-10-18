extends RefCounted
# Original deterministic rules, NOT measured equations from the reference ad.
const RUN := "canal-bridge-v1"
const SEED := 61723
const CAP := 12
const END_TICK := 3000
const SPEED := 1.6
const LANES := [-2.65, 0.0, 2.65]

static func fresh() -> Dictionary:
	var enemies: Array = []
	for i in 24:
		enemies.append({"id": i, "born": 600 + i * 65, "x": LANES[(i * 7 + SEED) % 3], "z": 23.0, "hp": 3, "resolved": false})
	return {"run": RUN, "seed": SEED, "phase": "ready", "tick": 0, "x": 0.0, "aim": 0.0, "crew": 3, "joined": 0, "lost": 0,
		"gates": [{"id": 0, "x": 0.0, "z": 14.0, "value": -6, "hits": 0, "crossed": false, "applied": 0},
			{"id": 1, "x": 2.65, "z": 28.0, "value": -12, "hits": 0, "crossed": false, "applied": 0}],
		"enemies": enemies, "bullets": [], "shots": 0, "gate_hits": 0, "kills": 0, "leaks": 0, "contact": 0,
		"side_hp": 120, "side_hits": 0, "side_claimed": false, "final_hp": 40, "final_hits": 0,
		"gain_tick": -1000, "hurt_tick": -1000, "notice": "Drag across the road. Fire is automatic.", "last_crossing": 0}

static func offset(index: int, count: int) -> Vector2:
	var columns := mini(count, 4)
	return Vector2((index % columns - (columns - 1) * 0.5) * 0.47, floori(float(index) / columns) * 0.46)

static func half_width(count: int) -> float:
	return (mini(count, 4) - 1) * 0.235 + 0.24

static func overlap(x: float, count: int, target_x: float, width: float) -> bool:
	return absf(x - target_x) <= half_width(count) + width

static func steer(s: Dictionary, x: float) -> void:
	s.aim = clampf(x, -4.35 + half_width(s.crew), 4.35 - half_width(s.crew))

static func add_crew(s: Dictionary, amount: int) -> void:
	var old: int = s.crew
	s.crew = clampi(s.crew + amount, 0, CAP)
	if s.crew > old:
		s.gain_tick = s.tick
		s.joined += s.crew - old
	if s.crew < old:
		s.hurt_tick = s.tick
		s.lost += old - s.crew
	s.x = clampf(s.x, -4.35 + half_width(s.crew), 4.35 - half_width(s.crew))
	s.aim = clampf(s.aim, -4.35 + half_width(s.crew), 4.35 - half_width(s.crew))

static func gate_hit(g: Dictionary) -> void:
	g.hits += 1
	g.value = mini(6, (-6 if g.id == 0 else -12) + g.hits)

static func cross(s: Dictionary, g: Dictionary) -> void:
	if g.crossed:
		return
	g.crossed = true
	if overlap(s.x, s.crew, g.x, 0.9):
		g.applied = g.value
		s.last_crossing = g.value
		add_crew(s, g.value)
		s.notice = "Gate crossed once: %+d crew" % g.value
	else:
		s.notice = "Gate passed outside your footprint"

static func hit(s: Dictionary, bullet: Dictionary, old_z: float) -> bool:
	var nearest := INF
	var kind := ""
	var index := -1
	for i in s.gates.size():
		var g: Dictionary = s.gates[i]
		if not g.crossed and absf(bullet.x - g.x) <= 0.9 and g.z >= old_z and g.z <= bullet.z and g.z < nearest:
			nearest = g.z
			kind = "gate"
			index = i
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		if s.tick >= e.born and not e.resolved and absf(bullet.x - e.x) <= 0.55 and e.z >= old_z and e.z <= bullet.z and e.z < nearest:
			nearest = e.z
			kind = "enemy"
			index = i
	if s.side_hp > 0 and absf(bullet.x + 2.65) <= 1.0 and old_z <= 12.0 and bullet.z >= 12.0 and 12.0 < nearest:
		nearest = 12.0
		kind = "side"
	var final_z := 20.0 - maxf(0, s.tick - 2160) / 60.0 * SPEED
	if s.tick >= 2160 and s.final_hp > 0 and absf(bullet.x) <= 1.25 and old_z <= final_z and bullet.z >= final_z and final_z < nearest:
		kind = "final"
	match kind:
		"gate":
			gate_hit(s.gates[index])
			s.gate_hits += 1
		"enemy":
			s.enemies[index].hp -= 1
			if s.enemies[index].hp == 0:
				s.enemies[index].resolved = true
				s.kills += 1
		"side":
			s.side_hp -= 1
			s.side_hits += 1
			if s.side_hp == 0 and not s.side_claimed:
				s.side_claimed = true
				add_crew(s, 3)
				s.notice = "Spore crane cleared! Three riggers join."
		"final":
			s.final_hp -= 1
			s.final_hits += 1
			if s.final_hp == 0:
				s.notice = "Evacuation barricade cleared. Hold the rescue line!"
	return not kind.is_empty()

static func step(s: Dictionary) -> void:
	if s.phase != "playing":
		return
	s.tick += 1
	s.x = move_toward(s.x, s.aim, 6.0 / 60.0)
	for g in s.gates:
		if not g.crossed:
			g.z = maxf(0, g.z - SPEED / 60.0)
			if g.z <= 0:
				cross(s, g)
	for e in s.enemies:
		if s.tick >= e.born and not e.resolved:
			e.z = maxf(0, e.z - 2.2 / 60.0)
			if e.z <= 0:
				e.resolved = true
				var touching := overlap(s.x, s.crew, e.x, 0.35)
				add_crew(s, -2 if touching else -1)
				s.leaks += 1
				s.contact += int(touching)
				s.notice = "Contact: -2 crew" if touching else "Infected reached rescue line: -1 crew"
	if s.tick % 30 == 0:
		for i in s.crew:
			var q := offset(i, s.crew)
			s.bullets.append({"x": s.x + q.x, "z": 0.35, "id": s.shots})
			s.shots += 1
	for i in range(s.bullets.size() - 1, -1, -1):
		var b: Dictionary = s.bullets[i]
		var old: float = b.z
		b.z += 24.0 / 60.0
		if hit(s, b, old) or b.z > 34:
			s.bullets.remove_at(i)
	if s.crew == 0:
		s.phase = "defeat"
		s.notice = "The rescue crew was depleted. Retry immediately."
	elif s.tick >= 2910 and s.final_hp > 0:
		s.phase = "defeat"
		s.notice = "The barricade reached the line. Aim down the centre."
	elif s.tick >= END_TICK:
		s.phase = "victory"
		s.notice = "Bridge open. The evacuation convoy is through!"

static func number(v: Variant, low: float, high: float, integer: bool = false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v >= low and v <= high and (not integer or v == floor(v))

static func valid(s: Variant) -> bool:
	if not s is Dictionary or s.get("run") != RUN or s.get("seed") != SEED or s.get("phase") not in ["ready", "playing", "victory", "defeat"]:
		return false
	for k in ["tick", "crew", "joined", "lost", "shots", "gate_hits", "kills", "leaks", "contact", "side_hp", "side_hits", "final_hp", "final_hits", "gain_tick", "hurt_tick", "last_crossing"]:
		if not number(s.get(k), -1000 if k in ["gain_tick", "hurt_tick", "last_crossing"] else 0, 100000, true):
			return false
	if s.tick > END_TICK or s.crew > CAP or not number(s.get("x"), -4.35 + half_width(s.crew) - 0.00001, 4.35 - half_width(s.crew) + 0.00001) or not number(s.get("aim"), -4.35 + half_width(s.crew) - 0.00001, 4.35 - half_width(s.crew) + 0.00001):
		return false
	if not s.get("notice") is String or s.notice.length() > 240 or not s.get("side_claimed") is bool or s.side_hp + s.side_hits != 120 or s.final_hp + s.final_hits != 40 or s.side_claimed != (s.side_hp == 0):
		return false
	if not s.get("gates") is Array or s.gates.size() != 2 or not s.get("enemies") is Array or s.enemies.size() != 24 or not s.get("bullets") is Array or s.bullets.size() > 400:
		return false
	var gh := 0
	var gains := 0
	for i in 2:
		var g: Variant = s.gates[i]
		if not g is Dictionary or g.get("id") != i or g.get("x") != (0.0 if i == 0 else 2.65) or not number(g.get("hits"), 0, s.shots, true) or g.get("value") != mini(6, (-6 if i == 0 else -12) + int(g.hits)) or not g.get("crossed") is bool or not number(g.get("applied"), -12, 6, true) or not number(g.get("z"), 0, 28):
			return false
		var expected := maxf(0, (14.0 if i == 0 else 28.0) - s.tick / 60.0 * SPEED)
		if absf(g.z - expected) > 0.0001 or g.crossed != (expected < 0.0001) or (not g.crossed and g.applied != 0) or (g.applied != 0 and g.applied != g.value):
			return false
		gh += g.hits
		gains += g.applied
	var kills := 0
	var leaks := 0
	for i in 24:
		var e: Variant = s.enemies[i]
		if not e is Dictionary or e.get("id") != i or e.get("born") != 600 + i * 65 or e.get("x") != LANES[(i * 7 + SEED) % 3] or not number(e.get("hp"), 0, 3, true) or not number(e.get("z"), 0, 23) or not e.get("resolved") is bool:
			return false
		if s.tick < e.born and (e.hp != 3 or e.resolved or e.z != 23):
			return false
		if e.hp == 0:
			if not e.resolved:
				return false
			kills += 1
		elif e.resolved:
			if e.z != 0:
				return false
			leaks += 1
		elif absf(e.z - maxf(0, 23.0 - maxi(0, s.tick - e.born + 1) / 60.0 * 2.2)) > 0.0001:
			return false
	if gh != s.gate_hits or kills != s.kills or leaks != s.leaks or s.contact > s.leaks or s.kills + s.leaks > 24:
		return false
	var possible_joined := maxi(0, s.gates[0].applied) + maxi(0, s.gates[1].applied) + (3 if s.side_claimed else 0)
	var possible_lost: int = maxi(0, -s.gates[0].applied) + maxi(0, -s.gates[1].applied) + s.leaks + s.contact
	if s.crew != 3 + s.joined - s.lost or s.joined > possible_joined or s.lost > possible_lost or (s.crew > 0 and s.lost != possible_lost):
		return false
	var ids := {}
	for b in s.bullets:
		if not b is Dictionary or not number(b.get("id"), 0, s.shots - 1, true) or ids.has(b.id) or not number(b.get("x"), -4.5, 4.5) or not number(b.get("z"), 0, 34):
			return false
		ids[b.id] = true
	if s.phase == "ready":
		for key in ["tick", "joined", "lost", "shots", "gate_hits", "kills", "leaks", "contact", "side_hits", "final_hits", "last_crossing", "x", "aim"]:
			if s[key] != 0:
				return false
		if s.crew != 3 or s.gain_tick != -1000 or s.hurt_tick != -1000 or not s.bullets.is_empty():
			return false
	if s.phase == "victory" and (s.tick != END_TICK or s.crew == 0 or s.final_hp != 0):
		return false
	if s.phase == "playing" and (s.tick >= END_TICK or s.crew == 0 or (s.tick >= 2910 and s.final_hp > 0)):
		return false
	if s.phase == "defeat" and not (s.crew == 0 or (s.tick >= 2910 and s.final_hp > 0)):
		return false
	return true
