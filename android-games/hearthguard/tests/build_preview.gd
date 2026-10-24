extends "res://tests/import_recovery.gd"
var preview_observations: Array=[]
var preview_profile: Dictionary={}
func contact(point: Vector2,index: int,pressed: bool) -> void:
	var e:=InputEventScreenTouch.new(); e.index=index; e.position=root.get_final_transform()*point; e.pressed=pressed
	Input.parse_input_event(e); Input.flush_buffered_events()
	events.append({"frame":Engine.get_physics_frames(),"kind":"gui_press" if pressed else "gui_release","index":index,"target":"prospective coverage","position":[e.position.x,e.position.y]})
	await process_frame
func drag_contact(point: Vector2,index: int,relative: Vector2) -> void:
	var e:=InputEventScreenDrag.new(); e.index=index; e.position=root.get_final_transform()*point; e.relative=relative
	Input.parse_input_event(e); Input.flush_buffered_events(); events.append({"frame":Engine.get_physics_frames(),"kind":"gui_drag","index":index,"position":[e.position.x,e.position.y]}); await process_frame
func run() -> void:
	root.size=Vector2i(720,1280); fixtures=build_fixtures()
	var context:=S.decode(S.encode(C.fresh(Cat.definition(0)),R.profile(),{"sound":false,"reduced_effects":false},1,true,C.profile()))
	var io:=fixture_io(context); await open_owner(io); await action("BEGIN WATCH"); scene.set_physics_process(true)
	await gather_supply(); await move_to(C.pad_point(scene.state.definition,2),500); scene.set_physics_process(false)
	check(scene.state.wallet==18 and scene.state.collected.size()==6 and scene.state.ledger.is_empty(),"actual Begin and joystick input earn the complete bootstrap budget without injected currency")
	check(C.nearby(scene.state)==2 and scene.action_buttons[2].is_visible_in_tree() and not scene.action_buttons[2].disabled,"actual movement reaches an empty pad with an affordable Beacon action")
	var before:=decoded_context(scene); var files: Dictionary=io.files.duplicate(true); var writes: int=io.writes
	await contact(scene.action_buttons[2].get_global_rect().get_center(),1,true); await process_frame
	var ring: MeshInstance3D=scene.presenter.range_ring
	var label: Variant=scene.get("build_preview_label")
	check(ring.visible and is_equal_approx(ring.mesh.outer_radius*ring.scale.x,scene.state.definition.families[2].stats[0].range),"holding an existing build choice previews its exact prospective pinned range before spending")
	check(label is Label and label.visible and label.text.contains("PREVIEW") and label.text.contains("BEACON"),"held prospective coverage is explicitly labelled before purchase")
	check(exact(decoded_context(scene),before) and io.files==files and io.writes==writes,"press-only preview changes no complete state/profile/settings/parked context or file/write count")
	preview_observations.append({"before":before,"held_range_visible":ring.visible,"held_radius":ring.mesh.outer_radius*ring.scale.x,"held_label":label.text if label is Label else "absent","raw_files":files,"input_scope":"Actual fresh Begin, joystick pickup and pad approach, then actual held Beacon button; cached headless/Dummy."})
	await drag_contact(Vector2(690,300),1,Vector2(0,-500)); await contact(Vector2(690,300),1,false); await process_frame
	check(exact(decoded_context(scene),before) and io.files==files and io.writes==writes,"release outside cancels without a purchase or save")
	await preview_family_cases()
	await preview_purchase_cases()
	await preview_context_cases()
	await preview_contact_cases()
	await preview_continuation_case()
	await preview_boss_layout_cases()
	await shutdown(); await process_frame
	FileAccess.open(folder.path_join("build-preview.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details,"events":events,"observations":preview_observations,"scope":"Actual engine input and headless presentation geometry; no rendered/native/clipboard/human acceptance."},"  "))
	print("BUILD_PREVIEW ",checks," failures=",failures); print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)

func preview_fixture(mirrored: bool=false,pad: int=2) -> Dictionary:
	var battle:=C.fresh(Cat.definition(4,37,-1,mirrored)); battle.phase="playing"
	for frame in 1000:
		if battle.coins.is_empty(): break
		var coin: Dictionary=battle.coins[0]; C.tick(battle,(Vector2(coin.x,coin.z)-C.position(battle)).limit_length(),1.0/60)
	var goal:=C.pad_point(battle.definition,pad)+Vector2(.55,.35)
	for frame in 600:
		if C.position(battle).distance_to(goal)<.05: break
		C.tick(battle,(goal-C.position(battle)).limit_length(),1.0/60)
	if preview_profile.is_empty():
		preview_profile=fixtures.source.campaign.duplicate(true)
		for stage in [1,2,3]:
			var watch:=C.fresh(Cat.definition(stage)); watch.phase="playing"
			for frame in 20000:
				if watch.phase!="playing": break
				var plan:=Policy.plan(watch)
				if plan.affordable and C.position(watch).distance_to(plan.goal)<1.4: C.action(watch,plan.pad,plan.choice)
				C.tick(watch,(plan.goal-C.position(watch)).limit_length(),1.0/60)
			C.finish(watch,preview_profile)
		check(preview_profile.clears.size()==4,"synthetic prior rule clears legitimately unlock the two-road geometry fixture")
	return S.decode(S.encode(battle,fixtures.source.profile,fixtures.source.settings,1,true,preview_profile))
func preview_open(context: Dictionary) -> RecoveryFault:
	var io:=fixture_io(context); await open_owner(io); await action("RESUME"); scene.sync_world(0); return io
func preview_clear() -> bool:
	return scene.build_preview_choice==-1 and not scene.build_preview_label.visible
func preview_cancel(choice: int,index: int=1) -> void:
	var outside:=Vector2(root.size.x-30,minf(300,root.size.y*.5))
	await drag_contact(outside,index,outside-scene.action_buttons[choice].get_global_rect().get_center()); await contact(outside,index,false); await process_frame
func preview_family_cases() -> void:
	for mirrored in [false,true]:
		for pad in [0,7]:
			for family in 3:
				print("PREVIEW FAMILY ",mirrored," / ",pad," / ",family)
				var context:=preview_fixture(mirrored,pad); check(context.ok,"synthetic rule-funded complete pinned geometry fixture validates")
				var io:=await preview_open(context); var before:=decoded_context(scene); var files: Dictionary=io.files.duplicate(true); var writes: int=io.writes
				await contact(scene.action_buttons[family].get_global_rect().get_center(),1,true); await process_frame
				var ring: MeshInstance3D=scene.presenter.range_ring; var center:=C.pad_point(scene.state.definition,pad); var radius: float=scene.state.definition.families[family].stats[0].range
				check(scene.build_preview_choice==family and ring.visible and is_equal_approx(ring.mesh.outer_radius*ring.scale.x,radius) and ring.position.is_equal_approx(Vector3(center.x,.1,center.y)),"all family/mirrored previews use the exact captured pad and pinned base range")
				check(not C.position(scene.state).is_equal_approx(center),"preview is anchored to pad geometry, not avatar location")
				var probe: Dictionary=scene.state.duplicate(true); probe.towers[pad].family=family; var inside:=0; var outside:=0
				for lane in 2:
					for sample in 35:
						var enemy:={"id":0,"z":-9.0+sample*.5,"hp":6.0,"lane":lane}; probe.enemies=[enemy]
						var covered: bool=C.point(probe.definition,enemy).distance_to(center)<=ring.mesh.outer_radius*ring.scale.x
						check(not C.targets(probe,pad).is_empty()==covered,"painted radius agrees with authoritative targeting along both actual roads")
						if covered: inside+=1
						else: outside+=1
				check(inside>0 and outside>0,"coverage samples include reachable and unreachable road positions")
				check(exact(decoded_context(scene),before) and io.files==files and io.writes==writes,"held family preview keeps complete progress/settings/parked context and all file bytes unchanged")
				await preview_cancel(family)
				check(preview_clear() and not ring.visible and exact(decoded_context(scene),before) and io.files==files and io.writes==writes,"actual drag-off cancels each preview without purchase/save")
func preview_purchase_cases() -> void:
	for family in 3:
		var io:=await preview_open(preview_fixture()); var before:=decoded_context(scene); var expected:=before.duplicate(true); var pad:=C.nearby(scene.state); var writes: int=io.writes
		check(C.action(expected.state,pad,family),"existing authoritative purchase expected result is legal")
		await action(scene.action_buttons[family].text); scene.sync_world(0)
		check(preview_clear() and exact(decoded_context(scene),expected) and io.writes==writes+1 and exact(S.read(S.PATH,io),expected),"ordinary quick tap makes exactly one unchanged complete purchase and save")
		var radius: float=expected.state.definition.families[family].stats[0].range; check(scene.presenter.range_ring.visible and is_equal_approx(scene.presenter.range_ring.mesh.outer_radius*scene.presenter.range_ring.scale.x,radius),"occupied tower range remains after prospective preview ends")
		var occupied:=decoded_context(scene); var files: Dictionary=io.files.duplicate(true); writes=io.writes
		await contact(scene.action_buttons[2].get_global_rect().get_center(),1,true); await process_frame
		check(preview_clear() and scene.presenter.range_ring.visible,"sell action never presents a new-build range or removes occupied coverage")
		await preview_cancel(2); check(exact(decoded_context(scene),occupied) and io.files==files and io.writes==writes,"canceling Sell preserves original tower and complete context")
	var empty:=S.decode(S.encode(C.fresh(Cat.definition(0)),R.profile(),{"sound":false,"reduced_effects":false},1,true,C.profile())); empty.state.phase="playing"
	empty.state.x=empty.state.definition.pads[2].x; empty.state.z=empty.state.definition.pads[2].z
	var poor:=await preview_open(empty); var untouched:=decoded_context(scene); var bytes: Dictionary=poor.files.duplicate(true); var count: int=poor.writes
	for family in 3:
		check(scene.action_buttons[family].disabled,"unaffordable choices remain disabled")
		await contact(scene.action_buttons[family].get_global_rect().get_center(),1,true); await contact(scene.action_buttons[family].get_global_rect().get_center(),1,false)
	check(preview_clear() and exact(decoded_context(scene),untouched) and poor.files==bytes and poor.writes==count,"disabled buttons cannot preview, buy or write")
func preview_context_cases() -> void:
	for kind in ["pad_return","pause_return","hide_return","disable_return","resize_return","world_replace","focus_return","terminal","recovery"]:
		print("PREVIEW CONTEXT ",kind)
		var io:=await preview_open(preview_fixture()); var before:=decoded_context(scene); var files: Dictionary=io.files.duplicate(true); var writes: int=io.writes
		await contact(scene.action_buttons[2].get_global_rect().get_center(),1,true); await process_frame
		check(scene.build_preview_choice==2,"actual contact begins context-safety preview")
		if kind=="pad_return":
			# Deterministic UI context fixture; actual movement is checked separately.
			var x: float=scene.state.x; var z: float=scene.state.z; scene.state.x=4.7; scene.state.z=6.7; await process_frame; scene.state.x=x; scene.state.z=z; await process_frame
		elif kind=="pause_return": await key(KEY_ESCAPE); await key(KEY_ESCAPE)
		elif kind=="hide_return": scene.ui.hide(); await process_frame; scene.ui.show(); await process_frame
		elif kind=="disable_return": scene.action_buttons[2].disabled=true; await process_frame; scene.action_buttons[2].disabled=false; await process_frame
		elif kind=="resize_return": root.size=Vector2i(450,1000); await process_frame; root.size=Vector2i(720,1280); await process_frame
		elif kind=="world_replace": scene.make_world(); await process_frame; await process_frame
		elif kind=="focus_return": scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT); await action("RESUME")
		elif kind=="terminal": scene.state.phase="defeat"; scene.refresh(); await process_frame; scene.state.phase="playing"; scene.refresh(); await process_frame
		elif kind=="recovery":
			io.mode="read1"; scene.begin_import(whole_code(before)); check(scene.recovery_pending,"real uncertain Import freezes held preview before ownership changes")
		check(preview_clear(),"context loss irreversibly clears preview "+kind)
		await contact(scene.action_buttons[2].get_global_rect().get_center(),1,false); await process_frame
		check(scene.state.ledger==before.state.ledger and scene.state.wallet==before.state.wallet and scene.state.spent==before.state.spent,"returning context and old release cannot revive a purchase "+kind)
		if kind=="recovery":
			reset_fault(io); await action("KEEP PREVIOUS WHOLE SAVE"); await action("RESUME")
		else:
			check(exact(decoded_context(scene),before),"all unrelated context fields remain exact after presentation invalidation "+kind)
			if kind not in ["pause_return","focus_return"]: check(io.files==files and io.writes==writes,"presentation invalidation adds no storage writes "+kind)
		await action(scene.action_buttons[2].text)
		check(scene.state.ledger.size()==before.state.ledger.size()+1,"fresh touch after invalidation makes one legal purchase "+kind)
func preview_contact_cases() -> void:
	var io:=await preview_open(preview_fixture()); var before:=decoded_context(scene)
	await contact(scene.action_buttons[0].get_global_rect().get_center(),1,true); await contact(scene.action_buttons[1].get_global_rect().get_center(),2,true); await process_frame
	preview_observations.append({"kind":"multi-action-held","preview_choice":scene.build_preview_choice,"latches":scene.action_latches.duplicate()})
	check(scene.build_preview_choice==1,"second actual action contact owns its family preview")
	await contact(scene.action_buttons[0].get_global_rect().get_center(),1,false); await process_frame
	check(scene.build_preview_choice==1 and scene.state.ledger==before.state.ledger,"releasing another action cannot clear or buy under the current preview")
	await contact(scene.action_buttons[1].get_global_rect().get_center(),2,false); await process_frame
	check(preview_clear() and scene.state.ledger.size()==before.state.ledger.size()+1 and scene.state.towers[C.nearby(scene.state)].family==1,"current action contact commits exactly its own preview family")
	io=await preview_open(preview_fixture()); before=decoded_context(scene); var files: Dictionary=io.files.duplicate(true); var writes: int=io.writes
	await contact(Vector2(120,970),0,true); await drag_contact(Vector2(150,970),0,Vector2(30,0)); var direction: Vector2=scene.input_vector
	await contact(scene.action_buttons[2].get_global_rect().get_center(),1,true)
	check(scene.build_preview_choice==2 and scene.presenter.range_ring.visible,"action preview appears while the other finger keeps the joystick held")
	await preview_cancel(2,1)
	check(scene.stick_id==0 and scene.input_vector==direction and direction.length()>0,"releasing action contact preserves the separate held joystick")
	check(exact(decoded_context(scene),before) and io.files==files and io.writes==writes,"multi-contact cancel has no battle or storage side effect")
	var expected:=before.duplicate(true); C.action(expected.state,C.nearby(scene.state),2)
	await contact(scene.action_buttons[2].get_global_rect().get_center(),1,true); await contact(scene.action_buttons[2].get_global_rect().get_center(),1,false)
	check(scene.stick_id==0 and scene.input_vector==direction and exact(decoded_context(scene),expected),"fresh action contact commits exactly once while preserving the separately held joystick")
	await contact(Vector2(150,970),0,false)
func preview_continuation_case() -> void:
	var io:=await preview_open(preview_fixture()); var before:=decoded_context(scene)
	await contact(scene.action_buttons[2].get_global_rect().get_center(),1,true); scene.set_physics_process(true)
	for frame in 135: await physics_frame
	await process_frame; scene.set_physics_process(false)
	var ticks:=roundi((scene.state.time-before.state.time)*60); var expected:=before.duplicate(true)
	for frame in ticks: C.tick(expected.state,Vector2.ZERO,1.0/60)
	check(ticks>=135 and exact(decoded_context(scene),expected),"holding preview preserves matched-timestep combat continuation and never pauses or changes rules")
	check(scene.build_preview_choice==2 and not scene.paused,"preview remains visible while normal encounter time advances")
	await preview_cancel(2)
	# Actual joystick leaves and returns while the build contact stays held.
	io=await preview_open(preview_fixture()); before=decoded_context(scene); await contact(scene.action_buttons[2].get_global_rect().get_center(),1,true); scene.set_physics_process(true)
	var origin:=C.position(scene.state); await move_to(origin+Vector2(3,0),300); check(preview_clear(),"actual joystick departure cancels held pad preview")
	await move_to(origin,300); scene.set_physics_process(false); await contact(scene.action_buttons[2].get_global_rect().get_center(),1,false)
	check(preview_clear() and scene.state.spent==before.state.spent and scene.state.ledger==before.state.ledger,"actual joystick return cannot revive the old held purchase")

func preview_boss_layout_cases() -> void:
	var watch:=C.fresh(Cat.definition(2)); watch.phase="playing"; var found:=false
	for frame in 20000:
		for enemy in watch.enemies:
			if watch.definition.roster[int(enemy.id)].role=="ram": found=true
		if found or watch.phase!="playing": break
		var plan:=Policy.plan(watch)
		if plan.affordable and C.position(watch).distance_to(plan.goal)<1.4: C.action(watch,plan.pad,plan.choice)
		C.tick(watch,(plan.goal-C.position(watch)).limit_length(),1.0/60)
	var pad:=0
	for index in watch.towers.size():
		if watch.towers[index].invested>watch.towers[pad].invested: pad=index
	var center:=C.pad_point(watch.definition,pad); watch.x=center.x+.2; watch.z=center.y+.2
	if watch.towers[pad].family>=0: C.action(watch,pad,2)
	var context:=S.decode(S.encode(watch,fixtures.source.profile,fixtures.source.settings,1,true,preview_profile))
	check(found and context.ok,"synthetic rule-played live boss context validates with legitimate paid pad release")
	if not context.ok: return
	for extent in [Vector2i(450,1000),Vector2i(720,1280),Vector2i(1000,900),Vector2i(900,450)]:
		root.size=extent; var io:=await preview_open(context); var before:=decoded_context(scene); var files: Dictionary=io.files.duplicate(true); var writes: int=io.writes; var warning: String=scene.guidance.text
		await contact(scene.action_buttons[0].get_global_rect().get_center(),1,true); await process_frame
		check(scene.build_preview_choice==0 and scene.guidance.text==warning and warning.contains("RAM:"),"prospective range retains the complete live boss warning "+str(extent))
		print("PREVIEW_LAYOUT ",extent," safe ",scene.safe_rect," guidance ",scene.guidance.get_global_rect()," preview ",scene.build_preview_label.get_global_rect()," action ",scene.action_buttons[0].get_global_rect())
		check(scene.safe_rect.encloses(scene.build_preview_label.get_global_rect()) and not scene.guidance.get_global_rect().intersects(scene.build_preview_label.get_global_rect()) and not scene.build_preview_label.get_global_rect().intersects(scene.action_buttons[0].get_global_rect()),"preview label stays inside safe layout and separates warning/actions "+str(extent))
		await preview_cancel(0)
		check(exact(decoded_context(scene),before) and io.files==files and io.writes==writes,"boss preview/cancel changes no authoritative context or file bytes "+str(extent))
	root.size=Vector2i(720,1280)
