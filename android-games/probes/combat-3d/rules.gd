extends RefCounted

static func initial_state() -> Dictionary:
	return {"version": 1, "x": 0.0, "z": 0.0, "health": 100.0, "kills": 0, "elapsed": 0.0, "spawn": 0.0, "shot": 0.0, "serial": 0, "enemies": [], "result": "playing"}

static func step(state: Dictionary, movement: Vector2, delta: float) -> void:
	if state["result"] != "playing" or delta <= 0.0:
		return
	var dt := minf(delta, 0.1)
	var direction := movement.limit_length(1.0)
	state["x"] = clampf(state["x"] + direction.x * dt * 4.2, -6.5, 6.5)
	state["z"] = clampf(state["z"] + direction.y * dt * 4.2, -9.0, 9.0)
	state["elapsed"] += dt
	state["spawn"] -= dt
	state["shot"] -= dt
	if state["spawn"] <= 0.0:
		state["serial"] += 1
		var angle: float = float(state["serial"]) * 2.399963
		state["enemies"].append({"id": state["serial"], "x": cos(angle) * 7.5, "z": sin(angle) * 10.0})
		state["spawn"] = maxf(0.45, 1.7 - float(state["kills"]) * 0.03)
	var player := Vector2(state["x"], state["z"])
	var nearest := -1
	var nearest_distance := 4.3
	for index in range(state["enemies"].size()):
		var enemy: Dictionary = state["enemies"][index]
		var position := Vector2(enemy["x"], enemy["z"])
		var distance := player.distance_to(position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
		if distance < 0.8:
			state["health"] = maxf(0.0, state["health"] - dt * 24.0)
		else:
			position += position.direction_to(player) * dt * (1.55 + minf(0.8, float(state["kills"]) * 0.015))
			enemy["x"] = position.x
			enemy["z"] = position.y
	if nearest >= 0 and state["shot"] <= 0.0:
		state["enemies"].remove_at(nearest)
		state["kills"] += 1
		state["shot"] = 0.7
	if state["health"] <= 0.0:
		state["result"] = "defeat"
	elif state["kills"] >= 30:
		state["result"] = "victory"

static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in initial_state().keys():
		if not value.has(key):
			return false
	if value["version"] != 1 or not value["enemies"] is Array or value["enemies"].size() > 200:
		return false
	for key in ["x", "z", "health", "kills", "elapsed", "spawn", "shot", "serial"]:
		if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])):
			return false
	if absf(value["x"]) > 6.5 or absf(value["z"]) > 9.0 or value["health"] < 0 or value["health"] > 100:
		return false
	if value["kills"] < 0 or value["kills"] > 30 or value["elapsed"] < 0 or value["serial"] < 0:
		return false
	if not value["result"] in ["playing", "victory", "defeat"]:
		return false
	for enemy in value["enemies"]:
		if not enemy is Dictionary:
			return false
		for key in ["id", "x", "z"]:
			if not enemy.has(key) or not (enemy[key] is int or enemy[key] is float) or not is_finite(float(enemy[key])):
				return false
	return true

static func restore(value: Variant) -> Dictionary:
	if not valid(value):
		return {}
	var state: Dictionary = value.duplicate(true)
	for key in ["version", "kills", "serial"]:
		state[key] = int(state[key])
	for key in ["x", "z", "health", "elapsed", "spawn", "shot"]:
		state[key] = float(state[key])
	for enemy in state["enemies"]:
		enemy["id"] = int(enemy["id"])
		enemy["x"] = float(enemy["x"])
		enemy["z"] = float(enemy["z"])
	return state

