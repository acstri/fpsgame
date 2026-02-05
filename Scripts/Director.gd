extends Node
class_name Director

@export_group("Refs")
@export var player_group := "player"
@export var enemy_scene: PackedScene

@export_group("Spawn Area")
@export var spawn_radius_min := 18.0
@export var spawn_radius_max := 28.0
@export var max_spawn_tries := 8
@export var spawn_height_offset := 0.5

@export_group("Pacing")
@export var start_spawns_per_second := 0.6
@export var max_spawns_per_second := 4.0
@export var ramp_minutes := 6.0
@export var max_alive_enemies := 120

@export_group("Collision Check")
@export_flags_3d_physics var avoid_mask := 0
@export var avoid_radius := 1.0

var _player: Node3D = null
var _spawn_accum: float = 0.0
var _time: float = 0.0

@export_group("Map Bounds")
@export var ground_body_path: NodePath          # drag your floor (CSGBox3D) here
@export var bounds_margin := 1.0   
var _ground_body: StaticBody3D = null
var _ground_shape: CollisionShape3D = null             # keep away from edges


func _ready() -> void:
	_ground_body = get_node_or_null(ground_body_path) as StaticBody3D
	if _ground_body == null:
		push_warning("Director: ground_body_path not set to a StaticBody3D.")
		return

	_ground_shape = _ground_body.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if _ground_shape == null or not (_ground_shape.shape is BoxShape3D):
		push_warning("Director: Ground needs a CollisionShape3D with a BoxShape3D for bounds spawning.")

func _physics_process(delta: float) -> void:
	

	_time += delta

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		return

	if enemy_scene == null:
		return

	if _alive_enemies() >= max_alive_enemies:
		return

	var rate: float = _current_spawn_rate()
	_spawn_accum += rate * delta

	while _spawn_accum >= 1.0 and _alive_enemies() < max_alive_enemies:
		_spawn_accum -= 1.0
		_spawn_one()


func _current_spawn_rate() -> float:
	var ramp_seconds: float = maxf(1.0, ramp_minutes * 60.0)
	var t: float = clamp(_time / ramp_seconds, 0.0, 1.0)
	return lerpf(start_spawns_per_second, max_spawns_per_second, t)

func _spawn_one() -> void:
	var pos: Vector3 = _find_spawn_position()
	if pos == Vector3.INF:
		return
		
	var enemy: Node3D = enemy_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos

func _find_spawn_position() -> Vector3:
	if _ground_body == null or _ground_shape == null:
		return Vector3.INF
	if not (_ground_shape.shape is BoxShape3D):
		return Vector3.INF

	var box := _ground_shape.shape as BoxShape3D
	var ext: Vector3 = box.size * 0.5

	# Ground collision shape transform in world space
	var gt: Transform3D = _ground_shape.global_transform
	var center: Vector3 = gt.origin

	# Assume floor is NOT rotated (typical). If it is rotated, we’ll do a better method.
	var min_x := center.x - ext.x + bounds_margin
	var max_x := center.x + ext.x - bounds_margin
	var min_z := center.z - ext.z + bounds_margin
	var max_z := center.z + ext.z - bounds_margin

	# Top surface of the box
	var floor_top_y := center.y + ext.y

	for i in range(max_spawn_tries):
		var x := randf_range(min_x, max_x)
		var z := randf_range(min_z, max_z)
		var pos := Vector3(x, floor_top_y + spawn_height_offset, z)

		# optional: keep away from player
		if _player != null and _player.global_position.distance_to(pos) < spawn_radius_min:
			continue

		if _is_position_free(pos):
			return pos

	return Vector3.INF



func _is_position_free(pos: Vector3) -> bool:
	var world: World3D = get_viewport().get_world_3d()
	if world == null:
		return true

	var space: PhysicsDirectSpaceState3D = world.direct_space_state

	var shape := SphereShape3D.new()
	shape.radius = avoid_radius

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
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
	if nodes.is_empty():
		return null
	return nodes[0] as Node3D
