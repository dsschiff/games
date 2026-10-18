extends RefCounted
const Gear = preload("res://scripts/gear_rules.gd")

static func plan(state: Dictionary, policy: String) -> Array:
	var config: Dictionary = state.config
	var steps: Array = []
	if policy == "starter":
		return steps
	if state.encounter == "camp_01":
		steps.append({"move": 3, "x": 1, "y": 2})
	if state.encounter == "camp_05":
		steps.append({"move": 2, "x": 1, "y": 1})
		steps.append({"move": 3, "x": 3, "y": 1})
	if policy in ["guard", "ranger", "mortar", "cheapest"]:
		var role := "drive" if policy == "cheapest" else policy
		var cells: Array = config.sockets.duplicate(true)
		cells.sort_custom(func(a, b): return absi(int(a[0]) - 2) + absi(int(a[1]) - 2) < absi(int(b[0]) - 2) + absi(int(b[1]) - 2))
		for cell in cells:
			steps.append({"kind": role, "x": int(cell[0]), "y": int(cell[1]), "lane": (int(cell[0]) / 2) % 3})
		return steps
	if state.encounter == "camp_01":
		for entry in ([["guard", 3, 2, 2], ["drive", 1, 1, 1], ["drive", 3, 1, 1]] if policy == "A" else [["guard", 2, 3, 1], ["drive", 1, 3, 1], ["drive", 3, 3, 1]]):
			steps.append({"kind": entry[0], "x": entry[1], "y": entry[2], "lane": entry[3]})
		return steps
	var entries: Array
	if state.encounter == "camp_05":
		entries = [["guard", 1, 2, 0], ["guard", 3, 2, 2], ["ranger", 0, 2, 0], ["ranger", 4, 2, 2], ["mortar", 2, 3, 1], ["drive", 1, 3, 1], ["drive", 3, 3, 1]] if policy == "A" else [["guard", 1, 2, 0], ["guard", 3, 2, 2], ["guard", 2, 3, 1], ["ranger", 0, 2, 0], ["mortar", 4, 2, 2], ["drive", 1, 3, 1], ["drive", 3, 3, 1]]
	else:
		var adaptive: bool = policy == "A" and state.encounter in ["camp_02", "camp_08"]
		entries = [["guard", 1, 2, 0], ["guard", 3, 2, 2], ["ranger", 1, 1, 0], ["ranger", 3, 1, 2]] if policy == "A" and not adaptive else [["guard", 1, 2, 0], ["guard", 3, 2, 2], ["guard", 2, 3, 1], ["ranger", 1, 1, 0]]
		if "mortar" in config.allowed:
			entries.append(["mortar", 2, 3, 1] if policy == "A" and not adaptive else ["mortar", 3, 1, 2])
		if state.encounter == "camp_09" and policy == "B":
			entries.append(["ranger", 0, 2, 2])
		entries.append(["drive", 1, 3, 1])
		entries.append(["drive", 3, 3, 1])
		entries.append(["drive", 0, 2, 0])
		entries.append(["drive", 4, 2, 2])
	for p in entries:
		steps.append({"kind": p[0], "x": p[1], "y": p[2], "lane": 0 if state.encounter == "camp_07" else p[3]})
	return steps

static func apply(state: Dictionary, policy: String) -> void:
	for step in plan(state, policy):
		if step.has("move"):
			var moved := Gear.move(state.board, int(step.move), int(step.x), int(step.y), state.encounter, state.config)
			if moved.ok:
				state.board = moved.board
			continue
		var result := Gear.buy(state.board, step.kind, int(step.x), int(step.y), int(state.gold), int(state.next_id), state.encounter, state.config)
		if result.ok:
			state.board = result.board
			state.board.back().lane = int(step.lane)
			state.gold = result.gold
			state.spent += int(state.config.costs[step.kind])
			state.next_id += 1

static func refit_steps(state: Dictionary, x: int, y: int, desired: String) -> Array:
	var board: Array = state.board.duplicate(true)
	var index := Gear.at(board, x, y)
	var result: Array = []
	var gold := int(state.gold)
	if index < 0:
		return result
	for attempt in 3:
		if board[index].kind == desired:
			break
		var refitted := Gear.refit(board, int(board[index].id), gold, state.config.allowed, state.config.costs)
		if not refitted.ok:
			break
		result.append({"refit": int(board[index].id), "x": x, "y": y, "cost": refitted.cost})
		board = refitted.board
		gold = refitted.gold
	return result

static func adaptations(state: Dictionary, policy: String) -> Array:
	var steps: Array = []
	if policy in ["A", "B"] and state.encounter == "camp_08":
		if int(state.wave) >= 2:
			if policy == "A":
				steps.append_array(refit_steps(state, 2, 3, "ranger"))
				var used := 0
				for step in steps:
					used += int(step.cost)
				if Gear.at(state.board, 1, 3) < 0 and int(state.gold) - used >= int(state.config.costs.drive):
					steps.append({"kind": "drive", "x": 1, "y": 3, "lane": 1})
			else:
				steps.append_array(refit_steps(state, 1, 2, "ranger"))
				steps.append_array(refit_steps(state, 3, 2, "ranger"))
		return steps
	if policy == "A" and state.encounter == "camp_02" and int(state.wave) >= 2:
		steps.append_array(refit_steps(state, 2, 3, "ranger"))
	if policy == "splash" and state.encounter == "camp_08" and int(state.wave) >= 2:
		steps.append_array(refit_steps(state, 1, 1, "ranger" if int(state.wave) >= 5 else "mortar"))
	if state.encounter == "camp_07":
		for p in state.board:
			if not p.kind in Gear.BASE_RATES:
				continue
			var lane: int = 0 if state.wave == 1 else 2 if state.wave == 2 else 1 if state.wave == 3 else 0 if int(p.x) < 2 else 2
			if int(p.lane) != lane:
				steps.append({"gate": lane, "id": int(p.id), "x": int(p.x), "y": int(p.y)})
	if policy == "splash" and state.encounter == "camp_08" and state.wave >= 2:
		var available: int = int(state.gold)
		for step in steps:
			if step.has("refit"):
				available -= int(step.cost)
		var purchases: Array = [["drive", 0, 2, 1], ["drive", 4, 2, 1], ["drive", 1, 0, 1], ["drive", 3, 0, 1]]
		for purchase in purchases:
			if Gear.at(state.board, int(purchase[1]), int(purchase[2])) >= 0:
				continue
			var cost: int = state.config.costs[purchase[0]]
			if available < cost:
				break
			available -= cost
			steps.append({"kind": purchase[0], "x": purchase[1], "y": purchase[2], "lane": purchase[3]})
	return steps

static func adapt(state: Dictionary, policy: String) -> void:
	for step in adaptations(state, policy):
		if step.has("refit"):
			var result := Gear.refit(state.board, int(step.refit), int(state.gold), state.config.allowed, state.config.costs)
			if result.ok:
				state.board = result.board
				state.gold = result.gold
				state.spent += int(result.cost)
		elif step.has("gate"):
			for p in state.board:
				if int(p.id) == int(step.id):
					p.lane = int(step.gate)
		else:
			var result := Gear.buy(state.board, step.kind, int(step.x), int(step.y), int(state.gold), int(state.next_id), state.encounter, state.config)
			if result.ok:
				state.board = result.board
				state.board.back().lane = int(step.get("lane", 1))
				state.gold = result.gold
				state.next_id += 1
				state.spent += int(state.config.costs[step.kind])
