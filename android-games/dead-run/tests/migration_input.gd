extends "res://tests/campaign_input.gd"
const OldStore = preload("res://scripts/save_store.gd")
const Faults = preload("res://tests/fault_files.gd")
var fixture_path := ""
func _initialize() -> void:
	super._initialize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-fixture="): fixture_path = arg.trim_prefix("--legacy-fixture=")

func run() -> void:
	root.size = Vector2i(720, 1280)
	var original := OldStore.decode(FileAccess.get_file_as_string(fixture_path))
	check(original.ok and original.revision == 384 and original.state.tick == 103, "migration launch uses actual native earned code1 fixture")
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(8)
	check(scene.ctx.mode == "legacy" and is_instance_valid(scene.legacy_view) and scene.legacy_view.paused, "real schema1 startup selects parked legacy and starts active run paused")
	check(Data.same(scene.ctx.legacy, original.state) and Data.same(scene.legacy_view.state, original.state) and scene.ctx.settings == original.settings, "entire actual native legacy body/settings unchanged before input")
	check(scene.ctx.profile.clears.is_empty() and scene.ctx.profile.medals.is_empty() and scene.ctx.campaign.phase == "ready", "old native active run creates no invented campaign progress")
	var migrated := Store.read()
	check(migrated.ok and not migrated.migrated and migrated.revision > 384 and Data.same(migrated.context.legacy, original.state), "app writes new checked schema2 with exact parked legacy meaning")
	await snap("legacy-code1-migrated-before-input")
	var host := scene
	scene = host.legacy_view
	await click("RESUME")
	await dwell(20)
	await click("II")
	check(scene.state.tick > 103 and scene.state.phase == "playing", "actual Resume advances real old pinned run instead of resetting it")
	var active: Dictionary = scene.state.duplicate(true)
	await click("EVACUATION MAP")
	scene = host
	await dwell(4)
	check(scene.ctx.mode == "campaign" and Data.same(scene.ctx.legacy, active) and scene.ctx.settings == original.settings, "actual return to map preserves newly advanced legacy and settings")
	await click(scene.stage_buttons[0].text)
	await click("START RESCUE")
	await dwell(110)
	await click("II")
	var before: Dictionary = scene.ctx.duplicate(true)
	check(Data.same(before.legacy, active), "new campaign road parks legacy body without edits")
	await click("SAVE / TRANSFER")
	var code := Store.encode(before, Store.read().revision)
	scene.code_box.text = code
	var denied := Faults.new()
	denied.fail_rename = true
	scene.files = denied
	await click("IMPORT")
	check(scene.transfer_status.text.begins_with("Import could not") and Data.same(scene.ctx, before), "failed durable schema2 import leaves whole live context unchanged")
	scene.files = null
	await click("IMPORT")
	check(scene.transfer_status.text.begins_with("Imported") and Data.same(scene.ctx, before) and Store.read().ok, "successful import durably promotes complete campaign and parked legacy")
	await click("CLOSE TRANSFER")
	var saved := Store.read()
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(scene.paused and Data.same(scene.ctx, saved.context), "whole schema2 active campaign and genuine legacy survive scene restore paused")
	await snap("legacy-and-campaign-restored")
	write_report_campaign("Real code1 native fixture copied into isolated APPDATA before engine launch. Migration/Resume/menu/import tests use actual GUI events. This is desktop schema migration, not Android install-r. Fault adapter and code-box transfer text are labelled fixtures; no fabricated campaign clears.")
	scene.queue_free()
	await process_frame
	print("MIGRATION ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
