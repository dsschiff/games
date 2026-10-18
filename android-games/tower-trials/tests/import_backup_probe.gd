extends SceneTree
## Standalone review diagnostic, not a passing release suite or runtime mutation.
const Saves = preload("res://scripts/save_store.gd")
const Fault = preload("res://tests/fault_files.gd")

func _initialize() -> void:
	var io := Fault.new()
	var data := Saves.fresh()
	data.actions = ["bell"]
	var baseline := Saves.write(data, "save", io)
	var imported := data.duplicate(true)
	imported.actions.append("rope")
	var accepted := Saves.write(imported, "save", io, false)
	var committed := Saves.read("save", io)
	var subsequent := Saves.write(imported, "save", io)
	io.files["save"] = "{"
	var recovered := Saves.read("save", io)
	var result := {"baseline_written": baseline, "import_committed": accepted, "committed_primary_loads": committed.ok, "subsequent_write": subsequent, "corrupt_primary_recovers_import_backup": recovered.ok, "bug_observed": baseline and accepted and committed.ok and subsequent and not recovered.ok, "expected": "The committed import becomes a valid backup. Only an uncommitted .tmp import must be ignored.", "scope": "In-memory filesystem fault probe; reviewed runtime kept frozen"}
	DirAccess.make_dir_recursive_absolute("res://.artifacts/preparation")
	var file := FileAccess.open("res://.artifacts/preparation/import-backup-probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print(JSON.stringify(result))
	quit()
