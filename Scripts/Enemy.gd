extends CharacterBody3D
class_name Enemy

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
@export var climb_speed := 18.0
@export var climb_max_up_speed := 14.0
@export var blocked_speed_threshold := 0.35
@export var climb_start_time := 0.15
@export var climb_linger := 0.6
@export var climb_gravity_mult := 0.2
@export var max_climb_height_above_player := 20.0

@export_group("Refs (optional overrides)")
@export var health: EnemyHealth

var _target: Node3D
var _blocked_t := 0.0
var _climb_t := 0.0
var _ready_ok := false

func _ready() -> void:
	add_to_group("enemy")
	_autowire()
	_ready_ok = _validate_refs()
	_target = _find_player()

func apply_damage(amount: float, hit := {}) -> void:
	if health != null:
		health.apply_damage(amount, hit)

func _physics_process(delta: float) -> void:
	if not _ready_ok:
		return

	# Reacquire target as needed
	if _target == null or not is_instance_valid(_target):
		_target = _find_player()

	# If still no target, just idle with gravity so enemies don't float
	if _target == null:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			if velocity.y < 0.0:
				velocity.y = -0.1

		move_and_slide()
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	var want_move := dist > stop_distance
	var desired_vel := Vector3.ZERO
	if want_move and dist > 0.001:
		desired_vel = to_target.normalized() * move_speed

	# Smooth accel in XZ
	velocity.x = move_toward(velocity.x, desired_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_vel.z, acceleration * delta)

	# Detect "blocked" (want to move but not moving much)
	var desired_flat := desired_vel.length()
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

	# Climb boost
	if climbing_now and global_position.y <= _target.global_position.y + max_climb_height_above_player:
		velocity.y = minf(velocity.y + climb_speed * delta, climb_max_up_speed)

	# Rotation
	if face_movement:
		var flat_vel := Vector3(velocity.x, 0.0, velocity.z)
		if flat_vel.length() > 0.05:
			_rotate_towards(flat_vel.normalized(), delta)
	else:
		if dist > 0.001:
			_rotate_towards(to_target.normalized(), delta)

	move_and_slide()

func _rotate_towards(dir: Vector3, delta: float) -> void:
	var target_basis: Basis = Basis.looking_at(-dir, Vector3.UP)
	var target_yaw := target_basis.get_euler().y
	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))

func _find_player() -> Node3D:
	var nodes := get_tree().get_nodes_in_group(player_group)
	return null if nodes.is_empty() else nodes[0] as Node3D

func _autowire() -> void:
	if health == null:
		health = _find_child_by_type(self, EnemyHealth) as EnemyHealth
		if health == null:
			health = get_node_or_null("Health") as EnemyHealth

func _validate_refs() -> bool:
	if health == null:
		push_error("Enemy: EnemyHealth not found (assign export 'health' or add child named 'Health' with EnemyHealth).")
		return false
	return true

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
