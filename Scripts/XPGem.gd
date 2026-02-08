extends Area3D
class_name XPGem

@export var value := 1

@export_group("Attract")
@export var attract_distance := 7.0
@export var attract_speed := 9.0          # horizontal pull speed
@export var attract_accel := 22.0         # how quickly it reaches attract_speed

@export_group("Vertical motion")
@export var spawn_height := 1.2           # initial height above current position
@export var glide_down_speed := 2.2       # slow fall speed before first ground hit
@export var gravity_strength := 18.0
@export var max_fall_speed := 30.0

@export_group("Bounce")
@export var bounce_restitution := 0.45
@export var bounce_threshold := 2.0       # only bounce if impact speed is larger than this
@export var bounce_damping_xz := 0.75     # reduce sliding on bounce
@export var max_bounces := 3

@export_group("Hover")
@export var hover_height := 0.35
@export var bob_amp := 0.06
@export var bob_speed := 3.5

@export_group("Ground detection")
@export var ray_up := 1.2
@export var ray_down := 3.0
@export var ground_snap_eps := 0.05

var _player: Node3D
var _vel := Vector3.ZERO
var _bob_phase := 0.0
var _bounces := 0
var _touched_ground := false

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

	_player = get_tree().get_first_node_in_group("player") as Node3D
	_bob_phase = randf() * TAU

	# Spawn above and glide down
	global_position.y += spawn_height
	_vel.y = 0.0

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	# --- Horizontal attraction (ALWAYS allowed) ---
	var attracting := false
	if _player != null:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist <= attract_distance and dist > 0.001:
			attracting = true
			var desired_vx := (to_player / dist) * attract_speed
			_vel.x = move_toward(_vel.x, desired_vx.x, attract_accel * delta)
			_vel.z = move_toward(_vel.z, desired_vx.z, attract_accel * delta)
	# If not attracting, gently damp horizontal drift so it doesn't slide forever
	if not attracting:
		_vel.x = move_toward(_vel.x, 0.0, 10.0 * delta)
		_vel.z = move_toward(_vel.z, 0.0, 10.0 * delta)

	# --- Vertical: glide first, then gravity + bounce, then hover ---
	var hit := _raycast_down(global_position)
	if hit.is_empty():
		# Airborne
		if not _touched_ground:
			# initial glide (looks nicer than instant gravity)
			_vel.y = move_toward(_vel.y, -glide_down_speed, 10.0 * delta)
		else:
			_vel.y = maxf(-max_fall_speed, _vel.y - gravity_strength * delta)

		global_position += _vel * delta
		return

	# We have ground under us
	var ground_y: float = (hit.get("position", global_position) as Vector3).y
	var normal: Vector3 = hit.get("normal", Vector3.UP)

	# Detect impact (crossing into ground zone while moving down)
	var hover_target_y := ground_y + hover_height
	var y_next := global_position.y + _vel.y * delta

	var entering_ground := (y_next <= hover_target_y + ground_snap_eps) and (_vel.y < 0.0)

	if entering_ground:
		_touched_ground = true

		# Snap to hover band
		_bob_phase += delta * bob_speed * TAU
		var bob := sin(_bob_phase) * bob_amp
		global_position.y = hover_target_y + bob

		# Bounce only on meaningful impacts, limited count
		if _bounces < max_bounces and _vel.y < -bounce_threshold:
			_bounces += 1
			_vel = _vel.bounce(normal) * bounce_restitution
			_vel.x *= bounce_damping_xz
			_vel.z *= bounce_damping_xz
		else:
			_vel.y = 0.0
	else:
		# Not entering ground this frame: keep hovering smoothly
		_touched_ground = true
		_bob_phase += delta * bob_speed * TAU
		var bob2 := sin(_bob_phase) * bob_amp
		global_position.y = hover_target_y + bob2
		_vel.y = 0.0

	# Apply horizontal move after vertical placement
	global_position.x += _vel.x * delta
	global_position.z += _vel.z * delta

func _raycast_down(pos: Vector3) -> Dictionary:
	var world := get_viewport().get_world_3d()
	if world == null:
		return {}

	var from := pos + Vector3.UP * ray_up
	var to := pos + Vector3.DOWN * ray_down

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return world.direct_space_state.intersect_ray(q)

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("add_xp"):
		body.add_xp(value)
	queue_free()

func set_value(v: int) -> void:
	value = v
