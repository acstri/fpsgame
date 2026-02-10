extends RigidBody3D
class_name GoreChunk

@export_group("Lifetime")
@export var lifetime := 6.0
@export var fade_after := 4.5 # seconds; 0 disables fade

@export_group("Optional Visual")
@export var fade_mesh_path: NodePath

var _t := 0.0
var _mesh: GeometryInstance3D

func _ready() -> void:
	if fade_mesh_path != NodePath(""):
		_mesh = get_node_or_null(fade_mesh_path) as GeometryInstance3D

func _physics_process(delta: float) -> void:
	_t += delta
	if lifetime > 0.0 and _t >= lifetime:
		queue_free()
		return

	if _mesh != null and fade_after > 0.0 and lifetime > fade_after and _t >= fade_after:
		var a := 1.0 - clampf((_t - fade_after) / maxf(0.001, (lifetime - fade_after)), 0.0, 1.0)
		# Requires StandardMaterial3D with transparency enabled.
		var mat = _mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color.a = a
