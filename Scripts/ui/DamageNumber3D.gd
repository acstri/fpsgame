extends Node3D
class_name DamageNumber3D

@export var label: Label3D
@export var float_up := 1.2
@export var duration := 0.8
@export var crit_scale := 1.35
@export var normal_color := Color(1, 1, 1, 1)
@export var crit_color := Color(0.971, 0.971, 0.0, 1.0) # change to whatever you want

var _tween: Tween

func _ready() -> void:
	if label == null:
		label = get_node_or_null("Label3D") as Label3D

func setup(amount: float, is_crit: bool) -> void:
	if label == null:
		return
	
	var n := int(round(amount))
	label.text = ("%d!" % n) if is_crit else ("%d" % n)
	label.scale = Vector3.ONE * (1.0)
	if is_crit:
		label.scale *= 1.15

	# You can style crit by changing label.modulate or outline here if you want.
	_set_label_color(crit_color if is_crit else normal_color)

	# Animate up + fade
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()

	var start_pos := global_position
	var end_pos := start_pos + Vector3.UP * float_up

	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(self, "global_position", end_pos, duration)

	# Fade label alpha
	var c := label.modulate
	c.a = 1.0
	label.modulate = c

	_tween.parallel().tween_method(_set_alpha, 1.0, 0.0, duration)
	_tween.finished.connect(queue_free)

func _set_alpha(a: float) -> void:
	if label == null:
		return
	var c := label.modulate
	c.a = clampf(a, 0.0, 1.0)
	label.modulate = c

func _set_label_color(c: Color) -> void:
	# Label3D commonly supports modulate; if yours doesn't, use material_override.
	if "modulate" in label:
		label.modulate = c
		return

	var mat := label.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		label.material_override = mat

	mat.albedo_color = c
