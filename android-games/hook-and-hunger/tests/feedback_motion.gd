extends "res://tests/contact_feedback.gd"
## Short normal-cadence capture. Fixtures below never enter a save or earned route.
var label: Label
var movie_frame := 0
var recording := false
var frame_capture := false
var markers: Array = []
var fixture_view: Node3D
var framebuffer_ok := true

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--frames": frame_capture = true
	call_deferred("run")

func frame() -> void:
	if not recording: return
	var image := root.get_texture().get_image()
	framebuffer_ok = framebuffer_ok and image.get_size() == Vector2i(720,1280)
	image.save_png(capture_dir.path_join("frames/%06d.png" % movie_frame))
	movie_frame += 1

func caption(text: String) -> void:
	label.text = text
	markers.append({"frame":movie_frame,"physics_frame":Engine.get_physics_frames(),"label":text})

func photograph(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	root.size = Vector2i(720,1280)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(24,310)
	label.size = Vector2(672,95)
	label.add_theme_font_size_override("font_size",25)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(4)
	if frame_capture and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("frames"))
		RenderingServer.frame_post_draw.connect(frame)
		recording = true
	caption("REAL INPUT / fresh opening\nApproach, then retreat before contact")
	await steer(Vector2(0,-1))
	for i in 600:
		await physics_frame
		if scene.state.strike > .30 and not scene.state.contact: break
	check(scene.state.strike > .30 and scene.state.strike_id >= 0,"actual approach launches automatic chain")
	var id: int = scene.state.strike_id
	var target := enemy_by_id(scene.state,id)
	var hp: float = target.hp
	var contacts: int = scene.presentation.event_counts.get("contact",0)
	await steer((R.position(scene.state)-Vector2(target.x,target.z)).normalized())
	for i in 30:
		await physics_frame
		if scene.state.contact: break
	await release()
	target = enemy_by_id(scene.state,id)
	check(scene.state.contact and target.hp == hp,"retreat causes genuine miss with unchanged target hull")
	check(scene.presentation.event_counts.get("contact",0) == contacts,"miss has no gold contact event")
	caption("REAL INPUT / MISS\nTarget hull %d → %d; no gold burst" % [hp,target.hp])
	observations.append({"case":"actual_input_miss","state":scene.state.duplicate(true),"events":scene.presentation.events.duplicate(true),"hp_before":hp,"hp_after":target.hp})
	await photograph("01-real-input-miss")
	await dwell(24)
	caption("REAL INPUT / re-approach\nHold in reach for a genuine hit")
	for i in 900:
		target = enemy_by_id(scene.state,id)
		if target.is_empty() or target.hp < hp: break
		await steer(policy(scene.state))
		await physics_frame
	await release()
	target = enemy_by_id(scene.state,id)
	check(target.is_empty() or target.hp < hp,"actual re-approach earns damage")
	check(scene.presentation.event_counts.get("contact",0) > contacts,"real damage emits gold contact")
	caption("REAL INPUT / HIT\nTarget hull %d → %d; gold contact" % [hp,0 if target.is_empty() else target.hp])
	observations.append({"case":"actual_input_hit","state":scene.state.duplicate(true),"events":scene.presentation.events.duplicate(true),"hp_before":hp,"hp_after":0 if target.is_empty() else target.hp})
	await photograph("02-real-input-hit")
	await dwell(45)
	scene.free()
	await process_frame
	await armor_fixture()
	for attack in ["line","charge","shot"]: await warning_fixture(attack)
	recording = false
	if frame_capture: check(framebuffer_ok and movie_frame > 0,"all recorded framebuffer sizes are native720x1280")
	if frame_capture: RenderingServer.frame_post_draw.disconnect(frame)
	if not capture_dir.is_empty():
		FileAccess.open(capture_dir.path_join("feedback-motion-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"observations":observations,"events":events,"markers":markers,"frames":movie_frame,"cadence":60,"scope":"Actual engine touch opening miss and hit only. Armor/line/charge/projectile are explicitly synthetic rule-derived arrangements, not earned progression. 1x playback cadence; no measured FPS, Android, sound or human acceptance."},"  "))
	layer.free()
	await process_frame
	print("FEEDBACK_MOTION ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func setup_fixture(role: String, stage: int, seed: int = 1701) -> Dictionary:
	var state := C.fresh(stage,3,0,seed)
	var chosen: Dictionary = {}
	for enemy in C.active(state):
		if state.definition.roster[int(enemy.id)].role == role:
			chosen = enemy
			break
	check(not chosen.is_empty(),"fixture roster contains " + role)
	state.enemies = [chosen]
	chosen.x = 0.0; chosen.z = -2.0
	chosen.ax = 0.0; chosen.az = -2.0
	chosen.facing = 0.0
	state.x = 0.0; state.z = 1.0
	state.time = 10.0
	fixture_view = Adapter.new()
	root.add_child(fixture_view)
	fixture_view.build(state)
	var camera: Camera3D = fixture_view.island.camera
	camera.position = Vector3(0,18,14)
	camera.look_at(Vector3(0,0,0))
	return state

func fixture_frames(state: Dictionary, count: int) -> void:
	for i in count:
		state.time += 1.0 / 60
		fixture_view.capture(state)
		fixture_view.present(1.0 / 60)
		await physics_frame

func armor_fixture() -> void:
	caption("SYNTHETIC ARMOR FIXTURE\nRule strike against shield front")
	var state := setup_fixture("shield",4)
	var enemy: Dictionary = state.enemies[0]
	state.strike_id = enemy.id
	state.strike_x = enemy.x; state.strike_z = enemy.z
	state.strike = .36; state.contact = false; state.time += .02
	fixture_view.capture(state)
	await fixture_frames(state,18)
	var hp: float = enemy.hp
	C._strike(state)
	state.contact = true; state.strike = .18; state.time += .02
	fixture_view.capture(state)
	fixture_view.present(0)
	check(enemy.hp == hp and state.blocked > 0,"existing shield rule blocks fixture strike")
	check(fixture_view.event_counts.get("blocked",0) == 1 and fixture_view.event_counts.get("contact",0) == 0,"armor fixture pale block has no gold contact")
	observations.append({"case":"synthetic_armor","state":state.duplicate(true),"events":fixture_view.events.duplicate(true),"hp_before":hp,"hp_after":enemy.hp})
	await photograph("03-synthetic-armor-block")
	await fixture_frames(state,54)
	fixture_view.free()
	await process_frame

func warning_fixture(attack: String) -> void:
	caption("SYNTHETIC %s FIXTURE\nExisting windup footprint; then rule resolve" % attack.to_upper())
	var state := setup_fixture("lancer" if attack == "line" else "charger" if attack == "charge" else "spitter",9,5 if attack == "charge" else 1701)
	var enemy: Dictionary = state.enemies[0]
	enemy.mode = "wind"; enemy.attack = attack; enemy.tx = 0.0; enemy.tz = 1.0; enemy.clock = 1.0
	state.x = -2.0; state.z = 1.0
	if attack == "charge":
		caption("SYNTHETIC CHARGE / rock deflection\nConservative paint covers redirected route")
		enemy.x = -1.4; enemy.z = -7.0; enemy.ax = -1.4; enemy.az = -7.0
		state.x = -2.4; state.z = -2.515
		var camera: Camera3D = fixture_view.island.camera
		camera.position = Vector3(0,18,10)
		camera.look_at(Vector3(0,0,-3))
	fixture_view.hydrate(state)
	var held := state.duplicate(true)
	await fixture_frames(state,42)
	var strip: MeshInstance3D = fixture_view.actors[int(enemy.id)].warning.get_node("Line")
	check(strip.visible and strip.mesh.size.x * absf(strip.scale.x) / 2 >= (.8 if attack == "line" else .9 if attack == "charge" else .5) - .00001,"rendered " + attack + " strip covers current damaging half width")
	await photograph("04-synthetic-" + attack + "-windup")
	C._resolve(state,enemy,state.definition.roster[int(enemy.id)])
	for i in (60 if attack == "charge" else 48):
		C.step(state,Vector2.ZERO,1.0/60)
		fixture_view.capture(state)
		fixture_view.present(1.0/60)
		await physics_frame
	if attack == "charge": check(state.hp < held.hp,"real rule step damages fixture diver on rock-deflected charge")
	observations.append({"case":"synthetic_"+attack,"windup_state":held,"resolved_state":state.duplicate(true),"events":fixture_view.events.duplicate(true)})
	await photograph("05-synthetic-" + attack + "-resolved")
	fixture_view.free()
	await process_frame

