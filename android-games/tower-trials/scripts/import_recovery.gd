extends RefCounted
## Whole Tower data transaction; no game rules, cloud or save-schema changes.
const Store = preload("res://scripts/save_store.gd")
const Files = preload("res://scripts/save_files.gd")
const Copies = preload("res://scripts/recovery_copies.gd")
const PATH := "user://tower-import-pending"
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
func _init(backend: RefCounted=null,journal_path: String=PATH,active_path: String=Store.PATH) -> void:
	io=backend if backend!=null else Files.new(); copies=Copies.new(io); path=journal_path; save_path=active_path
static func path_for(active_path: String) -> String: return PATH if active_path==Store.PATH else active_path+".import-pending"
func read() -> Dictionary:
	journal_ready=false; var present:=false
	for suffix in ["", ".tmp"]:
		var file: String=path+str(suffix)
		if not io.exists(file): continue
		present=true; var parsed:=decode(io.read_text(file))
		if not parsed.ok: continue
		var a:=copies.get_code(parsed.record.original); var b:=copies.get_code(parsed.record.incoming)
		if not a.ok or not b.ok: continue
		record=parsed.record.duplicate(true); original_code=a.text; incoming_code=b.text
		original=Store.decode(a.text); incoming=Store.decode(b.text); journal_ready=suffix.is_empty()
		message="Play and saving are paused. Choose which complete save to keep."
		return {"pending":true,"ok":true,"original":original.duplicate(true),"incoming":incoming.duplicate(true)}
	if present: message="We cannot read your saved choices. Play and saving stay paused. Retry reading. Keep this app installed to retain its local copies."
	return {"pending":present,"ok":false}
func begin(live_code: String,intake: String) -> Dictionary:
	if read().pending: return {"pending":true,"ok":false}
	original=Store.decode(live_code); incoming=Store.decode(intake); original_code=live_code; incoming_code=intake
	if not original.ok or not incoming.ok: return {"pending":false,"ok":false}
	var codes: Array[String]=[live_code]
	if intake not in codes: codes.append(intake)
	for suffix in [".tmp", "", ".bak", ".bak.tmp"]:
		var file: String=save_path+str(suffix)
		if not io.exists(file): continue
		var text: String=io.read_text(file)
		if Store.decode(text).ok and text not in codes: codes.append(text)
	var ids: Array[String]=[]
	for text in codes:
		var kept:=copies.keep(text)
		if not kept.ok:
			message="Storage failed before Import. Your current route is unchanged."
			return {"pending":false,"ok":false}
		ids.append(kept.id)
	record={"version":1,"original":live_code.sha256_text(),"incoming":intake.sha256_text(),"copies":ids}
	journal_ready=persist()
	if not journal_ready: message="We could not confirm the saved choices. Play and saving stay paused. Retry Import or keep your previous complete save."
	return {"pending":true,"ok":journal_ready}
func resolve(use_import: bool) -> Dictionary:
	if record.is_empty() and not read().ok: return {"ok":false}
	journal_ready=persist()
	if not journal_ready: message="We could not confirm your saved choices. Play and saving stay paused. Retry when storage is available."; return {"ok":false}
	for id in record.copies:
		if not copies.get_code(id).ok:
			message="A retained save cannot be read. Play and saving stay paused. Retry reading when storage is available."; return {"ok":false}
	var chosen: Dictionary=incoming if use_import else original
	if not Store.write(chosen.data,save_path,io,false):
		message="We could not confirm the chosen save. Play and saving stay paused. Retry your choice."; return {"ok":false}
	var checked:=Store.read(save_path,io)
	if not same(checked,chosen): message="We could not read back the chosen save. Play and saving stay paused. Retry your choice."; return {"ok":false}
	if not clear():
		journal_ready=false; message="The chosen save was checked, but recovery is not finished. Play stays paused. Retry your choice."; return {"ok":false}
	return {"ok":true,"decoded":checked}
func persist() -> bool:
	var payload:=JSON.stringify(record); var text:=JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}); var intended:=decode(text)
	if not intended.ok: return false
	var present:=false
	# Cleanup can expose either artifact; every existing record must agree.
	for suffix in ["", ".tmp"]:
		var file: String=path+str(suffix)
		if not io.exists(file): continue
		present=true; var saved:=decode(io.read_text(file))
		if not saved.ok or saved.record!=intended.record: return false
	if present: return true
	if not io.write_text(path+".tmp",text) or io.read_text(path+".tmp")!=text: return false
	if not io.rename(path+".tmp",path) or not io.exists(path): return false
	var checked: String=io.read_text(path)
	return checked==text and decode(checked).ok
func clear() -> bool:
	for suffix in ["", ".tmp"]:
		var file: String=path+str(suffix)
		if io.exists(file) and not io.remove(file): return false
	var absent: bool=not io.exists(path) and not io.exists(path+".tmp")
	if absent: journal_ready=false
	return absent
static func meaning(data: Dictionary) -> Dictionary:
	var result:=data.duplicate(true); result.erase("revision"); result.erase("recoverable"); return result
static func same(a: Dictionary,b: Dictionary) -> bool:
	return a.get("ok")==true and b.get("ok")==true and meaning(a.data)==meaning(b.data) and a.state==b.state
static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size()>LIMIT: return {"ok":false}
	var parser:=JSON.new()
	if parser.parse(text)!=OK or not parser.data is Dictionary: return {"ok":false}
	var envelope: Dictionary=parser.data
	if not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text()!=envelope.sha256: return {"ok":false}
	if parser.parse(envelope.payload)!=OK or not parser.data is Dictionary: return {"ok":false}
	var value: Dictionary=parser.data
	if value.get("version")!=1 or not value.get("copies") is Array or value.copies.is_empty() or value.copies.size()>6: return {"ok":false}
	for id in value.copies:
		if not id is String or id.length()!=64 or not id.is_valid_hex_number(false): return {"ok":false}
	if not value.get("original") in value.copies or not value.get("incoming") in value.copies: return {"ok":false}
	return {"ok":true,"record":value}
static func describe(value: Dictionary) -> String:
	var data: Dictionary=value.data
	var campaign: Dictionary=Store.Content.by_id(data.level_id,int(data.catalog))
	var text: String="Campaign: %s · %d steps · %d watches cleared" % [campaign.name,data.actions.size(),data.profile.size()]
	if not data.challenge_run.is_empty():
		var run: Dictionary=data.challenge_run
		text+="\nChallenge: %s · seed %d · %d steps%s" % [run.bundle.family,run.bundle.seed,run.actions.size()," · active" if data.kind=="challenge" else " · parked"]
	text+="\n%d challenge records. Route, Undo history, medals and settings move together." % data.challenge_records.size()
	return text
