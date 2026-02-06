extends Node
class_name UpgradeService

signal choices_rolled(choices: Array[UpgradeData])

@export var all_upgrades: Array[UpgradeData] = []
@export var choices_count: int = 3

var _stacks: Dictionary = {} # id -> int

func reset_run() -> void:
	_stacks.clear()

func get_upgrade_stack(id: String) -> int:
	return int(_stacks.get(id, 0))

func can_take(up: UpgradeData) -> bool:
	return get_upgrade_stack(up.id) < up.max_stacks

func roll_choices() -> Array[UpgradeData]:
	var candidates: Array[UpgradeData] = []
	for up in all_upgrades:
		if up != null and can_take(up):
			candidates.append(up)

	var rolled: Array[UpgradeData] = []
	for i in range(choices_count):
		var pick: UpgradeData = _weighted_pick_excluding(candidates, rolled)
		if pick == null:
			break
		rolled.append(pick)

	choices_rolled.emit(rolled)
	return rolled

func apply_upgrade(up: UpgradeData, stats: PlayerStats) -> void:
	if up == null or stats == null:
		return
	if not can_take(up):
		return

	_stacks[up.id] = get_upgrade_stack(up.id) + 1

	match up.effect_key:
		"damage_up":
			stats.add_damage_percent(up.effect_value)
		"fire_rate_up":
			stats.add_fire_rate_percent(up.effect_value)
		"move_speed_up":
			stats.add_move_speed_percent(up.effect_value)
		_:
			push_warning("UpgradeService: Unknown effect_key: %s" % up.effect_key)

func _weighted_pick_excluding(pool: Array[UpgradeData], exclude: Array[UpgradeData]) -> UpgradeData:
	var total: float = 0.0
	for up in pool:
		if up == null:
			continue
		if exclude.has(up):
			continue
		total += maxf(0.0, up.weight)

	if total <= 0.0:
		return null

	var r: float = randf() * total
	var running: float = 0.0

	for up in pool:
		if up == null or exclude.has(up):
			continue
		running += maxf(0.0, up.weight)
		if r <= running:
			return up

	return null
