extends SceneTree
## Development balance sweep (rule fixture, not engine input or earned progress).
## Prints per-road outcomes for each weapon/priority plus an unattended run.
const R = preload("res://scripts/campaign_rules.gd")
const P = preload("res://tests/campaign_policy.gd")
const S = preload("res://scripts/campaign_store.gd")

func play(index: int, weapon: String, priority: String, seed: int = 0) -> Dictionary:
	var s := R.fresh(index, weapon, seed)
	s.phase = "playing"
	var live: Array = []
	var peak := 0
	var cost := 0
	var worst := 0
	var boss_tick := -1
	var save := {}
	while s.phase == "playing":
		if s.tick == s.definition.boss.born and weapon == "rivet" and priority != "idle":
			var ctx := S.fresh()
			ctx.campaign = s
			for c in index: ctx.profile.clears.append(c)
			for c in index: ctx.profile.medals[str(c)] = {"rescues": false, "no_loss": false, "best_crew": 5}
			var t1 := Time.get_ticks_usec()
			var code := S.encode(ctx, 1)
			var t2 := Time.get_ticks_usec()
			var ok: bool = S.decode(code).ok
			save = {"bytes": code.length(), "encode_us": t2 - t1, "decode_us": Time.get_ticks_usec() - t2, "ok": ok}
		if s.tick % 600 == 0 and not R.valid(s):
			print("INVALID ", index, " ", weapon, " tick=", s.tick)
			break
		if boss_tick < 0 and s.boss.dead: boss_tick = s.tick - s.definition.boss.born
		if priority == "sloppy":
			# Bad play: reacts once a second to the single nearest infected and
			# never works gates, rescues or telegraphs.
			if s.tick % 60 == 0:
				var eta := INF
				for i in s.enemies.size():
					var def: Dictionary = s.definition.enemies[i]
					if s.tick >= def.born and not s.enemies[i].resolved and s.enemies[i].z / def.speed < eta:
						eta = s.enemies[i].z / def.speed
						R.steer(s, def.x)
		elif priority != "idle" and s.tick % 15 == 0: R.steer(s, P.aim(s, priority))
		var t0 := Time.get_ticks_usec()
		R.step(s)
		var dt := Time.get_ticks_usec() - t0
		cost += dt
		worst = maxi(worst, dt)
		if s.tick % 30 == 0:
			var n := 0
			for i in s.enemies.size():
				if s.tick >= s.definition.enemies[i].born and not s.enemies[i].resolved: n += 1
			live.append(n)
		peak = maxi(peak, s.crew)
	live.sort()
	return {"phase": s.phase, "tick": s.tick, "crew": s.crew, "peak": peak, "lost": s.lost, "joined": s.joined, "kills": s.kills, "leaks": s.leaks, "boss": s.boss.hp,
		"live_med": live[live.size() / 2] if live.size() else 0, "live_p90": live[live.size() * 9 / 10] if live.size() else 0, "live_max": live[-1] if live.size() else 0,
		"enemies": s.enemies.size(), "us_tick": cost / maxi(1, s.tick), "us_worst": worst, "sides": s.sides.map(func(x): return x.claimed), "boss_tick": boss_tick, "window": s.definition.duration - s.definition.boss.born, "save": save, "notice": s.notice.substr(0, 60)}

func _initialize() -> void:
	var only: Array = []
	var weapons := ["rivet", "lance", "fan"]
	var priorities := ["rescue"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--roads="): only = Array(arg.trim_prefix("--roads=").split(",")).map(func(x): return int(x))
		if arg.begins_with("--priority="): priorities = arg.trim_prefix("--priority=").split(",")
	var wins := 0
	var total := 0
	for index in 24:
		if not only.is_empty() and index not in only: continue
		for priority in priorities:
			for weapon in weapons:
				var r := play(index, weapon, priority)
				total += 1
				wins += int(r.phase == "victory")
				print("ROAD %02d %-6s %-6s %-7s crew=%2d peak=%2d lost=%3d join=%3d kill=%3d leak=%3d en=%3d live med=%2d p90=%2d max=%2d boss=%d us/tick=%d worst=%d boss@%d/%d %s %s %s" % [index + 1, weapon, priority, r.phase, r.crew, r.peak, r.lost, r.joined, r.kills, r.leaks, r.enemies, r.live_med, r.live_p90, r.live_max, r.boss, r.us_tick, r.us_worst, r.boss_tick, r.window, str(r.sides), str(r.save) if r.save else "", r.notice if r.phase != "victory" else ""])
		var idle := play(index, "rivet", "idle")
		print("IDLE %02d %s crew=%d tick=%d %s" % [index + 1, idle.phase, idle.crew, idle.tick, idle.notice])
	print("WINS ", wins, "/", total)
	quit()
