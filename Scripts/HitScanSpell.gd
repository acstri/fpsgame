extends Node3D
class_name HitscanSpell

signal cast_started()
signal cast_finished(hit: Dictionary) # empty dict = no hit

@export_group("Refs")
@export var camera: Camera3D
@export var stats: PlayerStats # optional

@export_group("Collision")
@export_flags_3d_physics var hit_mask := 0
@export var exclude_player := true

@export_group("Defaults (use if you don't have SpellData yet)")
@export var default_damage := 10.0
@export var default_range := 120.0
@export var default_spread_deg := 0.0

@export_group("Debug")
@export var debug_hits := false


# Cast using current defaults (temporary, until you have SpellData)
func cast_default() -> void:
	cast(default_damage, default_range, default_spread_deg)


# Cast with explicit parameters (works now, no SpellData needed)
func cast(damage: float, spellrange: float, spread_deg: float) -> void:
	cast_started.emit()

	if camera == null:
		push_warning("HitscanSpell: camera not assigned.")
		cast_finished.emit({})
		return

	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	dir = _apply_spread(dir, spread_deg)
	var to := from + dir * spellrange

	var world: World3D = camera.get_viewport().get_world_3d()
	if world == null:
		push_warning("HitscanSpell: camera viewport has no World3D (wrong camera/viewport?).")
		cast_finished.emit({})
		return

	var space: PhysicsDirectSpaceState3D = world.direct_space_state

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = hit_mask
	q.collide_with_areas = true
	q.collide_with_bodies = true

	if exclude_player:
		var player := get_owner()
		if player != null:
			q.exclude = [player]

	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		if debug_hits:
			print("HitscanSpell: NO HIT")
		cast_finished.emit({})
		return

	if debug_hits:
		print("HitscanSpell: HIT ", hit.get("collider"), " at ", hit.get("position"))

	# Optional stat scaling (only if these fields exist on PlayerStats)
	if stats != null:
		if "damage_mult" in stats:
			damage *= stats.damage_mult
		if "range_mult" in stats:
			spellrange *= stats.range_mult
		if "spread_mult" in stats:
			spread_deg *= stats.spread_mult

	# Apply damage to collider or its parent
	_apply_damage_from_hit(hit, damage)

	cast_finished.emit(hit)


func _apply_damage_from_hit(hit: Dictionary, damage: float) -> void:
	var collider: Object = hit.get("collider")

	if collider != null and _has_apply_damage(collider):
		_call_apply_damage(collider, damage, hit)
		return

	if collider is Node:
		var p := (collider as Node).get_parent()
		if p != null and _has_apply_damage(p):
			_call_apply_damage(p, damage, hit)


func _has_apply_damage(obj: Object) -> bool:
	return obj != null and obj.has_method("apply_damage")


# Calls apply_damage with 2 args if supported, else 1 arg.
func _call_apply_damage(obj: Object, damage: float, hit: Dictionary) -> void:
	var arg_count := _apply_damage_arg_count(obj)
	if arg_count >= 2:
		obj.callv("apply_damage", [damage, hit])
	else:
		obj.callv("apply_damage", [damage])


func _apply_damage_arg_count(obj: Object) -> int:
	# Returns argument count for apply_damage if discoverable, else assume 1.
	for m in obj.get_method_list():
		if m.get("name") == "apply_damage":
			var args: Array = m.get("args", [])
			return args.size()
	return 1


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

	# Godot forward is -Z, so use -z for cone-forward local direction
	var b: Basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return (b * Vector3(x, y, -z)).normalized()
