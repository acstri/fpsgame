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

	# Optional stat scaling (range/spread must be applied BEFORE raycast)
	if stats != null:
		if "damage_mult" in stats:
			damage *= stats.damage_mult
		if "range_mult" in stats:
			spellrange *= stats.range_mult
		if "spread_mult" in stats:
			spread_deg *= stats.spread_mult

	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	dir = SpellUtil.apply_spread(dir, spread_deg)
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
		cast_finished.emit({})
		return

	SpellUtil.apply_damage_from_hit(hit, damage)
	cast_finished.emit(hit)
