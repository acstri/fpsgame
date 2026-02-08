extends Node
class_name EnemyHurtFlash

@export var health: EnemyHealth
@export var meshes: Array[MeshInstance3D] = []

@export var flash_strength := 1.5      # emission energy multiplier
@export var flash_in := 0.04
@export var flash_out := 0.10

var _tween: Tween
var _mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	if health == null:
		var root := get_parent() if get_parent() != null else self
		health = _find_child_by_type(root, EnemyHealth) as EnemyHealth
		if health == null:
			health = root.get_node_or_null("Health") as EnemyHealth

	if health == null:
		push_warning("EnemyHurtFlash: EnemyHealth not found.")
		return

	_prepare_materials()

	health.damaged.connect(_on_damaged)

func _prepare_materials() -> void:
	_mats.clear()

	for m in meshes:
		if m == null:
			_mats.append(null)
			continue

		# Prefer material_override; otherwise duplicate surface 0 material.
		var mat: Material = m.material_override
		if mat == null and m.mesh != null and m.mesh.get_surface_count() > 0:
			mat = m.mesh.surface_get_material(0)

		var std := mat as StandardMaterial3D
		if std == null:
			# Create a new StandardMaterial3D so flashing always works
			std = StandardMaterial3D.new()
			std.albedo_color = Color(1, 1, 1, 1)

		# Duplicate so we don't mutate shared materials across instances
		std = std.duplicate() as StandardMaterial3D
		std.emission_enabled = true
		std.emission = Color(1, 1, 1, 1)
		std.emission_energy_multiplier = 0.0

		m.material_override = std
		_mats.append(std)

func _on_damaged(_amt: float, _remaining: float, _hit: Dictionary) -> void:
	if _mats.is_empty():
		return

	if _tween != null and is_instance_valid(_tween):
		_tween.kill()

	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_method(_set_flash, 0.0, flash_strength, flash_in)
	_tween.tween_method(_set_flash, flash_strength, 0.0, flash_out)

func _set_flash(v: float) -> void:
	for std in _mats:
		if std == null:
			continue
		std.emission_energy_multiplier = maxf(0.0, v)

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
