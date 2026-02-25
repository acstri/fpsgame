extends RefCounted
class_name PlayerStateMachine

var _states: Dictionary = {}
var _current_name: StringName = &""
var _current: PlayerState = null

func add_state(name: StringName, state: PlayerState) -> void:
	_states[name] = state

func current_name() -> StringName:
	return _current_name

func set_state(pc: PlayerController, name: StringName) -> void:
	if _current_name == name:
		return

	var next: PlayerState = _states.get(name, null) as PlayerState
	if next == null:
		push_error("PlayerStateMachine: missing state '%s'" % String(name))
		return

	if _current != null:
		_current.exit(pc)

	_current = next
	_current_name = name
	_current.enter(pc)

func physics_update(pc: PlayerController, delta: float) -> void:
	if _current != null:
		_current.physics_update(pc, delta)
