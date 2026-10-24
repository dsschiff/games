extends RefCounted
var files := {}
var fail_write := false
var fail_rename := false
var corrupt_readback := false
var unreadable_after := 0
var destination_prefix := "user://dead-run-save-"
var destination_reads := 0
var promoted := ""
var destination_mode := ""
var stale_code := ""

func exists(path: String) -> bool:
	return files.has(path)

func read_text(path: String) -> String:
	if path==promoted and unreadable_after>0:
		destination_reads+=1
		if destination_reads>=unreadable_after: return "unreadable"
	return "broken" if corrupt_readback and path.ends_with(".tmp") else str(files.get(path, ""))

func write_text(path: String, text: String) -> bool:
	files[path] = text.substr(0, 13) if fail_write else text
	return not fail_write

func rename(from: String, to: String) -> bool:
	if fail_rename:
		return false
	files[to] = files[from]
	files.erase(from)
	if to==destination_prefix+"0" or to==destination_prefix+"1":
		promoted=to; destination_reads=0
		if destination_mode=="missing": files.erase(to)
		elif destination_mode=="corrupt": files[to]="torn"
		elif destination_mode=="stale": files[to]=stale_code
	return true

func remove(path: String) -> bool:
	files.erase(path); return true
