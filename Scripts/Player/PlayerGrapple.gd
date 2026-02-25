extends RefCounted
class_name PlayerGrapple

class ProcCurveRunner:
	var curve: Curve
	var length: float
	var position: float = 0.0
	var change_min_threshold: float
	var targets := {"min": 0.0, "max": 1.0, "defaultMin": 0.0, "snap": 0.0}
	var stopped: bool = true

	func _init(p_curve: Curve, p_length: float, p_threshold: float) -> void:
		curve = p_curve
		length = maxf(0.001, p_length)
		change_min_threshold = p_threshold

	func set_targets(p_min: float, p_max: float, p_snap: float = -INF) -> void:
		targets["min"] = p_min
		targets["defaultMin"] = p_min
		targets["max"] = p_max
		targets["snap"] = p_max if p_snap == -INF else p_snap

	func start() -> void:
		stopped = false
		position = 0.0

	func is_running() -> bool:
		return not stopped

	func force_stop() -> void:
		stopped = true
		position = 0.0

	func step(delta: float) -> float:
		if stopped or curve == null:
			return float(targets["min"])

		position += (delta / length)
		var c := curve.sample(clampf(position, 0.0, 1.0))
		var lerped := lerpf(float(targets["min"]), float(targets["max"]), c)

		if position >= 1.0:
			position = 0.0
			stopped = true
			return float(targets["snap"])

		if c > change_min_threshold and float(targets["min"]) != float(targets["defaultMin"]):
			targets["min"] = targets["defaultMin"]

		return lerped

var launched: bool = false
var target: Vector3 = Vector3.ZERO
var rest_length: float = 0.0

var attached_body: Node3D = null
var local_offset: Vector3 = Vector3.ZERO

var _floor_snap_default: float = 0.0
var _runner: ProcCurveRunner = null

func init_from(pc: PlayerController) -> void:
	if pc.grapple_rest_curve != null:
		_runner = ProcCurveRunner.new(pc.grapple_rest_curve, pc.grapple_rest_curve_length, pc.grapple_change_min_threshold)

	_floor_snap_default = pc.floor_snap_length
	if pc.grapple_rope != null:
		pc.grapple_rope.visible = false

func try_launch(pc: PlayerController) -> bool:
	if pc.grapple_ray == null or pc.grapple_origin == null:
		return false

	pc.grapple_ray.target_position = Vector3(0.0, 0.0, -pc.grapple_max_distance)
	pc.grapple_ray.force_raycast_update()
	if not pc.grapple_ray.is_colliding():
		return false

	var hit := pc.grapple_ray.get_collision_point()
	var dist := pc.grapple_origin.global_position.distance_to(hit)
	if dist < pc.grapple_min_attach_distance:
		return false

	attached_body = pc.grapple_ray.get_collider() as Node3D
	local_offset = attached_body.to_local(hit) if attached_body != null else Vector3.ZERO

	target = hit
	launched = true

	_floor_snap_default = pc.floor_snap_length
	pc.floor_snap_length = 0.0

	# Quakelike-style: rest starts at max fraction; runner animates down toward min
	rest_length = dist * pc.grapple_max_rest_fraction
	if _runner != null:
		var min_len := dist * pc.grapple_min_rest_fraction
		_runner.set_targets(min_len, rest_length)
		_runner.start()

	return true

func retract(pc: PlayerController) -> void:
	launched = false
	attached_body = null
	local_offset = Vector3.ZERO

	pc.floor_snap_length = _floor_snap_default

	if _runner != null:
		_runner.force_stop()

	if pc.grapple_rope != null:
		pc.grapple_rope.visible = false

func update_target_from_body(pc: PlayerController) -> void:
	if attached_body == null:
		return
	if not is_instance_valid(attached_body):
		retract(pc)
		return
	target = attached_body.to_global(local_offset)

func tick_rest_length(delta: float) -> void:
	if _runner != null and _runner.is_running():
		rest_length = _runner.step(delta)
	elif _runner != null:
		rest_length = float(_runner.targets["min"])

func apply_rope_force(pc: PlayerController, delta: float) -> void:
	# updates target if attached to moving body
	update_target_from_body(pc)
	tick_rest_length(delta)

	var to_target := target - pc.global_position
	var dist := to_target.length()
	if dist < 0.001:
		return

	var dir := to_target / dist
	var displacement := dist - rest_length
	if displacement <= 0.0:
		return

	var vel_along := pc.velocity.dot(dir)
	var magnitude := displacement * pc.grapple_stiffness
	var force := dir * magnitude - dir * (vel_along * pc.grapple_damping)
	pc.velocity += force * delta

func update_rope_visual(pc: PlayerController) -> void:
	if pc.grapple_rope == null:
		return
	if not launched:
		pc.grapple_rope.visible = false
		return

	pc.grapple_rope.visible = true
	if pc.grapple_origin != null:
		pc.grapple_rope.global_position = pc.grapple_origin.global_position

	pc.grapple_rope.look_at(target, Vector3.UP)

	var d := 0.0
	if pc.grapple_origin != null:
		d = pc.grapple_origin.global_position.distance_to(target)
	else:
		d = pc.global_position.distance_to(target)

	var s := pc.grapple_rope.scale
	s.z = d
	pc.grapple_rope.scale = s
