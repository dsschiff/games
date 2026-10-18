extends "res://tests/campaign_input.gd"
const Copy = preload("res://scripts/copy_confirm.gd")
const BackendFault = preload("res://tests/clipboard_fault.gd")

func run() -> void:
	var service := Copy.new()
	var fake := BackendFault.new()
	service.backend = fake
	fake.delay_reads = 3
	service.begin("delayed code")
	check(service.pending and service.feedback.begins_with("Copy requested"), "copy request is pending, never prematurely called unavailable")
	for i in 6: service.poll(0.09)
	check(not service.pending and service.feedback == "Copied checked rescue save.", "bounded polling confirms eventual delayed success")
	fake.write_ok = false
	service.begin("refused code")
	check(not service.pending and service.feedback.begins_with("Copy failed"), "explicit backend refusal reports real write failure")
	fake.write_ok = true
	fake.never_echo = true
	service.begin("unconfirmed code")
	for i in 10: service.poll(0.09)
	check(not service.pending and service.feedback.begins_with("Copy not confirmed"), "bounded mismatch reports unconfirmed, not definitive unavailability")
	fake.never_echo = false
	fake.delay_reads = 0
	service.begin("old request")
	fake.reenter = func(): service.begin("new request")
	service.poll(0.1)
	check(service.pending and service.expected == "new request" and service.feedback.begins_with("Copy requested"), "stale old poll cannot overwrite newer Export feedback")
	service.poll(0.1)
	check(service.feedback == "Copied checked rescue save." and service.expected == "new request", "new request confirms its own bytes")
	service.begin("cancelled")
	service.cancel()
	check(not service.poll(1.0), "cancelled request cannot publish stale feedback")
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	await click(scene.stage_buttons[0].text)
	await click("START RESCUE")
	await dwell(130)
	await click("II")
	await click("SAVE / TRANSFER")
	var before: Dictionary = scene.ctx.duplicate(true)
	await click("EXPORT / COPY")
	var code: String = scene.code_box.text
	await dwell(45)
	check(Store.decode(code).ok, "actual Export encodes whole checked campaign plus parked legacy")
	if "--os-clipboard-locked" in OS.get_cmdline_user_args():
		check(scene.transfer_status.text.begins_with("Copy not confirmed"), "real Windows OS exclusion cannot falsely confirm failed clipboard write")
		check(Data.same(scene.ctx, before), "real clipboard failure does not mutate gameplay")
		await snap("real-os-clipboard-failure-unconfirmed")
		write("release-clipboard-lock.request", {"request": true})
		for frame in 300:
			if FileAccess.file_exists(folder.path_join("clipboard-lock.released")): break
			await physics_frame
		check(FileAccess.file_exists(folder.path_join("clipboard-lock.released")), "bounded real clipboard exclusion releases before retry")
		await click("EXPORT / COPY")
		code = scene.code_box.text
		await dwell(45)
	if DisplayServer.get_name() == "headless":
		check(scene.transfer_status.text.begins_with("Clipboard unavailable"), "real headless capability failure is reported honestly")
	else:
		check(scene.transfer_status.text == "Copied checked rescue save." and DisplayServer.clipboard_get() == code, "real Windows eventual confirmation matches actual clipboard bytes")
		await click("PASTE")
		check(scene.code_box.text == code, "real actual Paste reads exported code")
		var previous_revision: int = Store.read().revision
		await click("IMPORT")
		check(scene.transfer_status.text.begins_with("Imported") and Store.read().revision > previous_revision and Data.same(scene.ctx, before), "real copied code imports a fresh durable whole-context commit")
	# Explicit denied/unconfirmed backends exercise GUI feedback without touching OS clipboard.
	fake = BackendFault.new()
	fake.write_ok = false
	scene.copy_service.backend = fake
	await click("EXPORT / COPY")
	check(scene.transfer_status.text.begins_with("Copy failed"), "GUI reflects explicit backend failure without false success")
	fake.write_ok = true
	fake.delay_reads = 2
	await click("EXPORT / COPY")
	await dwell(40)
	check(scene.transfer_status.text == "Copied checked rescue save.", "GUI eventually confirms delayed backend success")
	fake.never_echo = true
	await click("EXPORT / COPY")
	await dwell(45)
	check(scene.transfer_status.text.begins_with("Copy not confirmed"), "GUI timeout keeps honest unconfirmed feedback")
	await tap(scene.code_box.get_global_rect().position + Vector2(20, 20))
	await key(KEY_A, true)
	await key(KEY_X, false, 120)
	var disk := Store.read()
	await click("IMPORT")
	check(scene.transfer_status.text.begins_with("Invalid") and Data.same(scene.ctx, before) and Store.read().revision == disk.revision, "typed INVALID code preserves complete live/durable journey")
	await dwell(60)
	check(scene.transfer_status.text.begins_with("Invalid"), "older pending Export cannot overwrite later Import feedback")
	await snap("clipboard-feedback-final")
	write_report_campaign("Dedicated bounded-copy tests. Real Windows Copy/Paste runs only under the coordinator's exclusive clipboard window. Explicit delayed/refused/stale backends are labelled synthetic API-contract fixtures. No progress injection.")
	scene.queue_free()
	await process_frame
	print("CLIPBOARD ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
