extends Control
class_name HUD

@export var player: Node # optional; if null, finds group "player"

# UI references
@export var hp_label: Label
@export var level_label: Label
@export var xp_bar: ProgressBar
@export var hurt_flash: ColorRect

# Optional spell UI
@export_group("Spell UI (optional)")
@export var spell_label: Label
@export var spell_stats_label: Label

# Cooldown UI (optional)
@export_group("Cooldown UI (optional)")
@export var cooldown_bar: ProgressBar
@export var cooldown_label: Label

# Crosshair (optional)
@export_group("Crosshair (optional)")
@export var crosshair: Crosshair

# Enemy counter UI (optional)
@export_group("Enemy Counter (optional)")
@export var enemy_count_label: Label
@export var enemy_group_name := "enemy"
@export_range(1.0, 60.0, 1.0) var enemy_count_update_hz := 10.0

# Pack-a-Punch / Essence UI (optional)
@export_group("Pack-a-Punch UI (optional)")
@export var essence_label: Label
@export var pap_label: Label

@export var xp_show_percent := false

var _health: PlayerHealth
var _level_system: LevelSystem
var _spell_caster: SpellCaster
var _hurt_tween: Tween

# Enemy count cache
var _enemy_count_accum := 0.0
var _last_enemy_count := -1

# PaP/Essence cache
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
	else:
		push_error("HUD: PlayerHealth not found under player.")

	if _level_system != null:
		var cb_xp := Callable(self, "_on_xp_changed")
		var cb_lv := Callable(self, "_on_level_up")

		if not _level_system.xp_changed.is_connected(cb_xp):
			_level_system.xp_changed.connect(cb_xp)
		if not _level_system.level_up.is_connected(cb_lv):
			_level_system.level_up.connect(cb_lv)

		_on_level_up(_level_system.level)
		_on_xp_changed(_level_system.xp, _level_system.xp_required)
	else:
		push_error("HUD: LevelSystem not found under player.")

	if _spell_caster != null:
		var cb_sc := Callable(self, "_on_spell_changed")
		if not _spell_caster.spell_changed.is_connected(cb_sc):
			_spell_caster.spell_changed.connect(cb_sc)
		_on_spell_changed(_spell_caster._get_spelldata_kind(), _spell_caster.spell)
	else:
		push_warning("HUD: SpellCaster not found under player.")

func _bind_events() -> void:
	var events := get_node_or_null("/root/Combat_Events")
	if events != null and events.has_signal("hurt_flash"):
		events.hurt_flash.connect(_on_hurt_flash)

	var wallet := get_node_or_null("/root/EssenceWallet")
	if wallet != null and wallet.has_signal("changed"):
		wallet.changed.connect(_on_essence_changed)
		_on_essence_changed(wallet.get_amount())

	var pap := get_node_or_null("/root/PackAPunch")
	if pap != null and pap.has_signal("tier_changed"):
		pap.tier_changed.connect(_on_pap_tier_changed)

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

	if xp_show_percent and xp_bar.has_method("set_text"):
		var pct := 0.0
		if required > 0:
			pct = (float(current) / float(required)) * 100.0
		xp_bar.set_text(str(int(pct)) + "%")

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
	if kind != StringName():
		stats_line += "  (" + String(kind) + ")"

	_set_spell_texts(header, stats_line)

func _set_spell_texts(header: String, stats_line: String) -> void:
	if spell_label != null:
		spell_label.text = header
	if spell_stats_label != null:
		spell_stats_label.text = stats_line

func _refresh_cooldown() -> void:
	if cooldown_bar == null and cooldown_label == null and crosshair == null:
		return
	if _spell_caster == null:
		_set_cooldown_ui(0.0, 0.0)
		return
	_set_cooldown_ui(_spell_caster.get_cooldown_left(), _spell_caster.get_cooldown_total())

func _set_cooldown_ui(left: float, total: float) -> void:
	var ratio := 0.0
	if total > 0.0001:
		ratio = 1.0 - clampf(left / total, 0.0, 1.0)

	if crosshair != null and is_instance_valid(crosshair):
		crosshair.set_cooldown_ratio(ratio if left > 0.0 else 0.0)

	if cooldown_bar != null:
		cooldown_bar.max_value = 1.0
		cooldown_bar.value = ratio
		cooldown_bar.visible = ratio > 0.001

	if cooldown_label != null:
		if ratio <= 0.001:
			cooldown_label.text = "Ready"
		else:
			cooldown_label.text = "CD: %.2fs" % left

func _refresh_enemy_count(delta: float) -> void:
	if enemy_count_label == null:
		return

	var hz := maxf(1.0, enemy_count_update_hz)
	var interval := 1.0 / hz

	_enemy_count_accum += delta
	if _enemy_count_accum < interval:
		return
	_enemy_count_accum = 0.0

	var n := 0
	if enemy_group_name != "":
		n = get_tree().get_nodes_in_group(enemy_group_name).size()

	if n == _last_enemy_count:
		return
	_last_enemy_count = n
	enemy_count_label.text = "Enemies: %d" % n

func _refresh_essence() -> void:
	if essence_label == null:
		return

	var wallet := get_node_or_null("/root/EssenceWallet")
	if wallet == null:
		essence_label.text = "Essence: -"
		return

	var v := int(wallet.get_amount())
	if v == _last_essence:
		return
	_last_essence = v
	essence_label.text = "Essence: %d" % v

func _refresh_pap() -> void:
	if pap_label == null:
		return

	var pap := get_node_or_null("/root/PackAPunch")
	if pap == null:
		pap_label.text = "PaP: -"
		return

	var kind: StringName = StringName()
	if _spell_caster != null and _spell_caster.spell != null:
		kind = _spell_caster.spell.spell_key
		if kind == StringName():
			kind = _spell_caster.spell.delivery_kind

	if kind == StringName():
		pap_label.text = "PaP: (no spell)"
		return

	var tier := int(PackAPunch.get_tier(kind))
	var display_name := String(PackAPunch.get_display_name(kind))

	if kind == _last_pap_kind and tier == _last_pap_tier and display_name == _last_pap_name:
		return
	_last_pap_kind = kind
	_last_pap_tier = tier
	_last_pap_name = display_name

	pap_label.text = "PaP: %s (T%d)" % [display_name, tier]

func _on_essence_changed(_new_amount: int) -> void:
	_last_essence = -1
	_refresh_essence()

func _on_pap_tier_changed(_kind: StringName, _new_tier: int) -> void:
	_last_pap_tier = -999
	_refresh_pap()

func _on_hurt_flash(is_player: bool) -> void:
	if not is_player:
		return
	if hurt_flash == null:
		return

	if _hurt_tween != null and is_instance_valid(_hurt_tween):
		_hurt_tween.kill()

	hurt_flash.visible = true
	_set_hurt_alpha(0.0)

	_hurt_tween = create_tween()
	_hurt_tween.set_ignore_time_scale(true)
	_hurt_tween.tween_method(_set_hurt_alpha, 0.0, 0.35, 0.05)
	_hurt_tween.tween_method(_set_hurt_alpha, 0.35, 0.0, 0.18)

func _set_hurt_alpha(a: float) -> void:
	if hurt_flash == null:
		return
	var c := hurt_flash.color
	c.a = clampf(a, 0.0, 1.0)
	hurt_flash.color = c
