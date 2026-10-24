extends "res://scripts/cloud/port.gd"
## Actual singleton bridge. No simulated transport and no SDK readiness request.
const Backup = preload("res://scripts/cloud/backup.gd")
const OPS := ["sign_in","status","read","write","resolve"]
static var owner: RefCounted
var native: Object
var pending := ""
var cancel_id := ""
var serial := 0
var cancelling := false
var attached := false
var cleanup_needed := false

func _init(binding: Object=null) -> void:
	native = binding

func is_configured() -> bool:
	if owner!=null and owner!=self: return false
	if native==null and Engine.has_singleton("PlayCloud"): native=Engine.get_singleton("PlayCloud")
	if native==null or not native.has_method("is_configured") or not native.has_method("cancel") or not native.has_method("request") or not native.has_signal("completed"): return false
	return native.call("is_configured")==true

func _attach() -> void:
	if attached: return
	owner=self; attached=true; native.connect("completed",_native_completed)

func request(id: String, operation: String, args: Dictionary) -> void:
	if not is_configured(): completed.emit(id,{"status":"not_configured"}); return
	if cancelling or cleanup_needed or not pending.is_empty(): completed.emit(id,{"status":"busy"}); return
	var encoded := JSON.stringify(args)
	if id.is_empty() or id.length()>128 or operation not in OPS or encoded.to_utf8_buffer().size()>((Backup.MAX_BYTES+2)/3)*4+16384:
		completed.emit(id,{"status":"invalid_request"}); return
	_attach(); pending=id
	native.call("request",id,operation,encoded)

func abandon() -> void:
	if cancelling: return
	if not attached:
		completed.emit("@abandoned",{"status":"cancelled"}); return
	cleanup_needed=true; cancelling=true; pending=""; serial+=1; cancel_id="frontline-cleanup-"+str(get_instance_id())+"-"+str(serial)
	native.call("cancel",cancel_id)

func _native_completed(id: String, encoded: String) -> void:
	if cancelling and id!=cancel_id: return
	if not cancelling and (id!=pending or pending.is_empty()): return
	# Two maximum base64 snapshots plus bounded metadata; reject before JSON parse.
	var result := {"status":"invalid_response"}
	if encoded.to_utf8_buffer().size()<=((Backup.MAX_BYTES+2)/3)*8+32768:
		var json := JSON.new()
		if json.parse(encoded)==OK and json.data is Dictionary: result=json.data
	if cancelling:
		if result.get("status")=="cancelled":
			native.disconnect("completed",_native_completed); attached=false; cleanup_needed=false; owner=null
		cancelling=false; cancel_id=""
		completed.emit("@abandoned",result)
	else:
		pending=""; completed.emit(id,result)

func cleanup_required() -> bool:
	return cleanup_needed
