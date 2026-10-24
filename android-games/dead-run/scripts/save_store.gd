extends RefCounted
const R = preload("res://scripts/rules.gd")
const Files = preload("res://scripts/save_files.gd")
const PATH := "user://dead-run-save-"
const LIMIT := 150000

static func encode(state: Dictionary, settings: Dictionary, revision: int, committed: bool = true) -> String:
	var payload := JSON.stringify({"version": 1, "revision": revision, "committed": committed, "state": state, "settings": settings}, "", true, true)
	return JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})

static func decode(text: String) -> Dictionary:
	var bad := {"ok": false}
	if text.length() > LIMIT:
		return bad
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return bad
	var env: Dictionary = parser.data
	if not env.get("payload") is String or not env.get("sha256") is String or env.payload.sha256_text() != env.sha256:
		return bad
	if parser.parse(env.payload) != OK or not parser.data is Dictionary:
		return bad
	var d: Dictionary = parser.data
	if d.get("version") != 1 or not R.number(d.get("revision"), 0, 1000000000, true) or not d.get("committed") is bool or not R.valid(d.get("state")) or not d.get("settings") is Dictionary:
		return bad
	for key in ["sound", "reduced_effects"]:
		if not d.settings.get(key) is bool:
			return bad
	# JSON numbers decode as floats. Restore the rule model's integer counters.
	d.revision = int(d.revision)
	for key in ["seed", "tick", "crew", "joined", "lost", "shots", "gate_hits", "kills", "leaks", "contact", "side_hp", "side_hits", "final_hp", "final_hits", "gain_tick", "hurt_tick", "last_crossing"]:
		d.state[key] = int(d.state[key])
	for g in d.state.gates:
		for key in ["id", "value", "hits", "applied"]:
			g[key] = int(g[key])
	for e in d.state.enemies:
		for key in ["id", "born", "hp"]:
			e[key] = int(e[key])
	for b in d.state.bullets:
		b.id = int(b.id)
	d["ok"] = true
	return d

static func read(path: String = PATH, io: Variant = null) -> Dictionary:
	if io == null:
		io = Files.new()
	var best := {"ok": false, "revision": 0, "slot": 1}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var file: String = path + str(slot) + suffix
			if io.exists(file):
				var d := decode(io.read_text(file))
				if d.ok and (suffix.is_empty() or d.committed) and (not best.ok or d.revision > best.revision):
					d["slot"] = slot
					best = d
	return best

static func write(state: Dictionary, settings: Dictionary, path: String = PATH, io: Variant = null, imported: bool = false) -> bool:
	if io == null:
		io = Files.new()
	var best := read(path, io)
	var file := path + str(1 - int(best.slot))
	var text := encode(state, settings, int(best.revision) + 1, not imported)
	if not decode(text).ok or not io.write_text(file + ".tmp", text) or io.read_text(file + ".tmp") != text:
		return false
	if not io.rename(file + ".tmp", file) or not io.exists(file): return false
	var confirmed: String=io.read_text(file)
	return confirmed==text and decode(confirmed).ok
