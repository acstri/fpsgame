extends Node3D
class_name SpellProjectile

@export var max_lifetime: float = 3.0

var speed: float = 35.0
var hit_mask: int = 5
var damage: float = 0.0
var caster: Node = null
var max_distance: float = 120.0

var _life: float = 0.0
var _traveled: float = 0.0
var _velocity: Vector3 = Vector3.ZERO

func setup(p_damage: float, p_direction: Vector3, p_caster: Node, p_speed: float, p_max_distance: float, p_hit_mask: int) -> void:
	damage = p_damage
	caster = p_caster
	speed = p_speed
	max_distance = p_max_distance
	hit_mask = p_hit_mask
	_velocity = p_direction.normalized() * speed

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= max_lifetime:
		queue_free()
		return

	var from := global_position
	var to := from + _velocity * delta

	_traveled += from.distance_to(to)
	if _traveled >= max_distance:
		queue_free()
		return

	var world := get_viewport().get_world_3d()
	if world == null:
		global_position = to
		return

	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = hit_mask
	q.collide_with_areas = true
	q.collide_with_bodies = true
	if caster != null:
		q.exclude = [caster]

	var hit := space.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return

	if hit.has("position"):
		global_position = hit["position"]

	_apply_damage_from_hit(hit, damage)
	queue_free()

func _apply_damage_from_hit(hit: Dictionary, amount: float) -> void:
	var collider: Object = hit.get("collider")
	if collider == null:
		return

	# Preferred: your Enemy scene has a child node named "Health" with apply_damage()
	if collider is Node:
		var n := collider as Node

		var h := n.get_node_or_null("Health")
		if h != null and h.has_method("apply_damage"):
			h.callv("apply_damage", [amount, hit])
			return

		var p := n.get_parent()
		if p != null:
			var hp := p.get_node_or_null("Health")
			if hp != null and hp.has_method("apply_damage"):
				hp.callv("apply_damage", [amount, hit])
				return

	# Fallback: direct apply_damage on collider/parent if present
	if collider.has_method("apply_damage"):
		collider.callv("apply_damage", [amount, hit])
		return

	if collider is Node:
		var parent := (collider as Node).get_parent()
		if parent != null and parent.has_method("apply_damage"):
			parent.callv("apply_damage", [amount, hit])
