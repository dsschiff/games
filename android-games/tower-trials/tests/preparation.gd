extends SceneTree

const Prepared = preload("res://design/prepared_cases.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func explore(level: Dictionary) -> Dictionary:
	var queue: Array = [{"state": Rules.initial(level), "route": []}]
	var seen: Dictionary = {}
	var cursor := 0
	var wins := 0
	var losses := 0
	var treasure_route: Array = []
	var richest := -1
	while cursor < queue.size():
		var node: Dictionary = queue[cursor]
		cursor += 1
		var signature := Rules.signature(node.state)
		if seen.has(signature):
			continue
		seen[signature] = true
		if node.state.status == "won":
			wins += 1
			if int(node.state.treasure) > richest:
				richest = int(node.state.treasure)
				treasure_route = node.route
			continue
		if node.state.status == "lost":
			losses += 1
			continue
		for room in level.rooms:
			var before: Dictionary = node.state.duplicate(true)
			var result := Rules.step(level, node.state, room.id)
			check(node.state == before, "Preview purity " + level.id + ":" + room.id)
			if not result.ok:
				continue
			var route: Array = node.route.duplicate()
			route.append(room.id)
			var reconstructed := Rules.initial(level)
			for id in node.route:
				reconstructed = Rules.step(level, reconstructed, id).state
			check(reconstructed == before, "Undo prefix reconstructs every field " + level.id)
			queue.append({"state": result.state, "route": route})
	return {"states": seen.size(), "successful_terminal_states": wins, "losing_terminal_states": losses, "most_treasure": richest, "treasure_route": treasure_route, "qualification": "State-space exploration deduplicates equivalent histories; not a count of unique solutions"}

func _initialize() -> void:
	var rows: Array = []
	for level in Prepared.cases():
		var solved := Rules.solve(level)
		check(solved.ok and solved.route.size() <= int(level.par), "Prepared case has achievable par " + level.id)
		var graph := explore(level)
		check(graph.successful_terminal_states > 0 and graph.losing_terminal_states > 0, "Prepared case offers consequential routes " + level.id)
		rows.append({"id": level.id, "shortest_route": solved.route, "greedy": Rules.greedy(level), "graph": graph})
	var selected: Dictionary = Prepared.cases()[5]
	var greedy := Rules.greedy(selected)
	check(not greedy.won, "Smallest-first wastes the rescue key on optional treasure")
	var file_path := "res://.artifacts/preparation"
	DirAccess.make_dir_recursive_absolute(file_path)
	var file := FileAccess.open(file_path + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": rows, "status": "Inactive solver preparation; not playable campaign"}, "\t"))
	file.close()
	print("TOWER PREPARATION: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
