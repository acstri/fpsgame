extends Area3D
class_name EnemyMeleeDamage

@export var damage := 10.0
@export var hit_cooldown := 0.7
@export var target_group := "player"

var _cooldown := 0.0

func _ready() -> void:
	monitoring = true

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return

	for b in get_overlapping_bodies():
		if b is Node and (b as Node).is_in_group(target_group):
			var health := _find_child_by_type(b as Node, PlayerHealth) as PlayerHealth
			if health == null:
				# Fallback for current prototype compatibility
				health = (b as Node).get_node_or_null("Health") as PlayerHealth

			if health != null and health.has_method("apply_damage"):
				health.apply_damage(damage)
				_cooldown = hit_cooldown
				return

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
