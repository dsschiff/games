extends RefCounted

const Content = preload("res://scripts/content.gd")
const Rules = preload("res://scripts/rules.gd")
const Files = preload("res://scripts/save_files.gd")
const Challenge = preload("res://scripts/challenge_v1.gd")
const VERSION := 3
const PATH := "user://tower-save.json"
const LIMIT := 200000

static func fresh() -> Dictionary:
	return {"schema": VERSION, "revision": 0, "recoverable": true, "catalog": Content.VERSION, "level_id": "watch_01", "level": 0, "actions": [], "used_undo": false, "profile": {}, "settings": {"sound": true, "reduced_effects": false}, "kind": "campaign", "challenge_run": {}, "challenge_records": []}

static func replay(data: Dictionary) -> Dictionary:
	if data.get("kind", "campaign") == "challenge":
		return replay_route(data.challenge_run.bundle.snapshot, data.challenge_run.actions)
	var level: Dictionary = Content.by_id(data.level_id, int(data.catalog))
	return replay_route(level, data.actions)

static func replay_route(level: Dictionary, actions: Array) -> Dictionary:
	var state := Rules.initial(level)
	for action in actions:
		var result := Rules.step(level, state, action)
		if not result.ok:
			return {}
		state = result.state
	return state

static func whole(value: Variant, lower: int, upper: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == int(value) and int(value) >= lower and int(value) <= upper

static func decode(source: String) -> Dictionary:
	if source.length() > LIMIT:
		return {"ok": false, "message": "Save exceeds size limit"}
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return {"ok": false, "message": "Invalid save text"}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"ok": false, "message": "Invalid save text"}
	var data: Dictionary = parsed
	for key in fresh():
		if not data.has(key):
			if key in ["kind", "challenge_run", "challenge_records"] and whole(data.get("schema", 0), 1, 2):
				data[key] = fresh()[key]
			else:
				return {"ok": false, "message": "Incomplete save"}
	if not whole(data.catalog, 1, Content.VERSION) or not data.level_id is String or Content.by_id(data.level_id, int(data.catalog)).is_empty():
		return {"ok": false, "message": "Unknown saved catalog or puzzle ID"}
	var saved_levels := Content.levels(int(data.catalog))
	if not whole(data.schema, 1, VERSION) or not whole(data.revision, 0, 1000000000) or not whole(data.level, 0, saved_levels.size() - 1):
		return {"ok": false, "message": "Unsupported save or level"}
	if not data.recoverable is bool or not data.used_undo is bool or not data.actions is Array or data.actions.size() > 32 or not data.profile is Dictionary or not data.settings is Dictionary:
		return {"ok": false, "message": "Invalid save structure"}
	for key in ["sound", "reduced_effects"]:
		if not data.settings.has(key) or not data.settings[key] is bool:
			return {"ok": false, "message": "Invalid settings"}
	var levels := Content.levels()
	if saved_levels[int(data.level)].id != data.level_id:
		return {"ok": false, "message": "Puzzle ID and index disagree"}
	for id in data.profile:
		var index := -1
		for i in levels.size():
			if levels[i].id == id:
				index = i
		if index < 0 or not data.profile[id] is Dictionary:
			return {"ok": false, "message": "Unknown earned clear"}
		var medal: Dictionary = data.profile[id]
		if not whole(medal.get("best", -1), 1, levels[index].rooms.size()) or not whole(medal.get("medals", 0), 1, 15):
			return {"ok": false, "message": "Invalid earned medal"}
		if int(medal.medals) & 1 == 0 or (int(medal.medals) & 4 != 0 and not levels[index].rooms.any(func(room): return room.treasure)):
			return {"ok": false, "message": "Impossible medal type"}
		medal.best = int(medal.best)
		medal.medals = int(medal.medals)
	# Historic clears may predate tutorials inserted in catalog2. Validate the
	# active route against its own catalog, without manufacturing new clears.
	if not data.profile.has(data.level_id):
		for prior in int(data.level):
			if not data.profile.has(saved_levels[prior].id):
				return {"ok": false, "message": "Locked active level"}
	for action in data.actions:
		if not action is String:
			return {"ok": false, "message": "Invalid route"}
	data.level = int(data.level)
	data.catalog = int(data.catalog)
	data.schema = VERSION
	data.revision = int(data.revision)
	var state := replay_route(Content.by_id(data.level_id, data.catalog), data.actions)
	if state.is_empty():
		return {"ok": false, "message": "Impossible route"}
	if state.status == "won" and not data.profile.has(data.level_id):
		return {"ok": false, "message": "Completed route is missing its earned clear"}
	if not data.kind is String or not data.kind in ["campaign", "challenge"] or not data.challenge_run is Dictionary or not data.challenge_records is Array or data.challenge_records.size() > Challenge.MAX_RECORDS:
		return {"ok": false, "message": "Invalid challenge save structure"}
	var record_keys: Array = []
	for record in data.challenge_records:
		if not record is Dictionary or record.size() != 8: return {"ok": false, "message": "Invalid challenge record"}
		for field in ["key", "version", "family", "seed", "options", "best", "medals", "fallback"]:
			if not record.has(field): return {"ok": false, "message": "Incomplete challenge record"}
		if not record.fallback is bool or not record.key is String or not RegEx.create_from_string("^[a-f0-9]{64}$").search(record.key) or record.key in record_keys or not whole(record.version, 1, 1) or not record.family in Challenge.FAMILIES or not whole(record.seed, 0, 2147483647) or not Challenge.options_valid(record.options) or not whole(record.best, 1, 8) or not whole(record.medals, 1, 15) or int(record.medals) & 1 == 0 or (not record.options.treasure and int(record.medals) & 4 != 0):
			return {"ok": false, "message": "Invalid challenge medal bounds"}
		record_keys.append(record.key)
		for field in ["version", "seed", "best", "medals"]: record[field] = int(record[field])
		record.options.weave = int(record.options.weave)
	if not data.challenge_run.is_empty():
		var run: Dictionary = data.challenge_run
		if run.size() != 3 or not run.has("bundle") or not run.get("actions") is Array or run.actions.size() > 8 or not run.get("used_undo") is bool:
			return {"ok": false, "message": "Invalid challenge run"}
		var valid := Challenge.validate(run.bundle)
		if not valid.ok: return valid
		for record in data.challenge_records:
			if record.key == valid.key and (record.fallback != run.bundle.fallback or record.version != run.bundle.version or record.family != run.bundle.family or record.seed != run.bundle.seed or record.options != run.bundle.options or record.best < int(run.bundle.snapshot.par) or record.best > run.bundle.snapshot.rooms.size() or (int(record.medals) & 2 != 0 and record.best > int(run.bundle.snapshot.par))):
				return {"ok": false, "message": "Challenge record does not match its pinned snapshot"}
		for action in run.actions:
			if not action is String: return {"ok": false, "message": "Invalid challenge action"}
		var challenge_state := replay_route(run.bundle.snapshot, run.actions)
		if challenge_state.is_empty() or (challenge_state.status == "won" and not valid.key in record_keys):
			return {"ok": false, "message": "Invalid challenge history or missing medal"}
		if data.kind == "challenge": state = challenge_state
	elif data.kind == "challenge":
		return {"ok": false, "message": "Missing generated snapshot"}
	return {"ok": true, "data": data, "state": state}

static func encode(data: Dictionary) -> String:
	return JSON.stringify(data, "", true, true)

static func checked_write(io: Variant, path: String, source: String) -> bool:
	return io.write_text(path, source) and io.read_text(path) == source and decode(source).ok

static func checked_rename(io: Variant, from: String, to: String, source: String) -> bool:
	var renamed: bool = io.rename(from, to)
	var stored: String = io.read_text(to) if io.exists(to) else ""
	if renamed and stored == source and decode(stored).ok:
		return true
	# A lying/partial rename may consume the sole valid staged backup. Restore
	# its checked bytes before returning failure; failed imports stay excluded
	# from .tmp recovery through their existing recoverable=false marker.
	if not io.exists(from) or io.read_text(from) != source:
		checked_write(io, from, source)
	return false

static func read(path: String = PATH, backend: Variant = null) -> Dictionary:
	var io: Variant = Files.new() if backend == null else backend
	var best := {"ok": false, "message": "No valid local save"}
	for candidate in [path + ".tmp", path, path + ".bak", path + ".bak.tmp"]:
		if io.exists(candidate):
			var source: String = io.read_text(candidate)
			var decoded := decode(source)
			if decoded.ok and (candidate != path + ".tmp" or decoded.data.recoverable):
				if not best.ok or int(decoded.data.revision) > int(best.data.revision):
					best = decoded
					best["source"] = source
					best["path"] = candidate
	return best

static func write(data: Dictionary, path: String = PATH, backend: Variant = null, recoverable: bool = true) -> bool:
	var io: Variant = Files.new() if backend == null else backend
	var previous := read(path, io)
	var next := data.duplicate(true)
	next.revision = int(previous.data.revision) + 1 if previous.ok else 1
	next.recoverable = recoverable
	var source := encode(next)
	if not decode(source).ok:
		return false
	if previous.ok and (not io.exists(path + ".bak") or io.read_text(path + ".bak") != previous.source):
		# A staged backup can be the sole surviving valid file. Never truncate it.
		if not io.exists(path + ".bak.tmp") or io.read_text(path + ".bak.tmp") != previous.source:
			if not checked_write(io, path + ".bak.tmp", previous.source):
				return false
		if not checked_rename(io, path + ".bak.tmp", path + ".bak", previous.source):
			return false
	if not checked_write(io, path + ".tmp", source):
		return false
	return checked_rename(io, path + ".tmp", path, source)
