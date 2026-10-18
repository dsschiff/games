extends "res://tests/campaign_input.gd"

func notify(what: int, descendants: bool = false) -> void:
	if descendants: scene.propagate_notification(what)
	else: scene.notification(what)
	events.append({"frame": Engine.get_physics_frames(), "kind": "synthetic_engine_notification", "what": what, "descendants": descendants})

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	await click(scene.stage_buttons[0].text)
	await click("START RESCUE")
	var rev: int = Store.read().revision
	notify(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(scene.paused and Store.read().revision == rev + 1, "engine Back notification pauses exactly once across script inheritance")
	await click("SAVE / TRANSFER")
	rev = Store.read().revision
	notify(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not scene.transfer.visible and scene.paused and Store.read().revision == rev, "engine Back closes transfer only, without second hidden pause toggle")
	notify(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not scene.paused and Store.read().revision == rev + 1, "next engine Back resumes exactly once")
	await dwell(15)
	rev = Store.read().revision
	notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(scene.paused and Store.read().revision == rev + 1, "application pause notification stores exactly one whole active context")
	var before: Dictionary = scene.ctx.duplicate(true)
	await dwell(30)
	check(Data.same(scene.ctx, before), "background notification leaves whole context paused")
	await click("EVACUATION MAP")
	rev = Store.read().revision
	notify(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not scene.journey_visible and scene.paused and Store.read().revision == rev, "Back from map closes map only and retains underlying pause")
	await click("EVACUATION MAP")
	await click("LEGACY CANAL BRIDGE")
	await dwell(5)
	before = scene.ctx.campaign.duplicate(true)
	rev = Store.read().revision
	notify(Node.NOTIFICATION_WM_GO_BACK_REQUEST, true)
	check(scene.legacy_view.paused and Store.read().revision == rev + 1 and Data.same(scene.ctx.campaign, before), "propagated Back reaches legacy exactly once while parked campaign is guarded")
	check(not quit_on_go_back and not auto_accept_quit, "native Back/close autoquit remains disabled")
	await snap("platform-notification-paused-legacy")
	write_report_campaign("Synthetic ENGINE notification dispatch through real Godot script inheritance, after actual GUI Start/menu input. Not actual Android Back/Home or OS lifecycle evidence. Captures notification double-dispatch sensitivity without invoking gameplay handlers.")
	scene.queue_free()
	await process_frame
	print("PLATFORM_NOTIFICATIONS ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
