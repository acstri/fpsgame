extends Node3D
class_name FireballSpell

signal cast_started()
signal cast_finished()

@export_group("Refs")
@export var camera: Camera3D
@export var stats: PlayerStats # optional
@export var caster_root: Node # optional; used for exclusion. If null, will try group "player", else owner.

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 28.0
@export var spawn_distance_from_cam: float = 0.8

@export_group("Explosion")
@export var explosion_radius: float = 3.5
@export_range(0.0, 5.0, 0.05) var aoe_damage_mult: float = 0.65

@export_group("Multi-shot")
@export var fireballs_per_cast: int = 1
@export var multi_cast_spread_deg: float = 6.0

@export_group("Collision")
@export_flags_3d_physics var hit_mask := 5
@export var exclude_player := true

@export_group("Audio - Cast")
@export var cast_sfx: AudioStream
@export_range(-60.0, 12.0, 0.1) var cast_volume_db := -6.0
@export var cast_bus := "SFX"
@export_range(0.1, 3.0, 0.01) var cast_pitch_min := 0.95
@export_range(0.1, 3.0, 0.01) var cast_pitch_max := 1.10
@export var cast_max_distance := 18.0

func _ready() -> void:
	_autowire()

func cast(damage: float, spellrange: float, spread_deg: float, is_crit: bool = false) -> void:
	cast_started.emit()
	_autowire()

	if camera == null:
		push_warning("FireballSpell: camera not assigned/found.")
		cast_finished.emit()
		return
	if projectile_scene == null:
		push_warning("FireballSpell: projectile_scene not assigned.")
		cast_finished.emit()
		return

	_play_cast_sfx()

	var count: int = maxi(1, fireballs_per_cast)
	if stats != null:
		count += stats.extra_projectiles

	var speed := projectile_speed
	if stats != null:
		speed *= stats.projectile_speed_mult

	var spawn_xform := camera.global_transform
	var base_forward := -camera.global_transform.basis.z
	spawn_xform.origin += base_forward * spawn_distance_from_cam

	var caster_node: Node = _get_exclude_node() if exclude_player else null

	for i in range(count):
		var dir := SpellUtil.apply_spread(base_forward, spread_deg)

		var yaw := 0.0
		if count > 1:
			var t := float(i) / float(count - 1)
			yaw = (t - 0.5) * multi_cast_spread_deg
		dir = _yaw_offset(dir, yaw)

		var p := projectile_scene.instantiate()
		if p.has_method("setup"):
			p.callv("setup", [
				damage,
				dir,
				caster_node,
				speed,
				spellrange,
				hit_mask,
				explosion_radius,
				aoe_damage_mult,
				is_crit
			])

		var parent := get_tree().current_scene
		if parent == null:
			parent = get_tree().root
		parent.add_child(p)

		if p is Node3D:
			(p as Node3D).global_transform = spawn_xform

	cast_finished.emit()

func _autowire() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if caster_root == null:
		var ps := get_tree().get_nodes_in_group("player")
		if ps.size() > 0:
			caster_root = ps[0]
		elif get_owner() != null:
			caster_root = get_owner()

func _get_exclude_node() -> Node:
	if caster_root != null:
		return caster_root
	return get_owner()

func _yaw_offset(dir: Vector3, yaw_deg: float) -> Vector3:
	if absf(yaw_deg) <= 0.0001:
		return dir.normalized()
	var yaw := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	return (yaw * dir).normalized()

func _play_cast_sfx() -> void:
	if cast_sfx == null or camera == null:
		return

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var p := AudioStreamPlayer3D.new()
	p.stream = cast_sfx
	p.bus = cast_bus
	p.volume_db = cast_volume_db
	p.max_distance = cast_max_distance
	p.pitch_scale = randf_range(minf(cast_pitch_min, cast_pitch_max), maxf(cast_pitch_min, cast_pitch_max))

	parent.add_child(p)
	p.global_position = camera.global_position
	p.play()
	p.finished.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)
