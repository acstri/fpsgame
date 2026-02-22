extends Control
class_name UpgradeScreen

signal upgrade_picked(upgrade: UpgradeData)

@export_group("UI Refs")
@export var choice1: Button
@export var choice2: Button
@export var choice3: Button

@export_group("Tooltip (optional refs)")
@export var tooltip_panel: PanelContainer
@export var tooltip_title: Label
@export var tooltip_desc: Label

@export_group("Layout / Autosize")
@export var button_padding := Vector2(28, 16) # x=left+right, y=top+bottom
@export var min_button_width := 180.0
@export var max_button_width := 520.0

@export_group("Hold To Accept")
@export_range(0.05, 2.0, 0.05) var hold_seconds := 0.45
@export var fill_color: Color = Color(1, 1, 1, 0.22)

@export_group("Audio")
@export var level_up_sounds: Array[AudioStream] = []
@export var randomize_pitch := false
@export var pitch_range := Vector2(0.98, 1.02)

var _choices: Array[UpgradeData] = []
var _buttons: Array[Button] = []
var _hold_fills: Array[ColorRect] = []

var _holding_idx := -1
var _hold_elapsed := 0.0

var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_autowire()
	_buttons = [choice1, choice2, choice3]

	_setup_tooltip_if_needed()
	_setup_hold_ui()
	_connect_buttons()

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_player)

func open(choices: Array[UpgradeData]) -> void:
	_choices = choices
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	play_level_up_sfx()

	_set_button(choice1, 0)
	_set_button(choice2, 1)
	_set_button(choice3, 2)

	_hide_tooltip()
	_cancel_hold()

func close() -> void:
	_cancel_hold()
	_hide_tooltip()
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	if not visible:
		return

	# Keep tooltip following mouse
	if tooltip_panel != null and tooltip_panel.visible:
		_position_tooltip()

	if _holding_idx == -1:
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_cancel_hold()
		return

	_hold_elapsed += delta
	var progress := clampf(_hold_elapsed / max(hold_seconds, 0.001), 0.0, 1.0)
	_set_fill_progress(_holding_idx, progress)

	if progress >= 1.0:
		var idx := _holding_idx
		_cancel_hold()
		_pick(idx)

func _connect_buttons() -> void:
	for i in _buttons.size():
		var btn := _buttons[i]
		if btn == null:
			continue

		btn.process_mode = Node.PROCESS_MODE_ALWAYS

		# hold input
		btn.button_down.connect(func(): _on_choice_down(i))
		btn.button_up.connect(func(): _on_choice_up(i))
		btn.mouse_exited.connect(func(): _on_choice_exit(i))

		# tooltip
		btn.mouse_entered.connect(func(): _on_choice_hover(i, true))
		btn.mouse_exited.connect(func(): _on_choice_hover(i, false))

func _on_choice_down(idx: int) -> void:
	if not visible:
		return
	if idx >= _choices.size():
		return
	if _choices[idx] == null:
		return
	var btn := _buttons[idx]
	if btn == null or not btn.visible or btn.disabled:
		return

	_holding_idx = idx
	_hold_elapsed = 0.0
	_set_fill_progress(idx, 0.0)

func _on_choice_up(idx: int) -> void:
	if _holding_idx == idx:
		_cancel_hold()

func _on_choice_exit(idx: int) -> void:
	# leaving while holding cancels
	if _holding_idx == idx:
		_cancel_hold()

func _on_choice_hover(idx: int, entering: bool) -> void:
	if not visible:
		return
	if idx < 0 or idx >= _choices.size():
		return
	var up := _choices[idx]
	if up == null:
		return

	if entering:
		_show_tooltip(up)
	else:
		_hide_tooltip()

func _cancel_hold() -> void:
	_holding_idx = -1
	_hold_elapsed = 0.0
	for i in _hold_fills.size():
		_set_fill_progress(i, 0.0)

func _pick(idx: int) -> void:
	if idx < 0 or idx >= _choices.size():
		return
	var up := _choices[idx]
	if up == null:
		return

	upgrade_picked.emit(up)
	close()

func _set_button(btn: Button, idx: int) -> void:
	if btn == null:
		return

	if idx >= _choices.size() or _choices[idx] == null:
		btn.visible = false
		btn.disabled = true
		return

	var up := _choices[idx]
	btn.visible = true
	btn.disabled = false

	# Only title on the card
	btn.text = up.title

	# Autosize width to title text
	_apply_autosize(btn, up.title)

func _apply_autosize(btn: Button, title: String) -> void:
	# Let the container size the height, but enforce minimums.
	# Width is computed from font measurement.
	var font := btn.get_theme_font("font")
	var font_size := btn.get_theme_font_size("font_size")

	var text_w := 0.0
	if font != null and font_size > 0:
		text_w = float(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)

	var w := clampf(text_w + button_padding.x, min_button_width, max_button_width)
	var h := maxf(btn.custom_minimum_size.y, button_padding.y)

	btn.custom_minimum_size = Vector2(w, h)

func _setup_hold_ui() -> void:
	_hold_fills.resize(3)

	for i in 3:
		var btn := _buttons[i]
		if btn == null:
			continue

		var fill := ColorRect.new()
		fill.color = fill_color
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.process_mode = Node.PROCESS_MODE_ALWAYS
		fill.size = Vector2.ZERO
		fill.visible = false
		fill.position = Vector2.ZERO
		fill.z_index = 100 # on top of button content

		btn.add_child(fill)
		_hold_fills[i] = fill

		# Keep fill sized if button resizes (autosize)
		btn.resized.connect(func(): _set_fill_progress(i, (_hold_elapsed / max(hold_seconds, 0.001)) if _holding_idx == i else 0.0))

func _set_fill_progress(idx: int, progress: float) -> void:
	if idx < 0 or idx >= _buttons.size():
		return

	var btn := _buttons[idx]
	var fill := _hold_fills[idx]
	if btn == null or fill == null:
		return

	progress = clampf(progress, 0.0, 1.0)

	fill.position = Vector2.ZERO
	fill.size = Vector2(btn.size.x * progress, btn.size.y)
	fill.visible = progress > 0.0

func _setup_tooltip_if_needed() -> void:
	# If you assigned nodes, keep them. Otherwise build a simple tooltip.
	if tooltip_panel != null and tooltip_title != null and tooltip_desc != null:
		tooltip_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		tooltip_panel.visible = false
		return

	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "UpgradeTooltip"
	tooltip_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.visible = false
	add_child(tooltip_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	tooltip_panel.add_child(vb)


	tooltip_desc = Label.new()
	tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_desc.custom_minimum_size = Vector2(320, 0)
	tooltip_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tooltip_desc)

func _show_tooltip(up: UpgradeData) -> void:
	if tooltip_panel == null:
		return
		
	tooltip_desc.text = up.description

	tooltip_panel.visible = true
	_position_tooltip()

func _hide_tooltip() -> void:
	if tooltip_panel != null:
		tooltip_panel.visible = false

func _position_tooltip() -> void:
	# Position tooltip near mouse, clamp to screen.
	if tooltip_panel == null:
		return

	var mouse := get_viewport().get_mouse_position()
	var offset := Vector2(18, 18)

	# Ensure tooltip has correct size before clamping
	tooltip_panel.reset_size()
	tooltip_panel.size = tooltip_panel.get_combined_minimum_size()

	var vp := get_viewport_rect().size
	var pos := mouse + offset

	if pos.x + tooltip_panel.size.x > vp.x:
		pos.x = mouse.x - tooltip_panel.size.x - offset.x
	if pos.y + tooltip_panel.size.y > vp.y:
		pos.y = mouse.y - tooltip_panel.size.y - offset.y

	tooltip_panel.position = pos

func play_level_up_sfx() -> void:
	if level_up_sounds.is_empty() or _sfx_player == null:
		return

	var stream := level_up_sounds[randi() % level_up_sounds.size()]
	if stream == null:
		return

	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.pitch_scale = randf_range(pitch_range.x, pitch_range.y) if randomize_pitch else 1.0
	_sfx_player.play()

func _autowire() -> void:
	# You can still assign via Inspector; this is just a fallback.
	if choice1 == null:
		choice1 = get_node_or_null("PanelContainer/VBoxContainer/Choice1") as Button
	if choice2 == null:
		choice2 = get_node_or_null("PanelContainer/VBoxContainer/Choice2") as Button
	if choice3 == null:
		choice3 = get_node_or_null("PanelContainer/VBoxContainer/Choice3") as Button
