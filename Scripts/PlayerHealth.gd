extends Node
class_name PlayerHealth

signal hp_changed(current: float, max_hp: float)
signal died()

@export var max_hp := 100.0
@export var invuln_time := 0.35

var hp: float
var _invuln := 0.0

func _ready() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)

func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)

func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if _invuln > 0.0:
		return

	hp = maxf(0.0, hp - amount)
	_invuln = invuln_time
	hp_changed.emit(hp, max_hp)

	if hp <= 0.0:
		died.emit()
