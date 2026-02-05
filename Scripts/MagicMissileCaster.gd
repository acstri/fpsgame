extends Node
class_name MagicMissileCaster

@export var hitscan: HitscanSpell
@export var projectile_spell: ProjectileSpell
@export var spell: SpellData
@export var automatic := true

var _cd_left := 0.0

func _physics_process(delta: float) -> void:
	_cd_left = maxf(0.0, _cd_left - delta)

	var wants_cast := Input.is_action_pressed("fire") if automatic else Input.is_action_just_pressed("fire")
	if wants_cast:
		try_cast()

func try_cast() -> void:
	if spell == null:
		return
	if _cd_left > 0.0:
		return

	_cd_left = maxf(0.01, spell.cooldown)

	# Prefer projectile if assigned
	if projectile_spell != null:
		projectile_spell.cast(spell.damage, spell.spell_range, spell.spread_deg)
		return

	# Fallback to hitscan
	if hitscan != null:
		hitscan.cast(spell.damage, spell.spell_range, spell.spread_deg)
