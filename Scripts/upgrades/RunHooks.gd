extends Node
class_name RunHooks

@export var player: Node3D # optional; if null, will find group "player"
@export var upgrade_screen: UpgradeScreen
@export var game_over_screen: GameOverScreen
@export var screen_fader: ScreenFader
@export var director: Node

# Optional overrides; if null, will be found under player
@export var level_system: LevelSystem
@export var stats: PlayerStats
@export var upgrades: UpgradeService
@export var health: PlayerHealth

@export var death_slowmo_scale := 0.2
@export var death_slowmo_duration := 1.2

var _ended := false

func _ready() -> void:
	_autowire()

	if not _validate_critical():
		set_process(false)
		set_physics_process(false)
		return

	_safe_connect(level_system.level_up, _on_level_up)
	_safe_connect(upgrade_screen.upgrade_picked, _on_upgrade_picked)
	_safe_connect(health.died, _on_player_died)
	_safe_connect(game_over_screen.restart_pressed, _on_restart)

	upgrades.reset_run()

func _exit_tree() -> void:
	# Ensure globals aren't left behind if scene changes unexpectedly
	Engine.time_scale = 1.0
	get_tree().paused = false

func _autowire() -> void:
	# Player
	if player == null:
		var ps := get_tree().get_nodes_in_group("player")
		if ps.size() > 0:
			player = ps[0] as Node3D

	if player == null:
		return

	# Find core nodes under player by type first, then by common name
	if level_system == null:
		level_system = _find_child_by_type(player, LevelSystem) as LevelSystem
		if level_system == null:
			level_system = player.get_node_or_null("LevelSystem") as LevelSystem

	if stats == null:
		stats = _find_child_by_type(player, PlayerStats) as PlayerStats
		if stats == null:
			stats = player.get_node_or_null("PlayerStats") as PlayerStats

	if health == null:
		health = _find_child_by_type(player, PlayerHealth) as PlayerHealth
		if health == null:
			health = player.get_node_or_null("Health") as PlayerHealth

	# Upgrades service: allow it to live anywhere in scene (commonly under a “Systems” node)
	if upgrades == null:
		upgrades = _find_any_by_type(UpgradeService) as UpgradeService

func _validate_critical() -> bool:
	var ok := true

	if player == null:
		push_error("RunHooks: player is null (assign export or put player in group 'player').")
		ok = false
	if upgrade_screen == null:
		push_error("RunHooks: upgrade_screen not assigned.")
		ok = false
	if game_over_screen == null:
		push_error("RunHooks: game_over_screen not assigned.")
		ok = false
	if upgrades == null:
		push_error("RunHooks: upgrades (UpgradeService) not found/assigned.")
		ok = false
	if level_system == null:
		push_error("RunHooks: level_system not found/assigned.")
		ok = false
	if stats == null:
		push_error("RunHooks: stats not found/assigned.")
		ok = false
	if health == null:
		push_error("RunHooks: health not found/assigned.")
		ok = false

	return ok

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func _on_level_up(_new_level: int) -> void:
	if _ended:
		return
	var choices: Array[UpgradeData] = upgrades.roll_choices()
	upgrade_screen.open(choices)
	print("all_upgrades=", upgrades.all_upgrades.size(), " rolled=", choices.size())

func _on_upgrade_picked(up: UpgradeData) -> void:
	if _ended:
		return
	upgrades.apply_upgrade(up, stats)

func _on_player_died() -> void:
	if _ended:
		return
	_ended = true

	if director != null:
		director.set_process(false)
		director.set_physics_process(false)

	if upgrade_screen != null and upgrade_screen.visible:
		upgrade_screen.close()

	Engine.time_scale = death_slowmo_scale
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if screen_fader != null:
		screen_fader.fade_to_black(death_slowmo_duration)

	await get_tree().create_timer(death_slowmo_duration, true, false, true).timeout

	Engine.time_scale = 1.0
	get_tree().paused = true
	if game_over_screen != null:
		game_over_screen.visible = true

func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

# --- helpers ---

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null

func _find_any_by_type(t: Variant) -> Node:
	var nodes := get_tree().get_nodes_in_group("__dummy__") # placeholder to avoid warnings
	# Instead of group scanning, walk scene tree from current scene
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_child_by_type(scene, t)
