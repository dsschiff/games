extends RefCounted

const MAX_POWER := 1000000
const Legacy = preload("res://scripts/rules_v1.gd")

static func initial(level: Dictionary) -> Dictionary:
	if int(level.get("rules", 1)) == 1:
		return Legacy.initial(level)
	var state := {"level": level.id, "power": int(level.power), "keys": 0, "shields": 0, "claimed": [], "collapsed": [], "moves": 0, "treasure": 0, "status": "active", "last": "home"}
	if int(level.get("rules", 1)) >= 2:
		state["rescued"] = []
	return state

static func find_room(level: Dictionary, id: String) -> Dictionary:
	for room in level.rooms:
		if room.id == id:
			return room
	return {}

static func blocked(state: Dictionary, room: Dictionary) -> String:
	if room.is_empty():
		return "Unknown room"
	if state.status != "active":
		return "Retry or undo to continue"
	if room.id in state.claimed:
		return "Already claimed"
	if room.id in state.collapsed:
		return "Bridge collapsed"
	for prerequisite in room.requires:
		if not prerequisite in state.claimed:
			return "First claim " + str(prerequisite).capitalize()
	if room.has("requires_any") and not room.requires_any.any(func(id): return id in state.claimed):
		return "First claim " + " or ".join(room.requires_any)
	if int(state.keys) < int(room.key_cost):
		return "Needs %d key%s" % [int(room.key_cost), "s" if int(room.key_cost) > 1 else ""]
	if int(room.multiplier) > 1 and int(state.shields) > 0:
		return "Sun lens refuses a carried shield"
	return ""

static func step(level: Dictionary, before: Dictionary, id: String) -> Dictionary:
	if int(level.get("rules", 1)) == 1:
		return Legacy.step(level, before, id)
	var room := find_room(level, id)
	var reason := blocked(before, room)
	if reason != "":
		return {"ok": false, "message": reason, "state": before.duplicate(true), "events": []}
	var state := before.duplicate(true)
	var events: Array = []
	state.moves += 1
	state.keys -= int(room.key_cost)
	state.last = id
	state.collapsed.append_array(room.collapse)
	if int(room.key_cost) > 0:
		events.append("Spend %d key" % int(room.key_cost))
	if not room.collapse.is_empty():
		var sealed: Array = room.collapse.map(func(id): return str(find_room(level, id).name))
		events.append("Seals: " + ", ".join(sealed))
	if int(room.trap) > 0:
		if int(state.shields) > 0:
			state.shields -= 1
			events.append("Shield blocks trap %d" % int(room.trap))
		else:
			state.power -= int(room.trap)
			events.append("Trap: -%d power" % int(room.trap))
			if int(state.power) <= 0:
				state.power = 0
				state.status = "lost"
				return {"ok": true, "win": false, "state": state, "message": "The glass trap drains your power.", "events": events}
	for enemy in room.enemies:
		if int(state.power) <= int(enemy):
			events.append("%d %s %d: lose" % [state.power, "=" if int(state.power) == int(enemy) else "<", enemy])
			state.status = "lost"
			return {"ok": true, "win": false, "state": state, "message": "You need GREATER power. Equality loses.", "events": events}
		events.append("%d > %d  +%d = %d" % [state.power, enemy, enemy, int(state.power) + int(enemy)])
		state.power += int(enemy)
	state.power = mini(MAX_POWER, int(state.power) * int(room.multiplier))
	if int(room.multiplier) > 1:
		events.append("Sun lens x%d = %d" % [room.multiplier, state.power])
	state.keys += int(room.keys)
	state.shields += int(room.shields)
	if int(room.keys) > 0:
		events.append("Take %d key%s" % [room.keys, "s" if int(room.keys) > 1 else ""])
	if int(room.shields) > 0:
		events.append("Take %d shield%s" % [room.shields, "s" if int(room.shields) > 1 else ""])
	state.claimed.append(id)
	if bool(room.get("keeper", false)):
		state.rescued.append(id)
		events.append("Keeper rescued; travels with you")
	state.treasure += 1 if room.treasure else 0
	state.status = "won" if room.rescue else "active"
	if state.status == "active" and not level.rooms.any(func(next_room): return blocked(state, next_room) == ""):
		state.status = "lost"
		events.append("No route remains: a needed key or room is gone.")
		return {"ok": true, "win": false, "state": state, "message": "Your route is stranded. Undo the commitment.", "events": events}
	return {"ok": true, "win": true, "state": state, "message": "Keeper rescued!" if room.rescue else "Room claimed. Your watch grows.", "events": events}

static func signature(state: Dictionary) -> String:
	var claimed: Array = state.claimed.duplicate()
	var collapsed: Array = state.collapsed.duplicate()
	claimed.sort()
	collapsed.sort()
	var rescued: Array = state.get("rescued", []).duplicate()
	rescued.sort()
	return JSON.stringify([state.power, state.keys, state.shields, claimed, collapsed, rescued, state.status, state.treasure])

static func solve(level: Dictionary, start: Dictionary = {}, require_treasure: bool = false) -> Dictionary:
	var queue: Array = [{"state": initial(level) if start.is_empty() else start, "route": []}]
	var seen: Dictionary = {}
	var cursor := 0
	while cursor < queue.size():
		var node: Dictionary = queue[cursor]
		cursor += 1
		if node.state.status == "won" and (not require_treasure or int(node.state.treasure) > 0):
			return {"ok": true, "route": node.route, "visited": cursor, "shortest": true}
		var key := signature(node.state)
		if seen.has(key):
			continue
		seen[key] = true
		for room in level.rooms:
			var result := step(level, node.state, room.id)
			if result.ok and result.state.status != "lost":
				var route: Array = node.route.duplicate()
				route.append(room.id)
				queue.append({"state": result.state, "route": route})
	return {"ok": false, "route": [], "visited": cursor, "shortest": false}

static func greedy(level: Dictionary) -> Dictionary:
	var state := initial(level)
	var route: Array = []
	for count in level.rooms.size():
		var options: Array = level.rooms.filter(func(room): return blocked(state, room) == "")
		options.sort_custom(func(a, b): return a.enemies.reduce(func(total, n): return total + n, 0) < b.enemies.reduce(func(total, n): return total + n, 0))
		if options.is_empty():
			break
		var result := step(level, state, options[0].id)
		route.append(options[0].id)
		state = result.state
		if state.status != "active":
			break
	return {"won": state.status == "won", "state": state, "route": route}
