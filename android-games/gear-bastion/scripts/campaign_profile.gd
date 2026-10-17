class_name CampaignProfile
extends RefCounted
const Content = preload("res://scripts/campaign_data.gd")

static func fresh() -> Dictionary:
	return {"version": 1, "cleared": [], "medals": {}, "best": {}, "ending_seen": false, "challenge_clears": {}}

static func accessible(profile: Dictionary, id: String) -> bool:
	var index := Content.IDS.find(id)
	return index == 0 or (index > 0 and Content.IDS[index - 1] in profile.cleared)

static func award(profile: Dictionary, run: Dictionary) -> bool:
	if run.phase != "victory" or not run.encounter in Content.IDS:
		return false
	var id: String = run.encounter
	var config: Dictionary = run.config
	var medal := 1
	if is_equal_approx(float(run.wall), float(config.wall)):
		medal += 1
	if int(run.gold) >= 6 and float(run.time) <= float(config.get("par_seconds", 300)):
		medal += 1
	if bool(config.get("challenge", false)):
		profile.challenge_clears[id + ":" + str(int(run.seed))] = medal
		return true
	if not id in profile.cleared:
		profile.cleared.append(id)
	profile.medals[id] = maxi(int(profile.medals.get(id, 0)), medal)
	var previous: Dictionary = profile.best.get(id, {})
	if previous.is_empty() or float(run.time) < float(previous.seconds):
		profile.best[id] = {"seconds": run.time, "wall": run.wall, "spent": run.spent, "produced": run.produced, "losses": run.losses, "cap_seconds": run.cap_time}
	return true

static func valid(profile: Dictionary) -> bool:
	for key in ["version", "cleared", "medals", "best", "ending_seen", "challenge_clears"]:
		if not profile.has(key):
			return false
	if not Content.numeric(profile.version, 1, 1, true) or not profile.ending_seen is bool or not profile.cleared is Array or not profile.medals is Dictionary or not profile.best is Dictionary or not profile.challenge_clears is Dictionary:
		return false
	var seen: Dictionary = {}
	for id in profile.cleared:
		if not id in Content.IDS or seen.has(id):
			return false
		seen[id] = true
	for id in profile.medals:
		if not id in Content.IDS or not Content.numeric(profile.medals[id], 1, 3, true):
			return false
	for id in profile.best:
		if not id in Content.IDS or not profile.best[id] is Dictionary or not profile.best[id].has("seconds") or not Content.numeric(profile.best[id].seconds, 0, 1000000):
			return false
	for key in profile.challenge_clears:
		if not key is String or key.length() > 64 or not Content.numeric(profile.challenge_clears[key], 1, 3, true):
			return false
	return profile.challenge_clears.size() <= 200
