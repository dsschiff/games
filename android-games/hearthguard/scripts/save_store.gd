extends RefCounted
const R = preload("res://scripts/rules.gd")
const Files = preload("res://scripts/save_files.gd")
const PATH := "user://hearth-save-"
const LIMIT := 100000

static func encode(s: Dictionary, p: Dictionary, settings: Dictionary, revision: int, committed: bool = true) -> String:
	var payload := JSON.stringify({"version": 1, "revision": revision, "committed": committed, "state": s, "profile": p, "settings": settings})
	return JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})

static func decode(text: String) -> Dictionary:
	if text.length() > LIMIT:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {"ok": false}
	var env: Dictionary = parser.data
	if not env.get("payload") is String or not env.get("sha256") is String or env.payload.sha256_text() != env.sha256:
		return {"ok": false}
	if parser.parse(env.payload) != OK or not parser.data is Dictionary:
		return {"ok": false}
	var d: Dictionary = parser.data
	if d.get("version") != 1 or not R.number(d.get("revision"), 0, 1000000000, true) or not d.get("committed") is bool or not R.valid(d.get("state")) or not R.valid_profile(d.get("profile")) or not d.get("settings") is Dictionary:
		return {"ok": false}
	for key in ["sound", "reduced_effects"]:
		if not d.settings.get(key) is bool:
			return {"ok": false}
	if d.state.phase in ["victory", "defeat"] and (d.profile.attempts < 1 or d.profile.best_kills < d.state.killed.size()):
		return {"ok": false}
	if d.state.phase == "victory" and d.profile.wins < 1:
		return {"ok": false}
	d["ok"] = true
	return d

static func read(path: String = PATH, io: Variant = null) -> Dictionary:
	if io == null:
		io = Files.new()
	var best := {"ok": false, "revision": 0, "slot": 1}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var file: String = path + str(slot) + suffix
			if not io.exists(file):
				continue
			var d := decode(io.read_text(file))
			if d.ok and (suffix.is_empty() or d.committed) and (not best.ok or d.revision > best.revision):
				d["slot"] = slot
				best = d
	return best

static func write(s: Dictionary, p: Dictionary, settings: Dictionary, path: String = PATH, io: Variant = null, imported: bool = false) -> bool:
	if io == null:
		io = Files.new()
	var best := read(path, io)
	var file := path + str(1 - int(best.slot))
	var text := encode(s, p, settings, int(best.revision) + 1, not imported)
	if not decode(text).ok or not io.write_text(file + ".tmp", text) or io.read_text(file + ".tmp") != text:
		return false
	return io.rename(file + ".tmp", file)
