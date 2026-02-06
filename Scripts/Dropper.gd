extends Node
class_name EnemyDropper

@export var xp_gem_scene: PackedScene
@export var total_xp := 3
@export var gems_min := 1
@export var gems_max := 3

@onready var health: Node = get_parent().get_node_or_null("Health")

func _ready() -> void:
	if health != null and health.has_signal("died"):
		health.died.connect(_on_died)
	else:
		push_warning("EnemyDropper: Could not find Health node with died signal.")

func _on_died(_hit := {}) -> void:
	if xp_gem_scene == null:
		return

	var count : float = clamp(randi_range(gems_min, gems_max), 1, 999)
	var xp_left : float = max(0, total_xp)

	var root := get_tree().current_scene
	var base_pos := (get_parent() as Node3D).global_position

	for i in range(count):
		var gem := xp_gem_scene.instantiate() as Node3D
		root.add_child(gem)
		gem.global_position = base_pos + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))

		# distribute XP into gems (last gem gets the remainder)
		var v = 1
		if i == count - 1:
			v = xp_left
		else:
			v = mini(1, xp_left)

		xp_left = max(0, xp_left - v)

		if gem.has_method("set_value"):
			gem.call("set_value", v)
		elif gem is XPGem:
			(gem as XPGem).value = v
