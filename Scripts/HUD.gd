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
@export var cooldown_bar: ProgressBar          # set max=1, value=0..1 (or let script do it)
@export var cooldown_label: Label              # e.g. "CD: 0.42s"

# Enemy counter UI (optional)
@export_group("Enemy Counter (optional)")
@export var enemy_count_label: Label
@export var enemy_group_name := "enemy"
@export_range(1.0, 60.0, 1.0) var enemy_count_update_hz := 10.0

@export var xp_show_percent := false

var _health: PlayerHealth
var _level_system: LevelSystem
var _spell_caster: Node
var _hurt_tween: Tween

# Enemy count cache
var _enemy_count_accum := 0.0
var _last_enemy_count := -1

# Cache to avoid rebuilding strings every frame
var _last_spell_res_path := ""
var _last_spell_kind := ""
var _last_spell_damage := INF
var _last_spell_cd := INF
var _last_spell_rng := INF
var _last_spell_spr := INF

func _ready() -> void:
	_autowire()

	if not _validate_ui():
		set_process(false)
		return

	if player == null:
		push_error("HUD: player not found (assign export or add player to group 'player').")
		set_process(false)
		return

	_health = _find_child_by_type(player, PlayerHealth) as PlayerHealth
	if _health == null:
		_health = player.get_node_or_null("Health") as PlayerHealth

	if _health != null:
		_health.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(_health.hp, _health.get_max_hp())

	_level_system = _find_child_by_type(player, LevelSystem) as LevelSystem
	if _level_system == null:
		_level_system = player.get_node_or_null("LevelSystem") as LevelSystem

	_spell_caster = player.get_node_or_null("SpellCaster")
	if _spell_caster == null:
		_spell_caster = player.get_node_or_null("MagicMissileCaster")

	if _health == null:
		push_error("HUD: PlayerHealth not found under player.")
	if _level_system == null:
		push_error("HUD: LevelSystem not found under player.")

	_refresh_all()

	var events := get_node_or_null("/root/Combat_Events")
	if events != null and events.has_signal("hurt_flash"):
		events.hurt_flash.connect(_on_hurt_flash)
	else:
		push_warning("HUD: Combat_Events missing or has no hurt_flash signal.")

func _process(delta: float) -> void:
	_refresh_runtime(delta)

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

func _refresh_all() -> void:
	_refresh_level()
	_refresh_xp()
	_refresh_spell()
	_refresh_cooldown()
	_refresh_enemy_count(999.0) # force immediate

func _refresh_runtime(delta: float) -> void:
	_refresh_level()
	_refresh_xp()
	_refresh_spell()
	_refresh_cooldown()
	_refresh_enemy_count(delta)

func _on_hp_changed(current: float, max_hp: float) -> void:
	if hp_label == null:
		return
	hp_label.text = "HP: %d / %d" % [int(round(current)), int(round(max_hp))]

func _refresh_level() -> void:
	if _level_system == null or level_label == null:
		return
	if "level" in _level_system:
		level_label.text = "Lv " + str(_level_system.level)
	else:
		level_label.text = "Lv"

func _refresh_xp() -> void:
	if _level_system == null or xp_bar == null:
		return

	var xp := 0.0
	var xp_to_next := 1.0

	if "xp" in _level_system:
		xp = float(_level_system.xp)
	elif "current_xp" in _level_system:
		xp = float(_level_system.current_xp)

	if "xp_to_next" in _level_system:
		xp_to_next = max(1.0, float(_level_system.xp_to_next))
	elif "xp_required" in _level_system:
		xp_to_next = max(1.0, float(_level_system.xp_required))

	xp_bar.max_value = xp_to_next
	xp_bar.value = clamp(xp, 0.0, xp_to_next)

	if xp_show_percent and xp_bar.has_method("set_text"):
		xp_bar.set_text(str(int((xp / xp_to_next) * 100.0)) + "%")

func _refresh_spell() -> void:
	if spell_label == null and spell_stats_label == null:
		return
	if _spell_caster == null or not ("spell" in _spell_caster):
		_set_spell_texts("", "")
		return

	var sd: Resource = _spell_caster.spell
	if sd == null:
		_set_spell_texts("Spell: (none)", "")
		return

	var kind := ""
	var dmg := 0.0
	var cd := 0.0
	var rng := 0.0
	var spr := 0.0

	if "delivery_kind" in sd:
		kind = String(sd.delivery_kind)
	if "damage" in sd:
		dmg = float(sd.damage)
	if "cooldown" in sd:
		cd = float(sd.cooldown)
	if "spell_range" in sd:
		rng = float(sd.spell_range)
	if "spread_deg" in sd:
		spr = float(sd.spread_deg)

	var res_path := sd.resource_path

	if res_path == _last_spell_res_path \
	and kind == _last_spell_kind \
	and is_equal_approx(dmg, _last_spell_damage) \
	and is_equal_approx(cd, _last_spell_cd) \
	and is_equal_approx(rng, _last_spell_rng) \
	and is_equal_approx(spr, _last_spell_spr):
		return

	_last_spell_res_path = res_path
	_last_spell_kind = kind
	_last_spell_damage = dmg
	_last_spell_cd = cd
	_last_spell_rng = rng
	_last_spell_spr = spr

	var title := ""
	if res_path != "":
		title = res_path.get_file().get_basename()
	else:
		title = kind if kind != "" else "(spell)"

	var header := "Spell: " + title
	var stats_line := "DMG %d | CD %.2f | RNG %d | SPR %.1f" % [
		int(round(dmg)),
		cd,
		int(round(rng)),
		spr
	]
	if kind != "":
		stats_line += "  (" + kind + ")"

	_set_spell_texts(header, stats_line)

func _set_spell_texts(header: String, stats_line: String) -> void:
	if spell_label != null:
		spell_label.text = header
	if spell_stats_label != null:
		spell_stats_label.text = stats_line

func _refresh_cooldown() -> void:
	if cooldown_bar == null and cooldown_label == null:
		return

	if _spell_caster == null:
		_set_cooldown_ui(0.0, 0.0)
		return

	var left := 0.0
	var total := 0.0

	if _spell_caster.has_method("get_cooldown_left"):
		left = float(_spell_caster.call("get_cooldown_left"))
	if _spell_caster.has_method("get_cooldown_total"):
		total = float(_spell_caster.call("get_cooldown_total"))

	_set_cooldown_ui(left, total)

func _set_cooldown_ui(left: float, total: float) -> void:
	var ratio := 0.0
	if total > 0.0001:
		ratio = clampf(left / total, 0.0, 1.0)

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

	var tree := get_tree()
	if tree == null:
		return

	var n := 0
	if enemy_group_name != "":
		n = tree.get_nodes_in_group(enemy_group_name).size()

	if n == _last_enemy_count:
		return
	_last_enemy_count = n
	enemy_count_label.text = "Enemies: %d" % n

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null

func _on_hurt_flash(is_player: bool) -> void:
	if not is_player:
		return
	if hurt_flash == null:
		push_warning("HUD: hurt_flash ColorRect not assigned.")
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
