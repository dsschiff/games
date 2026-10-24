extends RefCounted
## Dormant typed transport boundary. No native singleton, auth or network calls.
## A future native binding must own late callbacks/handle cleanup after abandon().
signal completed(request_id: String, body: Dictionary)

func is_configured() -> bool:
	return false

func request(request_id: String, _operation: String, _arguments: Dictionary) -> void:
	completed.emit(request_id,{"status":"not_configured"})

func abandon() -> void:
	pass
