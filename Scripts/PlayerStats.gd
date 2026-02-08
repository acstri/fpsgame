extends Node
class_name PlayerStats

signal stats_changed()

# Multipliers (1.0 = baseline)
var damage_mult: float = 1.0
var fire_rate_mult: float = 1.0
var move_speed_mult: float = 1.0
var range_mult: float = 1.0
var spread_mult: float = 1.0          # >1 = more spread, <1 = tighter
var projectile_speed_mult: float = 1.0
var jump_mult: float = 1.0
var max_hp_mult: float = 1.0
var hp_regen_per_sec: float = 0.0  # flat HP/sec
var extra_projectiles: int = 0

# Additive / chance stats
var crit_chance: float = 0.0          # 0..1
var crit_mult: float = 2.0            # 2.0 = double damage on crit
var evasion: float = 0.0              # 0..1 (not used until PlayerHealth integrates it)

func add_damage_percent(pct: float) -> void:
	damage_mult *= (1.0 + pct)
	stats_changed.emit()

func add_fire_rate_percent(pct: float) -> void:
	fire_rate_mult *= (1.0 + pct)
	stats_changed.emit()

func add_move_speed_percent(pct: float) -> void:
	move_speed_mult *= (1.0 + pct)
	stats_changed.emit()

func add_range_percent(pct: float) -> void:
	range_mult *= (1.0 + pct)
	stats_changed.emit()

func add_projectile_speed_percent(pct: float) -> void:
	projectile_speed_mult *= (1.0 + pct)
	stats_changed.emit()
	
func add_extra_projectiles(n: int) -> void:
	extra_projectiles = max(0, extra_projectiles + n)
	stats_changed.emit()

func add_jump_percent(pct: float) -> void:
	jump_mult *= (1.0 + pct)
	stats_changed.emit()

# For spread you typically want "spread_down" upgrades:
# pct=0.10 means 10% tighter -> spread_mult *= 0.90
func add_spread_tighten_percent(pct: float) -> void:
	spread_mult *= maxf(0.05, (1.0 - pct))
	stats_changed.emit()

func add_crit_chance(pct: float) -> void:
	crit_chance = clampf(crit_chance + pct, 0.0, 1.0)
	stats_changed.emit()

func add_crit_mult_percent(pct: float) -> void:
	# pct=0.25 means crit_mult increases by 25% (2.0 -> 2.5)
	crit_mult = maxf(1.0, crit_mult * (1.0 + pct))
	stats_changed.emit()

func roll_crit(damage: float) -> Dictionary:
	var crit := false
	var out := damage
	if crit_chance > 0.0 and randf() < crit_chance:
		crit = true
		out = damage * crit_mult
	return {"damage": out, "crit": crit}


func add_evasion(pct: float) -> void:
	evasion = clampf(evasion + pct, 0.0, 0.95)
	stats_changed.emit()

func apply_crit(damage: float) -> float:
	if crit_chance <= 0.0:
		return damage
	if randf() < crit_chance:
		return damage * crit_mult
	return damage
	
func add_max_hp_percent(pct: float) -> void:
	max_hp_mult *= (1.0 + pct)
	stats_changed.emit()

func add_hp_regen_flat(amount_per_sec: float) -> void:
	hp_regen_per_sec = maxf(0.0, hp_regen_per_sec + amount_per_sec)
	stats_changed.emit()
