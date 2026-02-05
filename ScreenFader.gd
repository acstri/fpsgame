extends Control
class_name ScreenFader

@onready var rect: ColorRect = $ColorRect

func _ready() -> void:
	rect.color.a = 0.0
	visible = true

func fade_to_black(duration: float = 1.0) -> void:
	# kill any previous tween
	if get_tree() == null:
		return

	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(rect, "color:a", 1.0, duration)
