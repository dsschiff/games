extends "res://tests/input_base.gd"
const Challenge = preload("res://scripts/challenge_v1.gd")
var native_requests := 0

func _initialize() -> void:
	rendered = DisplayServer.get_name() != "headless"
	folder = "res://.artifacts/code4/back-" + ("rendered" if rendered else "headless")
	if not OS.get_environment("TOWER_BACK_EVIDENCE").is_empty(): folder = OS.get_environment("TOWER_BACK_EVIDENCE")
	test_path = "user://tower-code4-back.json"
	call_deferred("run")

func native_back() -> void:
	root.go_back_requested.emit()
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	native_requests += 1
	await wait_frames(3)
	check(is_instance_valid(game) and game.is_inside_tree(), "Window Back request keeps application scene alive")

func modal_sequence(kind: String) -> void:
	var before: Dictionary = game.state.duplicate(true)
	var challenge_before: Dictionary = game.data.challenge_run.duplicate(true)
	var campaign_before := {"profile": game.data.profile.duplicate(true), "settings": game.data.settings.duplicate(true), "actions": game.data.actions.duplicate(), "catalog": game.data.catalog, "level_id": game.data.level_id, "used_undo": game.data.used_undo}
	await action("settings")
	await native_back()
	check(not game.menu and not game.paused and game.screen == "game" and game.state == before, kind + " Back closes Settings before pause/map")
	await action("settings")
	await action("transfer")
	await native_back()
	check(not game.transfer and not game.editor.visible and game.menu and not game.paused and game.state == before, kind + " Back closes transfer first")
	await native_back()
	check(not game.menu and not game.paused, kind + " subsequent Back closes parent Settings")
	await action("settings")
	await action("guide")
	await native_back()
	check(not game.guide and game.menu and not game.paused and game.state == before, kind + " Back closes guide first")
	await native_back()
	check(not game.menu and not game.paused, kind + " guide parent Settings closes next")
	var next_room: String = "rope" if kind == "campaign" else Challenge.search(game.level, game.state).route[0]
	await choose(next_room)
	await action("details")
	await native_back()
	check(not game.details and not game.paused and game.state == before, kind + " Back closes forecast first")
	await frame(kind + "-modals-closed")
	await native_back()
	check(game.paused and game.screen == "game" and game.state == before, kind + " first gameplay Back pauses without changing whole state")
	await frame(kind + "-back-paused")
	await native_back()
	check(game.screen == "map", kind + " second gameplay Back opens campaign map")
	if kind == "campaign":
		check(game.state == before, "Campaign map keeps active route")
	else:
		check(game.data.kind == "campaign" and game.data.challenge_run == challenge_before, "Challenge Back keeps exact pinned run when returning to campaign")
	check(game.data.profile == campaign_before.profile and game.data.settings == campaign_before.settings and game.data.actions == campaign_before.actions and game.data.catalog == campaign_before.catalog and game.data.level_id == campaign_before.level_id and game.data.used_undo == campaign_before.used_undo, kind + " Back preserves campaign history/profile/settings")
	await action("resume")
	if kind == "challenge":
		await action("settings")
		await action("challenge_select")
		await action("resume_challenge")
		check(game.state == before and game.data.challenge_run == challenge_before, "Challenge resumes exact state after Back/map navigation")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(test_path + suffix)
	await create_game()
	check(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false, "Project startup Back policy explicitly disables default quit")
	check(quit_on_go_back == false and auto_accept_quit == false, "Runtime SceneTree disables Back-to-quit and automatic close")
	await enter("bell")
	var campaign: Dictionary = game.state.duplicate(true)
	await modal_sequence("campaign")
	await action("settings")
	await action("challenge_select")
	await action("generate")
	var id: String = game.data.challenge_run.bundle.witness[0]
	await enter(id)
	await modal_sequence("challenge")
	await action("map")
	check(game.state == campaign, "Whole original campaign route survives native-request navigation in both modes")
	var file := FileAccess.open(folder + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "window_back_requests": native_requests, "actual_touch_taps": taps, "captures": captures, "scope": "Desktop root Window.go_back_requested signal (default quit policy) plus explicit WM_GO_BACK_REQUEST notification propagation (navigation); not actual Android KEYCODE_BACK/gesture or phone evidence"}, "\t"))
	file.close()
	print("CODE4 BACK: %d checks; %d failures; %d window requests" % [checks, failures.size(), native_requests])
	game.queue_free()
	await wait_frames(3)
	if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
