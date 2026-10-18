extends RefCounted
## Opt-in local render-loop timing, never network telemetry.
var enabled := false
var rows: Array = []
var metadata: Dictionary = {}
var last_usec := 0
var warm_seconds := 0.0
var excluded_frames := 0
var warmup := 1.5
const MAX_SAMPLES := 30000

func start(extra: Dictionary = {}) -> void:
	rows.clear()
	last_usec = 0
	warm_seconds = 0
	excluded_frames = 0
	metadata = {"device_model": OS.get_model_name(), "os": OS.get_name(), "os_version": OS.get_version(), "godot": Engine.get_version_info().string, "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "started_unix": Time.get_unix_time_from_system()}
	metadata["render_device"] = RenderingServer.get_video_adapter_name()
	metadata["render_vendor"] = RenderingServer.get_video_adapter_vendor()
	metadata["command_line"] = Array(OS.get_cmdline_args())
	# Godot strips its engine flags from OS.get_cmdline_args(). Use the actual
	# writer state plus the runner's explicit fixed-rate marker instead.
	metadata["movie_writer_path"] = Engine.get_write_movie_path()
	var capture_fps := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-fixed-fps="):
			capture_fps = int(argument.trim_prefix("--capture-fixed-fps="))
	metadata["fixed_cadence_capture"] = not Engine.get_write_movie_path().is_empty() or capture_fps > 0
	metadata["capture_fixed_fps"] = capture_fps
	metadata["counter_scope"] = "SubViewport visible 3D draw calls/primitives; shadow passes excluded; node count is process-wide"
	metadata["draw_cpu_usec_scope"] = "Main 2D draw callback CPU elapsed only; excludes complete 3D/GPU rendering"
	metadata.merge(extra, true)
	enabled = true

func sample(now_usec: int, eligible: bool, tag: Dictionary, draw_usec: int = 0) -> void:
	if not enabled:
		return
	if not eligible:
		excluded_frames += 1
		last_usec = 0
		return
	if last_usec == 0:
		last_usec = now_usec
		return
	var seconds := float(now_usec - last_usec) / 1000000.0
	last_usec = now_usec
	warm_seconds += seconds
	if warm_seconds <= warmup or rows.size() >= MAX_SAMPLES:
		return
	rows.append([seconds * 1000, int(tag.friendly), int(tag.enemies), str(tag.encounter), bool(tag.reduced_effects), draw_usec, int(tag.get("draw_calls",0)), int(tag.get("primitives",0)), int(tag.get("nodes",0)), tag.get("render_size",[])])

func summary(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"frames": 0, "seconds": 0.0, "median_ms": null, "p95_ms": null, "p99_ms": null}
	var intervals: Array = samples.map(func(row): return float(row[0]))
	intervals.sort()
	var seconds := 0.0
	var slow_60 := 0
	var slow_30 := 0
	for value in intervals:
		seconds += float(value) / 1000
		slow_60 += 1 if float(value) > 16.667 else 0
		slow_30 += 1 if float(value) > 33.333 else 0
	return {"frames": intervals.size(), "seconds": seconds, "median_ms": intervals[floori((intervals.size() - 1) * 0.5)], "p95_ms": intervals[ceili(intervals.size() * 0.95) - 1], "p99_ms": intervals[ceili(intervals.size() * 0.99) - 1], "over_16_667_ms": slow_60, "over_33_333_ms": slow_30}

func stop() -> Dictionary:
	enabled = false
	return {"schema": 2, "metadata": metadata, "criteria": {"clock": "Time.get_ticks_usec at RenderingServer.frame_post_draw; render-loop submission intervals, not OS presentation timestamps", "warmup_eligible_seconds": warmup, "excluded": "menus, explicit pause, loading/ready states and visible modals; gaps reset before resumed samples", "heavy_filter": "friendly + enemy actors >= 120", "max_samples": MAX_SAMPLES}, "excluded_frames": excluded_frames, "all_frames": summary(rows), "heavy_frames": summary(rows.filter(func(row): return int(row[1]) + int(row[2]) >= 120)), "columns": ["frame_ms", "friendly", "enemies", "encounter", "reduced_effects", "draw_cpu_usec", "draw_calls_3d", "primitives_3d", "nodes_process", "render_size"], "rows": rows}
