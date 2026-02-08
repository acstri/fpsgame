# res://Scripts/Director.gd
extends Node
class_name Director

@export_group("Refs")
@export var player_group := "player"
@export var enemy_scene: PackedScene

@export_group("Spawn Area")
@export var spawn_radius_min := 18.0
@export var spawn_radius_max := 28.0
@export var max_spawn_tries := 10
@export var spawn_height_offset := 0.2

@export_group("Pacing")
@export var start_spawns_per_second := 0.6
@export var max_spawns_per_second := 4.0
@export var ramp_minutes := 6.0
@export var max_alive_enemies := 120

@export_group("Collision Check")
@export_flags_3d_physics var avoid_mask := 0
@export var avoid_radius := 1.0

@export_group("Ground Finding (NEW)")
@export var ground_group := "ground"                # put all walkable ground colliders into this group
@export_flags_3d_physics var ground_mask := 0        # collision mask for ground raycasts (set this!)
@export var ground_raycast_height := 60.0            # ray start above candidate point
@export var ground_raycast_depth := 120.0            # how far down to search
@export var require_ground_group := true             # if true, only accept hits on nodes in ground_group

@export_group("Legacy Map Bounds (optional)")
@export var use_legacy_box_bounds := false
@export var ground_body_path: NodePath               # legacy: single floor StaticBody3D with BoxShape3D
@export var bounds_margin := 1.0

var _player: Node3D = null
var _spawn_accum: float = 0.0
var _time: float = 0.0

# legacy (optional)
var _ground_body: StaticBody3D = null
var _ground_shape: CollisionShape3D = null

var _ready_ok := false
var _avoid_shape: SphereShape3D

func _ready() -> void:
	_ready_ok = _autowire_and_validate()
	if not _ready_ok:
		set_physics_process(false)
		return

	_avoid_shape = SphereShape3D.new()
	_avoid_shape.radius = avoid_radius

func _physics_process(delta: float) -> void:
	if not _ready_ok:
		return

	_time += delta

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		# If player isn't present yet, don't accumulate time/spawns
		return

	if enemy_scene == null:
		return

	var alive := _alive_enemies()
	if alive >= max_alive_enemies:
		return

	var rate: float = _current_spawn_rate()
	_spawn_accum += rate * delta

	while _spawn_accum >= 1.0 and alive < max_alive_enemies:
		_spawn_accum -= 1.0
		if _spawn_one():
			alive += 1
		else:
			break

func _current_spawn_rate() -> float:
	var ramp_seconds: float = maxf(1.0, ramp_minutes * 60.0)
	var t: float = clamp(_time / ramp_seconds, 0.0, 1.0)
	return lerpf(start_spawns_per_second, max_spawns_per_second, t)

func _spawn_one() -> bool:
	var pos: Vector3 = _find_spawn_position()
	if pos == Vector3.INF:
		return false

	var enemy: Node3D = enemy_scene.instantiate() as Node3D
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(enemy)
	enemy.global_position = pos
	return true

func _find_spawn_position() -> Vector3:
	# Legacy mode: keep your old “box floor bounds” behavior if you enable it.
	if use_legacy_box_bounds and _ground_body != null and _ground_shape != null and (_ground_shape.shape is BoxShape3D):
		return _find_spawn_position_legacy_box()

	# New mode: pick a point around the player, raycast down to ground.
	return _find_spawn_position_by_ground_raycast()

# -------------------------
# NEW: group-based ground raycast
# -------------------------

func _find_spawn_position_by_ground_raycast() -> Vector3:
	if ground_mask == 0:
		push_warning("Director: ground_mask is 0. Set it to the collision layer(s) used by ground.")
		return Vector3.INF

	var world: World3D = get_viewport().get_world_3d()
	if world == null:
		return Vector3.INF
	var space: PhysicsDirectSpaceState3D = world.direct_space_state

	for i in range(max_spawn_tries):
		var p := _random_point_around_player()

		var from := Vector3(p.x, p.y + ground_raycast_height, p.z)
		var to := Vector3(p.x, p.y - ground_raycast_depth, p.z)

		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = ground_mask
		q.collide_with_areas = true
		q.collide_with_bodies = true

		# Exclude player body if possible (so we don't hit ourselves if the player has collision)
		var ex := _get_exclude_rids()
		if not ex.is_empty():
			q.exclude = ex

		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue

		var collider = hit.get("collider", null)
		if require_ground_group and collider != null:
			# Accept if collider (or its parent chain) is in group
			if not _node_or_parent_in_group(collider, ground_group):
				continue

		var pos = hit.get("position", Vector3.INF)
		if pos == Vector3.INF:
			continue

		pos.y += spawn_height_offset

		# keep away from player (3D distance feels odd on ramps; use horizontal distance)
		if _player != null:
			var dx = pos.x - _player.global_position.x
			var dz = pos.z - _player.global_position.z
			var horiz := sqrt(dx * dx + dz * dz)
			if horiz < spawn_radius_min:
				continue

		if _is_position_free(pos):
			return pos

	return Vector3.INF

func _random_point_around_player() -> Vector3:
	# Uniform area sampling in an annulus (better distribution than linear radius)
	var a := randf_range(0.0, TAU)
	var rmin := maxf(0.0, spawn_radius_min)
	var rmax := maxf(rmin + 0.01, spawn_radius_max)

	var r := sqrt(randf_range(rmin * rmin, rmax * rmax))
	var x := cos(a) * r
	var z := sin(a) * r

	var base := _player.global_position
	return Vector3(base.x + x, base.y, base.z + z)

func _node_or_parent_in_group(n: Object, group_name: String) -> bool:
	if n == null:
		return false
	if n is Node:
		var node := n as Node
		var cur: Node = node
		while cur != null:
			if cur.is_in_group(group_name):
				return true
			cur = cur.get_parent()
	return false

# -------------------------
# Legacy: old single-floor BoxShape bounds
# -------------------------

func _find_spawn_position_legacy_box() -> Vector3:
	var box := _ground_shape.shape as BoxShape3D
	var ext: Vector3 = box.size * 0.5

	var gt: Transform3D = _ground_shape.global_transform
	var center: Vector3 = gt.origin

	var min_x := center.x - ext.x + bounds_margin
	var max_x := center.x + ext.x - bounds_margin
	var min_z := center.z - ext.z + bounds_margin
	var max_z := center.z + ext.z - bounds_margin

	var floor_top_y := center.y + ext.y

	for i in range(max_spawn_tries):
		var x := randf_range(min_x, max_x)
		var z := randf_range(min_z, max_z)
		var pos := Vector3(x, floor_top_y + spawn_height_offset, z)

		if _player != null and _player.global_position.distance_to(pos) < spawn_radius_min:
			continue

		if _is_position_free(pos):
			return pos

	return Vector3.INF

# -------------------------
# Shared helpers
# -------------------------

func _is_position_free(pos: Vector3) -> bool:
	if avoid_mask == 0:
		return true

	var world: World3D = get_viewport().get_world_3d()
	if world == null:
		return true

	var space: PhysicsDirectSpaceState3D = world.direct_space_state

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _avoid_shape
	params.transform = Transform3D(Basis(), pos + Vector3.UP * avoid_radius)
	params.collision_mask = avoid_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var hits: Array[Dictionary] = space.intersect_shape(params, 1)
	return hits.is_empty()

func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group("enemy").size()

func _find_player() -> Node3D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(player_group)
	return null if nodes.is_empty() else nodes[0] as Node3D

func _get_exclude_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if _player == null:
		return rids

	if _player is CollisionObject3D:
		rids.append((_player as CollisionObject3D).get_rid())
	return rids

func _autowire_and_validate() -> bool:
	# Legacy wiring (optional)
	_ground_body = get_node_or_null(ground_body_path) as StaticBody3D
	if use_legacy_box_bounds:
		if _ground_body == null:
			push_error("Director: use_legacy_box_bounds is ON but ground_body_path is not set to a StaticBody3D. Spawning disabled.")
			return false

		_ground_shape = _ground_body.find_child("CollisionShape3D", true, false) as CollisionShape3D
		if _ground_shape == null or not (_ground_shape.shape is BoxShape3D):
			push_error("Director: Legacy mode requires Ground CollisionShape3D with a BoxShape3D. Spawning disabled.")
			return false

	# New mode validation
	if not use_legacy_box_bounds:
		if ground_mask == 0:
			push_warning("Director: ground_mask is 0. Set it to the collision layer(s) used by your ground.")
		if require_ground_group:
			# Not fatal; but helpful warning if you forgot to tag your ground pieces.
			var grounds := get_tree().get_nodes_in_group(ground_group)
			if grounds.is_empty():
				push_warning("Director: require_ground_group is ON but no nodes are in group '%s'." % ground_group)

	if max_alive_enemies < 1:
		push_warning("Director: max_alive_enemies < 1; no spawns will occur.")
	return true
