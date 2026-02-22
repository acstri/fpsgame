extends Node
class_name Director

@export_group("Refs")
@export var player_group := "player"
@export var enemy_scene: PackedScene

@export_group("Spawn Area (around player)")
@export var spawn_radius_min := 18.0
@export var spawn_radius_max := 28.0
@export var max_spawn_tries := 10
@export var spawn_height_offset := 0.2

@export_group("Pacing (single spawns)")
@export var start_spawns_per_second := 0.6
@export var max_spawns_per_second := 4.0
@export var ramp_minutes := 6.0
@export var max_alive_enemies := 120

@export_group("Burst Chance (optional)")
@export var bursts_enabled := true
@export_range(0.0, 1.0, 0.01) var burst_chance := 0.18   # chance that a "spawn 1" becomes a burst
@export var burst_cooldown := 2.25                       # minimum seconds between burst triggers
@export var burst_size_min := 4
@export var burst_size_max := 10
@export var burst_cluster_radius := 4.5                  # spread around burst center
@export var burst_telegraph_delay := 0.65                # warning time before enemies appear
@export var burst_spawn_stagger := 0.0                   # 0 = all same frame; >0 = per-enemy delay

@export_group("Ground Finding")
@export var ground_group := "ground"
@export_flags_3d_physics var ground_mask := 0
@export var ground_raycast_height := 60.0
@export var ground_raycast_depth := 120.0
@export var require_ground_group := true

@export_group("Collision Check (avoid overlaps)")
@export_flags_3d_physics var avoid_mask := 0
@export var avoid_radius := 1.0

@export_group("Telegraph (Visual + Audio)")
@export var telegraph_scene: PackedScene                 # optional custom indicator (Node3D)
@export var telegraph_color: Color = Color(1, 0.2, 0.2, 1)
@export var telegraph_ring_radius := 2.5
@export var telegraph_ring_thickness := 0.15
@export var telegraph_pulse_scale := 1.15
@export var telegraph_y_offset := 0.05
@export var telegraph_sound: AudioStream                 # played when warning appears
@export var spawn_sound: AudioStream                     # played when burst spawns
@export var telegraph_bus := "SFX"
@export var telegraph_volume_db := -6.0
@export var spawn_volume_db := -4.0

var _player: Node3D

var _spawn_accum := 0.0
var _time := 0.0

var _burst_cd_left := 0.0

var _avoid_shape: SphereShape3D

class PendingBurst:
	var center: Vector3
	var count: int
	var delay_left: float
	var per_enemy_stagger: float
	var spawned: int
	var next_enemy_in: float
	var telegraph_node: Node3D

	func _init(p_center: Vector3, p_count: int, p_delay: float, p_stagger: float, p_tele: Node3D) -> void:
		center = p_center
		count = p_count
		delay_left = p_delay
		per_enemy_stagger = p_stagger
		spawned = 0
		next_enemy_in = 0.0
		telegraph_node = p_tele

var _pending: Array[PendingBurst] = []

func _ready() -> void:
	_avoid_shape = SphereShape3D.new()
	_avoid_shape.radius = avoid_radius

func _physics_process(delta: float) -> void:
	_time += delta
	if _burst_cd_left > 0.0:
		_burst_cd_left = maxf(0.0, _burst_cd_left - delta)

	_player = _find_player()
	if _player == null or not is_instance_valid(_player):
		return
	if enemy_scene == null:
		return

	_tick_pending_bursts(delta)

	var alive := _alive_enemies()
	if alive >= max_alive_enemies:
		return

	var rate := _current_spawn_rate()
	_spawn_accum += rate * delta

	while _spawn_accum >= 1.0 and _alive_enemies() < max_alive_enemies:
		_spawn_accum -= 1.0
		_spawn_one_or_burst()

# -------------------------
# Spawn logic
# -------------------------

func _spawn_one_or_burst() -> void:
	if bursts_enabled and _burst_cd_left <= 0.0 and randf() < burst_chance:
		if _try_start_burst():
			_burst_cd_left = burst_cooldown
			return
	# fallback: single spawn (as before)
	_spawn_one()

func _spawn_one() -> bool:
	var pos := _find_spawn_position_around_player()
	if pos == Vector3.INF:
		return false

	var enemy := enemy_scene.instantiate() as Node3D
	if enemy == null:
		return false

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(enemy)
	enemy.global_position = pos
	return true

func _try_start_burst() -> bool:
	# pick a burst center near player
	var center := _find_spawn_position_around_player()
	if center == Vector3.INF:
		return false

	var count := randi_range(max(1, burst_size_min), max(1, burst_size_max))
	var tele := _spawn_telegraph(center)

	var b := PendingBurst.new(
		center,
		count,
		maxf(0.0, burst_telegraph_delay),
		maxf(0.0, burst_spawn_stagger),
		tele
	)
	_pending.append(b)
	return true

# -------------------------
# Pending bursts
# -------------------------

func _tick_pending_bursts(delta: float) -> void:
	if _pending.is_empty():
		return

	for i in range(_pending.size() - 1, -1, -1):
		var b := _pending[i]

		if b.delay_left > 0.0:
			b.delay_left = maxf(0.0, b.delay_left - delta)
			continue

		# burst is armed: spawn enemies
		if b.per_enemy_stagger <= 0.0:
			_play_3d_sound(spawn_sound, b.center, spawn_volume_db)
			for _k in range(b.count):
				if _alive_enemies() >= max_alive_enemies:
					break
				_spawn_one_near(b.center)
			_finish_burst(i, b)
		else:
			if b.spawned == 0:
				_play_3d_sound(spawn_sound, b.center, spawn_volume_db)

			b.next_enemy_in = maxf(0.0, b.next_enemy_in - delta)
			while b.next_enemy_in <= 0.0 and b.spawned < b.count and _alive_enemies() < max_alive_enemies:
				_spawn_one_near(b.center)
				b.spawned += 1
				b.next_enemy_in += b.per_enemy_stagger

			if b.spawned >= b.count:
				_finish_burst(i, b)

func _finish_burst(index: int, b: PendingBurst) -> void:
	if b.telegraph_node != null and is_instance_valid(b.telegraph_node):
		b.telegraph_node.queue_free()
	_pending.remove_at(index)

func _spawn_one_near(center: Vector3) -> bool:
	var pos := _find_spawn_position_near(center)
	if pos == Vector3.INF:
		return false

	var enemy := enemy_scene.instantiate() as Node3D
	if enemy == null:
		return false

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(enemy)
	enemy.global_position = pos
	return true

# -------------------------
# Spawn position finding
# -------------------------

func _find_spawn_position_around_player() -> Vector3:
	if ground_mask == 0:
		push_warning("Director: ground_mask is 0. Set it to the collision layer(s) used by ground.")
		return Vector3.INF

	var world := get_viewport().get_world_3d()
	if world == null:
		return Vector3.INF
	var space := world.direct_space_state

	for _i in range(max_spawn_tries):
		var p := _random_point_around_player()

		var from := Vector3(p.x, p.y + ground_raycast_height, p.z)
		var to := Vector3(p.x, p.y - ground_raycast_depth, p.z)

		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = ground_mask
		q.collide_with_areas = true
		q.collide_with_bodies = true

		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue

		var collider = hit.get("collider", null)
		if require_ground_group and collider != null:
			if not _node_or_parent_in_group(collider, ground_group):
				continue

		var pos: Vector3 = hit.get("position", Vector3.INF)
		if pos == Vector3.INF:
			continue

		pos.y += spawn_height_offset

		# keep minimum radius from player
		var dx := pos.x - _player.global_position.x
		var dz := pos.z - _player.global_position.z
		var horiz := sqrt(dx * dx + dz * dz)
		if horiz < spawn_radius_min:
			continue

		if _is_position_free(pos):
			return pos

	return Vector3.INF

func _find_spawn_position_near(center: Vector3) -> Vector3:
	if ground_mask == 0:
		return Vector3.INF

	var world := get_viewport().get_world_3d()
	if world == null:
		return Vector3.INF
	var space := world.direct_space_state

	for _i in range(max_spawn_tries):
		var a := randf_range(0.0, TAU)
		var r := sqrt(randf_range(0.0, burst_cluster_radius * burst_cluster_radius))
		var x := cos(a) * r
		var z := sin(a) * r

		var p := Vector3(center.x + x, center.y, center.z + z)

		var from := Vector3(p.x, p.y + ground_raycast_height, p.z)
		var to := Vector3(p.x, p.y - ground_raycast_depth, p.z)

		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = ground_mask
		q.collide_with_areas = true
		q.collide_with_bodies = true

		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue

		var collider = hit.get("collider", null)
		if require_ground_group and collider != null:
			if not _node_or_parent_in_group(collider, ground_group):
				continue

		var pos: Vector3 = hit.get("position", Vector3.INF)
		if pos == Vector3.INF:
			continue

		pos.y += spawn_height_offset

		# keep minimum radius from player
		if _player != null:
			var dx := pos.x - _player.global_position.x
			var dz := pos.z - _player.global_position.z
			var horiz := sqrt(dx * dx + dz * dz)
			if horiz < spawn_radius_min:
				continue

		if _is_position_free(pos):
			return pos

	return Vector3.INF

func _random_point_around_player() -> Vector3:
	var a := randf_range(0.0, TAU)
	var rmin := maxf(0.0, spawn_radius_min)
	var rmax := maxf(rmin + 0.01, spawn_radius_max)
	var r := sqrt(randf_range(rmin * rmin, rmax * rmax))
	var x := cos(a) * r
	var z := sin(a) * r
	var base := _player.global_position
	return Vector3(base.x + x, base.y, base.z + z)

# -------------------------
# Telegraph
# -------------------------

func _spawn_telegraph(center: Vector3) -> Node3D:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var node: Node3D

	if telegraph_scene != null:
		node = telegraph_scene.instantiate() as Node3D
		parent.add_child(node)
		node.global_position = center + Vector3(0, telegraph_y_offset, 0)
	else:
		node = Node3D.new()
		node.name = "SpawnTelegraph"
		parent.add_child(node)
		node.global_position = center + Vector3(0, telegraph_y_offset, 0)

		var mesh := MeshInstance3D.new()

		# Ring using a thin cylinder (Godot 4-friendly)
		var ring := CylinderMesh.new()
		ring.top_radius = telegraph_ring_radius
		ring.bottom_radius = telegraph_ring_radius
		ring.height = telegraph_ring_thickness
		ring.radial_segments = 48

		mesh.mesh = ring
		# lay it flat on the ground (cylinder axis is Y)
		mesh.rotation_degrees = Vector3(90, 0, 0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = telegraph_color
		mat.emission_enabled = true
		mat.emission = telegraph_color
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.85
		mesh.material_override = mat

		node.add_child(mesh)

		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD)
		tw.set_ease(Tween.EASE_OUT)
		var base := node.scale
		tw.tween_property(node, "scale", base * telegraph_pulse_scale, 0.18)
		tw.tween_property(node, "scale", base, 0.18)
		

	_play_3d_sound(telegraph_sound, center + Vector3(0, telegraph_y_offset, 0), telegraph_volume_db)
	return node

func _play_3d_sound(stream: AudioStream, pos: Vector3, vol_db: float) -> void:
	if stream == null:
		return
	if not is_inside_tree():
		return

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if parent == null:
		return

	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = telegraph_bus
	p.volume_db = vol_db
	parent.add_child(p)

	# Now it is in the tree: setting global_position is safe
	p.global_position = pos

	p.finished.connect(func(): p.queue_free())
	p.play()

# -------------------------
# Helpers
# -------------------------

func _current_spawn_rate() -> float:
	var ramp_seconds := maxf(1.0, ramp_minutes * 60.0)
	var t := clampf(_time / ramp_seconds, 0.0, 1.0)
	return lerpf(start_spawns_per_second, max_spawns_per_second, t)

func _is_position_free(pos: Vector3) -> bool:
	if avoid_mask == 0:
		return true

	var world := get_viewport().get_world_3d()
	if world == null:
		return true
	var space := world.direct_space_state

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _avoid_shape
	params.transform = Transform3D(Basis(), pos + Vector3.UP * avoid_radius)
	params.collision_mask = avoid_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var hits := space.intersect_shape(params, 1)
	return hits.is_empty()

func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group("enemy").size()

func _find_player() -> Node3D:
	var nodes := get_tree().get_nodes_in_group(player_group)
	return null if nodes.is_empty() else nodes[0] as Node3D

func _node_or_parent_in_group(n: Object, group_name: String) -> bool:
	if n == null:
		return false
	if n is Node:
		var cur := n as Node
		while cur != null:
			if cur.is_in_group(group_name):
				return true
			cur = cur.get_parent()
	return false
