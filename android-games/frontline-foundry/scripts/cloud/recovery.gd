extends Node
## Unconnected Frontline recovery scaffold; no auto-merge, rank, upload or resolve.
const Store = preload("res://scripts/save_store.gd")
const Backup = preload("res://scripts/cloud/backup.gd")
const Copies = preload("res://scripts/cloud/copies.gd")
const Files = preload("res://scripts/save_files.gd")
const Port = preload("res://scripts/cloud/port.gd")
signal changed
signal restore_committed(decoded: Dictionary)
enum Phase { CLOSED, NOT_CONFIGURED, SIGNED_OUT, AUTHENTICATING, READY, READING, CHOOSE, CONFIRM, VERIFYING, RESTORED, ERROR, CANCELLING, RECOVERY_REQUIRED }
var phase: Phase = Phase.CLOSED
var message := "Optional cloud recovery is not configured for this build. Local saves work offline."
var port: Port
var copies: Copies
var local_source: Callable
var storage: RefCounted
var store_path := Store.PATH
var player := ""
var preserved_ids: Array[String] = []
var _local := {}
var _disk := {}
var _disk_bytes := {}
var _hold: Callable
var _release: Callable
var _held := false
var _adopt: Callable
var _committed := {}
var _verified_write := false
var _local_text := ""
var _choices: Array[Dictionary] = []
var _selected := -1
var _serial := 0
var _pending := ""
var _operation := ""
var _cancelled := false
var _conflict := ""
var _conflict_player := ""
var _after_close: Phase = Phase.CLOSED

func setup(source: Callable, backend: RefCounted = null, transport: Port = null, path: String = Store.PATH, hold: Callable = Callable(), release: Callable = Callable(), adopt: Callable = Callable()) -> bool:
	if port != null: return false
	local_source = source; storage = backend; store_path = path
	_hold = hold; _release = release; _adopt = adopt
	port = transport if transport != null else Port.new()
	copies = Copies.new(backend)
	port.completed.connect(_receive)
	return true

func open() -> bool:
	if port == null: return _fail("Local recovery owner is not configured. This device remains offline.")
	if not _pending.is_empty() or not _conflict.is_empty() or _held: return false
	_cancelled = false; _selected = -1; _choices.clear(); player = ""
	if port.is_configured():
		if not _adopt.is_valid() or not _hold.is_valid() or not _release.is_valid() or _hold.call() != true: return _fail("Pause play and local save actions before checking cloud recovery.")
		_held = true
	var current := _current()
	var disk := Store.read(store_path,storage)
	if not current.ok or not disk.ok: return _fail("Pause and save this device before checking cloud recovery.")
	_local = current.decoded.duplicate(true); _local_text = current.text; _disk = disk.duplicate(true); _disk_bytes = _disk_identity()
	phase = Phase.SIGNED_OUT if port.is_configured() else Phase.NOT_CONFIGURED
	message = "Connect only if you want to check this account's cloud saves." if port.is_configured() else "Optional cloud recovery is not configured for this build. Local saves work offline."
	changed.emit(); return true

func connect_account() -> bool:
	if phase != Phase.SIGNED_OUT or not port.is_configured(): return false
	phase = Phase.AUTHENTICATING; message = "Connecting..."; _send("sign_in",{}); return true

func check_backup() -> bool:
	if phase != Phase.READY or player.is_empty(): return false
	phase = Phase.READING; message = "Checking cloud saves..."
	_send("read",{"slot":"frontline-foundry-v1","player":player}); return true

func stage_restore(index: int) -> bool:
	if phase != Phase.CHOOSE or index < 0 or index >= _choices.size(): return false
	_selected = index; phase = Phase.CONFIRM
	message = "Restore this whole save on this device? Complete copies of this device and the cloud choices shown will be kept. Cloud saves will not be changed."
	changed.emit(); return true

func confirm_restore() -> bool:
	if phase != Phase.CONFIRM or _selected < 0: return false
	phase = Phase.VERIFYING; message = "Confirming the account and local save..."
	_send("status",{}); return true

func keep_this_device() -> void:
	cancel()

func cancel() -> void:
	if not _committed.is_empty(): return
	_cancelled = true; _selected = -1; _choices.clear()
	_release_owner()
	phase = Phase.CANCELLING if not _pending.is_empty() else Phase.CLOSED
	message = "This device's save was kept."
	if _pending.is_empty(): _close_handles(Phase.CLOSED)
	changed.emit()

func summaries() -> Dictionary:
	var remote: Array[Dictionary] = []
	for choice in _choices:
		remote.append({"summary":summary(choice.decoded),"id":choice.save.sha256_text(),"code":choice.save})
	return {"local":{"summary":summary(_local),"id":_local_text.sha256_text(),"code":_local_text} if not _local.is_empty() else {},"cloud":remote.duplicate(true),"status":message,"phase":phase}

static func summary(decoded: Dictionary) -> String:
	var state: Dictionary = decoded.state
	var career: Dictionary = decoded.career
	var title := "Legacy siege" if state.catalog == 1 else str(state.definition.title)
	return "%s | %s | %d districts | %d campaign wins | %d scrap" % [title,str(state.phase),career.clears.size(),int(career.victories),int(state.wallet)]

func _current() -> Dictionary:
	if not local_source.is_valid(): return {"ok":false}
	var current: Variant = local_source.call()
	if not current is Dictionary or current.get("paused") != true or not current.get("text") is String: return {"ok":false}
	var decoded := Store.decode(current.text)
	return {"ok":true,"decoded":decoded,"text":current.text} if decoded.ok else {"ok":false}

static func same_values(a: Dictionary,b: Dictionary) -> bool:
	return a.get("state")==b.get("state") and a.get("profile")==b.get("profile") and a.get("settings")==b.get("settings") and a.get("career")==b.get("career")

func _send(operation: String,args: Dictionary) -> void:
	_serial += 1; _pending = "frontline-recovery-"+str(get_instance_id())+"-"+str(_serial); _operation = operation
	changed.emit(); port.request(_pending,operation,args.duplicate(true))

func _receive(id: String,body: Dictionary) -> void:
	if id != _pending or _pending.is_empty(): return
	var operation := _operation
	_pending = ""; _operation = ""
	var status := str(body.get("status",""))
	if operation == "discard_conflict":
		if status == "discarded": _conflict = ""; _conflict_player = ""; phase = _after_close
		else:
			phase = Phase.ERROR if _committed.is_empty() else Phase.RECOVERY_REQUIRED
			message = "Cloud cleanup could not be confirmed. Local recovery must finish before play resumes." if not _committed.is_empty() else "Cloud cleanup could not be confirmed. This device's save is retained."
		changed.emit(); return
	if operation == "read" and status == "conflict":
		_conflict = str(body.get("conflict",""))
		if _conflict.is_empty(): _conflict = "#invalid"
		var returned_player := str(body.get("player",""))
		_conflict_player = returned_player if not returned_player.is_empty() and returned_player.length()<=128 else player
	if _cancelled:
		_close_handles(Phase.CLOSED); return
	if operation == "sign_in":
		if status != "authenticated": _fail("Connection unavailable. This device's save was kept."); return
		_send("status",{}); return
	if operation == "status":
		var owner := str(body.get("player",""))
		if status != "authenticated" or owner.is_empty() or owner.length()>128: _fail("Account unavailable. This device's save was kept."); return
		if phase == Phase.VERIFYING:
			if owner != player: _fail("The account changed. Check cloud saves again before restoring."); return
			_commit_selected(); return
		player = owner; phase = Phase.READY; message = "Connected. Check cloud saves to compare complete saves."; changed.emit(); return
	if operation != "read" or str(body.get("player","")) != player: _fail("The account changed. This device's save was kept."); return
	if status == "conflict":
		if not body.get("conflict") is String or body.conflict.is_empty() or body.conflict.length()>512: _fail("Invalid cloud response. This device's save was kept."); return
		for key in ["first","second"]:
			if not body.get(key) is Dictionary: _fail("Invalid cloud save. This device's save was kept."); return
			var candidate := Backup.snapshot(body[key])
			if not candidate.ok: _fail("Invalid cloud save. This device's save was kept."); return
			_choices.append(candidate)
	elif status == "loaded" and body.get("snapshot") is Dictionary:
		var candidate := Backup.snapshot(body.snapshot)
		if not candidate.ok: _fail("Invalid cloud save. This device's save was kept."); return
		_choices.append(candidate)
	else: _fail("Cloud save unavailable. This device's save was kept."); return
	phase = Phase.CHOOSE; message = "Compare whole saves. Choose one to restore locally, or keep this device. Cloud saves will not be changed."; changed.emit()

func _commit_selected() -> void:
	var current := _current()
	var disk := Store.read(store_path,storage)
	if not _held or not current.ok or not disk.ok or not same_values(current.decoded,_local) or not same_values(disk,_disk) or _disk_identity() != _disk_bytes: _fail("This device's save changed. Compare again before restoring."); return
	var codes: Array[String] = [_local_text]
	# Keep exact disk bytes as well as a possibly unsaved/re-encoded live context.
	for code in _disk_bytes.values():
		if code is String and Store.decode(code).ok and code not in codes: codes.append(code)
	for choice in _choices:
		if choice.save not in codes: codes.append(choice.save)
	preserved_ids.clear()
	for text in codes:
		var kept := copies.keep(text)
		if not kept.ok: _fail("Storage failed while keeping complete copies. This device's save was kept."); return
		preserved_ids.append(kept.id)
	var selected: Dictionary = _choices[_selected].decoded
	_committed = selected.duplicate(true); _verified_write = false
	# False can follow a successful rename whose readback was transiently unavailable.
	# Keep old live state frozen until a later verified write or verified recovery.
	if not Store.write(selected.state,selected.profile,selected.settings,store_path,storage,true,selected.career):
		_block("The local restore write is unconfirmed. Play and local save actions stay paused. Retry local recovery."); return
	_verified_write = true
	_finish_adoption()

func retry_adoption() -> bool:
	if phase != Phase.RECOVERY_REQUIRED or not _held or _committed.is_empty() or not _pending.is_empty(): return false
	return _finish_adoption()

func _finish_adoption() -> bool:
	if not _verified_write:
		if not Store.write(_committed.state,_committed.profile,_committed.settings,store_path,storage,true,_committed.career): return _block("The local restore write is still unconfirmed. Play and local save actions stay paused. Retry local recovery.")
		_verified_write = true
	var confirmed := Store.read(store_path,storage)
	if not confirmed.ok or not same_values(confirmed,_committed): return _block("A local restore was written but its readback is uncertain. Play and local save actions stay paused. Retry local recovery.")
	var adopted: Variant = _adopt.call(_committed.duplicate(true))
	var current := _current()
	if not adopted is Dictionary or not same_values(adopted,_committed) or not current.ok or not same_values(current.decoded,_committed): return _block("A local restore was written but live adoption is incomplete. Play and local save actions stay paused. Retry local recovery.")
	var result := _committed.duplicate(true)
	_committed.clear(); _choices.clear(); _selected = -1
	phase = Phase.RESTORED; message = "Restore committed on this device. Resume when ready. Cloud saves were not changed."
	_release_owner()
	_close_handles(Phase.RESTORED)
	restore_committed.emit(result)
	return true

func _block(text: String) -> bool:
	phase = Phase.RECOVERY_REQUIRED; message = text; _choices.clear(); _selected = -1
	_close_handles(Phase.RECOVERY_REQUIRED)
	return false

func _close_handles(after: Phase) -> void:
	_after_close = after
	if not _conflict.is_empty(): _send("discard_conflict",{"player":_conflict_player})
	else: phase = after; changed.emit()

func _fail(text: String) -> bool:
	phase = Phase.ERROR; message = text; _selected = -1; _choices.clear()
	_release_owner()
	_close_handles(Phase.ERROR); return false

func _release_owner() -> void:
	if _held:
		_held = false
		_release.call()

func _disk_identity() -> Dictionary:
	var io: RefCounted = storage if storage != null else Files.new()
	var result := {}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = store_path+str(slot)+str(suffix)
			result[path] = io.read_text(path) if io.exists(path) else null
	return result

func _exit_tree() -> void:
	_cancelled = true; _pending = ""; _operation = ""
	if _committed.is_empty(): _release_owner()
	if port != null:
		if port.completed.is_connected(_receive): port.completed.disconnect(_receive)
		port.abandon()
