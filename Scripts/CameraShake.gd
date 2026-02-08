extends Node
class_name CameraShake

@export var enabled := true

# If you attach this to a Camera3D directly, it will use that.
# If you attach it as a child node, set camera_path or it will use the viewport camera.
@export var camera_path: NodePath

var _cam: Camera3D
var _base_transform: Transform3D

var _time_left := 0.0
var _duration := 0.0
var _amplitude := 0.0
var _frequency := 25.0
var _pos_scale := 1.0
var _rot_scale := 1.0

func _ready() -> void:
	_cam = _resolve_camera()
	if _cam != null:
		_base_transform = _cam.transform

func shake(amplitude: float, duration: float, frequency: float = 25.0, pos_scale: float = 1.0, rot_scale: float = 1.0) -> void:
	if not enabled:
		return

	_cam = _resolve_camera()
	if _cam == null:
		return

	# Store base transform when starting a new shake (or if camera changed).
	_base_transform = _cam.transform

	_amplitude = maxf(0.0, amplitude)
	_duration = maxf(0.01, duration)
	_time_left = _duration
	_frequency = maxf(1.0, frequency)
	_pos_scale = maxf(0.0, pos_scale)
	_rot_scale = maxf(0.0, rot_scale)

	set_process(true)

func _process(delta: float) -> void:
	if _cam == null:
		set_process(false)
		return

	if _time_left <= 0.0:
		_cam.transform = _base_transform
		set_process(false)
		return

	_time_left = maxf(0.0, _time_left - delta)

	# Fade out over time
	var t := 1.0 - (_time_left / maxf(0.0001, _duration)) # 0..1
	var fade := 1.0 - t
	fade = fade * fade

	# Jitter
	var a := _amplitude * fade
	var pos_jit := Vector3(
		randf_range(-a, a),
		randf_range(-a, a),
		randf_range(-a, a)
	) * 0.02 * _pos_scale

	var rot_jit := Vector3(
		randf_range(-a, a),
		randf_range(-a, a),
		randf_range(-a, a)
	) * 0.003 * _rot_scale

	# Apply relative to base
	var tr := _base_transform
	tr.origin += pos_jit
	tr.basis = Basis.from_euler(rot_jit) * tr.basis
	_cam.transform = tr

func _resolve_camera() -> Camera3D:
	# If this script is on the camera itself
	# If an explicit path is set
	if camera_path != NodePath() and has_node(camera_path):
		var n := get_node(camera_path)
		if n is Camera3D:
			return n as Camera3D

	# Fallback: viewport camera
	return get_viewport().get_camera_3d()
