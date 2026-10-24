extends "res://tests/input_base.gd"
const Fault = preload("res://tests/fault_files.gd")
const Challenge = preload("res://scripts/challenge_v1.gd")
class PaintObserver extends "res://scripts/main.gd":
	var painted: Array[Dictionary]=[]
	var recording_note:=false
	func lines(value: String,at: Vector2,width: float,size: int,color: Color=Color("f4eee3"),max_lines: int=3,line_height: float=0.0) -> void:
		recording_note=transfer and value==note and width==516 and size==19
		super.lines(value,at,width,size,color,max_lines,line_height); recording_note=false
	func text_at(value: String,at: Vector2,size: int,color: Color=Color("f4eee3")) -> void:
		if recording_note: painted.append({"text":value,"at":at,"size":size})
		super.text_at(value,at,size,color)
	func _draw() -> void:
		painted.clear(); super._draw()
var transfer_geometry: Array[Dictionary]=[]
func create_game() -> void:
	game=PaintObserver.new(); game.save_path=test_path; root.add_child(game); current_scene=game; await wait_frames(3)
func complete_fixture(active_challenge: bool) -> Dictionary:
	var value: Dictionary=Saves.decode(FileAccess.get_file_as_string("res://tests/fixtures/save-commit-before.json")).data
	var bundle: Dictionary=Challenge.generate("key",137,{"weave":0,"treasure":true}).bundle
	value.challenge_run={"bundle":bundle,"actions":[bundle.witness[0]],"used_undo":true}
	value.challenge_records=[{"key":Challenge.validate(bundle).key,"version":bundle.version,"family":bundle.family,"seed":bundle.seed,"options":bundle.options.duplicate(true),"best":bundle.witness.size(),"medals":1,"fallback":bundle.fallback}]
	value.kind="challenge" if active_challenge else "campaign"
	value.settings.sound=false; value.settings.reduced_effects=true; value.settings.note="full geometry fixture"
	return Saves.decode(Saves.encode(value)).data
func transfer_note_bounds() -> void:
	game.queue_free(); await wait_frames(3)
	var notes: Array[String]=["Save text copied. Store it somewhere private.","Save text copied. Store it somewhere private. Keep this complete route safely so your progress can be restored.","Save text copied. Store it somewhere private. Keep this complete route safely so your progress can be restored. Your whole campaign and challenge progress are included in the saved text."]
	for active_challenge in [false,true]:
		var io:=Fault.new()
		for slot in 4:
			var fixture:=complete_fixture(active_challenge); fixture.revision=5+slot
			io.files[test_path+["", ".tmp", ".bak", ".bak.tmp"][slot]]=" "+Saves.encode(fixture)+" \n"
		game=PaintObserver.new(); game.save_path=test_path; game.save_io=io; root.add_child(game); current_scene=game; await wait_frames(3)
		game.set_process(false)
		await action("settings"); await action("transfer")
		check(game.transfer and game.editor.visible,"actual touch opens the real transfer panel")
		var before: Dictionary=game.data.duplicate(true); var state_before: Dictionary=game.state.duplicate(true); var raw: Dictionary=io.files.duplicate(true)
		var controls: Dictionary=game.buttons().duplicate(true)
		check(controls=={"copy":Rect2(42,710,160,80),"paste":Rect2(220,710,160,80),"import":Rect2(398,710,160,80),"close_transfer":Rect2(42,804,516,80)},"all four transfer controls retain their existing hit rectangles")
		for viewport in [Vector2i(344,642),Vector2i(690,829),Vector2i(1066,600)]:
			root.size=viewport; await wait_frames(3)
			for index in notes.size():
				game.note=notes[index]; game.queue_redraw(); await wait_frames(3)
				var rows: Array[Dictionary]=[]
				for item in game.painted:
					if item.size==19 and item.at.y>800: rows.append(item)
				check(rows.size()==index+1,"production wrapping emits the intended one/two/three-line note")
				var bounds: Array[Rect2]=[]
				for row in rows:
					var rect:=Rect2(row.at-Vector2(0,game.font.get_ascent(19)),Vector2(game.font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x,game.font.get_height(19)))
					check(rect.position.y>=controls.close_transfer.end.y+8.0-0.01,"actual ascender ink clears Return with eight-pixel gap")
					check(not rect.intersects(controls.close_transfer),"actual ascender/descender bounds never overlap Return")
					check(Rect2(42,controls.close_transfer.end.y,516,1066-controls.close_transfer.end.y).encloses(rect),"all transfer note glyph bounds remain in the logical panel")
					for previous in bounds: check(not previous.intersects(rect),"actual wrapped note font cells remain vertically separated")
					bounds.append(rect)
					var physical: Rect2=root.get_final_transform()*game.global_transform*rect
					check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(physical),"cover/inner/wide transformed note remains on screen")
				transfer_geometry.append({"active_kind":game.data.kind,"viewport":str(viewport),"requested_lines":index+1,"rows":rows,"font_ascent":game.font.get_ascent(19),"font_height":game.font.get_height(19),"bounds":str(bounds),"return":str(controls.close_transfer)})
				check(game.buttons()==controls and game.data==before and game.state==state_before and io.files==raw,"repeated actual drawing/geometry queries preserve every control and whole data/raw save")
		await action("close_transfer"); check(not game.transfer and not game.editor.visible,"actual unchanged Return touch closes transfer")
		check(game.data==before and game.state==state_before and io.files==raw,"Return preserves campaign/actions/Undo/profile/settings plus challenge snapshot/actions/Undo/records and active kind")
		game.queue_free(); await wait_frames(3)

func _initialize() -> void:
	root.size = Vector2i(360, 800)
	rendered = DisplayServer.get_name() != "headless"
	folder = "res://.artifacts/challenge-v1/campaign/layout-" + ("rendered" if rendered else "headless")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder=arg.trim_prefix("--capture-dir=")
	test_path = "user://tower-layout-input.json"
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		DirAccess.remove_absolute(test_path + suffix)
	await create_game()
	root.size = Vector2i(360, 800)
	await wait_frames(5)
	check(root.size == Vector2i(360, 800), "Requested cover-size desktop viewport is active")
	await enter("bell")
	check(game.state.power == 5, "Cover-aspect actual input claims room")
	await tap(game.buttons().retry.end - Vector2.ONE)
	check(game.state.power == 3 and game.data.actions.is_empty(), "Bottom-right hit-area boundary activates Retry without adjacent action")
	await enter("bell")
	await tap(game.buttons().undo.position + Vector2.ONE)
	check(game.state.power == 3 and game.data.used_undo, "Top-left Undo hit-area boundary restores whole action")
	await frame("00-cover-boundaries")
	await action("map")
	await drag(Vector2(540, 840), Vector2(540, 400))
	check(game.screen == "map" and game.map_scroll > 0 and game.data.level_id == "watch_01", "Drag scrolls without selecting the touched row")
	await frame("01-cover-map-footer")
	await action("level8")
	check(game.screen == "map" and game.data.profile.is_empty(), "Scrolled locked chapter finale remains locked")
	await action("resume")
	var before: Dictionary = game.state.duplicate(true)
	root.size = Vector2i(900, 1000)
	await wait_frames(5)
	check(game.state == before, "Resize preserves action and Undo state")
	await enter("bell")
	check(game.state.power == 5, "Actual unfolded-aspect room input still aligns after resize")
	await frame("02-unfolded-input")
	await transfer_note_bounds()
	var file := FileAccess.open(folder + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "actual_touch_taps": taps, "transfer_geometry":transfer_geometry, "scope": "Desktop 360x800 and900x1000 aspect tests and logical hit boundaries; not phone safe-area/density measurement"}, "\t"))
	file.close()
	print("TOWER LAYOUT INPUT: %d checks; %d failures" % [checks, failures.size()])
	if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
