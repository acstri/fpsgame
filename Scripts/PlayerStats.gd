extends Node
class_name PlayerStats

signal stats_changed()

var damage_mult: float = 1.0
var fire_rate_mult: float = 1.0
var move_speed_mult: float = 1.0

func add_damage_percent(pct: float) -> void:
	damage_mult *= (1.0 + pct)
	stats_changed.emit()

func add_fire_rate_percent(pct: float) -> void:
	fire_rate_mult *= (1.0 + pct)
	stats_changed.emit()

func add_move_speed_percent(pct: float) -> void:
	move_speed_mult *= (1.0 + pct)
	stats_changed.emit()
