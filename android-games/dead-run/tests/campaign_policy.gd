extends RefCounted
const C = preload("res://scripts/campaign_rules.gd")

# Read-only state policy. Callers choose rule-fixture steering OR real input events.
# It is not a human pacing/difficulty model and never grants earned state.
# Rule3 hordes: the default aim is the lane position whose fire covers the
# most urgent pressure; gates, rescues and bosses take over when it is calm.

## Weighted pressure covered by a crew centred at cx. Fan pellets drift, so
## far infected are reachable from further away.
static func pressure(s: Dictionary, cx: float, horizon: float) -> float:
	var d: Dictionary = s.definition
	var hw := C.half_width(s.crew)
	var gun: Dictionary = d.weapons[s.weapon]
	var score := 0.0
	for i in s.enemies.size():
		var def: Dictionary = d.enemies[i]
		if s.tick < def.born: continue
		var e: Dictionary = s.enemies[i]
		if e.resolved: continue
		var eta: float = e.z / def.speed
		if eta > horizon: continue
		var reach: float = hw - 0.12 + def.width + gun.spread * e.z / 0.48
		var gap := absf(def.x - cx)
		if gap > reach: continue
		var weight: float = (def.loss + 0.6) * (1.0 + 0.12 * (e.hp + e.armor)) / pow(maxf(0.7, eta), 1.6)
		score += weight * (1.0 - 0.35 * gap / reach)
	return score

static func threat(s: Dictionary, horizon: float = 9.0) -> Dictionary:
	var lo := -4.35 + C.half_width(s.crew)
	var best := {"x": 0.0, "score": 0.0}
	for k in 29:
		var cx := clampf(-3.5 + k * 0.25, lo, -lo)
		var score := pressure(s, cx, horizon) - absf(cx - s.x) * 0.02
		if score > best.score:
			best = {"x": cx, "score": score}
	return best

static func urgent_eta(s: Dictionary) -> float:
	var d: Dictionary = s.definition
	var urgent := INF
	for i in s.enemies.size():
		var def: Dictionary = d.enemies[i]
		if s.tick >= def.born and not s.enemies[i].resolved:
			urgent = minf(urgent, s.enemies[i].z / def.speed)
	return urgent

static func aim(s: Dictionary, priority: String = "rescue") -> float:
	var d: Dictionary = s.definition
	var rescue := priority.begins_with("rescue")
	var demonstrate_harm: bool = priority == "rescue-harm" and d.index == 0
	var hw := C.half_width(s.crew)
	var hot := threat(s, 3.2 if rescue else 4.2)
	var calm: bool = hot.score < (1.4 if rescue else 0.9)
	var target: float = hot.x if hot.score > 0 else threat(s).x
	if not s.gates[0].crossed:
		target = d.gates[0].x
	elif not calm:
		target = hot.x
	elif s.tick >= d.boss.born and not s.boss.dead:
		if d.boss.kind == 4 and s.boss.arms[0] + s.boss.arms[1] > 0:
			var first := 0 if rescue else 1
			target = (-2.3 if first == 0 else 2.3) if s.boss.arms[first] > 0 else (2.3 if first == 0 else -2.3)
		else: target = s.boss.x + (0.9 + hw * 0.5 if d.boss.kind == 2 and s.weapon != "lance" else 0.0)
	else:
		var chosen := false
		for i in s.gates.size():
			var g: Dictionary = s.gates[i]
			var gd: Dictionary = d.gates[i]
			if s.tick < gd.born or g.crossed or g.z > 9: continue
			var mul: bool = gd.get("kind", "add") == "mul"
			var worth: bool = (g.value > 1) if mul else (g.value > 0)
			var improvable: bool = g.value < gd.cap and g.z > 2.0
			if (worth or improvable) and not (mul and s.crew >= d.cap):
				target = gd.x
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
			if g.z < 3.3: target = def.x + (hw + def.width - 0.06) * (-1 if def.x > 0 else 1)
			elif absf(target - def.x) < hw + def.width + 0.5: target = -2.65 if def.x >= 0 else 2.65
	# Do not cross a harmful gate accidentally while chasing a near target.
	for i in s.gates.size():
		if demonstrate_harm and i == 2: continue
		var g: Dictionary = s.gates[i]
		var gd: Dictionary = d.gates[i]
		if not g.crossed and s.tick >= gd.born and g.z < 1.6 and g.value < 0 and absf(target - gd.x) <= hw + gd.width:
			target = gd.x - (hw + gd.width + 0.1) if gd.x >= 0 else gd.x + hw + gd.width + 0.1
			if absf(target) > 4.35 - hw: target = gd.x + (hw + gd.width + 0.1) * (1 if gd.x >= 0 else -1)
	var dangers: Array = []
	for h in s.hazards:
		if not h.resolved and h.fire - s.tick < 105: dangers.append({"x": h.x, "width": h.width})
	for i in s.obstacles.size():
		if not s.obstacles[i].crossed and s.tick >= d.obstacles[i].born and s.obstacles[i].z < 3.3:
			dangers.append({"x": d.obstacles[i].x, "width": d.obstacles[i].width})
	for i in s.gates.size():
		var g: Dictionary = s.gates[i]
		if demonstrate_harm and i == 2: continue
		if not g.crossed and s.tick >= d.gates[i].born and g.z < 1.6 and g.value < 0:
			dangers.append({"x": d.gates[i].x, "width": d.gates[i].width})
	if not dangers.is_empty():
		var best := INF
		var safest := target
		for k in 29:
			var candidate := clampf(-3.5 + k * 0.25, -4.35 + hw, 4.35 - hw)
			var bad := 0
			for h in dangers:
				if absf(candidate - h.x) <= hw + h.width + 0.08: bad += 1
			var cost: float = bad * 100.0 + absf(candidate - target) + absf(candidate - s.x) * 0.12
			if cost < best:
				best = cost
				safest = candidate
		target = safest
	return clampf(target, -4.35 + hw, 4.35 - hw)
