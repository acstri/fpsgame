extends Node
class_name EnemyDropper

@export var xp_gem_scene: PackedScene
@export var gems_min := 1
@export var gems_max := 2

@onready var health: Node = get_parent().get_node_or_null("Health")

func _ready() -> void:
	if health != null and health.has_signal("died"):
		health.connect("died", _on_died)
	else:
		push_warning("EnemyDropper: Could not find Health node with died signal.")

func _on_died(_hit := {}) -> void:
	if xp_gem_scene == null:
		return

	var count := randi_range(gems_min, gems_max)
	var root := get_tree().current_scene
	var base_pos := (get_parent() as Node3D).global_position

	for i in range(count):
		var gem := xp_gem_scene.instantiate() as Node3D
		root.add_child(gem)
		# small random scatter
		gem.global_position = base_pos + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))
