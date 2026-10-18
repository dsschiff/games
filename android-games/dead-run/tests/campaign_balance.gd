extends SceneTree
const R = preload("res://scripts/campaign_rules.gd")
const P = preload("res://tests/campaign_policy.gd")
func _initialize() -> void:
	var failure := false
	for index in 24:
		var weapon: String = ["rivet", "lance", "fan"][index % 3]
		var s := R.fresh(index, weapon)
		s.phase = "playing"
		while s.phase == "playing":
			if s.tick % 15 == 0: R.steer(s, P.aim(s))
			R.step(s)
			if s.tick % 60 == 0 and not R.valid(s):
				print("INVALID ", index, " tick=", s.tick)
				quit(2)
				return
		print("RULE_POLICY ", index, " ", weapon, " ", s.phase, " tick=", s.tick, " crew=", s.crew, " joined=", s.joined, " lost=", s.lost, " killed=", s.kills, " leaks=", s.leaks, " boss=", s.boss.hp, " arms=", s.boss.arms, " rescue=", s.sides.map(func(side):return side.hp))
		failure = failure or s.phase != "victory"
	print("SCOPE rule simulation fixture, not actual engine input or earned campaign")
	print("SUITE_COMPLETE: ", "FAIL" if failure else "PASS")
	quit(1 if failure else 0)
