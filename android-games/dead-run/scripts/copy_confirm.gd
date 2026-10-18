extends RefCounted
const Backend = preload("res://scripts/clipboard_backend.gd")
var backend: Variant = Backend.new()
var generation := 0
var pending := false
var expected := ""
var feedback := ""
var elapsed := 0.0
var next_poll := 0.08

func cancel() -> void:
	generation += 1
	pending = false

func begin(text: String) -> void:
	cancel()
	expected = text
	elapsed = 0.0
	next_poll = 0.08
	if not backend.available():
		feedback = "Clipboard unavailable. Select and copy the code manually."
		return
	if not backend.put(text):
		feedback = "Copy failed. Select and copy the code manually."
		return
	pending = true
	feedback = "Copy requested. Waiting for confirmation…"

func poll(delta: float) -> bool:
	if not pending: return false
	elapsed += delta
	if elapsed < next_poll: return false
	next_poll += 0.08
	var token := generation
	var observed: String = backend.get_text()
	if token != generation: return false
	if observed == expected:
		pending = false
		feedback = "Copied checked rescue save."
		return true
	if elapsed >= 0.64:
		pending = false
		feedback = "Copy not confirmed. Use Paste to check, or select and copy the code."
		return true
	return false
