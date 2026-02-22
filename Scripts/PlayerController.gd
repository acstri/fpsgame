# full replacement: PlayerController.gd
extends CharacterBody3D
class_name PlayerController

@export_group("References")
@export var head: Node3D
@export var camera: Camera3D
@export var stats: PlayerStats
@export var level_system: LevelSystem

@export_group("Look")
@export var mouse_sensitivity := 0.0025
@export var pitch_min_deg := -65
@export var pitch_max_deg := 65

@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var gravity := 18.0
@export var ground_accel := 40.0
@export var ground_decel := 70.0

@export_group("Air Control")
@export var air_accel := 18.0
@export var air_decel := 0.0 # 0 = do NOT bleed speed in air when no input
@export var max_air_speed := 8.0 # normal air cap (can be exceeded if carried)

@export_group("Jump")
@export var jump_velocity_base := 4.5          # jump at/below jump_speed_ref
@export var jump_speed_ref := 6.0              # "normal" run speed reference
@export var jump_velocity_per_speed := 0.10    # extra vertical velocity per 1.0 speed above ref
@export var jump_velocity_max_bonus := 2.5     # cap of the bonus (so it doesn't get silly)

@export_group("Sprint Sticky (press to start, stop moving to cancel)")
@export var sprint_action := "sprint"
@export var sprint_cancels_on_no_input := true
var _sprint_latched := false

@export_group("Slide (hold)")
@export var slide_action := "crouch"
@export var slide_min_speed := 6.0
@export var slide_friction := 10.0 # lower = keep speed longer
@export var slide_steer := 4.0
@export var slide_boost := 1.05
@export var slide_end_speed := 2.0
@export var slide_cooldown := 0.35

@export_group("Slide Boost Burst")
# Short initial acceleration burst after slide starts.
# Adds speed (m/s) along the initial slide direction for a brief duration,
# capped by slide_burst_max_bonus.
@export var slide_burst_duration := 0.12
@export var slide_burst_accel := 30.0
@export var slide_burst_max_bonus := 4.0

@export_group("Slide Buffer")
@export var slide_buffer_time := 0.20

@export_group("Slide Ground Stick")
@export var slide_ground_snap_speed := 16.0
@export var slide_leave_ground_grace := 0.08


@export_group("Slide Slopes")
@export var slide_slope_accel := 14.0
@export var slide_slope_max_speed := 20.0
@export var slide_slope_min_angle_deg := 3.0

@export_group("Slide Camera")
@export var slide_camera_drop := 0.45
@export var slide_camera_lerp_speed := 12.0

@export_group("Speed Lines (Shader)")
@export var speed_lines_material: ShaderMaterial
@export var speed_lines_density_param := "line_density"
@export var speed_lines_normal_speed := 6.0
@export var speed_lines_full_speed := 16.0
@export var speed_lines_max_density := 1.0
@export var speed_lines_lerp_in := 10.0
@export var speed_lines_lerp_out := 14.0
@export_group("Speed Lines (Slide Burst)")
@export var speed_lines_burst_bonus := 0.35 # extra intensity while burst is active
@export var speed_lines_burst_lerp := 18.0  # how fast it kicks in/out

@export_group("Wind Loop (no node needed in scene)")
@export var wind_stream: AudioStream
@export var wind_bus := "Master"
@export var wind_min_db := -30.0
@export var wind_max_db := 0.0
@export var wind_min_pitch := 0.95
@export var wind_max_pitch := 1.15
@export var wind_lerp := 10.0
@export var wind_start_threshold := 0.02
@export_group("Slide Loop (no node needed in scene)")
@export var slide_loop_stream: AudioStream
@export var slide_loop_bus := "SFX"
@export var slide_loop_min_db := -26.0
@export var slide_loop_max_db := -4.0
@export var slide_loop_min_pitch := 0.95
@export var slide_loop_max_pitch := 1.10
@export var slide_loop_lerp := 14.0
@export var slide_loop_start_speed := 1.0  # don’t play if barely moving

@export_group("Momentum Carry")
@export var carry_speed_in_air := true
@export var air_carry_decay := 0.0 # 0 = never decay carried cap; >0 decays back to max_air_speed

enum MoveState { GROUND, AIR, SLIDE }
var _state: MoveState = MoveState.GROUND

var _yaw := 0.0
var _pitch := 0.0

var _slide_cd_left := 0.0
var _slide_buffer_left := 0.0
var _slide_leave_ground_left := 0.0

# slide burst state
var _slide_burst_left := 0.0
var _slide_burst_dir := Vector3.ZERO
var _slide_burst_added := 0.0

var _head_base_pos: Vector3

var _speed_fx_intensity := 0.0

var _air_speed_cap := 0.0

var _wind_player: AudioStreamPlayer
var _slide_loop_player: AudioStreamPlayer

func _ready() -> void:
	if ProjectSettings.has_setting("application/config/mouse_sensitivity"):
		mouse_sensitivity = float(ProjectSettings.get_setting("application/config/mouse_sensitivity"))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_autowire()
	if not _validate_refs():
		set_process(false)
		set_physics_process(false)
		return

	_yaw = rotation.y
	_pitch = head.rotation.x
	_head_base_pos = head.position

	_air_speed_cap = max_air_speed
	_setup_wind_player()
	_setup_slide_loop_player()

func _setup_wind_player() -> void:
	if wind_stream == null:
		return
	_wind_player = AudioStreamPlayer.new()
	_wind_player.name = "_WindLoop"
	_wind_player.stream = wind_stream
	_wind_player.bus = wind_bus
	_wind_player.volume_db = wind_min_db
	_wind_player.pitch_scale = wind_min_pitch
	_wind_player.autoplay = false
	add_child(_wind_player)
	
func _setup_slide_loop_player() -> void:
	if slide_loop_stream == null:
		return
	_slide_loop_player = AudioStreamPlayer.new()
	_slide_loop_player.name = "_SlideLoop"
	_slide_loop_player.stream = slide_loop_stream
	_slide_loop_player.bus = slide_loop_bus
	_slide_loop_player.volume_db = slide_loop_min_db
	_slide_loop_player.pitch_scale = slide_loop_min_pitch
	_slide_loop_player.autoplay = false
	add_child(_slide_loop_player)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		rotation.y = _yaw

		_pitch = clamp(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg)
		)
		head.rotation.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()

	if _slide_cd_left > 0.0:
		_slide_cd_left = maxf(0.0, _slide_cd_left - delta)
	if _slide_buffer_left > 0.0:
		_slide_buffer_left = maxf(0.0, _slide_buffer_left - delta)
	if _slide_leave_ground_left > 0.0:
		_slide_leave_ground_left = maxf(0.0, _slide_leave_ground_left - delta)

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var has_move_input := input_vec.length() > 0.0
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var slide_held := Input.is_action_pressed(slide_action)
	var slide_pressed := Input.is_action_just_pressed(slide_action)

	if Input.is_action_just_pressed(sprint_action) and has_move_input:
		_sprint_latched = true
	if sprint_cancels_on_no_input and not has_move_input:
		_sprint_latched = false

	var mult := stats.move_speed_mult if stats != null else 1.0
	var target_speed := (sprint_speed if _sprint_latched else walk_speed) * mult

	if not was_on_floor:
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.1

	if slide_pressed:
		if was_on_floor:
			_try_start_slide(true)
		else:
			_slide_buffer_left = slide_buffer_time

	if was_on_floor and Input.is_action_just_pressed("jump"):
		_do_jump()

	match _state:
		MoveState.SLIDE:
			_tick_slide(delta, wish_dir, was_on_floor, slide_held)
		MoveState.AIR:
			_tick_air(delta, wish_dir, has_move_input, target_speed)
		MoveState.GROUND:
			_tick_ground(delta, input_vec, wish_dir, target_speed, was_on_floor)

	_update_slide_camera(delta)
	_update_speed_fx(delta)

	move_and_slide()

	var now_on_floor := is_on_floor()

	if (not was_on_floor) and now_on_floor and _slide_buffer_left > 0.0 and slide_held:
		_slide_buffer_left = 0.0
		_try_start_slide(true)

	_post_update_state(was_on_floor, now_on_floor)

func _tick_ground(delta: float, input_vec: Vector2, wish_dir: Vector3, target_speed: float, on_floor: bool) -> void:
	if not on_floor:
		_state = MoveState.AIR
		_capture_air_cap()
		return

	_air_speed_cap = max_air_speed

	if input_vec.length() > 0.0:
		var target_vel := wish_dir * target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, ground_accel * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, ground_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_decel * delta)

func _tick_air(delta: float, wish_dir: Vector3, has_move_input: bool, target_speed: float) -> void:
	if has_move_input and wish_dir.length_squared() > 0.0001:
		velocity.x = move_toward(velocity.x, wish_dir.x * target_speed, air_accel * delta)
		velocity.z = move_toward(velocity.z, wish_dir.z * target_speed, air_accel * delta)
	else:
		if air_decel > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, air_decel * delta)
			velocity.z = move_toward(velocity.z, 0.0, air_decel * delta)

	if air_carry_decay > 0.0:
		_air_speed_cap = move_toward(_air_speed_cap, max_air_speed, air_carry_decay * delta)
	else:
		_air_speed_cap = maxf(_air_speed_cap, max_air_speed)

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > _air_speed_cap:
		flat = flat.normalized() * _air_speed_cap
		velocity.x = flat.x
		velocity.z = flat.z

func _tick_slide(delta: float, wish_dir: Vector3, on_floor: bool, slide_held: bool) -> void:
	if not slide_held:
		_slide_burst_left = 0.0
		_state = MoveState.GROUND
		return

	if velocity.y > -slide_ground_snap_speed:
		velocity.y = -slide_ground_snap_speed

	if on_floor:
		_slide_leave_ground_left = slide_leave_ground_grace
	else:
		if _slide_leave_ground_left <= 0.0:
			_slide_burst_left = 0.0
			_state = MoveState.AIR
			_capture_air_cap()
			return

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	if speed > 0.0:
		var new_speed := maxf(0.0, speed - slide_friction * delta)
		hv = hv.normalized() * new_speed

	if on_floor:
		var n := get_floor_normal().normalized()
		var angle := rad_to_deg(acos(clampf(n.dot(Vector3.UP), -1.0, 1.0)))
		if angle >= slide_slope_min_angle_deg:
			var downhill := (Vector3.DOWN - n * Vector3.DOWN.dot(n))
			if downhill.length_squared() > 0.000001:
				downhill = downhill.normalized()
				hv += downhill * slide_slope_accel * delta
				var capped := minf(hv.length(), slide_slope_max_speed)
				if hv.length() > 0.0:
					hv = hv.normalized() * capped

	if wish_dir.length_squared() > 0.0 and hv.length_squared() > 0.0:
		var hv_dir := hv.normalized()
		var t := clampf(slide_steer * delta, 0.0, 1.0)
		var steered := hv_dir.slerp(wish_dir, t)
		hv = steered * hv.length()

	# --- NEW: short initial burst after slide start ---
	if _slide_burst_left > 0.0:
		_slide_burst_left = maxf(0.0, _slide_burst_left - delta)

		# pick a direction if missing (e.g. if we started from near-zero hv)
		if _slide_burst_dir.length_squared() < 0.000001:
			_slide_burst_dir = hv.normalized() if hv.length_squared() > 0.000001 else wish_dir

		var remaining := maxf(0.0, slide_burst_max_bonus - _slide_burst_added)
		if remaining > 0.0 and _slide_burst_dir.length_squared() > 0.000001:
			var add := minf(slide_burst_accel * delta, remaining)
			hv += _slide_burst_dir.normalized() * add
			_slide_burst_added += add
	# -----------------------------------------------

	velocity.x = hv.x
	velocity.z = hv.z

	if hv.length() <= slide_end_speed:
		_slide_burst_left = 0.0
		_state = MoveState.GROUND

func _try_start_slide(on_floor: bool) -> void:
	if _state == MoveState.SLIDE:
		return
	if _slide_cd_left > 0.0:
		return
	if not on_floor:
		return

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	if speed < slide_min_speed:
		return

	_state = MoveState.SLIDE
	_slide_cd_left = slide_cooldown
	_slide_leave_ground_left = slide_leave_ground_grace

	# arm burst using the pre-slide direction
	_slide_burst_left = slide_burst_duration
	_slide_burst_added = 0.0
	_slide_burst_dir = hv.normalized() if speed > 0.0 else Vector3.ZERO

	if speed > 0.0:
		var dir := hv.normalized()
		velocity.x = dir.x * speed * slide_boost
		velocity.z = dir.z * speed * slide_boost

	if velocity.y > -slide_ground_snap_speed:
		velocity.y = -slide_ground_snap_speed

func _do_jump() -> void:
	# jump height increases with current horizontal speed
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()

	# compute bonus based on speed above reference
	var over := maxf(0.0, speed - jump_speed_ref)
	var bonus := minf(over * jump_velocity_per_speed, jump_velocity_max_bonus)

	if _state == MoveState.SLIDE:
		_slide_burst_left = 0.0
		_state = MoveState.AIR
	_capture_air_cap()

	var jmult := stats.jump_mult if stats != null else 1.0
	velocity.y = (jump_velocity_base + bonus) * jmult

func _capture_air_cap() -> void:
	if not carry_speed_in_air:
		_air_speed_cap = max_air_speed
		return
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	_air_speed_cap = max(max_air_speed, hv.length())

func _post_update_state(was_on_floor: bool, now_on_floor: bool) -> void:
	if now_on_floor:
		if _state == MoveState.AIR:
			_state = MoveState.GROUND
		_air_speed_cap = max_air_speed
	else:
		if _state == MoveState.GROUND:
			_state = MoveState.AIR
			_capture_air_cap()

func _update_slide_camera(delta: float) -> void:
	if head == null:
		return

	var target := _head_base_pos
	if _state == MoveState.SLIDE:
		target.y = _head_base_pos.y - slide_camera_drop

	head.position = head.position.lerp(target, clampf(slide_camera_lerp_speed * delta, 0.0, 1.0))

func _update_speed_fx(delta: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()

	# base intensity from speed
	var raw := 0.0
	if speed > speed_lines_normal_speed:
		raw = inverse_lerp(speed_lines_normal_speed, speed_lines_full_speed, speed)
	raw = clampf(raw, 0.0, 1.0)

	# extra intensity during slide burst
	var burst_raw := 0.0
	if _state == MoveState.SLIDE and _slide_burst_left > 0.0:
		# scale by remaining burst time (strongest at start)
		var t := clampf(_slide_burst_left / max(slide_burst_duration, 0.001), 0.0, 1.0)
		burst_raw = speed_lines_burst_bonus * t

	raw = clampf(raw + burst_raw, 0.0, 1.0)

	# smoother response (separate burst lerp)
	var target := raw
	var rate := speed_lines_lerp_in if target > _speed_fx_intensity else speed_lines_lerp_out

	# if burst is active, kick faster
	if _state == MoveState.SLIDE and _slide_burst_left > 0.0:
		rate = maxf(rate, speed_lines_burst_lerp)

	_speed_fx_intensity = lerpf(_speed_fx_intensity, target, clampf(rate * delta, 0.0, 1.0))

	if speed_lines_material != null:
		speed_lines_material.set_shader_parameter(
			speed_lines_density_param,
			_speed_fx_intensity * speed_lines_max_density
		)

	# wind stays tied to intensity
	if _wind_player != null and _wind_player.stream != null:
		if _speed_fx_intensity > wind_start_threshold:
			if not _wind_player.playing:
				_wind_player.play()
		else:
			if _wind_player.playing and _wind_player.volume_db <= (wind_min_db + 0.5):
				_wind_player.stop()

		var target_db := lerpf(wind_min_db, wind_max_db, _speed_fx_intensity)
		var target_pitch := lerpf(wind_min_pitch, wind_max_pitch, _speed_fx_intensity)
		_wind_player.volume_db = lerpf(_wind_player.volume_db, target_db, clampf(wind_lerp * delta, 0.0, 1.0))
		_wind_player.pitch_scale = lerpf(_wind_player.pitch_scale, target_pitch, clampf(wind_lerp * delta, 0.0, 1.0))

func _update_slide_loop(delta: float) -> void:
	if _slide_loop_player == null or _slide_loop_player.stream == null:
		return

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()

	var should_play := (_state == MoveState.SLIDE and speed >= slide_loop_start_speed)

	if should_play:
		if not _slide_loop_player.playing:
			_slide_loop_player.play()

		# map speed -> 0..1 (reuse your speed lines range for a good feel)
		var t := 0.0
		if speed > speed_lines_normal_speed:
			t = inverse_lerp(speed_lines_normal_speed, speed_lines_full_speed, speed)
		t = clampf(t, 0.0, 1.0)

		var target_db := lerpf(slide_loop_min_db, slide_loop_max_db, t)
		var target_pitch := lerpf(slide_loop_min_pitch, slide_loop_max_pitch, t)

		_slide_loop_player.volume_db = lerpf(_slide_loop_player.volume_db, target_db, clampf(slide_loop_lerp * delta, 0.0, 1.0))
		_slide_loop_player.pitch_scale = lerpf(_slide_loop_player.pitch_scale, target_pitch, clampf(slide_loop_lerp * delta, 0.0, 1.0))
	else:
		# fade out then stop
		_slide_loop_player.volume_db = lerpf(_slide_loop_player.volume_db, slide_loop_min_db, clampf(slide_loop_lerp * delta, 0.0, 1.0))
		if _slide_loop_player.playing and _slide_loop_player.volume_db <= (slide_loop_min_db + 0.5):
			_slide_loop_player.stop()
			_slide_loop_player.pitch_scale = slide_loop_min_pitch

func add_xp(amount: int) -> void:
	if level_system == null:
		push_error("PlayerController.add_xp(): level_system is null.")
		return
	level_system.add_xp(amount)

# --- wiring/validation ---

func _autowire() -> void:
	if head == null:
		head = get_node_or_null("Head") as Node3D
	if camera == null:
		camera = _find_child_by_type(self, Camera3D) as Camera3D

	if stats == null:
		stats = _find_child_by_type(self, PlayerStats) as PlayerStats
		if stats == null:
			stats = get_node_or_null("PlayerStats") as PlayerStats

	if level_system == null:
		level_system = _find_child_by_type(self, LevelSystem) as LevelSystem
		if level_system == null:
			level_system = get_node_or_null("LevelSystem") as LevelSystem

func _validate_refs() -> bool:
	var ok := true
	if head == null:
		push_error("PlayerController: head not assigned/found.")
		ok = false
	if camera == null:
		push_error("PlayerController: camera not assigned/found.")
		ok = false
	if level_system == null:
		push_error("PlayerController: level_system not assigned/found.")
		ok = false
	return ok

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
