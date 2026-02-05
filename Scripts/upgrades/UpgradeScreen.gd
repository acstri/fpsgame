extends Control
class_name UpgradeScreen

signal upgrade_picked(upgrade: UpgradeData)

@onready var b1: Button = $PanelContainer/VBoxContainer/Choice1
@onready var b2: Button = $PanelContainer/VBoxContainer/Choice2
@onready var b3: Button = $PanelContainer/VBoxContainer/Choice3

var _choices: Array[UpgradeData] = []

func _ready() -> void:
	visible = false
	b1.pressed.connect(func(): _pick(0))
	b2.pressed.connect(func(): _pick(1))
	b3.pressed.connect(func(): _pick(2))

func open(choices: Array[UpgradeData]) -> void:
	_choices = choices
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_set_button(b1, 0)
	_set_button(b2, 1)
	_set_button(b3, 2)


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _set_button(btn: Button, idx: int) -> void:
	if idx >= _choices.size() or _choices[idx] == null:
		btn.visible = false
		return

	var up := _choices[idx]
	btn.visible = true
	btn.text = "%s\n%s" % [up.title, up.description]

func _pick(idx: int) -> void:
	if idx < 0 or idx >= _choices.size():
		return
	var up := _choices[idx]
	if up == null:
		return
	upgrade_picked.emit(up)
	close()
