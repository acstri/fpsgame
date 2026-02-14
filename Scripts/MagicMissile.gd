extends Node3D
class_name MagicMissile

signal cast_started()
signal cast_finished()

@export_group("Refs")
@export var camera: Camera3D
@export var stats: PlayerStats
@export var caster_root: Node

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 35.0
@export var spawn_distance_from_cam: float = 0.6

@export_group("Multi-shot")
@export var missiles_per_cast: int = 5
@export var missile_interval: float = 0.06
@export var multi_cast_spread_deg: float = 8.0

@export_group("Targeting")
@export var target_group_name := "enemy"
@export var target_pick_radius: float = 60.0
@export var prefer_distinct_targets := true

@export_group("Collision")
@export_flags_3d_physics var hit_mask := 5
@export var exclude_player := true

@export_group("Audio")
@export var audio_bus: StringName = &"SFX"   # fallback to Master if missing
@export var sfx_cast: AudioStream            # one-shot
@export var sfx_charge_loop: AudioStream     # looping
@export var sfx_flight_loop: AudioStream     # looping
@export_range(-60.0, 6.0, 0.5) var sfx_db := -6.0
@export_range(0.25, 2.0, 0.01) var flight_pitch_min := 0.95
@export_range(0.25, 2.0, 0.01) var flight_pitch_max := 1.05

var _charge_player: AudioStreamPlayer

func _ready() -> void:
	_autowire()
	_ensure_audio_nodes()

func cast(damage: float, spellrange: float, spread_deg: float, is_crit: bool = false) -> void:
	call_deferred("_cast_sequence", damage, spellrange, spread_deg, is_crit)

func _cast_sequence(damage: float, spellrange: float, spread_deg: float, is_crit: bool) -> void:
	cast_started.emit()
	_autowire()
	_ensure_audio_nodes()

	if camera == null:
		push_warning("MagicMissile: camera not assigned/found.")
		cast_finished.emit()
		return
	if projectile_scene == null:
		push_warning("MagicMissile: projectile_scene not assigned.")
		cast_finished.emit()
		return

	var count: int = maxi(1, missiles_per_cast)

	if stats != null:
		if "extra_projectiles" in stats:
			count += int(stats.extra_projectiles)
		if "damage_mult" in stats:
			damage *= float(stats.damage_mult)
		if "range_mult" in stats:
			spellrange *= float(stats.range_mult)
		if "spread_mult" in stats:
			spread_deg *= float(stats.spread_mult)

	_play_one_shot_2d(sfx_cast)
	_start_charge_loop()

	var spawn_xform := camera.global_transform
	var base_forward := -camera.global_transform.basis.z
	spawn_xform.origin += base_forward * spawn_distance_from_cam

	var caster_node: Node = _get_exclude_node() if exclude_player else null
	var targets: Array[Node3D] = _get_targets_near(spawn_xform.origin, target_pick_radius)

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var interval := maxf(0.0, missile_interval)

	for i in range(count):
		var dir := SpellUtil.apply_spread(base_forward, spread_deg)

		var yaw := 0.0
		if count > 1:
			var t := float(i) / float(count - 1)
			yaw = (t - 0.5) * multi_cast_spread_deg
		dir = _yaw_offset(dir, yaw)

		var missile_damage := damage
		var missile_is_crit := false
		if stats != null and stats.has_method("roll_crit"):
			var r: Dictionary = stats.roll_crit(damage)
			if r.has("damage"):
				missile_damage = float(r["damage"])
			if r.has("crit"):
				missile_is_crit = bool(r["crit"])
		else:
			missile_is_crit = is_crit

		var assigned_target: Node3D = null
		if targets.size() > 0:
			assigned_target = targets[i % targets.size()] if prefer_distinct_targets else targets[0]

		var p := projectile_scene.instantiate()
		if p.has_method("setup"):
			var pitch := randf_range(flight_pitch_min, flight_pitch_max)
			# Added params: flight_loop_stream, pitch, db, bus
			p.callv("setup", [
				missile_damage,
				dir,
				caster_node,
				projectile_speed,
				spellrange,
				hit_mask,
				missile_is_crit,
				assigned_target,
				sfx_flight_loop,
				pitch,
				sfx_db,
				audio_bus
			])
			parent.add_child(p)
			if p is Node3D:
				(p as Node3D).global_transform = spawn_xform
		else:
			push_warning("MagicMissile: projectile has no setup() method.")

		if interval > 0.0 and i < count - 1:
			await get_tree().create_timer(interval).timeout

	_stop_charge_loop()
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
	return (Basis(Vector3.UP, deg_to_rad(yaw_deg)) * dir).normalized()

func _get_targets_near(pos: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var enemies := get_tree().get_nodes_in_group(target_group_name)
	var r2 := radius * radius

	for e in enemies:
		if not (e is Node3D):
			continue
		if not is_instance_valid(e):
			continue
		var n := e as Node3D
		if pos.distance_squared_to(n.global_position) <= r2:
			out.append(n)

	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return pos.distance_squared_to(a.global_position) < pos.distance_squared_to(b.global_position)
	)
	return out

# ----------------
# Audio (2D, bus-safe)
# ----------------

func _ensure_audio_nodes() -> void:
	if _charge_player != null and is_instance_valid(_charge_player):
		return
	_charge_player = AudioStreamPlayer.new()
	_charge_player.name = "MM_ChargeLoop"
	_charge_player.bus = _resolve_bus(audio_bus)
	_charge_player.volume_db = sfx_db
	add_child(_charge_player)

func _resolve_bus(preferred: StringName) -> StringName:
	if AudioServer.get_bus_index(String(preferred)) != -1:
		return preferred
	return &"Master"

func _play_one_shot_2d(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = _resolve_bus(audio_bus)
	p.volume_db = sfx_db
	p.stream = stream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _start_charge_loop() -> void:
	if sfx_charge_loop == null:
		return
	_charge_player.bus = _resolve_bus(audio_bus)
	_charge_player.volume_db = sfx_db
	_charge_player.stream = sfx_charge_loop
	if not _charge_player.playing:
		_charge_player.play()

func _stop_charge_loop() -> void:
	if _charge_player != null and is_instance_valid(_charge_player) and _charge_player.playing:
		_charge_player.stop()
