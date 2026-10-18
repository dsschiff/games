extends RefCounted
const Base = preload("res://tests/campaign_policy.gd")
const C = preload("res://scripts/campaign_rules.gd")

static func aim(s: Dictionary, priority: String) -> float:
	if priority == "left-riggers-first": return Base.aim(s, "rescue")
	var result := Base.aim(s, "line")
	var d: Dictionary = s.definition
	if d.index != 21 or s.sides[1].claimed: return result
	# Preserve already telegraphed dodges; otherwise defer the left opportunity
	# until the right pump is available and secured. This reads state only.
	for h in s.hazards:
		if not h.resolved and h.fire - s.tick < 105: return result
	for i in s.obstacles.size():
		if not s.obstacles[i].crossed and s.tick >= d.obstacles[i].born and s.obstacles[i].z < 3.3: return result
	var eta := INF
	var enemy_x := 0.0
	var enemy_z := INF
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		if not e.resolved and s.tick >= d.enemies[i].born and e.z / d.enemies[i].speed < eta:
			eta = e.z / d.enemies[i].speed
			enemy_x = d.enemies[i].x
			enemy_z = e.z
	if eta < 6.0: return result
	for i in s.gates.size():
		if s.tick >= d.gates[i].born and not s.gates[i].crossed and s.gates[i].z < 5: return result
	if s.tick < d.sides[1].born and absf(result - d.sides[0].x) < 0.1:
		return enemy_x if enemy_z < 12 else 0.0
	return result
