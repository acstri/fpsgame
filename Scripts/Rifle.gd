extends HitscanWeapon
class_name wizardry

@export var automatic := true

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if Input.is_action_just_pressed("reload"):
		try_reload()

	if automatic:
		if Input.is_action_pressed("fire"):
			try_fire()
	else:
		if Input.is_action_just_pressed("fire"):
			try_fire()
