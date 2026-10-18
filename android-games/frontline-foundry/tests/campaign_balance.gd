extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
const P = preload("res://tests/policy.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var total := 0.0
	var bad := 0
	for i in 12:
		var s := C.fresh(D.mission(i))
		s.phase = "playing"
		s.planned_support = "ward" if i == 11 else "relay"
		var valid := C.valid(s)
		for frame in 12000:
			if s.phase != "playing":
				break
			var choice := P.decide(s)
			if choice.station >= 0 and C.nearby(s) == choice.station:
				C.buy(s, choice.station)
			C.tick(s, (choice.goal - C.position(s)).limit_length(), 0.05)
			if frame % 100 == 0 and not C.valid(s):
				valid = false
				print("INVALID ", i, " frame=", frame, " ", JSON.stringify(s))
				break
		print("BALANCE ", i + 1, " ", s.definition.id, " ", s.phase, " time=", s.time, " hp=", s.hp, " HQ=", s.hq, " kills=", s.killed.size(), " escaped=", s.escaped.size(), " bought=", s.bought, " stock=", s.stock, " support=", s.support, " coins=", s.coins.size(), " captures=", s.captures, " cause=", s.cause, " valid=", valid)
		if s.phase != "victory" or not valid:
			bad += 1
		total += s.time
	print("SYNTHETIC_TOTAL_SECONDS ", total, " failures=", bad)
	for variant in ["A", "B", "mistake"]:
		var s := C.fresh(D.mission(11))
		s.phase = "playing"
		s.planned_support = "ward"
		for frame in 12000:
			if s.phase != "playing":
				break
			var choice := P.decide(s, variant)
			if choice.station >= 0 and C.nearby(s) == choice.station:
				C.buy(s, choice.station)
			C.tick(s, (choice.goal - C.position(s)).limit_length(), 0.05)
		print("ALTERNATIVE ", variant, " ", s.phase, " hp=", s.hp, " HQ=", s.hq, " kills=", s.killed.size(), " purchases=", s.purchases, " cause=", s.cause)
	quit(bad)
