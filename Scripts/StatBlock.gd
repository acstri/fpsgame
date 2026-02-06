extends Control
class_name StatBlock

@export var stats: PlayerStats

@onready var damage_label: Label = $VBoxContainer/DamageLabel
@onready var fire_rate_label: Label = $VBoxContainer/FireRateLabel
@onready var move_speed_label: Label = $VBoxContainer/MoveSpeedLabel

func _ready() -> void:
	_update_text()

func _process(_delta: float) -> void:
	# simplest: update every frame (fine for a few labels)
	_update_text()

func _update_text() -> void:
	if stats == null:
		damage_label.text = "Damage: -"
		fire_rate_label.text = "Fire Rate: -"
		move_speed_label.text = "Move Speed: -"
		return

	damage_label.text = "Damage: x%.2f" % stats.damage_mult
	fire_rate_label.text = "Fire Rate: x%.2f" % stats.fire_rate_mult
	move_speed_label.text = "Move Speed: x%.2f" % stats.move_speed_mult
