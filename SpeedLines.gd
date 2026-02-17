extends ColorRect
class_name SpeedLines

@export_group("References")
@export var player_path: NodePath

@export_group("Speed Mapping")
@export var start_speed := 10.0
@export var full_speed := 22.0
@export var smoothing := 10.0

@export_group("Shader Control")
@export var shader_strength_param := "strength"
@export var shader_speed_param := "speed"
@export var shader_speed_min := 2.5
@export var shader_speed_max := 6.0

var _player: Node
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_node_or_null(player_path)
	# If player_path not set, try a common fallback
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	var sm := material as ShaderMaterial
	if sm == null:
		return

	var speed := _get_player_horizontal_speed()
	var target_t := _inv_lerp_clamped(start_speed, full_speed, speed)

	_t = lerpf(_t, target_t, clampf(smoothing * delta, 0.0, 1.0))

	sm.set_shader_parameter(shader_strength_param, _t)

	# Optional: make animation faster at higher speed
	var anim_speed := lerpf(shader_speed_min, shader_speed_max, _t)
	sm.set_shader_parameter(shader_speed_param, anim_speed)

	# If you want it fully invisible when not active:
	visible = _t > 0.01

func _get_player_horizontal_speed() -> float:
	if _player == null:
		return 0.0

	# CharacterBody3D has "velocity"
	if _player is CharacterBody3D:
		var v: Vector3 = (_player as CharacterBody3D).velocity
		return Vector3(v.x, 0.0, v.z).length()

	# Fallback if you store velocity differently
	if _player.has_method("get_velocity"):
		var vv: Vector3 = _player.call("get_velocity")
		return Vector3(vv.x, 0.0, vv.z).length()

	return 0.0

func _inv_lerp_clamped(a: float, b: float, v: float) -> float:
	if is_equal_approx(a, b):
		return 0.0
	return clampf((v - a) / (b - a), 0.0, 1.0)
