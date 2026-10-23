extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
const P = preload("res://tests/policy.gd")
func _initialize():
 var records: Array = []
 var failures := 0
 for i in 12:
  for policy in ["untouched", "commander", "A", "B", "mistake"]:
   var s = C.fresh(D.mission(i))
   s.phase = "playing"
   s.planned_support = "ward" if i == 11 else "relay"
   for frame in 12000:
    if s.phase != "playing": break
    var choice = P.decide(s, policy if policy != "untouched" else "A")
    if policy == "untouched": choice = {"goal": C.position(s), "station": -1}
    if policy in ["A", "B", "mistake"] and choice.station >= 0 and C.nearby(s) == choice.station: C.buy(s, choice.station)
    C.tick(s, (choice.goal - C.position(s)).limit_length(), 0.05)
   var damage = 0.0
   for r in s.recruits: damage += r.damage
   var record = {"mission": i+1, "version": s.definition.version, "policy": policy, "phase": s.phase, "hp": s.hp, "hq": s.hq, "killed": s.killed.size(), "escaped": s.escaped.size(), "spent": s.spent, "troop_damage": damage, "commander_damage": s.commander_damage, "valid": C.valid(s)}
   records.append(record)
   print(JSON.stringify(record))
   var expected: String = "victory" if policy in ["A", "B"] or (i == 0 and policy in ["untouched", "mistake"]) or (policy == "commander" and i not in [3,7,8,11]) else "defeat"
   if s.phase != expected or not C.valid(s): failures += 1
 var sample := C.fresh(D.mission(0))
 var original := sample.duplicate(true)
 var F = load("res://scripts/reinforcement_feedback.gd")
 if F.crew_line(sample).is_empty() or not F.contribution(sample).begins_with("Crew damage 0"): failures += 1
 if sample != original: failures += 1
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var file = FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
   file.store_string(JSON.stringify({"records":records,"failures":failures,"scope":"Synthetic policy comparison; no proof of optimal play, human fun or pacing. Untouched stays at opening; commander uses all ordinary threat/objective/collection choices without purchasing; A/B buy two distinct orders; mistake buys rifles then retreats."},"  "))
   file.close()
 print("DECISION_COMPARISON 60 policies failures=",failures)
 print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")
 quit(0 if failures == 0 else 1)
