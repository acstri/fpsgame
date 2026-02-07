extends Node3D
class_name MM_SpellProjectile

@export_group("Lifetime")
@export var max_lifetime: float = 4.0

@export_group("Phases")
@export var arm_time: float = 0.18 # slow, no tracer
@export var start_speed: float = 6.0

@export_group("Homing")
@export var acquire_radius: float = 9999.0
@export var turn_rate_deg: float = 540.0
@export var retarget_if_lost: bool = true

@export_group("Acceleration")
@export var accel: float = 220.0 # units/s^2 until reaching top speed

@export_group("Tracer")
@export var tracer_path: NodePath = ^"Tracer"

@export_group("Targeting")
@export var aim_point_path: NodePath = ^"AimPoint"
@export var fallback_aim_height: float = 1.0

# Values passed from spawner
var hit_mask: int = 5
var damage: float = 0.0
var caster: Node = null
var max_distance: float = 120.0

# We'll treat the spawner's speed as "top speed"
var top_speed: float = 55.0

# Internal state
var _configured := false
var _life: float = 0.0
var _traveled: float = 0.0
var _armed: bool = false
var _speed: float = 0.0
var _dir: Vector3 = Vector3.FORWARD
var _target: Node3D = null

@onready var _tracer: GPUParticles3D = get_node_or_null(tracer_path) as GPUParticles3D

func setup(p_damage: float, p_direction: Vector3, p_caster: Node, p_speed: float, p_max_distance: float, p_hit_mask: int) -> void:
	damage = p_damage
	caster = p_caster
	top_speed = p_speed
	max_distance = p_max_distance
	hit_mask = p_hit_mask
	_dir = p_direction.normalized()
	_configured = true

func _ready() -> void:
	_speed = start_speed
	if _tracer:
		_tracer.emitting = false

	# Fail fast: projectile should never exist without setup.
	# This turns “silent weird behavior” into an obvious warning.
	if not _configured:
		push_warning("MM_SpellProjectile: setup() was not called. Freeing projectile to avoid undefined behavior.")
		queue_free()

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= max_lifetime:
		queue_free()
		return

	# Arm: acquire nearest enemy and enable tracer
	if not _armed and _life >= arm_time:
		_armed = true
		_target = _find_nearest_enemy()
		if _tracer:
			_tracer.emitting = true

	# Armed: accelerate and home
	if _armed:
		_speed = minf(top_speed, _speed + accel * delta)

		if (_target == null or not is_instance_valid(_target)) and retarget_if_lost:
			_target = _find_nearest_enemy()

		if _target != null and is_instance_valid(_target):
			var aim_pos := _get_target_point(_target)
			var desired := (aim_pos - global_position).normalized()
			_dir = _steer_toward(_dir, desired, delta)

	# Move with ray-marched collision (prevents tunneling)
	var from := global_position
	var to := from + _dir * _speed * delta

	_traveled += from.distance_to(to)
	if _traveled >= max_distance:
		queue_free()
		return

	var hit := _raycast(from, to)
	if hit.is_empty():
		global_position = to
		return

	if hit.has("position"):
		global_position = hit["position"]

	# Use shared utility to keep damage logic consistent across hitscan/projectiles
	SpellUtil.apply_damage_from_hit(hit, damage)
	queue_free()

func _steer_toward(current_dir: Vector3, desired_dir: Vector3, delta: float) -> Vector3:
	var max_rad := deg_to_rad(turn_rate_deg) * delta
	var angle := current_dir.angle_to(desired_dir)
	if angle <= max_rad:
		return desired_dir

	var t: float = max_rad / max(angle, 0.0001)
	return current_dir.slerp(desired_dir, t).normalized()

func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	# Prefer Node3D world if available; fallback to viewport world
	var world: World3D = get_world_3d()
	if world == null:
		world = get_viewport().get_world_3d()
	if world == null:
		return {}

	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = hit_mask
	q.collide_with_areas = true
	q.collide_with_bodies = true

	var ex := _exclude_rids()
	if not ex.is_empty():
		q.exclude = ex

	return space.intersect_ray(q)

func _exclude_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if caster == null:
		return rids

	# Best case: caster is a CollisionObject3D
	if caster is CollisionObject3D:
		rids.append((caster as CollisionObject3D).get_rid())
		return rids

	# Fallback: if node provides get_rid()
	if caster.has_method("get_rid"):
		var rid = caster.call("get_rid")
		if rid is RID:
			rids.append(rid)
	return rids

func _find_nearest_enemy() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best: Node3D = null
	var best_d2 := INF
	var r2 := acquire_radius * acquire_radius

	for e in enemies:
		if not (e is Node3D):
			continue
		if not is_instance_valid(e):
			continue
		var d2 := global_position.distance_squared_to((e as Node3D).global_position)
		if d2 < best_d2 and d2 <= r2:
			best_d2 = d2
			best = e as Node3D

	return best

func _get_target_point(enemy: Node3D) -> Vector3:
	# 1) Explicit marker: Enemy/AimPoint (Marker3D)
	var aim := enemy.get_node_or_null(aim_point_path)
	if aim != null and aim is Node3D:
		return (aim as Node3D).global_position

	# 2) Health node often sits near center
	var health := enemy.get_node_or_null(^"Health")
	if health != null and health is Node3D:
		return (health as Node3D).global_position

	# 3) Otherwise lift root position so we don't aim at feet
	return enemy.global_position + Vector3.UP * fallback_aim_height
