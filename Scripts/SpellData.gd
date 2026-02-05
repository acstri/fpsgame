extends Resource
class_name SpellData

@export var id: StringName
@export var display_name := "Spell"
@export_multiline var description := ""

@export_group("Gameplay")
@export var damage := 10.0
@export var spell_range := 120.0
@export var spread_deg := 0.0
@export var cooldown := 0.3

@export_group("UI")
@export var icon: Texture2D
