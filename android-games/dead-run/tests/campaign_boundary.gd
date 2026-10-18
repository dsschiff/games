extends RefCounted
const R = preload("res://scripts/campaign_rules.gd")
# Synthetic import-valid same-tick contact / final crane-hit boundary, not earned.
static func make(survives: bool) -> Dictionary:
	var s := R.fresh()
	s.phase = "playing"
	var first: Dictionary = s.definition.enemies[0]
	s.tick = first.born + ceili(first.z / first.speed * 60.0) - 2
	s.x = -2.65
	s.aim = -2.65
	s.crew = 3 if survives else 1
	s.members = [0, 1, 2] if survives else [0]
	s.lost = 2 if survives else 4
	var gate_tick: int = s.definition.gates[0].born + ceili(s.definition.gates[0].z / s.definition.speed * 60.0) - 1
	s.hurt_tick = gate_tick
	s.shots = 150
	for i in s.gates.size():
		var def: Dictionary = s.definition.gates[i]
		s.gates[i].z = maxf(0, def.z - maxi(0, s.tick - def.born + 1) / 60.0 * s.definition.speed)
		s.gates[i].crossed = s.gates[i].z == 0
	s.gates[0].hits = 3 if survives else 1
	s.gates[0].value = -2 if survives else -4
	s.gates[0].applied = s.gates[0].value
	s.gates[0].delta = s.gates[0].value
	s.events = [{"tick": gate_tick, "cause": "Synthetic gate boundary", "delta": s.gates[0].delta}]
	for i in s.enemies.size():
		var def: Dictionary = s.definition.enemies[i]
		s.enemies[i].z = maxf(0, def.z - maxi(0, s.tick - def.born + 1) / 60.0 * def.speed)
	s.sides[0].hp = 1
	s.bullets = [{"id": 149, "owner": 0, "x": -2.65, "z": 13.25, "dx": 0.0, "remaining": 1, "hit_ids": []}]
	return s
