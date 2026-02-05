extends Node
class_name LevelSystem

signal xp_changed(current: int, required: int)
signal level_up(new_level: int)

@export var start_level := 1
@export var base_xp_required := 10
@export var xp_growth := 1.25

var level: int
var xp: int = 0
var xp_required: int

func _ready() -> void:
	level = start_level
	xp_required = _calc_required(level)
	xp_changed.emit(xp, xp_required)

func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	xp += amount
	while xp >= xp_required:
		xp -= xp_required
		level += 1
		xp_required = _calc_required(level)
		level_up.emit(level)

	xp_changed.emit(xp, xp_required)

func _calc_required(lvl: int) -> int:
	# grows like: base * growth^(lvl-1)
	return int(round(base_xp_required * pow(xp_growth, float(lvl - 1))))
