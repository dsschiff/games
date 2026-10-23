extends RefCounted
const D = preload("res://scripts/definitions.gd")

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
