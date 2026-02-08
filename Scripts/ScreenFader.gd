extends Control
class_name ScreenFader

@export_group("UI Ref")
@export var rect: ColorRect # assign in Inspector; fallback will try to find one

var _tween: Tween

func _ready() -> void:
	_autowire()
	if rect == null:
		push_error("ScreenFader: rect (ColorRect) not assigned/found.")
		set_process(false)
		return

	visible = true
	_set_alpha(0.0)

func _exit_tree() -> void:
	_kill_tween()

func fade_to_black(duration: float = 1.0) -> void:
	if rect == null:
		return
	visible = true
	_kill_tween()

	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_method(_set_alpha, rect.color.a, 1.0, maxf(0.0, duration))

func fade_from_black(duration: float = 1.0) -> void:
	if rect == null:
		return
	visible = true
	_kill_tween()

	# Ensure we start at black
	_set_alpha(1.0)

	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_method(_set_alpha, 1.0, 0.0, maxf(0.0, duration))

func clear_instant() -> void:
	if rect == null:
		return
	_kill_tween()
	_set_alpha(0.0)

func black_instant() -> void:
	if rect == null:
		return
	_kill_tween()
	_set_alpha(1.0)

# --- internals ---

func _autowire() -> void:
	if rect != null:
		return

	# Backwards-compatible fallback with your current scene
	rect = get_node_or_null("ColorRect") as ColorRect
	if rect != null:
		return

	# Final fallback: search any ColorRect below
	rect = find_child("", true, false) as ColorRect
	if rect == null:
		for c in get_children():
			if c is ColorRect:
				rect = c
				break

func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null

func _set_alpha(a: float) -> void:
	if rect == null:
		return
	var c := rect.color
	c.a = clampf(a, 0.0, 1.0)
	rect.color = c
