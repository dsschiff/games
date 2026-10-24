extends "res://tests/feedback_motion.gd"
const Policy = preload("res://tests/campaign_policy.gd")
var checkpoint := ""
var force_defeat := false
var drain_audio := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--checkpoint="): checkpoint = arg.trim_prefix("--checkpoint=")
		if arg == "--frames": frame_capture = true
		if arg == "--force-defeat": force_defeat = true
		if arg == "--drain-audio": drain_audio = true
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720,1280)
	var loaded := S.decode(FileAccess.get_file_as_string(checkpoint))
	check(loaded.ok,"historical earned full-journey checkpoint decodes")
	if not loaded.ok: quit(1); return
	check(S.write(loaded.state,loaded.settings,S.PATH,null,false,loaded.profile),"install whole earned checkpoint in isolated save")
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.state == loaded.state and scene.profile == loaded.profile and scene.settings == loaded.settings,"normal load restores exact historical whole context")
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(24,310)
	label.size = Vector2(672,110)
	label.add_theme_font_size_override("font_size",23)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)
	await click("RESUME")
	if frame_capture and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("frames"))
		RenderingServer.frame_post_draw.connect(frame)
		recording = true
	caption("REAL INPUT / earned passage continuation\nNo enemy, rule or player state edits")
	var locked: Dictionary = {}
	var goal := Vector2.ZERO
	var windows: Array = []
	var passed_sidestep := false
	var most_charges := 0
	for tick in 720:
		if scene.state.phase != "playing": break
		var s: Dictionary = scene.state
		var charging: Array = []
		for enemy in C.active(s):
			if enemy.attack == "charge" and enemy.mode in ["wind","charge"]: charging.append(enemy)
		most_charges = maxi(most_charges,charging.size())
		if locked.is_empty():
			for enemy in charging:
				if enemy.mode != "wind": continue
				if not inside(scene.presentation.actors[int(enemy.id)].warning.get_node("Line"),C.p(s)): continue
				var picked := safe_goal(charging)
				if not picked.is_empty():
					goal = picked.point
					locked = {"id":enemy.id,"start":s.time,"hp_before":s.hp,"goal":goal,"outside_before_charge":false,"charge_hit":false,"simultaneous":charging.size(),"initial_state":s.duplicate(true),"started_inside":true,"envelope":str(scene.presentation._charge_envelope(s,enemy))}
					caption("REAL INPUT / charger sidestep\nMove beyond the visible warning edge")
					await photograph("charge-%d-windup" % windows.size())
					break
		if not locked.is_empty():
			var enemy := enemy_by_id(s,int(locked.id))
			if not enemy.is_empty() and enemy.mode == "wind":
				var strip: MeshInstance3D = scene.presentation.actors[int(enemy.id)].warning.get_node("Line")
				locked.outside_before_charge = not inside(strip,C.p(s))
			if not enemy.is_empty() and enemy.charge_hit: locked.charge_hit = true
			if enemy.is_empty() or not enemy.mode in ["wind","charge"]:
				locked.hp_after = s.hp
				locked.end_state = s.duplicate(true)
				locked.moved = C.p(s).distance_to(C.p(locked.initial_state))
				locked.success = locked.started_inside and locked.outside_before_charge and locked.moved > .25 and not locked.charge_hit
				passed_sidestep = passed_sidestep or locked.success
				windows.append(locked.duplicate(true))
				caption("REAL INPUT / charge resolved\n%s" % ("Outside warning; charge did not hit" if locked.success else "Recorded outcome; inspect report"))
				await photograph("charge-%d-resolved" % (windows.size()-1))
				locked = {}
		var direction := (goal-C.p(s)).limit_length() if not locked.is_empty() else Policy.direction(s)
		await steer(direction)
		await physics_frame
	await release()
	if force_defeat:
		for tick in 2400:
			if scene.state.phase != "playing": break
			await physics_frame
		check(scene.state.phase == "defeat","teardown probe reaches natural defeat without state writes")
	recording = false
	if frame_capture:
		RenderingServer.frame_post_draw.disconnect(frame)
		check(framebuffer_ok and movie_frame > 0,"all captured frames are native720x1280")
	check(passed_sidestep,"actual touch gets outside painted charge warning before resolve and avoids that charge")
	check(C.valid(scene.state),"earned continuation remains valid without rule-state writes")
	FileAccess.open(capture_dir.path_join("charge-play-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"windows":windows,"maximum_simultaneous_charges":most_charges,"frames":movie_frame,"cadence":60,"markers":markers,"events":events,"initial":loaded,"final_state":scene.state,"scope":"Exact authenticated earned checkpoint continued through normal load/actual touch; safe-goal policy reads presentation geometry. No synthetic state/rule edits, no human/device/FPS acceptance."},"  "))
	FileAccess.open(capture_dir.path_join("continued-save.json"),FileAccess.WRITE).store_string(S.encode(scene.state,scene.settings,0,true,scene.profile))
	if drain_audio: scene.audio.stop()
	scene.free()
	layer.free()
	await process_frame
	if drain_audio: OS.delay_msec(100)
	print("CHARGE_PLAY ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func inside(strip: MeshInstance3D,point: Vector2) -> bool:
	var local := strip.to_local(Vector3(point.x,strip.global_position.y,point.y))
	var half: Vector3 = strip.mesh.size / 2
	return absf(local.x) <= half.x and absf(local.z) <= half.z

func safe_goal(enemies: Array) -> Dictionary:
	var p := C.p(scene.state)
	var best := {}
	var distance := INF
	for enemy in enemies:
		if not scene.presentation.actors.has(int(enemy.id)): continue
		var strip: MeshInstance3D = scene.presentation.actors[int(enemy.id)].warning.get_node("Line")
		var local := strip.to_local(Vector3(p.x,strip.global_position.y,p.y))
		var half: Vector3 = strip.mesh.size / 2
		for edge in [-1.0,1.0]:
			var world := strip.to_global(Vector3(edge*(half.x+.08),0,local.z))
			var candidate := Vector2(world.x,world.z)
			if candidate.distance_to(C.constrain(scene.state,candidate,.4)) > .001 or candidate.y >= 4.7: continue
			var clear := true
			for other in enemies:
				if other.mode == "wind" and scene.presentation.actors.has(int(other.id)):
					if inside(scene.presentation.actors[int(other.id)].warning.get_node("Line"),candidate): clear = false
			if clear and p.distance_to(candidate) < distance:
				distance = p.distance_to(candidate)
				best = {"point":candidate}
	return best
