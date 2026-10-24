extends RefCounted
## Explicit game-side cloud operations. Local adoption belongs only to ImportRecovery.
const Store = preload("res://scripts/save_store.gd")
const Files = preload("res://scripts/save_files.gd")
const Backup = preload("res://scripts/cloud/backup.gd")
const Copies = preload("res://scripts/cloud/copies.gd")
const Port = preload("res://scripts/cloud/port.gd")
signal changed
signal closed
const SLOT := "frontline-foundry-v1"
var phase := "closed"
var message := ""
var player := ""
var choices: Array[Dictionary] = []
var preserved_ids: Array[String] = []
var local_code := ""
var configured := false
var port: Port
var io: RefCounted
var copies: Copies
var restore: Callable
var capture: Callable
var _disk := {}
var _serial := 0
var _pending := ""
var _operation := ""
var _conflict := ""
var _selected := -1
var _action := ""
var _expected := ""
var _closing := false
var _awaiting_cleanup := false
var remote_effect := "none"
var _after_cleanup := ""
var _restore_code := ""
var _restore_account := false

func setup(source: Callable, backend: RefCounted, transport: Port, restore_local: Callable) -> void:
	restore = restore_local; capture = source; io = backend if backend != null else Files.new(); copies = Copies.new(io); port = transport
	port.completed.connect(_receive)

func open() -> void:
	if phase != "closed": return
	local_code = str(capture.call())
	if not Store.decode(local_code).ok:
		phase = "error"; message = "The complete local save could not be read. Local play remains paused."; changed.emit(); return
	_disk = disk_identity()
	if port.cleanup_required():
		_after_cleanup="close"; _awaiting_cleanup=true; phase="cleanup_required"; message="Previous cloud cleanup is unfinished. Retry cleanup before opening a connection. Local play stays paused."; changed.emit(); return
	configured = port.is_configured()
	phase = "connect" if configured else "unavailable"
	message = "Optional. Connect to check this account's saves. Nothing is uploaded automatically." if configured else "Cloud is unavailable in this build. No account connection or backup is active. Local saves and local recovery copies work offline."
	changed.emit()

func connect_account() -> void:
	if phase != "connect": return
	_send("sign_in",{})

func check_cloud() -> void:
	if phase not in ["ready","choose","submitted","error"] or player.is_empty() or not _conflict.is_empty(): return
	choices.clear(); _expected = ""; _send("read",{"slot":SLOT,"player":player})

func stage_backup() -> void:
	if phase not in ["ready","choose","submitted","error"] or player.is_empty() or not _conflict.is_empty(): return
	if choices.size()>1: return
	_action = "backup"; phase = "confirm"
	message = "Submit this device's whole save?" + (" It will replace exactly the cloud record shown; its complete copy will be retained locally." if choices.size()==1 else " This first attempt creates an empty slot only. Any existing save must be compared and confirmed separately.") + " Submission can be cached offline; it does not prove server sync."
	changed.emit()

func stage_restore(index: int) -> void:
	if phase != "choose" or index<0 or index>=choices.size(): return
	_restore_account = true; _selected = index; _restore_code = choices[index].save; _action = "restore"; phase = "confirm"
	message = "Use this exact whole save on this device? Current progress, settings and parked modes will be replaced together. Complete copies are kept locally. Cloud records will not be changed."
	changed.emit()

func stage_archive(code: String) -> void:
	if phase not in ["unavailable","connect","ready","choose","submitted","error"] or not _pending.is_empty() or not _conflict.is_empty() or not Store.decode(code).ok: return
	_restore_account = false; _restore_code = code; _action = "restore"; phase = "confirm"
	message = "Use this local recovery copy? It replaces the complete local context after verified Import recovery. No cloud operation is needed."
	changed.emit()

func stage_resolve(index: int) -> void:
	if phase != "choose" or _conflict.is_empty() or index<0 or index>=choices.size(): return
	_selected = index; _action = "resolve"; phase = "confirm"
	message = "Keep cloud copy " + str(index+1) + " as this account's conflict choice? Both whole copies will be retained on this device first. This changes cloud conflict selection; it does not restore locally or upload this device. Another conflict will require another choice."
	changed.emit()

func decline() -> void:
	if phase != "confirm": return
	phase = "choose" if not choices.is_empty() else ("ready" if not player.is_empty() else ("connect" if configured else "unavailable"))
	_action = ""; changed.emit()

func confirm() -> void:
	if phase != "confirm": return
	if not unchanged(): _fail("This device's complete save changed. Close and compare again."); return
	if not preserve(): _fail("Complete recovery copies could not be verified. Nothing was changed."); return
	if _action == "restore" and _restore_account:
		_send("status",{})
	elif _action == "restore":
		# Await original-client cleanup before replacing this scene with local Import.
		_after_cleanup = "restore"
		_cleanup()
	else:
		_send("status",{})

func cancel() -> void:
	if phase=="closed" or _closing: return
	# Local cancellation is final immediately; the independent port owns cleanup.
	# It cannot undo a cloud commit/resolve that was already dispatched.
	_closing=true; _awaiting_cleanup=false; _restore_code=""; _action=""; restore=Callable()
	_pending=""; _operation=""; phase="closed"
	message="Local play can continue. A dispatched cloud operation may still finish." if remote_effect=="unknown" else "Local play can continue. Cloud cleanup may still be pending."
	if port.completed.is_connected(_receive): port.completed.disconnect(_receive)
	port.abandon()
	closed.emit()

func _cleanup() -> void:
	phase = "closing"; _pending = ""; _operation = ""
	_awaiting_cleanup=true; port.abandon(); changed.emit()

func _send(operation: String,args: Dictionary) -> void:
	_serial += 1; _pending = "frontline-ui-"+str(get_instance_id())+"-"+str(_serial); _operation = operation
	phase = "busy"; message = {"sign_in":"Connecting...","status":"Confirming account...","read":"Checking cloud saves...","write":"Submitting whole backup. This may be cached offline...","resolve":"Submitting the explicit cloud conflict choice..."}.get(operation,"Working...")
	if operation in ["write","resolve"]: remote_effect="unknown"
	changed.emit(); port.request(_pending,operation,args)

func _receive(id: String, body: Dictionary) -> void:
	if id == "@abandoned":
		if not _awaiting_cleanup: return
		_awaiting_cleanup=false
		remote_effect=str(body.get("remote_effect",remote_effect))
		if body.get("status") != "cancelled":
			phase = "cleanup_required"; message = "Cloud cleanup is unconfirmed. Retry cleanup; local play remains paused."; changed.emit(); return
		_conflict = ""; _pending = ""; _operation = ""
		if _after_cleanup == "restore":
			if not unchanged(): _fail("This device changed before Import. Compare again."); return
			if _restore_account:
				_action="restore_after_cleanup"; _send("status",{})
			else:
				_handoff()
		elif _after_cleanup=="error":
			phase="error"; changed.emit()
		else:
			phase = "closed"; closed.emit()
		return
	if id != _pending or _pending.is_empty(): return
	var op := _operation; _pending = ""; _operation = ""
	var status := str(body.get("status",""))
	if op == "sign_in":
		if status == "authenticated": _send("status",{})
		else: _fail("Connection unavailable. This device's save is unchanged.")
		return
	if op == "status":
		var owner := str(body.get("player",""))
		if status != "authenticated" or owner.is_empty() or owner.length()>128 or (not player.is_empty() and owner!=player):
			_fail("Account unavailable or changed. Close and compare again; local progress is unchanged."); return
		player = owner
		if _action == "restore_after_cleanup":
			if not unchanged(): _fail("This device changed before Import. Compare again."); return
			_handoff()
		elif _action == "restore":
			if not unchanged(): _fail("This device changed before restore. Compare again."); return
			_after_cleanup = "restore"; _cleanup()
		elif _action == "backup":
			if not unchanged(): _fail("This device changed before backup. Compare again."); return
			var packet := Backup.encode(local_code)
			if not packet.ok: _fail("The whole local save cannot be encoded. No upload was requested."); return
			_send("write",{"slot":SLOT,"player":player,"expected_sha256":_expected,"data":Marshalls.raw_to_base64(packet.text.to_utf8_buffer())})
		elif _action == "resolve":
			if not unchanged(): _fail("This device changed before conflict selection. Compare again."); return
			_send("resolve",{"player":player,"conflict":_conflict,"choice":_selected})
		else:
			phase = "ready"; message = "Connected. Check saves or explicitly submit a whole backup. No automatic sync is active."; changed.emit()
		return
	if status in ["conflict","loaded","remote_changed"]:
		if str(body.get("player","")) != player:
			_fail("The account changed. Reconnect before comparing."); return
		var packets: Array = [body.get("first"),body.get("second")] if status=="conflict" else [body.get("snapshot") if status=="loaded" else body.get("remote")]
		var decoded_choices: Array[Dictionary] = []
		for packet in packets:
			if not packet is Dictionary: _fail("The cloud response could not be validated. Local progress is unchanged."); return
			var decoded := Backup.snapshot(packet)
			if not decoded.ok: _fail("A cloud copy is invalid or belongs to another game. Local progress is unchanged."); return
			decoded_choices.append(decoded)
		choices = decoded_choices; _selected = -1; _action = ""
		_conflict = str(body.get("conflict","")) if status=="conflict" else ""
		if status=="conflict" and (_conflict.is_empty() or _conflict.length()>512): _fail("Cloud conflict identity is invalid."); return
		_expected = str(packets[0].sha256) if choices.size()==1 else ""
		phase = "choose"; message = "Compare whole saves. Local restore does not change cloud. Conflict selection and backup replacement each require a separate confirmation." if status=="conflict" else "Compare this device and the exact cloud copy. No newer-device ranking is used. Restore locally or separately confirm a whole backup replacement."
		changed.emit(); return
	if op == "write" and status=="submitted" and str(body.get("player",""))==player:
		var sent := Backup.encode(local_code)
		if str(body.get("sha256","")) != sent.get("sha256",""): _fail("Backup submission identity was not confirmed. Check cloud again."); return
		phase = "submitted"; _action = ""; choices.clear(); _expected = ""
		message = "Whole backup submitted to Play Games; it may be cached offline. Server durability and cross-device sync are not confirmed. Local progress is unchanged."; changed.emit(); return
	_fail("Cloud operation is unconfirmed ("+status+" ). Local progress is unchanged. A submitted backup may have reached Play Games; check again before another choice.")

func retry_cleanup() -> void:
	if phase != "cleanup_required": return
	_cleanup()

func _fail(text: String) -> void:
	phase = "error"; message = text; _action = ""; choices.clear(); _expected=""
	_after_cleanup="error"; _cleanup()

func unchanged() -> bool:
	return str(capture.call())==local_code and disk_identity()==_disk

func disk_identity() -> Dictionary:
	var value := {}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = Store.PATH+str(slot)+str(suffix)
			value[path] = io.read_text(path) if io.exists(path) else null
	return value

func preserve() -> bool:
	var codes: Array[String] = [local_code]
	for text in _disk.values():
		if text is String and Store.decode(text).ok and text not in codes: codes.append(text)
	for choice in choices:
		if choice.save not in codes: codes.append(choice.save)
	if not _restore_code.is_empty() and _restore_code not in codes: codes.append(_restore_code)
	preserved_ids.clear()
	for code in codes:
		var kept := copies.keep(code)
		if not kept.ok: return false
		preserved_ids.append(kept.id)
	return true

func dispose() -> void:
	restore=Callable(); capture=Callable()
	_pending=""; _operation=""
	if port.completed.is_connected(_receive): port.completed.disconnect(_receive)
	port.abandon()

static func describe(decoded: Dictionary) -> String:
	var state: Dictionary = decoded.state
	var title := "Legacy siege" if state.catalog==1 else str(state.definition.title)
	return "%s / %s\n%d districts / %d campaign wins / %d legacy wins / %d scrap" % [title,state.phase,decoded.career.clears.size(),decoded.career.victories,decoded.profile.wins,state.wallet]

func _handoff() -> void:
	phase="handoff"
	if not restore.is_valid() or restore.call(_restore_code)!=true:
		_fail("Local Import could not begin. No local restore was adopted; play stays paused.")
