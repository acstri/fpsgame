extends CharacterBody3D
class_name PlayerController

@export_group("References")
@export var head: Node3D
@export var camera: Camera3D
@export var stats: PlayerStats
# Optional override; if null, will be found under the player
@export var level_system: LevelSystem

@export_group("Look")
@export var mouse_sensitivity := 0.0025
@export var pitch_min_deg := -65
@export var pitch_max_deg := 65

@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var gravity := 18.0
@export var ground_accel := 40.0
@export var ground_decel := 70.0
@export var air_accel := 18.0
@export var max_air_speed := 8.0

@export_group("Sprint Sticky (press to start, stop moving to cancel)")
@export var sprint_action := "sprint"
@export var sprint_cancels_on_no_input := true
var _sprint_latched := false

@export_group("Jump Momentum (farther jump when faster)")
@export var jump_horizontal_per_speed := 0.12   # extra horizontal m/s per 1 m/s of current horizontal speed
@export var jump_horizontal_max := 5.0          # cap for extra horizontal boost
@export var jump_dir_prefers_velocity := true   # use current velocity direction (good for slide-jumps)

@export_group("Slide (duration scales with start speed)")
@export var slide_action := "crouch"
@export var slide_min_speed := 6.0
@export var slide_base_duration := 0.35
@export var slide_duration_per_speed := 0.06
@export var slide_max_duration := 1.25
@export var slide_friction := 16.0
@export var slide_steer := 4.0
@export var slide_boost := 1.05
@export var slide_end_speed := 2.0
@export var slide_cooldown := 0.35

@export_group("Slide Slopes")
@export var slide_slope_accel := 14.0
@export var slide_slope_max_speed := 20.0
@export var slide_slope_min_angle_deg := 3.0

@export_group("Slide Camera")
@export var slide_camera_drop := 0.45
@export var slide_camera_lerp_speed := 12.0

enum MoveState { GROUND, AIR, SLIDE }
var _state: MoveState = MoveState.GROUND

var _yaw := 0.0
var _pitch := 0.0

# Slide runtime
var _slide_time_left := 0.0
var _slide_cd_left := 0.0

# Head baseline
var _head_base_pos: Vector3

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

	# timers
	if _slide_cd_left > 0.0:
		_slide_cd_left = maxf(0.0, _slide_cd_left - delta)

	# input
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var has_move_input := input_vec.length() > 0.0
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	# Sprint latch behavior:
	# - If moving and you press sprint => latch on
	# - Pressing sprint again does nothing (stays on)
	# - If you stop moving => latch off (optional)
	if Input.is_action_just_pressed(sprint_action) and has_move_input:
		_sprint_latched = true
	if sprint_cancels_on_no_input and not has_move_input:
		_sprint_latched = false

	# Effective speed multiplier (your existing stats integration)
	var mult := stats.move_speed_mult if stats != null else 1.0
	var target_speed := (sprint_speed if _sprint_latched else walk_speed) * mult

	# Gravity / floor stick
	if not was_on_floor:
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.1

	# Slide trigger (only meaningful from ground)
	if Input.is_action_just_pressed(slide_action):
		_try_start_slide(was_on_floor)

	# Jump (state-aware) – farther jump when faster
	if was_on_floor and Input.is_action_just_pressed("jump"):
		_do_jump(wish_dir)

	# Tick current movement state (horizontal control)
	match _state:
		MoveState.SLIDE:
			_tick_slide(delta, wish_dir, was_on_floor)
		MoveState.AIR:
			_tick_air(delta, wish_dir, target_speed)
		MoveState.GROUND:
			_tick_ground(delta, input_vec, wish_dir, target_speed, was_on_floor)

	_update_slide_camera(delta)

	move_and_slide()

	# Post-move state transitions based on new floor result
	var now_on_floor := is_on_floor()
	_post_update_state(now_on_floor)

func _tick_ground(delta: float, input_vec: Vector2, wish_dir: Vector3, target_speed: float, on_floor: bool) -> void:
	if not on_floor:
		_state = MoveState.AIR
		return

	if input_vec.length() > 0.0:
		var target_vel := wish_dir * target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, ground_accel * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, ground_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_decel * delta)

func _tick_air(delta: float, wish_dir: Vector3, target_speed: float) -> void:
	var air_target := wish_dir * target_speed
	velocity.x = move_toward(velocity.x, air_target.x, air_accel * delta)
	velocity.z = move_toward(velocity.z, air_target.z, air_accel * delta)

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > max_air_speed:
		flat = flat.normalized() * max_air_speed
		velocity.x = flat.x
		velocity.z = flat.z

func _tick_slide(delta: float, wish_dir: Vector3, on_floor: bool) -> void:
	_slide_time_left -= delta

	# If you leave the floor while sliding, go to air
	if not on_floor:
		_state = MoveState.AIR
		return

	# friction on horizontal velocity
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	if speed > 0.0:
		var new_speed := maxf(0.0, speed - slide_friction * delta)
		hv = hv.normalized() * new_speed

	# downhill acceleration while sliding
	var n := get_floor_normal().normalized()
	var angle := rad_to_deg(acos(clampf(n.dot(Vector3.UP), -1.0, 1.0)))
	if angle >= slide_slope_min_angle_deg:
		var downhill := (Vector3.DOWN - n * Vector3.DOWN.dot(n))
		if downhill.length_squared() > 0.000001:
			downhill = downhill.normalized()
			hv += downhill * slide_slope_accel * delta
			# cap
			var capped := minf(hv.length(), slide_slope_max_speed)
			if hv.length() > 0.0:
				hv = hv.normalized() * capped

	# limited steering
	if wish_dir.length_squared() > 0.0 and hv.length_squared() > 0.0:
		var hv_dir := hv.normalized()
		var t := clampf(slide_steer * delta, 0.0, 1.0)
		var steered := hv_dir.slerp(wish_dir, t)
		hv = steered * hv.length()

	velocity.x = hv.x
	velocity.z = hv.z

	# end conditions
	if _slide_time_left <= 0.0 or hv.length() <= slide_end_speed:
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

	# duration scales with start speed
	var extra_speed := maxf(0.0, speed - slide_min_speed)
	var dur := slide_base_duration + extra_speed * slide_duration_per_speed
	_slide_time_left = clampf(dur, slide_base_duration, slide_max_duration)

	# optional boost at start (keeps momentum feel)
	if speed > 0.0:
		var dir := hv.normalized()
		velocity.x = dir.x * speed * slide_boost
		velocity.z = dir.z * speed * slide_boost

func _do_jump(wish_dir: Vector3) -> void:
	# jumping cancels slide state, but keeps momentum (and uses it for farther jumps)
	if _state == MoveState.SLIDE:
		_state = MoveState.AIR

	var jmult := stats.jump_mult if stats != null else 1.0

	# far-jump boost based on current horizontal speed
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	var extra := clampf(speed * jump_horizontal_per_speed, 0.0, jump_horizontal_max)

	var dir := wish_dir
	if jump_dir_prefers_velocity and hv.length_squared() > 0.0001:
		dir = hv.normalized()
	elif dir.length_squared() < 0.0001 and hv.length_squared() > 0.0001:
		dir = hv.normalized()

	if dir.length_squared() > 0.0001 and extra > 0.0:
		velocity.x += dir.x * extra
		velocity.z += dir.z * extra

	velocity.y = jump_velocity * jmult

func _post_update_state(on_floor: bool) -> void:
	# If we landed, snap to ground unless we're actively sliding.
	if on_floor:
		if _state == MoveState.AIR:
			_state = MoveState.GROUND
	else:
		if _state == MoveState.GROUND:
			_state = MoveState.AIR

func _update_slide_camera(delta: float) -> void:
	if head == null:
		return

	var target := _head_base_pos
	if _state == MoveState.SLIDE:
		target.y = _head_base_pos.y - slide_camera_drop

	head.position = head.position.lerp(target, clampf(slide_camera_lerp_speed * delta, 0.0, 1.0))

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
