extends Node
class_name EnemyHealth

signal damaged(amount: float, remaining: float, hit: Dictionary)
signal died(hit: Dictionary)

@export var max_hp := 30.0
@export var invulnerable := false

# Optional override: if you want to free a specific node on death
@export var death_owner: Node

var hp: float
var _dead := false

func _ready() -> void:
	hp = max_hp
	if death_owner == null:
		# Default behavior from your original script
		death_owner = get_owner()

func apply_damage(amount: float, hit: Dictionary = {}) -> void:
	if invulnerable or _dead:
		return
	if amount <= 0.0:
		return

	hp -= amount
	damaged.emit(amount, hp, hit)

	if hp <= 0.0:
		_die(hit)

func _die(hit: Dictionary) -> void:
	if _dead:
		return
	_dead = true

	died.emit(hit)

	if death_owner != null and is_instance_valid(death_owner):
		death_owner.queue_free()
	else:
		queue_free()
