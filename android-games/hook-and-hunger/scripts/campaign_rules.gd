extends RefCounted
const Data = preload("res://scripts/campaign_data.gd")
const PAD := Vector2(0, 6.8)
const SAVE_NUMERIC_EPSILON := 0.000001

static func profile() -> Dictionary:
	return {"version": 1, "stage": -1, "clears": [], "medals": {}, "time": 0.0, "hits": 0, "rescues": 0, "completed": false, "arena_seed": 1701, "arena_weapon": 3, "arena_scores": {}, "ending": {}}

static func fresh(stage: int, tier: int, wallet: int, seed: int = 1701, arena: bool = false) -> Dictionary:
	var d := Data.definition(stage, seed, arena, tier)
	var enemies := []
	for spec in d.roster:
		enemies.append(actor(spec))
	return {"schema": 2, "definition": d, "x": 0.0, "z": 6.8, "hp": 100.0, "tier": tier, "starting_tier": tier, "wallet": wallet, "starting_wallet": wallet, "spent": 0, "collected": [], "dead": [], "drops": [], "enemies": enemies, "phase": "playing", "time": 0.0, "deaths": 0, "hits": 0, "cooldown": 0.0, "strike": 0.0, "strike_id": -1, "strike_x": 0.0, "strike_z": 0.0, "contact": false, "notice": d.lesson, "notice_left": 6.0, "wave": 0, "projectiles": [], "serial": 0, "blocked": 0.0, "heals": 0, "wave_times": []}

static func actor(spec: Dictionary) -> Dictionary:
	return {"id": int(spec.id), "x": spec.x, "z": spec.z, "hp": spec.hp, "mode": "idle", "clock": 0.0, "ax": spec.x, "az": spec.z, "tx": 0.0, "tz": 1.0, "flash": 0.0, "facing": PI, "cycles": 0, "attack": "slam", "heal_clock": 2.0, "heal_to": -1, "charge_hit": false}

static func p(s: Dictionary) -> Vector2:
	return Vector2(s.x, s.z)

static func weapon(s: Dictionary) -> Dictionary:
	return s.definition.weapons[int(s.tier)]

static func active(s: Dictionary) -> Array:
	return s.enemies.filter(func(e: Dictionary) -> bool: return int(s.definition.roster[int(e.id)].wave) == int(s.wave))

static func constrain(s: Dictionary, point: Vector2, radius: float, enemy: bool = false) -> Vector2:
	point.x = clampf(point.x, -6.6 + radius, 6.6 - radius)
	var low := -12.6 + radius
	var high := 4.5 - radius if enemy else 8.8 - radius
	if not enemy and int(s.tier) < int(s.definition.required_tier):
		low = 5.0 + radius
	point.y = clampf(point.y, low, high)
	for b in s.definition.obstacles:
		var center := Vector2(b.x, b.z)
		var minimum: float = float(b.radius) + radius
		if point.distance_to(center) < minimum:
			point = center + (point - center).normalized() * minimum if point != center else center + Vector2(minimum, 0)
	return point

static func clear_line(s: Dictionary, a: Vector2, b: Vector2) -> bool:
	for rock in s.definition.obstacles:
		var center := Vector2(rock.x, rock.z)
		if Geometry2D.get_closest_point_to_segment(center, a, b).distance_to(center) < float(rock.radius) + 0.12:
			return false
	return true

static func notify(s: Dictionary, text: String) -> void:
	s.notice = text
	s.notice_left = 4.5

static func cost(s: Dictionary) -> int:
	return int(s.definition.costs[int(s.tier)]) if int(s.tier) < int(s.definition.offer) else 0

static func purchase(s: Dictionary) -> bool:
	if s.phase != "playing" or p(s).distance_to(PAD) > 1.8:
		return false
	var price := cost(s)
	if price > 0:
		if int(s.wallet) < price:
			return false
		s.wallet -= price
		s.spent += price
		s.tier += 1
		s.cooldown = 0.0
		notify(s, str(weapon(s).name) + " • power " + str(weapon(s).power) + " • full hull • passage open")
	else:
		notify(s, "Dock repaired your hull. Earned salvage retained.")
	s.hp = 100.0
	return true

static func retry(s: Dictionary) -> bool:
	if s.phase != "defeat":
		return false
	s.phase = "playing"
	s.x = PAD.x
	s.z = PAD.y
	s.hp = 100.0
	s.deaths += 1
	s.cooldown = 0.0
	s.strike = 0.0
	s.strike_id = -1
	s.projectiles.clear()
	for i in s.enemies.size():
		s.enemies[i] = actor(s.definition.roster[int(s.enemies[i].id)])
	notify(s, "Recovered. Weapon, earned salvage and cleared foes retained.")
	return true

static func target(s: Dictionary) -> int:
	if p(s).y >= 5.0 or int(s.tier) < int(s.definition.required_tier):
		return -1
	var nearest: float = float(weapon(s).reach)
	var chosen := -1
	for e in active(s):
		var q := Vector2(e.x, e.z)
		var distance := p(s).distance_to(q)
		if distance <= nearest and clear_line(s, p(s), q):
			chosen = int(e.id)
			nearest = distance
	return chosen

static func shielded(s: Dictionary, e: Dictionary) -> bool:
	var role: String = s.definition.roster[int(e.id)].role
	if not role in ["shield", "kiln"]:
		return false
	return Vector2(sin(e.facing), cos(e.facing)).dot(Vector2(e.x, e.z).direction_to(p(s))) > 0.2

static func collect(s: Dictionary, sweep: bool = false) -> void:
	for drop in s.drops.duplicate():
		if sweep or p(s).distance_to(Vector2(drop.x, drop.z)) <= 1.4:
			if not int(drop.id) in s.collected:
				s.wallet += int(s.definition.roster[int(drop.id)].reward)
				s.collected.append(int(drop.id))
			s.drops.erase(drop)

static func hit(s: Dictionary, damage: float) -> void:
	s.hp = maxf(0, s.hp - damage)
	s.hits += 1

static func _strike(s: Dictionary) -> void:
	if p(s).y >= 5.0 or int(s.tier) < int(s.definition.required_tier):
		return
	var impact := Vector2(s.strike_x, s.strike_z)
	for e in active(s):
		var q := Vector2(e.x, e.z)
		if not (int(e.id) == int(s.strike_id) and q.distance_to(impact) < 1.3 or q.distance_to(impact) < float(weapon(s).cleave)) or p(s).distance_to(q) > float(weapon(s).reach) + 0.25 or not clear_line(s, p(s), q):
			continue
		if shielded(s, e):
			s.blocked = 0.4
			continue
		e.hp = maxf(0, e.hp - float(weapon(s).damage))
		e.flash = 0.16
		if e.hp <= 0 and not int(e.id) in s.dead:
			s.dead.append(int(e.id))
			s.drops.append({"id": int(e.id), "x": e.x, "z": e.z})
	s.enemies = s.enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if active(s).is_empty():
		collect(s, true)
		s.projectiles.clear()
		s.wave_times.append(s.time)
		if int(s.wave) == int(s.definition.waves) - 1:
			s.phase = "victory"
			notify(s, "Passage restored. Return to the harbor route.")
		else:
			s.wave += 1
			s.hp = minf(100, s.hp + 15)
			notify(s, "WAVE " + str(int(s.wave) + 1) + " • salvage swept in • +15 hull")

static func _attack_kind(spec: Dictionary, e: Dictionary) -> String:
	match str(spec.role):
		"lancer", "shield": return "line"
		"spitter", "tender", "twin_sun": return "shot"
		"charger", "twin_moon": return "charge"
		"warden": return ["ring", "slam", "line"][int(e.cycles) % 3]
		"kiln": return ["line", "ring", "shot"][int(e.cycles) % 3]
		"crown": return ["ring", "line", "burst", "charge"][int(e.cycles) % 4]
	return "slam"

static func _projectile(s: Dictionary, e: Dictionary, spec: Dictionary, angle: float) -> void:
	s.serial += 1
	var direction := Vector2(e.tx, e.tz).rotated(angle)
	s.projectiles.append({"id": int(s.serial), "x": e.x, "z": e.z, "dx": direction.x, "dz": direction.y, "life": 2.2, "damage": spec.damage})

static func _resolve(s: Dictionary, e: Dictionary, spec: Dictionary) -> void:
	var center := Vector2(e.ax, e.az)
	var distance := p(s).distance_to(center)
	var direction := Vector2(e.tx, e.tz)
	match str(e.attack):
		"slam":
			if distance < (3.55 if spec.boss else float(spec.range) + 0.35) and clear_line(s, center, p(s)):
				hit(s, spec.damage)
		"ring":
			if distance > 2.0 and distance < 6.35 and clear_line(s, center, p(s)):
				hit(s, spec.damage)
		"line":
			var end := center + direction * (8.5 if spec.boss else 5.3)
			if Geometry2D.get_closest_point_to_segment(p(s), center, end).distance_to(p(s)) < 0.8 and clear_line(s, center, p(s)):
				hit(s, spec.damage)
		"shot", "burst":
			for angle in ([-0.32, 0.0, 0.32] if spec.boss or e.attack == "burst" else [0.0]):
				_projectile(s, e, spec, angle)
		"charge":
			e.mode = "charge"
			e.clock = 0.85
			e.charge_hit = false
			return
	e.mode = "recover"
	e.clock = spec.recovery

static func step(s: Dictionary, movement: Vector2, delta: float) -> void:
	if s.phase != "playing" or not is_finite(delta) or delta <= 0:
		return
	var dt := minf(delta, 0.05)
	s.time += dt
	s.notice_left = maxf(0, s.notice_left - dt)
	s.blocked = maxf(0, s.blocked - dt)
	s.cooldown = maxf(0, s.cooldown - dt)
	var point := constrain(s, p(s) + movement.limit_length() * dt * 4.2, 0.4)
	s.x = point.x
	s.z = point.y
	collect(s)
	if s.strike > 0:
		var before: float = s.strike
		s.strike = maxf(0, s.strike - dt)
		if before > 0.18 and s.strike <= 0.18 and not s.contact:
			s.contact = true
			_strike(s)
	if s.phase != "playing":
		return
	if s.cooldown <= 0 and s.strike <= 0:
		var chosen := target(s)
		if chosen >= 0:
			for e in active(s):
				if int(e.id) == chosen:
					s.strike_id = chosen
					s.strike_x = e.x
					s.strike_z = e.z
					s.strike = 0.36
					s.contact = false
					s.cooldown = float(weapon(s).period)
	for shot in s.projectiles.duplicate():
		var old := Vector2(shot.x, shot.z)
		var next := old + Vector2(shot.dx, shot.dz) * dt * 7.0
		shot.x = next.x
		shot.z = next.y
		shot.life -= dt
		if not clear_line(s, old, next):
			s.projectiles.erase(shot)
		elif p(s).y < 5 and Geometry2D.get_closest_point_to_segment(p(s), old, next).distance_to(p(s)) < 0.5:
			hit(s, shot.damage)
			s.projectiles.erase(shot)
		elif shot.life <= 0:
			s.projectiles.erase(shot)
	for e in active(s):
		var spec: Dictionary = s.definition.roster[int(e.id)]
		var q := Vector2(e.x, e.z)
		var distance := p(s).distance_to(q)
		e.flash = maxf(0, e.flash - dt)
		e.heal_to = -1
		if p(s).y >= 5.0:
			continue
		if spec.role == "tender":
			e.heal_clock -= dt
			if e.heal_clock <= 0:
				e.heal_clock = 2.4
				for ally in active(s):
					var ally_spec: Dictionary = s.definition.roster[int(ally.id)]
					if int(ally.id) != int(e.id) and ally.hp < ally_spec.hp and q.distance_to(Vector2(ally.x, ally.z)) < 5.0:
						ally.hp = minf(ally_spec.hp, ally.hp + float(weapon(s).damage) * 1.5)
						e.heal_to = int(ally.id)
						s.heals += 1
						break
		if e.mode == "wind":
			e.clock -= dt
			if e.clock <= 0:
				_resolve(s, e, spec)
		elif e.mode == "charge":
			var next := constrain(s, q + Vector2(e.tx, e.tz) * dt * 8.0, 0.6, true)
			if not e.charge_hit and Geometry2D.get_closest_point_to_segment(p(s), q, next).distance_to(p(s)) < 0.9:
				hit(s, spec.damage)
				e.charge_hit = true
			e.x = next.x
			e.z = next.y
			e.clock -= dt
			if e.clock <= 0 or next.distance_to(q) < 0.01:
				e.mode = "recover"
				e.clock = spec.recovery
		elif e.mode == "recover":
			e.clock = maxf(0, e.clock - dt)
			if e.clock <= 0:
				e.mode = "idle"
		else:
			e.facing = atan2(p(s).x - q.x, p(s).y - q.y)
			if distance <= float(spec.range) and clear_line(s, q, p(s)):
				e.mode = "wind"
				e.clock = spec.wind
				e.ax = e.x
				e.az = e.z
				var direction := q.direction_to(p(s))
				e.tx = direction.x
				e.tz = direction.y
				e.attack = _attack_kind(spec, e)
				e.cycles += 1
			else:
				var direction := q.direction_to(p(s))
				if spec.role in ["spitter", "tender"] and distance < 4.5:
					direction = -direction
				var next := constrain(s, q + direction * float(spec.speed) * dt, 0.6, true)
				e.x = next.x
				e.z = next.y
	if s.hp <= 0:
		s.phase = "defeat"
		notify(s, "Hull breached. Recover at the dock; your earned progress is safe.")

static func valid(v: Variant) -> bool:
	if not v is Dictionary or v.get("schema") != 2 or not Data.valid(v.get("definition")):
		return false
	for key in ["x", "z", "hp", "tier", "starting_tier", "wallet", "starting_wallet", "spent", "collected", "dead", "drops", "enemies", "phase", "time", "deaths", "hits", "cooldown", "strike", "strike_id", "strike_x", "strike_z", "contact", "notice", "notice_left", "wave", "projectiles", "serial", "blocked", "heals", "wave_times"]:
		if not v.has(key):
			return false
	for key in ["tier", "starting_tier", "wallet", "starting_wallet", "spent", "deaths", "hits", "serial", "heals"]:
		if not Data.number(v[key], 0, 1000000, true):
			return false
	if v.tier < 1 or v.tier > 3 or not Data.number(v.x, -6.201, 6.201) or not Data.number(v.z, -12.201, 8.401) or not Data.number(v.hp, 0, 100) or not Data.number(v.wave, 0, v.definition.waves - 1, true):
		return false
	if int(v.tier) < int(v.definition.required_tier) and (v.z < 5.399 or v.starting_wallet < v.definition.costs[int(v.tier)]):
		return false
	if int(v.tier) < int(v.definition.required_tier) and (v.phase == "victory" or not v.dead is Array or not v.dead.is_empty() or v.wave != 0 or int(v.definition.offer) <= int(v.tier)):
		return false
	if v.starting_tier < 1 or v.starting_tier > v.tier or v.tier > maxi(int(v.starting_tier), int(v.definition.offer)):
		return false
	var expected_spend := 0
	for tier in range(int(v.starting_tier), int(v.tier)):
		expected_spend += int(v.definition.costs[tier])
	if v.spent != expected_spend:
		return false
	for key in ["time", "notice_left", "cooldown", "strike", "blocked"]:
		if not Data.number(v[key], 0, 10000000):
			return false
	if v.cooldown > float(weapon(v).period) + SAVE_NUMERIC_EPSILON or v.strike > 0.361 or not v.phase in ["playing", "victory", "defeat"] or not v.contact is bool or not v.notice is String or v.notice.length() > 200 or not Data.number(v.strike_id, -1, v.definition.roster.size() - 1, true) or not Data.number(v.strike_x, -7, 7) or not Data.number(v.strike_z, -13, 9):
		return false
	if (v.hp == 0) != (v.phase == "defeat") or not v.wave_times is Array or v.wave_times.size() != int(v.wave) + (1 if v.phase == "victory" else 0):
		return false
	var dead := []
	var collected := []
	for group_index in 2:
		var group: Variant = v.dead if group_index == 0 else v.collected
		if not group is Array or group.size() > v.definition.roster.size():
			return false
		var seen := []
		for id in group:
			if not Data.number(id, 0, v.definition.roster.size() - 1, true) or int(id) in seen:
				return false
			seen.append(int(id))
		if group_index == 0:
			dead = seen
		else:
			collected = seen
	var ids := []
	var current_wave_living := 0
	if not v.enemies is Array or v.enemies.size() > 100 or not v.drops is Array or v.drops.size() > 100 or not v.projectiles is Array or v.projectiles.size() > 200:
		return false
	for e in v.enemies:
		if not e is Dictionary or not Data.number(e.get("id"), 0, v.definition.roster.size() - 1, true):
			return false
		var id := int(e.id)
		if id in ids or id in dead or not Data.number(e.get("hp"), 0.001, v.definition.roster[id].hp) or not e.get("mode") in ["idle", "wind", "recover", "charge"] or not e.get("charge_hit") is bool or not e.get("attack") in ["slam", "line", "ring", "shot", "burst", "charge"]:
			return false
		for key in ["x", "ax"]:
			if not Data.number(e.get(key), -6.01, 6.01):
				return false
		for key in ["z", "az"]:
			if not Data.number(e.get(key), -12.01, 4.01):
				return false
		for key in ["clock", "flash", "heal_clock", "cycles"]:
			if not Data.number(e.get(key), 0, 1000000):
				return false
		if not Data.number(e.get("tx"), -1.001, 1.001) or not Data.number(e.get("tz"), -1.001, 1.001) or not Data.number(e.get("facing"), -TAU, TAU) or not Data.number(e.get("heal_to"), -1, v.definition.roster.size() - 1, true):
			return false
		ids.append(id)
		if int(v.definition.roster[id].wave) == int(v.wave):
			current_wave_living += 1
	if ids.size() + dead.size() != v.definition.roster.size() or (v.phase == "victory" and not ids.is_empty()):
		return false
	# Natural last-kill transitions advance the wave synchronously in _strike.
	# An active/Retry state without current opponents cannot make that transition.
	if v.phase != "victory" and current_wave_living == 0:
		return false
	for spec in v.definition.roster:
		if int(spec.wave) < int(v.wave) and not int(spec.id) in dead or int(spec.wave) > int(v.wave) and int(spec.id) in dead:
			return false
	var accounted := collected.duplicate()
	for id in collected:
		if not id in dead:
			return false
	for drop in v.drops:
		if not drop is Dictionary or not Data.number(drop.get("id"), 0, v.definition.roster.size() - 1, true) or not int(drop.id) in dead or int(drop.id) in accounted or not Data.number(drop.get("x"), -6.01, 6.01) or not Data.number(drop.get("z"), -12.01, 4.01):
			return false
		for b in v.definition.obstacles:
			if Vector2(drop.x, drop.z).distance_to(Vector2(b.x, b.z)) < float(b.radius) + 0.1:
				return false
		accounted.append(int(drop.id))
	if accounted.size() != dead.size():
		return false
	var earned := 0
	for id in collected:
		earned += int(v.definition.roster[id].reward)
	if int(v.wallet) + int(v.spent) != int(v.starting_wallet) + earned:
		return false
	var shot_ids := []
	for shot in v.projectiles:
		if not shot is Dictionary:
			return false
		for key in ["x", "z", "dx", "dz", "life", "damage", "id"]:
			if not Data.number(shot.get(key), -100 if key in ["x", "z", "dx", "dz"] else 0, 1000000):
				return false
		if not Data.number(shot.id, 1, v.serial, true) or int(shot.id) in shot_ids or not Data.number(shot.life, 0, 2.201) or not Data.number(shot.damage, 1, 100) or absf(Vector2(shot.dx, shot.dz).length() - 1.0) > 0.001:
			return false
		shot_ids.append(int(shot.id))
	for value in v.wave_times:
		if not Data.number(value, 0, v.time):
			return false
	return true

static func restore(v: Variant) -> Dictionary:
	if not valid(v):
		return {}
	var s: Dictionary = v.duplicate(true)
	for key in ["schema", "tier", "starting_tier", "wallet", "starting_wallet", "spent", "deaths", "hits", "strike_id", "wave", "serial", "heals"]:
		s[key] = int(s[key])
	for group in [s.dead, s.collected]:
		for i in group.size():
			group[i] = int(group[i])
	for e in s.enemies:
		e.id = int(e.id)
		e.cycles = int(e.cycles)
		e.heal_to = int(e.heal_to)
	for drop in s.drops:
		drop.id = int(drop.id)
	return s

static func valid_profile(v: Variant) -> bool:
	if not v is Dictionary:
		return false
	for key in profile():
		if not v.has(key):
			return false
	if v.version != 1 or not Data.number(v.stage, -1, 11, true) or not v.clears is Array or v.clears.size() > 13 or not v.medals is Dictionary or not v.completed is bool or not v.arena_scores is Dictionary or v.arena_scores.size() > 100 or not v.ending is Dictionary:
		return false
	for key in ["time", "hits", "rescues"]:
		if not Data.number(v[key], 0, 100000000, key != "time"):
			return false
	for i in v.clears.size():
		if not Data.number(v.clears[i], i - 1, i - 1, true):
			return false
	if v.stage > v.clears.size() - 1 or v.completed and v.clears.size() != 13 or not Data.number(v.arena_seed, 1, 999999, true) or not Data.number(v.arena_weapon, 1, 3, true):
		return false
	for key in v.medals:
		if not str(key).is_valid_int() or not Data.number(int(key), -1, 11, true) or not Data.number(v.medals[key], 1, 3, true):
			return false
	for key in v.arena_scores:
		var score: Variant = v.arena_scores[key]
		if not key is String or not score is Dictionary:
			return false
		for field in ["time", "hits", "rescues"]:
			if not Data.number(score.get(field), 0, 100000000, field != "time"):
				return false
	return v.ending.is_empty() or v.completed and valid(v.ending) and int(v.ending.definition.stage) == 11 and not v.ending.definition.arena and v.ending.phase == "victory"

static func record(profile_data: Dictionary, s: Dictionary) -> void:
	if s.phase != "victory":
		return
	if s.get("schema") == 2 and s.definition.arena:
		var key := str(s.definition.seed) + ":" + str(s.tier)
		var score := {"time": s.time, "hits": s.hits, "rescues": s.deaths}
		if not profile_data.arena_scores.has(key) or s.hits < profile_data.arena_scores[key].hits or s.hits == profile_data.arena_scores[key].hits and s.time < profile_data.arena_scores[key].time:
			profile_data.arena_scores[key] = score
		return
	var stage := int(profile_data.stage)
	if not stage in profile_data.clears:
		profile_data.clears.append(stage)
		profile_data.time += s.time
		profile_data.hits += s.hits
		profile_data.rescues += s.deaths
	var medal := 3 if s.deaths == 0 and s.hits <= (3 if stage == -1 else 12) else (2 if s.deaths <= 1 else 1)
	profile_data.medals[str(stage)] = maxi(medal, int(profile_data.medals.get(str(stage), 0)))
	if stage == 11:
		profile_data.completed = true
