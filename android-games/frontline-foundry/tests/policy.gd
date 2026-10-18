extends RefCounted
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")

# Read-only controller shared by labelled synthetic controls and real touch routes.
static func decide(s: Dictionary, variant: String = "A") -> Dictionary:
	var p := C.position(s)
	var result := {"goal": Vector2(0, -1), "station": -1}
	if variant == "idle" and s.purchases.size() >= 5:
		return {"goal": Vector2(4.5, 5.5), "station": -1}
	for mark in s.marks:
		if p.distance_to(Vector2(mark.x, mark.z)) < 1.6:
			result.goal = p + Vector2(2.4 if p.x < 2 else -2.4, 0)
			return result
	for e in s.enemies:
		if e.role not in ["mortar", "storm", "runner"] and p.distance_to(Vector2(e.x, e.z)) < s.definition.enemy[e.role].range + 0.25:
			result.goal = p + (p - Vector2(e.x, e.z)).normalized() * 2
			return result
	var desired := -1
	if variant != "mistake" and C.active_count(s) + s.stock.reduce(func(a, b): return a + b, 0) < s.definition.cap:
		var order: Array = ["rifle", "ranger", "breaker", "rover", "ranger", "breaker", "rifle", "rover", "rifle", "ranger", "breaker", "rover"] if variant in ["A", "idle"] else ["rover", "breaker", "ranger", "rifle", "breaker", "ranger", "rifle", "rover", "ranger", "breaker", "rifle", "rover"]
		var counts := [0, 0, 0, 0]
		for role in order:
			var index: int = D.ROLES.find(role)
			counts[index] += 1
			if role in s.definition.available and counts[index] > s.bought[index] and s.bought[index] < s.definition.pool[index]:
				if s.wallet >= s.definition.unit[role].cost:
					desired = index
				break
	if variant == "mistake" and s.bought[0] < 3 and s.wallet >= 7:
		desired = 0
	if s.support == "none" and s.wallet >= 14 and s.purchases.size() >= 3 and variant != "mistake":
		desired = 4
	if desired >= 0:
		return {"goal": D.pad(s.definition, desired), "station": desired}
	if variant == "mistake":
		return {"goal": Vector2(4.5, 5.5), "station": -1}
	# Clear urgent distant fire/jamming before entering exposed pickup/capture routes.
	var urgent: Dictionary = {}
	for e in s.enemies:
		if e.role in ["mortar", "jammer", "storm"] and (urgent.is_empty() or e.z > urgent.z):
			urgent = e
	if not urgent.is_empty():
		return {"goal": Vector2(urgent.x, urgent.z + (4.4 if s.support == "relay" else 3.2)), "station": -1}
	for i in s.captures.size():
		if s.captures[i] < s.definition.capture_seconds:
			return {"goal": Vector2(s.definition.relays[i][0], s.definition.relays[i][1]), "station": -1}
	if not s.coins.is_empty():
		var nearest := INF
		for coin in s.coins:
			var distance := p.distance_to(Vector2(coin.x, coin.z))
			if distance < nearest:
				nearest = distance
				result.goal = Vector2(coin.x, coin.z)
		return result
	if not s.enemies.is_empty():
		var e: Dictionary = s.enemies[0]
		result.goal = Vector2(e.x, e.z + (4.4 if s.support == "relay" else 3.4))
	return result
