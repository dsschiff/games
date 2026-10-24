extends "res://tests/input_base.gd"
const Content = preload("res://scripts/content.gd")
class PaintObserver extends "res://scripts/main.gd":
	var painted: Array[Dictionary] = []
	var observed_events: Array[Dictionary] = []
	func text_at(value: String, at: Vector2, size: int, color: Color=Color("f4eee3")) -> void:
		painted.append({"text":value,"at":at,"size":size}); super.text_at(value,at,size,color)
	func _draw() -> void:
		painted.clear(); super._draw()
	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch: observed_events.append({"pressed":event.pressed,"position":str(event.position)})
var evidence: Array[Dictionary] = []
var observed_events: Array[Dictionary] = []
var geometry_evidence: Array[Dictionary] = []
func _initialize() -> void:
	root.size=Vector2i(600,1066); folder="res://.artifacts/medal-feedback"; test_path="user://tower-medal-feedback.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder=arg.trim_prefix("--capture-dir=")
	call_deferred("run")
func create_game() -> void:
	game=PaintObserver.new(); game.save_path=test_path; root.add_child(game); current_scene=game; await wait_frames(3)
func close_game() -> void:
	if game is PaintObserver: observed_events.append_array(game.observed_events)
	game.queue_free(); await wait_frames(3)
func row(prefix: String) -> String:
	for item in game.painted:
		if item.at.y>=792 and item.at.y<862 and item.text.to_lower().begins_with(prefix.to_lower()): return item.text
	return ""
func feedback(label: String,this_words: Array,not_this_words: Array,collected_words: Array,best: int) -> void:
	game.queue_redraw(); await wait_frames(3)
	var this_row:=row("This clear"); var collected:=row("Collected"); var stats:=row("Best")
	check(game.painted.any(func(item): return item.text.begins_with("Moves %d " % game.state.moves)),label+": existing HUD keeps the current move count visible")
	for word in this_words: check(this_row.contains(word),label+": current clear explicitly names "+word)
	for word in not_this_words: check(not this_row.contains(word),label+": current clear does not claim "+word)
	for word in collected_words: check(collected.contains(word),label+": cumulative record explicitly names "+word)
	check(stats.contains("Best %d" % best),label+": best is separate from this route")
	check(not (this_row+collected+stats).to_lower().contains("new"),label+": presentation makes no newly-earned claim")
	evidence.append({"label":label,"data":game.data.duplicate(true),"state":game.state.duplicate(true),"painted":game.painted.duplicate(true)})
func meaning(data: Dictionary) -> Dictionary:
	var copy:=data.duplicate(true); copy.erase("revision"); copy.erase("recoverable"); return copy
func geometry(label: String) -> void:
	var context: Dictionary=game.data.duplicate(true); var state: Dictionary=game.state.duplicate(true); var disk:=FileAccess.get_file_as_string(test_path)
	for viewport in [Vector2i(344,642),Vector2i(690,829),Vector2i(1066,600)]:
		root.size=viewport; game.queue_redraw(); await wait_frames(4)
		var rects: Array[Rect2]=[]
		for item in game.painted:
			if item.at.y<792 or item.at.y>=862 or not (item.text.begins_with("This clear") or item.text.begins_with("Collected") or item.text.begins_with("Best")): continue
			var size: int=item.size
			var rect:=Rect2(item.at-Vector2(0,game.font.get_ascent(size)),Vector2(game.font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,game.font.get_height(size)))
			check(Rect2(24,792,552,158).encloses(rect),label+": actual font ascender/descender bounds inside result")
			check(not rect.intersects(game.buttons().next),label+": result text clear of unchanged Next hit rect")
			for other in rects: check(not rect.intersects(other),label+": result rows do not overlap")
			rects.append(rect)
			geometry_evidence.append({"label":label,"viewport":str(viewport),"text":item.text,"font_size":size,"font_rect":str(rect),"next":str(game.buttons().next)})
			var physical: Rect2=root.get_final_transform()*game.global_transform*rect
			check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(physical),label+": transformed text remains on "+str(viewport))
		check(rects.size()==3,label+": all three distinct feedback groups emitted")
		check(game.buttons().next==Rect2(38,862,524,80),label+": existing Next target unchanged")
		check(game.buttons().undo.size.y==80 and game.buttons().retry.size.y==80,label+": Undo and Retry retain their targets")
	check(game.data==context and game.state==state and FileAccess.get_file_as_string(test_path)==disk,label+": repeated drawing never mutates whole data/state or save bytes")
	root.size=Vector2i(600,1066); await wait_frames(3)
func check_journey_geometry(label: String) -> void:
	for viewport in [Vector2i(344,642),Vector2i(690,829),Vector2i(1066,600)]:
		root.size=viewport; game.queue_redraw(); await wait_frames(4)
		for id in game.buttons():
			if not id.begins_with("level"): continue
			var button: Rect2=game.buttons()[id]
			for item in game.painted:
				if item.at==button.position+Vector2(70,55):
					var size: int=item.size
					var rect:=Rect2(item.at-Vector2(0,game.font.get_ascent(size)),Vector2(game.font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,game.font.get_height(size)))
					check(button.encloses(rect),label+": existing Journey row contains named goal font bounds")
					var physical: Rect2=root.get_final_transform()*game.global_transform*rect
					check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(physical),label+": transformed Journey label remains visible")
	root.size=Vector2i(600,1066); await wait_frames(3)
func longest_labels() -> void:
	# Read-only typed layout cases, not injected gameplay or newly earned progress.
	var before: Dictionary=game.data.duplicate(true); var state: Dictionary=game.state.duplicate(true); var disk:=FileAccess.get_file_as_string(test_path)
	var all_names: String=game.medal_labels(15)
	check(all_names=="Rescue · Par · Treasure · No Undo","all eligible medal names have the intended unambiguous No Undo wording")
	check(game.font.get_string_size("This clear · "+all_names,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x<=520,"longest current-clear name group fits actual result width")
	var collected_width: float=game.font.get_string_size("Collected · "+all_names,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	var metric_width: float=game.font.get_string_size("Best 8 · Par 8",HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	check(collected_width+metric_width+16<=520,"longest collected names and valid maximum-best metrics retain a gap")
	var all_goal: String=game.journey_medals(Content.by_id("meridian_09"),{"best":8,"medals":1})
	check(all_goal=="Best 8 · To earn: Par · No Undo","non-treasure eligible goals omit Treasure even in the maximum-best case")
	for definition in Content.levels():
		for bits in [1,3,11,15]:
			var text: String=game.journey_medals(definition,{"best":definition.rooms.size(),"medals":bits})
			check(game.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x<=478,"valid campaign goal/best font width fits existing Journey row")
			if not definition.rooms.any(func(room): return room.treasure): check(not text.contains("Treasure"),"unoffered Treasure never becomes a replay goal")
	var record_text: String=game.medal_labels(15)+" · fallback"
	check(game.font.get_string_size(record_text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<=484,"existing challenge record row fits longest No Undo/fallback label")
	check(game.data==before and game.state==state and FileAccess.get_file_as_string(test_path)==disk,"typed layout queries never alter whole context or file")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(test_path+suffix)
	await create_game()
	await enter("bell"); await action("undo")
	for id in Rules.solve(game.level,game.state).route: await enter(id)
	check(game.data.profile.watch_01.medals==3 and game.current_run().used_undo,"actual Undo win independently earns Rescue/Par only")
	await feedback("Undo win",["Rescue","Par"],["No Undo","Treasure"],["Rescue","Par"],4); await geometry("Undo win")
	await action("map"); game.queue_redraw(); await wait_frames(3)
	check(game.painted.any(func(item): return item.text.contains("To earn: No Undo")),"Journey names eligible missing No Undo rather than anonymous count"); await check_journey_geometry("Missing No Undo")
	await action("level0"); await action("retry"); for id in Rules.solve(game.level).route: await enter(id)
	check(game.data.profile.watch_01.medals==11 and not game.current_run().used_undo,"actual clean replay preserves existing medals and earns No Undo")
	await feedback("No Undo replay",["Rescue","Par","No Undo"],["Treasure"],["Rescue","Par","No Undo"],4)
	await action("undo"); await enter("light")
	check(game.data.profile.watch_01.medals==11 and game.current_run().used_undo,"later Undo does not erase the cumulative No Undo medal")
	await feedback("Undo after collected No Undo",["Rescue","Par"],["No Undo","Treasure"],["Rescue","Par","No Undo"],4)
	await action("map"); game.queue_redraw(); await wait_frames(3)
	check(game.painted.any(func(item): return item.text.contains("All medals earned")),"non-treasure Journey can reach all-earned without Treasure")
	await action("resume"); await action("next")
	for index in range(1,11):
		check(game.data.level_id==Content.levels()[index].id,"actual progression reaches "+Content.levels()[index].id)
		for id in Rules.solve(game.level,game.state).route: await enter(id)
		if index<10: await action("next")
	check(game.data.profile.archive_02=={"best":3,"medals":11},"actual par route earns independent known11/best3")
	await action("map"); await action("chapter1"); game.queue_redraw(); await wait_frames(3)
	check(game.painted.any(func(item): return item.text.contains("Best 3") and item.text.contains("To earn: Treasure")),"Journey names the existing treasure replay goal"); await check_journey_geometry("Missing Treasure")
	await action("level10"); await action("retry")
	for id in ["key","door","spare","chest","light"]: await enter(id)
	check(game.state.status=="won" and game.state.moves==5 and game.state.treasure==1 and not game.current_run().used_undo,"actual five-step treasure replay reaches its distinct known result")
	check(game.data.profile.archive_02=={"best":3,"medals":15},"slower treasure replay unions medals without replacing best3")
	await feedback("Treasure replay",["Rescue","Treasure","No Undo"],["Par"],["Rescue","Par","Treasure","No Undo"],3); await geometry("Treasure replay")
	var complete: Dictionary=game.data.duplicate(true); var before:=FileAccess.get_file_as_string(test_path)
	await close_game(); game=Scene.instantiate(); game.save_path=test_path; root.add_child(game); current_scene=game; await wait_frames(3)
	check(meaning(game.data)==meaning(complete) and FileAccess.get_file_as_string(test_path)==before,"normal uninstrumented shipping cold owner retains complete profile/settings/route and exact save")
	await close_game(); await create_game()
	check(meaning(game.data)==meaning(complete),"observer cold owner reads the same complete context")
	await feedback("Cold won route",["Rescue","Treasure","No Undo"],["Par"],["Rescue","Par","Treasure","No Undo"],3)
	var parked: Dictionary=game.data.duplicate(true)
	await action("settings"); await action("challenge_select"); await action("treasure_option"); await action("generate")
	check(game.data.kind=="challenge" and not game.data.challenge_run.bundle.options.treasure,"actual controls generate pinned no-treasure challenge")
	for id in Rules.solve(game.level).route: await enter(id)
	var challenge_best: int=game.level.par
	check(game.current_challenge_record().medals==11,"no-treasure challenge independently earns all eligible bits11")
	await feedback("No Treasure challenge",["Rescue","Par","No Undo"],["Treasure"],["Rescue","Par","No Undo"],challenge_best); await geometry("No Treasure challenge")
	check(game.data.profile==parked.profile and game.data.actions==parked.actions and game.data.settings==parked.settings and game.data.used_undo==parked.used_undo,"challenge feedback and play retain full parked campaign/profile/settings/Undo")
	await action("next"); check(game.state.moves==0 and game.state.status=="active","actual challenge Next retains Replay behavior")
	for id in Rules.solve(game.level).route: await enter(id)
	await action("undo"); check(game.state.status=="active" and game.current_run().used_undo,"actual challenge Undo retains action semantics after win")
	await action("retry"); check(game.state.moves==0 and not game.current_run().used_undo,"actual challenge Retry retains clean-attempt semantics")
	await action("settings"); await action("challenge_select"); await action("treasure_option"); await action("generate")
	for id in Rules.solve(game.level).route: await enter(id)
	challenge_best=game.level.par
	await action("next")
	for id in Rules.solve(game.level,{},true).route: await enter(id)
	check(game.current_challenge_record().medals==15 and game.current_challenge_record().best==challenge_best,"actual challenge par then treasure replay accumulates separately by exact pinned identity")
	await feedback("Treasure challenge",["Rescue","Treasure","No Undo"],["Par"],["Rescue","Par","Treasure","No Undo"],challenge_best); await geometry("Treasure challenge")
	var whole: Dictionary=game.data.duplicate(true); var code:=FileAccess.get_file_as_string(test_path)
	await close_game(); game=Scene.instantiate(); game.save_path=test_path; root.add_child(game); current_scene=game; await wait_frames(3)
	check(meaning(game.data)==meaning(whole) and FileAccess.get_file_as_string(test_path)==code,"normal shipping cold owner preserves complete challenge record/snapshot and parked campaign")
	await close_game(); await create_game(); await feedback("Cold challenge clear",["Rescue","Treasure","No Undo"],["Par"],["Rescue","Par","Treasure","No Undo"],challenge_best)
	longest_labels()
	await close_game()
	FileAccess.open(folder.path_join("medal-feedback.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"actual_touch_taps":taps,"observed_events":observed_events,"geometry":geometry_evidence,"evidence":evidence,"scope":"CPU/headless/Dummy. PaintObserver records production text_at arguments and delegates unchanged; actual engine touch drives all progress. Uninstrumented shipping cold owner checks full context. No rendered/native/fun claim."}))
	print("TOWER_MEDAL_FEEDBACK ",checks," / ",failures.size()," / ",taps," taps"); if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
