extends CanvasLayer
class_name DamageNumberLayer

@export_group("Refs")
@export var camera: Camera3D
@export var number_scene: PackedScene

@export_group("Placement")
@export var world_y_offset := 0.8
@export var spread_world := 0.35

@export_group("Clutter Control")
@export var merge_window_sec := 0.10
@export var merge_screen_radius_px := 32.0
@export var max_live_numbers := 40

@export_group("Style")
@export var base_scale := 1.0
@export var crit_scale_mult := 1.35
@export var normal_color := Color(1.0, 0.95, 0.85)
@export var crit_color := Color(1.0, 0.45, 0.25)

class MergeBucket:
	var num: DamageNumber
	var last_time: float
	var screen_pos: Vector2

var _buckets: Array[MergeBucket] = []
var _events: Node

func _ready() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()

	if number_scene == null:
		push_error("DamageNumberLayer: number_scene not assigned.")
		return

	_events = get_node_or_null("/root/Combat_Events")
	if _events == null or not _events.has_signal("damage_number"):
		push_error("DamageNumberLayer: Combat_Events missing or has no damage_number signal.")
		return

	_events.damage_number.connect(_on_damage_number)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_buckets.size() - 1, -1, -1):
		var b := _buckets[i]
		if b.num == null or not is_instance_valid(b.num) or (now - b.last_time) > (merge_window_sec * 2.0):
			_buckets.remove_at(i)

func _on_damage_number(world_pos: Vector3, amount: float, is_crit: bool, is_player_target: bool) -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return

	var now := Time.get_ticks_msec() / 1000.0

	var p := world_pos
	p.y += world_y_offset
	p += Vector3(
		randf_range(-spread_world, spread_world),
		randf_range(-spread_world * 0.15, spread_world * 0.15),
		randf_range(-spread_world, spread_world)
	)

	var sp := camera.unproject_position(p)

	# Try merging
	var best_idx := -1
	var best_d2 := INF

	for i in range(_buckets.size()):
		var b := _buckets[i]
		if b.num == null or not is_instance_valid(b.num):
			continue
		if (now - b.last_time) > merge_window_sec:
			continue

		var d2 := b.screen_pos.distance_squared_to(sp)
		if d2 < merge_screen_radius_px * merge_screen_radius_px and d2 < best_d2:
			best_d2 = d2
			best_idx = i

	if best_idx != -1:
		var bucket := _buckets[best_idx]
		bucket.num.add_amount(amount, is_crit)
		bucket.num.apply_style(
			base_scale,
			crit_scale_mult,
			normal_color,
			crit_color
		)
		bucket.last_time = now
		bucket.screen_pos = sp
		return

	# Hard cap fallback
	if get_child_count() >= max_live_numbers and _buckets.size() > 0:
		var closest := 0
		var cd2 := INF
		for i in range(_buckets.size()):
			var b := _buckets[i]
			if b.num == null or not is_instance_valid(b.num):
				continue
			var d2 := b.screen_pos.distance_squared_to(sp)
			if d2 < cd2:
				cd2 = d2
				closest = i
		var bucket2 := _buckets[closest]
		bucket2.num.add_amount(amount, is_crit)
		bucket2.num.apply_style(
			base_scale,
			crit_scale_mult,
			normal_color,
			crit_color
		)
		bucket2.last_time = now
		bucket2.screen_pos = sp
		return

	# Spawn new number
	var num := number_scene.instantiate() as DamageNumber
	add_child(num)

	num.setup(camera, p, amount, is_crit, is_player_target)
	num.apply_style(
		base_scale,
		crit_scale_mult,
		normal_color,
		crit_color
	)

	var nb := MergeBucket.new()
	nb.num = num
	nb.last_time = now
	nb.screen_pos = sp
	_buckets.append(nb)
