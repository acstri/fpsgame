extends Control
class_name GameOverScreen

signal restart_pressed()

@export_group("UI Refs")
@export var restart_button: Button

var _ready_ok := false

func _ready() -> void:
	visible = false
	_autowire()
	_ready_ok = _validate_ui()
	if not _ready_ok:
		set_process(false)
		return

	restart_button.pressed.connect(func():
		restart_pressed.emit()
	)

func _autowire() -> void:
	# Backwards-compatible fallback
	if restart_button == null:
		restart_button = get_node_or_null("PanelContainer/VBoxContainer/RestartButton") as Button

func _validate_ui() -> bool:
	if restart_button == null:
		push_error("GameOverScreen: restart_button not assigned/found.")
		return false
	return true
