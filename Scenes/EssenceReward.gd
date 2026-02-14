extends Node
class_name EssenceReward

@export var amount: int = 25

@export_group("Wiring")
@export var enemy_health_path: NodePath = NodePath("") # optional; leave empty to auto-find

var _connected := false

func _ready() -> void:
	var hp := _resolve_enemy_health()
	if hp == null:
		push_warning("EssenceReward: could not find EnemyHealth/EnemHealth node to connect.")
		return

	if hp.has_signal("died"):
		# Avoid double-connect if scene gets re-parented / duplicated
		if not hp.is_connected("died", Callable(self, "_on_enemy_died")):
			hp.connect("died", Callable(self, "_on_enemy_died"))
		_connected = true
	else:
		push_warning("EssenceReward: found health node but it has no 'died' signal: %s" % [hp.name])

func _on_enemy_died(_arg = null) -> void:
	# Kills
	var kc := get_node_or_null("/root/KillCounter")
	if kc != null:
		kc.add_kill(1)
	else:
		push_warning("EssenceReward: /root/KillCounter missing (autoload not set?).")

	# Essence
	if amount > 0:
		var wallet := get_node_or_null("/root/EssenceWallet")
		if wallet != null:
			wallet.add(amount)
		else:
			push_warning("EssenceReward: /root/EssenceWallet missing (autoload not set?).")

func _resolve_enemy_health() -> Node:
	# 1) Explicit path (if set)
	if enemy_health_path != NodePath(""):
		var n := get_node_or_null(enemy_health_path)
		if n != null:
			return n

	# 2) Common node names (your trace suggests EnemHealth.gd)
	var parent := get_parent()
	if parent != null:
		var by_name := parent.get_node_or_null("EnemyHealth")
		if by_name != null:
			return by_name
		by_name = parent.get_node_or_null("EnemHealth")
		if by_name != null:
			return by_name
		by_name = parent.get_node_or_null("Health")
		if by_name != null:
			return by_name

	# 3) First descendant that has a 'died' signal
	if parent != null:
		return _find_descendant_with_signal(parent, "died")

	return null

func _find_descendant_with_signal(root: Node, sig: StringName) -> Node:
	for c in root.get_children():
		if c != null and c.has_signal(sig):
			return c
		var deep := _find_descendant_with_signal(c, sig)
		if deep != null:
			return deep
	return null
