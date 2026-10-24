extends RefCounted
const Rules = preload("res://scripts/engine.gd")
const Campaign = preload("res://scripts/campaign_rules.gd")
const PATH := "user://hook-save"
const LIMIT := 600000

static func encode(state: Dictionary, settings: Dictionary, revision: int, committed: bool = true, profile_data: Dictionary = {}) -> String:
	var payload := JSON.stringify({"version": 2, "revision": revision, "committed": committed, "state": state, "settings": settings, "profile": Campaign.profile() if profile_data.is_empty() else profile_data})
	return JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})

static func decode(text: String) -> Dictionary:
	if text.length() > LIMIT:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text() != envelope.sha256:
		return {"ok": false}
	if parser.parse(envelope.payload) != OK:
		return {"ok": false}
	var packet: Variant = parser.data
	if not packet is Dictionary or not Rules.numeric(packet.get("version"), 1, 2, true) or not Rules.numeric(packet.get("revision"), 0, 100000000, true) or not packet.get("committed") is bool or not Rules.valid(packet.get("state")) or not packet.get("settings") is Dictionary:
		return {"ok": false}
	var profile_data: Variant = packet.get("profile", Campaign.profile())
	if packet.version == 2 and not packet.has("profile") or not Campaign.valid_profile(profile_data):
		return {"ok": false}
	if packet.version == 1 and packet.state.schema != 1:
		return {"ok": false}
	if packet.state.schema == 1 and profile_data.stage != -1:
		return {"ok": false}
	if packet.state.schema == 1:
		if packet.state.phase == "victory" and packet.state.tier != 1:
			return {"ok": false}
		for drop in packet.state.drops:
			for rock in Rules.Legacy.OBSTACLES:
				if Vector2(drop.x, drop.z).distance_to(Vector2(rock.x, rock.y)) + 1.349 < rock.z + 0.4:
					return {"ok": false}
	if packet.state.schema == 2:
		if packet.state.definition.arena:
			if not profile_data.completed or profile_data.ending.is_empty():
				return {"ok": false}
		elif packet.state.definition.stage != profile_data.stage:
			return {"ok": false}
	for key in ["sound", "reduced_effects"]:
		if not packet.settings.get(key) is bool:
			return {"ok": false}
	# The old active state stays field-for-field intact. New campaign metadata
	# lives beside it, and schema1 still executes the shipped version1 rules.
	for key in ["version", "stage", "arena_seed", "arena_weapon", "hits", "rescues"]:
		profile_data[key] = int(profile_data[key])
	for i in profile_data.clears.size():
		profile_data.clears[i] = int(profile_data.clears[i])
	for key in profile_data.medals:
		profile_data.medals[key] = int(profile_data.medals[key])
	for key in profile_data.arena_scores:
		profile_data.arena_scores[key].hits = int(profile_data.arena_scores[key].hits)
		profile_data.arena_scores[key].rescues = int(profile_data.arena_scores[key].rescues)
	if not profile_data.ending.is_empty():
		profile_data.ending = Campaign.restore(profile_data.ending)
	return {"ok": true, "state": Rules.restore(packet.state), "profile": profile_data, "settings": packet.settings, "revision": int(packet.revision), "committed": packet.committed, "source": text}

static func read(path: String = PATH, io: Variant = null) -> Dictionary:
	if io == null:
		io = preload("res://scripts/save_files.gd").new()
	var best := {"ok": false, "revision": 0, "slot": 1}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var file: String = path + str(slot) + suffix
			if not io.exists(file):
				continue
			var candidate := decode(io.read_text(file))
			if candidate.ok and (candidate.committed or suffix.is_empty()) and (not best.ok or int(candidate.revision) > int(best.revision)):
				candidate["slot"] = slot
				candidate["recovered"] = not suffix.is_empty()
				best = candidate
	return best

static func write(state: Dictionary, settings: Dictionary, path: String = PATH, io: Variant = null, imported: bool = false, profile_data: Dictionary = {}) -> bool:
	if io == null:
		io = preload("res://scripts/save_files.gd").new()
	var best := read(path, io)
	# Alternate slots, even when the newest valid file is a staged recovery.
	# No write can truncate the newest good candidate.
	var slot := 1 - int(best.slot)
	var file := path + str(slot)
	var source := encode(state, settings, int(best.revision) + 1, not imported, profile_data)
	if not decode(source).ok or not io.write_text(file + ".tmp", source):
		return false
	if io.read_text(file + ".tmp") != source:
		return false
	if not io.rename(file + ".tmp", file) or not io.exists(file):
		return false
	var committed: String = io.read_text(file)
	return committed == source and decode(committed).ok
