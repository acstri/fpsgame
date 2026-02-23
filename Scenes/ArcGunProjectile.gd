# res://Scripts/ArcGunProjectile.gd
extends Node3D
class_name ArcGunProjectile

@export_group("Lifetime")
@export var max_lifetime: float = 3.0

@export_group("Collision (anti-tunneling)")
@export var hit_radius: float = 0.12
@export var extra_rays: int = 4

@export_group("SFX - Flight")
@export var fly_stream: AudioStream
@export var fly_bus: StringName = &"SFX"
@export_range(-60.0, 12.0, 0.1) var fly_volume_db := -18.0
@export_range(0.5, 2.0, 0.01) var fly_pitch_min := 0.98
@export_range(0.5, 2.0, 0.01) var fly_pitch_max := 1.08
@export var fly_max_distance := 24.0
@export var fly_unit_size := 1.0

@export_group("SFX - Impact")
@export var impact_stream: AudioStream
@export var impact_bus: StringName = &"SFX"
@export_range(-60.0, 12.0, 0.1) var impact_volume_db := -10.0
@export_range(0.5, 2.0, 0.01) var impact_pitch_min := 0.95
@export_range(0.5, 2.0, 0.01) var impact_pitch_max := 1.10
@export var impact_max_distance := 28.0
@export var impact_unit_size := 1.0

var hit_mask: int = 5
var damage: float = 0.0
var caster: Node = null
var speed: float = 70.0
var max_distance: float = 80.0
var is_crit: bool = false

var _dir: Vector3 = Vector3.FORWARD
var _life := 0.0
var _traveled := 0.0
var _configured := false

var _fly_player: AudioStreamPlayer3D

func setup(
	p_damage: float,
	p_dir: Vector3,
	p_caster: Node,
	p_speed: float,
	p_max_dist: float,
	p_mask: int,
	p_is_crit: bool = false
) -> void:
	damage = p_damage
	_dir = p_dir.normalized()
	caster = p_caster
	speed = p_speed
	max_distance = p_max_dist
	hit_mask = p_mask
	is_crit = p_is_crit
	_configured = true

func _ready() -> void:
	if not _configured:
		push_warning("ArcGunProjectile: setup() not called.")
		queue_free()
		return
	_start_fly_sfx()

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= max_lifetime:
		queue_free()
		return

	var from := global_position
	var to := from + _dir * speed * delta

	_traveled += from.distance_to(to)
	if _traveled >= max_distance:
		queue_free()
		return

	var hit := _sweep(from, to)
	if hit.is_empty():
		global_position = to
		return

	var hit_pos: Vector3 = hit.get("position", to)
	global_position = hit_pos

	SpellUtil.apply_damage_from_hit(hit, damage, is_crit)
	_play_impact_sfx(hit_pos)
	queue_free()

func _start_fly_sfx() -> void:
	if fly_stream == null:
		return
	_fly_player = AudioStreamPlayer3D.new()
	_fly_player.name = "_FlySfx"
	_fly_player.stream = fly_stream
	_fly_player.bus = String(fly_bus)
	_fly_player.volume_db = fly_volume_db
	_fly_player.pitch_scale = randf_range(minf(fly_pitch_min, fly_pitch_max), maxf(fly_pitch_min, fly_pitch_max))
	_fly_player.max_distance = fly_max_distance
	_fly_player.unit_size = fly_unit_size
	_fly_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_fly_player.autoplay = false
	add_child(_fly_player)
	_fly_player.play()

func _play_impact_sfx(pos: Vector3) -> void:
	if impact_stream == null:
		return
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var p := AudioStreamPlayer3D.new()
	p.name = "_ArcGunImpactSfx"
	p.stream = impact_stream
	p.bus = String(impact_bus)
	p.volume_db = impact_volume_db
	p.pitch_scale = randf_range(minf(impact_pitch_min, impact_pitch_max), maxf(impact_pitch_min, impact_pitch_max))
	p.max_distance = impact_max_distance
	p.unit_size = impact_unit_size
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.autoplay = false

	parent.add_child(p)
	p.global_position = pos
	p.play()

	p.finished.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var best := _ray(from, to)
	var best_d2 := INF
	if not best.is_empty():
		best_d2 = from.distance_squared_to(best.get("position", to))

	if extra_rays <= 0 or hit_radius <= 0.0:
		return best

	var d := (to - from)
	if d.length_squared() < 0.000001:
		return best
	d = d.normalized()

	var up := Vector3.UP
	if abs(d.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var right := d.cross(up).normalized()
	up = right.cross(d).normalized()

	var offsets := [right * hit_radius, -right * hit_radius, up * hit_radius, -up * hit_radius]
	var count = min(extra_rays, offsets.size())

	for i in range(count):
		var h := _ray(from + offsets[i], to + offsets[i])
		if h.is_empty():
			continue
		var d2 := from.distance_squared_to(h.get("position", to))
		if d2 < best_d2:
			best = h
			best_d2 = d2

	return best

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var space := world.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = hit_mask
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = _exclude_rids()
	return space.intersect_ray(q)

func _exclude_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if caster == null:
		return rids
	if caster is CollisionObject3D:
		rids.append((caster as CollisionObject3D).get_rid())
	return rids
