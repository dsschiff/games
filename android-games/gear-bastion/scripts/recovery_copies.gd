extends RefCounted
## Exact complete save codes, retained outside the rotating active candidates.
const Store = preload("res://scripts/save_store.gd")
const Files = preload("res://scripts/save_files.gd")
const PREFIX := "user://gear-recovery-copy-"
var io: RefCounted
func _init(backend: RefCounted=null) -> void:
	io=backend if backend!=null else Files.new()
func keep(text: String) -> Dictionary:
	if not Store.decode(text).ok: return {"ok":false}
	var id:=text.sha256_text(); var path:=PREFIX+id
	if io.exists(path): return {"ok":io.read_text(path)==text,"id":id}
	if not io.write_text(path+".tmp",text) or io.read_text(path+".tmp")!=text: return {"ok":false}
	if not io.rename(path+".tmp",path) or not io.exists(path): return {"ok":false}
	var checked: String=io.read_text(path)
	return {"ok":checked==text and Store.decode(checked).ok,"id":id}
func get_code(id: String) -> Dictionary:
	if id.length()!=64 or not id.is_valid_hex_number(false): return {"ok":false}
	var path:=PREFIX+id
	if not io.exists(path): return {"ok":false}
	var text: String=io.read_text(path)
	return {"ok":true,"text":text} if text.sha256_text()==id and Store.decode(text).ok else {"ok":false}
