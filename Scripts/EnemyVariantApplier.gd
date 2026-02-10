extends Node
class_name EnemyVariantApplier

@export_group("Selection")
@export var variants: Array[EnemyVariantData] = []
@export var force_variant_id: String = "" # blank = random
@export var apply_on_ready: bool = true

@export_group("Scaling")
@export var apply_scale: bool = true

@export_group("Tag (Sprite3D)")
@export var tag_height: float = 2.35
@export var tag_billboard: int = BaseMaterial3D.BILLBOARD_ENABLED
@export var tag_no_depth_test: bool = true
@export var tag_default_scale: float = 0.35

var active_variant: EnemyVariantData = null

var _base_enemy_scale: Vector3 = Vector3.ONE
var _base_scale_cached := false

func _ready() -> void:
	_cache_base_scale()
	if apply_on_ready:
		apply_variant(_pick_variant())

func _cache_base_scale() -> void:
	if _base_scale_cached:
		return
	var enemy := get_parent()
	if enemy is Node3D:
		_base_enemy_scale = (enemy as Node3D).scale
		_base_scale_cached = true

func apply_variant(v: EnemyVariantData) -> void:
	active_variant = v
	if v == null:
		_hide_tag()
		return

	var enemy := get_parent()
	if enemy == null:
		return

	_cache_base_scale()

	# ---- Scale (root)
	if apply_scale and enemy is Node3D:
		var m := maxf(0.01, v.scale_mult)
		(enemy as Node3D).scale = _base_enemy_scale * m

	# ---- Move speed (Enemy.gd)
	if enemy is Enemy:
		(enemy as Enemy).move_speed *= v.move_speed_mult

	# ---- HP (EnemyHealth)
	var health := _find_child_by_type(enemy, EnemyHealth) as EnemyHealth
	if health == null:
		health = enemy.get_node_or_null("EnemyHealth") as EnemyHealth
	if health != null:
		health.max_hp *= v.hp_mult
		health.hp = health.max_hp

	# ---- Melee damage (EnemyMeleeDamage)
	var melee := _find_child_by_type(enemy, EnemyMeleeDamage) as EnemyMeleeDamage
	if melee == null:
		melee = enemy.get_node_or_null("HurtArea") as EnemyMeleeDamage
	if melee != null:
		melee.damage *= v.melee_damage_mult

	# ---- XP (EnemyDropper)
	var dropper := _find_child_by_type(enemy, EnemyDropper) as EnemyDropper
	if dropper == null:
		dropper = enemy.get_node_or_null("Dropper") as EnemyDropper
	if dropper != null:
		dropper.total_xp = int(round(float(dropper.total_xp) * v.xp_mult))

	# ---- Tag (deferred-safe)
	_update_tag(v)

func _pick_variant() -> EnemyVariantData:
	if variants.is_empty():
		return null

	# Forced
	if force_variant_id.strip_edges() != "":
		for vv in variants:
			if vv != null and vv.id == force_variant_id:
				return vv

	# Weighted random
	var total := 0.0
	for vv in variants:
		if vv == null or vv.weight <= 0.0:
			continue
		total += vv.weight

	if total <= 0.0:
		return variants[0]

	var roll := randf() * total
	var acc := 0.0
	for vv in variants:
		if vv == null or vv.weight <= 0.0:
			continue
		acc += vv.weight
		if roll <= acc:
			return vv

	return variants[0]

# ---------------- Tag helpers (deferred-safe) ----------------

func _update_tag(v: EnemyVariantData) -> void:
	var enemy := get_parent()
	if enemy == null:
		return

	var sprite := enemy.get_node_or_null("VariantTag/Sprite3D") as Sprite3D
	if sprite != null:
		_apply_tag_to_sprite(sprite, v)
		return

	call_deferred("_ensure_tag_nodes_and_apply", v)

func _ensure_tag_nodes_and_apply(v: EnemyVariantData) -> void:
	var sprite := _get_or_create_tag_sprite_deferred_safe()
	if sprite == null:
		return
	_apply_tag_to_sprite(sprite, v)

func _get_or_create_tag_sprite_deferred_safe() -> Sprite3D:
	var enemy := get_parent()
	if enemy == null:
		return null

	var existing := enemy.get_node_or_null("VariantTag/Sprite3D") as Sprite3D
	if existing != null:
		return existing

	var marker := enemy.get_node_or_null("VariantTag") as Node3D
	if marker == null:
		marker = Marker3D.new()
		marker.name = "VariantTag"
		enemy.add_child.call_deferred(marker)

	marker.position = Vector3(0, tag_height, 0)

	var sprite := Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.visible = false
	sprite.billboard = tag_billboard
	sprite.no_depth_test = tag_no_depth_test
	sprite.pixel_size = 0.01

	marker.add_child.call_deferred(sprite)
	return sprite

func _apply_tag_to_sprite(sprite: Sprite3D, v: EnemyVariantData) -> void:
	if (not v.show_tag) or v.tag_texture == null:
		sprite.visible = false
		return

	sprite.visible = true
	sprite.texture = v.tag_texture
	sprite.modulate = v.tag_color

	var s := v.tag_scale if v.tag_scale > 0.0 else tag_default_scale
	sprite.scale = Vector3(s, s, s)

func _hide_tag() -> void:
	var enemy := get_parent()
	if enemy == null:
		return
	var sprite := enemy.get_node_or_null("VariantTag/Sprite3D") as Sprite3D
	if sprite != null:
		sprite.visible = false

# ---------------- Utils ----------------

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
