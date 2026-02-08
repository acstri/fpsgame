extends Node
class_name SpellCaster

@export_group("Spell Nodes (optional overrides)")
@export var chainlightning: ChainLightning
@export var magicmissile: MagicMissile
@export var fireball: FireballSpell

@export_group("Spell Switching")
@export var allow_runtime_switching: bool = true

@export_group("SpellData (generic-only)")
@export var spell: SpellData
@export var spell_chainlightning: SpellData
@export var spell_fireball: SpellData
@export var spell_magicmissile: SpellData

@export_group("Data/Stats")
@export var automatic := true
@export var stats: PlayerStats # optional; will be auto-found

@export_group("Refs")
@export var camera: Camera3D # optional; will be auto-found

var _cd_left := 0.0
var _cd_total := 0.0
var _ready_ok := false

# Cached implementation refs (never nulled)
var _impl_chain: ChainLightning
var _impl_fireball: FireballSpell
var _impl_magicmissile: MagicMissile

func _ready() -> void:
	_bind_impl_nodes()
	_autowire()

	_ready_ok = _validate_refs()
	if not _ready_ok:
		set_physics_process(false)
		return

	if spell == null:
		spell = _first_available_spelldata()

	if spell == null:
		push_error("SpellCaster: spell is null and no SpellData slots are assigned.")
		set_physics_process(false)
		return

	_ensure_spelldata_kind_is_valid()

func _physics_process(delta: float) -> void:
	if not _ready_ok:
		return

	_cd_left = maxf(0.0, _cd_left - delta)

	var wants_cast := Input.is_action_pressed("fire") if automatic else Input.is_action_just_pressed("fire")
	if wants_cast:
		try_cast()

# -------------------------
# Public API (switching)
# -------------------------

func set_spell(new_spell: SpellData) -> void:
	if new_spell == null:
		return
	spell = new_spell
	_ensure_spelldata_kind_is_valid()

func set_spell_by_kind(kind: StringName) -> void:
	if not allow_runtime_switching:
		return

	var sd := _spelldata_for_kind(kind)
	if sd == null:
		push_warning("SpellCaster: no SpellData assigned for kind '%s'." % String(kind))
		return

	set_spell(sd)

func cycle_spell() -> void:
	if not allow_runtime_switching:
		return

	var order: Array[StringName] = [&"chainlightning", &"fireball", &"magicmissile"]
	var current := _get_spelldata_kind()
	var idx := order.find(current)
	if idx == -1:
		idx = 0

	for step in range(order.size()):
		var next_kind := order[(idx + 1 + step) % order.size()]
		var sd := _spelldata_for_kind(next_kind)
		if sd != null:
			set_spell(sd)
			return

# -------------------------
# Casting
# -------------------------

func try_cast() -> void:
	if not _ready_ok:
		return
	if spell == null:
		return
	if _cd_left > 0.0:
		return

	var impl := _get_impl_from_spelldata()
	if impl == null:
		return

	var fire_mult := stats.fire_rate_mult if stats != null else 1.0
	_cd_total = maxf(0.01, spell.cooldown / maxf(0.001, fire_mult))
	_cd_left = _cd_total

	var dmg := spell.damage * (stats.damage_mult if stats != null else 1.0)
	var rng := spell.spell_range * (stats.range_mult if stats != null else 1.0)
	var spr := spell.spread_deg * (stats.spread_mult if stats != null else 1.0)

	var is_crit := false
	if stats != null:
		var r := stats.roll_crit(dmg)
		dmg = float(r.get("damage", dmg))
		is_crit = bool(r.get("crit", false))

	impl.call("cast", dmg, rng, spr, is_crit)

# -------------------------
# Cooldown telemetry for HUD
# -------------------------

func get_cooldown_left() -> float:
	return _cd_left

func get_cooldown_total() -> float:
	return _cd_total

func get_cooldown_ratio() -> float:
	if _cd_total <= 0.0001:
		return 0.0
	return clampf(_cd_left / _cd_total, 0.0, 1.0)

# -------------------------
# SpellData routing
# -------------------------

func _spelldata_for_kind(kind: StringName) -> SpellData:
	match kind:
		&"chainlightning":
			return spell_chainlightning
		&"fireball":
			return spell_fireball
		&"magicmissile":
			return spell_magicmissile
		_:
			return null

func _first_available_spelldata() -> SpellData:
	if spell_chainlightning != null:
		return spell_chainlightning
	if spell_fireball != null:
		return spell_fireball
	if spell_magicmissile != null:
		return spell_magicmissile
	return null

func _get_spelldata_kind() -> StringName:
	if spell == null:
		return StringName()
	if "delivery_kind" in spell:
		return spell.delivery_kind
	return StringName()

func _ensure_spelldata_kind_is_valid() -> void:
	if spell == null:
		return

	var kind := _get_spelldata_kind()
	if kind == StringName():
		push_warning("SpellCaster: SpellData.delivery_kind is empty on %s" % spell.resource_path)
		return

	if _get_impl_from_spelldata() == null:
		push_warning("SpellCaster: SpellData.delivery_kind '%s' has no matching implementation node." % String(kind))

func _get_impl_from_spelldata() -> Node:
	var kind := _get_spelldata_kind()
	match kind:
		&"chainlightning":
			return _impl_chain
		&"fireball":
			return _impl_fireball
		&"magicmissile":
			return _impl_magicmissile
		_:
			push_warning("SpellCaster: unknown SpellData.delivery_kind '%s' (expected: chainlightning/fireball/magicmissile)" % String(kind))
			return null

# -------------------------
# Binding / wiring / validation
# -------------------------

func _bind_impl_nodes() -> void:
	_impl_chain = chainlightning
	_impl_fireball = fireball
	_impl_magicmissile = magicmissile

	if _impl_fireball == null and has_node(^"FireballSpell"):
		_impl_fireball = get_node(^"FireballSpell") as FireballSpell
	if _impl_chain == null and has_node(^"chainlightningSpell"):
		_impl_chain = get_node(^"chainlightningSpell") as ChainLightning
	if _impl_magicmissile == null and has_node(^"magicmissile"):
		_impl_magicmissile = get_node(^"magicmissile") as MagicMissile
	# If your node is named ProjectileSpell instead, use this instead:
	# if _impl_magicmissile == null and has_node(^"ProjectileSpell"):
	#	_impl_magicmissile = get_node(^"ProjectileSpell") as MagicMissile

func _autowire() -> void:
	var owner_node := get_owner()

	if stats == null and owner_node != null:
		stats = _find_child_by_type(owner_node, PlayerStats) as PlayerStats
		if stats == null:
			stats = owner_node.get_node_or_null("PlayerStats") as PlayerStats

	if camera == null:
		if owner_node != null:
			camera = _find_child_by_type(owner_node, Camera3D) as Camera3D
		if camera == null:
			camera = get_viewport().get_camera_3d()

	if _impl_magicmissile != null:
		_impl_magicmissile.caster_root = owner_node
		if _impl_magicmissile.camera == null:
			_impl_magicmissile.camera = camera
		if _impl_magicmissile.stats == null:
			_impl_magicmissile.stats = stats

	if _impl_fireball != null:
		_impl_fireball.caster_root = owner_node
		if _impl_fireball.camera == null:
			_impl_fireball.camera = camera
		if _impl_fireball.stats == null:
			_impl_fireball.stats = stats

	if _impl_chain != null:
		_impl_chain.caster_root = owner_node
		if _impl_chain.camera == null:
			_impl_chain.camera = camera
		if _impl_chain.stats == null:
			_impl_chain.stats = stats

func _validate_refs() -> bool:
	var ok := true

	if _impl_chain == null and _impl_fireball == null and _impl_magicmissile == null:
		push_error("SpellCaster: no spell implementation found (chainlightning/fireball/magicmissile).")
		ok = false

	if camera == null:
		push_error("SpellCaster: camera could not be found/assigned.")
		ok = false

	return ok

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
