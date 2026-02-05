extends Node3D
class_name HitscanWeapon

signal fired()
signal dry_fired()
signal reloaded()
signal ammo_changed(in_mag: int, mag_size: int, reserve: int)

@export_group("Refs")
@export var camera: Camera3D
@export var stats: PlayerStats # optional (drag Player/Stats here)

@export_group("Stats")
@export var base_damage := 10.0
@export var base_range := 200.0
@export var base_fire_rate := 8.0
@export var spread_deg := 0.4

@export_group("Ammo")
@export var mag_size := 30
@export var ammo_in_mag := 30
@export var ammo_reserve := 120
@export var infinite_ammo := false
@export var reload_time := 1.2

@export_group("Collision")
@export_flags_3d_physics var hit_mask := 0

var _cooldown := 0.0
var _reloading := false
var _reload_timer := 0.0

func _ready() -> void:
	_emit_ammo()

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

func try_fire() -> void:
	if _reloading or _cooldown > 0.0:
		return

	if not infinite_ammo and ammo_in_mag <= 0:
		dry_fired.emit()
		_cooldown = 0.15
		return

	var fire_rate := base_fire_rate
	if stats != null:
		fire_rate *= stats.fire_rate_mult
	_cooldown = 1.0 / maxf(0.01, fire_rate)

	if not infinite_ammo:
		ammo_in_mag -= 1
		_emit_ammo()

	fired.emit()
	_fire_once() # child can override behavior (rifle=1 ray, shotgun=pellets)

func try_reload() -> void:
	if _reloading or infinite_ammo:
		return
	if ammo_in_mag >= mag_size:
		return
	if ammo_reserve <= 0:
		return

	_reloading = true
	_reload_timer = maxf(0.01, reload_time)

func _finish_reload() -> void:
	_reloading = false

	var needed := mag_size - ammo_in_mag
	var take := mini(needed, ammo_reserve)
	ammo_in_mag += take
	ammo_reserve -= take

	_emit_ammo()
	reloaded.emit()

func _fire_once() -> void:
	# default: one hitscan ray (rifle)
	_do_hitscan(base_damage, spread_deg)

func _do_hitscan(dmg_base: float, spread: float) -> void:
	if camera == null:
		return

	var from := camera.global_transform.origin
	var dir := -camera.global_transform.basis.z
	dir = _apply_spread(dir, spread)
	var to := from + dir * base_range

	var world: World3D = camera.get_viewport().get_world_3d()
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = hit_mask
	q.collide_with_areas = true
	q.collide_with_bodies = true

	var hit := space.intersect_ray(q)
	if hit.is_empty():
		print("NO HIT")
		return
	print("HIT:", hit["collider"], "at", hit["position"])

	var dmg := dmg_base
	if stats != null:
		dmg *= stats.damage_mult

	var collider: Object = hit.get("collider")
	if collider != null and collider.has_method("apply_damage"):
		collider.apply_damage(dmg, hit)
	elif collider != null and collider.get_parent() != null and collider.get_parent().has_method("apply_damage"):
		collider.get_parent().apply_damage(dmg, hit)

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

func _emit_ammo() -> void:
	ammo_changed.emit(ammo_in_mag, mag_size, ammo_reserve)
