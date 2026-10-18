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
	var static_plan := false
	var response_delay := 0.0
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
		if arg == "--static":
			static_plan = true
		if arg.begins_with("--response-delay="):
			response_delay = float(arg.trim_prefix("--response-delay="))
	for id in Content.IDS:
		if selected != "" and not id in selected.split(","):
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
			var observed_wave := 0
			var response_at := 0.0
			for i in ceili(500 / dt):
				if int(state.wave) != observed_wave:
					observed_wave = int(state.wave)
					response_at = float(state.time) + response_delay
				if not applied and float(state.time) >= delay:
					Policy.apply(state, policy)
					applied = true
				if applied and policy in ["A", "B", "splash"] and not static_plan and float(state.time) >= response_at:
					Policy.adapt(state, policy)
				Battle.tick(state, dt)
				if state.phase != "battle":
					break
			var entry := {"id": id, "policy": policy, "seed": seed_value, "config_sha256": JSON.stringify(state.config).sha256_text(), "definition_version": state.config.definition_version, "delay": delay, "adaptations": not static_plan, "response_delay": response_delay, "challenge": challenge, "step": dt, "phase": state.phase, "time": state.time, "wall": state.wall, "losses": state.losses, "kills": state.kills, "spent": state.spent, "gold": state.gold, "peak": state.peak_units, "cap_seconds": state.cap_time, "produced_by_role": state.produced_by_role, "wall_ms": Time.get_ticks_msec() - began}
			results.append(entry)
			print(JSON.stringify(entry))
	var directory := "res://.artifacts/campaign"
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory + "/policy-probe-%d-%d.json" % [int(Time.get_unix_time_from_system() * 1000000), OS.get_process_id()], FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	quit()
