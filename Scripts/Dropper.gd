extends Node
class_name EnemyDropper

@export_group("Drops")
@export var xp_gem_scene: PackedScene
@export var total_xp := 3
@export var gems_min := 1
@export var gems_max := 3

@export_group("Refs (optional override)")
@export var health: EnemyHealth

func _ready() -> void:
	_autowire()

	if health == null:
		push_warning("EnemyDropper: Could not find EnemyHealth (assign export or add child 'Health' with EnemyHealth).")
		return

	if health.has_signal("died"):
		var cb := Callable(self, "_on_died")
		if not health.died.is_connected(cb):
			health.died.connect(cb)

func _on_died(_hit := {}) -> void:
	if xp_gem_scene == null:
		return
	if total_xp <= 0:
		return

	var count: int = clamp(randi_range(gems_min, gems_max), 1, 999)
	var xp_left: int = max(0, total_xp)

	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root

	var parent_3d := get_parent() as Node3D
	var base_pos := parent_3d.global_position if parent_3d != null else Vector3.ZERO

	for i in range(count):
		var gem := xp_gem_scene.instantiate() as Node3D
		root.add_child(gem)
		gem.global_position = base_pos + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))

		# distribute XP (last gem gets remainder)
		var v: int = 1
		if i == count - 1:
			v = xp_left
		else:
			v = min(1, xp_left)

		xp_left = max(0, xp_left - v)

		if gem.has_method("set_value"):
			gem.call("set_value", v)
		elif gem is XPGem:
			(gem as XPGem).value = v

func _autowire() -> void:
	if health != null:
		return

	var p := get_parent()
	if p == null:
		return

	# Prefer type-based lookup (stable), fallback to old name for compatibility
	health = _find_child_by_type(p, EnemyHealth) as EnemyHealth
	if health == null:
		health = p.get_node_or_null("Health") as EnemyHealth

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
