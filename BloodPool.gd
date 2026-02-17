extends Node3D
class_name BloodPool

@export_group("Lifetime")
@export var lifetime := 10.0            # seconds (0 = infinite)
@export var fade_time := 1.0            # seconds before deletion (0 = instant delete)

@export_group("Variation")
@export var random_yaw := true
@export var random_uniform_scale := Vector2(0.9, 1.25)

var _timer: Timer
var _fading := false

func _ready() -> void:
	if random_yaw:
		rotation.y = randf_range(-PI, PI)

	if random_uniform_scale.x > 0.0 and random_uniform_scale.y > 0.0:
		var s := randf_range(random_uniform_scale.x, random_uniform_scale.y)
		scale *= Vector3.ONE * s

	if lifetime > 0.0:
		_timer = Timer.new()
		_timer.wait_time = lifetime
		_timer.one_shot = true
		_timer.timeout.connect(_on_lifetime_timeout)
		add_child(_timer)
		_timer.start()

func _on_lifetime_timeout() -> void:
	if fade_time <= 0.0:
		queue_free()
		return

	_fading = true

	var tween := create_tween()
	tween.tween_method(_fade_step, 1.0, 0.0, fade_time)
	tween.tween_callback(queue_free)

func _fade_step(value: float) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mat = child.get_active_material(0)
			if mat and mat is StandardMaterial3D:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				var c = mat.albedo_color
				c.a = value
				mat.albedo_color = c
