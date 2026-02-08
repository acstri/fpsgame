extends Node3D
class_name FireballProjectile

@export_group("Lifetime")
@export var max_lifetime: float = 4.0

@export_group("VFX")
@export var explosion_pulse_scene: PackedScene

@export_group("Knockback")
@export var knockback_enabled := true
@export var knockback_force := 22.0        # increase for stronger push
@export var knockback_upward := 0.8        # adds lift (0 = flat)
@export var knockback_use_falloff := true  # weaker at edge of radius
@export_range(0.0, 1.0, 0.05) var knockback_falloff_min := 0.35

@export_group("Camera Shake")
@export var shake_enabled := true
@export var shake_amplitude := 1.2
@export var shake_duration := 0.12
@export var shake_frequency := 30.0
@export var shake_pos_scale := 1.0
@export var shake_rot_scale := 1.0

var hit_mask: int = 5
var damage: float = 0.0
var caster: Node = null
var max_distance: float = 120.0
var speed: float = 28.0

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
	_do_camera_shake()

	# 1) Full damage to directly hit enemy (if any)
	var direct_collider = direct_hit.get("collider", null)
	if direct_collider != null:
		SpellUtil.apply_damage_from_hit(direct_hit, damage, is_crit, false)

	# 2) AoE damage + knockback to others in radius
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

		# Knockback applies to everyone in radius (including direct target)
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

	# Try common patterns without requiring changes to enemy core:
	# 1) RigidBody3D impulse
	if target is RigidBody3D:
		(target as RigidBody3D).apply_central_impulse(dir * strength)
		return

	# 2) Dedicated method on enemy (optional)
	if target.has_method("apply_knockback"):
		target.call("apply_knockback", dir * strength)
		return

	# 3) CharacterBody3D velocity injection (common)
	if target is CharacterBody3D:
		var cb := target as CharacterBody3D
		cb.velocity += dir * strength
		return

	# 4) Generic "velocity" property injection
	if "velocity" in target:
		target.velocity += dir * strength
		return

func _do_camera_shake() -> void:
	if not shake_enabled:
		return

	# Look for a CameraShake node under the active camera.
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var shaker := cam.get_node_or_null("CameraShake")
	if shaker == null:
		return

	if shaker.has_method("shake"):
		shaker.call("shake", shake_amplitude, shake_duration, shake_frequency, shake_pos_scale, shake_rot_scale)

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

	# Match VFX start radius to gameplay explosion radius (your ExplosionPulse.gd supports this).
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
