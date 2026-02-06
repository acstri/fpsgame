extends Area3D
class_name XPGem

@export var value := 1
@export var attract_speed := 14.0
@export var attract_distance := 6.0
@export var collect_distance := 0.35

var _player: Node3D

func _ready() -> void:
	monitoring = true
	_player = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return

	var to_player := _player.global_position - global_position
	var dist := to_player.length()

	if dist <= collect_distance:
		_collect()
		return

	if dist <= attract_distance:
		global_position += to_player.normalized() * attract_speed * delta

func _collect() -> void:
	if _player != null and _player.has_method("add_xp"):
		_player.add_xp(value)
	queue_free()

func set_value(v: int) -> void:
	value = v
