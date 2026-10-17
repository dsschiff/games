class_name SaveStore
extends RefCounted

const Gear = preload("res://scripts/gear_rules.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const VERSION := 2
const PATH := "user://bastion-save.json"
const MAX_BYTES := 1000000

static func encode(state: Dictionary, settings: Dictionary) -> String:
	return JSON.stringify({"version": VERSION, "state": state, "settings": settings}, "", true, true)

static func decode(source: String) -> Dictionary:
	if source.length() > MAX_BYTES:
		return {"ok": false, "message": "Save is too large"}
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return {"ok": false, "message": "Invalid JSON"}
	var data = parser.data
	if not data is Dictionary or not data.has("version") or not data.has("state"):
		return {"ok": false, "message": "Invalid save"}
	if not number(data.version) or float(data.version) != int(data.version) or int(data.version) < 1 or int(data.version) > VERSION or not data.state is Dictionary:
		return {"ok": false, "message": "Unsupported save version"}
	var state: Dictionary = data.state
	var baseline := Battle.initial()
	for key in baseline:
		if not state.has(key):
			if int(data.version) == 1:
				state[key] = baseline[key]
			else:
				return {"ok": false, "message": "Incomplete save"}
	if not state.board is Array or not Gear.valid_board(state.board):
		return {"ok": false, "message": "Invalid board"}
	if not state.units is Array or not state.enemies is Array or not state.production is Dictionary or not state.projectiles is Array:
		return {"ok": false, "message": "Invalid battle"}
	for key in ["gold", "next_id", "wall", "time", "wave", "wave_time", "spawn_clock", "spawned", "serial", "seed", "kills", "produced", "peak_units", "wall_hits", "cap_time"]:
		if not number(state[key]) or absf(float(state[key])) > 100000000:
			return {"ok": false, "message": "Invalid numeric state"}
	for key in ["gold", "next_id", "wave", "spawned", "serial", "seed", "kills", "produced", "peak_units", "wall_hits"]:
		if float(state[key]) != int(state[key]):
			return {"ok": false, "message": "Invalid integer state"}
		state[key] = int(state[key])
	if int(state.next_id) < 2 or int(state.serial) < 1 or float(state.time) < 0 or float(state.wave_time) < 0 or float(state.spawn_clock) < 0 or int(state.spawned) < 0 or int(state.spawned) > 20:
		return {"ok": false, "message": "Invalid battle counters"}
	if state.units.size() > Battle.UNIT_CAP or state.enemies.size() > Battle.ENEMY_CAP or not str(state.phase) in ["ready", "battle", "victory", "defeat"]:
		return {"ok": false, "message": "Invalid battle bounds"}
	if float(state.wall) < 0 or float(state.wall) > 220 or int(state.gold) < 0 or int(state.gold) > 100000 or int(state.wave) < 0 or int(state.wave) > 3:
		return {"ok": false, "message": "Invalid resources"}
	if str(state.phase) != "ready" and int(state.wave) == 0:
		return {"ok": false, "message": "Invalid wave"}
	for p in state.board:
		for key in ["id", "x", "y", "level", "lane"]:
			p[key] = int(p[key])
		if int(p.id) >= int(state.next_id):
			return {"ok": false, "message": "Invalid piece sequence"}
	for group in [state.units, state.enemies]:
		for unit in group:
			if not unit is Dictionary:
				return {"ok": false, "message": "Invalid unit"}
			for key in ["id", "kind", "lane", "x", "y", "hp", "max_hp", "cooldown", "flash"]:
				if not unit.has(key):
					return {"ok": false, "message": "Incomplete unit"}
			for key in ["id", "lane", "x", "y", "hp", "max_hp", "cooldown", "flash"]:
				if not number(unit[key]):
					return {"ok": false, "message": "Invalid numeric unit"}
			for key in ["id", "lane"]:
				if float(unit[key]) != int(unit[key]):
					return {"ok": false, "message": "Invalid unit index"}
				unit[key] = int(unit[key])
			if not Battle.STATS.has(unit.kind) or float(unit.hp) <= 0 or float(unit.hp) > 1000 or float(unit.x) < 0 or float(unit.x) > 600 or float(unit.y) < 0 or float(unit.y) > 600:
				return {"ok": false, "message": "Invalid unit bounds"}
			if int(unit.id) < 1 or int(unit.id) >= int(state.serial) or int(unit.lane) < 0 or int(unit.lane) > 2 or float(unit.cooldown) < 0 or float(unit.cooldown) > 5:
				return {"ok": false, "message": "Invalid unit counters"}
	if state.production.size() > 20:
		return {"ok": false, "message": "Invalid production size"}
	for value in state.production.values():
		if not number(value) or float(value) < 0 or float(value) > 1:
			return {"ok": false, "message": "Invalid production value"}
	# Projectiles are transient drawing data. Rebuild on next simulation step.
	state.projectiles = []
	var settings: Dictionary = data.get("settings", {}) if data.get("settings", {}) is Dictionary else {}
	return {"ok": true, "state": state, "settings": {"muted": bool(settings.get("muted", false)), "reduced_effects": bool(settings.get("reduced_effects", false))}}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func write(state: Dictionary, settings: Dictionary, path: String = PATH) -> bool:
	var source := encode(state, settings)
	if not decode(source).ok:
		return false
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(source)
	file.flush()
	file.close()
	# A known-good backup survives an interrupted replacement or corrupt primary.
	if FileAccess.file_exists(path):
		var existing := FileAccess.get_file_as_string(path)
		if decode(existing).ok:
			var backup := FileAccess.open(path + ".bak", FileAccess.WRITE)
			if backup != null:
				backup.store_string(existing)
				backup.close()
	return DirAccess.rename_absolute(temp, path) == OK

static func read(path: String = PATH) -> Dictionary:
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			var result := decode(FileAccess.get_file_as_string(candidate))
			if result.ok:
				result["recovered"] = candidate != path
				return result
	return {"ok": false, "message": "No valid save"}
