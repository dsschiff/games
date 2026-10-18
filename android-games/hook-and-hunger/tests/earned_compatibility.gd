extends SceneTree
## Authenticate historical earned exports. New continuations are CPU invariants,
## never newly earned progression or proof of graphical quality.
const S = preload("res://scripts/save_store.gd")
const E = preload("res://scripts/engine.gd")
const P = preload("res://tests/campaign_policy.gd")
const Adapter = preload("res://scripts/presentation/adapter.gd")
var rows := []
var failures := 0
var capture_dir := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://evidence/campaign-checkpoint.json"))
	for receipt in index.artifacts:
		var path: String = str(receipt.path)
		if not path.begins_with(".artifacts/campaign-code2-final/") or not path.ends_with(".json") or not (path.get_file().begins_with("stage-") or path.get_file().begins_with("arena-")):
			continue
		var result := {"path": path, "authenticated": FileAccess.get_sha256("res://" + path) == str(receipt.sha256), "decoded": false, "equivalent": false, "immutable": false}
		if result.authenticated:
			var loaded := S.decode(FileAccess.get_file_as_string("res://" + path))
			result.decoded = loaded.ok
			if loaded.ok:
				var state: Dictionary = loaded.state.duplicate(true)
				var control := state.duplicate(true)
				var view := Adapter.new()
				root.add_child(view)
				view.build(state)
				result.equivalent = true
				result.immutable = true
				for frame in 120:
					var movement := P.direction(state)
					E.step(state, movement, 1.0 / 60)
					E.step(control, movement, 1.0 / 60)
					var before := state.duplicate(true)
					view.capture(state)
					view.present(1.0 / 60)
					result.equivalent = result.equivalent and state == control
					result.immutable = result.immutable and state == before
				view.free()
				await process_frame
		if not result.authenticated or not result.decoded or not result.equivalent or not result.immutable:
			failures += 1
			push_error("Earned compatibility: " + path)
		rows.append(result)
	if rows.size() != 37:
		failures += 1
		push_error("Expected 37 historical exports")
	if not capture_dir.is_empty():
		FileAccess.open(capture_dir.path_join("earned-compatibility.json"), FileAccess.WRITE).store_string(JSON.stringify({"sources": rows, "failures": failures, "scope": "Historical authenticated earned exports; 120 synthetic continuation steps each, full-state equivalence; no new earned route or rendered evidence"}, "  "))
	print("EARNED_COMPATIBILITY: ", rows.size(), " sources; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
