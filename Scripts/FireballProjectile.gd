# res://Scripts/FireballProjectile.gd

extends Node3D
class_name FireballProjectile

@export_group("Lifetime")
@export var max_lifetime: float = 4.0

@export_group("VFX")
@export var explosion_pulse_scene: PackedScene

@export_group("Audio - Flight Loop")
@export var flight_loop_sfx: AudioStream
@export_range(-60.0, 12.0, 0.1) var flight_volume_db := -14.0
@export var flight_bus := "SFX"
@export_range(0.1, 3.0, 0.01) var flight_pitch_min := 0.95
@export_range(0.1, 3.0, 0.01) var flight_pitch_max := 1.08
@export var flight_max_distance := 18.0

@export_group("Audio - Impact")
@export var impact_sfx: AudioStream
@export_range(-60.0, 12.0, 0.1) var impact_volume_db := -6.0
@export var impact_bus := "SFX"
@export_range(0.1, 3.0, 0.01) var impact_pitch_min := 0.92
@export_range(0.1, 3.0, 0.01) var impact_pitch_max := 1.12
@export var impact_max_distance := 26.0
@export var impact_autofree_after := 3.0

@export_group("Knockback")
@export var knockback_enabled := true
@export var knockback_force := 22.0
@export var knockback_upward := 0.8
@export var knockback_use_falloff := true
@export_range(0.0, 1.0, 0.05) var knockback_falloff_min := 0.35

@export_group("Camera Shake")
@export var shake_enabled := true
@export var shake_amplitude := 1.2
@export var shake_duration := 0.12
@export var shake_frequency := 30.0
@export var shake_pos_scale := 1.0
@export var shake_rot_scale := 1.0
@export var shake_max_distance_mult := 4.0
@export_range(0.0, 1.0, 0.05) var shake_min_scale := 0.0
@export var shake_use_smooth_falloff := true

var hit_mask: int = 5
var damage: float = 0.0
var caster: Node = null
var max_distance: float = 120.0
var speed: float = 28.0

@export_group("Damage")
var explosion_radius: float = 3.5
@export_range(0.0, 5.0, 0.05) var aoe_damage_mult: float = 0.65
@export var use_falloff: bool = true
@export_range(0.0, 1.0, 0.05) var falloff_min: float = 0.25

var is_crit := false

var _configured := false
var _life := 0.0
var _traveled := 0.0
var _dir: Vector3 = Vector3.FORWARD

var _flight_player: AudioStreamPlayer3D = null

func setup(
	p_damage: float,
	p_direction: Vector3,
	p_caster: Node,
	p_speed: float,
	p_max_distance: float,
	p_hit_mask: int,
	p_explosion_radius: float,
	p_aoe_damage_mult: float,
	p_is_crit: bool = false
) -> void:
	damage = p_damage
	_dir = p_direction.normalized()
	caster = p_caster
	speed = p_speed
	max_distance = p_max_distance
	hit_mask = p_hit_mask
	explosion_radius = p_explosion_radius
	aoe_damage_mult = p_aoe_damage_mult
	is_crit = p_is_crit
	_configured = true

func _ready() -> void:
	if not _configured:
		push_warning("FireballProjectile: setup() was not called. Freeing projectile to avoid undefined behavior.")
		queue_free()
		return

	_start_flight_loop()

func _exit_tree() -> void:
	_stop_flight_loop()

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

	var hit := _raycast(from, to)
	if hit.is_empty():
		global_position = to
		return

	if hit.has("position"):
		global_position = hit["position"]

	_explode(global_position, hit)
	queue_free()

func _explode(pos: Vector3, direct_hit: Dictionary) -> void:
	_stop_flight_loop()
	_play_impact_sfx(pos)

	_spawn_explosion_pulse(pos)
	_do_camera_shake(pos)

	# 1) Full damage to directly hit enemy (if any)
	var direct_collider = direct_hit.get("collider", null)
	if direct_collider != null:
		SpellUtil.apply_damage_from_hit(direct_hit, damage, is_crit, false)

	# 2) AoE damage + knockback in radius
	var enemies := get_tree().get_nodes_in_group("enemy")
	var r2 := explosion_radius * explosion_radius

	for e in enemies:
		if not (e is Node3D):
			continue
		if not is_instance_valid(e):
			continue

		var n := e as Node3D
		var d2 := n.global_position.distance_squared_to(pos)
		if d2 > r2:
			continue

		# AoE damage: skip the direct collider so it doesn't double-dip
		if e != direct_collider:
			var falloff := 1.0
			if use_falloff:
				var t := clampf(sqrt(d2) / maxf(0.001, explosion_radius), 0.0, 1.0)
				falloff = lerpf(1.0, falloff_min, t)

			var amount := damage * aoe_damage_mult * falloff
			var fake_hit := {"collider": n, "position": pos}
			SpellUtil.apply_damage_from_hit(fake_hit, amount, is_crit, false)

		if knockback_enabled:
			_apply_knockback(n, pos, d2)

func _apply_knockback(target: Node3D, origin: Vector3, dist2: float) -> void:
	var dir := (target.global_position - origin)
	if dir.length_squared() < 0.0001:
		dir = Vector3.UP
	dir = dir.normalized()
	dir.y += knockback_upward
	dir = dir.normalized()

	var strength := knockback_force
	if knockback_use_falloff:
		var t := clampf(sqrt(dist2) / maxf(0.001, explosion_radius), 0.0, 1.0)
		var f := lerpf(1.0, knockback_falloff_min, t)
		strength *= f

	if target is RigidBody3D:
		(target as RigidBody3D).apply_central_impulse(dir * strength)
		return

	if target.has_method("apply_knockback"):
		target.call("apply_knockback", dir * strength)
		return

	if target is CharacterBody3D:
		var cb := target as CharacterBody3D
		cb.velocity += dir * strength
		return

	if "velocity" in target:
		target.velocity += dir * strength
		return

func _do_camera_shake(explosion_pos: Vector3) -> void:
	if not shake_enabled:
		return

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var shaker := cam.get_node_or_null("CameraShake")
	if shaker == null:
		return
	if not shaker.has_method("shake"):
		return

	var d := cam.global_position.distance_to(explosion_pos)
	var max_d := maxf(0.01, explosion_radius * maxf(0.1, shake_max_distance_mult))
	var t := clampf(d / max_d, 0.0, 1.0)

	var shake_scale := 1.0 - t
	if shake_use_smooth_falloff:
		shake_scale = shake_scale * shake_scale * (3.0 - 2.0 * shake_scale)

	shake_scale = lerpf(shake_min_scale, 1.0, shake_scale)
	if shake_scale <= 0.001:
		return

	shaker.call(
		"shake",
		shake_amplitude * shake_scale,
		shake_duration * lerpf(0.7, 1.0, shake_scale),
		shake_frequency,
		shake_pos_scale,
		shake_rot_scale
	)

# ---------------- Audio helpers ----------------

func _start_flight_loop() -> void:
	if flight_loop_sfx == null:
		return
	if _flight_player != null and is_instance_valid(_flight_player):
		return

	_flight_player = AudioStreamPlayer3D.new()
	_flight_player.stream = flight_loop_sfx
	_flight_player.bus = flight_bus
	_flight_player.volume_db = flight_volume_db
	_flight_player.max_distance = flight_max_distance
	_flight_player.pitch_scale = randf_range(minf(flight_pitch_min, flight_pitch_max), maxf(flight_pitch_min, flight_pitch_max))
	_flight_player.autoplay = false

	add_child(_flight_player)
	_flight_player.global_position = global_position
	_flight_player.play()

func _stop_flight_loop() -> void:
	if _flight_player == null:
		return
	if is_instance_valid(_flight_player):
		_flight_player.stop()
		_flight_player.queue_free()
	_flight_player = null

func _play_impact_sfx(pos: Vector3) -> void:
	if impact_sfx == null:
		return

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var p := AudioStreamPlayer3D.new()
	p.stream = impact_sfx
	p.bus = impact_bus
	p.volume_db = impact_volume_db
	p.max_distance = impact_max_distance
	p.pitch_scale = randf_range(minf(impact_pitch_min, impact_pitch_max), maxf(impact_pitch_min, impact_pitch_max))

	parent.add_child(p)
	p.global_position = pos
	p.play()

	p.finished.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)

	if impact_autofree_after > 0.0:
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = impact_autofree_after
		t.timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)
		p.add_child(t)
		t.start()

# ---------------- Existing raycast / VFX ----------------

func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = hit_mask

	# Exclude caster if it is a CollisionObject3D
	if caster is CollisionObject3D:
		q.exclude = [(caster as CollisionObject3D).get_rid()]

	return world.direct_space_state.intersect_ray(q)

func _spawn_explosion_pulse(pos: Vector3) -> void:
	if explosion_pulse_scene == null:
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var v := explosion_pulse_scene.instantiate()
	parent.add_child(v)
	if v is Node3D:
		(v as Node3D).global_position = pos
	# If your pulse script expects radius params, keep your existing setup there (unchanged).
