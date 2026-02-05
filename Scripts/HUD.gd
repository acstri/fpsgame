extends Control
class_name HUD

@export_group("Refs")
@export var player: Node3D
@export var weapon_path: NodePath

@onready var hp_label: Label = $TopLeft/HPLabel
@onready var ammo_label: Label = $TopLeft/AmmoLabel
@onready var xp_bar: ProgressBar = $Bottom/XPBar
@onready var level_label: Label = $Bottom/LevelLabel
var _level_system: LevelSystem
var _health: Node
var _current_level: int = 1

func _ready() -> void:
	if player == null:
		push_warning("HUD: player not assigned.")
		return

	# Level system
	_level_system = player.get_node_or_null("LevelSystem") as LevelSystem
	if _level_system != null:
		_level_system.xp_changed.connect(_on_xp_changed)
		_level_system.level_up.connect(_on_level_up)

	# Health (optional)
	_health = player.get_node_or_null("Health")
	if _health != null and _health.has_signal("hp_changed"):
		_health.connect("hp_changed", _on_hp_changed)

	# Weapon (via NodePath)
	var weapon: Node = null
	if weapon_path != NodePath():
		weapon = player.get_node_or_null(weapon_path)

	if weapon != null and weapon.has_signal("ammo_changed"):
		weapon.connect("ammo_changed", _on_ammo_changed)
	else:
		push_warning("HUD: weapon not found or has no ammo_changed signal.")

	# Initial UI
	_set_hp_text_unknown()
	_set_ammo_text_unknown()
	_update_level_text()

func _on_xp_changed(current: int, required: int) -> void:
	xp_bar.min_value = 0
	xp_bar.max_value = max(1, required)
	xp_bar.value = clamp(current, 0, required)

func _on_level_up(new_level: int) -> void:
	_current_level = new_level
	_update_level_text()

func _on_ammo_changed(in_mag: int, mag_size: int, reserve: int) -> void:
	ammo_label.text = "Ammo: %d/%d | Reserve: %d" % [in_mag, mag_size, reserve]

func _on_hp_changed(current: float, max_hp: float) -> void:
	hp_label.text = "HP: %d / %d" % [int(round(current)), int(round(max_hp))]

func _update_level_text() -> void:
	level_label.text = "Level: %d" % _current_level

func _set_hp_text_unknown() -> void:
	hp_label.text = "HP: --"

func _set_ammo_text_unknown() -> void:
	ammo_label.text = "Ammo: --"
