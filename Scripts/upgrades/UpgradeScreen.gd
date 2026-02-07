extends Control
class_name UpgradeScreen

signal upgrade_picked(upgrade: UpgradeData)

@export_group("UI Refs")
@export var choice1: Button
@export var choice2: Button
@export var choice3: Button

var _choices: Array[UpgradeData] = []
var _ready_ok := false

func _ready() -> void:
	visible = false
	_autowire()
	_ready_ok = _validate_ui()
	if not _ready_ok:
		set_process(false)
		return

	choice1.pressed.connect(func(): _pick(0))
	choice2.pressed.connect(func(): _pick(1))
	choice3.pressed.connect(func(): _pick(2))

func open(choices: Array[UpgradeData]) -> void:
	if not _ready_ok:
		return

	_choices = choices
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_set_button(choice1, 0)
	_set_button(choice2, 1)
	_set_button(choice3, 2)

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _set_button(btn: Button, idx: int) -> void:
	if btn == null:
		return

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

func _autowire() -> void:
	# Backwards-compatible fallback (keeps your current scene working even if you forget to assign exports)
	if choice1 == null:
		choice1 = get_node_or_null("PanelContainer/VBoxContainer/Choice1") as Button
	if choice2 == null:
		choice2 = get_node_or_null("PanelContainer/VBoxContainer/Choice2") as Button
	if choice3 == null:
		choice3 = get_node_or_null("PanelContainer/VBoxContainer/Choice3") as Button

func _validate_ui() -> bool:
	var ok := true
	if choice1 == null:
		push_error("UpgradeScreen: choice1 not assigned/found.")
		ok = false
	if choice2 == null:
		push_error("UpgradeScreen: choice2 not assigned/found.")
		ok = false
	if choice3 == null:
		push_error("UpgradeScreen: choice3 not assigned/found.")
		ok = false
	return ok
