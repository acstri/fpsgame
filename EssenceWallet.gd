extends Node

signal changed(new_amount: int)

var _amount: int = 0

func get_amount() -> int:
	return _amount

func add(value: int) -> void:
	if value <= 0:
		return
	_amount += value
	changed.emit(_amount)

func can_afford(cost: int) -> bool:
	return cost <= _amount

func spend(cost: int) -> bool:
	if cost <= 0:
		return true
	if _amount < cost:
		return false
	_amount -= cost
	changed.emit(_amount)
	return true
