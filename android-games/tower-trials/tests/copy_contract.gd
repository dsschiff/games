extends SceneTree
const Confirm = preload("res://scripts/copy_confirm.gd")
var checks:=0
var failures: Array[String]=[]
var rows: Array[Dictionary]=[]
var folder:=""
class Clipboard extends RefCounted:
	var supported:=true
	var accepted:=true
	var expected:=""
	var mode:="exact"
	var puts:=0
	var gets:=0
	var available_calls:=0
	var on_available:=Callable()
	var on_put:=Callable()
	var on_get:=Callable()
	func available() -> bool:
		available_calls+=1
		var callback:=on_available; on_available=Callable()
		if callback.is_valid(): callback.call()
		return supported
	func put(text: String) -> bool:
		puts+=1; expected=text
		var callback:=on_put; on_put=Callable()
		if callback.is_valid(): callback.call()
		return accepted
	func get_text() -> String:
		gets+=1
		var callback:=on_get; on_get=Callable()
		if callback.is_valid(): callback.call()
		return expected if mode=="exact" or mode=="delay" and gets>=3 else "different"
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: "+label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder=arg.trim_prefix("--capture-dir=")
	call_deferred("run")
func run() -> void:
	for mode in ["exact","delay","never"]:
		var port:=Clipboard.new(); port.mode=mode; var confirm:=Confirm.new(port)
		var token:=confirm.begin(" \nΩ漢🙂SAVE\n ","original")
		check(confirm.pending and confirm.outcome=="waiting" and port.puts==1 and port.gets==0,"single set requests confirmation without immediate read: "+mode)
		check(not confirm.poll(0.04) and port.gets==0,"no read before the frame poll interval")
		for step in 17:
			confirm.poll(0.04)
			if not confirm.pending: break
		check(confirm.outcome==("unconfirmed" if mode=="never" else "confirmed"),"only exact readback confirms; wrong value times out: "+mode)
		check(port.puts==1 and port.gets<=9 and confirm.elapsed<=0.68,"bounded polls never repeat the write or spin: "+mode)
		check(confirm.expected==" \nΩ漢🙂SAVE\n " and confirm.target=="original" and confirm.generation==token,"request preserves immutable exact unicode/whitespace source and identity")
		var reads:=port.gets; confirm.poll(5); check(port.gets==reads,"completed requests no longer read the clipboard")
		rows.append({"mode":mode,"outcome":confirm.outcome,"puts":port.puts,"gets":port.gets,"elapsed":confirm.elapsed})
	for supported in [false,true]:
		var port:=Clipboard.new(); port.supported=supported; port.accepted=false; var confirm:=Confirm.new(port); confirm.begin("A","A")
		confirm.poll(1)
		check(not confirm.pending and confirm.outcome==("unconfirmed" if supported else "unavailable"),"unsupported is distinct from rejected/unconfirmed write")
		check(port.puts==(1 if supported else 0) and port.gets==0,"unsupported makes zero clipboard calls; rejected writes do not poll")
	for phase in ["available","put","get"]:
		var port:=Clipboard.new(); var confirm:=Confirm.new(port)
		if phase=="available": port.on_available=confirm.cancel
		elif phase=="put": port.on_put=confirm.cancel
		else: port.on_get=confirm.cancel
		var token:=confirm.begin("A","A"); confirm.poll(.08)
		check(not confirm.pending and confirm.outcome.is_empty() and confirm.generation!=token,"reentrant cancellation cannot resurrect waiting/confirmed feedback: "+phase)
		check(port.puts==(0 if phase=="available" else 1),"cancellation respects admitted single write boundary")
	for phase in ["put","get"]:
		for same_text in [false,true]:
			var port:=Clipboard.new(); var confirm:=Confirm.new(port); var replacement: String="A" if same_text else "B"
			var replace:=func(): confirm.begin(replacement,"targetB")
			if phase=="put": port.on_put=replace
			else: port.on_get=replace
			var token:=confirm.begin("A","targetA")
			if phase=="get": check(not confirm.poll(.08),"stale A read cannot emit B confirmation")
			check(confirm.pending and confirm.outcome=="waiting" and confirm.expected==replacement and confirm.target=="targetB" and confirm.generation!=token,"reentrant B request owns state even when source text matches: "+phase)
			check(confirm.poll(.08) and confirm.outcome=="confirmed" and port.puts==2,"replacement request confirms independently with one set each")
	var original:=Clipboard.new(); var other:=Clipboard.new(); var confirm:=Confirm.new(original); confirm.begin("A","A"); confirm.backend=other
	check(confirm.poll(.08) and original.gets==1 and other.gets==0,"admitted request polls its captured original backend")
	confirm.begin("B","B"); check(other.puts==1,"next explicit request may select the new backend")
	var port:=Clipboard.new(); port.mode="never"; confirm=Confirm.new(port); confirm.begin("A","A"); confirm.poll(-1)
	check(port.gets==0,"negative frame time cannot force read")
	check(confirm.poll(2) and confirm.outcome=="unconfirmed" and port.gets==1,"late frame reaches deadline with one bounded read rather than catch-up loop")
	FileAccess.open(folder.path_join("copy-contract.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"scope":"Pure typed fake clipboard contract. No OS clipboard, scene/render/native or save adoption."}))
	print("TOWER_COPY_CONTRACT ",checks," / ",failures.size()); if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
