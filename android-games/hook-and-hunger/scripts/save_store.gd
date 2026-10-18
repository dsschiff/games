extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const PATH := "user://hook-save"
const LIMIT := 60000

static func encode(state: Dictionary, settings: Dictionary, revision: int, committed: bool = true) -> String:
	var payload := JSON.stringify({"version": 1, "revision": revision, "committed": committed, "state": state, "settings": settings})
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
	if not packet is Dictionary or packet.get("version") != 1 or not Rules.numeric(packet.get("revision"), 0, 100000000, true) or not packet.get("committed") is bool or not Rules.valid(packet.get("state")) or not packet.get("settings") is Dictionary:
		return {"ok": false}
	for key in ["sound", "reduced_effects"]:
		if not packet.settings.get(key) is bool:
			return {"ok": false}
	return {"ok": true, "state": Rules.restore(packet.state), "settings": packet.settings, "revision": int(packet.revision), "committed": packet.committed, "source": text}

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

static func write(state: Dictionary, settings: Dictionary, path: String = PATH, io: Variant = null, imported: bool = false) -> bool:
	if io == null:
		io = preload("res://scripts/save_files.gd").new()
	var best := read(path, io)
	# Alternate slots, even when the newest valid file is a staged recovery.
	# No write can truncate the newest good candidate.
	var slot := 1 - int(best.slot)
	var file := path + str(slot)
	var source := encode(state, settings, int(best.revision) + 1, not imported)
	if not decode(source).ok or not io.write_text(file + ".tmp", source):
		return false
	if io.read_text(file + ".tmp") != source:
		return false
	return io.rename(file + ".tmp", file)
