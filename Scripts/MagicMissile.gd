extends Node3D
class_name MagicMissile

signal cast_started()
signal cast_finished()

@export_group("Refs")
@export var camera: Camera3D
@export var stats: PlayerStats # optional

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 35.0
@export var spawn_distance_from_cam: float = 0.6

@export_group("Multi-shot")
@export var missiles_per_cast: int = 5
@export var multi_cast_spread_deg: float = 8.0 # separation between missiles

@export_group("Collision")
@export_flags_3d_physics var hit_mask := 5
@export var exclude_player := true

func cast(damage: float, spellrange: float, spread_deg: float) -> void:
	cast_started.emit()

	if camera == null:
		push_warning("MagicMissile: camera not assigned.")
		cast_finished.emit()
		return
	if projectile_scene == null:
		push_warning("MagicMissile: projectile_scene not assigned.")
		cast_finished.emit()
		return

	# Optional stat scaling
	if stats != null:
		if "damage_mult" in stats:
			damage *= stats.damage_mult
		if "range_mult" in stats:
			spellrange *= stats.range_mult
		if "spread_mult" in stats:
			spread_deg *= stats.spread_mult

	var spawn_xform := camera.global_transform
	var base_forward := -camera.global_transform.basis.z
	spawn_xform.origin += base_forward * spawn_distance_from_cam

	# exclude player root
	var caster_node: Node = get_owner() if exclude_player else null

	var count : float = max(1, missiles_per_cast)

	for i in range(count):
		# base aim + normal "inaccuracy" spread
		var dir := SpellUtil.apply_spread(base_forward, spread_deg)

		# deterministic fan so missiles separate visually
		var yaw := 0.0
		if count > 1:
			var t := float(i) / float(count - 1) # 0..1
			yaw = (t - 0.5) * multi_cast_spread_deg

		dir = _yaw_offset(dir, yaw)

		var p := projectile_scene.instantiate()

		# Ensure it goes into the main world, not the SubViewport
		get_tree().current_scene.add_child(p)

		if p is Node3D:
			(p as Node3D).global_transform = spawn_xform

		# Configure projectile (keeps your existing setup signature)
		if p.has_method("setup"):
			p.callv("setup", [damage, dir, caster_node, projectile_speed, spellrange, hit_mask])

	cast_finished.emit()

func _yaw_offset(dir: Vector3, yaw_deg: float) -> Vector3:
	if absf(yaw_deg) <= 0.0001:
		return dir.normalized()

	var yaw := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	return (yaw * dir).normalized()
