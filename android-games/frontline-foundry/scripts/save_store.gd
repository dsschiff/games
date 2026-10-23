extends RefCounted
const R = preload("res://scripts/rules.gd")
const C = preload("res://scripts/campaign_rules.gd")
const Files = preload("res://scripts/save_files.gd")
const PATH := "user://frontline-save-"
const LIMIT := 500000

static func encode(s: Dictionary, p: Dictionary, settings: Dictionary, revision: int, committed: bool = true, career: Dictionary = {}) -> String:
	var payload := JSON.stringify({"version": 2, "revision": revision, "committed": committed, "state": s, "profile": p, "settings": settings, "career": C.career() if career.is_empty() else career})
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
	if not R.number(d.get("version"), 1, 2, true) or not R.number(d.get("revision"), 0, 1000000000, true) or not d.get("committed") is bool or not d.get("state") is Dictionary or not R.valid_profile(d.get("profile")) or not d.get("settings") is Dictionary:
		return {"ok": false}
	if d.version == 1:
		if not R.valid(d.state):
			return {"ok": false}
		d["career"] = C.career()
	else:
		if not C.valid_career(d.get("career")):
			return {"ok": false}
		if d.state.get("catalog") == 1:
			if not R.valid(d.state):
				return {"ok": false}
		elif not C.valid(d.state):
			return {"ok": false}
	for key in ["sound", "reduced_effects"]:
		if not d.settings.get(key) is bool:
			return {"ok": false}
	if d.state.catalog == 1 and d.state.phase in ["victory", "defeat"] and (d.profile.attempts < 1 or d.profile.best_kills < d.state.killed.size()):
		return {"ok": false}
	if d.state.phase in ["victory", "defeat"] and not d.state.recorded:
		return {"ok": false}
	if d.state.catalog == 1 and d.state.phase == "victory" and d.profile.wins < 1:
		return {"ok": false}
	if d.state.catalog == 2:
		var def: Dictionary = d.state.definition
		if def.mode == "campaign" and def.index > d.career.clears.size():
			return {"ok": false}
		if d.state.phase in ["victory", "defeat"] and d.career.attempts < 1:
			return {"ok": false}
		if d.state.phase == "victory" and (d.career.victories < 1 or (def.mode == "campaign" and not d.career.clears.has(def.id)) or (def.mode == "skirmish" and not d.career.skirmishes.has(str(int(def.seed)) + ":" + def.style))):
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

static func write(s: Dictionary, p: Dictionary, settings: Dictionary, path: String = PATH, io: Variant = null, imported: bool = false, career: Dictionary = {}) -> bool:
	if io == null:
		io = Files.new()
	var best := read(path, io)
	var file := path + str(1 - int(best.slot))
	var saved_career: Dictionary = career if not career.is_empty() else (best.career if best.ok else C.career())
	var text := encode(s, p, settings, int(best.revision) + 1, not imported, saved_career)
	if not decode(text).ok or not io.write_text(file + ".tmp", text) or io.read_text(file + ".tmp") != text:
		return false
	if not io.rename(file + ".tmp", file):
		return false
	# A successful rename is only a command receipt; verify the committed bytes.
	return io.exists(file) and io.read_text(file) == text and decode(io.read_text(file)).ok
