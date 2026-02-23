# res://Scripts/ArcGunSpell.gd
extends Node3D
class_name ArcGunSpell

@export_group("Refs")
@export var camera: Camera3D
@export var stats: PlayerStats
@export var caster_root: Node

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 70.0
@export var spawn_distance_from_cam: float = 0.6

@export_group("Collision")
@export_flags_3d_physics var hit_mask: int = 5
@export var exclude_player := true

@export_group("SFX - Cast")
@export var cast_stream: AudioStream
@export var cast_bus: StringName = &"SFX"
@export_range(-60.0, 12.0, 0.1) var cast_volume_db := -8.0
@export_range(0.5, 2.0, 0.01) var cast_pitch_min := 0.96
@export_range(0.5, 2.0, 0.01) var cast_pitch_max := 1.06
@export var cast_max_distance := 28.0
@export var cast_unit_size := 1.0

var _cast_player: AudioStreamPlayer3D

func _ready() -> void:
	_autowire()
	_ensure_cast_player()

func cast(damage: float, spellrange: float, spread_deg: float, is_crit: bool = false) -> void:
	_autowire()
	if camera == null:
		push_warning("ArcGunSpell: camera not assigned/found.")
		return
	if projectile_scene == null:
		push_warning("ArcGunSpell: projectile_scene not assigned.")
		return

	_play_cast_sfx()

	var forward: Vector3 = -camera.global_transform.basis.z
	var dir: Vector3 = SpellUtil.apply_spread(forward, spread_deg)

	var spawn_xform := camera.global_transform
	spawn_xform.origin += forward * spawn_distance_from_cam

	var caster_node: Node = _get_exclude_node() if exclude_player else null

	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var p: Node = projectile_scene.instantiate()
	if p == null:
		return

	if p.has_method("setup"):
		p.callv("setup", [
			damage,
			dir,
			caster_node,
			projectile_speed,
			spellrange,
			hit_mask,
			is_crit
		])

	parent.add_child(p)
	if p is Node3D:
		(p as Node3D).global_transform = spawn_xform

func _play_cast_sfx() -> void:
	if cast_stream == null:
		return
	_ensure_cast_player()
	if _cast_player == null:
		return

	_cast_player.global_position = (camera.global_position if camera != null else global_position)
	_cast_player.stream = cast_stream
	_cast_player.bus = String(cast_bus)
	_cast_player.volume_db = cast_volume_db
	_cast_player.pitch_scale = randf_range(minf(cast_pitch_min, cast_pitch_max), maxf(cast_pitch_min, cast_pitch_max))
	_cast_player.max_distance = cast_max_distance
	_cast_player.unit_size = cast_unit_size

	# restart for rapid-fire consistency
	if _cast_player.playing:
		_cast_player.stop()
	_cast_player.play()

func _ensure_cast_player() -> void:
	if _cast_player != null and is_instance_valid(_cast_player):
		return
	_cast_player = AudioStreamPlayer3D.new()
	_cast_player.name = "_ArcGunCastSfx"
	_cast_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_cast_player.autoplay = false
	add_child(_cast_player)

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
