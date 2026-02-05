extends Control
class_name HUD

@export_group("Refs")
@export var player: Node3D
@export var spell_caster_path: NodePath # optional: point to SpellCaster/MagicMissileCaster

@onready var hp_label: Label = $TopLeft/HPLabel
@onready var spell_label: Label = $TopLeft/AmmoLabel # reuse node, but show spell info
@onready var xp_bar: ProgressBar = $Bottom/XPBar
@onready var level_label: Label = $Bottom/LevelLabel

var _level_system: LevelSystem
var _health: Node
var _current_level: int = 1


func _ready() -> void:
	if player == null:
		push_warning("HUD: player not assigned.")
		return

	# Level system
	_level_system = player.get_node_or_null("LevelSystem") as LevelSystem
	if _level_system != null:
		_level_system.xp_changed.connect(_on_xp_changed)
		_level_system.level_up.connect(_on_level_up)

	# Health
	_health = player.get_node_or_null("Health")
	if _health != null and _health.has_signal("hp_changed"):
		_health.connect("hp_changed", _on_hp_changed)
	else:
		_set_hp_text_unknown()

	# Spell / caster display (no more ammo)
	_wire_spell_caster()

	_update_level_text()


func _wire_spell_caster() -> void:
	var caster: Node = null

	if spell_caster_path != NodePath():
		caster = get_node_or_null(spell_caster_path)
	else:
		# fallback: try common names under player
		caster = player.get_node_or_null("SpellCaster")
		if caster == null:
			caster = player.get_node_or_null("MagicMissileCaster")

	if caster == null:
		spell_label.text = "Spell: --"
		return

	# Show something immediately if properties exist
	_update_spell_text_from_caster(caster)

	# Optional: if your caster emits signals, HUD can react automatically.
	# (You can add these later; HUD won't break if they don't exist.)
	if caster.has_signal("spell_changed"):
		caster.connect("spell_changed", func():
			_update_spell_text_from_caster(caster)
		)
	if caster.has_signal("cooldown_changed"):
		caster.connect("cooldown_changed", func():
			_update_spell_text_from_caster(caster)
		)


func _update_spell_text_from_caster(caster: Node) -> void:
	var display_name := "Spell"
	var spell: SpellData = null

	if caster.has_method("get"):
		spell = caster.get("spell") as SpellData

	if spell != null:
		display_name = spell.display_name
		spell_label.text = "%s | DMG: %.0f | CD: %.2fs" % [
			display_name,
			spell.damage,
			spell.cooldown
		]

	else:
		spell_label.text = "Spell: %s" % display_name


func _get_prop_float(obj: Object, prop: StringName, fallback: float) -> float:
	if obj == null:
		return fallback
	# Godot exposes exported vars as properties.
	if obj.has_method("get"):
		var v = obj.get(prop)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			return float(v)
	return fallback


func _on_xp_changed(current: int, required: int) -> void:
	xp_bar.min_value = 0
	xp_bar.max_value = max(1, required)
	xp_bar.value = clamp(current, 0, required)


func _on_level_up(new_level: int) -> void:
	_current_level = new_level
	_update_level_text()


func _on_hp_changed(current: float, max_hp: float) -> void:
	hp_label.text = "HP: %d / %d" % [int(round(current)), int(round(max_hp))]


func _update_level_text() -> void:
	level_label.text = "Level: %d" % _current_level


func _set_hp_text_unknown() -> void:
	hp_label.text = "HP: --"
