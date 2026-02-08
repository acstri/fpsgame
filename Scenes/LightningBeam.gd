extends Node3D
class_name LightningBeam

@export var lifetime := 0.06
@export var width := 0.05
@export var color := Color(0.6, 0.85, 1.0, 1.0)

@export_range(2, 24, 1) var segments := 8
@export var jitter := 0.3

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()

# Accepts either:
# - 2 points (from/to) and generates a jagged lightning path internally
# - N points (already jagged) and draws them as-is
func draw_beam(points: PackedVector3Array) -> void:
	if points.size() < 2:
		return

	var final_pts := points
	if points.size() == 2:
		final_pts = _make_jagged(points[0], points[1])

	_draw_ribbon(final_pts)

func _make_jagged(a: Vector3, b: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var segs := maxi(2, segments)

	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var p := a.lerp(b, t)

		if i > 0 and i < segs:
			p += Vector3(
				randf_range(-jitter, jitter),
				randf_range(-jitter, jitter),
				randf_range(-jitter, jitter)
			)

		pts.append(p)

	return pts

func _draw_ribbon(points: PackedVector3Array) -> void:
	var mesh := ImmediateMesh.new()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.flags_unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

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

		var right := dir.cross(up).normalized() * width
		mesh.surface_add_vertex(points[i] - right)
		mesh.surface_add_vertex(points[i] + right)

	mesh.surface_end()
	_mesh_instance.mesh = mesh
