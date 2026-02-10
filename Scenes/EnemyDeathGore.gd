extends Node3D
class_name EnemyDeathGore

@export_group("Wiring")
@export var health: EnemyHealth

@export_group("Prefabs")
@export var chunk_scene: PackedScene
@export var pool_scene: PackedScene

@export_group("Chunks")
@export_range(0, 64, 1) var chunk_count := 6
@export var chunk_spawn_radius := 0.35
@export var chunk_impulse_min := 3.0
@export var chunk_impulse_max := 7.0
@export var chunk_upward_bias := 0.55
@export var chunk_torque_min := 0.5
@export var chunk_torque_max := 3.0
@export var chunk_lifetime := 6.0
@export var chunk_scale_range := Vector2(0.75, 1.25)

# Optional "anti-slide" tuning even if chunk scene has no script
@export var chunk_friction := 4.0          # requires physics material override
@export var chunk_linear_damp := 2.5
@export var chunk_angular_damp := 1.5

@export_group("Blood Pool")
@export var spawn_pool := true
@export_range(1, 16, 1) var pool_count := 3
@export var pool_spawn_radius := 0.6
@export var pool_scale_range := Vector2(0.85, 1.6)

@export var pool_lift := 0.01
@export var pool_random_yaw := true
@export var pool_ray_length := 6.0
@export var pool_collision_mask := 1

@export_group("Debug")
@export var enabled := true

var _wired := false

func _ready() -> void:
	if not enabled:
		return

	_autowire()
	if health == null:
		push_warning("EnemyDeathGore: EnemyHealth not found. Assign 'health' or add a child named 'Health' with EnemyHealth.")
		return

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)
	_wired = true

func _exit_tree() -> void:
	if _wired and health != null and is_instance_valid(health) and health.died.is_connected(_on_died):
		health.died.disconnect(_on_died)

func _autowire() -> void:
	if health != null:
		return

	var owner_node := get_owner()
	if owner_node != null:
		var h := owner_node.get_node_or_null("Health")
		if h is EnemyHealth:
			health = h

	if health == null:
		var h2 := get_node_or_null("../Health")
		if h2 is EnemyHealth:
			health = h2

func _on_died(hit: Dictionary) -> void:
	if not enabled:
		return

	var origin_pos := _get_death_position(hit)

	if spawn_pool and pool_scene != null:
		_spawn_pools(origin_pos)

	if chunk_scene != null and chunk_count > 0:
		_spawn_chunks(origin_pos)

func _get_death_position(hit: Dictionary) -> Vector3:
	if hit.has("position"):
		return hit.get("position")
	return global_position

func _world_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root

func _spawn_pools(origin_pos: Vector3) -> void:
	var parent := _world_parent()
	if parent == null:
		return

	for i in pool_count:
		var pool := pool_scene.instantiate()
		if pool == null:
			continue

		parent.add_child(pool)

		if pool is not Node3D:
			continue

		var offset := Vector3(
			randf_range(-pool_spawn_radius, pool_spawn_radius),
			0.0,
			randf_range(-pool_spawn_radius, pool_spawn_radius)
		)

		var t := _sample_ground_transform(origin_pos + offset)
		t.origin += t.basis.y * pool_lift

		if pool_random_yaw:
			var yaw := randf_range(-PI, PI)
			t.basis = t.basis.rotated(t.basis.y, yaw)

		(pool as Node3D).global_transform = t

		var s := _rand_scale(pool_scale_range)
		(pool as Node3D).scale *= Vector3.ONE * s

func _sample_ground_transform(origin_pos: Vector3) -> Transform3D:
	var world := get_world_3d()
	if world == null:
		return Transform3D(Basis.IDENTITY, origin_pos)

	var from := origin_pos + Vector3.UP * 1.0
	var to := origin_pos + Vector3.DOWN * pool_ray_length

	var space := world.direct_space_state
	if space == null:
		return Transform3D(Basis.IDENTITY, origin_pos)

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = pool_collision_mask
	q.exclude = []

	var res := space.intersect_ray(q)
	if res.is_empty():
		return Transform3D(Basis.IDENTITY, origin_pos)

	var p: Vector3 = res.get("position", origin_pos)
	var n: Vector3 = res.get("normal", Vector3.UP)
	if n.length_squared() < 0.0001:
		n = Vector3.UP

	var up := n.normalized()
	var forward := Vector3.FORWARD
	if absf(up.dot(forward)) > 0.95:
		forward = Vector3.RIGHT
	var right := up.cross(forward).normalized()
	forward = right.cross(up).normalized()
	var b := Basis(right, up, forward)
	return Transform3D(b, p)

func _spawn_chunks(origin_pos: Vector3) -> void:
	var parent := _world_parent()
	if parent == null:
		return

	for i in chunk_count:
		var c := chunk_scene.instantiate()
		if c == null:
			continue
		parent.add_child(c)

		if c is Node3D:
			var offset := Vector3(
				randf_range(-chunk_spawn_radius, chunk_spawn_radius),
				randf_range(0.05, chunk_spawn_radius),
				randf_range(-chunk_spawn_radius, chunk_spawn_radius)
			)
			(c as Node3D).global_position = origin_pos + offset

			var s := _rand_scale(chunk_scale_range)
			(c as Node3D).scale *= Vector3.ONE * s

		if c is RigidBody3D:
			var rb := c as RigidBody3D

			# Extra friction/damping to reduce ground sliding (still recommended to add the GoreChunk script below).
			rb.linear_damp = maxf(rb.linear_damp, chunk_linear_damp)
			rb.angular_damp = maxf(rb.angular_damp, chunk_angular_damp)

			var mat := PhysicsMaterial.new()
			mat.friction = chunk_friction
			mat.bounce = 0.0
			rb.physics_material_override = mat

			var dir := Vector3(
				randf_range(-1.0, 1.0),
				lerpf(0.2, 1.0, chunk_upward_bias),
				randf_range(-1.0, 1.0)
			).normalized()
			var strength := randf_range(chunk_impulse_min, chunk_impulse_max)
			rb.apply_central_impulse(dir * strength)

			var torque := Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized() * randf_range(chunk_torque_min, chunk_torque_max)
			rb.apply_torque_impulse(torque)

		if not (c.has_method("start_despawn") or c.has_method("arm_despawn")):
			_arm_despawn(c, chunk_lifetime)

func _rand_scale(r: Vector2) -> float:
	var a := minf(r.x, r.y)
	var b := maxf(r.x, r.y)
	return randf_range(a, b)

func _arm_despawn(n: Node, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	timer.timeout.connect(func():
		if n != null and is_instance_valid(n):
			n.queue_free()
	)
	n.add_child(timer)
	timer.start()
