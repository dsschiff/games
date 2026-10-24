extends RefCounted
const Backend = preload("res://scripts/clipboard_backend.gd")
const INTERVAL := 0.08
const DEADLINE := 0.64
var backend: RefCounted
var generation := 0
var pending := false
var expected := ""
var target := ""
var feedback := ""
var outcome := ""
var elapsed := 0.0
var next_poll := INTERVAL
var manual_help := ""
var request_backend: RefCounted
func _init(port: RefCounted=null) -> void:
	backend=port if port!=null else Backend.new()
func cancel() -> void:
	generation+=1; pending=false; target=""; expected=""; feedback=""; outcome=""; request_backend=null
func begin(text: String,identity: String,help: String="Select and copy the save code manually.") -> int:
	cancel(); var token:=generation
	expected=text; target=identity; manual_help=help; elapsed=0; next_poll=INTERVAL
	var port:=backend; request_backend=port
	var supported: bool=port.available()
	if token!=generation or target!=identity: return token
	if not supported:
		outcome="unavailable"; feedback="Clipboard unavailable. "+manual_help; return token
	var accepted: bool=port.put(text)
	if token!=generation or target!=identity: return token
	if not accepted:
		outcome="unconfirmed"; feedback="Copy not confirmed. "+manual_help; return token
	pending=true; outcome="waiting"; feedback="Copy requested. Waiting for confirmation…"
	return token
func poll(delta: float) -> bool:
	if not pending: return false
	elapsed+=maxf(0,delta)
	if elapsed<next_poll: return false
	next_poll+=INTERVAL
	var token:=generation; var identity:=target; var port:=request_backend
	var observed: String=port.get_text()
	if token!=generation or target!=identity: return false
	if observed==expected:
		pending=false; outcome="confirmed"; feedback="Copied and checked save code."; return true
	if elapsed>=DEADLINE:
		pending=false; outcome="unconfirmed"; feedback="Copy not confirmed. "+manual_help; return true
	return false
