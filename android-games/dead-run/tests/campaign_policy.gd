extends RefCounted
const C = preload("res://scripts/campaign_rules.gd")

# Read-only state policy. Callers choose rule-fixture steering OR real input events.
# It is not a human pacing/difficulty model and never grants earned state.
static func aim(s: Dictionary, priority: String = "rescue") -> float:
	var d: Dictionary = s.definition
	var rescue := priority.begins_with("rescue")
	var demonstrate_harm: bool = priority == "rescue-harm" and d.index == 0
	var urgent := INF
	var enemy_x := 0.0
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		var def: Dictionary = d.enemies[i]
		if s.tick >= def.born and not e.resolved:
			var eta: float = e.z / def.speed
			if eta < urgent:
				urgent = eta
				enemy_x = def.x
	var target := enemy_x if urgent < INF else 0.0
	if not s.gates[0].crossed:
		target = d.gates[0].x
	elif urgent < (4.0 if rescue else 6.0):
		target = enemy_x
	elif s.tick >= d.boss.born and not s.boss.dead:
		if d.boss.kind == 4 and s.boss.arms[0] + s.boss.arms[1] > 0:
			var first := 0 if rescue else 1
			target = (-2.3 if first == 0 else 2.3) if s.boss.arms[first] > 0 else (2.3 if first == 0 else -2.3)
		else: target = s.boss.x + (0.9 if d.boss.kind == 2 and s.weapon != "lance" else 0.0)
	else:
		var chosen := false
		for i in s.gates.size():
			var g: Dictionary = s.gates[i]
			if s.tick >= d.gates[i].born and not g.crossed and g.z < 5 and (g.value > 0 or g.z > 2.5):
				target = d.gates[i].x
				chosen = true
				break
		if not chosen:
			var indices: Array = range(s.sides.size())
			if not rescue: indices.reverse()
			for i in indices:
				var side: Dictionary = d.sides[i]
				if not s.sides[i].claimed and s.tick >= side.born and s.tick < side.until - 120:
					target = side.x
					chosen = true
					break
	# One explicitly labelled demonstration crosses a negative gate at the footprint
	# edge while aiming fire elsewhere. This is an intentional route choice, not an
	# injected counter or a mandatory tutorial failure.
	if demonstrate_harm and not s.gates[2].crossed:
		var g: Dictionary = s.gates[2]
		var def: Dictionary = d.gates[2]
		if s.tick >= def.born - 90:
			if g.z < 3.3: target = def.x + (C.half_width(s.crew) + def.width - 0.06) * (-1 if def.x > 0 else 1)
			elif absf(target - def.x) < C.half_width(s.crew) + def.width + 0.5: target = -2.65 if def.x >= 0 else 2.65
	# Do not cross a negative gate accidentally while chasing a near target.
	for i in s.gates.size():
		if demonstrate_harm and i == 2: continue
		var g: Dictionary = s.gates[i]
		if not g.crossed and s.tick >= d.gates[i].born and g.z < 1.4 and g.value < 0 and absf(target - d.gates[i].x) <= C.half_width(s.crew) + d.gates[i].width:
			target = -2.8 if d.gates[i].x >= 0 else 2.8
	var dangers: Array = []
	for h in s.hazards:
		if not h.resolved and h.fire - s.tick < 105: dangers.append({"x": h.x, "width": h.width})
	for i in s.obstacles.size():
		if not s.obstacles[i].crossed and s.tick >= d.obstacles[i].born and s.obstacles[i].z < 3.3:
			dangers.append({"x": d.obstacles[i].x, "width": d.obstacles[i].width})
	if not dangers.is_empty():
		var best := INF
		var safest := target
		for candidate in [-3.15, -2.65, -1.3, 0.0, 1.3, 2.65, 3.15]:
			var bad := 0
			for h in dangers:
				if absf(candidate - h.x) <= C.half_width(s.crew) + h.width + 0.08: bad += 1
			var cost: float = bad * 100.0 + absf(candidate - target) + absf(candidate - s.x) * 0.12
			if cost < best:
				best = cost
				safest = candidate
		target = safest
	return clampf(target, -4.35 + C.half_width(s.crew), 4.35 - C.half_width(s.crew))
