extends Node
class_name SpellCaster

signal spell_cast(kind: StringName, spell_data: SpellData)
signal spell_changed(kind: StringName, spell_data: SpellData)
signal ammo_changed(kind: StringName, current: float, max_ammo: float)

@export_group("Spell Nodes (optional overrides)")
@export var chainlightning: ChainLightning
@export var magicmissile: MagicMissile
@export var fireball: FireballSpell
@export var arcgun: ArcGunSpell

@export_group("Spell Switching")
@export var allow_runtime_switching: bool = true

@export_group("SpellData (generic-only)")
@export var spell: SpellData
@export var spell_chainlightning: SpellData
@export var spell_fireball: SpellData
@export var spell_magicmissile: SpellData
@export var spell_arcgun: SpellData

@export_group("Data/Stats")
@export var automatic := true
@export var stats: PlayerStats

@export_group("Refs")
@export var camera: Camera3D

var _cd_left := 0.0
var _cd_total := 0.0
var _ready_ok := false

var _impl_chain: ChainLightning
var _impl_fireball: FireballSpell
var _impl_magicmissile: MagicMissile
var _impl_arcgun: ArcGunSpell

# Ammo state per kind
var _ammo_by_kind: Dictionary = {} # Dictionary[StringName, float]
var _regen_block_left := 0.0

func _ready() -> void:
	_bind_impl_nodes()
	_autowire()

	_ready_ok = _validate_refs()
	if not _ready_ok:
		set_physics_process(false)
		return

	_apply_start_spell_lock()

	if spell == null:
		spell = _first_available_spelldata()

	if spell == null:
		push_error("SpellCaster: spell is null and no SpellData slots are assigned.")
		set_physics_process(false)
		return

	_normalize_spelldata_identity(spell)
	_ensure_spelldata_kind_is_valid()
	_prime_ammo_for_current_spell(true)
	spell_changed.emit(_get_spelldata_kind(), spell)

func _physics_process(delta: float) -> void:
	if not _ready_ok:
		return

	_cd_left = maxf(0.0, _cd_left - delta)

	var fire_pressed := Input.is_action_pressed("fire")
	var wants_cast := fire_pressed if automatic else Input.is_action_just_pressed("fire")

	if wants_cast:
		try_cast()
	else:
		_update_ammo_regen(delta)

# For PlayerSpellSwitch.gd compatibility
func set_active_spell_kind(kind: StringName) -> void:
	set_spell_by_kind(kind)

func set_spell(new_spell: SpellData) -> void:
	if new_spell == null:
		return
	spell = new_spell
	_normalize_spelldata_identity(spell)
	_ensure_spelldata_kind_is_valid()
	_prime_ammo_for_current_spell(false)
	spell_changed.emit(_get_spelldata_kind(), spell)

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
	var order: Array[StringName] = [&"chainlightning", &"fireball", &"magicmissile", &"arcgun"]
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

func try_cast() -> void:
	if not _ready_ok:
		return
	if spell == null:
		return
	if _cd_left > 0.0:
		return

	var kind := _get_spelldata_kind()
	if not _can_consume_ammo(kind, spell):
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

	_on_ammo_consumed(kind, spell)
	_regen_block_left = maxf(0.0, spell.ammo_regen_delay)

	spell_cast.emit(kind, spell)

func get_cooldown_left() -> float:
	return _cd_left

func get_cooldown_total() -> float:
	return _cd_total

func get_cooldown_ratio() -> float:
	if _cd_total <= 0.0001:
		return 0.0
	return clampf(_cd_left / _cd_total, 0.0, 1.0)

func get_ammo_current(kind: StringName = StringName()) -> float:
	if kind == StringName():
		kind = _get_spelldata_kind()
	return float(_ammo_by_kind.get(kind, 0.0))

func get_ammo_max(kind: StringName = StringName()) -> int:
	var sd := spell if kind == StringName() else _spelldata_for_kind(kind)
	if sd == null:
		return 0
	return maxi(0, sd.ammo_max)

func _spelldata_for_kind(kind: StringName) -> SpellData:
	match kind:
		&"chainlightning": return spell_chainlightning
		&"fireball": return spell_fireball
		&"magicmissile": return spell_magicmissile
		&"arcgun": return spell_arcgun
		_: return null

func _first_available_spelldata() -> SpellData:
	if spell_chainlightning != null: return spell_chainlightning
	if spell_fireball != null: return spell_fireball
	if spell_magicmissile != null: return spell_magicmissile
	if spell_arcgun != null: return spell_arcgun
	return null

func _get_spelldata_kind() -> StringName:
	if spell == null:
		return StringName()
	if spell.spell_key != StringName():
		return spell.spell_key
	if spell.delivery_kind != StringName():
		return spell.delivery_kind
	return StringName()

func _normalize_spelldata_identity(sd: SpellData) -> void:
	if sd == null:
		return
	if sd.spell_key == StringName() and sd.delivery_kind != StringName():
		sd.spell_key = sd.delivery_kind
	elif sd.delivery_kind == StringName() and sd.spell_key != StringName():
		sd.delivery_kind = sd.spell_key

func _ensure_spelldata_kind_is_valid() -> void:
	if spell == null:
		return
	var kind := _get_spelldata_kind()
	if kind == StringName():
		push_warning("SpellCaster: SpellData spell_key/delivery_kind is empty on %s" % spell.resource_path)
		return
	if _get_impl_from_spelldata() == null:
		push_warning("SpellCaster: SpellData kind '%s' has no matching implementation node." % String(kind))

func _get_impl_from_spelldata() -> Node:
	var kind := _get_spelldata_kind()
	match kind:
		&"chainlightning": return _impl_chain
		&"fireball": return _impl_fireball
		&"magicmissile": return _impl_magicmissile
		&"arcgun": return _impl_arcgun
		_:
			push_warning("SpellCaster: unknown spell kind '%s'." % String(kind))
			return null

# -------------------------
# Ammo internals
# -------------------------

func _prime_ammo_for_current_spell(force_full: bool) -> void:
	if spell == null:
		return
	var kind := _get_spelldata_kind()
	if kind == StringName():
		return

	if spell.ammo_max <= 0:
		_ammo_by_kind.erase(kind)
		ammo_changed.emit(kind, 0.0, 0.0)
		return

	var max_ammo := float(maxi(0, spell.ammo_max))
	var cur := float(_ammo_by_kind.get(kind, max_ammo))
	if force_full:
		cur = max_ammo
	cur = clampf(cur, 0.0, max_ammo)
	_ammo_by_kind[kind] = cur
	ammo_changed.emit(kind, cur, max_ammo)

func _can_consume_ammo(kind: StringName, sd: SpellData) -> bool:
	if sd == null or sd.ammo_max <= 0:
		return true
	var max_ammo := float(maxi(0, sd.ammo_max))
	var cur := float(_ammo_by_kind.get(kind, max_ammo))
	var cost := float(maxi(1, sd.ammo_cost_per_cast))
	return cur >= cost - 0.0001

func _on_ammo_consumed(kind: StringName, sd: SpellData) -> void:
	if sd == null or sd.ammo_max <= 0:
		return
	var max_ammo := float(maxi(0, sd.ammo_max))
	var cur := float(_ammo_by_kind.get(kind, max_ammo))
	var cost := float(maxi(1, sd.ammo_cost_per_cast))
	cur = clampf(cur - cost, 0.0, max_ammo)
	_ammo_by_kind[kind] = cur
	ammo_changed.emit(kind, cur, max_ammo)

func _update_ammo_regen(delta: float) -> void:
	if spell == null or spell.ammo_max <= 0:
		return

	if _regen_block_left > 0.0:
		_regen_block_left = maxf(0.0, _regen_block_left - delta)
		if _regen_block_left > 0.0:
			return

	var kind := _get_spelldata_kind()
	if kind == StringName():
		return

	var max_ammo := float(maxi(0, spell.ammo_max))
	var cur := float(_ammo_by_kind.get(kind, max_ammo))
	if cur >= max_ammo - 0.0001:
		return

	# Empty -> slow; Partial -> fast
	var rate := spell.ammo_regen_per_sec_empty if cur <= 0.0001 else spell.ammo_regen_per_sec_partial
	if rate <= 0.0:
		return

	cur = minf(max_ammo, cur + rate * delta)
	_ammo_by_kind[kind] = cur
	ammo_changed.emit(kind, cur, max_ammo)

# -------------------------
# Start spell lock (menu)
# -------------------------

func _apply_start_spell_lock() -> void:
	var start_kind := "fireball"
	if ProjectSettings.has_setting("application/config/start_spell_kind"):
		start_kind = String(ProjectSettings.get_setting("application/config/start_spell_kind"))

	var chosen: StringName
	match start_kind:
		"magicmissile": chosen = &"magicmissile"
		"arcgun": chosen = &"arcgun"
		_: chosen = &"fireball"

	allow_runtime_switching = false

	match chosen:
		&"fireball":
			spell = spell_fireball
			spell_magicmissile = null
			spell_arcgun = null
		&"magicmissile":
			spell = spell_magicmissile
			spell_fireball = null
			spell_arcgun = null
		&"arcgun":
			spell = spell_arcgun
			spell_fireball = null
			spell_magicmissile = null

	spell_chainlightning = null
	_disable_chainlightning_impl()

func _disable_chainlightning_impl() -> void:
	if _impl_chain == null:
		return
	_impl_chain.set_process(false)
	_impl_chain.set_physics_process(false)
	if _impl_chain is Node3D:
		(_impl_chain as Node3D).visible = false

# -------------------------
# Binding / wiring / validation
# -------------------------

func _bind_impl_nodes() -> void:
	_impl_chain = chainlightning
	_impl_fireball = fireball
	_impl_magicmissile = magicmissile
	_impl_arcgun = arcgun

	if _impl_fireball == null and has_node(^"FireballSpell"):
		_impl_fireball = get_node(^"FireballSpell") as FireballSpell
	if _impl_chain == null and has_node(^"chainlightningSpell"):
		_impl_chain = get_node(^"chainlightningSpell") as ChainLightning
	if _impl_magicmissile == null and has_node(^"magicmissile"):
		_impl_magicmissile = get_node(^"magicmissile") as MagicMissile
	if _impl_arcgun == null and has_node(^"ArcGunSpell"):
		_impl_arcgun = get_node(^"ArcGunSpell") as ArcGunSpell

func _autowire() -> void:
	var owner_node := get_owner()

	if stats == null and owner_node != null:
		stats = NodeUtil.find_child_by_type(owner_node, PlayerStats) as PlayerStats
		if stats == null:
			stats = owner_node.get_node_or_null("PlayerStats") as PlayerStats

	if camera == null:
		if owner_node != null:
			camera = NodeUtil.find_child_by_type(owner_node, Camera3D) as Camera3D
		if camera == null:
			camera = get_viewport().get_camera_3d()

	if _impl_arcgun != null:
		_impl_arcgun.caster_root = owner_node
		if _impl_arcgun.camera == null:
			_impl_arcgun.camera = camera
		if _impl_arcgun.stats == null:
			_impl_arcgun.stats = stats

func _validate_refs() -> bool:
	var ok := true
	if _impl_chain == null and _impl_fireball == null and _impl_magicmissile == null and _impl_arcgun == null:
		push_error("SpellCaster: no spell implementation found.")
		ok = false
	if camera == null:
		push_error("SpellCaster: camera could not be found/assigned.")
		ok = false
	return ok
