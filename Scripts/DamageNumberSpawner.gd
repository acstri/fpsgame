extends Control
class_name DamageNumber

@export var base_lifetime := 0.55
@export var rise_px := 55.0
@export var drift_px := 28.0
@export var crit_scale := 1.25

@onready var label: Label = $Label

var world_pos: Vector3
var is_crit := false
var is_player_target := false

var _age := 0.0
var _life := 0.55
var _start_screen := Vector2.ZERO
var _drift_dir := Vector2.ZERO
var _cam: Camera3D

# stacking/merge support
var _accum_amount := 0.0
var _shown_amount := 0.0

func setup(camera: Camera3D, p_world_pos: Vector3, amount: float, p_is_crit: bool, p_is_player_target: bool) -> void:
	_cam = camera
	world_pos = p_world_pos
	is_crit = p_is_crit
	is_player_target = p_is_player_target

	_accum_amount = amount
	_shown_amount = amount

	_age = 0.0
	_life = base_lifetime * (1.15 if is_crit else 1.0)

	_drift_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-0.35, 0.35)).normalized()
	_refresh_text_style()

	_start_screen = _project(world_pos)
	position = _start_screen

	visible = true
	set_process(true)

func add_amount(amount: float, p_is_crit: bool) -> void:
	# Merge hits: accumulate and “bump” lifetime a bit
	_accum_amount += amount
	is_crit = is_crit or p_is_crit
	_life = min(_life + 0.10, base_lifetime * 1.6)
	_age = min(_age, _life * 0.35) # keep it from dying immediately
	_refresh_text_style()

func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / maxf(0.001, _life), 0.0, 1.0)

	# Smoothly animate displayed amount toward accumulated amount (prevents jitter on rapid merges)
	_shown_amount = lerpf(_shown_amount, _accum_amount, 1.0 - pow(0.001, delta * 12.0))
	_update_label_text()

	# Rise and drift in screen space (stable and readable)
	var rise := rise_px * _ease_out(t)
	var drift := drift_px * _ease_out(t)

	# Re-project each frame so numbers “belong” to the hit location in world
	var base := _project(world_pos)
	position = base + Vector2(_drift_dir.x * drift, -rise)

	# Fade out
	modulate.a = 1.0 - _ease_in(t)

	if t >= 1.0:
		queue_free()

func _refresh_text_style() -> void:
	# You can swap colors/fonts here if desired
	if label == null:
		return

	var s := crit_scale if is_crit else 1.0
	scale = Vector2.ONE * s

	_update_label_text()

func _update_label_text() -> void:
	if label == null:
		return
	var amt := int(round(_shown_amount))
	label.text = str(amt)

func _project(p: Vector3) -> Vector2:
	if _cam == null:
		return Vector2.ZERO
	return _cam.unproject_position(p)

func _ease_out(t: float) -> float:
	# cubic ease out
	var u := 1.0 - t
	return 1.0 - (u * u * u)

func _ease_in(t: float) -> float:
	# quadratic ease in
	return t * t
	
func apply_style(
	p_base_scale: float,
	p_crit_scale_mult: float,
	p_normal_color: Color,
	p_crit_color: Color
) -> void:
	if label == null:
		return

	var s := p_base_scale
	if is_crit:
		s *= p_crit_scale_mult

	scale = Vector2.ONE * s
	label.modulate = p_crit_color if is_crit else p_normal_color
