extends RefCounted
## Dead Run local Import transaction; both bodies, bullets and pinned definitions preserved.
const Store = preload("res://scripts/campaign_store.gd")
const Old = preload("res://scripts/save_store.gd")
const Files = preload("res://scripts/save_files.gd")
const Copies = preload("res://scripts/recovery_copies.gd")
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
var legacy_only := false
func _init(backend: RefCounted=null,old_format: bool=false,active_path: String=Store.PATH) -> void:
	io=backend if backend!=null else Files.new(); copies=Copies.new(io)
	save_path=active_path; path=active_path+"import-pending"; legacy_only=old_format
func read() -> Dictionary:
	journal_ready=false
	var present:=false
	for suffix in ["", ".tmp"]:
		var file: String=path+str(suffix)
		if not io.exists(file): continue
		present=true
		var parsed:=decode(io.read_text(file))
		if not parsed.ok or (legacy_only and parsed.record.format!="legacy"): continue
		var a:=copies.get_code(parsed.record.original); var b:=copies.get_code(parsed.record.incoming)
		if not a.ok or not b.ok: continue
		record=parsed.record.duplicate(true); original_code=a.text; incoming_code=b.text
		original=Store.decode(original_code); incoming=Store.decode(incoming_code); journal_ready=suffix.is_empty()
		message="Import recovery is pending. Choose which whole save to use."
		return {"pending":true,"ok":true,"original":original.duplicate(true),"incoming":incoming.duplicate(true)}
	if present: message="Recovery cannot be read. Play and local saves stay paused. Retry reading recovery. Keep the app installed to retain its local copies."
	return {"pending":present,"ok":false}
func begin(live_code: String,import_code: String,intake_code: String="") -> Dictionary:
	if read().pending: return {"pending":true,"ok":false}
	original=Store.decode(live_code); incoming=Store.decode(import_code)
	if not original.ok or not incoming.ok or (legacy_only and (not Old.decode(live_code).ok or not Old.decode(import_code).ok)): return {"pending":false,"ok":false}
	original_code=live_code; incoming_code=import_code
	var codes: Array[String]=[live_code,import_code]
	if not intake_code.is_empty() and intake_code not in codes: codes.append(intake_code)
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var file: String=save_path+str(slot)+str(suffix)
			if not io.exists(file): continue
			var text: String=io.read_text(file)
			if Store.decode(text).ok and text not in codes: codes.append(text)
	var ids: Array[String]=[]
	for code in codes:
		var kept:=copies.keep(code)
		if not kept.ok:
			message="Storage failed before Import. The complete current game is unchanged."
			return {"pending":false,"ok":false}
		ids.append(kept.id)
	record={"version":1,"format":"legacy" if legacy_only else "journey","original":live_code.sha256_text(),"incoming":import_code.sha256_text(),"copies":ids}
	journal_ready=persist()
	if not journal_ready: message="Import recovery storage is unconfirmed. Play and local saves stay paused. Retry Import or keep the previous whole save."
	return {"pending":true,"ok":journal_ready}
func resolve(use_import: bool) -> Dictionary:
	if record.is_empty():
		if not read().ok: return {"ok":false}
	journal_ready=persist()
	if not journal_ready: message="Recovery storage is unconfirmed. Play and local saves stay paused."; return {"ok":false}
	var chosen: Dictionary=incoming if use_import else original
	for id in record.copies:
		if not copies.get_code(id).ok:
			message="A complete recovery copy cannot be verified. Play and saves stay paused. Retry reading recovery."; return {"ok":false}
	var written: bool=Old.write(chosen.context.legacy,chosen.context.settings,save_path,io,true) if record.format=="legacy" else Store.write(chosen.context,save_path,io,true)
	if not written:
		message="The chosen save write is unconfirmed. Play and local saves stay paused. Retry your choice."
		return {"ok":false}
	var checked:=Store.read(save_path,io)
	if not same(checked,chosen):
		message="The chosen save readback is unconfirmed. Play and local saves stay paused. Retry your choice."
		return {"ok":false}
	if not clear():
		journal_ready=false; message="The chosen whole save was verified, but recovery cleanup is unconfirmed. Play stays paused. Retry your choice."
		return {"ok":false}
	return {"ok":true,"decoded":checked}
func persist() -> bool:
	var payload:=JSON.stringify(record); var text:=JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})
	var intended:=decode(text)
	if not intended.ok: return false
	# Cleanup may expose either artifact, so every existing marker must agree.
	var present:=false
	for suffix in ["", ".tmp"]:
		var file: String=path+str(suffix)
		if not io.exists(file): continue
		present=true
		var saved:=decode(io.read_text(file))
		if not saved.ok or saved.record!=intended.record: return false
	if present: return true
	if not io.write_text(path+".tmp",text) or io.read_text(path+".tmp")!=text: return false
	if not io.rename(path+".tmp",path) or not io.exists(path): return false
	var checked: String=io.read_text(path)
	return checked==text and decode(checked).ok
func clear() -> bool:
	for suffix in ["", ".tmp"]:
		var file: String=path+str(suffix)
		if io.exists(file) and (not io.has_method("remove") or not io.remove(file)): return false
	var cleared: bool=not io.exists(path) and not io.exists(path+".tmp")
	if cleared: journal_ready=false
	return cleared
static func same(a: Dictionary,b: Dictionary) -> bool:
	return a.get("ok")==true and b.get("ok")==true and a.context==b.context
static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size()>LIMIT: return {"ok":false}
	var json:=JSON.new()
	if json.parse(text)!=OK or not json.data is Dictionary: return {"ok":false}
	var envelope: Dictionary=json.data
	if not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text()!=envelope.sha256: return {"ok":false}
	if json.parse(envelope.payload)!=OK or not json.data is Dictionary: return {"ok":false}
	var value: Dictionary=json.data
	if value.get("version")!=1 or value.get("format") not in ["journey","legacy"] or not value.get("copies") is Array or value.copies.is_empty() or value.copies.size()>7: return {"ok":false}
	for id in value.copies:
		if not id is String or id.length()!=64 or not id.is_valid_hex_number(false): return {"ok":false}
	if not value.get("original") in value.copies or not value.get("incoming") in value.copies: return {"ok":false}
	return {"ok":true,"record":value}
static func describe(value: Dictionary) -> String:
	var ctx: Dictionary=value.context
	var active: Dictionary=ctx.legacy if ctx.mode=="legacy" else ctx.campaign
	var title: String="Legacy canal bridge" if ctx.mode=="legacy" else "Road %02d / %s" % [ctx.campaign.definition.index+1,ctx.campaign.definition.title]
	return "%s / %s / tick %d / crew %d\n%d roads restored / %d replay records / loadout %s\nCampaign and legacy bullets: %d / %d" % [title,active.phase,active.tick,active.crew,ctx.profile.clears.size(),ctx.profile.replays.size(),ctx.loadout,ctx.campaign.bullets.size(),ctx.legacy.bullets.size()]
