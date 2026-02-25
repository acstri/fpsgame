extends Control
class_name HUD

@export var player: Node

@export var hp_label: Label
@export var level_label: Label
@export var xp_bar: ProgressBar
@export var hurt_flash: ColorRect

@export_group("Spell UI (optional)")
@export var spell_label: Label
@export var spell_stats_label: Label

@export_group("Cooldown UI (optional)")
@export var cooldown_bar: ProgressBar
@export var cooldown_label: Label

@export_group("Crosshair (optional)")
@export var crosshair: Crosshair

@export_group("Enemy Counter (optional)")
@export var enemy_count_label: Label
@export var enemy_group_name := "enemy"
@export_range(1.0, 60.0, 1.0) var enemy_count_update_hz := 10.0

@export_group("Pack-a-Punch UI (optional)")
@export var essence_label: Label
@export var pap_label: Label

@export var xp_show_percent := false

var _health: PlayerHealth
var _level_system: LevelSystem
var _spell_caster: SpellCaster
var _hurt_tween: Tween

var _enemy_count_accum := 0.0
var _last_enemy_count := -1

var _last_essence := -1
var _last_pap_kind: StringName = StringName()
var _last_pap_tier := -999
var _last_pap_name := ""

func _ready() -> void:
	_autowire()
	if not _validate_ui():
		return

	if crosshair == null:
		crosshair = get_node_or_null("Crosshair") as Crosshair

	_bind_player_refs()
	_bind_events()
	_refresh_all()

func _process(delta: float) -> void:
	_refresh_cooldown()
	_refresh_enemy_count(delta)

func _autowire() -> void:
	if player != null:
		return
	var ps := get_tree().get_nodes_in_group("player")
	if ps.size() > 0:
		player = ps[0]

func _validate_ui() -> bool:
	var ok := true
	if hp_label == null:
		push_error("HUD: hp_label not assigned.")
		ok = false
	if level_label == null:
		push_error("HUD: level_label not assigned.")
		ok = false
	if xp_bar == null:
		push_error("HUD: xp_bar not assigned.")
		ok = false
	return ok

func _bind_player_refs() -> void:
	if player == null:
		push_error("HUD: player not assigned and group 'player' not found.")
		return

	_health = NodeUtil.find_child_by_type(player, PlayerHealth) as PlayerHealth
	if _health == null:
		_health = player.get_node_or_null("PlayerHealth") as PlayerHealth

	_level_system = NodeUtil.find_child_by_type(player, LevelSystem) as LevelSystem
	if _level_system == null:
		_level_system = player.get_node_or_null("LevelSystem") as LevelSystem

	_spell_caster = player.get_node_or_null("SpellCaster") as SpellCaster
	if _spell_caster == null:
		_spell_caster = player.get_node_or_null("MagicMissileCaster") as SpellCaster

	if _health != null:
		var cb_hp := Callable(self, "_on_hp_changed")
		if not _health.hp_changed.is_connected(cb_hp):
			_health.hp_changed.connect(cb_hp)
		_on_hp_changed(_health.hp, _health.get_max_hp())

	if _level_system != null:
		var cb_xp := Callable(self, "_on_xp_changed")
		var cb_lv := Callable(self, "_on_level_up")
		if not _level_system.xp_changed.is_connected(cb_xp):
			_level_system.xp_changed.connect(cb_xp)
		if not _level_system.level_up.is_connected(cb_lv):
			_level_system.level_up.connect(cb_lv)
		_on_level_up(_level_system.level)
		_on_xp_changed(_level_system.xp, _level_system.xp_required)

	if _spell_caster != null:
		var cb_sc := Callable(self, "_on_spell_changed")
		if not _spell_caster.spell_changed.is_connected(cb_sc):
			_spell_caster.spell_changed.connect(cb_sc)
		_on_spell_changed(_spell_caster._get_spelldata_kind(), _spell_caster.spell)

func _bind_events() -> void:
	if is_instance_valid(Combat_Events) and Combat_Events.has_signal(&"hurt_flash"):
		Combat_Events.hurt_flash.connect(_on_hurt_flash)

	if is_instance_valid(EssenceWallet) and EssenceWallet.has_signal(&"changed"):
		EssenceWallet.changed.connect(_on_essence_changed)
		_on_essence_changed(EssenceWallet.get_amount())

	if is_instance_valid(PackAPunch) and PackAPunch.has_signal(&"tier_changed"):
		PackAPunch.tier_changed.connect(_on_pap_tier_changed)

func _refresh_all() -> void:
	_refresh_spell_panel(_spell_caster.spell if _spell_caster != null else null)
	_refresh_essence()
	_refresh_pap()

func _on_hp_changed(current: float, max_hp: float) -> void:
	if hp_label == null:
		return
	hp_label.text = "HP: %d / %d" % [int(round(current)), int(round(max_hp))]

func _on_level_up(new_level: int) -> void:
	if level_label == null:
		return
	level_label.text = "Lv " + str(new_level)

func _on_xp_changed(current: int, required: int) -> void:
	if xp_bar == null:
		return
	xp_bar.max_value = max(1, required)
	xp_bar.value = clamp(current, 0, required)

func _on_spell_changed(_kind: StringName, spell_data: SpellData) -> void:
	_refresh_spell_panel(spell_data)
	_refresh_pap()

func _refresh_spell_panel(sd: SpellData) -> void:
	if spell_label == null and spell_stats_label == null:
		return
	if sd == null:
		_set_spell_texts("Spell: (none)", "")
		return

	var kind := sd.spell_key
	if kind == StringName():
		kind = sd.delivery_kind

	var title := String(kind) if kind != StringName() else "(spell)"
	var header := "Spell: " + title
	var stats_line := "DMG %d | CD %.2f | RNG %d | SPR %.1f" % [
		int(round(sd.damage)),
		sd.cooldown,
		int(round(sd.spell_range)),
		sd.spread_deg
	]
	_set_spell_texts(header, stats_line)

func _set_spell_texts(header: String, stats_line: String) -> void:
	if spell_label != null:
		spell_label.text = header
	if spell_stats_label != null:
		spell_stats_label.text = stats_line

func _refresh_cooldown() -> void:
	if cooldown_bar == null and cooldown_label == null and crosshair == null:
		return
	if _spell_caster == null or _spell_caster.spell == null:
		_set_cooldown_ui(0.0, 0.0)
		if crosshair != null:
			crosshair.set_arc_mode_ammo(false)
		return

	var sd := _spell_caster.spell
	var kind := sd.spell_key
	if kind == StringName():
		kind = sd.delivery_kind

	# ArcGun: segmented ammo arc
	if crosshair != null and kind == &"arcgun" and sd.ammo_max > 0:
		crosshair.set_arc_mode_ammo(true)
		crosshair.set_ammo_state(_spell_caster.get_ammo_current(kind), sd.ammo_max)
	else:
		if crosshair != null:
			crosshair.set_arc_mode_ammo(false)

	_set_cooldown_ui(_spell_caster.get_cooldown_left(), _spell_caster.get_cooldown_total())

func _set_cooldown_ui(left: float, total: float) -> void:
	var ratio := 0.0
	if total > 0.0001:
		ratio = 1.0 - clampf(left / total, 0.0, 1.0)

	if crosshair != null and not crosshair._ammo_mode:
		crosshair.set_cooldown_ratio(ratio if left > 0.0 else 0.0)

	if cooldown_bar != null:
		cooldown_bar.max_value = 1.0
		cooldown_bar.value = ratio
		cooldown_bar.visible = ratio > 0.001

	if cooldown_label != null:
		cooldown_label.text = "Ready" if ratio <= 0.001 else ("CD: %.2fs" % left)

func _refresh_enemy_count(delta: float) -> void:
	if enemy_count_label == null:
		return
	var hz := maxf(1.0, enemy_count_update_hz)
	var interval := 1.0 / hz
	_enemy_count_accum += delta
	if _enemy_count_accum < interval:
		return
	_enemy_count_accum = 0.0
	var n := get_tree().get_nodes_in_group(enemy_group_name).size()
	if n == _last_enemy_count:
		return
	_last_enemy_count = n
	enemy_count_label.text = "Enemies: %d" % n

# keep your existing implementations
func _on_hurt_flash(_amount: float) -> void: pass
func _on_essence_changed(_amount: int) -> void: _refresh_essence()
func _refresh_essence() -> void: pass
func _on_pap_tier_changed(_kind: StringName, _tier: int) -> void:
	_refresh_pap()
func _refresh_pap() -> void: pass
