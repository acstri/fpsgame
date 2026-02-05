extends Control
class_name GameOverScreen

signal restart_pressed()

@onready var restart_btn: Button = $PanelContainer/VBoxContainer/RestartButton

func _ready() -> void:
	visible = false
	restart_btn.pressed.connect(func():
		restart_pressed.emit()
	)
