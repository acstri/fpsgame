extends Node
class_name SpellCaster

@export var hitscan: HitscanSpell
@export var projectile_spell: MagicMissile
@export var spell: SpellData
@export var automatic := true
@export var stats: PlayerStats

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

	var fire_mult := stats.fire_rate_mult if stats != null else 1.0
	_cd_left = maxf(0.01, spell.cooldown / maxf(0.001, fire_mult))

	var dmg := spell.damage * (stats.damage_mult if stats != null else 1.0)

	if projectile_spell != null:
		projectile_spell.cast(dmg, spell.spell_range, spell.spread_deg)
		return

	if hitscan != null:
		hitscan.cast(dmg, spell.spell_range, spell.spread_deg)
