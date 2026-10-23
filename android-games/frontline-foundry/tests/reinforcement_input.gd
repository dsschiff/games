extends "res://tests/campaign_input.gd"
var before := ""
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--before-campaign="): before = arg.trim_prefix("--before-campaign=")
 root.size = Vector2i(720,1280)
 Engine.time_scale = 4.0
 scene = load(before if not before.is_empty() else "res://scripts/campaign_main.gd").new()
 root.add_child(scene)
 app = scene
 await dwell(3)
 await click("LAUNCH SORTIE")
 await snap("before-purchase")
 var stage_seen := {}
 for frame in 500:
  if scene.state.purchases.is_empty():
   await steer((D.pad(scene.state.definition,0) - C.position(scene.state)).limit_length())
   if C.nearby(scene.state) == 0:
    await release()
    await click(scene.build_button.text)
  else:
   await release()
  await physics_frame
  var r = scene.state.recruits[0]
  var stage: String = r.phase
  if not stage_seen.has(stage) and stage in ["equipping","deploying","fighting"]:
   stage_seen[stage] = true
   await snap(stage)
  if r.damage > 0:
   await snap("earned-damage")
   break
 check(scene.state.bought[0] == 1 and scene.state.recruits[0].damage > 0, "actual touch purchase arms one individual who deploys and deals damage")
 if before.is_empty():
  check(scene.queue_label.visible and "DAMAGE" in scene.queue_label.text, "live footer names earned individual contribution")
 var original := root.size
 for dimensions in [Vector2i(720,1680),Vector2i(1153,1280),Vector2i(2276,1280)]:
  root.size = dimensions
  await dwell(3)
  for goal in [Vector2(-4.5,5.7),Vector2(4.5,-6.0),Vector2(0,1.5)]:
   for frame in 160:
    if C.position(scene.state).distance_to(goal) < .35 or scene.state.phase != "playing": break
    await steer((goal-C.position(scene.state)).limit_length())
    await physics_frame
   await release()
   await dwell(5)
   if before.is_empty():
    var rect: Rect2 = scene.hq_indicator.get_global_rect()
    check(rect.end.y < scene.build_button.position.y and rect.end.y < scene.guidance.position.y, "HQ indicator clears real controls/guidance " + str(dimensions) + str(goal))
    check(not rect.intersects(scene.stick.get_global_rect()), "HQ indicator clears joystick " + str(dimensions) + str(goal))
    check(not scene.guidance.get_global_rect().intersects(scene.stick.get_global_rect()) and not scene.guidance.get_global_rect().intersects(scene.build_button.get_global_rect()), "counter guidance clears touch controls " + str(dimensions))
    check(not scene.queue_label.get_global_rect().intersects(scene.stick.get_global_rect()) and not scene.queue_label.get_global_rect().intersects(scene.build_button.get_global_rect()), "footer clears stick and equipment action " + str(dimensions))
    check(scene.queue_label.get_minimum_size().x <= scene.queue_label.size.x, "individual feedback fits profile " + str(dimensions))
   await snap("profile-%s-at-%s" % [str(dimensions),str(goal)])
 if before.is_empty():
  var view: Vector2 = root.get_visible_rect().size
  for anchor in [Vector2(90, view.y - 140), Vector2(180, view.y - 140)]:
   origin = anchor
   await steer(Vector2.UP)
   await physics_frame
   check(scene.stick_id == 0 and scene.input_vector.length() > .9, "actual held stick is active at " + str(anchor))
   check(not scene.stick.get_global_rect().intersects(scene.guidance.get_global_rect()) and not scene.stick.get_global_rect().intersects(scene.hq_indicator.get_global_rect()) and not scene.stick.get_global_rect().intersects(scene.queue_label.get_global_rect()), "representative held anchor clears guidance/HQ/footer " + str(anchor))
   await snap("held-stick-" + str(anchor))
   await release()
 root.size = original
 await release()
 write_report()
 scene.queue_free()
 await process_frame
 await process_frame
 print("FOCUSED_FEEDBACK checks=",checks," failures=",failures," before=",not before.is_empty())
 print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL")
 quit(0 if failures==0 else 1)
