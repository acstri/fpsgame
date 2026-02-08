extends Node
class_name SpellCaster

@export_group("Spell Nodes (optional overrides)")
@export var hitscan: HitscanSpell
@export var projectile_spell: MagicMissile

@export_group("Data/Stats")
@export var spell: SpellData
@export var automatic := true
@export var stats: PlayerStats # optional; will be auto-found

@export_group("Refs")
@export var camera: Camera3D # optional; will be auto-found

var _cd_left := 0.0
var _ready_ok := false

func _ready() -> void:
	_autowire()
	_ready_ok = _validate_refs()
	if not _ready_ok:
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not _ready_ok:
		return

	_cd_left = maxf(0.0, _cd_left - delta)

	var wants_cast := Input.is_action_pressed("fire") if automatic else Input.is_action_just_pressed("fire")
	if wants_cast:
		try_cast()

func try_cast() -> void:
	if not _ready_ok:
		return
	if spell == null:
		return
	if _cd_left > 0.0:
		return

	var fire_mult := stats.fire_rate_mult if stats != null else 1.0
	_cd_left = maxf(0.01, spell.cooldown / maxf(0.001, fire_mult))

	var dmg := spell.damage * (stats.damage_mult if stats != null else 1.0)
	var rng := spell.spell_range * (stats.range_mult if stats != null else 1.0)
	var spr := spell.spread_deg * (stats.spread_mult if stats != null else 1.0)

	var is_crit := false
	if stats != null:
		var r := stats.roll_crit(dmg)
		dmg = float(r["damage"])
		is_crit = bool(r["crit"])

	if projectile_spell != null:
		projectile_spell.cast(dmg, rng, spr, is_crit)
		return

	if hitscan != null:
		hitscan.cast(dmg, rng, spr, is_crit)

# --- wiring/validation ---

func _autowire() -> void:
	var owner_node := get_owner()

	# Find spell nodes by type under the same owner/player if not assigned
	if projectile_spell != null:
		projectile_spell.caster_root = owner_node
	if hitscan != null:
		hitscan.caster_root = owner_node

	# Find stats/camera if not assigned
	if stats == null and owner_node != null:
		stats = _find_child_by_type(owner_node, PlayerStats) as PlayerStats
		if stats == null:
			stats = owner_node.get_node_or_null("PlayerStats") as PlayerStats

	if camera == null:
		if owner_node != null:
			camera = _find_child_by_type(owner_node, Camera3D) as Camera3D
		if camera == null:
			camera = get_viewport().get_camera_3d()

	# Inject camera/stats into spell implementations if they exist and are missing refs
	if projectile_spell != null:
		if projectile_spell.camera == null:
			projectile_spell.camera = camera
		if projectile_spell.stats == null:
			projectile_spell.stats = stats

	if hitscan != null:
		if hitscan.camera == null:
			hitscan.camera = camera
		if hitscan.stats == null:
			hitscan.stats = stats

func _validate_refs() -> bool:
	var ok := true

	if spell == null:
		push_error("SpellCaster: spell (SpellData) is not assigned.")
		ok = false

	# Must have at least one implementation
	if projectile_spell == null and hitscan == null:
		push_error("SpellCaster: no spell implementation found (assign projectile_spell or hitscan, or make sure one exists under the player).")
		ok = false

	# If an implementation exists, it must have a camera (after autowire)
	if projectile_spell != null and projectile_spell.camera == null:
		push_error("SpellCaster: projectile_spell has no camera (assign SpellCaster.camera or MagicMissile.camera).")
		ok = false

	if hitscan != null and hitscan.camera == null:
		push_error("SpellCaster: hitscan has no camera (assign SpellCaster.camera or HitscanSpell.camera).")
		ok = false

	return ok

func _find_child_by_type(root: Node, t: Variant) -> Node:
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := _find_child_by_type(c, t)
		if deep != null:
			return deep
	return null
