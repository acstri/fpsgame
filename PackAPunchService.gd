extends Node
class_name PackAPunchService

signal tier_changed(kind: StringName, new_tier: int)

@export var max_tier: int = 3

# Tier 1 cost at index 0, Tier 2 cost at index 1, etc.
@export var tier_costs: Array[int] = [500, 1000, 2000]

# Multipliers indexed by tier: [tier0(base), tier1, tier2, tier3]
@export var damage_mult_by_tier: Array[float] = [1.0, 1.75, 2.75, 4.0]
@export var cooldown_mult_by_tier: Array[float] = [1.0, 0.85, 0.75, 0.65]
@export var range_mult_by_tier: Array[float] = [1.0, 1.05, 1.10, 1.15]
@export var spread_mult_by_tier: Array[float] = [1.0, 1.00, 0.95, 0.90]

# Optional flavor names shown in HUD/prompt.
var name_by_kind := {
	&"fireball":    ["Fireball", "Fireball Mk II", "Fireball Mk III", "Fireball Mk IV"],
	&"chainlightning": ["Chain Lightning", "Chain Lightning Mk II", "Chain Lightning Mk III", "Chain Lightning Mk IV"],
	&"magicmissile": ["Magic Missile", "Magic Missile Mk II", "Magic Missile Mk III", "Magic Missile Mk IV"],
}

var _tier_by_kind: Dictionary = {} # kind(StringName) -> int

func get_tier(kind: StringName) -> int:
	return int(_tier_by_kind.get(kind, 0))

func can_upgrade(kind: StringName) -> bool:
	return get_tier(kind) < max_tier

func get_next_cost(kind: StringName) -> int:
	var t := get_tier(kind)
	if t >= max_tier:
		return 0
	var idx = clamp(t, 0, tier_costs.size() - 1)
	return tier_costs[idx]

func upgrade(kind: StringName) -> bool:
	if not can_upgrade(kind):
		return false
	var new_tier := get_tier(kind) + 1
	_tier_by_kind[kind] = new_tier
	tier_changed.emit(kind, new_tier)
	return true

func get_display_name(kind: StringName) -> String:
	var t := get_tier(kind)
	if name_by_kind.has(kind):
		var arr: Array = name_by_kind[kind]
		if t >= 0 and t < arr.size():
			return str(arr[t])
	return "%s T%d" % [String(kind), t]

# New typed API (preferred)
func apply_upgrade(sd: SpellData) -> SpellData:
	if sd == null:
		return null

	# Determine kind from spell_key (fallback to delivery_kind for compatibility)
	var kind := sd.spell_key
	if kind == StringName():
		kind = sd.delivery_kind
	if kind == StringName():
		push_warning("PackAPunchService: SpellData has empty spell_key/delivery_kind; cannot apply upgrade.")
		return sd

	var t := get_tier(kind)
	var upgraded := sd.duplicate(true) as SpellData
	if upgraded == null:
		return sd

	# Keep identity aligned
	if upgraded.spell_key == StringName() and upgraded.delivery_kind != StringName():
		upgraded.spell_key = upgraded.delivery_kind
	elif upgraded.delivery_kind == StringName() and upgraded.spell_key != StringName():
		upgraded.delivery_kind = upgraded.spell_key

	upgraded.damage = float(upgraded.damage) * _get_arr(damage_mult_by_tier, t, 1.0)
	upgraded.cooldown = float(upgraded.cooldown) * _get_arr(cooldown_mult_by_tier, t, 1.0)
	upgraded.spell_range = float(upgraded.spell_range) * _get_arr(range_mult_by_tier, t, 1.0)
	upgraded.spread_deg = float(upgraded.spread_deg) * _get_arr(spread_mult_by_tier, t, 1.0)

	if typeof(upgraded.extras) != TYPE_DICTIONARY:
		upgraded.extras = {}
	upgraded.extras["pap_tier"] = t
	upgraded.extras["pap_name"] = get_display_name(kind)

	return upgraded

# Back-compat wrapper (kept so older callers still work)
func apply_upgrade_to_spelldata(kind: StringName, base_data: Resource) -> Resource:
	if base_data == null:
		return null

	var sd := base_data as SpellData
	if sd != null:
		# Ensure kind is set on the data if caller provided it.
		if sd.spell_key == StringName() and kind != StringName():
			sd.spell_key = kind
		if sd.delivery_kind == StringName() and kind != StringName():
			sd.delivery_kind = kind
		return apply_upgrade(sd)

	# If some non-SpellData resource is passed, keep old behavior minimal:
	var upgraded := base_data.duplicate(true)
	return upgraded

func _get_arr(arr: Array, tier: int, fallback) -> Variant:
	if tier >= 0 and tier < arr.size():
		return arr[tier]
	return fallback

func reset_run() -> void:
	_tier_by_kind.clear()
	for kind in name_by_kind.keys():
		tier_changed.emit(kind, 0)
