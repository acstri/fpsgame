extends Control
class_name EnemyBehindIndicator

@export_group("Refs")
@export var player_path: NodePath
@export var camera_path: NodePath

@export_group("Enemy Detection")
@export var enemy_group: StringName = &"enemy"
@export var max_distance: float = 50.0
@export var max_arrows: int = 6

@export_group("Filter")
@export var show_only_if_behind: bool = true
@export var behind_deadzone_deg: float = 10.0
@export var behind_coverage_deg: float = 240.0 # NEW: 180=half circle, 240/300 wider, 360 full

@export_group("Visual: Radius by Distance")
@export var radius_close: float = 70.0
@export var radius_far: float = 120.0
@export var radius_curve_power: float = 1.0

@export_group("Visual: Arrow Shape")
@export var arrow_length: float = 18.0
@export var arrow_width: float = 12.0

@export_group("Visual: Color by Distance")
@export var color_far: Color = Color(1, 1, 1, 1)
@export var color_close: Color = Color(1, 0, 0, 1)
@export var color_curve_power: float = 1.5

@export_group("Transparency by Distance")
@export var alpha_near: float = 1.0
@export var alpha_far: float = 0.05
@export var alpha_curve_power: float = 1.5

var _player: Node3D
var _camera: Camera3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = get_node_or_null(player_path) as Node3D
	_camera = get_node_or_null(camera_path) as Camera3D

	if _player == null:
		push_error("EnemyBehindIndicator: player_path invalid.")
		set_process(false)
		return
	if _camera == null:
		push_error("EnemyBehindIndicator: camera_path invalid.")
		set_process(false)
		return

	queue_redraw()
	get_viewport().size_changed.connect(queue_redraw)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := get_viewport_rect().size * 0.5
	var enemies := get_tree().get_nodes_in_group(enemy_group)
	if enemies.is_empty():
		return

	var deadzone_rad := deg_to_rad(clampf(behind_deadzone_deg, 0.0, 89.0))
	var coverage_deg := clampf(behind_coverage_deg, 0.0, 360.0)
	var half_cov_rad := deg_to_rad(coverage_deg) * 0.5

	# If coverage <= 180, we can keep a deadzone near the left/right boundary.
	# If coverage > 180, deadzone would incorrectly remove large parts, so disable it.
	var use_deadzone := coverage_deg <= 180.0
	var half_cov_effective := half_cov_rad
	if use_deadzone:
		half_cov_effective = maxf(0.0, minf(half_cov_rad, PI * 0.5 - deadzone_rad))

	var candidates: Array = []
	for e in enemies:
		if not (e is Node3D):
			continue
		var n := e as Node3D
		if not is_instance_valid(n):
			continue

		var dist := _player.global_position.distance_to(n.global_position)
		if dist > max_distance:
			continue

		# Enemy in camera local space: x right, z behind(+)/in-front(-)
		var local: Vector3 = _camera.global_transform.affine_inverse() * n.global_transform.origin

		var is_behind := local.z > 0.0
		if show_only_if_behind and not is_behind:
			continue

		# angle around the "behind axis"
		# 0 = directly behind, + right, - left
		var ang := atan2(local.x, local.z)

		# Coverage filter:
		# - 180deg -> accepts [-90, +90]
		# - 240deg -> accepts [-120, +120]
		# - 360deg -> accepts [-180, +180] (full surround, while still requiring local.z>0 if show_only_if_behind)
		if show_only_if_behind:
			if abs(ang) > half_cov_effective:
				continue
		else:
			# If not behind-only, still use coverage as a general clamp around behind-axis.
			# This keeps behavior predictable and avoids "everything on screen" spam.
			if abs(ang) > half_cov_rad:
				continue

		candidates.append([dist, ang])

	candidates.sort_custom(func(a, b): return a[0] < b[0])

	var count = min(max_arrows, candidates.size())
	for i in range(count):
		var dist: float = candidates[i][0]
		var ang: float = candidates[i][1]

		var t_far := clampf(dist / max_distance, 0.0, 1.0)
		var t_close := 1.0 - t_far

		var tr := pow(t_far, radius_curve_power)
		var r := lerpf(radius_close, radius_far, tr)

		# Screen ring direction (behind at top)
		var dir := Vector2(sin(ang), cos(ang)).normalized()
		var pos := center + dir * r

		var ta := pow(t_far, alpha_curve_power)
		var alpha := lerpf(alpha_near, alpha_far, ta)

		var tc := pow(t_close, color_curve_power)
		var col := color_far.lerp(color_close, tc)
		col.a *= clampf(alpha, 0.0, 1.0)

		_draw_triangle_arrow(pos, dir, col)

func _draw_triangle_arrow(pos: Vector2, dir: Vector2, col: Color) -> void:
	var d := dir.normalized()
	var right := Vector2(-d.y, d.x)

	var tip := pos + d * (arrow_length * 0.5)
	var base := pos - d * (arrow_length * 0.5)

	var p1 := tip
	var p2 := base + right * (arrow_width * 0.5)
	var p3 := base - right * (arrow_width * 0.5)

	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), col)
