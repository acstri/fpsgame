# new script: res://fx/HurtFX.gd
# Attach to a Node under your Player (recommended: under Head or Camera so shake feels correct).
extends Node
class_name HurtFX

@export_group("References")
@export var head: Node3D              # usually your Head node (the one you rotate for pitch)
@export var camera: Camera3D          # player camera
@export var hurt_flash: CanvasItem    # ColorRect/TextureRect/etc. (modulate.a used)

@export_group("Flash")
@export var flash_alpha := 0.55
@export var flash_in_time := 0.03
@export var flash_out_time := 0.18

@export_group("Shake")
@export var shake_pos_strength := 0.06      # meters
@export var shake_rot_strength_deg := 1.8   # degrees
@export var shake_duration := 0.18
@export var shake_frequency := 28.0
@export var shake_falloff := 14.0           # larger = quicker fade

@export_group("Sounds")
@export var hurt_sounds: Array[AudioStream] = []
@export var sounds_bus := "SFX"
@export var sounds_min_pitch := 0.95
@export var sounds_max_pitch := 1.08
@export var sounds_min_db := -6.0
@export var sounds_max_db := 0.0

var _flash_tween: Tween
var _base_head_pos: Vector3
var _base_head_rot: Vector3

var _shake_left := 0.0
var _shake_phase := 0.0

var _audio: AudioStreamPlayer

func _ready() -> void:
	if head != null:
		_base_head_pos = head.position
		_base_head_rot = head.rotation

	_audio = AudioStreamPlayer.new()
	_audio.name = "_HurtSFX"
	_audio.bus = sounds_bus
	_audio.autoplay = false
	add_child(_audio)

	# Ensure flash starts hidden
	if hurt_flash != null:
		hurt_flash.modulate.a = 0.0

func trigger(amount: float = 1.0) -> void:
	# amount is 0..1-ish; you can pass damage normalized if you want
	_do_flash(amount)
	_do_shake(amount)
	_do_sound(amount)

func _do_flash(amount: float) -> void:
	if hurt_flash == null:
		return

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	var a := clampf(flash_alpha * maxf(0.2, amount), 0.0, 1.0)

	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_SINE)
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(hurt_flash, "modulate:a", a, flash_in_time)
	_flash_tween.tween_property(hurt_flash, "modulate:a", 0.0, flash_out_time)

func _do_shake(amount: float) -> void:
	if head == null:
		return
	# extend/refresh shake
	_shake_left = maxf(_shake_left, shake_duration * clampf(amount, 0.2, 2.0))

func _do_sound(amount: float) -> void:
	if hurt_sounds.is_empty():
		return

	var idx := randi() % hurt_sounds.size()
	var s := hurt_sounds[idx]
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

	# keep base updated if other code moves head (crouch/slide camera drop)
	# (assumes your controller changes head.position; we treat that as new baseline)
	_base_head_pos = _base_head_pos.lerp(head.position, 0.0) # no-op but keeps intent clear

	if _shake_left <= 0.0:
		# restore (do not fight your controller: only restore rotation offset we applied)
		head.rotation = Vector3(head.rotation.x, head.rotation.y, 0.0)
		return

	_shake_left = maxf(0.0, _shake_left - delta)

	var fade := 1.0 / (1.0 + (shake_falloff * (shake_duration - _shake_left)))
	# phase advance
	_shake_phase += delta * shake_frequency * TAU

	var pos_amp := shake_pos_strength * fade
	var rot_amp := deg_to_rad(shake_rot_strength_deg) * fade

	# simple pseudo-noise using sin/cos with different offsets
	var ox := sin(_shake_phase * 1.00)
	var oy := sin(_shake_phase * 1.37 + 1.2)
	var oz := cos(_shake_phase * 0.91 + 2.3)

	# Apply as small camera-space feeling: position + roll
	head.position += Vector3(ox, oy, 0.0) * pos_amp
	head.rotation.z = oz * rot_amp
