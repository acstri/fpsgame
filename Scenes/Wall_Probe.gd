# File: Scripts/WallProbe.gd
extends Node
class_name WallProbe

@export_group("Probe")
@export var range := 1.0
@export var height := 1.1
@export var side_offset := 0.35
@export var layers := 1 # set to your world collision layer mask if needed

var _body: CharacterBody3D
var _origin: Node3D

var _rc_front: RayCast3D
var _rc_left: RayCast3D
var _rc_right: RayCast3D

var _hit := false
var _normal := Vector3.ZERO

func setup(body: CharacterBody3D, origin: Node3D) -> void:
	_body = body
	_origin = origin

	_rc_front = _ensure_ray("WallRayFront", Vector3(0, height, 0), Vector3(0, 0, -range))
	_rc_left  = _ensure_ray("WallRayLeft",  Vector3(-side_offset, height, 0), Vector3(0, 0, -range))
	_rc_right = _ensure_ray("WallRayRight", Vector3( side_offset, height, 0), Vector3(0, 0, -range))

func tick() -> void:
	_hit = false
	_normal = Vector3.ZERO
	if _body == null:
		return

	_update_ray(_rc_front)
	_update_ray(_rc_left)
	_update_ray(_rc_right)

func has_wall() -> bool:
	return _hit

func wall_normal() -> Vector3:
	return _normal

func _ensure_ray(name_: String, origin_local: Vector3, target_local: Vector3) -> RayCast3D:
	var rc := get_node_or_null(name_) as RayCast3D
	if rc == null:
		rc = RayCast3D.new()
		rc.name = name_
		add_child(rc)

	rc.enabled = true
	rc.collide_with_areas = false
	rc.collide_with_bodies = true
	rc.collision_mask = layers

	rc.position = origin_local
	rc.target_position = target_local
	return rc

func _update_ray(rc: RayCast3D) -> void:
	if rc == null:
		return
	rc.force_raycast_update()
	if rc.is_colliding():
		var n := rc.get_collision_normal()
		# Prefer the "best" wall: largest horizontal component (more wall-like, less floor-like)
		var horiz := Vector3(n.x, 0.0, n.z).length()
		if not _hit or horiz > Vector3(_normal.x, 0.0, _normal.z).length():
			_hit = true
			_normal = n.normalized()
