extends "res://tests/production_passage.gd"
## Narrow CPU validation of authentic fixture decoding, capture guards and UI paths.
var fixtures := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures-dir="):
			fixtures = arg.trim_prefix("--fixtures-dir=")
	super._initialize()

func run() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/production-plan.json"))
	for key in plan.earned_sources:
		var decoded := S.decode(FileAccess.get_file_as_string(fixtures.path_join(key + ".code")))
		check(decoded.ok, "pinned accepted historical source decodes with actual unchanged save validator: " + key)
		if decoded.ok:
			check(decoded.revision == plan.earned_sources[key].revision and decoded.state.schema == plan.earned_sources[key].inventory.schema, "complete source revision/schema agrees with pinned inventory: " + key)
	var sample_rows := []
	for interval in [10.0, 20.0, 40.0, 80.0]:
		var row := []
		row.resize(18)
		row.fill(0)
		row[0] = interval
		row[3] = 7
		row[6] = 100
		row[7] = 1000
		row[9] = 200
		sample_rows.append(row)
	var arithmetic: Dictionary = sampler.summarize(sample_rows)
	check(arithmetic.frames == 4 and arithmetic.median_ms == 20 and arithmetic.p95_ms == 80 and arithmetic.p99_ms == 80 and arithmetic.over_33_333_ms == 2, "known arithmetic fixture verifies declared percentile/tail method; not measured performance")
	check(sampler.summarize([]).frames == 0, "empty timing subset does not invent percentiles")
	# Install byte-exact genuine loss only in this test's isolated userdata.
	var code := FileAccess.get_file_as_string(fixtures.path_join("loss.code"))
	var expected := S.decode(code)
	var f := FileAccess.open(S.PATH + "0", FileAccess.WRITE)
	f.store_string(code)
	f.close()
	root.size = Vector2i(720, 1280)
	await load_app()
	check(scene.state.phase == "defeat" and context_matches(expected), "normal app loads entire genuine terminal without fabricated progression")
	check(not sampler.eligible(scene), "terminal and modal state is excluded from timing")
	seconds = .15
	await retry_passage()
	await hold()
	await retain_slots("unit-retained")
	check(slot_snapshots["unit-retained"].files.size() >= 1, "production raw-slot recorder retains real app files with readback hashes")
	var held := S.read()
	var before := whole_memory()
	await dwell(8)
	check(whole_memory() == before and context_matches(held), "actual held context is stable after Retry")
	game_root.queue_free()
	await process_frame
	await process_frame
	await load_app()
	check(scene.paused and context_matches(held), "ordinary scene reload preserves whole app-written active context; separate production process is required for cold claim")
	check(not sampler.eligible(scene), "paused reload is excluded from timing")
	await start_playing()
	check(sampler.eligible(scene), "only actual unpaused playing state with no modals is timing-eligible")
	await hold()
	var file := FileAccess.open(folder.path_join("production-checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details,
		"scope": "CPU-only accepted-source/save decoder and short real-input Retry/raw-slot/scene-reload tests. Synthetic percentile arithmetic is explicitly not timing. No rendering, full campaign, GPU readback or cold-process evidence."}, "\t"))
	file.close()
	game_root.queue_free()
	await process_frame
	print("PRODUCTION_CHECKS ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
