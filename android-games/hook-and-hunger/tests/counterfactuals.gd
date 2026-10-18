extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const P = preload("res://tests/campaign_policy.gd")
var rows := []
var failures := 0

func _initialize() -> void:
	for stage in [1, 4, 11]:
		for simple in [true, false]:
			var s := C.fresh(stage, 1 if stage == 1 else (2 if stage == 4 else 3), 2000)
			var retries := 0
			for frame in 120000:
				if s.phase == "victory" or s.phase == "defeat" and simple:
					break
				if s.phase == "defeat":
					C.retry(s)
					retries += 1
				C.step(s, P.direction(s, simple), 1.0 / 60)
			var okay: bool = s.phase == "victory" if not simple else s.phase != "victory"
			if not okay:
				failures += 1
				push_error("Counterfactual did not separate policies at stage " + str(stage))
			rows.append({"stage": stage, "policy": "nearest outer reach only" if simple else "cover/flank/priority/pattern response", "result": s.phase, "wave": s.wave, "time": s.time, "hits": s.hits, "rescues": retries, "cleared": s.dead.size(), "pass": okay})
	for loadout in [1, 2, 3]:
		var s := C.fresh(11, loadout, 0, 1701, true)
		for frame in 120000:
			if s.phase == "victory":
				break
			if s.phase == "defeat":
				C.retry(s)
			C.step(s, P.direction(s), 1.0 / 60)
		if s.phase != "victory":
			failures += 1
			push_error("Arena loadout failed " + str(loadout))
		rows.append({"seed": 1701, "loadout": loadout, "result": s.phase, "time": s.time, "hits": s.hits, "rescues": s.deaths})
	var path := "res://.artifacts/counterfactuals.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			path = arg.trim_prefix("--report=")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": rows, "failures": failures, "scope": "Pure deterministic controls; positioned policy may Retry and retains earned IDs. These establish bounded tactical/efficiency differences, not human fun or universal balance."}, "  "))
	f.close()
	for row in rows:
		print(JSON.stringify(row))
	print("COUNTERFACTUALS: ", "PASS" if failures == 0 else "FAIL")
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
