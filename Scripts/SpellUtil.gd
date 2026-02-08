extends Object
class_name SpellUtil

static func apply_spread(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction.normalized()

	var rad := deg_to_rad(degrees)
	var u := randf()
	var v := randf()

	var theta := TAU * u
	var phi := acos(1.0 - v * (1.0 - cos(rad)))

	var x := sin(phi) * cos(theta)
	var y := sin(phi) * sin(theta)
	var z := cos(phi)

	# Godot forward is -Z, so use -z for cone-forward local direction
	var b: Basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return (b * Vector3(x, y, -z)).normalized()


static func apply_damage_from_hit(hit: Dictionary, amount: float, is_crit: bool = false, is_player_target: bool = false) -> bool:
	var collider: Object = hit.get("collider")
	if collider == null:
		return false


	# Preferred: Enemy has child node "Health" with apply_damage(amount, hit)
	if collider is Node:
		var n := collider as Node

		var h := n.get_node_or_null("Health")
		if h != null and h.has_method("apply_damage"):
			_call_apply_damage(h, amount, hit)
			_emit_damage_number(hit, amount, is_crit, is_player_target)
			return true

		var p := n.get_parent()
		if p != null:
			var hp := p.get_node_or_null("Health")
			if hp != null and hp.has_method("apply_damage"):
				_call_apply_damage(hp, amount, hit)
				_emit_damage_number(hit, amount, is_crit, is_player_target)
				return true

	# Fallback: direct apply_damage on collider/parent if present
	if collider.has_method("apply_damage"):
		_call_apply_damage(collider, amount, hit)
		_emit_damage_number(hit, amount, is_crit, is_player_target)
		return true

	if collider is Node:
		var parent := (collider as Node).get_parent()
		if parent != null and parent.has_method("apply_damage"):
			_call_apply_damage(parent, amount, hit)
			_emit_damage_number(hit, amount, is_crit, is_player_target)
			return true

	return false


static func _call_apply_damage(obj: Object, amount: float, hit: Dictionary) -> void:
	var arg_count := _apply_damage_arg_count(obj)
	if arg_count >= 2:
		obj.callv("apply_damage", [amount, hit])
	else:
		obj.callv("apply_damage", [amount])


static func _apply_damage_arg_count(obj: Object) -> int:
	for m in obj.get_method_list():
		if m.get("name") == "apply_damage":
			var args: Array = m.get("args", [])
			return args.size()
	return 1

static func _emit_damage_number(hit: Dictionary, amount: float, is_crit: bool, is_player_target: bool) -> void:
	# Safe lookup: does not require CombatEvents to exist at compile time.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var events := tree.root.get_node_or_null("Combat_Events")
	if events == null:
		return

	if not events.has_signal("damage_number"):
		return

	var pos: Vector3 = hit.get("position", Vector3.ZERO)
	events.emit_signal("damage_number", pos, amount, is_crit, is_player_target)
