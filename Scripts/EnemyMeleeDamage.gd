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
		if b is Node and b.is_in_group(target_group):
			var health := b.get_node_or_null("Health")
			if health != null and health.has_method("apply_damage"):
				health.apply_damage(damage)
				_cooldown = hit_cooldown
				return
