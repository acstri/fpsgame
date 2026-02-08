extends Node

@export var caster_path: NodePath = ^"../SpellCaster"

@export var key_1_kind: StringName = "&chainlightning"
@export var key_2_kind: StringName = "&fireball"
@export var key_3_kind: StringName = "&magicmissile"

var caster: Node = null

func _ready() -> void:
	if caster_path != NodePath():
		caster = get_node(caster_path)

func _unhandled_input(event: InputEvent) -> void:
	if caster == null:
		return

	# Cycle
	if event.is_action_pressed("spell_cycle"):
		if caster.has_method("cycle_spell"):
			caster.call("cycle_spell")
		return

	# Direct select
	if event.is_action_pressed("spell_1"):
		if caster.has_method("set_active_spell_kind"):
			caster.call("set_active_spell_kind", key_1_kind)
		return

	if event.is_action_pressed("spell_2"):
		if caster.has_method("set_active_spell_kind"):
			caster.call("set_active_spell_kind", key_2_kind)
		return

	if event.is_action_pressed("spell_3"):
		if caster.has_method("set_active_spell_kind"):
			caster.call("set_active_spell_kind", key_3_kind)
		return
