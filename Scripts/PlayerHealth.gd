extends Node
class_name PlayerHealth

signal hp_changed(current: float, max_hp: float)
signal died()
signal evaded()

@export var base_max_hp := 100.0
@export var invuln_time := 0.35

@export_group("Optional refs")
@export var stats: PlayerStats # if null, auto-found

var hp: float
var _invuln := 0.0
var _dead := false
var _max_hp_cached: float = 0.0

func _ready() -> void:
	_autowire()

	_max_hp_cached = get_max_hp()
	hp = _max_hp_cached

	if stats != null:
		var cb := Callable(self, "_on_stats_changed")
		if not stats.stats_changed.is_connected(cb):
			stats.stats_changed.connect(cb)

	hp_changed.emit(hp, _max_hp_cached)

func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)

	if _dead:
		return

	# regen
	var regen := 0.0
	if stats != null:
		regen = stats.hp_regen_per_sec
	if regen > 0.0 and hp > 0.0:
		var mx := get_max_hp()
		var new_hp := minf(mx, hp + regen * delta)
		if new_hp != hp:
			hp = new_hp
			hp_changed.emit(hp, mx)

func apply_damage(amount: float) -> void:
	if _dead:
		return
	if amount <= 0.0:
		return
	if _invuln > 0.0:
		return

	_autowire()

	# Evasion
	if stats != null and stats.evasion > 0.0:
		if randf() < stats.evasion:
			evaded.emit()
			return

	hp = maxf(0.0, hp - amount)
	_invuln = invuln_time
	
	var events := get_node_or_null("/root/Combat_Events")
	if events != null and events.has_signal("hurt_flash"):
		events.emit_signal("hurt_flash", true)


	var mx := get_max_hp()
	hp_changed.emit(hp, mx)

	if hp <= 0.0:
		_dead = true
		died.emit()

func heal(amount: float) -> void:
	if _dead:
		return
	if amount <= 0.0:
		return
	var mx := get_max_hp()
	var new_hp := minf(mx, hp + amount)
	if new_hp != hp:
		hp = new_hp
		hp_changed.emit(hp, mx)

func get_max_hp() -> float:
	# base_max_hp scaled by stats
	var mult := stats.max_hp_mult if stats != null else 1.0
	return maxf(1.0, base_max_hp * mult)

func _on_stats_changed() -> void:
	# When max HP changes, clamp current HP and update HUD
	var mx := get_max_hp()
	if mx != _max_hp_cached:
		_max_hp_cached = mx
		hp = clampf(hp, 0.0, mx)
		hp_changed.emit(hp, mx)

func _autowire() -> void:
	if stats != null:
		return

	var owner_node := get_owner()
	if owner_node == null:
		return

	stats = _find_child_by_type(owner_node, PlayerStats) as PlayerStats
	if stats == null:
		stats = owner_node.get_node_or_null("PlayerStats") as PlayerStats

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
