extends RefCounted
const D = preload("res://scripts/definitions.gd")
const C = preload("res://scripts/campaign_rules.gd")

static func crew_name(r: Dictionary) -> String:
	return "%s %d" % [r.role.to_upper(), int(r.id) % 3 + 1]

static func latest_crew(s: Dictionary) -> Dictionary:
	# Purchase order identifies the individual, including before its token is consumed.
	var counts := [0, 0, 0, 0]
	var id := -1
	for purchase in s.purchases:
		var station := int(purchase.station)
		if station < 4:
			id = station * 3 + counts[station]
			counts[station] += 1
	return s.recruits[id] if id >= 0 else {}

static func crew_line(s: Dictionary) -> String:
	var r := latest_crew(s)
	if r.is_empty():
		return "EQUIP A RECRUIT → FOLLOW THEM THROUGH THE GATE"
	var stage: String = {"waiting": "WEAPON READY", "equipping": "ARMING", "deploying": "THROUGH THE GATE", "fighting": "HOLDING THE LINE", "fallen": "FALLEN"}[r.phase]
	if r.phase == "deploying":
		stage = ["TO THE GATE", "THROUGH THE GATE", "TAKING POSITION"][int(r.waypoint)]
	if r.phase in ["fighting", "fallen"]:
		return "%s • %s • %d DAMAGE" % [crew_name(r), stage, r.damage]
	return "%s • %s" % [crew_name(r), stage]

static func contribution(s: Dictionary) -> String:
	var damage := 0.0
	var best: Dictionary = {}
	for r in s.recruits:
		damage += r.damage
		if r.damage > 0 and (best.is_empty() or r.damage > best.damage):
			best = r
	if best.is_empty():
		return "Crew damage 0 • no armed recruit hit a target"
	return "Crew damage %d • %s led with %d" % [damage, crew_name(best), best.damage]

static func counter(role: String) -> String:
	return {"rifle": "Rifle: rapid fire against light drones", "breaker": "Breaker: pierces armor and Bulwark cover", "ranger": "Ranger: reaches mortar crews and Jammers", "rover": "Rover: splash sweeps clustered rushers"}[role]

static func advice(s: Dictionary, station: int) -> String:
	if station >= 0 and station < 4:
		return counter(D.ROLES[station])
	if station == 4:
		return D.SUPPORT[s.planned_support]
	var threat := ""
	for e in s.enemies:
		if e.role in ["mortar", "jammer", "storm"]:
			return "Distant fire: equip a Ranger or flank it yourself"
		if e.role in ["bulwark", "drill", "carrier"]:
			threat = "Armor approaching: Breakers pierce it"
		elif e.role in ["runner", "sapper"] and threat.is_empty():
			threat = "Rushers approaching: Rovers hit groups"
	return threat

# Presentation mirrors the existing finish thresholds; it never awards or edits records.
static func sortie_medal(s: Dictionary) -> int:
	if s.phase != "victory": return 0
	return 3 if s.escaped.is_empty() and s.hp >= s.definition.commander_hp * 0.6 else (2 if s.hq >= s.definition.hq * 0.5 else 1)
static func criteria() -> String:
	return "On victory: 3 stars = no escapes + commander HP >=60%.\nOtherwise 2 stars = HQ >=50%.\nOtherwise 1 star."
static func campaign_row(index: int,c: Dictionary) -> String:
	var title: String="%02d  %s" % [index+1,D.TITLES[index]]
	if c.clears.has(D.IDS[index]): title+=" | Earned %d/3" % c.clears[D.IDS[index]]
	var record: Dictionary=c.records.get(D.IDS[index],{})
	return title+"\n"+("Record %d/3 | %.2fs" % [record.medal,record.seconds] if not record.is_empty() else "No campaign record")
static func skirmish_row(key: String,record: Dictionary) -> String:
	return "Latest clear %s | %d/3 | %.2fs" % [key,record.medal,record.seconds]
static func record_line(s: Dictionary,c: Dictionary) -> String:
	if s.definition.mode == "skirmish":
		var key: String=str(int(s.definition.seed))+":"+s.definition.style
		var record: Dictionary=c.skirmishes.get(key,{})
		return skirmish_row(key,record) if not record.is_empty() else "No result for this seed and style"
	var record: Dictionary=c.records.get(s.definition.id,{})
	return "Campaign record %d/3 | %.2fs" % [record.medal,record.seconds] if not record.is_empty() else "No campaign record"
static func compact_contribution(s: Dictionary) -> String:
	var damage:=0.0; var best: Dictionary={}
	for r in s.recruits:
		damage+=r.damage
		if r.damage>0 and (best.is_empty() or r.damage>best.damage): best=r
	return "Crew dmg %d | %s: %d" % [damage,crew_name(best),best.damage] if not best.is_empty() else "Crew damage 0 | no recruit hits"
static func support_line(s: Dictionary) -> String:
	match s.support:
		"ward": return "Ward prevented %.1f damage" % s.prevented
		"recovery": return "Recovery repaired %.1f / %d" % [s.support_used,s.definition.support_effects.repair_budget]
		"relay": return "Relay built: range and capture boost"
	return "No support built"
static func defeat_line(s: Dictionary) -> String:
	if s.cause == "Objective incomplete: " + C.objective_text(s):
		match s.definition.objective:
			"relay": return "Unmet: capture both relays"
			"liberate": return "Unmet: both relays + Storm Engine"
			"salvage": return "Unmet: all 3 field caches"
			"silence": return "Unmet: every mortar crew"
			"boss": return "Unmet: siege boss"
		return "Unmet: stop %d of %d" % [s.definition.minimum,s.definition.schedule.size()]
	return s.cause if s.cause.length() <= 43 else s.cause.left(40) + "..."
static func recap(s: Dictionary,c: Dictionary) -> String:
	if s.phase not in ["victory","defeat"]: return ""
	var current: String="%d/3" % sortie_medal(s) if s.phase=="victory" else "defeat"
	var lines: Array[String]=["This sortie %s | %.2fs" % [current,s.time],record_line(s,c)]
	if s.phase=="defeat": lines.append(defeat_line(s))
	else: lines.append("3 stars: no escapes + commander HP >=60%.")
	lines.append("%d stopped / %d escaped | spent %d" % [s.killed.size(),s.escaped.size(),s.spent])
	lines.append(compact_contribution(s))
	# Unusual retained causes may need a second row; the failure reason has priority.
	if s.phase != "defeat" or s.cause.length() <= 43 or s.cause == "Objective incomplete: " + C.objective_text(s): lines.append(support_line(s))
	return "\n".join(lines)
