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
	rows.append([seconds * 1000, int(tag.friendly), int(tag.enemies), str(tag.encounter), bool(tag.reduced_effects), draw_usec])

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
	return {"schema": 1, "metadata": metadata, "criteria": {"clock": "Time.get_ticks_usec at RenderingServer.frame_post_draw; render-loop submission intervals, not OS presentation timestamps", "warmup_eligible_seconds": warmup, "excluded": "menus, explicit pause, loading/ready states and visible modals; gaps reset before resumed samples", "heavy_filter": "friendly + enemy actors >= 120", "max_samples": MAX_SAMPLES}, "excluded_frames": excluded_frames, "all_frames": summary(rows), "heavy_frames": summary(rows.filter(func(row): return int(row[1]) + int(row[2]) >= 120)), "columns": ["frame_ms", "friendly", "enemies", "encounter", "reduced_effects", "draw_cpu_usec"], "rows": rows}
