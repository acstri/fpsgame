# res://Scripts/spells/SpellData.gd
extends Resource
class_name SpellData

# Stable identifier for Pack-a-Punch and UI.
# Set this to: "fireball", "chainlightning", "magicmissile"
@export var spell_key: StringName = &""

# Generic spell data (locked semantics)
@export var damage: float = 10.0
@export var cooldown: float = 1.0

# Your HUD already expects these names:
@export var spell_range: float = 12.0
@export var spread_deg: float = 0.0

# Existing field used by your systems/UI
@export var delivery_kind: StringName = &""

# Optional metadata (safe for PaP tags like pap_tier/pap_name)
@export var extras: Dictionary = {}

# Compatibility aliases so other scripts can use "range" / "spread"
# (PackAPunchService uses range/spread by default.)
var range: float:
	get:
		return spell_range
	set(value):
		spell_range = value

var spread: float:
	get:
		return spread_deg
	set(value):
		spread_deg = value
