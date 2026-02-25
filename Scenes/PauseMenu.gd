extends CanvasLayer
class_name PauseMenu

signal continue_pressed
signal quit_pressed

@export var title_label: Label
@export var time_label: Label
@export var continue_button: Button
@export var quit_button: Button

var _visible: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if continue_button != null:
		continue_button.pressed.connect(_on_continue)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit)

func set_survival_seconds(seconds: float) -> void:
	var total := int(maxf(0.0, seconds))
	var mins := total / 60
	var secs := total % 60
	if time_label != null:
		time_label.text = "Survived: %02d:%02d" % [mins, secs]

func open() -> void:
	_visible = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if continue_button != null:
		continue_button.grab_focus()

func close() -> void:
	_visible = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func is_open() -> bool:
	return _visible

func _on_continue() -> void:
	emit_signal("continue_pressed")

func _on_quit() -> void:
	emit_signal("quit_pressed")
