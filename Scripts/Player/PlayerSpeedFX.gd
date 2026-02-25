extends RefCounted
class_name PlayerSpeedLinesFX

var _intensity: float = 0.0

func tick(pc: PlayerController, delta: float, state_name: StringName) -> void:
	if pc.speed_lines_material == null:
		return

	var hv := Vector3(pc.velocity.x, 0.0, pc.velocity.z)
	var speed := hv.length()

	var raw := 0.0
	if speed > pc.speed_lines_normal_speed:
		raw = inverse_lerp(pc.speed_lines_normal_speed, pc.speed_lines_full_speed, speed)
	raw = clampf(raw, 0.0, 1.0)

	var burst_raw := 0.0
	if state_name == &"slide" and pc.slide_burst_left > 0.0:
		var bt := clampf(pc.slide_burst_left / max(pc.slide_burst_duration, 0.001), 0.0, 1.0)
		burst_raw = pc.speed_lines_burst_bonus * bt

	raw = clampf(raw + burst_raw, 0.0, 1.0)

	var rate := pc.speed_lines_lerp_in if raw > _intensity else pc.speed_lines_lerp_out
	if state_name == &"slide" and pc.slide_burst_left > 0.0:
		rate = maxf(rate, pc.speed_lines_burst_lerp)

	_intensity = lerpf(_intensity, raw, clampf(rate * delta, 0.0, 1.0))
	pc.speed_lines_material.set_shader_parameter(pc.speed_lines_density_param, _intensity * pc.speed_lines_max_density)
