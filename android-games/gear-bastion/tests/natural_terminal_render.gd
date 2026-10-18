extends SceneTree
## Late-battle rule fixtures finish in the normal process loop, without a capture redraw.
const Scene = preload("res://main.tscn")
const Battle = preload("res://scripts/battle_rules.gd")
const Policy = preload("res://tests/campaign_policies.gd")
const Files = preload("res://tests/fault_files.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func fixture(win: bool, seconds: float = -1) -> Dictionary:
	var state := Battle.initial(1701, "camp_01")
	if win:
		Policy.apply(state, "A")
	Battle.start(state)
	while state.phase == "battle" and (seconds < 0 or float(state.time) < seconds):
		Battle.tick(state, Battle.STEP)
	return state

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Natural terminal rendering needs a rendered viewport")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://.artifacts/natural-terminal")
	for win in [true, false]:
		var result := fixture(win)
		var pending := fixture(win, float(result.time) - 0.6)
		var expected: String = "victory" if win else "defeat"
		check(pending.phase == "battle" and result.phase == expected, "Rule fixture approaches " + expected)
		var game := Scene.instantiate()
		game.save_path = "user://natural-terminal-isolated.json"
		game.save_backend = Files.new()
		game.start_on_map = false
		game.settings.muted = true
		root.add_child(game)
		game.set_process(false)
		# Complete atlas initialization before measuring invalidation: a late bake
		# requests its own redraw and could otherwise mask a missing terminal event.
		while game.actor_art.atlas == null:
			await process_frame
		await process_frame
		var draws := {"phase": "", "paused": false, "count": 0}
		game.draw.connect(func():
			draws.phase = game.state.phase
			draws.paused = game.paused
			draws.count += 1
		)
		game.state = pending
		game.paused = false
		game.screen = "game"
		game.accumulator = 0.0
		game.save_clock = 0.0
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(draws.phase == "battle", "Initial battle frame painted before natural " + expected)
		game.set_process(true)
		var deadline := Time.get_ticks_msec() + 5000
		while game.state.phase == "battle" and Time.get_ticks_msec() < deadline:
			await process_frame
		# Nothing below requests redraw. The game must invalidate its terminal frame.
		await process_frame
		await RenderingServer.frame_post_draw
		check(game.state.phase == expected and draws.phase == expected, "Natural " + expected + " paints its terminal overlay before further input")
		root.get_texture().get_image().save_png("res://.artifacts/natural-terminal/" + expected + "-untouched.png")
		var settled: int = draws.count
		for i in 4:
			await process_frame
		check(int(draws.count) == settled, "Terminal " + expected + " keeps event-driven idle rendering")
		check(game.buttons().has("next") if win else game.buttons().has("begin"), "Terminal navigation is available for " + expected)
		game.set_process(false)
		game.queue_free()
		await process_frame
	print("NATURAL TERMINAL RENDER: ", checks, " checks; ", failures.size(), " failures")
	print("SUITE_COMPLETE: PASS" if failures.is_empty() else "SUITE_COMPLETE: FAIL")
	quit(0 if failures.is_empty() else 1)
