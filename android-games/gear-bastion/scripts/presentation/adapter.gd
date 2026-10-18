extends RefCounted
## Detached snapshots, fixed-step interpolation and bounded effect identity.
var epoch := 0
var previous: Dictionary = {}
var current: Dictionary = {}
var last_time := -1.0
var elapsed := 0.0
var interval := 1.0 / 30.0
var phase := "ready"
var paused := false
var seen: Dictionary = {}
var seen_order: Array[String] = []

func reset(state: Dictionary, held: bool) -> void:
	epoch += 1
	current = snapshot(state)
	previous = current.duplicate(true)
	last_time = float(state.time)
	elapsed = interval
	phase = str(state.phase)
	paused = held
	seen.clear()
	seen_order.clear()

func ingest(state: Dictionary, dt: float) -> void:
	if current.is_empty() or float(state.time) < last_time:
		reset(state, paused)
		return
	if float(state.time) > last_time:
		previous = current
		current = snapshot(state)
		interval = maxf(.001, dt)
		elapsed = 0
		last_time = float(state.time)
	else:
		current = snapshot(state)
	phase = str(state.phase)

func advance(dt: float) -> float:
	if not paused:
		elapsed = minf(interval, elapsed + dt)
	return clampf(elapsed / interval, 0, 1)

func accept(event: Dictionary) -> bool:
	var key := "%d:%s:%s:%s" % [epoch, event.attack, event.kind, event.target]
	if seen.has(key):
		return false
	seen[key] = true
	seen_order.append(key)
	if seen_order.size() > 1024:
		seen.erase(seen_order.pop_front())
	return true

static func snapshot(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for friendly in [true, false]:
		for unit in (state.units if friendly else state.enemies):
			var key := ("ally:" if friendly else "enemy:") + str(int(unit.id))
			result[key] = {"key": key, "role": str(unit.kind), "friendly": friendly,
				"point": Vector2(float(unit.x), float(unit.y)), "hp": float(unit.hp), "max_hp": float(unit.max_hp),
				"deploy_left": float(unit.get("deploy_left", 0)), "deploy_total": float(unit.get("deploy_total", 1)),
				"deploy_x": int(unit.get("deploy_x", 0)), "deploy_y": int(unit.get("deploy_y", 0)), "lane": int(unit.lane)}
	return result
