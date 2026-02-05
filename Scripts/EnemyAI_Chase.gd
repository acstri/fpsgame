extends CharacterBody3D
class_name EnemyAI_Chase

@export_group("Target")
@export var player_group := "player"

@export_group("Movement")
@export var move_speed := 3.5
@export var acceleration := 12.0
@export var gravity := 18.0
@export var stop_distance := 1.4

@export_group("Rotation")
@export var turn_speed := 10.0 # higher = snappier
@export var face_movement := true

@export_group("Cheat Climb")
@export var climb_speed := 18          # stronger = climbs tall walls
@export var climb_max_up_speed := 14   # terminal upward speed
@export var blocked_speed_threshold := 0.35
@export var blocked_time_to_climb := 0.12
@export var climb_gravity_mult := 0.2    # reduce gravity while climbing
@export var max_climb_height_above_player := 20
@export var climb_linger := 0.6     # seconds to keep climbing after getting unblocked
@export var climb_start_time := 0.15
var climbing := _climb_t > 0.0

var _blocked_t := 0.0
var _climb_t := 0.0
var _target: Node3D

func _ready() -> void:
	_target = _find_player()

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = _find_player()
		return

	var to_player := _target.global_transform.origin - global_transform.origin
	to_player.y = 0.0

	var dist := to_player.length()

	var desired := Vector3.ZERO
	if dist > stop_distance or climbing:
		if dist > 0.001:
			desired = to_player.normalized() * move_speed

	# Accelerate smoothly (prevents jitter)
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)

	# Rotate to face movement or player
	if face_movement:
		var flat_vel := Vector3(velocity.x, 0.0, velocity.z)
		if flat_vel.length() > 0.05:
			_rotate_towards(flat_vel.normalized(), delta)
	else:
		if dist > 0.001:
			_rotate_towards(to_player.normalized(), delta)


	# --- CHEAT CLIMB (chaotic, with hysteresis) ---
	var desired_flat := desired.length()
	var vel_flat := Vector3(velocity.x, 0.0, velocity.z).length()

	if desired_flat > 0.1 and vel_flat < blocked_speed_threshold:
		_blocked_t += delta
	else:
		_blocked_t = maxf(0.0, _blocked_t - delta * 1.5)

	if _blocked_t >= climb_start_time:
		_climb_t = climb_linger
	else:
		_climb_t = maxf(0.0, _climb_t - delta)

	var climbing_now := _climb_t > 0.0

# Gravity (weaker while climbing)
	if not is_on_floor():
		var g := gravity * (climb_gravity_mult if climbing_now else 1.0)
		velocity.y -= g * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.1

	# Climb boost (only while climbing)
	if climbing_now:
		if global_position.y <= _target.global_position.y + max_climb_height_above_player:
			velocity.y = minf(velocity.y + climb_speed * delta, climb_max_up_speed)



	move_and_slide()

func _rotate_towards(dir: Vector3, delta: float) -> void:
	# Godot forward is -Z, so we look in -dir
	var target_basis: Basis = Basis.looking_at(-dir, Vector3.UP)
	var target_yaw := target_basis.get_euler().y
	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))

func _find_player() -> Node3D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(player_group)
	if nodes.is_empty():
		return null
	return nodes[0] as Node3D
