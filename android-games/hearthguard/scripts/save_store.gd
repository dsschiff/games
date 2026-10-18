extends RefCounted
const R = preload("res://scripts/rules.gd")
const C = preload("res://scripts/campaign_rules.gd")
const Files = preload("res://scripts/save_files.gd")
const PATH := "user://hearth-save-"
const LIMIT := 600000

static func encode(s: Dictionary, p: Dictionary, settings: Dictionary, revision: int, committed: bool = true, campaign: Dictionary = {}) -> String:
	var payload := JSON.stringify({"version": 2, "revision": revision, "committed": committed, "state": s, "profile": p, "settings": settings, "campaign": C.profile() if campaign.is_empty() else campaign})
	return JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})

static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > LIMIT:
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
	if (d.state.get("schema") == 1 and not R.valid(d.state)) or (d.state.get("schema") == 2 and (d.version != 2 or not C.valid(d.state))) or not R.number(d.state.get("schema"), 1, 2, true):
		return {"ok": false}
	if d.version == 2 and (not d.has("campaign") or not C.valid_profile(d.campaign)):
		return {"ok": false}
	if d.version == 1:
		d["campaign"] = C.profile()
	if d.state.schema == 2:
		var def: Dictionary = d.state.definition
		if def.endless >= 0 and not d.campaign.ending or def.endless < 0 and def.stage > d.campaign.clears.size():
			return {"ok": false}
		if def.endless >= 0 and def.endless > d.campaign.endless_best.get(str(int(def.seed)), 0):
			return {"ok": false}
		if not C.credited_profile_matches(d.state, d.campaign):
			return {"ok": false}
	for key in ["sound", "reduced_effects"]:
		if not d.settings.get(key) is bool:
			return {"ok": false}
	for old_state in [d.state if d.state.schema == 1 else {}, d.campaign.legacy_snapshot]:
		if old_state.is_empty():
			continue
		if old_state.phase in ["victory", "defeat"] and (d.profile.attempts < 1 or d.profile.best_kills < old_state.killed.size()):
			return {"ok": false}
		if old_state.phase == "victory" and d.profile.wins < 1:
			return {"ok": false}
	d.campaign = C.restore_profile(d.campaign)
	if d.state.schema == 2:
		d.state = C.restore(d.state)
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

static func write(s: Dictionary, p: Dictionary, settings: Dictionary, path: String = PATH, io: Variant = null, imported: bool = false, campaign: Dictionary = {}) -> bool:
	if io == null:
		io = Files.new()
	var best := read(path, io)
	var file := path + str(1 - int(best.slot))
	var text := encode(s, p, settings, int(best.revision) + 1, not imported, campaign)
	if not decode(text).ok or not io.write_text(file + ".tmp", text) or io.read_text(file + ".tmp") != text:
		return false
	return io.rename(file + ".tmp", file)
