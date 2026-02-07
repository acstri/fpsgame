extends Control
class_name HUD

@export var player: Node # optional; if null, finds group "player"

# UI references (assign these in the editor once; then UI can be rearranged safely)
@export var hp_label: Label
@export var level_label: Label
@export var xp_bar: ProgressBar

# Optional: if your XP bar needs max updates
@export var xp_show_percent := false

var _health: PlayerHealth
var _level_system: LevelSystem
var _spell_caster: Node

func _ready() -> void:
	_autowire()

	if not _validate_ui():
		set_process(false)
		return

	if player == null:
		push_error("HUD: player not found (assign export or add player to group 'player').")
		set_process(false)
		return

	# Prefer type-based wiring (more robust than child names)
	_health = _find_child_by_type(player, PlayerHealth) as PlayerHealth
	if _health == null:
		# fallback to common name, for compatibility with current prototype
		_health = player.get_node_or_null("Health") as PlayerHealth

	if _health != null:
		_health.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(_health.hp, _health.max_hp)

	_level_system = _find_child_by_type(player, LevelSystem) as LevelSystem
	if _level_system == null:
		_level_system = player.get_node_or_null("LevelSystem") as LevelSystem

	# Spell caster: keep loose; HUD can work without it
	_spell_caster = player.get_node_or_null("SpellCaster")
	if _spell_caster == null:
		_spell_caster = player.get_node_or_null("MagicMissileCaster")

	# Fail-fast for core dependencies
	if _health == null:
		push_error("HUD: PlayerHealth not found under player.")
	if _level_system == null:
		push_error("HUD: LevelSystem not found under player.")

	# Initial paint (so it looks correct on frame 1)
	_refresh_all()

func _process(_delta: float) -> void:
	# HUD should not crash if something is missing; it should just stop updating that section.
	_refresh_runtime()

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

func _refresh_runtime() -> void:
	# Keep these cheap and safe
	_refresh_level()
	_refresh_xp()

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

	# Try common naming patterns; adjust if your LevelSystem differs
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
		# Some custom bars support text; default ProgressBar doesn't.
		xp_bar.set_text(str(int((xp / xp_to_next) * 100.0)) + "%")

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
