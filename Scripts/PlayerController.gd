extends CharacterBody3D
class_name PlayerController

@export_group("References")
@export var head: Node3D
@export var camera: Camera3D

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

@onready var level_system: LevelSystem = $LevelSystem

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_yaw = rotation.y
	_pitch = head.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# yaw on body
		_yaw -= event.relative.x * mouse_sensitivity
		rotation.y = _yaw

		# pitch on head
		_pitch = clamp(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg)
		)
	

		head.rotation.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		# Toggle mouse capture for testing
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Small stick-to-floor so slopes feel better
		if velocity.y < 0.0:
			velocity.y = -0.1

	# Jump
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# Movement input
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var target_speed := walk_speed
	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed

	if is_on_floor():
		# Ground: very snappy
		if input_vec.length() > 0.0:
			var target_vel := wish_dir * target_speed
			velocity.x = move_toward(velocity.x, target_vel.x, ground_accel * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, ground_accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
			velocity.z = move_toward(velocity.z, 0.0, ground_decel * delta)
	else:
		# Air: keep control, but clamp speed so it doesn't explode
		var air_target := wish_dir * target_speed
		velocity.x = move_toward(velocity.x, air_target.x, air_accel * delta)
		velocity.z = move_toward(velocity.z, air_target.z, air_accel * delta)

		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var max_spd := max_air_speed
		if flat.length() > max_spd:
			flat = flat.normalized() * max_spd
			velocity.x = flat.x
			velocity.z = flat.z


	move_and_slide()
	
func add_xp(amount: int) -> void:
	level_system.add_xp(amount)
