extends Node3D
class_name ChainLightning

signal cast_started()
signal cast_finished(hit: Dictionary) # empty dict = no hit (primary ray)

@export_group("Refs")
@export var camera: Camera3D
@export var stats: PlayerStats # optional
@export var caster_root: Node # optional; used for exclusion. If null, will try group "player", else owner.

@export_group("Collision")
@export_flags_3d_physics var hit_mask := 0
@export var exclude_player := true

@export_group("Defaults")
@export var default_damage := 10.0
@export var default_range := 120.0
@export var default_spread_deg := 0.0

@export_group("Chain Lightning (gameplay)")
@export var chain_enabled := true
@export_range(0, 20, 1) var chain_count := 3                # extra jumps AFTER primary hit
@export var chain_range := 7.0                              # max distance per jump
@export_range(0.0, 1.0, 0.05) var chain_damage_mult := 0.65  # multiplier for chain hits
@export var chain_requires_los := false                     # optional LOS check per jump

@export_group("VFX")
@export var beam_scene: PackedScene                         # root should have LightningBeam.gd

@export_group("Debug")
@export var debug_hits := false

func _ready() -> void:
	_autowire()

func cast_default() -> void:
	cast(default_damage, default_range, default_spread_deg)

func cast(damage: float, spellrange: float, spread_deg: float, is_crit: bool = false) -> void:
	cast_started.emit()
	_autowire()

	if camera == null:
		push_warning("ChainLightning: camera not assigned/found.")
		cast_finished.emit({})
		return

	var shots := 1
	if stats != null:
		shots += stats.extra_projectiles
		if "damage_mult" in stats:
			damage *= stats.damage_mult
		if "range_mult" in stats:
			spellrange *= stats.range_mult
		if "spread_mult" in stats:
			spread_deg *= stats.spread_mult

	var world: World3D = camera.get_viewport().get_world_3d()
	if world == null:
		push_warning("ChainLightning: camera viewport has no World3D (wrong camera/viewport?).")
		cast_finished.emit({})
		return

	var space: PhysicsDirectSpaceState3D = world.direct_space_state

	for i in range(shots):
		var from := camera.global_position
		var dir := -camera.global_transform.basis.z
		dir = SpellUtil.apply_spread(dir, spread_deg)
		var to := from + dir * spellrange

		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = hit_mask
		q.collide_with_areas = true
		q.collide_with_bodies = true
		if exclude_player:
			q.exclude = _get_exclude_rids()

		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			if debug_hits:
				print("ChainLightning: miss")
			cast_finished.emit({})
			continue

		if debug_hits:
			print("ChainLightning: primary hit -> ", hit.get("collider", null))

		var hit_pos: Vector3 = hit.get("position", to)

		# Primary VFX + damage
		_spawn_beam(from, hit_pos)
		SpellUtil.apply_damage_from_hit(hit, damage, is_crit)
		cast_finished.emit(hit)

		# Chain VFX + damage
		if chain_enabled:
			var primary_enemy = hit.get("collider", null)
			if primary_enemy is Node3D:
				var start_pos: Vector3 = hit.get("position", (primary_enemy as Node3D).global_position)
				_apply_chain(primary_enemy as Node3D, start_pos, damage, is_crit, space)

func _apply_chain(start_enemy: Node3D, start_pos: Vector3, base_damage: float, is_crit: bool, space: PhysicsDirectSpaceState3D) -> void:
	if chain_count <= 0:
		return

	var visited := {}
	visited[start_enemy] = true

	var current_pos := start_pos

	for j in range(chain_count):
		var next_enemy := _find_next_enemy(current_pos, visited, space)
		if next_enemy == null:
			break

		visited[next_enemy] = true

		var next_pos := next_enemy.global_position
		_spawn_beam(current_pos, next_pos)

		var fake_hit := {
			"collider": next_enemy,
			"position": next_pos
		}

		var chain_damage := base_damage * chain_damage_mult
		if debug_hits:
			print("ChainLightning: jump ", j + 1, " -> ", next_enemy, " dmg=", chain_damage)

		SpellUtil.apply_damage_from_hit(fake_hit, chain_damage, is_crit)

		current_pos = next_pos

func _find_next_enemy(from_pos: Vector3, visited: Dictionary, space: PhysicsDirectSpaceState3D) -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best: Node3D = null
	var best_d2 := INF
	var max_d2 := chain_range * chain_range

	for e in enemies:
		if not (e is Node3D):
			continue
		var n := e as Node3D
		if not is_instance_valid(n):
			continue
		if visited.has(n):
			continue

		var d2 := n.global_position.distance_squared_to(from_pos)
		if d2 > max_d2:
			continue

		if chain_requires_los and not _has_los(from_pos, n.global_position, space):
			continue

		if d2 < best_d2:
			best_d2 = d2
			best = n

	return best

func _has_los(a: Vector3, b: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collision_mask = hit_mask
	q.collide_with_areas = true
	q.collide_with_bodies = true
	if exclude_player:
		q.exclude = _get_exclude_rids()

	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true

	var c = hit.get("collider", null)
	return c is Node3D and ((c as Node3D).global_position.distance_squared_to(b) < 0.05)

func _spawn_beam(from: Vector3, to: Vector3) -> void:
	if beam_scene == null:
		return

	var beam_node := beam_scene.instantiate()
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(beam_node)

	# LightningBeam now owns its own jitter/segments/colors/width/lifetime.
	# We only pass endpoints.
	if beam_node.has_method("draw_beam"):
		var pts := PackedVector3Array()
		pts.append(from)
		pts.append(to)
		beam_node.call("draw_beam", pts)

func _autowire() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()

	if caster_root == null:
		var ps := get_tree().get_nodes_in_group("player")
		if ps.size() > 0:
			caster_root = ps[0]
		elif get_owner() != null:
			caster_root = get_owner()

func _get_exclude_rids() -> Array[RID]:
	var rids: Array[RID] = []
	var ex := _get_exclude_node()
	if ex == null:
		return rids

	if ex is CollisionObject3D:
		rids.append((ex as CollisionObject3D).get_rid())
		return rids

	if ex.has_method("get_rid"):
		var rid = ex.call("get_rid")
		if rid is RID:
			rids.append(rid)

	return rids

func _get_exclude_node() -> Node:
	if caster_root != null:
		return caster_root
	return get_owner()
