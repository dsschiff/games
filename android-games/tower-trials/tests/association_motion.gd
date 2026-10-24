extends "res://tests/feedback_association.gd"
## Same fresh actual-input route in both captures; no product overlay or hint.
class InputObserver:
    extends Node
    var events: Array = []
    func _input(event: InputEvent) -> void:
        if event is InputEventScreenTouch:
            events.append({"frame": Engine.get_process_frames(), "kind": "ScreenTouch", "pressed": event.pressed, "index": event.index, "position": [event.position.x, event.position.y]})

var observer: InputObserver
var photographed := {}
var picture_timeline: Array = []

func create_game() -> void:
    observer = InputObserver.new()
    root.add_child(observer)
    await super.create_game()

func measure_frame() -> void:
    super.measure_frame()
    if not measuring.is_empty() and measuring.frames in [45, 60, 75]:
        var label: String = measuring.label + "-" + str(measuring.frames)
        if not photographed.has(label):
            photographed[label] = true
            picture_timeline.append({"label": label, "process_frame": Engine.get_process_frames(), "level": game.level.id, "pending_room": game.pending_room, "state": game.state.duplicate(true), "popup_layout": str(painted()), "links": str(game.view.popup_links()) if game.view.has_method("popup_links") else "none on baseline"})
            if DisplayServer.get_name() != "headless": capture.call_deferred(label)

func capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder.path_join(label + ".png"))

func write_result() -> void:
    super.write_result()
    FileAccess.open(folder.path_join("observed-input-events.json"), FileAccess.WRITE).store_string(JSON.stringify(observer.events, "  "))
    FileAccess.open(folder.path_join("picture-timeline.json"), FileAccess.WRITE).store_string(JSON.stringify(picture_timeline, "  "))
    observer.queue_free()
    observer = null
