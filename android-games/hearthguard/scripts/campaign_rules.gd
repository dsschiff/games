extends RefCounted
const L = preload("res://scripts/rules.gd")
const Cat = preload("res://scripts/campaign_catalog.gd")

static func profile() -> Dictionary:
	return {"version": 1, "attempts": 0, "wins": 0, "clears": [], "records": {}, "ending": false, "endless_best": {}, "legacy_snapshot": {}, "parked": {}}

static func position(s: Dictionary) -> Vector2:
	return Vector2(s.x, s.z)

static func point(d: Dictionary, e: Dictionary) -> Vector2:
	return Vector2(Cat.road_x(d, int(e.lane), e.z), e.z)

static func pad_point(d: Dictionary, index: int) -> Vector2:
	return Vector2(d.pads[index].x, d.pads[index].z)

static func bootstrap(d: Dictionary) -> Array:
	var coins: Array = []
	for id in 6:
		coins.append({"id": id, "x": 2.8, "z": 4.7 - id * 0.9, "value": int(d.supply) / 6 + (1 if id < int(d.supply) % 6 else 0)})
	return coins

static func fresh(d: Dictionary) -> Dictionary:
	var s := {"schema": 2, "definition": d.duplicate(true), "phase": "ready", "time": 0.0, "x": 2.8, "z": 6.0, "wallet": 0, "integrity": d.integrity, "spawned": 0, "enemies": [], "killed": [], "leaked": [], "coins": bootstrap(d), "collected": [], "towers": [], "ledger": [], "spent": 0, "refunded": 0, "shots": [0, 0, 0], "credited": false}
	for pad in d.pads:
		s.towers.append({"family": -1, "fork": 0, "invested": 0, "cooldown": 0.0, "priority": 0, "jam": 0.0})
	return s

static func nearby(s: Dictionary) -> int:
	var index := -1
	var nearest := 1.65
	for i in s.definition.pads.size():
		var distance := position(s).distance_to(pad_point(s.definition, i))
		if distance < nearest:
			nearest = distance
			index = i
	return index

static func action(s: Dictionary, pad: int, choice: int) -> bool:
	if s.phase != "playing" or pad < 0 or pad >= s.towers.size() or choice < 0 or choice > 2 or position(s).distance_to(pad_point(s.definition, pad)) > 1.65:
		return false
	var t: Dictionary = s.towers[pad]
	if t.family == -1:
		var cost: int = s.definition.families[choice].price
		if s.wallet < cost:
			return false
		t.family = choice
		t.invested = cost
		s.wallet -= cost
		s.spent += cost
		s.ledger.append({"kind": "build", "pad": pad, "choice": choice})
	elif choice == 2:
		var refund := floori(t.invested * 0.7)
		s.wallet += refund
		s.refunded += refund
		s.ledger.append({"kind": "sell", "pad": pad, "choice": choice})
		s.towers[pad] = {"family": -1, "fork": 0, "invested": 0, "cooldown": 0.0, "priority": 0, "jam": 0.0}
	elif t.fork == 0:
		var cost: int = s.definition.families[int(t.family)].upgrades[choice]
		if s.wallet < cost:
			return false
		s.wallet -= cost
		s.spent += cost
		t.invested += cost
		t.fork = choice + 1
		s.ledger.append({"kind": "fork", "pad": pad, "choice": choice})
	else:
		if choice != 0:
			return false
		t.priority = (int(t.priority) + 1) % 3
	return true

static func targets(s: Dictionary, pad: int) -> Array:
	var t: Dictionary = s.towers[pad]
	var stats: Dictionary = s.definition.families[int(t.family)].stats[int(t.fork)]
	var candidates: Array = []
	for e in s.enemies:
		if point(s.definition, e).distance_to(pad_point(s.definition, pad)) <= stats.range:
			candidates.append(e)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if t.priority == 1 and a.hp != b.hp:
			return a.hp > b.hp
		if t.priority == 2 and a.hp != b.hp:
			return a.hp < b.hp
		return a.z > b.z)
	return candidates

static func tick(s: Dictionary, direction: Vector2, delta: float) -> Array:
	var events: Array = []
	if s.phase != "playing":
		return events
	var dt := clampf(delta, 0, 0.05)
	s.time += dt
	var movement := direction.limit_length() * 4.8 * dt
	s.x = clampf(s.x + movement.x, -4.7, 4.7)
	s.z = clampf(s.z + movement.y, -7.5, 6.7)
	for i in range(s.coins.size() - 1, -1, -1):
		var c: Dictionary = s.coins[i]
		if position(s).distance_to(Vector2(c.x, c.z)) <= 1.5:
			s.collected.append(c.id)
			s.wallet += c.value
			s.coins.remove_at(i)
			events.append({"kind": "pickup", "value": c.value})
	while s.spawned < s.definition.roster.size() and s.time >= s.definition.roster[int(s.spawned)].t:
		var e: Dictionary = s.definition.roster[int(s.spawned)]
		s.enemies.append({"id": e.id, "z": -9.0, "hp": float(e.hp), "lane": e.lane, "slow": 0.0, "factor": 1.0, "heal": 0.0})
		s.spawned += 1
	for t in s.towers:
		t.jam = maxf(0, t.jam - dt)
	for e in s.enemies:
		var spec: Dictionary = s.definition.roster[int(e.id)]
		e.slow = maxf(0, e.slow - dt)
		var speed: float = spec.speed * (e.factor if e.slow > 0 else 1.0)
		e.z += dt * speed
		if spec.role == "regent":
			e.lane = int((s.time - spec.t) / 11) % int(s.definition.lanes)
			if fmod(s.time - spec.t, 9) < 1.5:
				for i in s.towers.size():
					if point(s.definition, e).distance_to(pad_point(s.definition, i)) < 3.5:
						s.towers[i].jam = 0.3
		if spec.role in ["mender", "matriarch"]:
			e.heal -= dt
			if e.heal <= 0:
				e.heal = 4.0
				var healed := false
				for ally in s.enemies:
					if ally.id != e.id and point(s.definition, e).distance_to(point(s.definition, ally)) < 3.3:
						healed = healed or ally.hp < s.definition.roster[int(ally.id)].hp
						ally.hp = minf(s.definition.roster[int(ally.id)].hp, ally.hp + (5 if spec.role == "matriarch" else 2))
				if healed:
					events.append({"kind": "heal", "x": point(s.definition, e).x, "z": e.z})
	for pad in s.towers.size():
		var tower: Dictionary = s.towers[pad]
		tower.cooldown = maxf(0, tower.cooldown - dt)
		if tower.family < 0 or tower.cooldown > 0 or tower.jam > 0:
			continue
		var available := targets(s, pad)
		if available.is_empty():
			continue
		var stats: Dictionary = s.definition.families[int(tower.family)].stats[int(tower.fork)]
		tower.cooldown = stats.period
		s.shots[int(tower.family)] += 1
		var center := point(s.definition, available[0])
		var victims: Array = []
		for e in s.enemies:
			if (stats.area > 0 and point(s.definition, e).distance_to(center) <= stats.area) or (stats.area == 0 and available.slice(0, int(stats.chain)).has(e)):
				victims.append(e)
		for e in victims:
			var spec: Dictionary = s.definition.roster[int(e.id)]
			var damage: float = stats.damage
			if tower.family != 2:
				if not stats.pierce:
					damage = maxf(0.35, damage - spec.armor)
				if spec.role == "shade":
					damage *= 0.4
				if spec.role == "ram" and fmod(s.time - spec.t, 8) < 3:
					damage *= 0.4
			e.hp -= damage
			if stats.slow < 1:
				e.slow = 1.5
				e.factor = stats.slow
			if e.hp <= 0:
				s.killed.append(e.id)
				s.coins.append({"id": int(e.id) + 6, "x": point(s.definition, e).x, "z": maxf(-7.5, e.z), "value": spec.reward})
				s.enemies.erase(e)
				events.append({"kind": "kill", "id": e.id})
		events.append({"kind": "shot", "pad": pad, "family": tower.family, "fork": tower.fork, "x": center.x, "z": center.y, "area": stats.area})
	for i in range(s.enemies.size() - 1, -1, -1):
		var e: Dictionary = s.enemies[i]
		if e.z >= 8:
			s.leaked.append(e.id)
			s.integrity = maxi(0, s.integrity - int(s.definition.roster[int(e.id)].leak))
			s.enemies.remove_at(i)
			events.append({"kind": "leak", "id": e.id})
	if s.integrity == 0:
		s.phase = "defeat"
	elif s.spawned == s.definition.roster.size() and s.enemies.is_empty():
		s.phase = "victory"
	return events

static func finish(s: Dictionary, p: Dictionary) -> void:
	if s.credited or not s.phase in ["victory", "defeat"]:
		return
	s.credited = true
	p.attempts += 1
	if s.phase != "victory":
		return
	p.wins += 1
	var d: Dictionary = s.definition
	if d.endless >= 0:
		var key := str(int(d.seed))
		p.endless_best[key] = maxi(p.endless_best.get(key, 0), int(d.endless) + 1)
		return
	if not p.clears.has(int(d.stage)):
		p.clears.append(int(d.stage))
	var previous: Dictionary = p.records.get(d.id, {"leaks": 999, "time": 9999.0, "clears": 0})
	p.records[d.id] = {"leaks": mini(previous.leaks, s.leaked.size()), "time": minf(previous.time, s.time), "clears": int(previous.clears) + 1}
	p.ending = p.clears.size() == 10

static func equivalent(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		if not is_finite(float(a)) or not is_finite(float(b)):
			return false
		return float(a) == float(b) if float(b) == floor(float(b)) else absf(float(a) - float(b)) <= 0.000000000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not equivalent(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not equivalent(a[i], b[i]):
				return false
		return true
	return a == b

static func valid_definition(d: Variant) -> bool:
	if not d is Dictionary or not L.number(d.get("stage"), 0, 9, true) or not L.number(d.get("seed"), 1, 1000000, true) or not L.number(d.get("budget"), -1, 1, true) or not d.get("mirror") is bool or not L.number(d.get("endless"), -1, 1000, true):
		return false
	if d.endless >= 0 and d.stage != 9:
		return false
	return equivalent(d, Cat.definition(int(d.stage), int(d.seed), int(d.budget), d.mirror, int(d.endless)))

static func restore(s: Dictionary) -> Dictionary:
	for key in ["schema", "wallet", "integrity", "spawned", "spent", "refunded"]:
		s[key] = int(s[key])
	for key in ["stage", "catalog", "rules", "generator", "region", "seed", "budget", "endless", "lanes", "duration", "integrity", "supply"]:
		s.definition[key] = int(s.definition[key])
	for e in s.definition.roster:
		for key in ["id", "lane", "hp", "armor", "reward", "leak"]:
			e[key] = int(e[key])
	for key in ["killed", "leaked", "collected", "shots"]:
		for i in s[key].size():
			s[key][i] = int(s[key][i])
	for e in s.enemies:
		e.id = int(e.id)
		e.lane = int(e.lane)
	for c in s.coins:
		c.id = int(c.id)
		c.value = int(c.value)
	for t in s.towers:
		for key in ["family", "fork", "invested", "priority"]:
			t[key] = int(t[key])
	for entry in s.ledger:
		entry.pad = int(entry.pad)
		entry.choice = int(entry.choice)
	return s

static func restore_profile(p: Dictionary) -> Dictionary:
	for key in ["version", "attempts", "wins"]:
		p[key] = int(p[key])
	for i in p.clears.size():
		p.clears[i] = int(p.clears[i])
	for key in p.records:
		p.records[key].leaks = int(p.records[key].leaks)
		p.records[key].clears = int(p.records[key].clears)
	for key in p.endless_best:
		p.endless_best[key] = int(p.endless_best[key])
	if not p.parked.is_empty():
		p.parked = restore(p.parked)
	return p

static func valid_profile(p: Variant) -> bool:
	if not p is Dictionary or p.get("version") != 1 or not L.number(p.get("attempts"), 0, 1000000, true) or not L.number(p.get("wins"), 0, p.attempts, true) or not L.ids(p.get("clears"), 0, 9) or not p.get("records") is Dictionary or not p.get("endless_best") is Dictionary or not p.get("ending") is bool or not p.get("legacy_snapshot") is Dictionary:
		return false
	for i in p.clears.size():
		if p.clears[i] != i:
			return false
	if p.ending != (p.clears.size() == 10) or p.wins < p.clears.size() or p.records.size() != p.clears.size() or p.endless_best.size() > 1000:
		return false
	var credited_wins := 0
	for i in p.clears:
		var r: Variant = p.records.get("pass%02d" % (i + 1))
		if not r is Dictionary or not L.number(r.get("leaks"), 0, 15, true) or not L.number(r.get("time"), 0, 1000) or not L.number(r.get("clears"), 1, p.wins, true):
			return false
		credited_wins += int(r.clears)
	for k in p.endless_best:
		if not k is String or not k.is_valid_int() or str(int(k)) != k or not L.number(int(k), 1, 1000000, true) or not L.number(p.endless_best[k], 1, 1001, true) or not p.ending:
			return false
		credited_wins += int(p.endless_best[k])
	if credited_wins > p.wins:
		return false
	if not p.legacy_snapshot.is_empty() and not L.valid(p.legacy_snapshot):
		return false
	if not p.get("parked") is Dictionary or not p.parked.is_empty() and (not valid(p.parked) or p.parked.definition.stage > p.clears.size() or p.parked.definition.endless >= 0 and not p.ending):
		return false
	if not p.parked.is_empty() and p.parked.definition.endless >= 0 and p.parked.definition.endless > p.endless_best.get(str(int(p.parked.definition.seed)), 0):
		return false
	if not p.parked.is_empty() and not credited_profile_matches(p.parked, p):
		return false
	return true

static func credited_profile_matches(s: Dictionary, p: Dictionary) -> bool:
	if not s.credited:
		return true
	if p.attempts < 1:
		return false
	if s.phase != "victory":
		return true
	var d: Dictionary = s.definition
	if p.wins < 1:
		return false
	if d.endless >= 0:
		return p.endless_best.get(str(int(d.seed)), 0) >= d.endless + 1
	var record: Variant = p.records.get(d.id)
	return p.clears.has(d.stage) and record is Dictionary and record.leaks <= s.leaked.size() and record.time <= s.time + 0.000000000001

static func valid(s: Variant) -> bool:
	if not s is Dictionary or s.get("schema") != 2 or not valid_definition(s.get("definition")) or not s.get("phase") in ["ready", "playing", "victory", "defeat"] or not s.get("credited") is bool:
		return false
	var d: Dictionary = s.definition
	for spec in [["time", 0, 1000, false], ["x", -4.7, 4.7, false], ["z", -7.5, 6.7, false], ["wallet", 0, 100000, true], ["integrity", 0, d.integrity, true], ["spawned", 0, d.roster.size(), true], ["spent", 0, 100000, true], ["refunded", 0, 100000, true]]:
		if not L.number(s.get(spec[0]), spec[1], spec[2], spec[3]):
			return false
	if not L.ids(s.get("killed"), 0, d.roster.size() - 1) or not L.ids(s.get("leaked"), 0, d.roster.size() - 1) or not L.ids(s.get("collected"), 0, d.roster.size() + 5) or not s.get("enemies") is Array or not s.get("coins") is Array or not s.get("towers") is Array or s.towers.size() != d.pads.size() or not s.get("ledger") is Array or s.ledger.size() > 2000 or not s.get("shots") is Array or s.shots.size() != 3:
		return false
	for shots in s.shots:
		if not L.number(shots, 0, 100000, true):
			return false
	var towers: Array = []
	for pad in d.pads:
		towers.append({"family": -1, "fork": 0, "invested": 0})
	var spent := 0
	var refunds := 0
	for entry in s.ledger:
		if not entry is Dictionary or not L.number(entry.get("pad"), 0, towers.size() - 1, true) or not L.number(entry.get("choice"), 0, 2, true):
			return false
		var t: Dictionary = towers[int(entry.pad)]
		if entry.get("kind") == "build" and t.family == -1:
			t.family = int(entry.choice)
			t.invested = d.families[int(entry.choice)].price
			spent += t.invested
		elif entry.get("kind") == "fork" and t.family >= 0 and t.fork == 0 and entry.choice < 2:
			var price: int = d.families[int(t.family)].upgrades[int(entry.choice)]
			t.fork = int(entry.choice) + 1
			t.invested += price
			spent += price
		elif entry.get("kind") == "sell" and t.family >= 0:
			refunds += floori(t.invested * 0.7)
			t.family = -1
			t.fork = 0
			t.invested = 0
		else:
			return false
	if spent != s.spent or refunds != s.refunded:
		return false
	for i in towers.size():
		var t: Variant = s.towers[i]
		if not t is Dictionary or not L.number(t.get("family"), -1, 2, true) or not L.number(t.get("fork"), 0, 2, true) or not L.number(t.get("invested"), 0, 1000, true) or not L.number(t.get("cooldown"), 0, 1.8) or not L.number(t.get("jam"), 0, 0.3) or not L.number(t.get("priority"), 0, 2, true):
			return false
		for field in ["family", "fork", "invested"]:
			if t[field] != towers[i][field]:
				return false
		if t.family == -1 and (t.cooldown != 0 or t.priority != 0):
			return false
	var resolved := {}
	var damage := 0
	for id in s.killed + s.leaked:
		if id >= s.spawned or resolved.has(int(id)):
			return false
		resolved[int(id)] = true
	for id in s.leaked:
		damage += d.roster[int(id)].leak
	if s.integrity != maxi(0, int(d.integrity) - damage):
		return false
	for e in s.enemies:
		if not e is Dictionary or not L.number(e.get("id"), 0, s.spawned - 1, true) or resolved.has(int(e.id)) or not L.number(e.get("z"), -9, 8.1) or not L.number(e.get("hp"), 0, d.roster[int(e.id)].hp) or e.hp <= 0 or not L.number(e.get("lane"), 0, d.lanes - 1, true) or not L.number(e.get("slow"), 0, 1.5) or not L.number(e.get("factor"), 0.28, 1) or not L.number(e.get("heal"), 0, 4):
			return false
		resolved[int(e.id)] = true
	if resolved.size() != s.spawned:
		return false
	# Check the saved partition from both sides. Rounding near a spawn time
	# must not demand a future spawn or reject a just-spawned actor.
	for i in d.roster.size():
		var birth: float = d.roster[i].t
		if i < s.spawned and birth > s.time + 0.000000000001:
			return false
		if i >= s.spawned and birth < s.time - 0.000000000001:
			return false
	var coin_ids := {}
	var earned := 0
	var supply := bootstrap(d)
	for id in s.collected:
		if id >= 6 and not s.killed.has(id - 6):
			return false
		coin_ids[int(id)] = true
		earned += supply[int(id)].value if id < 6 else d.roster[int(id) - 6].reward
	for c in s.coins:
		if not c is Dictionary or not L.number(c.get("id"), 0, d.roster.size() + 5, true) or coin_ids.has(int(c.id)) or not L.number(c.get("x"), -4.7, 4.7) or not L.number(c.get("z"), -9, 8.1):
			return false
		if c.id < 6:
			if not equivalent(c, supply[int(c.id)]):
				return false
		elif not s.killed.has(c.id - 6) or c.get("value") != d.roster[int(c.id) - 6].reward or c.z < -7.5:
			return false
		coin_ids[int(c.id)] = true
	if coin_ids.size() != 6 + s.killed.size() or s.wallet + s.spent - s.refunded != earned:
		return false
	if s.phase == "ready" and (s.time != 0 or s.spawned != 0 or not s.ledger.is_empty() or not s.collected.is_empty()):
		return false
	if s.phase == "victory" and (s.spawned != d.roster.size() or not s.enemies.is_empty() or s.integrity <= 0):
		return false
	if s.phase != "victory" and s.integrity > 0 and s.spawned == d.roster.size() and s.enemies.is_empty():
		return false
	if (s.phase == "defeat") != (s.integrity == 0) or s.credited != (s.phase in ["victory", "defeat"]):
		return false
	return true
