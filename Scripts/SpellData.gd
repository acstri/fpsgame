# res://Scripts/SpellData.gd
extends Resource
class_name SpellData

@export var spell_key: StringName = &""

@export var damage: float = 10.0
@export var cooldown: float = 1.0

@export var spell_range: float = 12.0
@export var spread_deg: float = 0.0

@export var delivery_kind: StringName = &""
@export var extras: Dictionary = {}

@export_group("Ammo (optional)")
@export var ammo_max: int = 0
@export var ammo_cost_per_cast: int = 1

# Regen starts only when NOT holding fire, after this delay from last shot.
@export_range(0.0, 10.0, 0.01) var ammo_regen_delay: float = 0.12

# If you stop shooting with ammo still left -> quick refill.
@export_range(0.0, 999.0, 0.1) var ammo_regen_per_sec_partial: float = 40.0

# If you empty the mag -> slower "reload".
@export_range(0.0, 999.0, 0.1) var ammo_regen_per_sec_empty: float = 12.0

# Compatibility aliases (PackAPunchService uses range/spread)
var range: float:
	get: return spell_range
	set(v): spell_range = v

var spread: float:
	get: return spread_deg
	set(v): spread_deg = v
