extends RefCounted
## Fault-injection backend only; normal app-save tests use the real filesystem.
var files: Dictionary = {}
var times: Dictionary = {}
var fail_suffix := ""
var fail_mode := ""
var write_count := 0
var rename_count := 0
var bad_destination_suffix := ""
var bad_destination_mode := ""
var unreadable_destination_suffix := ""
var unreadable_after := 0
var promoted := ""
var destination_reads := 0
var stale_destination := ""

func exists(path: String) -> bool:
	return files.has(path)

func read_text(path: String) -> String:
	if path==promoted and unreadable_after>0:
		destination_reads+=1
		if destination_reads>=unreadable_after: return "unreadable"
	return str(files.get(path, ""))

func modified(path: String) -> int:
	return int(times.get(path, 0))

func write_text(path: String, source: String) -> bool:
	write_count += 1
	if fail_suffix != "" and path.ends_with(fail_suffix):
		if fail_mode == "write":
			files[path] = source.left(10)
			return false
		if fail_mode == "flush":
			files[path] = source
			return false
		if fail_mode == "readback":
			files[path] = source.left(10)
			return true
	files[path] = source
	times[path] = write_count
	return true

func rename(from: String, to: String) -> bool:
	rename_count += 1
	if fail_mode == "rename" and from.ends_with(fail_suffix):
		return false
	files[to] = files[from]
	times[to] = times.get(from, write_count)
	files.erase(from)
	times.erase(from)
	if not bad_destination_suffix.is_empty() and to.ends_with(bad_destination_suffix):
		if bad_destination_mode=="missing": files.erase(to); times.erase(to)
		elif bad_destination_mode=="corrupt": files[to]="torn destination"
		elif bad_destination_mode=="stale": files[to]=stale_destination
	if not unreadable_destination_suffix.is_empty() and to.ends_with(unreadable_destination_suffix): promoted=to; destination_reads=0
	return true

func remove(path: String) -> bool:
	files.erase(path); times.erase(path); return true
