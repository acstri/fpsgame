extends Control
class_name Crosshair

@export_group("Crosshair Settings")
@export var texture: Texture2D
@export var scale_factor: float = 1.0
@export var offset: Vector2 = Vector2.ZERO

@export_group("Cooldown Arc")
@export var cooldown_arc_enabled := true
@export_range(0.0, 1.0, 0.01) var cooldown_ratio := 0.0

@export_subgroup("Arc Geometry")
@export var arc_radius_padding := 10.0
@export var arc_thickness := 4.0
@export_range(8, 256, 1) var arc_points := 64
@export_range(0.0, 360.0, 1.0) var arc_sweep_angle_deg := 180.0
@export_range(-360.0, 360.0, 1.0) var arc_center_angle_deg := -90.0
@export var arc_clockwise := true

@export_subgroup("Arc Colors")
@export var arc_bg_color := Color(1, 1, 1, 0.18)
@export var arc_fg_color := Color(1, 1, 1, 0.85)
@export var arc_antialias := true
@export var arc_show_when_ready := false

@export_group("Ammo Arc (segmented)")
@export var ammo_arc_enabled := true
@export_range(1, 200, 1) var ammo_segments_default := 30
@export_range(0.0, 15.0, 0.1) var ammo_segment_gap_deg := 1.2
@export var ammo_depletes_right_to_left := true

var _tex_rect: TextureRect
var _center_pos := Vector2.ZERO
var _base_radius := 22.0

var _ammo_mode := false
var _ammo_current := 0.0
var _ammo_max := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	anchors_preset = Control.PRESET_FULL_RECT
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	_setup()
	_center()
	get_viewport().size_changed.connect(_center)

func set_cooldown_ratio(r: float) -> void:
	cooldown_ratio = clampf(r, 0.0, 1.0)
	queue_redraw()

func set_arc_mode_ammo(enabled: bool) -> void:
	_ammo_mode = enabled
	queue_redraw()

func set_ammo_state(current: float, max_ammo: int) -> void:
	_ammo_current = maxf(0.0, current)
	_ammo_max = maxi(0, max_ammo)
	queue_redraw()

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
	_base_radius = maxf(size.x, size.y) * 0.5

func _center() -> void:
	if _tex_rect == null:
		return
	_apply_size()

	var vp_size := get_viewport_rect().size
	var tex_size := _tex_rect.size

	_center_pos = (vp_size * 0.5) + offset
	_tex_rect.position = _center_pos - (tex_size * 0.5)

	queue_redraw()

func _draw() -> void:
	if _ammo_mode:
		if not ammo_arc_enabled:
			return
		_draw_ammo_segmented()
		return

	if not cooldown_arc_enabled:
		return

	var t := clampf(cooldown_ratio, 0.0, 1.0)
	if t <= 0.001 and not arc_show_when_ready:
		return

	var r := _base_radius + arc_radius_padding
	var sweep := deg_to_rad(clampf(arc_sweep_angle_deg, 0.0, 360.0))
	var half := sweep * 0.5
	var mid := deg_to_rad(arc_center_angle_deg)
	var a0 := mid - half
	var a1 := mid + half
	var pts := int(clampf(float(arc_points), 8.0, 256.0))

	draw_arc(_center_pos, r, a0, a1, pts, arc_bg_color, arc_thickness, arc_antialias)

	if t <= 0.001:
		return

	if arc_clockwise:
		var af := lerpf(a0, a1, t)
		draw_arc(_center_pos, r, a0, af, pts, arc_fg_color, arc_thickness, arc_antialias)
	else:
		var af := lerpf(a1, a0, t)
		draw_arc(_center_pos, r, a1, af, pts, arc_fg_color, arc_thickness, arc_antialias)

func _draw_ammo_segmented() -> void:
	var segs := _ammo_max if _ammo_max > 0 else ammo_segments_default
	segs = maxi(1, segs)

	var cur := clampf(_ammo_current, 0.0, float(segs))
	var full := int(floor(cur))
	var frac := cur - float(full)

	var r := _base_radius + arc_radius_padding

	var sweep_rad := deg_to_rad(clampf(arc_sweep_angle_deg, 0.0, 360.0))
	var half := sweep_rad * 0.5
	var mid := deg_to_rad(arc_center_angle_deg)
	var start := mid - half
	var end := mid + half

	var total_sweep := end - start
	var seg_sweep := total_sweep / float(segs)

	var gap := deg_to_rad(maxf(0.0, ammo_segment_gap_deg))
	gap = minf(gap, seg_sweep * 0.45)

	var pts_total := int(clampf(float(arc_points), 8.0, 256.0))
	var pts_per_seg := maxi(3, int(round(float(pts_total) / float(segs))))

	for i in range(segs):
		# Geometric segment index (left->right along the arc definition)
		var geom_i := i

		# Visual fill index: right-to-left depletion means "ammo remaining" fills from right side backward.
		# So we map geom_i to an ammo segment index that counts from the right.
		var ammo_i := (segs - 1 - geom_i) if ammo_depletes_right_to_left else geom_i

		var s0 := start + seg_sweep * float(geom_i)
		var s1 := s0 + seg_sweep

		var g0 := s0 + gap * 0.5
		var g1 := s1 - gap * 0.5
		if g1 <= g0:
			continue

		# Background tick
		draw_arc(_center_pos, r, g0, g1, pts_per_seg, arc_bg_color, arc_thickness, arc_antialias)

		# Foreground fill based on ammo_i
		if ammo_i < full:
			draw_arc(_center_pos, r, g0, g1, pts_per_seg, arc_fg_color, arc_thickness, arc_antialias)
		elif ammo_i == full and frac > 0.001:
			# Partial segment fill should grow in the same direction as the overall fill.
			# For right-to-left depletion, "filling back up" means segments get added from left->right in geom space,
			# but within the active segment we still want the partial to grow consistently with the segment's local direction.
			if arc_clockwise:
				var pf := lerpf(g0, g1, frac)
				draw_arc(_center_pos, r, g0, pf, pts_per_seg, arc_fg_color, arc_thickness, arc_antialias)
			else:
				var pf := lerpf(g1, g0, frac)
				draw_arc(_center_pos, r, g1, pf, pts_per_seg, arc_fg_color, arc_thickness, arc_antialias)
