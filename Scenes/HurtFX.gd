# res://fx/HurtFX.gd
# Attach under Player (ideally under Head or CameraPivot).
extends Node
class_name HurtFX

@export_group("References")
@export var head: Node3D              # e.g. your Head or CameraPivot node
@export var hurt_flash: CanvasItem    # ColorRect/TextureRect/etc. uses modulate.a

@export_group("Flash")
@export var flash_alpha := 0.55
@export var flash_in_time := 0.03
@export var flash_out_time := 0.18

@export_group("Shake")
@export var shake_pos_strength := 0.06      # meters
@export var shake_rot_strength_deg := 1.8   # degrees (roll only)
@export var shake_duration := 0.18
@export var shake_frequency := 28.0
@export var shake_falloff := 14.0

@export_group("Sounds")
@export var hurt_sounds: Array[AudioStream] = []
@export var sounds_bus := "SFX"
@export var sounds_min_pitch := 0.95
@export var sounds_max_pitch := 1.08
@export var sounds_min_db := -6.0
@export var sounds_max_db := 0.0

var _flash_tween: Tween
var _audio: AudioStreamPlayer

var _shake_left := 0.0
var _shake_phase := 0.0
var _base_head_pos: Vector3
var _base_head_rot: Vector3
var _has_base := false

var _last_pos_offset := Vector3.ZERO
var _last_roll := 0.0

func _ready() -> void:
	# Cache baseline
	if head != null:
		_base_head_pos = head.position
		_base_head_rot = head.rotation
		_has_base = true

	# Audio
	_audio = AudioStreamPlayer.new()
	_audio.name = "_HurtSFX"
	_audio.bus = sounds_bus
	add_child(_audio)

	# Flash starts hidden and above HUD if possible
	if hurt_flash != null:
		hurt_flash.modulate.a = 0.0
		if hurt_flash is Control:
			var c := hurt_flash as Control
			c.visible = true
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.move_to_front()

	# Auto-connect to Combat_Events.hurt_flash (your PlayerHealth emits this)
	var events := get_node_or_null("/root/Combat_Events")
	if events != null and events.has_signal("hurt_flash"):
		events.hurt_flash.connect(_on_hurt_flash)

func _exit_tree() -> void:
	if head == null:
		return
	head.position -= _last_pos_offset
	head.rotation.z -= _last_roll


# External API if you still want to call it manually
func trigger(amount: float = 1.0) -> void:
	_do_flash(amount)
	_do_shake(amount)
	_do_sound(amount)

func _on_hurt_flash(is_player: bool) -> void:
	# This signal is emitted for both player/enemies in some setups; keep player-only behavior
	if not is_player:
		return
	trigger(1.0)

func _do_flash(amount: float) -> void:
	if hurt_flash == null:
		return

	if _flash_tween != null and is_instance_valid(_flash_tween):
		_flash_tween.kill()

	var a := clampf(flash_alpha * maxf(0.2, amount), 0.0, 1.0)

	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_SINE)
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(_set_flash_alpha, 0.0, a, flash_in_time)
	_flash_tween.tween_method(_set_flash_alpha, a, 0.0, flash_out_time)

func _set_flash_alpha(v: float) -> void:
	if hurt_flash == null:
		return
	var c := hurt_flash.modulate
	c.a = clampf(v, 0.0, 1.0)
	hurt_flash.modulate = c


func _do_shake(amount: float) -> void:
	if head == null:
		return

	# Ensure we have a baseline captured at the start of a shake burst
	if not _has_base:
		_base_head_pos = head.position
		_base_head_rot = head.rotation
		_has_base = true
	elif _shake_left <= 0.0:
		_base_head_pos = head.position
		_base_head_rot = head.rotation

	# Extend/refresh shake
	_shake_left = maxf(_shake_left, shake_duration * clampf(amount, 0.2, 2.0))

func _do_sound(amount: float) -> void:
	if hurt_sounds.is_empty():
		return

	var s := hurt_sounds[randi() % hurt_sounds.size()]
	if s == null:
		return

	_audio.stop()
	_audio.stream = s

	var t := clampf(amount, 0.0, 1.5)
	_audio.pitch_scale = randf_range(sounds_min_pitch, sounds_max_pitch)
	_audio.volume_db = lerpf(sounds_min_db, sounds_max_db, clampf(t, 0.0, 1.0))
	_audio.play()

func _process(delta: float) -> void:
	if head == null:
		return

	# Remove last frame's offsets so controller rotation/pivot stays in control
	head.position -= _last_pos_offset
	head.rotation.z -= _last_roll
	_last_pos_offset = Vector3.ZERO
	_last_roll = 0.0

	if _shake_left <= 0.0:
		return

	_shake_left = maxf(0.0, _shake_left - delta)

	var t := (shake_duration - _shake_left)
	var fade := 1.0 / (1.0 + shake_falloff * maxf(0.0, t))

	_shake_phase += delta * shake_frequency * TAU

	var pos_amp := shake_pos_strength * fade
	var rot_amp := deg_to_rad(shake_rot_strength_deg) * fade

	var ox := sin(_shake_phase * 1.00)
	var oy := sin(_shake_phase * 1.37 + 1.2)
	var oz := cos(_shake_phase * 0.91 + 2.3)

	_last_pos_offset = Vector3(ox, oy, 0.0) * pos_amp
	_last_roll = oz * rot_amp

	head.position += _last_pos_offset
	head.rotation.z += _last_roll


func _restore_head() -> void:
	if head == null or not _has_base:
		return
	head.position = _base_head_pos
	head.rotation = _base_head_rot
