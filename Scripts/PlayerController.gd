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

@export_group("Movement (Quake-like)")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var gravity := 18.0

# Quake-like accel model
@export var ground_accel := 65.0
@export var air_accel := 25.0
@export var air_control := 0.35 # 0..1 (higher = stronger steering in air)
@export var ground_friction := 8.0
@export var stop_speed := 3.0 # friction baseline
@export var max_air_speed := 999.0 # leave high; Quake-like movement doesn't hard-cap air speed

@export_group("Slide")
@export var slide_enabled := true
@export var slide_duration := 0.75
@export var slide_min_speed := 6.0
@export var slide_boost := 1.8
@export var slide_friction := 2.0          # lower than ground_friction
@export var slide_steer := 0.25            # 0..1 (how much you can steer while sliding)

@export_group("Headbob")
@export var headbob_enabled := true
@export var headbob_pivot: Node3D          # set to your camera pivot/head node; defaults to head
@export var bob_base_frequency := 7.0
@export var bob_speed_to_frequency := 0.05
@export var bob_base_amplitude := 0.03
@export var bob_speed_to_amplitude := 0.00035
@export var bob_lerp_in := 18.0
@export var bob_lerp_out := 12.0
@export var bob_disable_while_sliding := true

var _yaw := 0.0
var _pitch := 0.0

enum MoveMode { GROUND, AIR, SLIDE }
var _mode: int = MoveMode.GROUND

var _is_sliding := false
var _slide_time_left := 0.0

var _bob_t := 0.0
var _bob_offset := Vector3.ZERO
var _bob_base_local_pos := Vector3.ZERO
var _pivot: Node3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_autowire()
	if not _validate_refs():
		set_process(false)
		set_physics_process(false)
		return

	_yaw = rotation.y
	_pitch = head.rotation.x

	_pivot = headbob_pivot if headbob_pivot != null else head
	if _pivot != null:
		_bob_base_local_pos = _pivot.position

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
	var grounded := is_on_floor()

	# Gravity / floor stick
	if not grounded:
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.1

	# Input
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y))
	if wish_dir.length_squared() > 0.0001:
		wish_dir = wish_dir.normalized()
	else:
		wish_dir = Vector3.ZERO

	# Stats multipliers
	var move_mult := stats.move_speed_mult if stats != null else 1.0
	var jmult := stats.jump_mult if stats != null else 1.0

	var target_speed := walk_speed * move_mult
	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed * move_mult

	# Slide start (requires a "crouch" action; falls back to "sprint" if crouch doesn't exist)
	if slide_enabled and grounded and not _is_sliding:
		var slide_pressed := false
		if InputMap.has_action("crouch"):
			slide_pressed = Input.is_action_just_pressed("crouch")
		else:
			# fallback: tap sprint to slide (so it works immediately without action setup)
			slide_pressed = Input.is_action_just_pressed("sprint")

		if slide_pressed:
			_try_start_slide(target_speed)

	# Jump (Quake-like: jumping while sliding cancels slide)
	if grounded and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity * jmult
		if _is_sliding:
			_end_slide()
		grounded = false

	# Mode
	if _is_sliding:
		_mode = MoveMode.SLIDE
	elif grounded:
		_mode = MoveMode.GROUND
	else:
		_mode = MoveMode.AIR

	# Horizontal movement
	match _mode:
		MoveMode.GROUND:
			_apply_ground_move(delta, wish_dir, target_speed)
		MoveMode.AIR:
			_apply_air_move(delta, wish_dir, target_speed)
		MoveMode.SLIDE:
			_update_slide(delta, wish_dir)

	move_and_slide()

	# Slide end conditions after move (floor might change)
	if _is_sliding:
		_slide_time_left -= delta
		if _slide_time_left <= 0.0 or not is_on_floor():
			_end_slide()
		else:
			# stop if we slowed too much
			var flat_speed := Vector3(velocity.x, 0.0, velocity.z).length()
			if flat_speed < 1.0:
				_end_slide()

	# Headbob (camera pivot only)
	_update_headbob(delta)

# -------------------------
# Quake-like movement helpers
# -------------------------

func _apply_ground_move(delta: float, wish_dir: Vector3, target_speed: float) -> void:
	_apply_friction(delta, ground_friction)

	if wish_dir == Vector3.ZERO:
		return

	_accelerate(wish_dir, target_speed, ground_accel, delta)

func _apply_air_move(delta: float, wish_dir: Vector3, target_speed: float) -> void:
	if wish_dir == Vector3.ZERO:
		return

	# Quake-style air accel uses a wishspeed clamp; keep it at target_speed
	_accelerate(wish_dir, target_speed, air_accel, delta)

	# Optional air control: improves steering when moving forward-ish
	if air_control > 0.0:
		_apply_air_control(wish_dir, target_speed, delta)

	# Optional: if you still want a cap, set max_air_speed to a value; otherwise leave huge
	if max_air_speed < 999.0:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var s := flat.length()
		if s > max_air_speed:
			flat = flat.normalized() * max_air_speed
			velocity.x = flat.x
			velocity.z = flat.z

func _apply_friction(delta: float, friction: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var control := maxf(speed, stop_speed)
	var drop := control * friction * delta
	var new_speed := maxf(0.0, speed - drop)

	if new_speed == speed:
		return

	new_speed /= speed
	velocity.x *= new_speed
	velocity.z *= new_speed

func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	# Adds velocity in wish_dir until reaching wish_speed along that dir
	var current_speed := velocity.dot(wish_dir)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return

	var accel_speed := accel * wish_speed * delta
	if accel_speed > add_speed:
		accel_speed = add_speed

	velocity.x += wish_dir.x * accel_speed
	velocity.z += wish_dir.z * accel_speed

func _apply_air_control(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	# Simple Quake-like air control approximation
	# Only meaningful when player is trying to move; scales with air_control.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed < 0.001:
		return

	flat = flat.normalized()

	# How aligned we are with wish_dir
	var dot := flat.dot(wish_dir)
	if dot <= 0.0:
		return

	var k := air_control * dot * dot * 12.0 * delta
	var new_dir := (flat * speed).lerp(wish_dir * speed, k)
	velocity.x = new_dir.x
	velocity.z = new_dir.z

# -------------------------
# Slide
# -------------------------

func _try_start_slide(target_speed: float) -> void:
	if not is_on_floor():
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed < slide_min_speed:
		return

	_is_sliding = true
	_slide_time_left = slide_duration

	var dir := flat.normalized()
	# Small impulse forward (keeps momentum feel)
	velocity.x += dir.x * slide_boost
	velocity.z += dir.z * slide_boost

func _update_slide(delta: float, wish_dir: Vector3) -> void:
	# Slide keeps momentum, low friction, limited steering
	_apply_friction(delta, slide_friction)

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed < 0.001:
		return

	# Limited steering (only if there is input)
	if wish_dir != Vector3.ZERO:
		var desired := wish_dir * speed
		flat = flat.lerp(desired, slide_steer * delta)

	velocity.x = flat.x
	velocity.z = flat.z

func _end_slide() -> void:
	_is_sliding = false
	_slide_time_left = 0.0

# -------------------------
# Headbob
# -------------------------

func _update_headbob(delta: float) -> void:
	if not headbob_enabled or _pivot == null:
		return

	var grounded := is_on_floor()
	var flat_speed := Vector3(velocity.x, 0.0, velocity.z).length()

	var bob_allowed := grounded and flat_speed > 0.1
	if bob_disable_while_sliding and _is_sliding:
		bob_allowed = false

	if not bob_allowed:
		_bob_offset = _bob_offset.lerp(Vector3.ZERO, bob_lerp_out * delta)
		_pivot.position = _pivot.position.lerp(_bob_base_local_pos, bob_lerp_out * delta)
		return

	var freq := bob_base_frequency + flat_speed * bob_speed_to_frequency
	var amp := bob_base_amplitude + flat_speed * bob_speed_to_amplitude

	_bob_t += delta * freq
	var x := sin(_bob_t * 2.0) * amp
	var y = -abs(sin(_bob_t)) * amp

	_bob_offset.x = x
	_bob_offset.y = y

	var target := _bob_base_local_pos + _bob_offset
	_pivot.position = _pivot.position.lerp(target, bob_lerp_in * delta)

# -------------------------
# XP passthrough
# -------------------------

func add_xp(amount: int) -> void:
	# Fail-safe: don't crash if XP is awarded during teardown/restart.
	if level_system == null:
		push_error("PlayerController.add_xp(): level_system is null.")
		return
	level_system.add_xp(amount)

# --- wiring/validation ---

func _autowire() -> void:
	# Prefer explicit exports; otherwise locate by type under this player.
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

	if headbob_pivot == null:
		# default to head so it works without extra setup
		headbob_pivot = head

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
	# stats is allowed to be null (defaults to mult=1.0), so no hard fail.
	return ok

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
