extends SceneTree
## CPU geometry regression; authored boss meshes, no gameplay footage fixture.
const Foundry = preload("res://scripts/presentation/foundry.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Layout = preload("res://scripts/window_layout.gd")
var checks := 0
var failures: Array[String] = []
var result_path := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="): result_path=arg.trim_prefix("--run-dir=")+"/hud-data.json"
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func run() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var world := Foundry.new()
	viewport.add_child(world)
	var layout := Layout.new()
	layout.arrange(Vector2(600,1400))
	world.build(layout,Vector2(600,1400))
	var old_overlap := false
	for dimensions in [Vector2(600,1400),Vector2(984,1092),Vector2(1092,984),Vector2(600,1066)]:
		layout.arrange(dimensions)
		viewport.size=Vector2i(dimensions)
		world.fit(layout,dimensions)
		var box: Rect2=layout.boss_status()
		check(Rect2(Vector2.ZERO,dimensions).encloses(box),"Boss status stays inside actual canvas "+str(dimensions))
		check(not box.intersects(layout.board) and not box.intersects(layout.field) and not box.intersects(layout.wall),"Boss status clears board/combat/deployment arches")
		for key in layout.controls:
			if key in ["begin","rally"] or str(key).begins_with("gate"): continue
			check(not box.intersects(layout.controls[key]),"Boss status clears functional "+str(key))
		for role in ["captain","siege","matriarch"]:
			var actor := Actor.new()
			world.add_child(actor)
			actor.configure(role,false,0)
			for lane in [44,300,556]:
				for y in [205,260,400,537]:
					actor.position=world.canvas_to_world(layout.field_point(Vector2(lane,y)))
					for angle in [0.0,PI*.5,PI,PI*1.5]:
						actor.rotation.y=angle
						var body: Rect2=world.projected_bounds(actor)
						check(not body.intersects(box),"Actual projected "+role+" body clears boss status")
						var old := Rect2(48,layout.field.position.y+66,dimensions.x-96,64)
						if role=="matriarch" and lane==300 and y==205 and old.intersects(body): old_overlap=true
			var text := "Phase 3 · 10000 HP" if layout.wide else str(role).capitalize()
			check(ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16 if layout.wide else 13).x<=box.size.x-12,"Full boss identity/status text fits "+role)
			actor.free()
	check(old_overlap,"Regression is sensitive: previous top panel intersects actual Matriarch mesh")
	var file := FileAccess.open(result_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"old_overlap_reproduced":old_overlap,"scope":"Actual exported mesh projection and functional-control clearance; CPU only"},"\t"));file.close()
	viewport.free()
	print("BOSS_HUD: %d checks, %d failures" % [checks,failures.size()])
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
