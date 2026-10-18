extends RefCounted
var enabled := true
var write_ok := true
var delay_reads := 0
var reads := 0
var code := ""
var never_echo := false
var reenter := Callable()
func available() -> bool: return enabled
func put(text: String) -> bool:
	code = text
	reads = 0
	return write_ok
func get_text() -> String:
	reads += 1
	if reenter.is_valid():
		var cb := reenter
		reenter = Callable()
		cb.call()
		return "older export"
	return code if not never_echo and reads > delay_reads else "previous clipboard"
