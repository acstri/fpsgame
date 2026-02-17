extends Label
class_name FPSCounter

@export var update_rate := 0.25   # seconds between updates
@export var show_frame_time := false

var _accum := 0.0

func _ready() -> void:
	text = "FPS: --"

func _process(delta: float) -> void:
	_accum += delta
	if _accum < update_rate:
		return
	_accum = 0.0

	var fps := Engine.get_frames_per_second()
	if show_frame_time and fps > 0:
		var ms := 1000.0 / fps
		text = "FPS: %d (%.2f ms)" % [fps, ms]
	else:
		text = "FPS: %d" % fps
