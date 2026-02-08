extends Node
class_name DamageNumberSpawner

@export var damage_number_scene: PackedScene
@export var use_world_parent: NodePath # optional; if empty uses current_scene/root
@export var random_offset := 0.25

func _ready() -> void:
	if damage_number_scene == null:
		push_error("DamageNumberSpawner: damage_number_scene not assigned.")
		set_process(false)
		return

	Combat_Events.damage_number.connect(_on_damage_number)

func _on_damage_number(world_pos: Vector3, amount: float, is_crit: bool, _is_player_target: bool) -> void:
	var inst := damage_number_scene.instantiate() as Node3D

	var parent := get_node_or_null(use_world_parent) if use_world_parent != NodePath("") else null
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	parent.add_child(inst)

	inst.global_position = world_pos + Vector3(
		randf_range(-random_offset, random_offset),
		randf_range(0.0, random_offset),
		randf_range(-random_offset, random_offset)
	)

	if inst.has_method("setup"):
		inst.call("setup", amount, is_crit)
