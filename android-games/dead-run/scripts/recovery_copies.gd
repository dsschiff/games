extends RefCounted
## Exact whole rescue codes outside the alternating active slots.
const Store=preload("res://scripts/campaign_store.gd")
const Files=preload("res://scripts/save_files.gd")
const PREFIX:="user://dead-run-recovery-copy-"
var io: RefCounted
func _init(backend: RefCounted=null) -> void: io=backend if backend!=null else Files.new()
func keep(code: String) -> Dictionary:
	if not Store.decode(code).ok: return {"ok":false}
	var id:=code.sha256_text(); var path:=PREFIX+id
	if io.exists(path): return {"ok":io.read_text(path)==code,"id":id}
	if not io.write_text(path+".tmp",code) or io.read_text(path+".tmp")!=code: return {"ok":false}
	if not io.rename(path+".tmp",path) or not io.exists(path): return {"ok":false}
	var checked: String=io.read_text(path)
	return {"ok":checked==code and Store.decode(checked).ok,"id":id}
func get_code(id: String) -> Dictionary:
	if id.length()!=64 or not id.is_valid_hex_number(false) or not io.exists(PREFIX+id): return {"ok":false}
	var code: String=io.read_text(PREFIX+id)
	return {"ok":true,"text":code} if code.sha256_text()==id and Store.decode(code).ok else {"ok":false}
