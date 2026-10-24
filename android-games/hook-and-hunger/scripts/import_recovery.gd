extends RefCounted
## Local import transaction. No transport, auth or cloud operations.
const Store = preload("res://scripts/save_store.gd")
const Files = preload("res://scripts/save_files.gd")
const Copies = preload("res://scripts/recovery_copies.gd")
const PATH := "user://hook-import-pending"
const LIMIT := 8192
var io: RefCounted
var copies: Copies
var path: String
var save_path: String
var record := {}
var original := {}
var incoming := {}
var original_code := ""
var incoming_code := ""
var journal_ready := false
var message := ""

func _init(backend: RefCounted = null, journal_path: String = PATH, active_path: String = Store.PATH) -> void:
	io = backend if backend != null else Files.new()
	copies = Copies.new(io); path = journal_path; save_path = active_path

func read() -> Dictionary:
	journal_ready = false
	var present := false
	for suffix in ["", ".tmp"]:
		var file: String = path + str(suffix)
		if not io.exists(file): continue
		present = true
		var parsed := decode(io.read_text(file))
		if not parsed.ok: continue
		var a := copies.get_code(parsed.record.original)
		var b := copies.get_code(parsed.record.incoming)
		if not a.ok or not b.ok: continue
		record = parsed.record.duplicate(true)
		original = Store.decode(a.text); incoming = Store.decode(b.text); original_code = a.text; incoming_code = b.text
		journal_ready = suffix.is_empty()
		message = "Import recovery is pending. Choose which complete save to use."
		return {"pending":true,"ok":true,"original":original.duplicate(true),"incoming":incoming.duplicate(true)}
	if present: message = "Import recovery cannot be read. Play and local saves stay paused. Retry reading recovery."
	return {"pending":present,"ok":false}

func begin(live_code: String, import_code: String) -> Dictionary:
	if read().pending: return {"pending":true,"ok":false}
	original = Store.decode(live_code); incoming = Store.decode(import_code); original_code = live_code; incoming_code = import_code
	if not original.ok or not incoming.ok: return {"pending":false,"ok":false}
	var codes: Array[String] = [live_code,import_code]
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var file: String = save_path + str(slot) + str(suffix)
			if not io.exists(file): continue
			var code: String = io.read_text(file)
			if Store.decode(code).ok and code not in codes: codes.append(code)
	var ids: Array[String] = []
	for code in codes:
		var kept := copies.keep(code)
		if not kept.ok:
			message = "Storage failed before import. The current save is unchanged."
			return {"pending":false,"ok":false}
		ids.append(kept.id)
	record = {"version":1,"original":live_code.sha256_text(),"incoming":import_code.sha256_text(),"copies":ids}
	journal_ready = persist()
	if not journal_ready:
		message = "Import recovery is not confirmed. Play and local saves stay paused. Retry import or keep the previous save."
	return {"pending":true,"ok":journal_ready}

func resolve(use_import: bool) -> Dictionary:
	if record.is_empty():
		if not read().ok: return {"ok":false}
	journal_ready = persist()
	if not journal_ready:
		message = "Recovery storage is unconfirmed. Play and local saves stay paused."
		return {"ok":false}
	for id in record.copies:
		if not copies.get_code(id).ok:
			message = "A complete recovery copy cannot be verified. Play and local saves stay paused. Retry reading recovery."
			return {"ok":false}
	var chosen: Dictionary = incoming if use_import else original
	if not Store.write(chosen.state,chosen.settings,save_path,io,true,chosen.profile):
		message = "The save write is unconfirmed. Play and local saves stay paused. Retry your choice."
		return {"ok":false}
	var checked := Store.read(save_path,io)
	if not checked.ok or not same_values(checked,chosen):
		message = "The save readback is unconfirmed. Play and local saves stay paused. Retry your choice."
		return {"ok":false}
	if not clear():
		journal_ready = false
		message = "The chosen save was verified; recovery cleanup is unconfirmed. Play stays paused. Retry your choice."
		return {"ok":false}
	message = "Imported save verified." if use_import else "Previous whole save restored and verified."
	return {"ok":true,"decoded":checked.duplicate(true)}

func persist() -> bool:
	var payload := JSON.stringify(record)
	var text := JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})
	var intended := decode(text)
	if not intended.ok: return false
	# Cleanup may expose either artifact, so every existing marker must agree.
	var present := false
	for suffix in ["", ".tmp"]:
		var file: String = path + str(suffix)
		if not io.exists(file): continue
		present = true
		var saved := decode(io.read_text(file))
		if not saved.ok or saved.record!=intended.record: return false
	if present: return true
	if not io.write_text(path+".tmp",text) or io.read_text(path+".tmp")!=text: return false
	if not io.rename(path+".tmp",path) or not io.exists(path): return false
	var confirmed: String = io.read_text(path)
	return confirmed==text and decode(confirmed).ok

func clear() -> bool:
	for suffix in ["", ".tmp"]:
		var file: String = path + str(suffix)
		if io.exists(file) and (not io.has_method("remove") or not io.remove(file)): return false
	var cleared: bool = not io.exists(path) and not io.exists(path+".tmp")
	if cleared: journal_ready = false
	return cleared

static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size()>LIMIT: return {"ok":false}
	var json := JSON.new()
	if json.parse(text)!=OK or not json.data is Dictionary: return {"ok":false}
	var envelope: Dictionary = json.data
	if not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text()!=envelope.sha256: return {"ok":false}
	if json.parse(envelope.payload)!=OK or not json.data is Dictionary: return {"ok":false}
	var value: Dictionary = json.data
	if value.get("version")!=1 or not value.get("copies") is Array or value.copies.is_empty() or value.copies.size()>6: return {"ok":false}
	for id in value.copies:
		if not id is String or id.length()!=64 or not id.is_valid_hex_number(false): return {"ok":false}
	if not value.get("original") in value.copies or not value.get("incoming") in value.copies: return {"ok":false}
	return {"ok":true,"record":value}

static func same_values(a: Dictionary,b: Dictionary) -> bool:
	return a.get("state")==b.get("state") and a.get("profile")==b.get("profile") and a.get("settings")==b.get("settings")

static func describe(context: Dictionary) -> String:
	if context.is_empty(): return "Unavailable"
	var title: String = "Saltglass legacy" if context.state.schema==1 else str(context.state.definition.title)
	return "%s / %s / %d passages / %d salvage" % [title,context.state.phase,context.profile.clears.size(),context.state.wallet]

func active_present() -> bool:
	for slot in 2:
		for suffix in ["", ".tmp"]:
			if io.exists(save_path+str(slot)+str(suffix)): return true
	return false
