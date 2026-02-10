extends Resource
class_name EnemyVariantData

@export var id: String = "normal"
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0

@export_group("Stat multipliers")
@export_range(0.1, 10.0, 0.05) var hp_mult: float = 1.0
@export_range(0.1, 10.0, 0.05) var move_speed_mult: float = 1.0
@export_range(0.1, 10.0, 0.05) var melee_damage_mult: float = 1.0
@export_range(0.0, 10.0, 0.05) var xp_mult: float = 1.0

@export_group("Scaling")
# Applied to the enemy root scale via EnemyVariantApplier (base_scale * scale_mult).
# Set elite.tres scale_mult to e.g. 1.25 or 1.5.
@export_range(0.25, 5.0, 0.05) var scale_mult: float = 1.0

@export_group("Tag (Sprite3D)")
@export var show_tag: bool = false
@export var tag_texture: Texture2D
@export var tag_color: Color = Color(1, 1, 1, 1)
@export_range(0.05, 5.0, 0.05) var tag_scale: float = 0.35
