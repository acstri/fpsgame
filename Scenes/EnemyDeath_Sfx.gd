extends Node3D
class_name EnemyDeathSfx

@export_group("Wiring")
@export var health: EnemyHealth

@export_group("Clips")
@export var death_clips: Array[AudioStream] = []
@export var avoid_repeating_last := true

@export_group("Pitch Variation")
@export_range(0.1, 3.0, 0.01) var pitch_min := 0.9
@export_range(0.1, 3.0, 0.01) var pitch_max := 1.15
@export var randomize_pitch := true

@export_group("Volume")
@export_range(-60.0, 12.0, 0.1) var volume_db := -6.0
@export var audio_bus := "SFX"

@export_group("3D Settings")
@export var max_distance := 28.0
@export var unit_size := 1.0
@export var attenuation_model := AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

@export_group("Cleanup")
@export var auto_free_after := 3.0 # seconds; should exceed your longest clip

@export_group("Debug")
@export var enabled := true

var _wired := false
var _last_clip_idx := -1

func _ready() -> void:
	if not enabled:
		return

	_autowire()
	if health == null:
		push_warning("EnemyDeathSfx: EnemyHealth not found. Assign 'health' or add a child named 'Health' with EnemyHealth.")
		return

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)
	_wired = true

func _exit_tree() -> void:
	if _wired and health != null and is_instance_valid(health) and health.died.is_connected(_on_died):
		health.died.disconnect(_on_died)

func _autowire() -> void:
	if health != null:
		return

	var owner_node := get_owner()
	if owner_node != null:
		var h := owner_node.get_node_or_null("Health")
		if h is EnemyHealth:
			health = h

	if health == null:
		var h2 := get_node_or_null("../Health")
		if h2 is EnemyHealth:
			health = h2

func _on_died(hit: Dictionary) -> void:
	if not enabled or death_clips.is_empty():
		return

	var pos := _get_death_position(hit)
	_play_at(pos)

func _get_death_position(hit: Dictionary) -> Vector3:
	if hit.has("position"):
		return hit.get("position")
	return global_position

func _world_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root

func _pick_clip_index() -> int:
	if death_clips.size() == 1:
		return 0

	var idx := randi() % death_clips.size()
	if avoid_repeating_last and idx == _last_clip_idx:
		idx = (idx + 1 + (randi() % (death_clips.size() - 1))) % death_clips.size()
	_last_clip_idx = idx
	return idx

func _play_at(world_pos: Vector3) -> void:
	var parent := _world_parent()
	if parent == null:
		return

	var idx := _pick_clip_index()
	var clip := death_clips[idx]
	if clip == null:
		return

	var p := AudioStreamPlayer3D.new()
	p.stream = clip
	p.bus = audio_bus
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = unit_size
	p.attenuation_model = attenuation_model

	if randomize_pitch:
		var a := minf(pitch_min, pitch_max)
		var b := maxf(pitch_min, pitch_max)
		p.pitch_scale = randf_range(a, b)

	parent.add_child(p)
	p.global_position = world_pos
	p.play()

	# Cleanup after clip finished (fallback timer in case finished isn't emitted)
	p.finished.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)

	if auto_free_after > 0.0:
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = auto_free_after
		t.timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)
		p.add_child(t)
		t.start()
