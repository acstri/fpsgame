# res://Scripts/FireballProjectile.gd
# Camera shake now scales by distance from the explosion to the camera (approximation).
# - At the center: full shake
# - Far away: reduced or zero shake (configurable)

extends Node3D
class_name FireballProjectile

@export_group("Lifetime")
@export var max_lifetime: float = 4.0

@export_group("VFX")
@export var explosion_pulse_scene: PackedScene

@export_group("Knockback")
@export var knockback_enabled := true
@export var knockback_force := 22.0
@export var knockback_upward := 0.8
@export var knockback_use_falloff := true
@export_range(0.0, 1.0, 0.05) var knockback_falloff_min := 0.35

@export_group("Camera Shake")
@export var shake_enabled := true

# Base shake values (at 0 distance)
@export var shake_amplitude := 1.2
@export var shake_duration := 0.12
@export var shake_frequency := 30.0
@export var shake_pos_scale := 1.0
@export var shake_rot_scale := 1.0

# NEW: distance scaling
@export var shake_max_distance_mult := 4.0     # shake range = explosion_radius * this
@export_range(0.0, 1.0, 0.05) var shake_min_scale := 0.0  # scale when at/after max distance
@export var shake_use_smooth_falloff := true  # smoothstep vs linear

var hit_mask: int = 5
var damage: float = 0.0
var caster: Node = null
var max_distance: float = 120.0
var speed: float = 28.0

@export_group("Damage")
var explosion_radius: float = 3.5
@export_range(0.0, 5.0, 0.05) var aoe_damage_mult: float = 0.65

@export var use_falloff: bool = true
@export_range(0.0, 1.0, 0.05) var falloff_min: float = 0.25

var is_crit := false

var _configured := false
var _life := 0.0
var _traveled := 0.0
var _dir: Vector3 = Vector3.FORWARD

func setup(
	p_damage: float,
	p_direction: Vector3,
	p_caster: Node,
	p_speed: float,
	p_max_distance: float,
	p_hit_mask: int,
	p_explosion_radius: float,
	p_aoe_damage_mult: float,
	p_is_crit: bool = false
) -> void:
	damage = p_damage
	_dir = p_direction.normalized()
	caster = p_caster
	speed = p_speed
	max_distance = p_max_distance
	hit_mask = p_hit_mask
	explosion_radius = p_explosion_radius
	aoe_damage_mult = p_aoe_damage_mult
	is_crit = p_is_crit
	_configured = true

func _ready() -> void:
	if not _configured:
		push_warning("FireballProjectile: setup() was not called. Freeing projectile to avoid undefined behavior.")
		queue_free()

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= max_lifetime:
		queue_free()
		return

	var from := global_position
	var to := from + _dir * speed * delta

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

	_explode(global_position, hit)
	queue_free()

func _explode(pos: Vector3, direct_hit: Dictionary) -> void:
	_spawn_explosion_pulse(pos)
	_do_camera_shake(pos)

	# 1) Full damage to directly hit enemy (if any)
	var direct_collider = direct_hit.get("collider", null)
	if direct_collider != null:
		SpellUtil.apply_damage_from_hit(direct_hit, damage, is_crit, false)

	# 2) AoE damage + knockback in radius
	var enemies := get_tree().get_nodes_in_group("enemy")
	var r2 := explosion_radius * explosion_radius

	for e in enemies:
		if not (e is Node3D):
			continue
		if not is_instance_valid(e):
			continue

		var n := e as Node3D
		var d2 := n.global_position.distance_squared_to(pos)
		if d2 > r2:
			continue

		# AoE damage: skip the direct collider so it doesn't double-dip
		if e != direct_collider:
			var falloff := 1.0
			if use_falloff:
				var t := clampf(sqrt(d2) / maxf(0.001, explosion_radius), 0.0, 1.0)
				falloff = lerpf(1.0, falloff_min, t)

			var amount := damage * aoe_damage_mult * falloff
			var fake_hit := {"collider": n, "position": pos}
			SpellUtil.apply_damage_from_hit(fake_hit, amount, is_crit, false)

		if knockback_enabled:
			_apply_knockback(n, pos, d2)

func _apply_knockback(target: Node3D, origin: Vector3, dist2: float) -> void:
	var dir := (target.global_position - origin)
	if dir.length_squared() < 0.0001:
		dir = Vector3.UP
	dir = dir.normalized()
	dir.y += knockback_upward
	dir = dir.normalized()

	var strength := knockback_force
	if knockback_use_falloff:
		var t := clampf(sqrt(dist2) / maxf(0.001, explosion_radius), 0.0, 1.0)
		var f := lerpf(1.0, knockback_falloff_min, t)
		strength *= f

	if target is RigidBody3D:
		(target as RigidBody3D).apply_central_impulse(dir * strength)
		return

	if target.has_method("apply_knockback"):
		target.call("apply_knockback", dir * strength)
		return

	if target is CharacterBody3D:
		var cb := target as CharacterBody3D
		cb.velocity += dir * strength
		return

	if "velocity" in target:
		target.velocity += dir * strength
		return

func _do_camera_shake(explosion_pos: Vector3) -> void:
	if not shake_enabled:
		return

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var shaker := cam.get_node_or_null("CameraShake")
	if shaker == null:
		return
	if not shaker.has_method("shake"):
		return

	# Approximation: distance from explosion to camera position
	var d := cam.global_position.distance_to(explosion_pos)

	# Shake range relative to explosion radius
	var max_d := maxf(0.01, explosion_radius * maxf(0.1, shake_max_distance_mult))

	# 0 = at center, 1 = at/after max distance
	var t := clampf(d / max_d, 0.0, 1.0)

	# Convert to scale where 1.0 is strongest and shake_min_scale is weakest
	var shake_scale := 1.0 - t
	if shake_use_smooth_falloff:
		# smoothstep
		shake_scale = shake_scale * shake_scale * (3.0 - 2.0 * shake_scale)

	shake_scale = lerpf(shake_min_scale, 1.0, shake_scale)

	# If scale is effectively zero, skip shake.
	if shake_scale <= 0.001:
		return

	shaker.call(
		"shake",
		shake_amplitude * shake_scale,
		shake_duration * lerpf(0.7, 1.0, shake_scale), # optional: slightly shorter when weak
		shake_frequency,
		shake_pos_scale,
		shake_rot_scale
	)

func _spawn_explosion_pulse(pos: Vector3) -> void:
	if explosion_pulse_scene == null:
		return

	var fx := explosion_pulse_scene.instantiate()
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(fx)

	if fx is Node3D:
		(fx as Node3D).global_position = pos

	if fx.has_method("set_target_radius"):
		fx.call("set_target_radius", explosion_radius)

func _raycast(from: Vector3, to: Vector3) -> Dictionary:
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

	if caster is CollisionObject3D:
		rids.append((caster as CollisionObject3D).get_rid())
		return rids

	if caster.has_method("get_rid"):
		var rid = caster.call("get_rid")
		if rid is RID:
			rids.append(rid)

	return rids
