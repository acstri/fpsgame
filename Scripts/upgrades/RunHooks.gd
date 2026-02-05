extends Node
class_name RunHooks

@export var player: Node3D
@export var upgrade_screen: UpgradeScreen

@onready var level_system: LevelSystem = player.get_node("LevelSystem") as LevelSystem
@onready var stats: PlayerStats = player.get_node("Stats") as PlayerStats
@onready var upgrades: UpgradeService = get_node("/root/Upgrades") as UpgradeService

@export var director: Node
@export var game_over_screen: GameOverScreen

@onready var health: PlayerHealth = player.get_node("Health") as PlayerHealth

@export var death_slowmo_scale := 0.2
@export var death_slowmo_duration := 1.2
@export var screen_fader: ScreenFader

func _ready() -> void:
	level_system.level_up.connect(_on_level_up)
	upgrade_screen.upgrade_picked.connect(_on_upgrade_picked)
	

	upgrades.reset_run()
	
	health.died.connect(_on_player_died)
	game_over_screen.restart_pressed.connect(_on_restart)


func _on_level_up(_new_level: int) -> void:
	var choices: Array[UpgradeData] = upgrades.roll_choices()
	upgrade_screen.open(choices)

func _on_upgrade_picked(up: UpgradeData) -> void:
	upgrades.apply_upgrade(up, stats)

func _on_player_died() -> void:
	if director != null:
		director.set_physics_process(false)

	if upgrade_screen != null and upgrade_screen.visible:
		upgrade_screen.close()

	# slow motion
	Engine.time_scale = death_slowmo_scale
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# start fade immediately
	if screen_fader != null:
		screen_fader.fade_to_black(death_slowmo_duration)

	# wait for slow-mo to finish (ignores time scale)
	await get_tree().create_timer(
		death_slowmo_duration,
		true, false, true
	).timeout

	Engine.time_scale = 1.0
	get_tree().paused = true

	if game_over_screen != null:
		game_over_screen.visible = true

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
