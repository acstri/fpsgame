extends Control
class_name StatBlock

@export var stats: PlayerStats

@onready var damage_label: Label = $VBoxContainer/DamageLabel
@onready var fire_rate_label: Label = $VBoxContainer/FireRateLabel
@onready var move_speed_label: Label = $VBoxContainer/MoveSpeedLabel
@onready var crit_chance_label: Label = $VBoxContainer/CritChanceLabel
@onready var crit_mult_label: Label = $VBoxContainer/CritMultLabel
@onready var life_regen_label: Label = $VBoxContainer/LifeRegenLabel
@onready var max_hp_label: Label = $VBoxContainer/MaxHpLabel
@onready var projectiles_label: Label = $VBoxContainer/ProjectilesLabel
@onready var evasion_label: Label = $VBoxContainer/EvasionLabel

func _ready() -> void:
	_update_text()

func _process(_delta: float) -> void:
	_update_text()

func _update_text() -> void:
	if stats == null:
		_set_empty()
		return

	# Damage / Fire rate / Move speed are multipliers
	damage_label.text = "Damage: x%.2f" % stats.damage_mult
	fire_rate_label.text = "Fire Rate: x%.2f" % stats.fire_rate_mult
	move_speed_label.text = "Move Speed: x%.2f" % stats.move_speed_mult

	# Crit chance is a percentage
	crit_chance_label.text = "Crit Chance: %d%%" % int(round(stats.crit_chance * 100.0))

	# Crit multiplier is a multiplier (e.g. 1.5x, 2.0x)
	crit_mult_label.text = "Crit Damage: x%.2f" % stats.crit_mult

	# Regen is a flat value per second
	life_regen_label.text = "Life Regen: +%.2f /s" % stats.hp_regen_per_sec

	# Max HP is a multiplier
	max_hp_label.text = "Max HP: x%.2f" % stats.max_hp_mult

	# Extra projectiles is an integer bonus
	projectiles_label.text = "Projectiles: +%d" % int(stats.extra_projectiles)

	# Evasion is a percentage
	evasion_label.text = "Evasion: %d%%" % int(round(stats.evasion * 100.0))

func _set_empty() -> void:
	damage_label.text = "Damage: -"
	fire_rate_label.text = "Fire Rate: -"
	move_speed_label.text = "Move Speed: -"
	crit_chance_label.text = "Crit Chance: -"
	crit_mult_label.text = "Crit Damage: -"
	life_regen_label.text = "Life Regen: -"
	max_hp_label.text = "Max HP: -"
	projectiles_label.text = "Projectiles: -"
	evasion_label.text = "Evasion: -"
