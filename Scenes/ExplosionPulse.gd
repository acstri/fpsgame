extends Node3D
class_name ExplosionPulse

@export var lifetime := 0.18

@export_group("Radius")
@export var target_radius := 3.5          # set at spawn to match damage explosion radius
@export var expand_mult := 1.25           # expands beyond target radius
@export var min_thickness := 0.0          # if you later switch to a ring mesh, you can use this

@export_group("Material")
@export var color := Color(1.0, 0.55, 0.2, 1.0)
@export var glow_boost := 2.0
@export var unshaded := true

@export_group("Light (optional)")
@export var use_light := true
@export var light_energy := 8.0
@export var light_range := 8.0
@export var light_color := Color(1.0, 0.55, 0.2, 1.0)

@export_group("Fade")
@export var fade_curve_pow := 1.6 # higher = faster fade

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _light: OmniLight3D = get_node_or_null("Light") as OmniLight3D

var _mat: StandardMaterial3D
var _base_mesh_radius := 0.5 # fallback assumption

func _ready() -> void:
	_capture_base_mesh_radius()
	_setup_material()
	_setup_light()
	_play()

func set_target_radius(r: float) -> void:
	target_radius = maxf(0.01, r)

func _capture_base_mesh_radius() -> void:
	if _mesh == null or _mesh.mesh == null:
		return

	# Best case: SphereMesh
	if _mesh.mesh is SphereMesh:
		_base_mesh_radius = maxf(0.001, (_mesh.mesh as SphereMesh).radius)
		return

	# Fallback: approximate from AABB
	var aabb := _mesh.mesh.get_aabb()
	var approx := 0.5 * maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	_base_mesh_radius = maxf(0.001, approx)

func _setup_material() -> void:
	if _mesh == null:
		return

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = color * glow_boost
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.flags_unshaded = unshaded
	_mesh.material_override = _mat

func _setup_light() -> void:
	if _light == null:
		return

	if use_light:
		_light.light_color = light_color
		_light.light_energy = light_energy
		_light.omni_range = light_range
	else:
		_light.visible = false

func _play() -> void:
	# Convert desired world-space radius to node scale
	var start_scale := target_radius / _base_mesh_radius
	var end_scale := (target_radius * expand_mult) / _base_mesh_radius

	# Start exactly at target radius
	scale = Vector3.ONE * start_scale

	var t := 0.0
	while t < lifetime:
		var u := clampf(t / maxf(0.0001, lifetime), 0.0, 1.0)

		# ease-out for expansion
		var grow := 1.0 - pow(1.0 - u, 2.0)
		var s := lerpf(start_scale, end_scale, grow)
		scale = Vector3.ONE * s

		# fade alpha + emission
		var a := 1.0 - u
		a = pow(a, fade_curve_pow)

		if _mat != null:
			var c := color
			c.a = a
			_mat.albedo_color = c
			_mat.emission = color * glow_boost * a

		if _light != null and use_light:
			_light.light_energy = light_energy * a

		await get_tree().process_frame
		t += get_process_delta_time()

	queue_free()
