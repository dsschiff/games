extends SceneTree
const Store = preload("res://scripts/save_store.gd")
const Fault = preload("res://tests/fault_files.gd")
const Challenge = preload("res://scripts/challenge_v1.gd")
var checks := 0
var failures: Array = []
var rows: Array = []
var folder := "res://.artifacts/save-commit"

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        printerr("FAIL: " + label)

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="): folder = arg.trim_prefix("--capture-dir=")
    call_deferred("run")

func run() -> void:
    var source := FileAccess.get_file_as_string("res://tests/fixtures/save-commit-before.json")
    var earned := Store.decode(source)
    check(earned.ok and earned.state.status == "won" and earned.data.profile.size() == 2, "Actual input-earned complete campaign fixture decodes")
    var pinned: Dictionary = earned.data.duplicate(true)
    var bundle: Dictionary = Challenge.generate("key", 137, {"weave": 0, "treasure": true}).bundle
    pinned.kind = "challenge"
    pinned.challenge_run = {"bundle": bundle, "actions": [bundle.witness[0]], "used_undo": true}
    check(Store.decode(Store.encode(pinned)).ok, "Separately labelled generated challenge variant retains earned campaign context")
    for label in ["earned-campaign", "generated-challenge-with-earned-campaign"]:
        var before: Dictionary = earned.data if label == "earned-campaign" else pinned
        for only_staged in [false, true]:
            for destination in ["primary", "backup"]:
                if only_staged and destination == "primary": continue
                for mode in ["rename_missing", "rename_corrupt", "rename_wrong_valid"]:
                    var io := Fault.new()
                    var original: Dictionary = before.duplicate(true)
                    original.revision = 7
                    var old_source := Store.encode(original)
                    io.files["save.bak.tmp" if only_staged else "save"] = old_source
                    if destination == "primary": io.files["save.bak"] = old_source
                    var imported: Dictionary = before.duplicate(true)
                    imported.settings.sound = not imported.settings.sound
                    imported.settings.reduced_effects = not imported.settings.reduced_effects
                    imported.used_undo = not imported.used_undo
                    var original_import: Dictionary = imported.duplicate(true)
                    var wrong_valid: Dictionary = original.duplicate(true)
                    wrong_valid.revision = 2
                    io.rename_replacement = Store.encode(wrong_valid)
                    io.fail_suffix = "save.tmp" if destination == "primary" else "save.bak.tmp"
                    io.fail_mode = mode
                    var returned := Store.write(imported, "save", io, false)
                    var restored := Store.read("save", io)
                    var case_label := "%s/%s/%s/%s" % [label, "staged-only" if only_staged else "primary-present", destination, mode]
                    check(not returned, case_label + ": false rename success is reported as failed commit")
                    check(restored.ok and restored.source == old_source, case_label + ": cold read preserves entire previous context byte-for-byte")
                    check(imported == original_import, case_label + ": failed write never mutates caller import context")
                    if destination == "backup":
                        check(not "save.tmp" in io.written_paths, case_label + ": unverified backup stops before staging import")
                    rows.append({"case": case_label, "returned": returned, "cold_ok": restored.ok, "preserved_source": restored.get("source", "") == old_source, "writes": io.write_count, "renames": io.rename_count})
    # Existing staged-only recovery and successful post-readback commit.
    var io := Fault.new()
    var old: Dictionary = earned.data.duplicate(true)
    old.revision = 7
    io.files["save.bak.tmp"] = Store.encode(old)
    io.fail_suffix = "save.bak.tmp"
    io.fail_mode = "write"
    check(Store.write(earned.data, "save", io), "Sole staged backup is reused without truncating it")
    check(Store.read("save", io).ok and Store.read("save", io).data.revision == 8, "Verified primary commit remains recoverable at next revision")
    var file := FileAccess.open(folder + "/save-commit-result.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": rows, "fixture_sha256": source.sha256_text(), "scope": "CPU real Store/fault backend. Earned campaign fixture provenance separate from generated challenge variant. No native or UI fault claim."}, "\t"))
    file.close()
    print("TOWER SAVE COMMIT: %d checks; %d failures" % [checks, failures.size()])
    if failures.is_empty(): print("SUITE_COMPLETE: PASS")
    quit(0 if failures.is_empty() else 1)
