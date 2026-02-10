extends Node3D
class_name BloodPool

# Optional helper for your blood pool scene.
# Default: persists forever. Set lifetime > 0 to auto-clean.

@export_group("Lifetime")
@export var lifetime := 0.0

@export_group("Variation")
@export var random_yaw := true
@export var random_uniform_scale := Vector2(0.9, 1.25)

var _t := 0.0

func _ready() -> void:
	if random_yaw:
		rotation.y = randf_range(-PI, PI)
	if random_uniform_scale.x > 0.0 and random_uniform_scale.y > 0.0:
		var s := randf_range(random_uniform_scale.x, random_uniform_scale.y)
		scale *= Vector3.ONE * s

func _process(delta: float) -> void:
	if lifetime <= 0.0:
		return
	_t += delta
	if _t >= lifetime:
		queue_free()
