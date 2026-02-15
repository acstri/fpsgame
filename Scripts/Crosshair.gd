extends Control
class_name Crosshair

@export_group("Crosshair Settings")
@export var texture: Texture2D
@export var scale_factor: float = 1.0
@export var offset: Vector2 = Vector2.ZERO

var _tex_rect: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_setup()
	_center()

	get_viewport().size_changed.connect(_center)

func _setup() -> void:
	_tex_rect = TextureRect.new()
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_tex_rect)

	if texture != null:
		_tex_rect.texture = texture
		_apply_size()

func _apply_size() -> void:
	if _tex_rect.texture == null:
		return

	var size := _tex_rect.texture.get_size() * scale_factor
	_tex_rect.custom_minimum_size = size
	_tex_rect.size = size

func _center() -> void:
	if _tex_rect == null:
		return

	var vp_size := get_viewport_rect().size
	var tex_size := _tex_rect.size
	_tex_rect.position = (vp_size * 0.5) - (tex_size * 0.5) + offset
