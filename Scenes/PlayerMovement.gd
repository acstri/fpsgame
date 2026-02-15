extends Node
class_name PlayerMovement

enum MoveState { GROUND, AIR, DASH, SLIDE }

var _body: CharacterBody3D
var _look: PlayerLook
var _ground: GroundProbe
var _wall: WallProbe
var _stats: PlayerStats
var _cfg: MovementConfig

var _state := MoveState.AIR

# Timers / buffers
var _coyote_t := 0.0
var _jump_buf_t := 0.0
var _dash_t := 0.0
var _dash_cd_t := 0.0
var _slide_t := 0.0
var _wall_jump_cd_t := 0.0

var _dash_charges := 0

func setup(
	body: CharacterBody3D,
	look: PlayerLook,
	ground: GroundProbe,
	wall: WallProbe,
	stats: PlayerStats,
	cfg: MovementConfig
) -> void:
	_body = body
	_look = look
	_ground = ground
	_wall = wall
	_stats = stats
	_cfg = cfg

	_dash_charges = max(0, _cfg.dash_charges)
	_state = MoveState.AIR

func tick(delta: float) -> void:
	if _body == null or _cfg == null:
		return

	if _ground != null:
		_ground.tick()
	if _wall != null:
		_wall.tick()

	_tick_timers(delta)

	# --- buffers ---
	if _action_just_pressed("jump"):
		_jump_buf_t = _cfg.jump_buffer
	if _action_just_pressed(_cfg.dash_action):
		_try_start_dash()
	if _action_just_pressed(_cfg.slide_action) or _action_just_pressed("slide"):
		_try_start_slide()

	# --- gravity ---
	_apply_gravity(delta)

	# --- state selection (basic) ---
	var on_floor := _body.is_on_floor()
	if on_floor:
		_coyote_t = _cfg.coyote_time
		if _cfg.dash_reset_on_floor:
			_dash_charges = max(_dash_charges, _cfg.dash_charges)

	if _state != MoveState.DASH and _state != MoveState.SLIDE:
		_state = MoveState.GROUND if on_floor else MoveState.AIR

	# --- jump consume ---
	_consume_jump_if_possible()

	# --- movement ---
	match _state:
		MoveState.GROUND:
			_tick_ground(delta)
		MoveState.AIR:
			_tick_air(delta)
		MoveState.DASH:
			_tick_dash(delta)
		MoveState.SLIDE:
			_tick_slide(delta)

	# --- wall jump (air) ---
	_try_wall_jump()

	# --- stabilize floor contact ---
	if _body.is_on_floor() and _body.velocity.y < 0.0:
		_body.velocity.y = -0.1

func _tick_timers(delta: float) -> void:
	_coyote_t = maxf(0.0, _coyote_t - delta)
	_jump_buf_t = maxf(0.0, _jump_buf_t - delta)
	_dash_cd_t = maxf(0.0, _dash_cd_t - delta)
	_slide_t = maxf(0.0, _slide_t - delta)
	_wall_jump_cd_t = maxf(0.0, _wall_jump_cd_t - delta)

	if _dash_t > 0.0:
		_dash_t = maxf(0.0, _dash_t - delta)
		if _dash_t <= 0.0:
			_state = MoveState.AIR if not _body.is_on_floor() else MoveState.GROUND

func _apply_gravity(delta: float) -> void:
	if _state == MoveState.DASH:
		# No gravity during dash for a crisp feel.
		return
	if not _body.is_on_floor():
		_body.velocity.y -= _cfg.gravity * delta

func _consume_jump_if_possible() -> void:
	if _jump_buf_t <= 0.0:
		return

	var can_jump := _body.is_on_floor() or _coyote_t > 0.0
	if not can_jump:
		return

	var jmult := (_stats.jump_mult if _stats != null else 1.0)
	_body.velocity.y = _cfg.jump_velocity * jmult

	_jump_buf_t = 0.0
	_coyote_t = 0.0
	_state = MoveState.AIR

func _tick_ground(delta: float) -> void:
	var mult := (_stats.move_speed_mult if _stats != null else 1.0)

	var wish := _get_wish_dir()
	var want_sprint := _action_pressed("sprint")
	var target_speed := ( _cfg.sprint_speed if want_sprint else _cfg.walk_speed ) * mult

	var accel := _cfg.ground_accel
	var friction := _cfg.ground_friction

	if want_sprint:
		accel *= 1.15
		friction *= 0.85

	_apply_friction_custom(delta, friction)

	if wish != Vector3.ZERO:
		_accelerate(wish, target_speed, accel, delta)


	# Project velocity along the ground plane for consistent slope behavior.
	var v := _body.velocity
	var fn := (_ground.floor_normal() if _ground != null else Vector3.UP)
	v = _clip_velocity_to_plane(v, fn)
	_body.velocity = v

	_apply_friction(delta)

	if wish != Vector3.ZERO:
		_accelerate(wish, target_speed, _cfg.ground_accel, delta)

func _tick_air(delta: float) -> void:
	var mult := (_stats.move_speed_mult if _stats != null else 1.0)

	var wish := _get_wish_dir()
	var want_sprint := _action_pressed("sprint")
	var base := ( _cfg.sprint_speed if want_sprint else _cfg.walk_speed ) * mult

	# Cap only the "wish influence" in air; do not clamp actual velocity.
	var wish_speed := minf(base, _cfg.air_max_wish_speed * mult)

	if wish != Vector3.ZERO:
		_accelerate(wish, wish_speed, _cfg.air_accel, delta)
		_apply_air_control(wish, wish_speed, delta)

func _tick_dash(_delta: float) -> void:
	# Dash keeps whatever velocity was set at dash start.
	pass

func _tick_slide(delta: float) -> void:
	# Low friction and gentle steering while sliding.
	var wish := _get_wish_dir()
	_apply_slide_friction(delta)

	if wish != Vector3.ZERO:
		_accelerate(wish, _cfg.walk_speed * 1.0, _cfg.slide_steer_accel, delta)

	# Slope boost: add along downhill direction.
	if _body.is_on_floor():
		var fn := (_ground.floor_normal() if _ground != null else Vector3.UP)
		var downhill := Vector3(0, -1, 0).slide(fn).normalized()
		if downhill.length() > 0.001:
			_body.velocity += downhill * _cfg.slope_slide_boost * delta

	# End slide when timer ends or if player releases crouch/slide.
	if _slide_t <= 0.0 or (not _action_pressed(_cfg.slide_action) and not _action_pressed("slide")):
		_state = MoveState.GROUND if _body.is_on_floor() else MoveState.AIR

func _try_start_dash() -> void:
	if _cfg.dash_charges <= 0:
		return
	if _dash_cd_t > 0.0:
		return
	if _dash_charges <= 0:
		return

	_dash_charges -= 1
	_dash_cd_t = _cfg.dash_cooldown
	_dash_t = _cfg.dash_time
	_state = MoveState.DASH

	var dir := _get_wish_dir()
	if dir == Vector3.ZERO:
		dir = (_look.get_flat_forward() if _look != null else Vector3.FORWARD)
	# Preserve a bit of vertical, but keep dash mainly horizontal.
	var vy := _body.velocity.y
	_body.velocity = dir * _cfg.dash_speed
	_body.velocity.y = vy * 0.25

func _try_start_slide() -> void:
	if not _body.is_on_floor():
		return
	if _state == MoveState.DASH:
		return

	var flat_speed := Vector3(_body.velocity.x, 0.0, _body.velocity.z).length()
	if flat_speed < _cfg.slide_min_speed:
		return

	_slide_t = _cfg.slide_time
	_state = MoveState.SLIDE

func _try_wall_jump() -> void:
	if not _cfg.wall_jump_enabled:
		return
	if _wall_jump_cd_t > 0.0:
		return
	if not _action_just_pressed(_cfg.wall_jump_action):
		return
	if _body.is_on_floor():
		return
	if _wall == null or not _wall.has_wall():
		return

	var n := _wall.wall_normal()
	# Push away from wall + add up
	var push := Vector3(n.x, 0.0, n.z).normalized() * _cfg.wall_jump_push
	_body.velocity.x = push.x
	_body.velocity.z = push.z
	_body.velocity.y = _cfg.wall_jump_up * (_stats.jump_mult if _stats != null else 1.0)

	_wall_jump_cd_t = _cfg.wall_jump_cooldown
	_state = MoveState.AIR
	_coyote_t = 0.0
	_jump_buf_t = 0.0

func _get_wish_dir() -> Vector3:
	var input_vec := Input.get_vector("move_left","move_right","move_forward","move_back")
	var forward_input := input_vec.y < -0.5
	var want_sprint := forward_input and _action_pressed("sprint")
	if input_vec.length() <= 0.001:
		return Vector3.ZERO

	var basis := (_look.get_basis() if _look != null else _body.global_transform.basis)
	var wish := (basis * Vector3(input_vec.x, 0.0, input_vec.y))
	wish.y = 0.0
	return wish.normalized()

# --- Quake-style movement helpers ---

func _apply_friction(delta: float) -> void:
	var v := _body.velocity
	var speed := Vector3(v.x, 0.0, v.z).length()
	if speed < 0.001:
		return

	# If no movement input, apply stronger friction to stop cleanly.
	var wish := _get_wish_dir()
	var control := maxf(speed, _cfg.stop_speed)
	var drop := control * _cfg.ground_friction * delta
	if wish == Vector3.ZERO:
		drop *= 1.35

	var new_speed := maxf(0.0, speed - drop)
	if new_speed == speed:
		return

	var scale := new_speed / speed
	v.x *= scale
	v.z *= scale
	_body.velocity = v

func _apply_slide_friction(delta: float) -> void:
	var v := _body.velocity
	var speed := Vector3(v.x, 0.0, v.z).length()
	if speed < 0.001:
		return

	var drop := speed * _cfg.slide_friction * delta
	var new_speed := maxf(0.0, speed - drop)
	var scale := new_speed / speed
	v.x *= scale
	v.z *= scale
	_body.velocity = v

func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir == Vector3.ZERO or wish_speed <= 0.0:
		return

	var v := _body.velocity
	var current_speed := v.dot(wish_dir)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return

	var accel_speed := accel * wish_speed * delta
	if accel_speed > add_speed:
		accel_speed = add_speed

	v += wish_dir * accel_speed
	_body.velocity = v

func _apply_air_control(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	# Subtle air control when already moving forward-ish.
	if _cfg.air_control <= 0.0:
		return

	var v := _body.velocity
	var v_flat := Vector3(v.x, 0.0, v.z)
	var speed := v_flat.length()
	if speed < 0.001:
		return

	var dot := v_flat.normalized().dot(wish_dir)
	if dot <= 0.0:
		return

	# Steer toward wish_dir a bit.
	var k := _cfg.air_control * dot * dot * delta
	var new_dir := v_flat.normalized().lerp(wish_dir, k).normalized()
	var new_flat := new_dir * speed

	v.x = new_flat.x
	v.z = new_flat.z
	_body.velocity = v

func _clip_velocity_to_plane(v: Vector3, n: Vector3) -> Vector3:
	# Remove component into the plane normal (prevents "micro hops" on slopes).
	var backoff := v.dot(n)
	return v - n * backoff

# --- safe input helpers (won't error if action doesn't exist) ---

func _action_pressed(name_: String) -> bool:
	if not InputMap.has_action(name_):
		return false
	return Input.is_action_pressed(name_)

func _action_just_pressed(name_: String) -> bool:
	if not InputMap.has_action(name_):
		return false
	return Input.is_action_just_pressed(name_)

func _apply_friction_custom(delta: float, friction: float) -> void:
	var v := _body.velocity
	var speed := Vector3(v.x, 0.0, v.z).length()
	if speed < 0.001:
		return

	var control := maxf(speed, _cfg.stop_speed)
	var drop := control * friction * delta

	var new_speed := maxf(0.0, speed - drop)
	var scale := new_speed / speed

	v.x *= scale
	v.z *= scale
	_body.velocity = v
