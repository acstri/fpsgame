extends Node3D
class_name FireballProjectile

@export_group("Lifetime")
@export var max_lifetime: float = 4.0

@export_group("FX (optional)")
@export var mesh_path: NodePath = ^"MeshInstance3D"

var hit_mask: int = 5
var damage: float = 0.0
var caster: Node = null
var max_distance: float = 120.0
var speed: float = 28.0

var explosion_radius: float = 3.5
@export_range(0.0, 5.0, 0.05) var aoe_damage_mult: float = 0.65

# If true: AoE damage scales down with distance from explosion center.
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
	# 1) Apply FULL damage to the directly hit enemy (if any)
	var direct_collider = direct_hit.get("collider", null)
	if direct_collider != null:
		SpellUtil.apply_damage_from_hit(direct_hit, damage, is_crit, false)

	# 2) Apply AoE damage to other enemies in radius
	var enemies := get_tree().get_nodes_in_group("enemy")
	var r2 := explosion_radius * explosion_radius

	for e in enemies:
		if not (e is Node3D):
			continue
		if not is_instance_valid(e):
			continue
		if e == direct_collider:
			continue

		var n := e as Node3D
		var d2 := n.global_position.distance_squared_to(pos)
		if d2 > r2:
			continue

		var falloff := 1.0
		if use_falloff:
			var t := clampf(sqrt(d2) / maxf(0.001, explosion_radius), 0.0, 1.0)
			falloff = lerpf(1.0, falloff_min, t)

		var amount := damage * aoe_damage_mult * falloff
		var fake_hit := {"collider": n, "position": pos}
		SpellUtil.apply_damage_from_hit(fake_hit, amount, is_crit, false)

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
