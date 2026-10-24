extends SceneTree
## Synthetic complete records + typed storage faults; actual GUI import buttons.
const Store = preload("res://scripts/save_store.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const Profile = preload("res://scripts/campaign_profile.gd")
const Fault = preload("res://tests/fault_files.gd")
var folder := ""
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var events: Array[Dictionary] = []
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report-dir="): folder=a.trim_prefix("--report-dir=")
	root.size=Vector2i(600,1066); call_deferred("run")
func check(okay: bool,label: String) -> void:
	checks+=1
	if not okay: failures.append(label); print("FAIL ",label)
func fixture(kind: int,revision: int=7) -> String:
	var state:=Battle.initial(1701,"tutorial" if kind==0 else "camp_01")
	var profile:=Profile.fresh(); profile.cleared=["camp_01"]; profile.medals={"camp_01":2}; profile.best={"camp_01":{"seconds":38.5,"wall":200,"spent":12,"produced":7,"losses":1,"cap_seconds":0.25}}; profile.medals.camp_01=1+kind; profile.best.camp_01.seconds=38.5+kind; profile.ending_seen=kind==2; profile.challenge_clears={"camp_05:1729":1+kind}
	if kind==2: Battle.start(state); Battle.tick(state,Battle.STEP)
	return Store.encode(state,{"muted":kind%2==0,"reduced_effects":kind%2!=0},revision,true,profile)
func same(a: Dictionary,b: Dictionary) -> bool:
	return a.get("ok")==true and b.get("ok")==true and a.state==b.state and a.settings==b.settings and a.profile==b.profile
func live(game: Node) -> Dictionary:
	return Store.decode(Store.encode(game.state,game.settings,0,true,game.profile))
func ticks(count: int=2) -> void:
	for i in count: await process_frame
func tap(point: Vector2,label: String) -> void:
	for pressed in [true,false]:
		var e:=InputEventScreenTouch.new(); e.index=0; e.position=root.get_final_transform()*point; e.pressed=pressed
		Input.parse_input_event(e); Input.flush_buffered_events(); events.append({"label":label,"pressed":pressed}); await ticks(1)
func dialog_button(game: Node,title: String) -> void:
	for b in game.save_dialog.find_children("*","Button",true,false):
		if b.text==title and b.is_visible_in_tree() and not b.disabled:
			game.dialog_scrolls[game.save_dialog].ensure_control_visible(b); await ticks()
			await tap(Vector2(game.save_dialog.position)+b.get_global_rect().get_center(),title); return
	check(false,"visible GUI button "+title)
func boot(io: RefCounted) -> Node:
	var game: Node=load("res://main.tscn").instantiate(); game.save_backend=io; root.add_child(game); current_scene=game; await ticks(); return game
func run() -> void:
	check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"all physical data stays isolated")
	if not failures.is_empty(): quit(1); return
	var old:=fixture(0); var incoming:=fixture(2,8)
	check(Store.decode(old).ok and Store.decode(incoming).ok,"synthetic records validate through owning Store")
	for source_suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		for target_suffix in [".bak", "fault-save.json"]:
			for mode in ["missing","corrupt","stale"]:
				var io:=Fault.new(); var path: String="user://fault-save.json"; io.files[path+source_suffix]=old
				io.bad_destination_suffix=target_suffix; io.bad_destination_mode=mode; io.stale_destination=fixture(1,2)
				# When the newest source already IS final backup, no backup promotion occurs.
				if source_suffix==".bak" and target_suffix==".bak": continue
				var decoded:=Store.decode(incoming); var result:=Store.write(decoded.state,decoded.settings,path,io,false,decoded.profile); var recovered:=Store.read(path,io)
				observations.append({"kind":"store_destination","source":source_suffix,"target":target_suffix,"mode":mode,"returned":result,"cold_original":same(recovered,Store.decode(old))})
				check(not result,"false-success rejected "+source_suffix+" / "+target_suffix+" / "+mode)
				check(same(recovered,Store.decode(old)),"newest prior whole context remains readable "+source_suffix+" / "+target_suffix+" / "+mode)
	for mode in ["missing","corrupt","stale"]:
		var io:=Fault.new(); io.files[Store.PATH]=old
		var game:=await boot(io)
		await tap(game.get_global_transform_with_canvas()*game.buttons().save.get_center(),"Save")
		check(game.save_dialog.visible,"actual map Save opens import dialog")
		game.save_text.text=incoming # Explicit synthetic code entry; Import is real GUI input.
		io.bad_destination_suffix="bastion-save.json"; io.bad_destination_mode=mode; io.stale_destination=fixture(1,2)
		await dialog_button(game,"Import"); await ticks()
		var disk:=Store.read(Store.PATH,io)
		observations.append({"kind":"actual_import","mode":mode,"message":game.message,"dialog_title":game.save_dialog.title,"live_incoming":same(live(game),Store.decode(incoming)),"cold_incoming":same(disk,Store.decode(incoming))})
		check(same(live(game),Store.decode(old)),"actual Import never adopts unverified destination "+mode)
		check(not game.message.begins_with("Imported"),"actual Import never claims unverified success "+mode)
		check(not (game.save_dialog.title.contains("current game retained") and not same(disk,Store.decode(old))),"retained claim agrees with cold whole context "+mode)
		game.queue_free(); await ticks()

	for original_kind in [0,1,2]:
		var source:=fixture(original_kind); var io:=Fault.new(); io.files[Store.PATH]=source
		var game:=await boot(io)
		await tap(game.get_global_transform_with_canvas()*game.buttons().save.get_center(),"Save transient")
		game.save_text.text=incoming; io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
		await dialog_button(game,"Import"); await ticks()
		var prior_live:=same(live(game),Store.decode(source)); var claim: String=game.save_dialog.title
		io.unreadable_after=0; var cold:=Store.read(Store.PATH,io)
		observations.append({"kind":"transient_post_commit","original_kind":original_kind,"old_live":prior_live,"claim":claim,"cold_incoming":same(cold,Store.decode(incoming))})
		check(not (prior_live and same(cold,Store.decode(incoming)) and claim.contains("current game retained")),"post-commit uncertainty never claims whole current retained while cold chooses imported "+str(original_kind))
		check(game.recovery_pending and game.paused and prior_live,"observed uncertain write retains whole live context under pending gate")
		game.queue_free(); await ticks()
		var fresh:=await boot(io)
		check(fresh.recovery_pending and fresh.paused and same(live(fresh),Store.decode(source)),"fresh bootstrap honors journal original even with a higher imported primary")
		fresh.queue_free(); await ticks()
	var output:={"checks":checks,"failures":failures,"observations":observations,"events":events,"limits":"Synthetic decoder-valid records, typed fault backend, actual ScreenTouch. Not native/power-loss or rendered acceptance."}
	var f:=FileAccess.open(folder.path_join("save-recovery.json"),FileAccess.WRITE); f.store_string(JSON.stringify(output)); f.close()
	print("GEAR_RECOVERY ",checks," / ",failures.size()," failures / ",events.size()," touch events"); quit(0 if failures.is_empty() else 1)
