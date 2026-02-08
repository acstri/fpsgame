extends Node
class_name SmokeTest

@export var run_on_ready := true
@export var verbose := true

var _errors: Array[String] = []

func _ready() -> void:
	if run_on_ready:
		call_deferred("_run")

func _run() -> void:
	_errors.clear()

	_check_autoloads()
	_check_player_contract()
	_check_director()
	_check_upgrade_service()
	_check_hud()
	_check_xp_gem()
	_check_pause_state()

	_report()

# -------------------- checks --------------------

func _check_autoloads() -> void:
	var events := get_node_or_null("/root/Combat_Events")
	if events == null:
		_fail("Autoload Combat_Events missing")
		return
	if not events.has_signal("damage_number"):
		_fail("Combat_Events missing signal: damage_number")
	if not events.has_signal("hurt_flash"):
		_fail("Combat_Events missing signal: hurt_flash")

func _check_player_contract() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() != 1:
		_fail("Expected exactly 1 node in group 'player', found %d" % players.size())
		return

	var p := players[0] as Node
	if _find_child_by_type(p, PlayerHealth) == null:
		_fail("PlayerHealth not found under player")
	if _find_child_by_type(p, PlayerStats) == null:
		_fail("PlayerStats not found under player")
	if _find_child_by_type(p, LevelSystem) == null:
		_fail("LevelSystem not found under player")
	if _find_child_by_type(p, SpellCaster) == null:
		_fail("SpellCaster not found under player")

func _check_director() -> void:
	var director := _find_node_by_type(Director)
	if director == null:
		_fail("Director not found in scene")
		return

	if director.ground_body_path == NodePath(""):
		_fail("Director.ground_body_path is not assigned")
	else:
		var gb := director.get_node_or_null(director.ground_body_path)
		if gb == null:
			_fail("Director.ground_body_path points to missing node")

func _check_upgrade_service() -> void:
	var svc := _find_node_by_type(UpgradeService)
	if svc == null:
		_fail("UpgradeService not found")
		return

	if svc.all_upgrades.is_empty():
		_fail("UpgradeService.all_upgrades is empty")

	# Deterministic sanity roll
	if "deterministic_rolls" in svc:
		svc.deterministic_rolls = true

	var rolled = svc.roll_choices()
	if rolled.is_empty():
		_fail("UpgradeService.roll_choices() returned empty list")

func _check_hud() -> void:
	var hud := _find_node_by_type(HUD)
	if hud == null:
		_fail("HUD not found")
		return

	if "hp_label" in hud and hud.hp_label == null:
		_fail("HUD.hp_label not assigned")
	if "hurt_flash" in hud and hud.hurt_flash == null:
		_fail("HUD.hurt_flash not assigned")

func _check_xp_gem() -> void:
	# Instantiate one XP gem safely
	var gem_scene := _find_xp_gem_scene()
	if gem_scene == null:
		_fail("XPGem scene not found (could not locate PackedScene)")
		return

	var gem := gem_scene.instantiate()
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(gem)
	if not gem is XPGem:
		_fail("Instantiated XP gem is not XPGem")
	gem.queue_free()

func _check_pause_state() -> void:
	if get_tree().paused:
		_fail("Tree is paused at start")
	if Engine.time_scale != 1.0:
		_fail("Engine.time_scale != 1 at start")

# -------------------- helpers --------------------

func _find_node_by_type(t: Variant) -> Node:
	for n in get_tree().get_nodes_in_group(""):
		pass
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _find_child_by_type(root, t)

func _find_child_by_type(root: Node, t: Variant) -> Node:
	if is_instance_of(root, t):
		return root
	for c in root.get_children():
		var r := _find_child_by_type(c, t)
		if r != null:
			return r
	return null

func _find_xp_gem_scene() -> PackedScene:
	# Try common paths first (edit if yours differs)
	var paths := [
		"res://Scenes/XPGem.tscn",
		"res://Scenes/items/XPGem.tscn",
		"res://Scenes/pickups/XPGem.tscn"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _fail(msg: String) -> void:
	_errors.append(msg)
	if verbose:
		push_error("[SMOKE FAIL] " + msg)

func _report() -> void:
	if _errors.is_empty():
		print("[SMOKE TEST] PASS ✔")
	else:
		push_error("[SMOKE TEST] FAIL ✖ (%d issues)" % _errors.size())
		for e in _errors:
			push_error(" - " + e)
