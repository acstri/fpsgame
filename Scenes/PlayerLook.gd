# File: Scripts/PlayerLook.gd
extends Node
class_name PlayerLook

@export_group("Look")
@export var mouse_sensitivity := 0.0025
@export var pitch_min_deg := -65.0
@export var pitch_max_deg := 65.0

var _player: Node3D
var _head: Node3D
var _camera: Camera3D

var _yaw := 0.0
var _pitch := 0.0

func setup(player: Node3D, head: Node3D, camera: Camera3D) -> void:
	_player = player
	_head = head
	_camera = camera

	if ProjectSettings.has_setting("application/config/mouse_sensitivity"):
		mouse_sensitivity = float(ProjectSettings.get_setting("application/config/mouse_sensitivity"))

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_yaw = _player.rotation.y
	_pitch = _head.rotation.x

func handle_input(event: InputEvent) -> void:
	if _player == null or _head == null:
		return

	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		_player.rotation.y = _yaw

		_pitch = clamp(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg)
		)
		_head.rotation.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)

func get_flat_forward() -> Vector3:
	if _player == null:
		return Vector3.FORWARD
	var f := -_player.global_transform.basis.z
	f.y = 0.0
	return f.normalized()

func get_basis() -> Basis:
	if _player == null:
		return Basis.IDENTITY
	return _player.global_transform.basis

func get_camera() -> Camera3D:
	return _camera
