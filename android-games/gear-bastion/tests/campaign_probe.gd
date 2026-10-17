extends SceneTree
const Battle = preload("res://scripts/battle_rules.gd")
const Content = preload("res://scripts/campaign_data.gd")
const Policy = preload("res://tests/campaign_policies.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var results: Array = []
	var policies: Array = ["A", "B"]
	var selected := ""
	var dt := Battle.STEP
	var seeds: Array = [1701]
	var delay := 0.0
	var challenge := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--policy="):
			policies = arg.trim_prefix("--policy=").split(",")
		if arg.begins_with("--stage="):
			selected = arg.trim_prefix("--stage=")
		if arg == "--fast":
			dt = 1.0 / 15.0
		if arg.begins_with("--seeds="):
			seeds = []
			for value in arg.trim_prefix("--seeds=").split(","):
				seeds.append(int(value))
		if arg.begins_with("--delay="):
			delay = float(arg.trim_prefix("--delay="))
		if arg == "--challenge":
			challenge = true
	for id in Content.IDS:
		if selected != "" and selected != id:
			continue
		for slot in seeds.size() * policies.size():
			var policy: String = policies[slot % policies.size()]
			var seed_value: int = seeds[slot / policies.size()]
			var state := Battle.initial(seed_value, id)
			if challenge:
				state.config.challenge = true
				state.config.budget -= 6
				state.gold -= 6
			assert(Content.valid_snapshot(state.config))
			if delay <= 0:
				Policy.apply(state, policy)
			Battle.start(state)
			var began := Time.get_ticks_msec()
			var applied := delay <= 0
			for i in ceili(500 / dt):
				if not applied and float(state.time) >= delay:
					Policy.apply(state, policy)
					applied = true
				if applied and policy in ["A", "B"]:
					Policy.adapt(state, policy)
				Battle.tick(state, dt)
				if state.phase != "battle":
					break
			var entry := {"id": id, "policy": policy, "seed": seed_value, "delay": delay, "challenge": challenge, "step": dt, "phase": state.phase, "time": state.time, "wall": state.wall, "losses": state.losses, "kills": state.kills, "spent": state.spent, "gold": state.gold, "peak": state.peak_units, "cap_seconds": state.cap_time, "produced_by_role": state.produced_by_role, "wall_ms": Time.get_ticks_msec() - began}
			results.append(entry)
			print(JSON.stringify(entry))
	var directory := "res://.artifacts/campaign"
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory + "/policy-probe-%d.json" % Time.get_ticks_msec(), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	quit()
