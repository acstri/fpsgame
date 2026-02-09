extends Node3D
class_name LightningBeam

@export var lifetime := 0.08
@export var base_width := 0.05
@export var color := Color(0.6, 0.85, 1.0, 1.0)

@export_range(2, 32, 1) var segments := 10
@export var jitter := 0.35

@export_group("Pulse/Flicker")
@export var pulse_width_mult := 1.4        # peak width multiplier
@export var flicker_redraws := 2           # redraw beam N times during its life
@export var jitter_per_redraw := 0.15      # extra jitter per redraw

@export_group("Glow (optional)")
@export var glow_boost := 1.5              # emission strength

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

var _a := Vector3.ZERO
var _b := Vector3.ZERO

func _ready() -> void:
	# If endpoints weren't set, just auto-delete after lifetime.
	if _a == Vector3.ZERO and _b == Vector3.ZERO:
		await get_tree().create_timer(lifetime).timeout
		queue_free()
		return

	_redraw(0)

	# Flicker redraws
	if flicker_redraws > 0:
		for i in range(flicker_redraws):
			await get_tree().create_timer(lifetime / float(flicker_redraws + 1)).timeout
			_redraw(i + 1)

	await get_tree().create_timer(lifetime).timeout
	queue_free()

func draw_beam(points: PackedVector3Array) -> void:
	if points.size() < 2:
		return
	_a = points[0]
	_b = points[points.size() - 1]
	_redraw(0)

func _redraw(step: int) -> void:
	var w := base_width
	if pulse_width_mult > 1.0:
		var t := float(step) / maxf(1.0, float(flicker_redraws))
		var pulse := lerpf(1.0, pulse_width_mult, 1.0 - absf(t * 2.0 - 1.0)) # triangle pulse
		w *= pulse

	var local_jitter := jitter + float(step) * jitter_per_redraw
	var pts := _make_jagged(_a, _b, local_jitter)
	_draw_ribbon(pts, w)

func _make_jagged(a: Vector3, b: Vector3, j: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var segs := maxi(2, segments)

	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var p := a.lerp(b, t)
		if i > 0 and i < segs:
			p += Vector3(
				randf_range(-j, j),
				randf_range(-j, j),
				randf_range(-j, j)
			)
		pts.append(p)

	return pts

func _draw_ribbon(points: PackedVector3Array, w: float) -> void:
	var mesh := ImmediateMesh.new()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * glow_boost
	mat.flags_unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)

	for i in range(points.size()):
		var dir := Vector3.FORWARD
		if i < points.size() - 1:
			dir = (points[i + 1] - points[i]).normalized()
		elif i > 0:
			dir = (points[i] - points[i - 1]).normalized()

		var up := Vector3.UP
		if absf(dir.dot(up)) > 0.95:
			up = Vector3.FORWARD

		var right := dir.cross(up).normalized() * w
		mesh.surface_add_vertex(points[i] - right)
		mesh.surface_add_vertex(points[i] + right)

	mesh.surface_end()
	_mesh_instance.mesh = mesh
