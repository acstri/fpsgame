extends Node3D
class_name ProjectileSpell

signal cast_started()
signal cast_finished()

@export_group("Refs")
@export var camera: Camera3D
@export var stats: PlayerStats # optional

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 35.0
@export var spawn_distance_from_cam: float = 0.6

@export_group("Collision")
@export_flags_3d_physics var hit_mask := 5
@export var exclude_player := true

func cast(damage: float, spellrange: float, spread_deg: float) -> void:
	cast_started.emit()

	if camera == null:
		push_warning("ProjectileSpell: camera not assigned.")
		cast_finished.emit()
		return
	if projectile_scene == null:
		push_warning("ProjectileSpell: projectile_scene not assigned.")
		cast_finished.emit()
		return

	# Optional stat scaling (matches your HitscanSpell style)
	if stats != null:
		if "damage_mult" in stats:
			damage *= stats.damage_mult
		if "range_mult" in stats:
			spellrange *= stats.range_mult
		if "spread_mult" in stats:
			spread_deg *= stats.spread_mult

	var dir := -camera.global_transform.basis.z
	dir = _apply_spread(dir, spread_deg)

	var spawn_xform := camera.global_transform
	spawn_xform.origin += (-camera.global_transform.basis.z) * spawn_distance_from_cam

	var p := projectile_scene.instantiate()
	if p is Node3D:
		(p as Node3D).global_transform = spawn_xform

	# exclude player root (same approach as hitscan)
	var caster_node: Node = null
	if exclude_player:
		caster_node = get_owner()

	# Configure projectile
	if p.has_method("setup"):
		p.callv("setup", [damage, dir, caster_node, projectile_speed, spellrange, hit_mask])

	# Ensure it goes into the main world, not the SubViewport
	get_tree().current_scene.add_child(p)

	cast_finished.emit()

func _apply_spread(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction.normalized()

	var rad := deg_to_rad(degrees)
	var u := randf()
	var v := randf()

	var theta := TAU * u
	var phi := acos(1.0 - v * (1.0 - cos(rad)))

	var x := sin(phi) * cos(theta)
	var y := sin(phi) * sin(theta)
	var z := cos(phi)

	var b: Basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return (b * Vector3(x, y, -z)).normalized()
