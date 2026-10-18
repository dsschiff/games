extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/campaign_data.gd")
const P = preload("res://tests/campaign_policy.gd")
const S = preload("res://scripts/save_store.gd")

func _initialize() -> void:
	var wallet := 63
	var tier := 1
	var total := 0.0
	for stage in 12:
		var s := C.fresh(stage, tier, wallet)
		print("INITIAL_VALID ", stage, " ", C.valid(s), " json=", C.valid(JSON.parse_string(JSON.stringify(s))), " definition=", D.valid(s.definition))
		if not C.valid(s):
			quit(1)
			return
		if C.cost(s) > 0:
			C.purchase(s)
		var retries := 0
		for frame in 180000:
			if s.phase == "victory":
				break
			if s.phase == "defeat":
				retries += 1
				C.retry(s)
			C.step(s, P.direction(s), 1.0 / 60)
			if frame % 3600 == 0:
				print("PROGRESS stage", stage, " time", s.time, " wave", s.wave, " alive", C.active(s).size(), " hp", s.hp, " point", C.p(s))
		print("STAGE_RESULT ", stage, " ", s.phase, " time=", s.time, " hits=", s.hits, " retries=", retries, " valid=", C.valid(s), " wallet=", s.wallet)
		if s.phase != "victory" or not C.valid(s):
			var f := FileAccess.open("res://.artifacts/failed-stage.json", FileAccess.WRITE)
			f.store_string(JSON.stringify(s, "  "))
			f.close()
			quit(1)
			return
		wallet = s.wallet
		tier = s.tier
		total += s.time
	print("CAMPAIGN_SIMULATED_TOTAL ", total)
	quit()
