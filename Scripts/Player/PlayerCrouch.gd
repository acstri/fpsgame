extends RefCounted
class_name PlayerCrouch

var _capsule_full_height: float = 0.0
var _capsule_crouch_height: float = 0.0
var _head_base_pos: Vector3 = Vector3.ZERO
var _ready_ok: bool = false

func init_from(pc: PlayerController) -> void:
	_ready_ok = false

	if pc.head != null:
		_head_base_pos = pc.head.position

	if pc.capsule_collider == null:
		return
	var cap := pc.capsule_collider.shape as CapsuleShape3D
	if cap == null:
		push_error("PlayerCrouch: capsule_collider must be CapsuleShape3D")
		return

	_capsule_full_height = cap.height
	_capsule_crouch_height = _capsule_full_height * pc.crouch_height_mult
	_ready_ok = true

func tick(pc: PlayerController, delta: float, crouch_held: bool, force_crouch: bool) -> void:
	pc.is_crouching = false
	pc.crouch_head_offset_y = 0.0

	if not _ready_ok:
		pc.is_crouching = force_crouch or crouch_held
		return

	var cap := pc.capsule_collider.shape as CapsuleShape3D
	if cap == null:
		pc.is_crouching = force_crouch or crouch_held
		return

	var blocked := false
	if pc.ceiling_check != null:
		blocked = pc.ceiling_check.is_colliding()

	var want_crouch := force_crouch or crouch_held
	if blocked and not want_crouch:
		want_crouch = cap.height < (_capsule_full_height - 0.02)

	var target_h := _capsule_crouch_height if want_crouch else _capsule_full_height
	cap.height = lerpf(cap.height, target_h, clampf(pc.crouch_lerp_speed * delta, 0.0, 1.0))

	var denom := maxf(0.001, _capsule_full_height - _capsule_crouch_height)
	var t := clampf((_capsule_full_height - cap.height) / denom, 0.0, 1.0)

	# Negative offset lowers the head.
	pc.crouch_head_offset_y = -t * (_head_base_pos.y * (1.0 - pc.crouch_height_mult))
	pc.is_crouching = want_crouch

func apply_head(pc: PlayerController, delta: float, extra_drop: float) -> void:
	if pc.head == null:
		return
	var desired := _head_base_pos
	desired.y += pc.crouch_head_offset_y
	desired.y -= extra_drop
	pc.head.position = pc.head.position.lerp(desired, clampf(pc.slide_camera_lerp_speed * delta, 0.0, 1.0))
