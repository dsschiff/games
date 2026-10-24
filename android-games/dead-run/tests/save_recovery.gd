extends SceneTree
## Synthetic decoder-valid whole contexts; real ScreenTouch Import and fresh owners.
const Store=preload("res://scripts/campaign_store.gd")
const Old=preload("res://scripts/save_store.gd")
const C=preload("res://scripts/campaign_rules.gd")
const R=preload("res://scripts/rules.gd")
const Fault=preload("res://tests/fault_files.gd")
var folder:=""
var checks:=0
var failures: Array[String]=[]
var events: Array[Dictionary]=[]
var observations: Array[Dictionary]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): folder=arg.trim_prefix("--report-dir=")
	root.size=Vector2i(720,1280); call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func fixture(kind: int,revision: int=10) -> String:
	var ctx:=Store.fresh(); ctx.settings={"sound":kind%2==0,"reduced_effects":kind%2!=0}; ctx.loadout="lance" if kind==1 else "fan"
	for id in 24:
		ctx.profile.clears.append(id); ctx.profile.medals[str(id)]={"rescues":id%2==0,"no_loss":id%3==0,"best_crew":12+kind}
	ctx.profile.ending=true; ctx.profile.replays=[{"seed":71723+kind,"crew":8+kind,"weapon":ctx.loadout}]
	ctx.legacy.phase="playing"
	for tick in 31+kind: R.step(ctx.legacy)
	ctx.campaign=C.fresh(5+kind,ctx.loadout)
	if kind>0:
		ctx.campaign.phase="playing"
		for tick in int(ctx.campaign.definition.weapons[ctx.loadout].period)+kind+1: C.step(ctx.campaign)
	ctx.mode="legacy" if kind==2 else "campaign"
	return Store.encode(ctx,revision)
func same(a: Dictionary,b: Dictionary) -> bool:
	return a.get("ok")==true and b.get("ok")==true and a.context==b.context
func live(game: Node) -> Dictionary:
	var ctx: Dictionary=game.ctx.duplicate(true); ctx.campaign=game.state.duplicate(true)
	if is_instance_valid(game.legacy_view): ctx.legacy=game.legacy_view.state.duplicate(true); ctx.settings=game.legacy_view.settings.duplicate(true)
	else: ctx.settings=game.settings.duplicate(true)
	return Store.decode(Store.encode(ctx,0))
func ui(game: Node) -> Node: return game if game.recovery_pending else (game.legacy_view if is_instance_valid(game.legacy_view) else game)
func ticks(count: int=2) -> void:
	for tick in count: await process_frame
func tap(point: Vector2,label: String) -> void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new(); event.index=0; event.position=root.get_final_transform()*point; event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); events.append({"label":label,"pressed":pressed}); await ticks(1)
func click(game: Node,title: String) -> void:
	for child in ui(game).hud.find_children("*","Button",true,false):
		if child.text==title and child.is_visible_in_tree() and not child.disabled:
			var parent: Node=child.get_parent()
			while parent!=null and not parent is ScrollContainer: parent=parent.get_parent()
			if parent is ScrollContainer: parent.ensure_control_visible(child); await ticks()
			await tap(child.get_global_rect().get_center(),title); return
	check(false,"visible actual button "+title)
func boot(io: RefCounted) -> Node:
	var game: Node=load("res://campaign.tscn").instantiate(); game.files=io; root.add_child(game); current_scene=game
	game.set_physics_process(false)
	if is_instance_valid(game.legacy_view): game.legacy_view.set_physics_process(false)
	await ticks(); return game
func run() -> void:
	check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"isolated app data only")
	if not failures.is_empty(): quit(1); return
	for kind in [0,1,2]:
		var source:=fixture(kind); var target:=fixture(1 if kind!=1 else 2,99)
		check(Store.decode(source).ok and Store.decode(target).ok,"owning decoder accepts complete synthetic contexts")
		var io:=Fault.new(); io.files[Store.PATH+"0"]=source
		var game:=await boot(io); await click(game,"SAVE / TRANSFER"); var before:=live(game)
		check(not before.context.legacy.bullets.is_empty() and (kind==0 or not before.context.campaign.bullets.is_empty()),"baseline fixtures retain real rule-emitted legacy and active campaign bullets")
		ui(game).code_box.text=target; io.unreadable_after=1
		await click(game,"IMPORT"); var claim: String=game.recovery.message if game.recovery_pending else ui(game).transfer_status.text
		check(game.recovery_pending and game.paused and same(live(game),before),"unconfirmed import retains exact whole live context under pending ownership")
		io.unreadable_after=0; var cold_record:=Store.read(Store.PATH,io)
		observations.append({"kind":kind,"claim":claim,"raw_highest_imported":same(cold_record,Store.decode(target)),"original_campaign_bullets":before.context.campaign.bullets.size(),"original_legacy_bullets":before.context.legacy.bullets.size()})
		check(not (same(cold_record,Store.decode(target)) and claim.contains("unchanged")),"uncertain committed Import cannot claim whole rescue unchanged")
		game.queue_free(); await ticks(); var cold:=await boot(io)
		check(cold.recovery_pending and cold.paused and same(live(cold),before),"fresh owner cannot silently adopt unconfirmed incoming context")
		observations.back()["fresh_owner_pending_original"]=cold.recovery_pending and same(live(cold),before)
		cold.queue_free(); await ticks()
	# Owning writers already reject bad final destination bytes; retain the old slot.
	for mode in ["missing","corrupt","stale","read1","read2"]:
		for legacy_only in [false,true]:
			var io:=Fault.new(); var source:=fixture(1); var target:=fixture(2,99)
			if legacy_only:
				var decoded:=Store.decode(source); source=Old.encode(decoded.context.legacy,decoded.context.settings,10)
				decoded=Store.decode(target); target=Old.encode(decoded.context.legacy,decoded.context.settings,99)
			io.files[Store.PATH+"0"]=source
			if mode.begins_with("read"): io.unreadable_after=1 if mode=="read1" else 2
			else: io.destination_mode=mode; io.stale_code=source
			var d:=Store.decode(target)
			var okay: bool=Old.write(d.context.legacy,d.context.settings,Store.PATH,io,true) if legacy_only else Store.write(d.context,Store.PATH,io,true)
			# Both owning writers now use one buffered exact destination read.
			check(okay if mode=="read2" else not okay,"owning destination outcome is truthful for "+mode+" / legacy="+str(legacy_only))
			io.unreadable_after=0
			check(Store.decode(io.files[Store.PATH+"0"]).context==Store.decode(source).context,"newest prior raw slot retained exactly across bad/uncertain destination")
	var output:={"checks":checks,"failures":failures,"events":events,"observations":observations,"limits":"Synthetic full schema2 fixtures, typed backend faults, actual GUI touches and same-process fresh owner; no native/OS kill/power-loss/render acceptance."}
	var f:=FileAccess.open(folder.path_join("save-recovery.json"),FileAccess.WRITE); f.store_string(JSON.stringify(output)); f.close()
	print("DEAD_RECOVERY ",checks," / ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
