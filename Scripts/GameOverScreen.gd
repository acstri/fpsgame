extends Control
class_name GameOverScreen

signal restart_pressed()

@export_group("UI Refs")
@export var restart_button: Button
@export var kills_label: Label # e.g. "Kills: 0"

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

	# Optional live updates while visible
	var kc := get_node_or_null("/root/KillCounter")
	if kc != null and kc.has_signal("changed"):
		kc.changed.connect(_on_kills_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_kills()

func show_game_over() -> void:
	_refresh_kills()
	visible = true

func hide_game_over() -> void:
	visible = false

func _refresh_kills() -> void:
	if kills_label == null:
		return

	var kc := get_node_or_null("/root/KillCounter")
	var k := 0
	if kc != null and kc.has_method("get_kills"):
		k = int(kc.get_kills())

	kills_label.text = "Kills: %d" % k

func _on_kills_changed(_k: int) -> void:
	if visible:
		_refresh_kills()

func _autowire() -> void:
	# Backwards-compatible fallback
	if restart_button == null:
		restart_button = get_node_or_null("PanelContainer/VBoxContainer/RestartButton") as Button
	if kills_label == null:
		# Make sure your Label node is actually named "KillsLabel"
		kills_label = get_node_or_null("PanelContainer/VBoxContainer/KillsLabel") as Label

func _validate_ui() -> bool:
	if restart_button == null:
		push_error("GameOverScreen: restart_button not assigned/found.")
		return false
	if kills_label == null:
		push_warning("GameOverScreen: kills_label not assigned/found (Kills will not display).")
	return true
