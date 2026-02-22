extends Control
class_name UpgradeChoiceCard

signal hold_started(card: UpgradeChoiceCard)
signal hold_canceled(card: UpgradeChoiceCard)
signal hold_completed(card: UpgradeChoiceCard)

@export_group("Assignable (preferred)")
@export var button: Button
@export var title_label: Label
@export var desc_label: Label
@export var icon_rect: TextureRect
@export var rarity_label: Label
@export var border_panel: Panel
@export var hold_fill: ColorRect
@export var sheen_rect: ColorRect

@export_group("Behavior")
@export_range(0.05, 2.0, 0.05) var hold_seconds := 0.45
@export_range(1.0, 1.2, 0.01) var hover_scale := 1.05
@export_range(0.0, 0.25, 0.01) var hover_time := 0.10

@export_group("Colors")
@export var fill_color: Color = Color(1, 1, 1, 0.18)

@export_group("Rarity (optional)")
@export var rarity_names: Array[String] = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
@export var rarity_colors: Array[Color] = [
	Color(0.70, 0.70, 0.70, 1.0),
	Color(0.35, 0.85, 0.45, 1.0),
	Color(0.35, 0.55, 0.95, 1.0),
	Color(0.80, 0.40, 0.95, 1.0),
	Color(0.98, 0.78, 0.25, 1.0)
]

var upgrade: UpgradeData
var index: int = -1

var _holding := false
var _elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_autowire_if_missing()

	if button == null:
		push_error("UpgradeChoiceCard: No button assigned and could not auto-find one.")
		return

	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.button_down.connect(_on_down)
	button.button_up.connect(_on_up)
	button.mouse_exited.connect(_on_exit)

	button.mouse_entered.connect(func(): _on_hover(true))
	button.focus_entered.connect(func(): _on_hover(true))
	button.focus_exited.connect(func(): _on_hover(false))

	button.resized.connect(_sync_overlays)

	if hold_fill != null:
		hold_fill.process_mode = Node.PROCESS_MODE_ALWAYS
		hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold_fill.color = fill_color
		hold_fill.visible = false
		hold_fill.size = Vector2.ZERO

	if sheen_rect != null:
		sheen_rect.process_mode = Node.PROCESS_MODE_ALWAYS
		sheen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sheen_rect.material == null:
			sheen_rect.material = _make_sheen_material()

	_sync_overlays()

func _process(delta: float) -> void:
	if not visible:
		return

	# sheen animation
	if sheen_rect != null and sheen_rect.material is ShaderMaterial:
		var m := sheen_rect.material as ShaderMaterial
		var tt: float = float(m.get_shader_parameter("u_time"))
		m.set_shader_parameter("u_time", tt + delta)

	# hold logic
	if not _holding:
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_cancel_hold(true)
		return

	_elapsed += delta
	var p = _elapsed / max(hold_seconds, 0.001)
	set_hold_progress(p)

	if p >= 1.0:
		_holding = false
		set_hold_progress(0.0)
		hold_completed.emit(self)

func set_upgrade(p_upgrade: UpgradeData, p_index: int) -> void:
	upgrade = p_upgrade
	index = p_index

	var has := (upgrade != null)
	visible = has
	if button != null:
		button.disabled = not has

	_cancel_hold(false)

	if not has:
		return

	if title_label != null:
		title_label.text = upgrade.title
	if desc_label != null:
		desc_label.text = upgrade.description

	if icon_rect != null:
		icon_rect.texture = upgrade.icon
		icon_rect.visible = (upgrade.icon != null)

	# rarity (only if you assign nodes)
	var rarity_i: int = 0
	if rarity_names.size() > 0:
		rarity_i = clampi(upgrade.rarity, 0, rarity_names.size() - 1)

	if rarity_label != null and rarity_names.size() > 0:
		var nm: String = rarity_names[rarity_i]
		if upgrade.rarity_label_override.strip_edges() != "":
			nm = upgrade.rarity_label_override.to_upper()
		rarity_label.text = nm

		if rarity_colors.size() > 0:
			var c: Color = rarity_colors[min(rarity_i, rarity_colors.size() - 1)]
			rarity_label.modulate = Color(c.r, c.g, c.b, 0.90)

	if border_panel != null and rarity_colors.size() > 0:
		var border_color: Color = rarity_colors[min(rarity_i, rarity_colors.size() - 1)]
		var sb := border_panel.get_theme_stylebox("panel") as StyleBox
		if sb is StyleBoxFlat:
			var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			flat.border_color = border_color
			border_panel.add_theme_stylebox_override("panel", flat)

	_sync_overlays()

func set_hold_progress(progress: float) -> void:
	if hold_fill == null or button == null:
		return
	progress = clampf(progress, 0.0, 1.0)

	var w := button.size.x * progress
	hold_fill.position = Vector2.ZERO
	hold_fill.size = Vector2(w, button.size.y)
	hold_fill.visible = progress > 0.0

func is_holding() -> bool:
	return _holding

func cancel_hold_external(play_cancel: bool) -> void:
	_cancel_hold(play_cancel)

func _on_down() -> void:
	if upgrade == null or button == null or button.disabled:
		return
	_holding = true
	_elapsed = 0.0
	set_hold_progress(0.0)
	hold_started.emit(self)

func _on_up() -> void:
	if _holding:
		_cancel_hold(true)

func _on_exit() -> void:
	if _holding:
		_cancel_hold(true)
	_on_hover(false)

func _cancel_hold(play_cancel: bool) -> void:
	_holding = false
	_elapsed = 0.0
	set_hold_progress(0.0)
	if play_cancel:
		hold_canceled.emit(self)

func _on_hover(entering: bool) -> void:
	if button == null or button.disabled or upgrade == null:
		return

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)

	var target := Vector2.ONE * (hover_scale if entering else 1.0)
	tw.tween_property(self, "scale", target, hover_time)

func _sync_overlays() -> void:
	if button == null:
		return

	if sheen_rect != null:
		sheen_rect.position = Vector2.ZERO
		sheen_rect.size = button.size

	if hold_fill != null:
		hold_fill.position = Vector2.ZERO
		hold_fill.size.y = button.size.y

func _autowire_if_missing() -> void:
	# Prefer explicit prefixes (works with Button1/Icon1/... names)
	if button == null:
		button = _find_button_by_prefix(["Button", "Button1", "Button2", "Button3"])
	if button == null:
		button = _find_first_button()

	if title_label == null:
		title_label = _find_label_by_prefix(["Title", "Title1", "Title2", "Title3"])
	if desc_label == null:
		desc_label = _find_label_by_prefix(["Desc", "Desc1", "Desc2", "Desc3", "Description", "Description1", "Text", "Text1"])
	if icon_rect == null:
		icon_rect = _find_texture_by_prefix(["Icon", "Icon1", "Icon2", "Icon3"])
	if rarity_label == null:
		rarity_label = _find_label_by_prefix(["RarityLabel", "RarityLabel1", "Rarity", "Rarity1"])
	if hold_fill == null:
		hold_fill = _find_colorrect_by_prefix(["HoldFill", "HoldFill1", "Fill", "Fill1", "Progress", "Progress1"])
	if sheen_rect == null:
		sheen_rect = _find_colorrect_by_prefix(["Sheen", "Sheen1", "Shine", "Shine1"])
	if border_panel == null:
		border_panel = _find_panel_by_prefix(["Border", "Border1", "Frame", "Frame1"])

func _walk_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n = stack.pop_back()
		out.append(n)
		for ch in n.get_children():
			if ch is Node:
				stack.push_back(ch)
	return out

func _find_button_by_prefix(prefixes: Array[String]) -> Button:
	for n in _walk_nodes():
		if n == self:
			continue
		if n is Button:
			var nm := String(n.name)
			for p in prefixes:
				if nm.begins_with(p):
					return n as Button
	return null

func _find_first_button() -> Button:
	for n in _walk_nodes():
		if n != self and n is Button:
			return n as Button
	return null

func _find_label_by_prefix(prefixes: Array[String]) -> Label:
	for n in _walk_nodes():
		if n == self:
			continue
		if n is Label:
			var nm := String(n.name)
			for p in prefixes:
				if nm.begins_with(p):
					return n as Label
	return null

func _find_texture_by_prefix(prefixes: Array[String]) -> TextureRect:
	for n in _walk_nodes():
		if n == self:
			continue
		if n is TextureRect:
			var nm := String(n.name)
			for p in prefixes:
				if nm.begins_with(p):
					return n as TextureRect
	return null

func _find_colorrect_by_prefix(prefixes: Array[String]) -> ColorRect:
	for n in _walk_nodes():
		if n == self:
			continue
		if n is ColorRect:
			var nm := String(n.name)
			for p in prefixes:
				if nm.begins_with(p):
					return n as ColorRect
	return null

func _find_panel_by_prefix(prefixes: Array[String]) -> Panel:
	for n in _walk_nodes():
		if n == self:
			continue
		if n is Panel:
			var nm := String(n.name)
			for p in prefixes:
				if nm.begins_with(p):
					return n as Panel
	return null

func _make_sheen_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float u_time = 0.0;
uniform float u_speed = 0.55;
uniform float u_width = 0.22;
uniform float u_alpha = 0.18;

void fragment() {
	vec2 uv = UV;
	float t = fract(u_time * u_speed);
	float d = uv.x + (uv.y * 0.35);
	float band = smoothstep(t - u_width, t, d) * (1.0 - smoothstep(t, t + u_width, d));
	COLOR = vec4(1.0, 1.0, 1.0, band * u_alpha);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("u_time", randf_range(0.0, 1.0))
	return mat
