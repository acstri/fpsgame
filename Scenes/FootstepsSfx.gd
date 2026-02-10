extends Node3D
class_name FootstepSfx

@export_group("Wiring")
@export var character: Node # CharacterBody3D recommended; if null uses parent.

@export_group("Surfaces")
# Surface sets used when ground collider has meta "footstep_surface" == surface_id.
@export var surface_sets: Array[FootstepSurfaceSet] = []
# Fallback if no surface match / no meta found.
@export var default_step_clips: Array[AudioStream] = []
@export var meta_key: StringName = &"footstep_surface"

@export_group("Ground Probe")
@export var ray_length := 1.6
@export var ray_start_height := 0.4
@export var ground_collision_mask := 1 # set to your ground/world mask
@export var probe_every_step := true   # if false, caches last surface until you stop moving

@export_group("When to step")
@export var min_move_speed := 0.6
@export var speed_for_fast_steps := 8.0
@export var require_on_floor := true

@export_group("Intervals (seconds)")
@export var step_interval_slow := 0.52
@export var step_interval_fast := 0.34

@export_group("Selection")
@export var avoid_repeating_last := true

@export_group("Volume")
@export_range(-60.0, 12.0, 0.1) var volume_db := -6.0
@export var audio_bus := "SFX"

@export_group("3D Settings")
@export var max_distance := 22.0
@export var unit_size := 1.0
@export var attenuation_model := AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

@export_group("Debug")
@export var enabled := true

var _t := 0.0
var _last_clip_idx := -1
var _cached_body: Node = null

var _last_surface_id: StringName = &"default"
var _surface_cache_valid := false

func _ready() -> void:
	if not enabled:
		set_process(false)
		return

	_cached_body = character if character != null else get_parent()
	if _cached_body == null:
		push_warning("FootstepSfx: No character (assign 'character' or parent it under the mover).")
		set_process(false)
		return

func _process(delta: float) -> void:
	if not enabled:
		return

	if require_on_floor and not _is_on_floor(_cached_body):
		_reset_stride_cache()
		return

	var speed := _horizontal_speed(_cached_body)
	if speed < min_move_speed:
		_reset_stride_cache()
		return

	var interval := _interval_for_speed(speed)
	_t += delta
	if _t >= interval:
		_t = fmod(_t, interval)
		_play_step()

func _reset_stride_cache() -> void:
	_t = 0.0
	_surface_cache_valid = false

func _horizontal_speed(n: Node) -> float:
	if "velocity" in n:
		var v: Vector3 = n.velocity
		return Vector2(v.x, v.z).length()
	if "linear_velocity" in n:
		var lv: Vector3 = n.linear_velocity
		return Vector2(lv.x, lv.z).length()
	return 0.0

func _is_on_floor(n: Node) -> bool:
	if n is CharacterBody3D:
		return (n as CharacterBody3D).is_on_floor()
	if n.has_method("is_on_floor"):
		return bool(n.call("is_on_floor"))
	return true

func _interval_for_speed(speed: float) -> float:
	var a := clampf(speed / maxf(0.001, speed_for_fast_steps), 0.0, 1.0)
	return lerpf(step_interval_slow, step_interval_fast, a)

func _play_step() -> void:
	var set = _get_surface_set()
	var clips = (set.clips if set != null and not set.clips.is_empty() else default_step_clips)
	if clips.is_empty():
		return

	var idx := _pick_clip_index(clips.size())
	var clip = clips[idx]
	if clip == null:
		return

	var p := AudioStreamPlayer3D.new()
	p.stream = clip
	p.bus = audio_bus

	var add_vol = set.volume_db_add if set != null else 0.0
	p.volume_db = volume_db + add_vol

	p.max_distance = max_distance
	p.unit_size = unit_size
	p.attenuation_model = attenuation_model

	var pmn = set.pitch_min if set != null else 0.95
	var pmx = set.pitch_max if set != null else 1.08
	p.pitch_scale = randf_range(minf(pmn, pmx), maxf(pmn, pmx))

	add_child(p)
	p.global_position = global_position
	p.play()

	p.finished.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)

func _pick_clip_index(count: int) -> int:
	if count <= 1:
		_last_clip_idx = 0
		return 0

	var idx := randi() % count
	if avoid_repeating_last and idx == _last_clip_idx:
		idx = (idx + 1 + (randi() % (count - 1))) % count
	_last_clip_idx = idx
	return idx

func _get_surface_set() -> FootstepSurfaceSet:
	if not probe_every_step and _surface_cache_valid:
		return _find_set(_last_surface_id)

	var id := _probe_surface_id()
	_last_surface_id = id
	_surface_cache_valid = true
	return _find_set(id)

func _find_set(id: StringName) -> FootstepSurfaceSet:
	for s in surface_sets:
		if s != null and s.surface_id == id:
			return s
	# If no match, allow default set by name
	for s in surface_sets:
		if s != null and s.surface_id == &"default":
			return s
	return null

func _probe_surface_id() -> StringName:
	var world := get_world_3d()
	if world == null:
		return &"default"

	var from := global_position + Vector3.UP * ray_start_height
	var to := from + Vector3.DOWN * ray_length

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = ground_collision_mask
	# DO NOT exclude self here – Node3D has no RID and it’s unnecessary

	var res := world.direct_space_state.intersect_ray(q)
	if res.is_empty():
		return &"default"

	var col = res.get("collider")
	if col is Object and (col as Object).has_meta(meta_key):
		var v = (col as Object).get_meta(meta_key)
		if v is StringName:
			return v
		if v is String:
			return StringName(v)

	# Also allow tagging the parent (common setup)
	if col is Node:
		var p = col.get_parent()
		if p != null and p.has_meta(meta_key):
			var v2 = p.get_meta(meta_key)
			if v2 is StringName:
				return v2
			if v2 is String:
				return StringName(v2)

	return &"default"
