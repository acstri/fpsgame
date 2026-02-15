# File: Scripts/GroundProbe.gd
extends Node
class_name GroundProbe

@export_group("Probe")
@export var strong_grounded_frames := 2

var _body: CharacterBody3D
var _floor_frames := 0
var _floor_normal := Vector3.UP

func setup(body: CharacterBody3D) -> void:
	_body = body

func tick() -> void:
	if _body == null:
		return

	if _body.is_on_floor():
		_floor_frames = min(_floor_frames + 1, 9999)
		_floor_normal = _body.get_floor_normal()
	else:
		_floor_frames = max(_floor_frames - 1, 0)
		_floor_normal = Vector3.UP

func is_grounded_strong() -> bool:
	# Helps avoid single-frame floor flicker on ramps/steps.
	return _floor_frames >= strong_grounded_frames

func floor_normal() -> Vector3:
	return _floor_normal
