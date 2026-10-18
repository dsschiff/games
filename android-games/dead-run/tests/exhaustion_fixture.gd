extends RefCounted
const R = preload("res://scripts/rules.gd")

# Synthetic valid-import boundary fixture. Not earned gameplay/reachability evidence.
static func make(surviving: bool = false) -> Dictionary:
	var s := R.fresh()
	s.phase = "playing"
	s.tick = 1226
	s.crew = 3 if surviving else 1
	s.joined = 6 if surviving else 4
	s.lost = 6
	s.gain_tick = 525
	s.hurt_tick = 1050
	s.shots = 150
	s.gate_hits = 18 if surviving else 16
	s.side_hp = 1
	s.side_hits = 119
	for i in 2:
		s.gates[i].z = 0.0
		s.gates[i].crossed = true
		s.gates[i].hits = (12 if surviving else 10) if i == 0 else 6
		s.gates[i].value = (6 if surviving else 4) if i == 0 else -6
		s.gates[i].applied = s.gates[i].value
	for e in s.enemies:
		if s.tick >= e.born:
			e.z = maxf(0, 23.0 - (s.tick - e.born + 1) / 60.0 * 2.2)
	s.bullets = [{"id": 149, "x": -2.65, "z": 11.99}]
	return s
