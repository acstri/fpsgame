extends Node
class_name EnemyHealth

signal damaged(amount: float, remaining: float, hit: Dictionary)
signal died(hit: Dictionary)

@export var max_hp := 30.0
@export var invulnerable := false

var hp: float

@onready var owner_node: Node = get_owner()

func _ready() -> void:
	hp = max_hp

func apply_damage(amount: float, hit: Dictionary = {}) -> void:
	if invulnerable:
		return
	if amount <= 0.0:
		return

	hp -= amount
	damaged.emit(amount, hp, hit)

	if hp <= 0.0:
		_die(hit)

func _die(hit: Dictionary) -> void:
	died.emit(hit)

	# If you later want ragdoll, death anim, drops, etc.:
	# emit signal here and let other components react.
	if owner_node != null:
		owner_node.queue_free()
	else:
		queue_free()
