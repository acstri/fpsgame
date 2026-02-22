extends Node
class_name EnemyHurtFlash

@export var health: EnemyHealth

@export_group("Meshes (optional)")
# Leave empty to auto-collect all MeshInstance3D / SkinnedMeshInstance3D under the enemy.
@export var meshes: Array[MeshInstance3D] = []

@export_group("Flash Look")
@export var flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export_range(0.0, 1.0, 0.01) var max_alpha := 0.85
@export var flash_in := 0.04
@export var flash_out := 0.10

@export_group("Overlay Layer")
@export var overlay_name := "FlashOverlay"
@export var overlay_cast_shadows := false
@export var overlay_blend_add := true # true = additive; false = mix

var _tween: Tween
var _overlays: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D

func _ready() -> void:
	# Find health if not assigned
	if health == null:
		var root := get_parent() if get_parent() != null else self
		health = _find_child_by_type(root, EnemyHealth) as EnemyHealth
		if health == null:
			health = root.get_node_or_null("Health") as EnemyHealth

	if health == null:
		push_warning("EnemyHurtFlash: EnemyHealth not found.")
		return

	# Collect meshes if none assigned (or only nulls)
	if meshes.is_empty() or _all_null(meshes):
		var root2 := get_parent() if get_parent() != null else self
		meshes = _collect_meshes(root2)

	_build_overlay_material()
	_build_overlays_from_duplicates()

	if _overlays.is_empty():
		push_warning("EnemyHurtFlash: no overlays created (no meshes found?).")
		return

	if not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)

func _build_overlay_material() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if overlay_blend_add else BaseMaterial3D.BLEND_MODE_MIX
	_mat.albedo_color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	_mat.disable_receive_shadows = true

func _build_overlays_from_duplicates() -> void:
	_overlays.clear()

	for base in meshes:
		if base == null or base.mesh == null:
			continue

		# If an overlay already exists as a sibling, reuse it
		var parent := base.get_parent()
		if parent == null:
			continue

		var existing := parent.get_node_or_null(overlay_name) as MeshInstance3D
		if existing != null and existing.mesh == base.mesh:
			_overlays.append(existing)
			continue

		# Duplicate the mesh node so it keeps skeleton/skin binding and animations
		# (SkinnedMeshInstance3D also derives from MeshInstance3D)
		var ov := base.duplicate() as MeshInstance3D
		if ov == null:
			continue

		ov.name = overlay_name

		# Make it sit exactly where the original is, as a sibling (safer for skeleton paths)
		ov.transform = base.transform
		parent.add_child(ov)
		parent.move_child(ov, parent.get_child_count() - 1)

		# Ensure same visibility layers
		ov.layers = base.layers

		# Shadows off by default
		ov.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not overlay_cast_shadows else base.cast_shadow

		# Important: override material so we don't touch original materials
		ov.material_override = _mat

		# Clear any surface overrides that might have been duplicated
		if ov.mesh != null:
			var sc := ov.mesh.get_surface_count()
			for s in range(sc):
				ov.set_surface_override_material(s, null)

		_overlays.append(ov)

	_set_alpha(0.0)

func _on_damaged(_amt: float, _remaining: float, _hit: Dictionary) -> void:
	if _overlays.is_empty() or _mat == null:
		return

	if _tween != null and is_instance_valid(_tween):
		_tween.kill()

	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_method(_set_alpha, 0.0, max_alpha, flash_in)
	_tween.tween_method(_set_alpha, max_alpha, 0.0, flash_out)

func _set_alpha(a: float) -> void:
	a = clampf(a, 0.0, 1.0)

	var c := _mat.albedo_color
	c.a = a
	_mat.albedo_color = c

	var show := a > 0.001
	for ov in _overlays:
		if ov != null:
			ov.visible = show

# -----------------------
# helpers
# -----------------------

func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D:
			# ignore overlays if this script reruns
			if String(n.name) == overlay_name:
				continue
			out.append(n as MeshInstance3D)
	return out

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null

func _all_null(arr: Array) -> bool:
	for v in arr:
		if v != null:
			return false
	return true
