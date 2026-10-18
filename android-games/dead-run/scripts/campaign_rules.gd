extends RefCounted
const D = preload("res://scripts/campaign_data.gd")
const N = preload("res://scripts/rules.gd")

static func fresh(index: int = 0, weapon: String = "rivet", seed: int = 0) -> Dictionary:
	var definition := D.stage(index, seed)
	var s := {"definition": definition, "weapon": weapon, "phase": "ready", "tick": 0, "x": 0.0, "aim": 0.0, "crew": 5,
		"members": [0, 1, 2, 3, 4], "next_member": 5, "joined": 0, "lost": 0, "shots": 0, "bullets": [],
		"gates": [], "enemies": [], "sides": [], "obstacles": [], "hazards": [], "next_hazard": 0,
		"kills": 0, "leaks": 0, "contacts": 0, "gain_tick": -1000, "hurt_tick": -1000, "rewarded": false,
		"events": [], "notice": "Drag sideways. Fire is automatic. Keep infected off the rescue line."}
	for g in definition.gates:
		s.gates.append({"id": g.id, "z": g.z, "value": g.initial, "hits": 0, "crossed": false, "applied": 0, "delta": 0})
	for e in definition.enemies:
		s.enemies.append({"id": e.id, "z": e.z, "hp": e.hp, "armor": e.armor, "resolved": false, "dead": false, "actual_loss": 0, "contact": false, "next_spit": e.born + 300})
	for t in definition.sides:
		s.sides.append({"id": t.id, "hp": t.hp, "claimed": false, "claimed_at": -1, "delta": 0})
	for o in definition.obstacles:
		s.obstacles.append({"id": o.id, "z": o.z, "crossed": false, "actual_loss": 0})
	var b: Dictionary = definition.boss
	s["boss"] = {"hp": b.hp, "arms": [b.arms, b.arms], "x": 0.0, "z": b.z, "dead": false, "next_attack": b.born + 210, "phase": 0}
	return s

static func offset(index: int, count: int) -> Vector2:
	var columns := mini(5, ceili(sqrt(count)))
	return Vector2((index % columns - (columns - 1) * 0.5) * 0.46, floori(float(index) / columns) * 0.43)

static func half_width(count: int) -> float:
	return maxf(0.24, (mini(5, ceili(sqrt(count))) - 1) * 0.23 + 0.24)

static func overlaps(s: Dictionary, x: float, width: float) -> bool:
	return absf(s.x - x) <= half_width(s.crew) + width

static func steer(s: Dictionary, x: float) -> void:
	s.aim = clampf(x, -4.35 + half_width(s.crew), 4.35 - half_width(s.crew))

static func adjust(s: Dictionary, amount: int, cause: String) -> int:
	if s.crew == 0 and amount > 0: return 0
	var old: int = s.crew
	s.crew = clampi(old + amount, 0, s.definition.cap)
	var delta: int = s.crew - old
	if delta > 0:
		for i in delta:
			s.members.append(s.next_member)
			s.next_member += 1
		s.joined += delta
		s.gain_tick = s.tick
	elif delta < 0:
		for i in -delta: s.members.pop_back()
		s.lost -= delta
		s.hurt_tick = s.tick
	s.events.append({"tick": s.tick, "cause": cause, "delta": delta})
	s.notice = cause + (" · %+d crew" % delta if delta != 0 else " · crew at capacity")
	s.x = clampf(s.x, -4.35 + half_width(s.crew), 4.35 - half_width(s.crew))
	steer(s, s.aim)
	return delta

static func hazard(s: Dictionary, source: int, x: float, width: float, loss: int, delay: int, label: String) -> void:
	s.hazards.append({"id": s.next_hazard, "source": source, "born": s.tick, "fire": s.tick + delay, "x": x, "width": width, "loss": loss, "label": label, "resolved": false, "actual_loss": 0, "cancelled": false})
	s.next_hazard += 1

static func targets(s: Dictionary) -> Array:
	var out: Array = []
	for i in s.gates.size():
		var def: Dictionary = s.definition.gates[i]
		if s.tick >= def.born and not s.gates[i].crossed:
			out.append({"kind": "gate", "id": i, "x": def.x, "z": s.gates[i].z, "width": def.width})
	for i in s.enemies.size():
		var def: Dictionary = s.definition.enemies[i]
		if s.tick >= def.born and not s.enemies[i].resolved:
			out.append({"kind": "enemy", "id": i, "x": def.x, "z": s.enemies[i].z, "width": def.width})
	for i in s.sides.size():
		var def: Dictionary = s.definition.sides[i]
		if s.tick >= def.born and s.tick <= def.until and not s.sides[i].claimed:
			out.append({"kind": "side", "id": i, "x": def.x, "z": def.z, "width": 0.95})
	if s.tick >= s.definition.boss.born and not s.boss.dead:
		if s.definition.boss.kind == 4 and (s.boss.arms[0] > 0 or s.boss.arms[1] > 0):
			for i in 2:
				if s.boss.arms[i] > 0: out.append({"kind": "arm", "id": i, "x": -2.3 if i == 0 else 2.3, "z": s.boss.z, "width": 0.9})
		else:
			out.append({"kind": "boss", "id": 0, "x": s.boss.x, "z": s.boss.z, "width": 1.25})
	return out

static func strike(s: Dictionary, b: Dictionary, t: Dictionary) -> bool:
	var gun: Dictionary = s.definition.weapons[s.weapon]
	match t.kind:
		"gate":
			var g: Dictionary = s.gates[t.id]
			if g.crossed: return false
			g.hits += 1
			g.value = mini(s.definition.gates[t.id].cap, s.definition.gates[t.id].initial + g.hits)
		"enemy":
			var e: Dictionary = s.enemies[t.id]
			if e.resolved or t.id in b.hit_ids: return false
			if e.armor > 0 and s.weapon != "lance":
				e.armor -= 1
			else:
				e.hp = maxi(0, e.hp - gun.damage)
			if e.hp == 0:
				e.resolved = true
				e.dead = true
				s.kills += 1
			b.hit_ids.append(t.id)
			b.remaining -= 1
			return b.remaining <= 0
		"side":
			var side: Dictionary = s.sides[t.id]
			if side.claimed: return false
			side.hp = maxi(0, side.hp - gun.damage)
			if side.hp == 0:
				side.claimed = true
				side.claimed_at = s.tick
				side.delta = adjust(s, s.definition.sides[t.id].reward, "Pump secured" if s.definition.sides[t.id].kind == "pump" else "Roadside riggers rescued")
		"arm":
			s.boss.arms[t.id] = maxi(0, s.boss.arms[t.id] - gun.damage)
			if s.boss.arms[t.id] == 0: s.notice = "Outer arm broken. " + ("Core exposed!" if s.boss.arms[0] + s.boss.arms[1] == 0 else "Break the other arm.")
		"boss":
			if s.definition.boss.kind == 2 and s.weapon != "lance" and absf(b.x - s.boss.x) < 0.55:
				s.notice = "Toll shield blocks centre fire. Move to a flank."
			else:
				s.boss.hp = maxi(0, s.boss.hp - gun.damage)
			if s.boss.hp == 0:
				s.boss.dead = true
				s.notice = "Route cleared. Keep the rescue line safe until the convoy passes."
				for h in s.hazards:
					if h.source == -1 and not h.resolved:
						h.resolved = true
						h.cancelled = true
	return true

static func step(s: Dictionary) -> void:
	if s.phase != "playing": return
	s.tick += 1
	s.x = move_toward(s.x, s.aim, 6.0 / 60.0)
	for i in s.gates.size():
		var def: Dictionary = s.definition.gates[i]
		var g: Dictionary = s.gates[i]
		if s.tick >= def.born and not g.crossed:
			g.z = maxf(0, def.z - float(s.tick - def.born + 1) / 60.0 * s.definition.speed)
			if g.z <= 0:
				g.crossed = true
				if overlaps(s, def.x, def.width):
					g.applied = g.value
					g.delta = adjust(s, g.value, "Gate %+d crossed" % g.value)
	for i in s.obstacles.size():
		var def: Dictionary = s.definition.obstacles[i]
		var o: Dictionary = s.obstacles[i]
		if s.tick >= def.born and not o.crossed:
			o.z = maxf(0, def.z - float(s.tick - def.born + 1) / 60.0 * s.definition.speed)
			if o.z <= 0:
				o.crossed = true
				if overlaps(s, def.x, def.width): o.actual_loss = -adjust(s, -def.loss, "Cart collision — steer the whole footprint clear")
	for i in s.enemies.size():
		var def: Dictionary = s.definition.enemies[i]
		var e: Dictionary = s.enemies[i]
		if s.tick >= def.born and not e.resolved:
			e.z = maxf(0, def.z - float(s.tick - def.born + 1) / 60.0 * def.speed)
			if e.z <= 0:
				e.resolved = true
				e.contact = overlaps(s, def.x, def.width)
				e.actual_loss = -adjust(s, -def.loss - int(e.contact), ("Contact" if e.contact else "Rescue-line leak") + " · " + def.role)
				s.leaks += 1
				s.contacts += int(e.contact)
			elif def.role == "spitter" and s.tick >= e.next_spit:
				hazard(s, i, s.x, 0.6, 2, 180, "Spit mark")
				e.next_spit += 420
	for def in s.definition.floods:
		if s.tick == def.mark:
			var disabled := false
			for i in s.sides.size():
				if s.sides[i].claimed and s.definition.sides[i].disables == def.pump: disabled = true
			if not disabled: hazard(s, -2 - def.id, def.x, def.width, def.loss, 180, "Flood pulse")
	var b: Dictionary = s.boss
	var bd: Dictionary = s.definition.boss
	if s.tick >= bd.born and not b.dead:
		b.phase = int((s.tick - bd.born) / 420)
		if bd.kind == 0:
			b.z = maxf(0, bd.z - float(s.tick - bd.born + 1) / 60.0 * 1.35)
		else:
			b.z = 14.0
			var target_x := (-2.3 if b.phase % 2 == 0 else 2.3) if bd.kind == 1 else ((-2.65 if b.hp > bd.hp / 2 else 2.65) if bd.kind == 3 else 0.0)
			b.x = move_toward(b.x, target_x, 4.0 / 60.0)
			if s.tick >= b.next_attack:
				if bd.kind in [1, 2]: hazard(s, -1, s.x, 0.85, 3, 180, "Cable sweep" if bd.kind == 1 else "Ram charge")
				elif bd.kind == 3:
					for j in 2: hazard(s, -1, D.LANES[(b.phase + j) % 3], 0.6, 2, 180, "Bell volley")
				else:
					hazard(s, -1, D.LANES[b.phase % 3], 0.75, 3, 180, "Ferry sweep")
				b.next_attack += 360
	for h in s.hazards:
		if not h.resolved and s.tick >= h.fire:
			h.resolved = true
			if overlaps(s, h.x, h.width): h.actual_loss = -adjust(s, -h.loss, h.label + " — leave marked lane before red")
	# All movement/contact/hazards settle before any queued fire/reward or completion.
	if s.crew == 0:
		s.phase = "defeat"
		var losses: Array = s.events.filter(func(e): return e.delta < 0)
		s.notice = "Crew depleted. " + (losses[-1].cause if not losses.is_empty() else "Hold the rescue line.")
		return
	if (bd.kind == 0 and s.tick >= bd.born and b.z <= 0 and not b.dead) or (s.tick >= s.definition.duration and not b.dead):
		s.phase = "defeat"
		s.notice = "The " + bd.title.to_lower() + " stopped the convoy. Focus its exposed target before the deadline."
		return
	var gun: Dictionary = s.definition.weapons[s.weapon]
	if s.tick % gun.period == 0:
		for i in s.crew:
			var q := offset(i, s.crew)
			for pellet in gun.pellets:
				s.bullets.append({"id": s.shots, "owner": s.members[i], "x": s.x + q.x, "z": 0.4, "dx": gun.spread * (-1 if pellet == 0 else 1), "remaining": gun.pierce, "hit_ids": []})
				s.shots += 1
	var ts := targets(s)
	for i in range(s.bullets.size() - 1, -1, -1):
		var bullet: Dictionary = s.bullets[i]
		var old: float = bullet.z
		bullet.z += 0.48
		bullet.x += bullet.dx
		var chosen: Dictionary = {}
		var nearest := INF
		for t in ts:
			if t.z >= old and t.z <= bullet.z and t.z < nearest and absf(bullet.x - t.x) <= t.width and not (t.kind == "enemy" and t.id in bullet.hit_ids):
				if (t.kind == "enemy" and s.enemies[t.id].resolved) or (t.kind == "side" and s.sides[t.id].claimed): continue
				nearest = t.z
				chosen = t
		var consumed := false
		if not chosen.is_empty(): consumed = strike(s, bullet, chosen)
		if consumed or bullet.z > 36 or absf(bullet.x) > 6:
			s.bullets.remove_at(i)
	if s.tick >= s.definition.duration and b.dead:
		s.phase = "victory"
		s.notice = "Convoy through. Roadside rescues %d/%d · crew lost %d." % [s.sides.filter(func(t): return t.claimed).size(), s.sides.size(), s.lost]

static func valid(s: Variant) -> bool:
	if not s is Dictionary or not s.get("definition") is Dictionary: return false
	var d: Dictionary = s.definition
	if not N.number(d.get("index"), 0, 23, true) or not N.number(d.get("seed"), 0, 999999, true) or not D.same(d, D.stage(int(d.index), int(d.seed))): return false
	# Hazards can refer to boss death, so validate the complete boss first.
	var b: Variant = s.get("boss")
	if not b is Dictionary or not N.number(b.get("hp"), 0, d.boss.hp, true) or not b.get("arms") is Array or b.arms.size() != 2 or not N.number(b.get("x"), -2.65, 2.65) or not N.number(b.get("z"), 0, 23) or not b.get("dead") is bool or not N.number(b.get("next_attack"), d.boss.born + 210, d.duration + 720, true) or not N.number(b.get("phase"), 0, 10, true): return false
	for arm in b.arms:
		if not N.number(arm, 0, d.boss.arms, true): return false
	if b.dead != (b.hp == 0 and b.arms[0] + b.arms[1] == 0): return false
	if not D.WEAPONS.has(s.get("weapon")) or s.get("phase") not in ["ready", "playing", "victory", "defeat"]: return false
	for k in ["tick", "crew", "next_member", "joined", "lost", "shots", "next_hazard", "kills", "leaks", "contacts"]:
		if not N.number(s.get(k), 0, 100000, true): return false
	for k in ["gain_tick", "hurt_tick"]:
		if not N.number(s.get(k), -1000, s.tick, true): return false
	if s.tick > d.duration or s.crew > 20 or not N.number(s.get("x"), -4.35 + half_width(s.crew) - 0.00001, 4.35 - half_width(s.crew) + 0.00001) or not N.number(s.get("aim"), -4.35 + half_width(s.crew) - 0.00001, 4.35 - half_width(s.crew) + 0.00001): return false
	if not s.get("notice") is String or s.notice.length() > 500 or not s.get("rewarded") is bool: return false
	for k in ["members", "gates", "enemies", "sides", "obstacles", "hazards", "bullets", "events"]:
		if not s.get(k) is Array: return false
	if s.gates.size() != d.gates.size() or s.enemies.size() != d.enemies.size() or s.sides.size() != d.sides.size() or s.obstacles.size() != d.obstacles.size() or s.hazards.size() != s.next_hazard or s.hazards.size() > 180 or s.bullets.size() > 600 or s.events.size() > 600: return false
	if s.crew != s.members.size() or s.next_member != 5 + s.joined or s.crew != 5 + s.joined - s.lost: return false
	var ids := {}
	for id in s.members:
		if not N.number(id, 0, s.next_member - 1, true) or ids.has(id): return false
		ids[id] = true
	var earned := 0
	var lost := 0
	for i in s.gates.size():
		var g: Variant = s.gates[i]
		var gd: Dictionary = d.gates[i]
		if not g is Dictionary or g.get("id") != i or not N.number(g.get("hits"), 0, s.shots, true) or g.get("value") != mini(gd.cap, gd.initial + int(g.hits)) or not g.get("crossed") is bool or not N.number(g.get("applied"), gd.initial, gd.cap, true) or not N.number(g.get("delta"), -20, gd.cap, true) or not N.number(g.get("z"), 0, gd.z): return false
		var expected := maxf(0, gd.z - maxi(0, s.tick - gd.born + 1) / 60.0 * d.speed)
		if absf(g.z - expected) > 0.0001 or g.crossed != (expected < 0.0001) or (not g.crossed and (g.applied != 0 or g.delta != 0)) or (g.applied != 0 and g.applied != g.value): return false
		if s.tick < gd.born and g.hits != 0: return false
		if (g.delta > 0 and (g.applied < g.delta)) or (g.delta < 0 and g.applied > g.delta): return false
		earned += maxi(0, g.delta)
		lost += maxi(0, -g.delta)
	var kills := 0
	var leaks := 0
	var contacts := 0
	for i in s.enemies.size():
		var e: Variant = s.enemies[i]
		var ed: Dictionary = d.enemies[i]
		if not e is Dictionary or e.get("id") != i or not N.number(e.get("hp"), 0, ed.hp, true) or not N.number(e.get("armor"), 0, ed.armor, true) or not N.number(e.get("z"), 0, ed.z) or not e.get("resolved") is bool or not e.get("dead") is bool or not e.get("contact") is bool or not N.number(e.get("actual_loss"), 0, ed.loss + 1, true) or not N.number(e.get("next_spit"), ed.born + 300, d.duration + 720, true): return false
		if s.tick < ed.born and (e.hp != ed.hp or e.armor != ed.armor or e.resolved or e.z != ed.z): return false
		if e.dead:
			if not e.resolved or e.hp != 0 or e.actual_loss != 0 or e.contact: return false
			kills += 1
		elif e.resolved:
			if e.z != 0 or e.hp == 0 or ed.z - maxi(0, s.tick - ed.born + 1) / 60.0 * ed.speed > 0.0001: return false
			leaks += 1
			contacts += int(e.contact)
		elif e.hp == 0 or e.actual_loss != 0 or e.contact or absf(e.z - maxf(0, ed.z - maxi(0, s.tick - ed.born + 1) / 60.0 * ed.speed)) > 0.0001: return false
		lost += e.actual_loss
	if kills != s.kills or leaks != s.leaks or contacts != s.contacts: return false
	for i in s.sides.size():
		var side: Variant = s.sides[i]
		if not side is Dictionary or side.get("id") != i or not N.number(side.get("hp"), 0, d.sides[i].hp, true) or not side.get("claimed") is bool or side.claimed != (side.hp == 0) or not N.number(side.get("delta"), 0, d.sides[i].reward, true) or (not side.claimed and side.delta != 0): return false
		if not N.number(side.get("claimed_at"), -1, s.tick, true) or (not side.claimed and side.claimed_at != -1) or (side.claimed and (side.claimed_at < d.sides[i].born or side.claimed_at > d.sides[i].until)): return false
		if s.tick < d.sides[i].born and side.hp != d.sides[i].hp: return false
		earned += side.delta
	for i in s.obstacles.size():
		var o: Variant = s.obstacles[i]
		var od: Dictionary = d.obstacles[i]
		if not o is Dictionary or o.get("id") != i or not o.get("crossed") is bool or not N.number(o.get("actual_loss"), 0, od.loss, true) or not N.number(o.get("z"), 0, od.z): return false
		var expected := maxf(0, od.z - maxi(0, s.tick - od.born + 1) / 60.0 * d.speed)
		if absf(o.z - expected) > 0.0001 or o.crossed != (expected < 0.0001) or (not o.crossed and o.actual_loss != 0): return false
		lost += o.actual_loss
	var hazard_keys := {}
	for i in s.hazards.size():
		var h: Variant = s.hazards[i]
		if not h is Dictionary or h.get("id") != i or not N.number(h.get("source"), -20, d.enemies.size() - 1, true) or not N.number(h.get("born"), 0, s.tick, true) or h.get("fire") != h.born + 180 or not N.number(h.get("x"), -4.35, 4.35) or not N.number(h.get("width"), 0.5, 0.9) or not N.number(h.get("loss"), 2, 3, true) or not h.get("resolved") is bool or not h.get("cancelled") is bool or not N.number(h.get("actual_loss"), 0, h.loss, true) or not h.get("label") is String: return false
		if h.source >= 0:
			var ed: Dictionary = d.enemies[int(h.source)]
			if ed.role != "spitter" or h.born < ed.born + 300 or int(h.born - ed.born - 300) % 420 != 0 or h.loss != 2 or h.width != 0.6 or h.label != "Spit mark" or h.cancelled: return false
		elif h.source == -1:
			if d.boss.kind == 0 or h.born < d.boss.born + 210 or int(h.born - d.boss.born - 210) % 360 != 0: return false
			if h.cancelled and not s.boss.dead: return false
		else:
			var flood_id := -2 - int(h.source)
			if flood_id < 0 or flood_id >= d.floods.size(): return false
			var fd: Dictionary = d.floods[flood_id]
			if h.born != fd.mark or h.x != fd.x or h.width != fd.width or h.loss != fd.loss or h.label != "Flood pulse" or h.cancelled: return false
			for side_id in s.sides.size():
				if s.sides[side_id].claimed and d.sides[side_id].disables == fd.pump and s.sides[side_id].claimed_at < fd.mark: return false
		var key := str(h.source) + ":" + str(h.born) + ":" + str(roundi(h.x * 1000000))
		if hazard_keys.has(key): return false
		hazard_keys[key] = true
		if (h.cancelled and (not h.resolved or h.actual_loss != 0)) or (not h.resolved and (h.actual_loss != 0 or s.tick >= h.fire)): return false
		lost += h.actual_loss
	if earned != s.joined or lost != s.lost: return false
	var event_joined := 0
	var event_lost := 0
	var previous_event_tick := -1
	var depleted := false
	for e in s.events:
		if not e is Dictionary or not N.number(e.get("tick"), 0, s.tick, true) or not N.number(e.get("delta"), -20, 6, true) or not e.get("cause") is String or e.cause.length() > 180: return false
		if e.tick < previous_event_tick or (depleted and e.delta > 0): return false
		previous_event_tick = e.tick
		event_joined += maxi(0, e.delta)
		event_lost += maxi(0, -e.delta)
		if 5 + event_joined - event_lost < 0 or 5 + event_joined - event_lost > 20: return false
		depleted = depleted or 5 + event_joined - event_lost == 0
	if event_joined != earned or event_lost != lost: return false
	if s.tick < d.boss.born and (b.hp != d.boss.hp or b.arms[0] != d.boss.arms or b.arms[1] != d.boss.arms or b.dead): return false
	ids = {}
	var gun: Dictionary = d.weapons[s.weapon]
	if s.shots > floori(float(s.tick) / gun.period) * 20 * gun.pellets: return false
	for bullet in s.bullets:
		if not bullet is Dictionary or not N.number(bullet.get("id"), 0, s.shots - 1, true) or ids.has(bullet.id) or not N.number(bullet.get("owner"), 0, s.next_member - 1, true) or not N.number(bullet.get("x"), -6, 6) or not N.number(bullet.get("z"), 0, 36) or not N.number(bullet.get("dx"), -gun.spread, gun.spread) or not N.number(bullet.get("remaining"), 1, gun.pierce, true) or not bullet.get("hit_ids") is Array or bullet.hit_ids.size() + bullet.remaining != gun.pierce: return false
		var seen := {}
		if absf(absf(bullet.dx) - gun.spread) > 0.000000001: return false
		for hit in bullet.hit_ids:
			if not N.number(hit, 0, d.enemies.size() - 1, true) or seen.has(hit) or d.enemies[int(hit)].born > s.tick or s.enemies[int(hit)].hp == d.enemies[int(hit)].hp: return false
			seen[hit] = true
		ids[bullet.id] = true
	if s.phase == "ready" and (s.tick != 0 or s.crew != 5 or s.shots != 0 or s.joined != 0 or s.lost != 0 or not s.events.is_empty()): return false
	if s.phase == "playing" and (s.crew == 0 or s.tick >= d.duration): return false
	if s.phase == "victory" and (s.tick != d.duration or s.crew == 0 or not b.dead): return false
	if s.phase == "defeat" and not (s.crew == 0 or (not b.dead and (s.tick >= d.duration or (d.boss.kind == 0 and b.z == 0)))): return false
	return true
