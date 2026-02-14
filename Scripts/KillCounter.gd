extends Node

signal changed(kills: int)

var _kills: int = 0

func reset() -> void:
	_kills = 0
	changed.emit(_kills)

func add_kill(amount: int = 1) -> void:
	if amount <= 0:
		return
	_kills += amount
	changed.emit(_kills)

func get_kills() -> int:
	return _kills
