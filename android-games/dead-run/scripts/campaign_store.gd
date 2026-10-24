extends RefCounted
const Old = preload("res://scripts/save_store.gd")
const Legacy = preload("res://scripts/rules.gd")
const R = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/campaign_data.gd")
const Files = preload("res://scripts/save_files.gd")
const PATH := Old.PATH
const LIMIT := 2000000
# Best-crew records accept the largest cap any catalog has used.
const MAX_CREW := D.CAP

static func profile() -> Dictionary:
	return {"clears": [], "medals": {}, "replays": [], "ending": false}

static func fresh() -> Dictionary:
	return {"mode": "campaign", "legacy": Legacy.fresh(), "campaign": R.fresh(), "profile": profile(), "settings": {"sound": true, "reduced_effects": false}, "loadout": "rivet"}

static func valid(ctx: Variant) -> bool:
	if not ctx is Dictionary or ctx.get("mode") not in ["campaign", "legacy"] or not Legacy.valid(ctx.get("legacy")) or not R.valid(ctx.get("campaign")) or not D.WEAPONS.has(ctx.get("loadout")): return false
	if not ctx.get("settings") is Dictionary or not ctx.settings.get("sound") is bool or not ctx.settings.get("reduced_effects") is bool: return false
	var p: Variant = ctx.get("profile")
	if not p is Dictionary or not p.get("clears") is Array or not p.get("medals") is Dictionary or not p.get("replays") is Array or not p.get("ending") is bool or p.clears.size() > 24 or p.replays.size() > 20: return false
	for i in p.clears.size():
		if p.clears[i] != i: return false
	if p.ending != (p.clears.size() == 24) or p.medals.size() != p.clears.size(): return false
	for id in p.medals:
		if not id is String or not id.is_valid_int() or id != str(int(id)) or int(id) < 0 or int(id) >= p.clears.size() or not p.medals[id] is Dictionary: return false
		var m: Dictionary = p.medals[id]
		if not m.get("rescues") is bool or not m.get("no_loss") is bool or not Legacy.number(m.get("best_crew"), 1, MAX_CREW, true): return false
	var seen := {}
	for rec in p.replays:
		if not rec is Dictionary or not Legacy.number(rec.get("seed"), 1, 999999, true) or seen.has(rec.seed) or not Legacy.number(rec.get("crew"), 1, MAX_CREW, true) or not D.WEAPONS.has(rec.get("weapon")): return false
		seen[rec.seed] = true
	if not p.ending and not p.replays.is_empty(): return false
	var s: Dictionary = ctx.campaign
	if not s.definition.replay and s.definition.index > mini(23, p.clears.size()): return false
	if s.definition.replay and not p.ending: return false
	if s.rewarded and s.phase != "victory": return false
	if s.phase == "victory" and not s.rewarded: return false
	if s.phase == "victory" and s.rewarded:
		if not s.definition.replay and s.definition.index not in p.clears: return false
		if s.definition.replay and not seen.has(s.definition.seed): return false
	return true

## Explicit code5 upgrade of a code2-code4 (catalog1/rule2) campaign road.
## A road in progress, and a finished road showing its result, keep their
## pinned catalog1 definition and replay under the frozen catalog1 rules.
## A road that was loaded but never started has nothing to preserve, so it
## becomes the same road, weapon and seed under the current horde rules.
## Clears, medals, best crew, replays, settings, loadout and the parked legacy
## canal bridge are never touched. Returns true when the context changed.
static func upgrade(ctx: Dictionary) -> bool:
	var s: Dictionary = ctx.campaign
	if not R.catalog1(s) or s.phase != "ready": return false
	ctx.campaign = R.fresh(int(s.definition.index), String(s.weapon), int(s.definition.seed))
	return true

static func award(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.campaign
	if s.phase != "victory" or s.rewarded: return
	var p: Dictionary = ctx.profile
	if s.definition.replay:
		var record := {"seed": s.definition.seed, "crew": s.crew, "weapon": s.weapon}
		var found := false
		for i in p.replays.size():
			if p.replays[i].seed == record.seed:
				if p.replays[i].crew < s.crew: p.replays[i] = record
				found = true
		if not found:
			p.replays.append(record)
			if p.replays.size() > 20: p.replays.pop_front()
	else:
		var index: int = s.definition.index
		if index == p.clears.size(): p.clears.append(index)
		var key := str(index)
		var rescues: bool = s.sides.all(func(side): return side.claimed)
		var old: Dictionary = p.medals.get(key, {"rescues": false, "no_loss": false, "best_crew": 1})
		p.medals[key] = {"rescues": rescues or old.rescues, "no_loss": s.lost == 0 or old.no_loss, "best_crew": maxi(s.crew, old.best_crew)}
		p.ending = p.clears.size() == 24
	s.rewarded = true

static func encode(ctx: Dictionary, revision: int, committed: bool = true) -> String:
	var payload := JSON.stringify({"version": 2, "revision": revision, "committed": committed, "context": ctx}, "", true, true)
	return JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})

static func integers(v: Variant) -> Variant:
	if v is float and v == floor(v): return int(v)
	if v is Dictionary:
		for k in v: v[k] = integers(v[k])
	if v is Array:
		for i in v.size(): v[i] = integers(v[i])
	return v

static func decode(text: String) -> Dictionary:
	var bad := {"ok": false}
	if text.length() > LIMIT: return bad
	var old := Old.decode(text)
	if old.ok:
		var ctx := fresh()
		ctx.mode = "legacy"
		ctx.legacy = old.state
		ctx.settings = old.settings
		return {"ok": true, "revision": old.revision, "committed": old.committed, "context": ctx, "migrated": true}
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary: return bad
	var env: Dictionary = parser.data
	if not env.get("payload") is String or not env.get("sha256") is String or env.payload.sha256_text() != env.sha256: return bad
	if parser.parse(env.payload) != OK or not parser.data is Dictionary: return bad
	var obj: Dictionary = parser.data
	if obj.get("version") != 2 or not Legacy.number(obj.get("revision"), 0, 1000000000, true) or not obj.get("committed") is bool or not valid(obj.get("context")): return bad
	# Preserve the legacy body's type normalization exactly as the code1 decoder does.
	obj.context.campaign = integers(obj.context.campaign)
	obj.context.profile = integers(obj.context.profile)
	var legacy: Dictionary = obj.context.legacy
	for key in ["seed", "tick", "crew", "joined", "lost", "shots", "gate_hits", "kills", "leaks", "contact", "side_hp", "side_hits", "final_hp", "final_hits", "gain_tick", "hurt_tick", "last_crossing"]:
		legacy[key] = int(legacy[key])
	for g in legacy.gates:
		for key in ["id", "value", "hits", "applied"]: g[key] = int(g[key])
	for e in legacy.enemies:
		for key in ["id", "born", "hp"]: e[key] = int(e[key])
	for b in legacy.bullets: b.id = int(b.id)
	return {"ok": true, "revision": int(obj.revision), "committed": obj.committed, "context": obj.context, "migrated": false}

static func read(path: String = PATH, io: Variant = null) -> Dictionary:
	if io == null: io = Files.new()
	var best := {"ok": false, "revision": 0, "slot": 1}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var name: String = path + str(slot) + suffix
			if io.exists(name):
				var d := decode(io.read_text(name))
				if d.ok and (suffix.is_empty() or d.committed) and (not best.ok or d.revision > best.revision):
					d["slot"] = slot
					best = d
	return best

static func write(ctx: Dictionary, path: String = PATH, io: Variant = null, imported: bool = false) -> bool:
	if io == null: io = Files.new()
	var best := read(path, io)
	var name := path + str(1 - int(best.slot))
	var code := encode(ctx, int(best.revision) + 1, not imported)
	if not decode(code).ok or not io.write_text(name + ".tmp", code) or io.read_text(name + ".tmp") != code: return false
	if not io.rename(name + ".tmp", name) or not io.exists(name): return false
	var confirmed: String=io.read_text(name)
	return confirmed==code and decode(confirmed).ok
