extends CharacterBody3D
class_name PlayerController

# =========================================================
# References (exports; no hardcoded paths)
# =========================================================
@export_group("References")
@export var head: Node3D
@export var camera: Camera3D
@export var stats: PlayerStats
@export var level_system: LevelSystem

@export_group("Crouch References")
@export var capsule_collider: CollisionShape3D
@export var ceiling_check: ShapeCast3D

@export_group("Speed Lines (Shader)")
@export var speed_lines_material: ShaderMaterial
@export var speed_lines_density_param := "line_density"

@export_group("Grapple References")
@export var grapple_origin: Node3D
@export var grapple_ray: RayCast3D
@export var grapple_rope: Node3D

# =========================================================
# Look
# =========================================================
@export_group("Look")
@export var mouse_sensitivity := 0.0025
@export var pitch_min_deg := -65.0
@export var pitch_max_deg := 65.0

# =========================================================
# Movement
# =========================================================
@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var gravity := 18.0
@export var ground_accel := 40.0
@export var ground_decel := 70.0

@export_group("Air Control")
@export var air_accel := 18.0
@export var air_decel := 0.0
@export var max_air_speed := 8.0
@export var air_carry_decay := 0.0
@export var carry_speed_in_air := true

# =========================================================
# Jump
# =========================================================
@export_group("Jump")
@export var jump_velocity_base := 4.5
@export var jump_speed_ref := 6.0
@export var jump_velocity_per_speed := 0.10
@export var jump_velocity_max_bonus := 2.5

@export_group("Jump Buffer / Coyote")
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12

# =========================================================
# Sprint latch
# =========================================================
@export_group("Sprint Sticky")
@export var sprint_action := "sprint"
@export var sprint_cancels_on_no_input := true

# =========================================================
# Crouch / Slide
# =========================================================
@export_group("Crouch")
@export_range(0.2, 1.0, 0.01) var crouch_height_mult := 0.55
@export var crouch_lerp_speed := 12.0
@export var crouch_speed := 3.5
@export var crouch_action := "crouch"

@export_group("Slide")
@export var slide_action := "crouch"
@export var slide_min_speed := 6.0
@export var slide_friction := 10.0
@export var slide_steer := 4.0
@export var slide_boost := 1.05
@export var slide_end_speed := 2.0
@export var slide_cooldown := 0.35
@export var slide_burst_duration := 0.12
@export var slide_burst_accel := 30.0
@export var slide_burst_max_bonus := 4.0
@export var slide_buffer_time := 0.20
@export var slide_ground_snap_speed := 16.0
@export var slide_leave_ground_grace := 0.08
@export var slide_slope_accel := 14.0
@export var slide_slope_max_speed := 20.0
@export var slide_slope_min_angle_deg := 3.0

@export_group("Slide Camera")
@export var slide_camera_drop := 0.45
@export var slide_camera_lerp_speed := 12.0
@export_range(0.0, 30.0, 0.1) var slide_roll_max_deg := 10.0
@export var slide_roll_lerp := 14.0
@export var slide_roll_invert := false

# =========================================================
# Air strafe shaping
# =========================================================
@export_group("Air Strafing (Curve)")
@export var air_strafe_curve: Curve
@export var air_strafe_modifier := 1.0

# =========================================================
# Wallrun
# =========================================================
@export_group("Wallrun")
@export var wallrun_enabled := false
@export var wallrun_time := 1.6
@export var wallrun_height := 3.0
@export var wallrun_curve: Curve
@export var wallrun_min_speed := 6.0
@export var wallrun_reset_time := 0.6
@export var wallrun_stick_force := 2.0
@export var wallrun_steer := 4.0
@export var wallrun_jump_boost := 2.2

# =========================================================
# Camera juice
# =========================================================
@export_group("Camera Juice - FOV")
@export var fov_speed_start := 6.0
@export var fov_speed_end := 16.0
@export var fov_max_bonus_deg := 12.0
@export var fov_lerp_in := 10.0
@export var fov_lerp_out := 14.0

@export_group("Camera Juice - Headbob")
@export var headbob_amount := 0.06
@export var headbob_speed := 10.0
@export var headbob_lerp := 12.0

@export_group("Camera Juice - Impulse Spring")
@export var cam_impulse_jump := 0.6
@export var cam_impulse_land := 0.8
@export var cam_spring_freq := 18.0
@export var cam_spring_damp := 0.85

# =========================================================
# Speed lines
# =========================================================
@export_group("Speed Lines Tuning")
@export var speed_lines_normal_speed := 6.0
@export var speed_lines_full_speed := 16.0
@export var speed_lines_max_density := 1.0
@export var speed_lines_lerp_in := 10.0
@export var speed_lines_lerp_out := 14.0
@export var speed_lines_burst_bonus := 0.35
@export var speed_lines_burst_lerp := 18.0

# =========================================================
# Grapple (Quakelike-style + moving anchor)
# =========================================================
@export_group("Grapple")
@export var grapple_enabled := true
@export var grapple_action := "grapple_fire"
@export var grapple_max_distance := 60.0
@export var grapple_max_rest_fraction := 0.9
@export var grapple_min_rest_fraction := 0.4
@export var grapple_stiffness := 4.25
@export var grapple_damping := 2.5
@export var grapple_rest_curve: Curve
@export var grapple_rest_curve_length := 0.22
@export_range(0.0, 1.0, 0.01) var grapple_change_min_threshold := 0.8
@export var grapple_min_attach_distance := 2.0
@export var grapple_release_on_jump := false
@export var grapple_cancel_slide := true
@export var grapple_cancel_wallrun := true

@export_group("UI")
@export var pause_menu: PauseMenu
var survived_seconds: float = 0.0

# =========================================================
# Runtime: components + state machine
# =========================================================
var sm: PlayerStateMachine
var states: PlayerStates
var crouch: PlayerCrouch
var grapple: PlayerGrapple
var camera_juice: PlayerCameraJuice
var speed_fx: PlayerSpeedLinesFX

# =========================================================
# Runtime: input snapshot (read-only for states)
# =========================================================
var input_vec: Vector2 = Vector2.ZERO
var has_move_input: bool = false
var wish_dir: Vector3 = Vector3.ZERO
var target_speed: float = 0.0
var slide_held: bool = false
var jump_pressed: bool = false

# =========================================================
# Runtime: shared movement state variables (owned by controller, mutated by states)
# =========================================================
var sprint_latched: bool = false

var coyote_left: float = 0.0
var jump_buffer_left: float = 0.0

var slide_cd_left: float = 0.0
var slide_buffer_left: float = 0.0
var slide_leave_ground_left: float = 0.0
var slide_burst_left: float = 0.0
var slide_burst_dir: Vector3 = Vector3.ZERO
var slide_burst_added: float = 0.0

var air_speed_cap: float = 0.0

var wallrun_t: float = 0.0
var wallrun_side_left: bool = false
var has_left_wallrun: bool = false
var has_right_wallrun: bool = false
var wallrun_reset_left: float = 0.0
var wallrun_reset_right: float = 0.0
var wallrun_start_speed: float = 0.0

# =========================================================
# Runtime: crouch outputs (written by PlayerCrouch)
# =========================================================
var is_crouching: bool = false
var crouch_head_offset_y: float = 0.0

signal pause_requested

@export var ui_cancel_action := "ui_cancel"
# =========================================================
# Look runtime
# =========================================================
var _yaw: float = 0.0
var _pitch: float = 0.0

func state_name() -> StringName:
	return sm.current_name()

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_yaw = rotation.y
	_pitch = head.rotation.x if head != null else 0.0

	air_speed_cap = max_air_speed

	# init components
	crouch = PlayerCrouch.new()
	crouch.init_from(self)

	grapple = PlayerGrapple.new()
	grapple.init_from(self)

	camera_juice = PlayerCameraJuice.new()
	camera_juice.init_from(self)

	speed_fx = PlayerSpeedLinesFX.new()

	# init state machine
	states = PlayerStates.new()
	sm = PlayerStateMachine.new()
	sm.add_state(&"ground", PlayerStates.GroundState.new())
	sm.add_state(&"air", PlayerStates.AirState.new())
	sm.add_state(&"slide", PlayerStates.SlideState.new())
	sm.add_state(&"wallrun", PlayerStates.WallrunState.new())
	sm.add_state(&"grapple", PlayerStates.GrappleState.new())
	sm.set_state(self, &"ground")

	if pause_menu != null:
		pause_requested.connect(_on_pause_requested)
		pause_menu.continue_pressed.connect(_on_pause_continue)
		pause_menu.quit_pressed.connect(_on_pause_quit)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		rotation.y = _yaw

		_pitch = clamp(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg)
		)
		if head != null:
			head.rotation.x = _pitch

	if event.is_action_pressed(ui_cancel_action):
		emit_signal("pause_requested")
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		survived_seconds += delta
		
	var was_on_floor := is_on_floor()
	var pre_move_y_vel := velocity.y

	# timers
	_tick_timers(delta)

	# input snapshot
	input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	has_move_input = input_vec.length() > 0.0

	wish_dir = (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y))
	wish_dir = wish_dir.normalized() if wish_dir.length_squared() > 0.0001 else Vector3.ZERO

	slide_held = Input.is_action_pressed(slide_action)
	jump_pressed = Input.is_action_just_pressed("jump")
	var crouch_held := Input.is_action_pressed(crouch_action)
	var slide_pressed := Input.is_action_just_pressed(slide_action)

	# sprint latch
	if Input.is_action_just_pressed(sprint_action) and has_move_input:
		sprint_latched = true
	if sprint_cancels_on_no_input and not has_move_input:
		sprint_latched = false

	var mult := stats.move_speed_mult if stats != null else 1.0
	target_speed = (sprint_speed if sprint_latched else walk_speed) * mult

	# gravity (wallrun state owns y)
	if not was_on_floor and state_name() != &"wallrun":
		velocity.y -= gravity * delta
	elif was_on_floor and velocity.y < 0.0 and state_name() != &"wallrun":
		velocity.y = -0.1

	# buffers
	if jump_pressed:
		jump_buffer_left = jump_buffer_time
	if was_on_floor:
		coyote_left = coyote_time

	# grapple input (press launches, release retracts)
	if grapple_enabled:
		if Input.is_action_just_pressed(grapple_action) and not grapple.launched:
			if grapple.try_launch(self):
				sm.set_state(self, &"grapple")
		if Input.is_action_just_released(grapple_action) and grapple.launched:
			grapple.retract(self)
			sm.set_state(self, &"ground" if is_on_floor() else &"air")
		if grapple_release_on_jump and grapple.launched and jump_pressed:
			grapple.retract(self)
			sm.set_state(self, &"ground" if is_on_floor() else &"air")

	# slide start/buffer
	if slide_pressed:
		if was_on_floor:
			try_start_slide()
		else:
			slide_buffer_left = slide_buffer_time

	if slide_held and was_on_floor and state_name() == &"ground" and slide_cd_left <= 0.0:
		var hv0 := Vector3(velocity.x, 0.0, velocity.z)
		if hv0.length() >= slide_min_speed:
			try_start_slide()

	# crouch component (forces crouch during slide)
	crouch.tick(self, delta, crouch_held, state_name() == &"slide")
	crouch.apply_head(self, delta, slide_camera_drop if state_name() == &"slide" else 0.0)

	# consume jump
	var can_jump := was_on_floor or coyote_left > 0.0
	if jump_buffer_left > 0.0 and can_jump:
		jump_buffer_left = 0.0
		coyote_left = 0.0
		do_jump()

	# state update
	sm.physics_update(self, delta)

	# fx / camera juice
	speed_fx.tick(self, delta, state_name())
	camera_juice.tick(self, delta, input_vec, state_name())

	# move
	move_and_slide()

	var now_on_floor := is_on_floor()

	# slide buffer on landing
	if (not was_on_floor) and now_on_floor and slide_buffer_left > 0.0 and slide_held:
		slide_buffer_left = 0.0
		try_start_slide()

	# landing impulse
	if (not was_on_floor) and now_on_floor:
		camera_juice.apply_land_impulse(self, pre_move_y_vel)

	# rope visual
	grapple.update_rope_visual(self)

func _tick_timers(delta: float) -> void:
	slide_cd_left = maxf(0.0, slide_cd_left - delta)
	slide_buffer_left = maxf(0.0, slide_buffer_left - delta)
	slide_leave_ground_left = maxf(0.0, slide_leave_ground_left - delta)
	coyote_left = maxf(0.0, coyote_left - delta)
	jump_buffer_left = maxf(0.0, jump_buffer_left - delta)
	wallrun_reset_left = maxf(0.0, wallrun_reset_left - delta)
	wallrun_reset_right = maxf(0.0, wallrun_reset_right - delta)

# =========================================================
# API used by states
# =========================================================
func capture_air_cap() -> void:
	if not carry_speed_in_air:
		air_speed_cap = max_air_speed
		return
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	air_speed_cap = max(max_air_speed, hv.length())

func horizontal_angle_deg(a: Vector3, b: Vector3) -> float:
	var aa := Vector3(a.x, 0.0, a.z)
	var bb := Vector3(b.x, 0.0, b.z)
	if aa.length_squared() < 0.0001 or bb.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(aa.angle_to(bb))

func wall_is_left(wall_normal: Vector3) -> bool:
	return wall_normal.dot(global_transform.basis.x) > 0.0

func start_wallrun(is_left: bool) -> void:
	wallrun_t = 0.0
	wallrun_side_left = is_left
	wallrun_start_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	if is_left:
		has_left_wallrun = true
	else:
		has_right_wallrun = true

func end_wallrun_to_air() -> void:
	if wallrun_side_left:
		wallrun_reset_left = wallrun_reset_time
	else:
		wallrun_reset_right = wallrun_reset_time
	wallrun_t = 0.0
	capture_air_cap()

func try_start_slide() -> void:
	if slide_cd_left > 0.0:
		return
	if not is_on_floor():
		return
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() < slide_min_speed:
		return
	sm.set_state(self, &"slide")

func do_jump() -> void:
	# leaving slide/wallrun prevents stacking
	if state_name() == &"slide":
		slide_burst_left = 0.0
		sm.set_state(self, &"air")
	elif state_name() == &"wallrun":
		end_wallrun_to_air()
		sm.set_state(self, &"air")

	capture_air_cap()

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	var over := maxf(0.0, speed - jump_speed_ref)
	var bonus := minf(over * jump_velocity_per_speed, jump_velocity_max_bonus)

	var jmult := stats.jump_mult if stats != null else 1.0
	velocity.y = (jump_velocity_base + bonus) * jmult
	camera_juice.apply_jump_impulse(self)

func add_xp(amount: int) -> void:
	if level_system == null:
		push_error("PlayerController.add_xp(): level_system is null.")
		return
	level_system.add_xp(amount)

func _on_pause_requested() -> void:
	if pause_menu == null:
		return

	if pause_menu.is_open():
		pause_menu.close()
	else:
		pause_menu.set_survival_seconds(survived_seconds)
		pause_menu.open()

func _on_pause_continue() -> void:
	if pause_menu != null:
		pause_menu.close()

func _on_pause_quit() -> void:
	# safest default: go back to main menu scene if you have one
	# otherwise just quit the game.
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().quit()
