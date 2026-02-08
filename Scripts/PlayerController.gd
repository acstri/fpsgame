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

var _yaw := 0.0
var _pitch := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_autowire()
	if not _validate_refs():
		set_process(false)
		set_physics_process(false)
		return

	_yaw = rotation.y
	_pitch = head.rotation.x

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
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.1

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		var jmult := stats.jump_mult if stats != null else 1.0
		velocity.y = jump_velocity * jmult


	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var mult := stats.move_speed_mult if stats != null else 1.0

	var target_speed := walk_speed * mult
	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed * mult

	if is_on_floor():
		if input_vec.length() > 0.0:
			var target_vel := wish_dir * target_speed
			velocity.x = move_toward(velocity.x, target_vel.x, ground_accel * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, ground_accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
			velocity.z = move_toward(velocity.z, 0.0, ground_decel * delta)
	else:
		var air_target := wish_dir * target_speed
		velocity.x = move_toward(velocity.x, air_target.x, air_accel * delta)
		velocity.z = move_toward(velocity.z, air_target.z, air_accel * delta)

		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if flat.length() > max_air_speed:
			flat = flat.normalized() * max_air_speed
			velocity.x = flat.x
			velocity.z = flat.z

	move_and_slide()

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
