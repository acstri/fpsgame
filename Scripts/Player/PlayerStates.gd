extends RefCounted
class_name PlayerStates

class GroundState extends PlayerState:
	func physics_update(pc: PlayerController, delta: float) -> void:
		if not pc.is_on_floor():
			pc.capture_air_cap()
			pc.sm.set_state(pc, &"air")
			return

		pc.air_speed_cap = pc.max_air_speed

		var ts := pc.target_speed
		if pc.is_crouching:
			ts = minf(ts, pc.crouch_speed)

		if pc.has_move_input:
			var target_vel := pc.wish_dir * ts
			pc.velocity.x = move_toward(pc.velocity.x, target_vel.x, pc.ground_accel * delta)
			pc.velocity.z = move_toward(pc.velocity.z, target_vel.z, pc.ground_accel * delta)
		else:
			pc.velocity.x = move_toward(pc.velocity.x, 0.0, pc.ground_decel * delta)
			pc.velocity.z = move_toward(pc.velocity.z, 0.0, pc.ground_decel * delta)

class AirState extends PlayerState:
	func physics_update(pc: PlayerController, delta: float) -> void:
		# IMPORTANT: if we landed, switch back to ground immediately
		if pc.is_on_floor():
			pc.air_speed_cap = pc.max_air_speed
			pc.sm.set_state(pc, &"ground")
			return

		# enter wallrun if allowed
		if pc.wallrun_enabled and pc.is_on_wall_only():
			var hv := Vector3(pc.velocity.x, 0.0, pc.velocity.z)
			if hv.length() >= pc.wallrun_min_speed:
				var wn := pc.get_wall_normal()
				var is_left := pc.wall_is_left(wn)
				var blocked := (is_left and (pc.has_left_wallrun or pc.wallrun_reset_left > 0.0)) \
					or ((not is_left) and (pc.has_right_wallrun or pc.wallrun_reset_right > 0.0))
				if not blocked:
					pc.start_wallrun(is_left)
					pc.sm.set_state(pc, &"wallrun")
					return

		var accel := pc.air_accel
		if pc.has_move_input and pc.wish_dir.length_squared() > 0.0001:
			if pc.air_strafe_curve != null:
				var hv2 := Vector3(pc.velocity.x, 0.0, pc.velocity.z)
				if hv2.length_squared() > 0.01:
					var ang := clampf(pc.horizontal_angle_deg(hv2, pc.wish_dir), 0.0, 180.0)
					var s := ang / 180.0
					var bonus := pc.air_strafe_curve.sample(s) * pc.air_strafe_modifier
					accel = pc.air_accel * (1.0 + bonus)

			pc.velocity.x = move_toward(pc.velocity.x, pc.wish_dir.x * pc.target_speed, accel * delta)
			pc.velocity.z = move_toward(pc.velocity.z, pc.wish_dir.z * pc.target_speed, accel * delta)
		else:
			if pc.air_decel > 0.0:
				pc.velocity.x = move_toward(pc.velocity.x, 0.0, pc.air_decel * delta)
				pc.velocity.z = move_toward(pc.velocity.z, 0.0, pc.air_decel * delta)

		# air carry cap
		if pc.air_carry_decay > 0.0:
			pc.air_speed_cap = move_toward(pc.air_speed_cap, pc.max_air_speed, pc.air_carry_decay * delta)
		else:
			pc.air_speed_cap = maxf(pc.air_speed_cap, pc.max_air_speed)

		var flat := Vector3(pc.velocity.x, 0.0, pc.velocity.z)
		if flat.length() > pc.air_speed_cap:
			flat = flat.normalized() * pc.air_speed_cap
			pc.velocity.x = flat.x
			pc.velocity.z = flat.z

class SlideState extends PlayerState:
	func enter(pc: PlayerController) -> void:
		pc.slide_cd_left = pc.slide_cooldown
		pc.slide_leave_ground_left = pc.slide_leave_ground_grace

		var hv := Vector3(pc.velocity.x, 0.0, pc.velocity.z)
		var speed := hv.length()
		if speed <= 0.001:
			pc.slide_burst_dir = Vector3.ZERO
		else:
			pc.slide_burst_dir = hv.normalized()

		pc.slide_burst_left = pc.slide_burst_duration
		pc.slide_burst_added = 0.0

		# slide boost
		if speed > 0.001:
			var dir := hv.normalized()
			pc.velocity.x = dir.x * speed * pc.slide_boost
			pc.velocity.z = dir.z * speed * pc.slide_boost

		if pc.velocity.y > -pc.slide_ground_snap_speed:
			pc.velocity.y = -pc.slide_ground_snap_speed

	func physics_update(pc: PlayerController, delta: float) -> void:
		if not pc.slide_held:
			pc.slide_burst_left = 0.0
			pc.sm.set_state(pc, &"ground" if pc.is_on_floor() else &"air")
			return

		if pc.velocity.y > -pc.slide_ground_snap_speed:
			pc.velocity.y = -pc.slide_ground_snap_speed

		if pc.is_on_floor():
			pc.slide_leave_ground_left = pc.slide_leave_ground_grace
		else:
			if pc.slide_leave_ground_left <= 0.0:
				pc.slide_burst_left = 0.0
				pc.capture_air_cap()
				pc.sm.set_state(pc, &"air")
				return

		var hv := Vector3(pc.velocity.x, 0.0, pc.velocity.z)
		var speed := hv.length()

		# friction
		if speed > 0.0:
			var new_speed := maxf(0.0, speed - pc.slide_friction * delta)
			hv = hv.normalized() * new_speed

		# slope accel
		if pc.is_on_floor():
			var n := pc.get_floor_normal().normalized()
			var angle := rad_to_deg(acos(clampf(n.dot(Vector3.UP), -1.0, 1.0)))
			if angle >= pc.slide_slope_min_angle_deg:
				var downhill := (Vector3.DOWN - n * Vector3.DOWN.dot(n))
				if downhill.length_squared() > 0.000001:
					downhill = downhill.normalized()
					hv += downhill * pc.slide_slope_accel * delta
					var capped := minf(hv.length(), pc.slide_slope_max_speed)
					if hv.length() > 0.0:
						hv = hv.normalized() * capped

		# steer
		if pc.wish_dir.length_squared() > 0.0001 and hv.length_squared() > 0.0001:
			var hv_dir := hv.normalized()
			var t := clampf(pc.slide_steer * delta, 0.0, 1.0)
			hv = hv_dir.slerp(pc.wish_dir, t) * hv.length()

		# burst
		if pc.slide_burst_left > 0.0:
			pc.slide_burst_left = maxf(0.0, pc.slide_burst_left - delta)
			if pc.slide_burst_dir.length_squared() < 0.000001:
				pc.slide_burst_dir = hv.normalized() if hv.length_squared() > 0.000001 else pc.wish_dir

			var remaining := maxf(0.0, pc.slide_burst_max_bonus - pc.slide_burst_added)
			if remaining > 0.0 and pc.slide_burst_dir.length_squared() > 0.000001:
				var add := minf(pc.slide_burst_accel * delta, remaining)
				hv += pc.slide_burst_dir.normalized() * add
				pc.slide_burst_added += add

		pc.velocity.x = hv.x
		pc.velocity.z = hv.z

		if hv.length() <= pc.slide_end_speed:
			pc.slide_burst_left = 0.0
			pc.sm.set_state(pc, &"ground" if pc.is_on_floor() else &"air")

class WallrunState extends PlayerState:
	func physics_update(pc: PlayerController, delta: float) -> void:
		if not pc.wallrun_enabled or not pc.is_on_wall_only():
			pc.end_wallrun_to_air()
			pc.sm.set_state(pc, &"air")
			return

		pc.wallrun_t += delta / maxf(0.01, pc.wallrun_time)
		if pc.wallrun_t >= 1.0:
			pc.end_wallrun_to_air()
			pc.sm.set_state(pc, &"air")
			return

		var wn := pc.get_wall_normal()
		var up := Vector3.UP
		var t1 := wn.cross(up).normalized()
		var t2 := up.cross(wn).normalized()

		var hv := Vector3(pc.velocity.x, 0.0, pc.velocity.z)
		var tangent := t1 if hv.dot(t1) > hv.dot(t2) else t2

		var target_speed := clampf(pc.wallrun_start_speed, pc.walk_speed, pc.sprint_speed * 2.0)
		var new_h := tangent * target_speed

		if pc.wish_dir.length_squared() > 0.0001:
			var wish_h := Vector3(pc.wish_dir.x, 0.0, pc.wish_dir.z)
			if wish_h.length_squared() > 0.0001:
				new_h = new_h.lerp(wish_h.normalized() * target_speed, clampf(pc.wallrun_steer * delta, 0.0, 1.0))

		pc.velocity.x = new_h.x
		pc.velocity.z = new_h.z

		var lift = 1.0 - pc.wallrun_t
		if pc.wallrun_curve != null:
			lift = pc.wallrun_curve.sample(clampf(pc.wallrun_t, 0.0, 1.0))
		pc.velocity.y = lift * pc.wallrun_height

		pc.velocity -= wn * pc.wallrun_stick_force

		if pc.jump_pressed:
			var dir := (up + wn * 0.5).normalized()
			pc.velocity = dir * (pc.jump_velocity_base * pc.wallrun_jump_boost)
			pc.camera_juice.apply_jump_impulse(pc)
			pc.end_wallrun_to_air()
			pc.sm.set_state(pc, &"air")

class GrappleState extends PlayerState:
	func enter(pc: PlayerController) -> void:
		# cancel states safely
		if pc.grapple_cancel_slide and pc.sm.current_name() == &"slide":
			pc.slide_burst_left = 0.0
		if pc.grapple_cancel_wallrun and pc.sm.current_name() == &"wallrun":
			pc.end_wallrun_to_air()

	func physics_update(pc: PlayerController, delta: float) -> void:
		if not pc.grapple.launched:
			pc.sm.set_state(pc, &"ground" if pc.is_on_floor() else &"air")
			return

		pc.grapple.apply_rope_force(pc, delta)

		# mild steering while grappling
		if pc.wish_dir.length_squared() > 0.0001:
			pc.velocity.x = move_toward(pc.velocity.x, pc.wish_dir.x * pc.max_air_speed, pc.air_accel * delta)
			pc.velocity.z = move_toward(pc.velocity.z, pc.wish_dir.z * pc.max_air_speed, pc.air_accel * delta)
