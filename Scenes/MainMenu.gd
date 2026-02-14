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

# New: start spell selector
@export_group("Start Spell (optional)")
@export var start_spell_option: OptionButton

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"

# Values stored in config / ProjectSettings
const KEY_MASTER := "master_volume"
const KEY_MOUSE := "mouse_sensitivity"
const KEY_START_SPELL := "start_spell_kind"

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_autowire()

	if play_button: play_button.pressed.connect(_on_play)
	if options_button: options_button.pressed.connect(_on_options)
	if quit_button: quit_button.pressed.connect(_on_quit)
	if back_button: back_button.pressed.connect(_on_back)

	if master_slider:
		master_slider.value_changed.connect(_on_master_changed)
	if mouse_slider:
		mouse_slider.value_changed.connect(_on_mouse_changed)

	_setup_start_spell_option()

	_load_settings()
	_apply_settings()

	_show_main_buttons()

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

func _find(name: String) -> Node:
	return find_child(name, true, false)

func _setup_start_spell_option() -> void:
	if start_spell_option == null:
		return

	start_spell_option.clear()
	# id 0 -> fireball, id 1 -> magicmissile
	start_spell_option.add_item("Fireball", 0)
	start_spell_option.add_item("Magic Missile", 1)

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

func _on_play() -> void:
	_save_settings()

	# Reset run meta (if present)
	var kc := get_node_or_null("/root/KillCounter")
	if kc != null:
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
		_apply_start_spell_setting() # still set defaults into ProjectSettings
		return

	if master_slider:
		master_slider.value = float(cfg.get_value(SECTION, KEY_MASTER, master_slider.value))
	if mouse_slider:
		mouse_slider.value = float(cfg.get_value(SECTION, KEY_MOUSE, mouse_slider.value))

	if start_spell_option:
		var kind := String(cfg.get_value(SECTION, KEY_START_SPELL, "fireball"))
		start_spell_option.selected = 0 if kind == "fireball" else 1

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

func _get_start_spell_kind() -> String:
	if start_spell_option == null:
		return "fireball"
	return "fireball" if start_spell_option.selected == 0 else "magicmissile"

func _apply_start_spell_setting() -> void:
	# Gameplay reads this on SpellCaster _ready()
	ProjectSettings.set_setting("application/config/start_spell_kind", _get_start_spell_kind())
	ProjectSettings.save()

func _on_master_changed(_v: float) -> void:
	_apply_master_volume()

func _on_mouse_changed(_v: float) -> void:
	_apply_mouse_sensitivity()
