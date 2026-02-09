extends Node
class_name HandCastAnimator

@export var spell_caster_path: NodePath = NodePath("../../../SpellCaster")
@export var anim_player_path: NodePath = NodePath("WeaponRig/hands/AnimationTree")

@export var cast_anim_name: StringName = &"cast"
@export var blend_time: float = 0.05
@export var restart_if_playing: bool = true

var _caster: SpellCaster
var _anim: AnimationPlayer

func _ready() -> void:
	_caster = get_node_or_null(spell_caster_path) as SpellCaster
	_anim = get_node_or_null(anim_player_path) as AnimationPlayer

	if _caster == null:
		push_warning("HandCastAnimator: SpellCaster not found at %s" % String(spell_caster_path))
		return
	if _anim == null:
		push_warning("HandCastAnimator: AnimationPlayer not found at %s" % String(anim_player_path))
		return

	_caster.spell_cast.connect(_on_spell_cast)

func _on_spell_cast(_kind: StringName, _spell_data: SpellData) -> void:
	if not _anim.has_animation(cast_anim_name):
		return

	if restart_if_playing and _anim.is_playing():
		_anim.stop()

	_anim.play(cast_anim_name, blend_time)
