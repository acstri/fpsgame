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
	# t=0 -> upgrading to 1 uses costs[0]
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

func apply_upgrade_to_spelldata(kind: StringName, base_data: Resource) -> Resource:
	# This assumes SpellData is a Resource with fields:
	# damage, cooldown, range, spread, delivery_kind
	# and optionally something like extras/meta Dictionary.
	if base_data == null:
		return null

	var t := get_tier(kind)
	var upgraded := base_data.duplicate(true)

	# Safe field access (no hard dependency if you rename fields)
	if upgraded.has_method("set"):
		# damage
		if _has_prop(upgraded, "damage"):
			upgraded.damage = float(upgraded.damage) * _get_arr(damage_mult_by_tier, t, 1.0)
		# cooldown (multiply by <1 to reduce cooldown)
		if _has_prop(upgraded, "cooldown"):
			upgraded.cooldown = float(upgraded.cooldown) * _get_arr(cooldown_mult_by_tier, t, 1.0)
		# range
		if _has_prop(upgraded, "range"):
			upgraded.range = float(upgraded.range) * _get_arr(range_mult_by_tier, t, 1.0)
		# spread
		if _has_prop(upgraded, "spread"):
			upgraded.spread = float(upgraded.spread) * _get_arr(spread_mult_by_tier, t, 1.0)

	# Optional metadata (only if your SpellData has extras/meta)
	if _has_prop(upgraded, "extras") and typeof(upgraded.extras) == TYPE_DICTIONARY:
		upgraded.extras["pap_tier"] = t
		upgraded.extras["pap_name"] = get_display_name(kind)
	elif _has_prop(upgraded, "meta") and typeof(upgraded.meta) == TYPE_DICTIONARY:
		upgraded.meta["pap_tier"] = t
		upgraded.meta["pap_name"] = get_display_name(kind)

	return upgraded

func _get_arr(arr: Array, tier: int, fallback) -> Variant:
	if tier >= 0 and tier < arr.size():
		return arr[tier]
	return fallback

func _has_prop(obj: Object, prop: StringName) -> bool:
	# Works for Resources too
	for p in obj.get_property_list():
		if StringName(p.name) == prop:
			return true
	return false
