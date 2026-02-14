extends Control
class_name UpgradeScreen

signal upgrade_picked(upgrade: UpgradeData)

@export_group("UI Refs")
@export var choice1: Button
@export var choice2: Button
@export var choice3: Button

@export_group("Audio")
@export var level_up_sounds: Array[AudioStream] = []   # add multiple sounds in Inspector
@export var randomize_pitch := false
@export var pitch_range := Vector2(0.98, 1.02)

var _choices: Array[UpgradeData] = []
var _ready_ok := false
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	visible = false
	_autowire()

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

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

	play_level_up_sfx()

	_set_button(choice1, 0)
	_set_button(choice2, 1)
	_set_button(choice3, 2)

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func play_level_up_sfx() -> void:
	if level_up_sounds.is_empty() or _sfx_player == null:
		return

	var stream := level_up_sounds[randi() % level_up_sounds.size()]
	if stream == null:
		return

	_sfx_player.stop()
	_sfx_player.stream = stream

	if randomize_pitch:
		_sfx_player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	else:
		_sfx_player.pitch_scale = 1.0

	_sfx_player.play()

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
