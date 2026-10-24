extends "res://tests/import_uncertainty.gd"
const Facade = preload("res://scripts/engine.gd")
const T = preload("res://scripts/import_recovery.gd")
const Copies = preload("res://scripts/recovery_copies.gd")

class Faults extends Uncertain:
	var mode := ""
	var active_writes := 0
	var guarded := false
	var markerless_writes := 0
	var reads := 0
	var once_path := ""
	var once_reads := 0
	func read_text(path: String) -> String:
		if path==once_path:
			once_reads+=1
			if once_reads>1: return "one read window closed"
		if mode=="journal_stage_read" and path==T.PATH+".tmp": return "unreadable"
		if path==promoted and mode in ["active_verify","active_after_store"]:
			reads+=1
			if reads >= (1 if mode=="active_verify" else 2): return "unreadable"
		return super.read_text(path)
	func write_text(path: String,text: String) -> bool:
		if path.begins_with(S.PATH):
			active_writes+=1
			if guarded and not files.has(T.PATH) and not files.has(T.PATH+".tmp"): markerless_writes+=1
		if mode=="archive_write" and path.begins_with(Copies.PREFIX): return false
		files[path]=text
		return true
	func rename(from: String,to: String) -> bool:
		var phase := "active" if to.begins_with(S.PATH) else ("journal" if to==T.PATH else "archive")
		if mode==phase+"_rename": return false
		if mode==phase+"_missing": files.erase(from); files.erase(to); return true
		if mode==phase+"_corrupt": files[to]="torn"; files.erase(from); return true
		if mode=="active_stale" and phase=="active": files.erase(from); return true
		files[to]=files[from]
		if not (mode=="clear_partial" and phase=="journal"): files.erase(from)
		if phase=="active": promoted=to; reads=0
		return true
	func remove(path: String) -> bool:
		if mode=="clear_failure" or mode=="clear_partial" and path.ends_with(".tmp"): return false
		if mode=="clear_lie": return true
		files.erase(path); return true

class Owner extends "res://scripts/main.gd":
	var fail_scene := false
	func _change_import_scene() -> Error:
		return ERR_CANT_OPEN if fail_scene else super._change_import_scene()

func full_contexts() -> Array:
	var list := contexts()
	var campaign: Dictionary=list[1]
	var enemy: Dictionary=campaign.state.enemies[0]
	C._projectile(campaign.state,enemy,campaign.state.definition.roster[int(enemy.id)],0)
	var dock := {"name":"legacy_dock", "state":R.fresh(),"profile":C.profile(),"settings":{"sound":false,"reduced_effects":false}}
	var loss: Dictionary=dock.duplicate(true)
	loss.name="legacy_defeat"; loss.state.hp=0.0; loss.state.phase="defeat"
	var win: Dictionary=dock.duplicate(true)
	win.name="legacy_victory"; win.state.phase="victory"; win.state.tier=1; win.state.wallet=-R.COST; win.state.enemies.clear()
	for i in R.ROSTER.size():
		win.state.dead.append(i); win.state.collected.append(i); win.state.wallet+=int(R.ROSTER[i].reward)
	C.record(win.profile,win.state)
	var campaign_loss: Dictionary=campaign.duplicate(true)
	campaign_loss.name="campaign_defeat"; campaign_loss.state.hp=0.0; campaign_loss.state.phase="defeat"
	var campaign_win: Dictionary=campaign.duplicate(true)
	campaign_win.name="campaign_victory"; campaign_win.state=completed(9); C.record(campaign_win.profile,campaign_win.state)
	var arena_win: Dictionary=list[2].duplicate(true)
	arena_win.name="arena_victory"; arena_win.state=completed(11,true); C.record(arena_win.profile,arena_win.state)
	list.append_array([dock,loss,win,campaign_loss,campaign_win,arena_win])
	return list

func fresh_io(context: Dictionary) -> Faults:
	var io := Faults.new(); io.mode="seed"
	io.files[S.PATH+"0"] = S.encode(context.state,context.settings,5,true,context.profile)
	io.files[S.PATH+"1"] = S.encode(context.state,context.settings,7,true,context.profile)
	io.files[S.PATH+"0.tmp"] = " "+S.encode(context.state,context.settings,50,false,context.profile)+" \n"
	io.files[S.PATH+"1.tmp"] = S.encode(context.state,context.settings,6,true,context.profile)
	io.mode=""; io.promoted=""
	return io

func open_owner(io: RefCounted, blocked_handoff: bool=false, pause_menu: bool=true) -> void:
	if is_instance_valid(scene): scene.free()
	scene=Owner.new(); scene.save_io=io; scene.fail_scene=blocked_handoff
	root.add_child(scene); current_scene=scene; scene.set_physics_process(false)
	await process_frame
	if not scene.paused and pause_menu: await click("PAUSE")

func tap(label: String) -> void:
	if label=="IMPORT" and scene.save_io is Faults:
		scene.save_io.promoted=""
		scene.save_io.guarded=true
	var button: Button
	for candidate in scene.find_children("*","Button",true,false):
		if candidate.text==label and candidate.is_visible_in_tree(): button=candidate; break
	check(button!=null and not button.disabled,"reachable actual touch choice "+label)
	if button==null or button.disabled: return
	var scroller: ScrollContainer
	var parent: Node=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer: scroller=parent; break
		parent=parent.get_parent()
	if scroller!=null:
		for attempt in 30:
			if scroller.get_global_rect().encloses(button.get_global_rect()): break
			var wheel := InputEventMouseButton.new()
			wheel.position=root.get_final_transform()*scroller.get_global_rect().get_center()
			wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if button.get_global_rect().get_center().y>scroller.get_global_rect().get_center().y else MOUSE_BUTTON_WHEEL_UP
			wheel.pressed=true; Input.parse_input_event(wheel.duplicate()); await process_frame
			wheel.pressed=false; Input.parse_input_event(wheel.duplicate()); await process_frame
	check(scroller==null or scroller.get_global_rect().encloses(button.get_global_rect()),"choice fully inside reachable scroll area "+label)
	await touch_point(button.get_global_rect().get_center(),label)
	if current_scene == null: await scene_changed
	if is_instance_valid(current_scene) and current_scene!=scene: scene=current_scene

func touch_point(point: Vector2,label: String) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new(); event.index=0; event.position=root.get_final_transform()*point; event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
		events.append({"target":label,"pressed":pressed,"position":[event.position.x,event.position.y]})
		await process_frame

func freeze_checks(io: Faults,before: Dictionary,label: String) -> void:
	var writes: int=io.active_writes
	for point in [Vector2(600,80),Vector2(180,1150),Vector2(100,500)]: await touch_point(point,"covered control")
	var key := InputEventKey.new(); key.physical_keycode=KEY_W; key.pressed=true; Input.parse_input_event(key)
	scene.set_physics_process(true)
	for frame in 6: await physics_frame
	scene.set_physics_process(false)
	key.pressed=false; Input.parse_input_event(key)
	scene._toggle_menu(); scene._continue(); scene._retry(); scene._buy(); scene._cycle_seed(); scene._cycle_weapon(); scene._arena()
	scene._setting(not scene.settings.sound,"sound"); scene._setting(not scene.settings.reduced_effects,"reduced_effects")
	scene._transfer("IMPORT"); scene._save(); scene._sync(); scene._physics_process(3.0)
	scene.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT); scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(scene.import_pending and scene.paused and whole()==before,"pending preserves every live field through actual touches/keys and all handlers: "+label)
	check(io.active_writes==writes,"pending blocks autosave, terminalSync, direct saves and lifecycle writes: "+label)

func run() -> void:
	if "--marker-retry" in OS.get_cmdline_user_args():
		await run_marker_retry(); return
	root.size=Vector2i(720,1280)
	var list := full_contexts()
	for context in list: check(S.decode(code(context)).ok,"complete synthetic fixture validates "+context.name)
	for index in list.size():
		var original: Dictionary=list[index]
		var incoming: Dictionary=list[(index+4)%list.size()]
		for use_import in [true,false]:
			var io := fresh_io(original)
			await open_owner(io)
			scene.settings["extra"]="unsaved live settings"; scene.profile.arena_seed=1719
			var previous := whole()
			var previous_code := S.encode(scene.state,scene.settings,0,true,scene.profile)
			var incoming_code: String=" \n"+code(incoming)+" \n"
			var raw_codes: Array=io.files.values().duplicate()
			io.mode="active_verify"
			scene.transfer.text=incoming_code
			await tap("IMPORT")
			var label: String=original.name+" to "+incoming.name+" choose "+str(use_import)
			check(scene.import_pending and whole()==previous,"postrename read failure preserves exact live state/profile/settings "+label)
			for raw in raw_codes+[previous_code,incoming_code]:
				check(io.files.get(Copies.PREFIX+str(raw).sha256_text())==raw,"opaque complete code archived byte-exact "+label)
			await freeze_checks(io,previous,label)
			io.mode=""; io.promoted=""
			materialize(io)
			await reload_disk(S.decode(previous_code),"pending bootstrap original "+label)
			check(scene.import_pending and scene.paused,"cold journal bootstrap remains pending "+label)
			# Reopen the fake storage owner so the chosen write/cleanup remain fault-observable.
			await open_owner(io)
			await tap("RETRY IMPORT" if use_import else "KEEP PREVIOUS")
			var expected := S.decode(incoming_code if use_import else previous_code)
			check(not scene.import_pending and scene.paused and matches(whole(),expected),"fresh owner adopts exact chosen whole context paused "+label)
			check(not io.files.has(T.PATH) and not io.files.has(T.PATH+".tmp") and io.markerless_writes==0,"verified choice clears both journal artifacts after guarded writes "+label)
			check(matches(S.read(S.PATH,io),expected),"verified rotating-slot choice equals complete chosen context "+label)
			materialize(io)
			await reload_disk(expected,"resolved normal decoder "+label)
	# Loading terminal saves is not another victory event; real Continue/Retry
	# still applies the existing rules through its visible input action.
	for index in [4,5,6,7,8]:
		var terminal: Dictionary=list[index]
		var terminal_io := fresh_io(terminal)
		await open_owner(terminal_io,false,false)
		var decoded := S.decode(code(terminal))
		check(matches(whole(),decoded) and terminal_io.active_writes==0,"terminal bootstrap is exact without re-record/write "+terminal.name)
		var expected := whole()
		if scene.state.phase=="defeat":
			check(Facade.retry(expected.state),"existing retry fixture applies")
			await tap("RETRY")
		else:
			C.record(expected.profile,expected.state)
			if expected.state.schema==2 and expected.state.definition.arena:
				expected.state=expected.profile.ending.duplicate(true); expected.profile.ending={}
			else:
				expected.profile.stage+=1
				expected.state=C.fresh(expected.profile.stage,expected.state.tier,expected.state.wallet)
			await tap(scene.continue_button.text)
		check(whole()==expected,"actual terminal action preserves existing Continue/Retry behavior "+terminal.name)
	for extent in [Vector2i(450,850),Vector2i(900,600)]:
		root.size=extent
		var narrow_io := fresh_io(list[1]); await open_owner(narrow_io)
		narrow_io.mode="active_verify"; scene.transfer.text=code(list[0]); await tap("IMPORT")
		var panel_pixels: Rect2=root.get_final_transform()*scene.recovery_panel.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(extent)).encloses(panel_pixels),"recovery panel stays within physical viewport "+str(extent))
		observations.append({"case":"narrow bounds","physical_extent":extent,"canvas_extent":root.get_visible_rect().size,"panel_pixels":panel_pixels})
		narrow_io.mode=""; narrow_io.promoted=""
		await tap("KEEP PREVIOUS")
		check(not scene.import_pending and matches(whole(),S.decode(code(list[1]))),"narrow/short recovery choice reachable "+str(extent))
	root.size=Vector2i(720,1280)
	var fault_modes := ["archive_write","archive_rename","archive_missing","archive_corrupt","journal_stage_read","journal_rename","journal_missing","journal_corrupt","active_rename","active_missing","active_corrupt","active_stale","active_after_store","clear_failure","clear_lie","clear_partial"]
	for mode in fault_modes:
		var original: Dictionary=list[1]; var incoming: Dictionary=list[2]
		var io := fresh_io(original); await open_owner(io)
		var before := whole(); var incoming_code := code(incoming)
		io.mode=mode; scene.transfer.text=incoming_code; await tap("IMPORT")
		check(whole()==before,"failed boundary retains complete live context "+mode)
		if mode.begins_with("archive"):
			check(io.active_writes==0 and not scene.import_pending,"archive failure precedes journal/active admission "+mode)
		else:
			check(scene.import_pending and scene.paused,"uncertain boundary remains pending "+mode)
			await freeze_checks(io,before,mode)
			io.mode=""; io.promoted=""
			await tap("KEEP PREVIOUS")
			if mode=="journal_corrupt":
				check(scene.import_pending and scene.paused and whole()==before,"persistently torn marker stays blocked without destructive repair")
			else:
				check(not scene.import_pending and scene.paused and whole()==before,"retry previous resolves exact full context "+mode)
		check(io.markerless_writes==0,"all active writes had durable journal admission "+mode)
	# A failed scene handoff cannot reuse the cleanup-cleared admission on retry.
	var io := fresh_io(list[2]); await open_owner(io,true)
	scene.transfer.text=code(list[0]); await tap("IMPORT")
	check(scene.import_pending and scene.paused and not io.files.has(T.PATH),"failed fresh-owner handoff stays frozen after confirmed cleanup")
	await tap("KEEP PREVIOUS")
	check(io.markerless_writes==0 and scene.import_pending,"retained owner reestablishes journal before another write")
	# One-read windows prove bootstrap binds one journal/archive decision.
	for kind in ["journal","original","incoming"]:
		var pending_io := fresh_io(list[1]); var tx := T.new(pending_io)
		check(tx.begin(code(list[1]),code(list[2])).ok,"one-read journal seeded")
		pending_io.once_path=T.PATH if kind=="journal" else Copies.PREFIX+(code(list[1]) if kind=="original" else code(list[2])).sha256_text()
		await open_owner(pending_io)
		check(scene.import_pending and matches(whole(),S.decode(code(list[1]))) and pending_io.once_reads==1,"single validated bootstrap decision for "+kind)
	# Corrupt markers and unreadable active files never run/save a default game.
	for kind in ["bad_marker_with_save","bad_marker_no_save","unreadable_active"]:
		var blocked_io := Faults.new()
		if kind!="unreadable_active": blocked_io.files[T.PATH]="damaged recovery marker"
		if kind=="bad_marker_with_save": blocked_io.files[S.PATH+"0"]=code(list[1])
		if kind=="unreadable_active": blocked_io.files[S.PATH+"0"]="unreadable existing save"
		await open_owner(blocked_io)
		check(scene.import_pending and scene.paused and blocked_io.active_writes==0,"unknown bootstrap blocks local writes "+kind)
		if kind!="bad_marker_with_save": check(not is_instance_valid(scene.presentation),"no default gameplay built without safe context "+kind)
		blocked_io.files.clear(); blocked_io.files[S.PATH+"0"]=code(list[1])
		await tap("RETRY RECOVERY READ")
		check(not scene.import_pending and scene.paused and matches(whole(),S.decode(code(list[1]))),"explicit read retry recovers complete local context "+kind)
	if is_instance_valid(scene): scene.free()
	await process_frame
	FileAccess.open(capture_dir.path_join("import-recovery.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"observations":observations,"scope":"CPU/headless/Dummy. Synthetic complete legacy/campaign/arena and terminal contexts, opaque saved-code copies, injected storage faults, actual touch/keyboard controls and materialized-file reload. Not OS kill, Android, physical fault, render or cloud verification."},"  "))
	print("IMPORT_RECOVERY ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)

func reload_disk(expected: Dictionary,label: String) -> void:
	await super.reload_disk(expected,label)
	if not matches(whole(),expected): observations.append({"case":label,"expected":expected,"actual":whole()})

class RetryFault extends Faults:
	var blocked: Array[String] = []
	var marker_failure := ""
	func read_text(file: String) -> String:
		return "unreadable" if file in blocked else super.read_text(file)
	func rename(from: String,to: String) -> bool:
		var okay:=super.rename(from,to)
		if to==T.PATH:
			if marker_failure=="missing": files.erase(to)
			elif marker_failure=="corrupt": files[to]="torn"
		return okay
func marker_code(context: Dictionary,tag: String) -> String:
	var full: Dictionary=context.duplicate(true); full.settings.extra=tag
	return code(full)
func marker_set(io: RetryFault) -> Dictionary:
	var result: Dictionary={}
	for path in [T.PATH,T.PATH+".tmp"]:
		if io.files.has(path): result[path]=io.files[path]
	return result
func run_marker_retry() -> void:
	root.size=Vector2i(720,1280)
	var list:=full_contexts()
	# Real Import/Retry/Keep, fresh owning controllers and materialized production reload.
	for original_index in [1,2]:
		for use_import in [false,true]:
			var original: Dictionary=list[original_index]; var incoming: Dictionary=list[0]
			var io:=RetryFault.new(); io.files=fresh_io(original).files.duplicate(true)
			await open_owner(io); scene.settings.extra="unsaved whole live setting"
			var before:=whole(); var live_code:=S.encode(scene.state,scene.settings,0,true,scene.profile)
			var target: String=" \n"+code(incoming)+" \n"; var raw: Array=io.files.values().duplicate()
			io.mode="clear_partial" if use_import else "clear_failure"; scene.transfer.text=target; await tap("IMPORT")
			check(scene.import_pending and scene.paused and whole()==before,"actual Import retains entire original through unconfirmed cleanup")
			for text in raw+[live_code,target]: check(io.files.get(Copies.PREFIX+str(text).sha256_text())==text,"actual Import preserves every opaque raw/live/incoming code exactly")
			io.mode=""; io.promoted=""; io.marker_failure="missing" if use_import else "corrupt"
			await tap("RETRY IMPORT" if use_import else "KEEP PREVIOUS")
			var expected: Dictionary=S.decode(target if use_import else live_code)
			check(not scene.import_pending and scene.paused and matches(whole(),expected) and matches(S.read(S.PATH,io),expected),"actual Retry/Keep verifies complete immediate live/disk context and paused adoption")
			materialize(io); await reload_disk(expected,"marker retry actual production reload")
			check(not scene.import_pending and scene.paused and matches(whole(),expected),"fresh materialized production owner retains complete chosen context")
			observations.append({"case":"actual marker retry","original":original.name,"use_import":use_import,"whole_equal":matches(whole(),expected),"projectiles":original.state.get("projectiles",[]).size(),"parked_finale":not original.profile.ending.is_empty(),"scope":"synthetic complete records, actual ScreenTouch and fresh production owner from real files; not OS kill/native"})
	# Typed admission matrix is separate from the actual production-input cases above.
	var source:=marker_code(list[2],"unsaved arena with parked finale"); var target:=marker_code(list[1],"campaign projectile")
	check(S.decode(source).ok and S.decode(target).ok and not S.decode(target).state.projectiles.is_empty() and not S.decode(source).profile.ending.is_empty(),"owning decoder accepts complete parked-finale and projectile-bearing contexts")
	for stage in [false,true]:
		for use_import in [false,true]:
			var io:=RetryFault.new(); io.files=fresh_io(list[2]).files.duplicate(true); var helper:=T.new(io); var raw: Array=io.files.values().duplicate()
			check(helper.begin(source,target).ok and helper.record.copies.size()==6,"six distinct complete raw/live/incoming codes archived before active mutation")
			if stage: io.files[T.PATH+".tmp"]=io.files[T.PATH]
			io.mode="clear_partial" if stage else "clear_failure"
			check(not helper.resolve(true).ok and matches(S.read(S.PATH,io),S.decode(target)),"verified incoming write stays pending after failed or partial cleanup")
			io.mode=""; io.promoted=""; io.marker_failure="missing"
			check(helper.resolve(use_import).ok and matches(S.read(S.PATH,io),S.decode(target if use_import else source)),"sole matching base/stage permits either verified whole choice without promotion")
			for text in raw+[source,target]: check(helper.copies.get_code(str(text).sha256_text()).get("text")==text,"all complete opaque codes remain exact after explicit choice")
			check(not helper.journal_ready and marker_set(io).is_empty(),"confirmed clear invalidates retained helper readiness")
			io.marker_failure=""; io.mode="active_verify"
			check(not helper.resolve(not use_import).ok and not marker_set(io).is_empty(),"retained helper establishes new marker before uncertain later write")
	for location in ["base","stage","both"]:
		for fault in ["unreadable","invalid","conflict"]:
			var io:=RetryFault.new(); io.files=fresh_io(list[2]).files.duplicate(true); var helper:=T.new(io); helper.begin(source,target)
			if location=="stage": io.files[T.PATH+".tmp"]=io.files[T.PATH]; io.files.erase(T.PATH)
			elif location=="both": io.files[T.PATH+".tmp"]=io.files[T.PATH]
			var path: String=T.PATH+".tmp" if location in ["stage","both"] else T.PATH
			if fault=="unreadable": io.blocked.append(path)
			elif fault=="invalid": io.files[path]="torn"
			else:
				var other:=T.new(RetryFault.new()); other.begin(marker_code(list[0],"other original"),marker_code(list[1],"other incoming")); io.files[path]=other.io.files[T.PATH]
			var prior: Dictionary=io.files.duplicate(true); var writes:=io.active_writes
			check(not helper.resolve(false).ok and io.files==prior and io.active_writes==writes,"all existing artifacts must fully agree before write: "+location+" / "+fault)
	for intended_first in [false,true]:
		var io:=RetryFault.new(); io.files=fresh_io(list[2]).files.duplicate(true); var helper:=T.new(io); helper.begin(source,target); var intended: String=io.files[T.PATH]
		var other:=T.new(RetryFault.new()); other.begin(marker_code(list[0],"other"),marker_code(list[1],"other incoming"))
		for path in other.io.files:
			if path.begins_with(Copies.PREFIX): io.files[path]=other.io.files[path]
		io.files[T.PATH]=intended if intended_first else other.io.files[T.PATH]; io.files[T.PATH+".tmp"]=other.io.files[T.PATH] if intended_first else intended; io.mode="clear_partial"
		var prior: Dictionary=io.files.duplicate(true); var writes:=io.active_writes
		check(not helper.resolve(true).ok and io.files==prior and io.active_writes==writes,"reverse conflicting records cannot expose a different transaction through partial cleanup")
	for post_store in [false,true]:
		for changed in ["invalid","unreadable","missing","conflict"]:
			var io:=RetryFault.new(); io.files=fresh_io(list[2]).files.duplicate(true); var helper:=T.new(io); helper.begin(source,target); io.mode="active_after_store" if post_store else "active_verify"
			check(not helper.resolve(true).ok,"owning-Store or later readback uncertainty keeps recovery pending")
			io.mode=""; io.promoted=""
			if changed=="invalid": io.files[T.PATH]="torn"
			elif changed=="unreadable": io.blocked.append(T.PATH)
			elif changed=="missing": io.files.erase(T.PATH); io.marker_failure="missing"
			else:
				var other:=T.new(RetryFault.new()); other.begin(marker_code(list[0],"other"),marker_code(list[1],"other incoming")); io.files[T.PATH]=other.io.files[T.PATH]
			var prior: Dictionary=io.files.duplicate(true); var writes:=io.active_writes
			check(not helper.resolve(false).ok and io.files==prior and io.active_writes==writes,"same owner refreshes admission after write uncertainty: "+changed)
	var io:=RetryFault.new(); var helper:=T.new(io); helper.begin(source,target); io.files[T.PATH]="torn"
	check(not helper.read().ok and not helper.journal_ready,"failed read cannot retain stale durable readiness")
	var stale_io:=RetryFault.new(); stale_io.files=fresh_io(list[2]).files.duplicate(true); var stale:=T.new(stale_io); stale.begin(source,target)
	var changed_record: Dictionary=stale.record.duplicate(true); changed_record.copies=[changed_record.original,changed_record.incoming]
	var stale_payload:=JSON.stringify(changed_record); stale_io.files[T.PATH]=JSON.stringify({"payload":stale_payload,"sha256":stale_payload.sha256_text()}); var stale_prior: Dictionary=stale_io.files.duplicate(true)
	check(T.decode(stale_io.files[T.PATH]).ok and not stale.resolve(true).ok and stale_io.files==stale_prior,"same original/incoming with stale whole archive list cannot admit active write")
	for copy_kind in ["original","incoming","raw_ending","raw_projectile"]:
		var broken_io:=RetryFault.new(); broken_io.files=fresh_io(list[2]).files.duplicate(true)
		var projectile_raw: String=S.encode(list[1].state,list[1].settings,5,true,list[1].profile); broken_io.files[S.PATH+"0"]=projectile_raw
		var ending_raw: String=broken_io.files[S.PATH+"1"]; var broken:=T.new(broken_io); broken.begin(source,target)
		var raw: String=projectile_raw if copy_kind=="raw_projectile" else ending_raw
		if copy_kind.begins_with("raw_"):
			var decoded:=S.decode(raw)
			check(decoded.ok and (not decoded.state.projectiles.is_empty() if copy_kind=="raw_projectile" else not decoded.profile.ending.is_empty()),"opaque raw fixture contains its real projectile/parked-ending fields")
		var id: String=broken.record.original if copy_kind=="original" else (broken.record.incoming if copy_kind=="incoming" else raw.sha256_text()); broken_io.files[Copies.PREFIX+id]="torn"
		var prior: Dictionary=broken_io.files.duplicate(true); var writes:=broken_io.active_writes
		check(not broken.resolve(true).ok and broken_io.files==prior and broken_io.active_writes==writes,"every whole archive reverified before active write: "+copy_kind)
	if is_instance_valid(scene): scene.free()
	await process_frame
	FileAccess.open(capture_dir.path_join("marker-retry.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"observations":observations,"scope":"CPU/headless/Dummy, synthetic complete projectile/profile.ending/settings contexts; actual touch, typed faults and materialized production owner reload; not OS kill/native/render/cloud proof."},"  "))
	print("MARKER_RETRY ",checks," failures=",failures); print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
