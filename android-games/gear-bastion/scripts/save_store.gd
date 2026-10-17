class_name SaveStore
extends RefCounted

const Gear = preload("res://scripts/gear_rules.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const Files = preload("res://scripts/save_files.gd")
const Content = preload("res://scripts/campaign_data.gd")
const Profile = preload("res://scripts/campaign_profile.gd")
const VERSION := 4
const PATH := "user://bastion-save.json"
const MAX_BYTES := 1000000

static func encode(state: Dictionary, settings: Dictionary, revision: int = 0, recoverable: bool = true, profile: Dictionary = {}) -> String:
	return JSON.stringify({"version": VERSION, "revision": revision, "recoverable": recoverable, "active_run": state, "profile": Profile.fresh() if profile.is_empty() else profile, "settings": settings}, "", true, true)

static func portable(state: Dictionary, settings: Dictionary, profile: Dictionary) -> String:
	var bytes := encode(state, settings, 0, true, profile).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return "GB4:" + Marshalls.raw_to_base64(bytes)

static func decode(source: String) -> Dictionary:
	if source.length() > MAX_BYTES:
		return {"ok": false, "message": "Save is too large"}
	if source.begins_with("GB4:"):
		var payload := source.trim_prefix("GB4:").strip_edges()
		var base64_pattern := RegEx.create_from_string("^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")
		if payload.is_empty() or base64_pattern.search(payload) == null:
			return {"ok": false, "message": "Invalid save code"}
		var compressed := Marshalls.base64_to_raw(payload)
		if compressed.size() < 18 or compressed[0] != 31 or compressed[1] != 139:
			return {"ok": false, "message": "Invalid save code"}
		var bytes := compressed.decompress_dynamic(MAX_BYTES, FileAccess.COMPRESSION_GZIP)
		if bytes.is_empty():
			return {"ok": false, "message": "Invalid compressed save"}
		source = bytes.get_string_from_utf8()
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return {"ok": false, "message": "Invalid JSON"}
	var data = parser.data
	if data is Dictionary and number(data.get("version", 0)) and int(data.get("version", 0)) == 4 and data.has("active_run"):
		data["state"] = data.active_run
	if not data is Dictionary or not data.has("version") or not data.has("state"):
		return {"ok": false, "message": "Invalid save"}
	if not number(data.version) or float(data.version) != int(data.version) or int(data.version) < 1 or int(data.version) > VERSION or not data.state is Dictionary:
		return {"ok": false, "message": "Unsupported save version"}
	var state: Dictionary = data.state
	var baseline := Battle.initial()
	for key in baseline:
		if not state.has(key):
			if int(data.version) == 1 or (int(data.version) == 2 and key in ["encounter", "spent", "production_last_id", "losses"]) or (int(data.version) <= 3 and key in ["config", "boss_spawned", "produced_by_role", "lost_by_role", "wave_times", "claimed_grants", "boss_phase", "boss_clock", "boss_total", "boss_volley", "rally"]):
				state[key] = baseline[key]
			else:
				return {"ok": false, "message": "Incomplete save"}
	if not state.board is Array or not Gear.valid_board(state.board):
		return {"ok": false, "message": "Invalid board"}
	if not state.units is Array or not state.enemies is Array or not state.production is Dictionary or not state.projectiles is Array:
		return {"ok": false, "message": "Invalid battle"}
	if not state.config is Dictionary or (not state.config.is_empty() and not Content.valid_snapshot(state.config)):
		return {"ok": false, "message": "Invalid saved encounter snapshot"}
	if not str(state.encounter) in ["tutorial", "iron_trial"] and not state.encounter in Content.IDS:
		return {"ok": false, "message": "Invalid encounter"}
	if state.encounter in Content.IDS and (state.config.is_empty() or state.config.id != state.encounter):
		return {"ok": false, "message": "Encounter snapshot mismatch"}
	for key in ["gold", "spent", "losses", "production_last_id", "next_id", "wall", "time", "wave", "wave_time", "spawn_clock", "spawned", "serial", "seed", "kills", "produced", "peak_units", "wall_hits", "cap_time"]:
		if not number(state[key]) or absf(float(state[key])) > 100000000:
			return {"ok": false, "message": "Invalid numeric state"}
	for key in ["gold", "spent", "losses", "production_last_id", "next_id", "wave", "spawned", "serial", "seed", "kills", "produced", "peak_units", "wall_hits"]:
		if float(state[key]) != int(state[key]):
			return {"ok": false, "message": "Invalid integer state"}
		state[key] = int(state[key])
	if int(state.next_id) < 2 or int(state.serial) < 1 or float(state.time) < 0 or float(state.wave_time) < 0 or float(state.spawn_clock) < 0 or int(state.spawned) < 0 or int(state.spawned) > 500 or int(state.production_last_id) < 0 or int(state.spent) < 0:
		return {"ok": false, "message": "Invalid battle counters"}
	if state.units.size() > Battle.UNIT_CAP or state.enemies.size() > Battle.ENEMY_CAP or not str(state.phase) in ["ready", "battle", "victory", "defeat"]:
		return {"ok": false, "message": "Invalid battle bounds"}
	if float(state.wall) < 0 or float(state.wall) > Battle.wall_limit(state) or int(state.gold) < 0 or int(state.gold) > 100000 or int(state.wave) < 0 or int(state.wave) > Battle.run_waves(state).size():
		return {"ok": false, "message": "Invalid resources"}
	if str(state.phase) != "ready" and int(state.wave) == 0:
		return {"ok": false, "message": "Invalid wave"}
	for p in state.board:
		for key in ["id", "x", "y", "level", "lane"]:
			p[key] = int(p[key])
		if int(p.id) >= int(state.next_id):
			return {"ok": false, "message": "Invalid piece sequence"}
		if not Gear.cell_allowed(int(p.x), int(p.y), str(state.encounter), state.config):
			return {"ok": false, "message": "Socket unavailable in this encounter"}
	if state.encounter == "iron_trial" and int(state.gold) + int(state.spent) != 54:
		return {"ok": false, "message": "Invalid trial budget"}
	if not state.config.is_empty():
		var expected_grants := 0
		for index in maxi(0, int(state.wave) - 1):
			expected_grants += int(state.config.waves[index].grant)
		if not number(state.claimed_grants) or int(state.claimed_grants) != expected_grants or int(state.gold) + int(state.spent) != int(state.config.budget) + int(state.claimed_grants):
			return {"ok": false, "message": "Invalid encounter budget"}
	for key in ["boss_clock", "boss_total", "boss_volley", "boss_phase"]:
		if not number(state[key]) or float(state[key]) < 0 or float(state[key]) > 100000:
			return {"ok": false, "message": "Invalid boss state"}
	if not state.produced_by_role is Dictionary or not state.lost_by_role is Dictionary or not state.wave_times is Array or state.wave_times.size() > 8:
		return {"ok": false, "message": "Invalid run statistics"}
	if not state.boss_spawned is bool or not state.rally is bool:
		return {"ok": false, "message": "Invalid battle flags"}
	for values in [state.produced_by_role, state.lost_by_role]:
		if values.size() > 3:
			return {"ok": false, "message": "Invalid role statistics"}
		for role in values:
			if not role in ["guard", "ranger", "mortar"] or not Content.numeric(values[role], 0, 100000000, true):
				return {"ok": false, "message": "Invalid role count"}
	for value in state.wave_times:
		if not Content.numeric(value, 0, 100000000):
			return {"ok": false, "message": "Invalid wave time"}
	var actor_ids: Dictionary = {}
	for group_index in 2:
		var group: Array = state.units if group_index == 0 else state.enemies
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
			var allowed_kinds: Array = ["guard", "ranger", "mortar"] if group_index == 0 else ["beetle", "shell", "skitter", "carapace", "spitter", "swarm", "captain", "siege", "matriarch"]
			if not unit.kind in allowed_kinds or float(unit.max_hp) <= 0 or float(unit.max_hp) > 30000 or float(unit.hp) <= 0 or float(unit.hp) > float(unit.max_hp) or float(unit.x) < 0 or float(unit.x) > 600 or float(unit.y) < 0 or float(unit.y) > 600:
				return {"ok": false, "message": "Invalid unit bounds"}
			if actor_ids.has(int(unit.id)):
				return {"ok": false, "message": "Duplicate actor ID"}
			actor_ids[int(unit.id)] = true
			if unit.has("wave_damage") and not Content.numeric(unit.wave_damage, 0.1, 3):
				return {"ok": false, "message": "Invalid saved wave modifier"}
			var period: float = state.config.get("actor_stats", Battle.STATS)[unit.kind].period
			if int(unit.id) < 1 or int(unit.id) >= int(state.serial) or int(unit.lane) < 0 or int(unit.lane) > 2 or float(unit.cooldown) < 0 or float(unit.cooldown) > maxf(0.1, period):
				return {"ok": false, "message": "Invalid unit counters"}
	if state.production.size() > 20:
		return {"ok": false, "message": "Invalid production size"}
	for value in state.production.values():
		if not number(value) or float(value) < 0 or float(value) > 1:
			return {"ok": false, "message": "Invalid production value"}
	# Projectiles are transient drawing data. Rebuild on next simulation step.
	state.projectiles = []
	var settings: Dictionary = data.get("settings", {}) if data.get("settings", {}) is Dictionary else {}
	var revision: Variant = data.get("revision", 0)
	if not number(revision) or float(revision) != int(revision) or float(revision) < 0 or float(revision) > 1000000000:
		return {"ok": false, "message": "Invalid save revision"}
	if not data.get("recoverable", true) is bool:
		return {"ok": false, "message": "Invalid transaction marker"}
	if int(data.version) == 4 and not data.has("profile"):
		return {"ok": false, "message": "Missing campaign profile"}
	var profile: Variant = data.get("profile", Profile.fresh())
	if not profile is Dictionary or not Profile.valid(profile):
		return {"ok": false, "message": "Invalid campaign profile"}
	return {"ok": true, "state": state, "profile": profile, "revision": int(revision), "recoverable": bool(data.get("recoverable", true)), "settings": {"muted": bool(settings.get("muted", false)), "reduced_effects": bool(settings.get("reduced_effects", false))}}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func write(state: Dictionary, settings: Dictionary, path: String = PATH, backend: Variant = null, recoverable: bool = true, profile: Dictionary = {}) -> bool:
	var io: Variant = Files.new() if backend == null else backend
	var previous := read(path, io)
	var revision := int(previous.get("revision", 0)) + 1
	var source := encode(state, settings, revision, recoverable, profile)
	if not decode(source).ok:
		return false
	# Protect the newest valid state BEFORE replacing any interrupted .tmp file.
	if previous.ok:
		var backup_source: String = previous.source
		if not io.exists(path + ".bak") or io.read_text(path + ".bak") != backup_source:
			# The staged backup may itself be the only surviving good candidate.
			# Reuse identical validated bytes instead of opening them for truncation.
			var staged_matches: bool = io.exists(path + ".bak.tmp") and io.read_text(path + ".bak.tmp") == backup_source
			if not staged_matches and not checked_write(io, path + ".bak.tmp", backup_source):
				return false
			if not io.rename(path + ".bak.tmp", path + ".bak"):
				return false
	if not checked_write(io, path + ".tmp", source):
		return false
	return io.rename(path + ".tmp", path)

static func checked_write(io: Variant, path: String, source: String) -> bool:
	if not io.write_text(path, source):
		return false
	var readback: String = io.read_text(path)
	return readback == source and decode(readback).ok

static func read(path: String = PATH, backend: Variant = null) -> Dictionary:
	var io: Variant = Files.new() if backend == null else backend
	var best := {"ok": false, "message": "No valid save"}
	var best_modified := -1
	# Ties favor a complete interrupted write over the primary, then the backup.
	for candidate in [path + ".tmp", path, path + ".bak", path + ".bak.tmp"]:
		if io.exists(candidate):
			var source: String = io.read_text(candidate)
			var result := decode(source)
			if result.ok:
				# An import is accepted only by successful primary replacement. A
				# failed import must not silently take over on the next app launch.
				if candidate == path + ".tmp" and not result.recoverable:
					continue
				var modified: int = io.modified(candidate)
				if not best.ok or int(result.revision) > int(best.revision) or (int(result.revision) == int(best.revision) and modified > best_modified):
					result["recovered"] = candidate != path
					result["source"] = source
					result["path"] = candidate
					best = result
					best_modified = modified
	return best
