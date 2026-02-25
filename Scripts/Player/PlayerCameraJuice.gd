extends RefCounted
class_name PlayerCameraJuice

var _base_fov: float = 75.0
var _base_rot: Vector3 = Vector3.ZERO
var _base_pos: Vector3 = Vector3.ZERO

var _bob_phase: float = 0.0
var _bob_offset: Vector3 = Vector3.ZERO

var _impulse: float = 0.0
var _impulse_vel: float = 0.0

func init_from(pc: PlayerController) -> void:
	if pc.camera == null:
		return
	_base_fov = pc.camera.fov
	_base_rot = pc.camera.rotation
	_base_pos = pc.camera.position

func apply_jump_impulse(pc: PlayerController) -> void:
	_impulse_vel -= pc.cam_impulse_jump

func apply_land_impulse(pc: PlayerController, pre_move_y_vel: float) -> void:
	var impact := clampf(absf(pre_move_y_vel) / 10.0, 0.2, 1.0)
	_impulse_vel += pc.cam_impulse_land * impact

func tick(pc: PlayerController, delta: float, input_vec: Vector2, state_name: StringName) -> void:
	if pc.camera == null:
		return

	var hv := Vector3(pc.velocity.x, 0.0, pc.velocity.z)
	var speed := hv.length()

	# headbob only on ground state
	var bob_allowed := pc.is_on_floor() and state_name == &"ground"
	var moving := bob_allowed and input_vec.length() > 0.1

	var bob_target := Vector3.ZERO
	if moving:
		_bob_phase += delta * pc.headbob_speed * clampf(speed / maxf(0.01, pc.sprint_speed), 0.0, 1.5)
		bob_target.y = sin(_bob_phase) * pc.headbob_amount
		bob_target.x = cos(_bob_phase * 0.5) * pc.headbob_amount * 0.5

	_bob_offset = _bob_offset.lerp(bob_target, clampf(pc.headbob_lerp * delta, 0.0, 1.0))
	pc.camera.position = _base_pos + _bob_offset

	# impulse spring
	var f := maxf(0.01, pc.cam_spring_freq)
	var k := f * f
	var c := 2.0 * pc.cam_spring_damp * f
	_impulse_vel += (-k * _impulse - c * _impulse_vel) * delta
	_impulse += _impulse_vel * delta

	# fov by speed
	var t := 0.0
	if speed > pc.fov_speed_start:
		t = clampf(inverse_lerp(pc.fov_speed_start, pc.fov_speed_end, speed), 0.0, 1.0)
	var target_fov := _base_fov + (pc.fov_max_bonus_deg * t)
	var rate := pc.fov_lerp_in if target_fov > pc.camera.fov else pc.fov_lerp_out
	pc.camera.fov = lerpf(pc.camera.fov, target_fov, clampf(rate * delta, 0.0, 1.0))

	# roll
	var target_roll := 0.0
	if state_name == &"slide":
		var steer := clampf(input_vec.x, -1.0, 1.0)
		var sign := -1.0 if pc.slide_roll_invert else 1.0
		target_roll = deg_to_rad(pc.slide_roll_max_deg) * steer * sign

	var rot := pc.camera.rotation
	rot.z = lerp_angle(rot.z, _base_rot.z + target_roll, clampf(pc.slide_roll_lerp * delta, 0.0, 1.0))
	rot.x = _base_rot.x + (_impulse * 0.02)
	pc.camera.rotation = rot
