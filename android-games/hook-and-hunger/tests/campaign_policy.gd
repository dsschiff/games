extends RefCounted
const C = preload("res://scripts/campaign_rules.gd")

static func direction(s: Dictionary, simple: bool = false) -> Vector2:
	var p := C.p(s)
	if int(s.tier) < int(s.definition.required_tier):
		return (C.PAD - p).limit_length()
	if p.y > 4.7:
		return Vector2(0, -1)
	var enemies := C.active(s)
	var nearest := 100000.0
	var target: Dictionary = {}
	for e in enemies:
		var role: String = s.definition.roster[int(e.id)].role
		var cost := p.distance_to(Vector2(e.x, e.z))
		if not simple:
			cost -= 4.0 if role == "tender" else 0.0
			cost += 1.0 if role in ["shield", "kiln"] and e.mode == "idle" else 0.0
		if cost < nearest:
			nearest = cost
			target = e
	if target.is_empty():
		return Vector2.ZERO
	var q := Vector2(target.x, target.z)
	var distance := p.distance_to(q)
	var desired: float = float(C.weapon(s).reach) - 0.25
	var vector := (q - p).normalized() if distance > desired else (p - q).normalized() if distance < desired - 0.3 else Vector2.ZERO
	if simple:
		return vector
	if s.definition.roster[int(target.id)].role in ["shield", "kiln"]:
		var facing := Vector2(sin(target.facing), cos(target.facing))
		var back := q - facing * 1.9
		vector = (back - p).limit_length()
		if target.mode == "idle" and distance < 3.2:
			vector = Vector2(-facing.y, facing.x) * 1.5
	for e in enemies:
		if e.mode != "wind" and e.mode != "charge":
			continue
		var spec: Dictionary = s.definition.roster[int(e.id)]
		var center := Vector2(e.ax, e.az)
		var dist := p.distance_to(center)
		if e.attack == "ring":
			if dist > 1.4 and dist < 6.9:
				vector += center.direction_to(p) * (4.0 if dist > 4.0 else -4.0)
		elif e.attack == "slam":
			var radius: float = 3.55 if spec.boss else float(spec.range) + 0.35
			if dist < radius + 0.7:
				vector += center.direction_to(p) * 3.5
		else:
			var axis := Vector2(e.tx, e.tz)
			if e.mode == "charge":
				center = Vector2(e.x, e.z)
			var along := (p - center).dot(axis)
			var side := Vector2(-axis.y, axis.x)
			var lateral := (p - center).dot(side)
			if along > -0.5 and along < 9.0 and absf(lateral) < 1.6:
				vector += side * (3.8 if lateral >= 0 else -3.8)
	for shot in s.projectiles:
		var center := Vector2(shot.x, shot.z)
		var axis := Vector2(shot.dx, shot.dz)
		var along := (p - center).dot(axis)
		var side := Vector2(-axis.y, axis.x)
		var lateral := (p - center).dot(side)
		if along > -0.3 and along < 4.0 and absf(lateral) < 1.1:
			vector += side * (4.5 if lateral >= 0 else -4.5)
	for b in s.definition.obstacles:
		var center := Vector2(b.x, b.z)
		if p.distance_to(center) < float(b.radius) + 1.0 and vector.dot(center - p) > 0:
			var side := Vector2(-(center - p).y, (center - p).x).normalized()
			if side.dot(q - p) < 0:
				side = -side
			vector += side * 2.3
	if absf(p.x) > 5.8 and vector.x * p.x > 0:
		vector.x = -signf(p.x) * 0.4
	if p.y < -11.7 and vector.y < 0:
		vector.y = 0.4
	if p.y > 4.0 and vector.y > 0 and not (s.hp < 20):
		vector.y = -0.5
	return vector.limit_length()
