extends Control
class_name MainMenu

@export_group("Scenes")
@export_file("*.tscn") var game_scene_path: String = "res://Scenes/World.tscn"

@export_group("UI")
@export var play_button: Button
@export var options_button: Button
@export var quit_button: Button
@export var options_panel: Control
@export var back_button: Button
@export var master_slider: HSlider
@export var mouse_slider: HSlider

@export_group("Player Name Gate")
@export var name_input: LineEdit
@export var name_warning_label: Label # optional: "Enter a name to start"

@export_group("Start Spell")
@export var start_spell_option: OptionButton

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"

const KEY_MASTER := "master_volume"
const KEY_MOUSE := "mouse_sensitivity"
const KEY_START_SPELL := "start_spell_kind"

const START_FIREBALL := "fireball"
const START_MAGICMISSILE := "magicmissile"
const START_ARCGUN := "arcgun"

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_autowire()

	if play_button:
		play_button.pressed.connect(_on_play)
	if options_button:
		options_button.pressed.connect(_on_options)
	if quit_button:
		quit_button.pressed.connect(_on_quit)
	if back_button:
		back_button.pressed.connect(_on_back)

	if master_slider:
		master_slider.value_changed.connect(_on_master_changed)
	if mouse_slider:
		mouse_slider.value_changed.connect(_on_mouse_changed)

	if name_input:
		name_input.text_changed.connect(func(_t: String) -> void: _refresh_play_gate())
		name_input.text_submitted.connect(func(_t: String) -> void: _on_play())

		var profile := get_node_or_null("/root/Player_Profile")
		if profile != null and "player_name" in profile:
			name_input.text = str(profile.player_name)

		name_input.grab_focus()

	_setup_start_spell_option()

	_load_settings()
	_apply_settings()

	_show_main_buttons()
	_refresh_play_gate()

func _autowire() -> void:
	if play_button == null:
		play_button = _find("PlayButton") as Button
	if options_button == null:
		options_button = _find("OptionsButton") as Button
	if quit_button == null:
		quit_button = _find("QuitButton") as Button
	if options_panel == null:
		options_panel = _find("OptionsPanel") as Control
	if back_button == null:
		back_button = _find("BackButton") as Button
	if master_slider == null:
		master_slider = _find("MasterSlider") as HSlider
	if mouse_slider == null:
		mouse_slider = _find("MouseSlider") as HSlider
	if start_spell_option == null:
		start_spell_option = _find("StartSpellOption") as OptionButton

	if name_input == null:
		name_input = _find("NameInput") as LineEdit
	if name_warning_label == null:
		name_warning_label = _find("NameWarningLabel") as Label

func _find(name: String) -> Node:
	return find_child(name, true, false)

func _setup_start_spell_option() -> void:
	if start_spell_option == null:
		return

	start_spell_option.clear()
	start_spell_option.add_item("Fireball", 0)
	start_spell_option.add_item("Magic Missile", 1)
	start_spell_option.add_item("ArcGun", 2)

	start_spell_option.item_selected.connect(func(_idx: int) -> void:
		_apply_start_spell_setting()
	)

func _show_main_buttons() -> void:
	if play_button: play_button.visible = true
	if options_button: options_button.visible = true
	if quit_button: quit_button.visible = true
	if options_panel: options_panel.visible = false

func _show_options() -> void:
	if play_button: play_button.visible = false
	if options_button: options_button.visible = false
	if quit_button: quit_button.visible = false
	if options_panel: options_panel.visible = true

func _refresh_play_gate() -> void:
	var ok := _is_name_valid(_get_name_text())
	if play_button:
		play_button.disabled = not ok
	if name_warning_label:
		name_warning_label.visible = not ok
		if not ok:
			name_warning_label.text = "Enter a name to start"

func _is_name_valid(raw: String) -> bool:
	return raw.strip_edges().length() > 0

func _get_name_text() -> String:
	if name_input == null:
		return ""
	return name_input.text

func _commit_name() -> void:
	if name_input == null:
		return

	var profile := get_node_or_null("/root/Player_Profile")
	if profile != null and profile.has_method("set_player_name"):
		profile.set_player_name(name_input.text)

	if profile != null and "player_name" in profile:
		name_input.text = str(profile.player_name)

func _on_play() -> void:
	_refresh_play_gate()
	if play_button != null and play_button.disabled:
		if name_input != null:
			name_input.grab_focus()
		return

	_commit_name()
	_save_settings()

	var kc := get_node_or_null("/root/KillCounter")
	if kc != null and kc.has_method("reset"):
		kc.reset()

	get_tree().change_scene_to_file(game_scene_path)

func _on_options() -> void:
	_show_options()

func _on_back() -> void:
	_save_settings()
	_show_main_buttons()

func _on_quit() -> void:
	_save_settings()
	get_tree().quit()

# -----------------------
# Settings
# -----------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		_apply_start_spell_setting()
		return

	if master_slider:
		master_slider.value = float(cfg.get_value(SECTION, KEY_MASTER, master_slider.value))
	if mouse_slider:
		mouse_slider.value = float(cfg.get_value(SECTION, KEY_MOUSE, mouse_slider.value))

	if start_spell_option:
		var kind := String(cfg.get_value(SECTION, KEY_START_SPELL, START_FIREBALL))
		start_spell_option.selected = _kind_to_option_index(kind)

	_apply_start_spell_setting()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	if master_slider:
		cfg.set_value(SECTION, KEY_MASTER, master_slider.value)
	if mouse_slider:
		cfg.set_value(SECTION, KEY_MOUSE, mouse_slider.value)

	if start_spell_option:
		cfg.set_value(SECTION, KEY_START_SPELL, _get_start_spell_kind())

	cfg.save(SETTINGS_PATH)

func _apply_settings() -> void:
	_apply_master_volume()
	_apply_mouse_sensitivity()
	_apply_start_spell_setting()

func _apply_master_volume() -> void:
	if master_slider == null:
		return
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		bus = 0
	var linear := clampf(float(master_slider.value), 0.0, 1.0)
	var db := linear_to_db(maxf(0.0001, linear))
	AudioServer.set_bus_volume_db(bus, db)

func _apply_mouse_sensitivity() -> void:
	if mouse_slider == null:
		return
	ProjectSettings.set_setting("application/config/mouse_sensitivity", float(mouse_slider.value))
	ProjectSettings.save()

func _kind_to_option_index(kind: String) -> int:
	match kind:
		START_FIREBALL:
			return 0
		START_MAGICMISSILE:
			return 1
		START_ARCGUN:
			return 2
		_:
			return 0

func _get_start_spell_kind() -> String:
	if start_spell_option == null:
		return START_FIREBALL
	match start_spell_option.selected:
		0:
			return START_FIREBALL
		1:
			return START_MAGICMISSILE
		2:
			return START_ARCGUN
		_:
			return START_FIREBALL

func _apply_start_spell_setting() -> void:
	ProjectSettings.set_setting("application/config/start_spell_kind", _get_start_spell_kind())
	ProjectSettings.save()

func _on_master_changed(_v: float) -> void:
	_apply_master_volume()

func _on_mouse_changed(_v: float) -> void:
	_apply_mouse_sensitivity()
