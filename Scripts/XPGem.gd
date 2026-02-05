extends Area3D
class_name XPGem

@export var value := 1
@export var attract_speed := 14.0
@export var attract_distance := 6.0

var _target: Node3D = null

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	if dist <= 0.05:
		_collect()
		return

	global_position += to_target.normalized() * attract_speed * delta

func _on_body_entered(body: Node) -> void:
	# simplest: player in group
	if body is Node3D and body.is_in_group("player"):
		_target = body as Node3D

func _collect() -> void:
	# call LevelSystem on player if present
	if _target != null and _target.has_method("add_xp"):
		_target.add_xp(value)

	queue_free()
