extends Node
class_name UpgradeService

signal choices_rolled(choices: Array[UpgradeData])
signal upgrade_applied(upgrade: UpgradeData, new_stack: int)

@export var all_upgrades: Array[UpgradeData] = []
@export var choices_count: int = 3

@export_group("Debug / Determinism")
@export var deterministic_rolls := false
@export var deterministic_seed: int = 123456

var _stacks: Dictionary = {} # id -> int
var _rng := RandomNumberGenerator.new()
var _validated := false

func _ready() -> void:
	_configure_rng()
	_validated = _validate_upgrade_list()

func reset_run() -> void:
	_stacks.clear()

func get_upgrade_stack(id: String) -> int:
	return int(_stacks.get(id, 0))

func can_take(up: UpgradeData) -> bool:
	if up == null:
		return false
	var uid := _upgrade_id(up)
	return get_upgrade_stack(uid) < up.max_stacks

func roll_choices() -> Array[UpgradeData]:
	if not _validated:
		_validated = _validate_upgrade_list()

	var candidates: Array[UpgradeData] = []
	for up in all_upgrades:
		if up != null and can_take(up) and up.weight > 0.0:
			candidates.append(up)

	var rolled: Array[UpgradeData] = []
	var n = min(choices_count, candidates.size())

	for i in range(n):
		var pick: UpgradeData = _weighted_pick_excluding(candidates, rolled)
		if pick == null:
			break
		rolled.append(pick)

	choices_rolled.emit(rolled)
	return rolled

func apply_upgrade(up: UpgradeData, stats: PlayerStats) -> bool:
	if up == null or stats == null:
		return false

	if not can_take(up):
		return false

	var uid := _upgrade_id(up)
	var new_stack := get_upgrade_stack(uid) + 1
	_stacks[uid] = new_stack

	var applied := _apply_effect(up, stats)
	if not applied:
		# If effect is unknown, roll back the stack so state doesn't silently corrupt.
		_stacks[uid] = new_stack - 1
		return false

	upgrade_applied.emit(up, new_stack)
	return true

# --- internals ---

func _configure_rng() -> void:
	if deterministic_rolls:
		_rng.seed = deterministic_seed
	else:
		_rng.randomize()

func _validate_upgrade_list() -> bool:
	var ok := true
	var seen: Dictionary = {} # id -> UpgradeData

	for up in all_upgrades:
		if up == null:
			continue

		if up.max_stacks < 1:
			push_warning("UpgradeService: Upgrade '%s' has max_stacks < 1; it will never be offered." % _upgrade_label(up))

		if up.weight <= 0.0:
			# Not an error: weight<=0 means "never roll"
			continue

		var uid := _upgrade_id(up)
		if uid == "":
			push_error("UpgradeService: Upgrade has empty id and no resource_path fallback: '%s'." % _upgrade_label(up))
			ok = false
			continue

		if seen.has(uid) and seen[uid] != up:
			push_warning("UpgradeService: Duplicate upgrade id '%s' found for '%s' and '%s'. They will share stacks." %
				[uid, _upgrade_label(seen[uid]), _upgrade_label(up)])
		else:
			seen[uid] = up

	return ok

func _upgrade_id(up: UpgradeData) -> String:
	# Prefer explicit id; fallback to resource path; final fallback to title.
	if up.id.strip_edges() != "":
		return up.id.strip_edges()
	if up.resource_path != null and up.resource_path.strip_edges() != "":
		return up.resource_path.strip_edges()
	if up.title.strip_edges() != "":
		return up.title.strip_edges()
	return ""

func _upgrade_label(up: UpgradeData) -> String:
	return "%s (%s)" % [up.title, up.resource_path]

func _apply_effect(up: UpgradeData, stats: PlayerStats) -> bool:
	match up.effect_key:
		"damage_up":
			stats.add_damage_percent(up.effect_value)
			return true
		"fire_rate_up":
			stats.add_fire_rate_percent(up.effect_value)
			return true
		"move_speed_up":
			stats.add_move_speed_percent(up.effect_value)
			return true
		"range_up":
			stats.add_range_percent(up.effect_value)
			return true
		"projectile_speed_up":
			stats.add_projectile_speed_percent(up.effect_value)
			return true
		"projectile_up":
			stats.add_extra_projectiles(int(round(up.effect_value)))
			return true
		"jump_vel_up":
			stats.add_jump_percent(up.effect_value)
			return true
		"spread_down":
			stats.add_spread_tighten_percent(up.effect_value)
			return true
		"crit_chance_up":
			stats.add_crit_chance(up.effect_value)
			return true
		"crit_mult_up":
			stats.add_crit_mult_percent(up.effect_value)
			return true
		"evasion_up":
			stats.add_evasion(up.effect_value)
			return true
		"max_hp_up":
			stats.add_max_hp_percent(up.effect_value)
			return true
		"life_regen_up":
			stats.add_hp_regen_flat(up.effect_value)
			return true
		_:
			push_warning("UpgradeService: Unknown effect_key: %s (upgrade=%s)" % [up.effect_key, _upgrade_label(up)])
			return false


func _weighted_pick_excluding(pool: Array[UpgradeData], exclude: Array[UpgradeData]) -> UpgradeData:
	var total: float = 0.0
	for up in pool:
		if up == null:
			continue
		if exclude.has(up):
			continue
		total += up.weight

	if total <= 0.0:
		return null

	var r: float = _rng.randf() * total
	var running: float = 0.0

	for up in pool:
		if up == null or exclude.has(up):
			continue
		running += up.weight
		if r <= running:
			return up

	return null
