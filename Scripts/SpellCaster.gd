extends Node
class_name SpellCaster

@export var hitscan: HitscanSpell

@export_group("Active Spell (temporary)")
@export var cooldown := 0.35
@export var damage := 10.0
@export var spellrange := 120.0
@export var spread_deg := 0.0

var _cd_left := 0.0

func _physics_process(delta: float) -> void:
	_cd_left = maxf(0.0, _cd_left - delta)

	if Input.is_action_pressed("fire"):
		try_cast()

func try_cast() -> void:
	if hitscan == null:
		return
	if _cd_left > 0.0:
		return

	_cd_left = maxf(0.01, cooldown)
	hitscan.cast(damage, spellrange, spread_deg)
