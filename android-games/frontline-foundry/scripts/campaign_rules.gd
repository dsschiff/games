extends RefCounted
const D = preload("res://scripts/definitions.gd")
const L = preload("res://scripts/rules.gd")

static func career() -> Dictionary:
	return {"version": 1, "attempts": 0, "victories": 0, "clears": {}, "records": {}, "skirmishes": {}, "ending": false, "legacy_state": {}, "legacy_profile": {}}

static func fresh(definition: Dictionary) -> Dictionary:
	var recruits: Array = []
	for role_index in 4:
		for ordinal in 3:
			var role: String = D.ROLES[role_index]
			var pad := D.pad(definition, role_index)
			recruits.append({"id": role_index * 3 + ordinal, "role": role, "phase": "waiting", "x": pad.x, "z": pad.y + 0.5 + ordinal * 0.3, "hp": definition.unit[role].hp, "clock": 0.0, "cooldown": 0.0, "slot": -1, "waypoint": 0, "shots": 0, "damage": 0.0, "taken": 0.0, "healed": 0.0})
	var coins: Array = []
	for i in definition.caches.size():
		coins.append({"id": 200 + i, "x": definition.caches[i][0], "z": definition.caches[i][1], "value": definition.caches[i][2]})
	var captures: Array = []
	for point in definition.relays:
		captures.append(0.0)
	return {"catalog": 2, "definition": definition.duplicate(true), "definition_hash": D.signature(definition), "phase": "ready", "time": 0.0, "x": 0.0, "z": 1.5, "hp": definition.commander_hp, "hq": definition.hq, "wallet": definition.funds, "spent": 0, "bought": [0, 0, 0, 0], "stock": [0, 0, 0, 0], "consumed": [0, 0, 0, 0], "recruits": recruits, "purchases": [], "planned_support": "ward", "support": "none", "support_used": 0.0, "prevented": 0.0, "spawned": 0, "enemies": [], "killed": [], "escaped": [], "coins": coins, "collected": [], "captures": captures, "marks": [], "commander_cd": 0.0, "sentry_cd": 0.0, "commander_shots": 0, "commander_damage": 0.0, "commander_taken": 0.0, "commander_healed": 0.0, "hq_taken": 0.0, "last_hurt": "", "cause": "", "recorded": false}

static func position(s: Dictionary) -> Vector2:
	return Vector2(s.x, s.z)

static func nearby(s: Dictionary) -> int:
	for i in 5:
		if position(s).distance_to(D.pad(s.definition, i)) < 1.1:
			return i
	return -1

static func active_count(s: Dictionary) -> int:
	var count := 0
	for r in s.recruits:
		if r.phase in ["equipping", "deploying", "fighting"]:
			count += 1
	return count

static func can_buy(s: Dictionary, index: int) -> bool:
	if s.phase != "playing" or index < 0 or index > 4 or nearby(s) != index or s.hp <= 0 or s.hq <= 0:
		return false
	if index == 4:
		return s.support == "none" and s.wallet >= s.definition.support_cost
	var role: String = D.ROLES[index]
	return role in s.definition.available and s.wallet >= s.definition.unit[role].cost and s.bought[index] < s.definition.pool[index] and active_count(s) + s.stock.reduce(func(a, b): return a + b, 0) < s.definition.cap

static func buy(s: Dictionary, index: int) -> bool:
	if not can_buy(s, index):
		return false
	var cost: int = s.definition.support_cost if index == 4 else s.definition.unit[D.ROLES[index]].cost
	s.wallet -= cost
	s.spent += cost
	s.purchases.append({"id": s.purchases.size(), "station": index, "cost": cost, "at": s.time, "support": s.planned_support if index == 4 else "none"})
	if index == 4:
		s.support = s.planned_support
	else:
		s.bought[index] += 1
		s.stock[index] += 1
	return true

static func pick_target(s: Dictionary, p: Vector2, reach: float, role: String) -> int:
	var selected := -1
	var best := INF
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		if e.hp <= 0:
			continue
		var distance := p.distance_to(Vector2(e.x, e.z))
		if distance > reach:
			continue
		var score := distance
		if role == "ranger" and e.role in ["mortar", "jammer", "storm"]:
			score -= 20
		if role == "breaker" and s.definition.enemy[e.role].armor:
			score -= 15
		if role == "rover" and e.role in ["runner", "sapper", "drone"]:
			score -= 10
		if score < best:
			best = score
			selected = i
	return selected

static func hit(s: Dictionary, e: Dictionary, source: Vector2, damage: float, owner: String, events: Array, actor: String = "") -> float:
	if e.hp <= 0:
		return 0
	var armor: bool = s.definition.enemy[e.role].armor
	var factor := 0.34 if owner in ["commander", "sentry"] else float(s.definition.unit[owner].armor)
	if e.role == "drill" and e.telegraph > 0:
		armor = false
	var adjusted := damage * (factor if armor else 1.0)
	if owner != "breaker" and e.role != "bulwark":
		for guard in s.enemies:
			if guard.role == "bulwark" and guard.hp > 0 and Vector2(guard.x, guard.z).distance_to(Vector2(e.x, e.z)) < 2.4:
				adjusted *= 0.5
				break
	var dealt := minf(e.hp, adjusted)
	e.hp -= dealt
	events.append({"kind": "shot", "owner": owner, "from": [source.x, source.y], "to": [e.x, e.z], "enemy": e.id, "damage": dealt, "actor": actor, "effect": "projectile", "attack": "%s:projectile:%.9f" % [actor, s.time]})
	return dealt

static func hurt(s: Dictionary, r: Dictionary, damage: float, source: Vector2, role: String, events: Array, actor: String = "", effect: String = "projectile") -> void:
	if r.is_empty():
		if s.hp <= 0:
			return
	else:
		if r.hp <= 0 or r.phase not in ["deploying", "fighting"]:
			return
	var reduced: float = damage * (s.definition.support_effects.ward_factor if s.support == "ward" else 1.0)
	s.prevented += damage - reduced
	var p: Vector2 = position(s) if r.is_empty() else Vector2(r.x, r.z)
	var actual := minf(s.hp if r.is_empty() else r.hp, reduced)
	if r.is_empty():
		s.hp -= actual
		s.commander_taken += actual
	else:
		r.hp -= actual
		r.taken += actual
		if r.hp <= 0:
			r.phase = "fallen"
			r.slot = -1
	s.last_hurt = role
	events.append({"kind": "incoming", "owner": "enemy", "from": [source.x, source.y], "to": [p.x, p.y], "recipient": -1 if r.is_empty() else int(r.id), "damage": actual, "actor": actor, "effect": effect, "attack": "%s:%s:%.9f" % [actor, effect, s.time]})

static func hurt_hq(s: Dictionary, damage: float, source: Vector2, role: String, events: Array, actor: String = "", effect: String = "projectile") -> void:
	var reduced: float = damage * (s.definition.support_effects.ward_factor if s.support == "ward" else 1.0)
	s.prevented += damage - reduced
	var actual := minf(s.hq, reduced)
	s.hq -= actual
	s.hq_taken += actual
	s.last_hurt = role
	events.append({"kind": "incoming", "owner": "enemy", "from": [source.x, source.y], "to": [0, 5.4], "recipient": -2, "damage": actual, "actor": actor, "effect": effect, "attack": "%s:%s:%.9f" % [actor, effect, s.time]})

static func tick(s: Dictionary, movement: Vector2, delta: float) -> Array:
	var events: Array = []
	var remaining := clampf(delta, 0, 0.25)
	while remaining > 0.00001 and s.phase == "playing":
		var dt := minf(0.05, remaining)
		step(s, movement, dt, events)
		remaining -= dt
	return events

static func step(s: Dictionary, movement: Vector2, dt: float, events: Array) -> void:
	var d: Dictionary = s.definition
	s.time += dt
	var p: Vector2 = position(s) + movement.limit_length() * d.command_speed * dt
	s.x = clampf(p.x, -4.7, 4.7)
	s.z = clampf(p.y, -6.2, 5.9)
	p = position(s)
	while s.spawned < d.schedule.size() and s.time >= d.schedule[int(s.spawned)].at:
		var spec: Dictionary = d.schedule[int(s.spawned)]
		s.enemies.append({"id": spec.id, "role": spec.role, "x": spec.x, "z": spec.z, "hp": d.enemy[spec.role].hp, "cooldown": 0.8, "telegraph": 0.0, "boss_clock": 3.0, "heal_left": 160.0 if spec.role == "carrier" else 0.0})
		s.spawned += 1
	for r in s.recruits:
		var ri: int = D.ROLES.find(r.role)
		var unit: Dictionary = d.unit[r.role]
		if r.phase == "waiting" and s.stock[ri] > 0 and active_count(s) < d.cap:
			var busy := false
			var occupied: Array = []
			for other in s.recruits:
				if other.role == r.role and other.phase == "equipping":
					busy = true
				if other.phase in ["equipping", "deploying", "fighting"]:
					occupied.append(int(other.slot))
			if not busy:
				for slot in int(d.cap):
					if slot not in occupied:
						r.slot = slot
						break
				s.stock[ri] -= 1
				s.consumed[ri] += 1
				r.phase = "equipping"
				r.clock = d.arm_seconds
				events.append({"kind": "equip", "id": r.id, "role": r.role})
		elif r.phase == "equipping":
			r.clock = maxf(0, r.clock - dt)
			if r.clock == 0:
				r.phase = "deploying"
		elif r.phase == "deploying":
			var destination: Vector2 = [Vector2(d.layout.gate[0][0], d.layout.gate[0][1]), Vector2(d.layout.gate[1][0], d.layout.gate[1][1]), D.formation(d, int(r.slot))][int(r.waypoint)]
			var q := Vector2(r.x, r.z).move_toward(destination, dt * unit.speed)
			r.x = q.x
			r.z = q.y
			if q.distance_to(destination) < 0.01:
				if r.waypoint < 2:
					r.waypoint += 1
				else:
					r.phase = "fighting"
		elif r.phase == "fighting":
			r.cooldown = maxf(0, r.cooldown - dt)
			var rp := Vector2(r.x, r.z)
			var jammed := false
			for e in s.enemies:
				if e.role == "jammer" and e.hp > 0 and rp.distance_to(Vector2(e.x, e.z)) < 4.7:
					jammed = true
			var target := pick_target(s, rp, unit.range + (d.support_effects.relay_unit_range if s.support == "relay" else 0), r.role)
			if target >= 0 and r.cooldown == 0 and not jammed:
				var e: Dictionary = s.enemies[target]
				r.damage += hit(s, e, rp, unit.damage, r.role, events, "recruit:" + str(int(r.id)))
				if r.role == "rover":
					var blast := Vector2(e.x, e.z)
					for other in s.enemies:
						if other.id != e.id and blast.distance_to(Vector2(other.x, other.z)) <= 2.2:
							r.damage += hit(s, other, rp, unit.damage * 0.65, r.role, events, "recruit:" + str(int(r.id)))
				r.shots += 1
				r.cooldown = unit.interval
	s.commander_cd = maxf(0, s.commander_cd - dt)
	var target := pick_target(s, p, d.command_range + (d.support_effects.relay_command_range if s.support == "relay" else 0), "commander")
	if target >= 0 and s.commander_cd == 0 and s.hp > 0:
		s.commander_damage += hit(s, s.enemies[target], p, d.command_damage * (d.support_effects.relay_damage_factor if s.support == "relay" else 1), "commander", events, "commander")
		s.commander_shots += 1
		s.commander_cd = d.command_interval
	s.sentry_cd = maxf(0, s.sentry_cd - dt)
	target = pick_target(s, Vector2(0, 0.6), d.sentry.range, "sentry")
	if target >= 0 and s.sentry_cd == 0:
		hit(s, s.enemies[target], Vector2(0, 0.6), d.sentry.damage, "sentry", events, "sentry")
		s.sentry_cd = d.sentry.interval
	# Ground strikes resolve before repair, pickups or success, and cannot revive casualties.
	for i in range(s.marks.size() - 1, -1, -1):
		var mark: Dictionary = s.marks[i]
		mark.remaining -= dt
		if mark.remaining <= 0:
			var blast := Vector2(mark.x, mark.z)
			if p.distance_to(blast) < 1.25:
				hurt(s, {}, 32, blast, "storm", events, "enemy:" + str(int(mark.source)), "ground")
			for r in s.recruits:
				if Vector2(r.x, r.z).distance_to(blast) < 1.25:
					hurt(s, r, 32, blast, "storm", events, "enemy:" + str(int(mark.source)), "ground")
			s.marks.remove_at(i)
	for e in s.enemies:
		if e.hp <= 0:
			continue
		var spec: Dictionary = d.enemy[e.role]
		var ep := Vector2(e.x, e.z)
		e.cooldown = maxf(0, e.cooldown - dt)
		e.boss_clock = maxf(0, e.boss_clock - dt)
		if e.role == "storm" and e.boss_clock == 0:
			s.marks.append({"x": p.x, "z": p.y, "remaining": 1.0, "source": e.id})
			e.boss_clock = 2.7
			events.append({"kind": "warning", "owner": "enemy", "from": [e.x, e.z], "to": [p.x, p.y], "actor": "enemy:" + str(int(e.id)), "effect": "ground_warning", "attack": "enemy:%d:warning:%.9f" % [e.id, s.time]})
		if e.role == "carrier" and e.boss_clock == 0 and e.heal_left > 0:
			for other in s.enemies:
				if other.hp > 0 and other.id != e.id and ep.distance_to(Vector2(other.x, other.z)) < 4:
					var healed := minf(20, minf(e.heal_left, d.enemy[other.role].hp - other.hp))
					other.hp += healed
					e.heal_left -= healed
					if healed > 0:
						events.append({"kind": "repair", "owner": "carrier", "from": [e.x, e.z], "to": [other.x, other.z], "healed": healed, "actor": "enemy:" + str(int(e.id)), "enemy": other.id, "effect": "repair", "attack": "enemy:%d:repair:%.9f" % [e.id, s.time]})
			e.boss_clock = 4.0
		if e.role == "drill":
			if e.telegraph > 0:
				e.telegraph = maxf(0, e.telegraph - dt)
				if e.telegraph == 0:
					e.z += 1.8
					if p.distance_to(Vector2(e.x, e.z)) < 2:
						hurt(s, {}, 30, ep, "drill", events, "enemy:" + str(int(e.id)), "contact")
					for r in s.recruits:
						if Vector2(r.x, r.z).distance_to(Vector2(e.x, e.z)) < 2:
							hurt(s, r, 30, ep, "drill", events, "enemy:" + str(int(e.id)), "contact")
			elif e.boss_clock == 0:
				e.telegraph = 1.2
				e.boss_clock = 7.0
				events.append({"kind": "warning", "owner": "enemy", "from": [e.x, e.z], "to": [e.x, e.z + 1.8], "actor": "enemy:" + str(int(e.id)), "effect": "charge_warning", "attack": "enemy:%d:charge:%.9f" % [e.id, s.time]})
		var victim: Dictionary = {}
		var nearest: float = spec.range
		if e.role not in ["runner", "mortar", "sapper", "storm"]:
			for r in s.recruits:
				var distance := ep.distance_to(Vector2(r.x, r.z))
				if r.phase in ["deploying", "fighting"] and distance < nearest:
					nearest = distance
					victim = r
		var commander_near: bool = ep.distance_to(p) < minf(nearest, spec.range) and e.role not in ["runner", "mortar", "storm"]
		if e.role in ["mortar", "storm"] and e.z >= -6.75:
			if e.cooldown == 0:
				hurt_hq(s, spec.damage, ep, e.role, events, "enemy:" + str(int(e.id)))
				if e.role == "mortar":
					var victims := 0
					for r in s.recruits:
						if r.phase in ["deploying", "fighting"] and victims < 2:
							hurt(s, r, 20, ep, "mortar", events, "enemy:" + str(int(e.id)))
							victims += 1
				e.cooldown = spec.interval
		elif e.role == "sapper" and e.z >= -0.5:
			hurt_hq(s, spec.damage, ep, e.role, events, "enemy:" + str(int(e.id)), "blast")
			for r in s.recruits:
				if ep.distance_to(Vector2(r.x, r.z)) < 3:
					hurt(s, r, 22, ep, e.role, events, "enemy:" + str(int(e.id)), "blast")
			e.z = 2.2
		elif commander_near or not victim.is_empty():
			if e.cooldown == 0:
				hurt(s, {} if commander_near else victim, spec.damage, ep, e.role, events, "enemy:" + str(int(e.id)))
				e.cooldown = spec.interval
		else:
			if e.telegraph == 0:
				e.z += spec.speed * dt
	for i in range(s.enemies.size() - 1, -1, -1):
		var e: Dictionary = s.enemies[i]
		if e.hp <= 0:
			s.killed.append(e.id)
			s.coins.append({"id": e.id, "x": e.x, "z": e.z, "value": d.enemy[e.role].reward})
			s.enemies.remove_at(i)
		elif e.z >= 2.0:
			s.escaped.append(e.id)
			hurt_hq(s, d.enemy[e.role].leak, Vector2(e.x, e.z), e.role, events, "enemy:" + str(int(e.id)), "breach")
			s.enemies.remove_at(i)
	if s.hp > 0 and s.hq > 0:
		for i in d.relays.size():
			var point := Vector2(d.relays[i][0], d.relays[i][1])
			if s.captures[i] < d.capture_seconds and p.distance_to(point) < 0.95:
				s.captures[i] = minf(d.capture_seconds, s.captures[i] + dt * (d.support_effects.relay_capture_factor if s.support == "relay" else 1))
				if s.captures[i] == d.capture_seconds:
					s.coins.append({"id": 100 + i, "x": point.x, "z": point.y, "value": 8})
		for i in range(s.coins.size() - 1, -1, -1):
			var c: Dictionary = s.coins[i]
			if p.distance_to(Vector2(c.x, c.z)) < d.pickup_radius:
				s.wallet += c.value
				s.collected.append(c.id)
				s.coins.remove_at(i)
				events.append({"kind": "pickup", "id": c.id})
		if s.support == "recovery" and s.support_used < d.support_effects.repair_budget:
			var heal := minf(dt * d.support_effects.repair_commander_rate, minf(d.support_effects.repair_budget - s.support_used, d.commander_hp - s.hp))
			s.hp += heal
			s.commander_healed += heal
			s.support_used += heal
			for r in s.recruits:
				if r.hp > 0 and r.phase in ["deploying", "fighting"]:
					heal = minf(dt * d.support_effects.repair_unit_rate, minf(d.support_effects.repair_budget - s.support_used, d.unit[r.role].hp - r.hp))
					r.hp += heal
					r.healed += heal
					s.support_used += heal
	if s.hp <= 0 or s.hq <= 0:
		s.phase = "defeat"
		s.cause = "Commander lost to " + s.last_hurt if s.hp <= 0 else "HQ breached by " + s.last_hurt
	elif s.killed.size() + s.escaped.size() == d.schedule.size() and s.marks.is_empty():
		var objective := objective_met(s)
		s.phase = "victory" if s.killed.size() >= d.minimum and objective else "defeat"
		s.cause = "Foundry liberated" if d.id == "foundry_liberation" and s.phase == "victory" else ("Objective secured" if s.phase == "victory" else "Objective incomplete: " + objective_text(s))

static func objective_met(s: Dictionary) -> bool:
	var d: Dictionary = s.definition
	if d.objective in ["relay", "liberate"] and s.captures.any(func(v): return v < d.capture_seconds):
		return false
	if d.objective == "salvage":
		for i in d.caches.size():
			if 200 + i not in s.collected.map(func(v): return int(v)):
				return false
	for e in d.schedule:
		if (d.objective == "silence" and e.role == "mortar") or e.role in ["drill", "carrier", "storm"]:
			if int(e.id) not in s.killed.map(func(v): return int(v)):
				return false
	return true

static func objective_text(s: Dictionary) -> String:
	match s.definition.objective:
		"relay", "liberate": return "capture both relays" + (" and destroy the Storm Engine" if s.definition.objective == "liberate" else "")
		"salvage": return "collect all three field caches"
		"silence": return "kill every mortar crew"
		"boss": return "destroy the siege boss"
	return "stop at least %d of %d" % [s.definition.minimum, s.definition.schedule.size()]

static func finish(s: Dictionary, c: Dictionary) -> void:
	if s.phase not in ["victory", "defeat"] or s.recorded:
		return
	s.recorded = true
	c.attempts += 1
	if s.phase != "victory":
		return
	c.victories += 1
	var medal := 3 if s.escaped.is_empty() and s.hp >= s.definition.commander_hp * 0.6 else (2 if s.hq >= s.definition.hq * 0.5 else 1)
	var record := {"medal": medal, "seconds": s.time, "kills": s.killed.size(), "spent": s.spent, "seed": s.definition.seed, "style": s.definition.style}
	if s.definition.mode == "campaign":
		var id: String = s.definition.id
		c.clears[id] = maxi(int(c.clears.get(id, 0)), medal)
		if not c.records.has(id) or record.medal > c.records[id].medal or (record.medal == c.records[id].medal and record.seconds < c.records[id].seconds):
			c.records[id] = record
		c.ending = c.clears.size() == 12
	else:
		var key: String = str(int(s.definition.seed)) + ":" + s.definition.style
		c.skirmishes[key] = record
		while c.skirmishes.size() > 8:
			c.skirmishes.erase(c.skirmishes.keys()[0])

static func valid_career(c: Variant) -> bool:
	if not c is Dictionary or c.get("version") != 1 or not L.number(c.get("attempts"), 0, 1000000, true) or not L.number(c.get("victories"), 0, c.attempts, true) or not c.get("clears") is Dictionary or not c.get("records") is Dictionary or not c.get("skirmishes") is Dictionary or not c.get("ending") is bool or not c.get("legacy_state") is Dictionary or not c.get("legacy_profile") is Dictionary:
		return false
	if c.clears.size() > 12 or c.victories < c.clears.size() or c.records.size() != c.clears.size() or c.skirmishes.size() > 8 or c.ending != (c.clears.size() == 12):
		return false
	for i in c.clears.size():
		var id: String = D.IDS[i]
		if not L.number(c.clears.get(id), 1, 3, true) or not valid_record(c.records.get(id)) or c.records[id].medal > c.clears[id]:
			return false
	for key in c.skirmishes:
		if not key is String or not valid_record(c.skirmishes[key]) or key != str(int(c.skirmishes[key].seed)) + ":" + c.skirmishes[key].style or c.skirmishes[key].style not in ["mixed", "flank", "siege"]:
			return false
	if c.legacy_state.is_empty() != c.legacy_profile.is_empty():
		return false
	return c.legacy_state.is_empty() or (L.valid(c.legacy_state) and L.valid_profile(c.legacy_profile))

static func valid_record(r: Variant) -> bool:
	return r is Dictionary and L.number(r.get("medal"), 1, 3, true) and L.number(r.get("seconds"), 0, 10000) and L.number(r.get("kills"), 0, 40, true) and L.number(r.get("spent"), 0, 1000, true) and L.number(r.get("seed"), 0, 999999, true) and r.get("style") in ["authored", "mixed", "flank", "siege"]

static func valid(s: Variant) -> bool:
	if not s is Dictionary or s.get("catalog") != 2 or not D.valid(s.get("definition")) or s.get("definition_hash") != D.signature(s.definition) or s.get("phase") not in ["ready", "playing", "victory", "defeat"] or not s.get("recorded") is bool or not s.get("cause") is String or not s.get("last_hurt") is String or s.get("planned_support") not in D.SUPPORT or s.get("support") not in ["none", "ward", "relay", "recovery"]:
		return false
	var d: Dictionary = s.definition
	for key in ["time", "hp", "hq", "wallet", "spent", "spawned", "commander_cd", "sentry_cd", "commander_shots", "commander_damage", "commander_taken", "commander_healed", "hq_taken", "support_used", "prevented"]:
		if not L.number(s.get(key), 0, 100000):
			return false
	if not L.number(s.get("x"), -4.7, 4.7) or not L.number(s.get("z"), -6.2, 5.9) or s.hp > d.commander_hp or s.hq > d.hq or s.support_used > 200.0001 or absf(s.hp - (d.commander_hp - s.commander_taken + s.commander_healed)) > 0.001 or absf(s.hq - (d.hq - s.hq_taken)) > 0.001:
		return false
	for key in ["bought", "stock", "consumed"]:
		if not s.get(key) is Array or s[key].size() != 4:
			return false
		for i in 4:
			if not L.number(s[key][i], 0, d.pool[i], true):
				return false
	for key in ["enemies", "recruits", "killed", "escaped", "coins", "collected", "purchases", "captures", "marks"]:
		if not s.get(key) is Array:
			return false
	if s.recruits.size() != 12 or s.purchases.size() > 13 or s.captures.size() != d.relays.size() or s.marks.size() > 2 or not L.number(s.spawned, 0, d.schedule.size(), true) or not L.number(s.wallet, 0, 1000, true) or not L.number(s.spent, 0, 1000, true):
		return false
	var consumed := [0, 0, 0, 0]
	var equipping := [0, 0, 0, 0]
	var slots: Array = []
	var healed: float = s.commander_healed
	for i in 12:
		var r: Variant = s.recruits[i]
		var role: String = D.ROLES[int(i / 3)]
		if not r is Dictionary or r.get("id") != i or r.get("role") != role or r.get("phase") not in ["waiting", "equipping", "deploying", "fighting", "fallen"] or not L.number(r.get("hp"), 0, d.unit[role].hp) or not L.number(r.get("x"), -4.7, 4.7) or not L.number(r.get("z"), -6.2, 5.9) or not L.number(r.get("clock"), 0, 0.6) or not L.number(r.get("cooldown"), 0, d.unit[role].interval) or not L.number(r.get("slot"), -1, 5, true) or not L.number(r.get("waypoint"), 0, 2, true):
			return false
		for key in ["shots", "damage", "taken", "healed"]:
			if not L.number(r.get(key), 0, 100000):
				return false
		if absf(r.hp - (d.unit[role].hp - r.taken + r.healed)) > 0.001 or ((r.phase == "fallen") != (r.hp == 0)):
			return false
		healed += r.healed
		if r.phase in ["waiting", "fallen"]:
			if r.slot != -1:
				return false
		else:
			slots.append(r.slot)
		if r.phase != "waiting":
			consumed[int(i / 3)] += 1
			if r.phase == "equipping":
				equipping[int(i / 3)] += 1
		elif r.shots != 0 or r.damage != 0 or r.taken != 0 or r.healed != 0:
			return false
	if not L.unique_ids(slots, 0, 5) or slots.size() + s.stock.reduce(func(a, b): return a + b, 0) > d.cap or absf(healed - s.support_used) > 0.001 or (s.support != "recovery" and s.support_used != 0):
		return false
	var bought := [0, 0, 0, 0]
	var costs := 0
	var support := "none"
	for i in s.purchases.size():
		var entry: Variant = s.purchases[i]
		if not entry is Dictionary or entry.get("id") != i or not L.number(entry.get("station"), 0, 4, true) or not L.number(entry.get("at"), 0, s.time):
			return false
		var station := int(entry.station)
		var price: int = d.support_cost if station == 4 else d.unit[D.ROLES[station]].cost
		if entry.get("cost") != price:
			return false
		costs += price
		if station < 4:
			if D.ROLES[station] not in d.available or entry.get("support") != "none":
				return false
			bought[station] += 1
		else:
			if support != "none" or entry.get("support") not in D.SUPPORT:
				return false
			support = entry.support
	if support != s.support or costs != s.spent or (support != "none" and support != s.planned_support):
		return false
	for i in 4:
		if s.bought[i] != bought[i] or s.consumed[i] != consumed[i] or s.bought[i] != s.stock[i] + s.consumed[i]:
			return false
		if equipping[i] > 1:
			return false
		for ordinal in 3:
			if (s.recruits[i * 3 + ordinal].phase != "waiting") != (ordinal < s.consumed[i]):
				return false
	var enemy_ids: Array = []
	for e in s.enemies:
		if not e is Dictionary or not L.number(e.get("id"), 0, s.spawned - 1, true):
			return false
		var spec: Dictionary = d.schedule[int(e.id)]
		if e.get("role") != spec.role or not L.number(e.get("hp"), 0, d.enemy[spec.role].hp) or e.hp <= 0 or not L.number(e.get("x"), -4.7, 4.7) or not L.number(e.get("z"), -6.75, 2.1) or not L.number(e.get("cooldown"), 0, 4) or not L.number(e.get("telegraph"), 0, 1.2) or not L.number(e.get("boss_clock"), 0, 7) or not L.number(e.get("heal_left"), 0, 160):
			return false
		enemy_ids.append(e.id)
	var partition: Array = s.killed + s.escaped + enemy_ids
	if not L.unique_ids(partition, 0, s.spawned - 1) or partition.size() != s.spawned:
		return false
	var arrived_min := 0
	var arrived_max := 0
	for spec in d.schedule:
		if spec.at < s.time - 0.000001:
			arrived_min += 1
		if spec.at <= s.time + 0.000001:
			arrived_max += 1
	# Float serialization can straddle an exact scheduled arrival by sub-microseconds.
	if s.spawned < arrived_min or s.spawned > arrived_max:
		return false
	var expected: Array = s.killed.duplicate()
	for i in d.caches.size():
		expected.append(200 + i)
	for i in s.captures.size():
		if not L.number(s.captures[i], 0, d.capture_seconds):
			return false
		if s.captures[i] == d.capture_seconds:
			expected.append(100 + i)
	var coin_ids: Array = []
	for coin in s.coins:
		if not coin is Dictionary or not L.number(coin.get("id"), 0, 202, true) or not L.number(coin.get("x"), -4.7, 4.7) or not L.number(coin.get("z"), -6.75, 5.9) or coin.get("value") != reward(s, int(coin.id)):
			return false
		coin_ids.append(coin.id)
	var rewards: Array = s.collected + coin_ids
	if not L.unique_ids(rewards, 0, 202) or rewards.size() != expected.size():
		return false
	var available: Array = expected.map(func(v): return int(v))
	for id in rewards:
		if int(id) not in available:
			return false
	var earned: int = d.funds
	for id in s.collected:
		earned += reward(s, int(id))
	if earned != s.wallet + s.spent:
		return false
	for mark in s.marks:
		if not mark is Dictionary or not L.number(mark.get("x"), -4.7, 4.7) or not L.number(mark.get("z"), -6.2, 5.9) or not L.number(mark.get("remaining"), 0.000001, 1) or not L.number(mark.get("source"), 0, s.spawned - 1, true) or d.schedule[int(mark.source)].role != "storm":
			return false
	if s.phase == "ready" and (s.time != 0 or s.spent != 0 or s.spawned != 0 or s.recorded or s.hp != d.commander_hp or s.hq != d.hq):
		return false
	if s.phase == "playing" and (s.hp <= 0 or s.hq <= 0 or s.recorded):
		return false
	if s.phase == "victory" and (s.hp <= 0 or s.hq <= 0 or s.killed.size() < d.minimum or s.killed.size() + s.escaped.size() != d.schedule.size() or not objective_met(s) or not s.marks.is_empty()):
		return false
	if s.phase == "defeat" and s.hp > 0 and s.hq > 0 and not (s.killed.size() + s.escaped.size() == d.schedule.size() and (s.killed.size() < d.minimum or not objective_met(s))):
		return false
	return true

static func reward(s: Dictionary, id: int) -> int:
	if id >= 200 and id < 200 + s.definition.caches.size():
		return int(s.definition.caches[id - 200][2])
	if id >= 100 and id < 100 + s.definition.relays.size():
		return 8
	if id >= 0 and id < s.definition.schedule.size():
		return int(s.definition.enemy[s.definition.schedule[id].role].reward)
	return -1
