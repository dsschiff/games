extends "res://tests/import_recovery.gd"
## Decoder-valid complete profiles; actual selector touch, no combat or clipboard simulation.
const RANKING := "Fewer hits first; faster time breaks ties."
const EMPTY := "No clear yet for this seed and loadout."
func run() -> void:
	var cases := [
		{"name":"no_clear","scores":{},"text":EMPTY},
		{"name":"zero","scores":{"1701:3":{"hits":0,"time":0.0,"rescues":0}},"text":"Best clear: 0 hits · 0.00 s"},
		{"name":"alias","scores":{"1701.0:3":{"hits":2,"time":41.25,"rescues":9}},"text":"Best clear: 2 hits · 41.25 s"},
		{"name":"alias_fewer_hits","scores":{"1701:3":{"hits":3,"time":1.0,"rescues":99},"1701.0:3":{"hits":1,"time":70.0,"rescues":0}},"text":"Best clear: 1 hit · 70.00 s"},
		{"name":"canonical_faster_tie","scores":{"1701:3":{"hits":1,"time":20.5,"rescues":0},"1701.0:3":{"hits":1,"time":30.0,"rescues":99}},"text":"Best clear: 1 hit · 20.50 s"},
		{"name":"long_seed","seed":999999,"scores":{"999999:3":{"hits":0,"time":0.0,"rescues":0}},"text":"Best clear: 0 hits · 0.00 s"},
		{"name":"largest_valid","scores":{"1701:3":{"hits":100000000,"time":100000000.0,"rescues":100000000}},"text":"Best clear: 100000000 hits · 100000000.00 s"}
	]
	for extent in [Vector2i(450,1000),Vector2i(720,1280),Vector2i(1000,900),Vector2i(900,450)]:
		root.size=extent
		for entry in cases:
			var context: Dictionary=contexts()[2]
			context.profile.arena_seed=entry.get("seed",1701)
			context.profile.arena_scores=entry.scores.duplicate(true)
			context.profile.arena_scores["1702:3"]={"hits":4,"time":12.5,"rescues":7}
			context.profile.arena_scores["1702.0:2"]={"hits":5,"time":25.0,"rescues":2}
			context.profile.arena_scores["opaque historical entry"]={"hits":2,"time":13.0,"rescues":8,"extra":"retain whole"}
			check(S.decode(code(context)).ok,"complete parked-finale profile validates "+entry.name)
			var io:=fresh_io(context)
			await open_owner(io); scene._layout(); await process_frame; await process_frame
			var before:=whole(); var files: Dictionary=io.files.duplicate(true); var writes: int=io.active_writes
			var display: Label=scene.get("arena_best_label")
			check(display!=null,"selected arena has read-only best-clear feedback "+entry.name)
			if display==null: continue
			check(display.text==entry.text+"\n"+RANKING,"selected canonical/legacy best or honest no-clear "+entry.name)
			for repeat in 6: scene._sync()
			check(whole()==before and io.files==files and io.active_writes==writes,"read-only best refresh preserves complete live context and every slot byte "+entry.name)
			await feedback_layout(display,extent,entry.name)
			check(display.is_visible_in_tree(),"completed Harbor exposes feedback beside matching selections")
			if entry.name=="long_seed": continue
			await tap(scene.arena_seed_button.text)
			var expected:=before.duplicate(true); expected.profile.arena_seed=1702
			check(display.text=="Best clear: 4 hits · 12.50 s\n"+RANKING,"actual seed selection updates only its best")
			check(whole()==expected and matches(S.read(S.PATH,io),expected),"actual seed selection saves only existing selection change; whole scores/ending retained")
			await tap(scene.arena_weapon_button.text)
			expected.profile.arena_weapon=1
			check(display.text==EMPTY+"\n"+RANKING,"actual loadout selection never borrows another loadout's score")
			check(whole()==expected and matches(S.read(S.PATH,io),expected),"actual loadout selection preserves complete parked ending and historical scores")
			await tap(scene.arena_weapon_button.text)
			expected.profile.arena_weapon=2
			check(display.text=="Best clear: 5 hits · 25.00 s\n"+RANKING,"actual loadout selection reads historical alias")
			check(whole()==expected and matches(S.read(S.PATH,io),expected),"second selection preserves entire expected context durably")
			observations.append({"case":entry.name,"size":[extent.x,extent.y],"initial_text":entry.text,"after":whole(),"saved":S.read(S.PATH,io),"feedback_rect":[display.position.x,display.position.y,display.size.x,display.size.y]})
	var locked_io:=fresh_io(contexts()[0]); await open_owner(locked_io)
	check(not scene.arena_panel.visible and not scene.arena_best_label.is_visible_in_tree(),"arena feedback stays hidden before existing unlock")
	# Pending recovery must bypass feedback and preserve the original whole context.
	var original: Dictionary=contexts()[2]; var io:=fresh_io(original); await open_owner(io)
	var before:=whole(); io.mode="active_after_store"; scene.transfer.text=code(contexts()[1]); await tap("IMPORT")
	check(scene.import_pending and scene.paused,"actual uncertain Import enters pending owner")
	var frozen_files: Dictionary=io.files.duplicate(true); var writes: int=io.active_writes
	if scene.get("arena_best_label")!=null:
		var text: String=scene.arena_best_label.text
		scene._sync(); scene._cycle_seed(); scene._cycle_weapon(); scene._arena(); scene._save()
		check(whole()==before and io.files==frozen_files and io.active_writes==writes and scene.arena_best_label.text==text,"pending gates still freeze selected arena feedback and all context/storage")
	if is_instance_valid(scene): scene.free()
	await process_frame
	FileAccess.open(capture_dir.path_join("arena-feedback.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"observations":observations,"scope":"Synthetic complete validated profiles and typed backend; actual ScreenTouch selector input/scroll and save readback. Headless/Dummy cached CPU layout only, no rendered/native/phone or earned fresh arena clear claim."},"  "))
	print("ARENA_FEEDBACK ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)

func feedback_layout(display: Label,extent: Vector2i,case_name: String) -> void:
	var scroll: ScrollContainer=scene.menu.get_child(0)
	scroll.ensure_control_visible(display); await process_frame; await process_frame
	check(scroll.get_global_rect().encloses(display.get_global_rect()),"whole wrapping best/ranking feedback fits reachable scroll area "+str(extent)+case_name)
	check(display.get_line_count()*display.get_line_height()<=display.size.y+1,"all feedback lines fit label height "+case_name)
	check(display.position.y>=scene.arena_weapon_button.position.y+scene.arena_weapon_button.size.y,"feedback follows selected seed/loadout")
	var sail: Button
	for b in scene.arena_panel.get_children():
		if b is Button and b.text=="SAIL TO ARENA": sail=b
	check(sail!=null and sail.position.y>=display.position.y+display.size.y,"feedback cannot overlap Sail action")
	if sail!=null:
		scroll.ensure_control_visible(sail); await process_frame; await process_frame
		check(scroll.get_global_rect().encloses(sail.get_global_rect()) and sail.size.y>=100,"Sail remains touch-sized/scroll-reachable after feedback "+str(extent))
