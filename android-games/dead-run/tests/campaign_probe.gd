extends SceneTree
const D = preload("res://scripts/campaign_data.gd")
const C = preload("res://scripts/campaign_rules.gd")
func _initialize() -> void:
	for index in 24:
		var s := C.fresh(index)
		print("DEF ", index, " valid=", C.valid(s), " enemies=", s.enemies.size(), " gates=", s.gates.size())
		if not C.valid(s): quit(1); return
		if index == 0:
			s.phase = "playing"
			while s.phase == "playing":
				C.step(s)
				if not C.valid(s):
					print("INVALID_TICK ", s.tick)
					quit(2)
					return
			print("UNTOUCHED ", s.phase, " at=", s.tick)
	print("SUITE_COMPLETE: PASS")
	quit()
