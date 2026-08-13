class_name PlayerController
extends CharacterBody2D

@export var config: GameConfig
@export_range(0.0, 5000.0, 50.0, "suffix:N") var box_push_force: float = 1800.0

@export_category("Lift Boost")


var movement_enabled: bool = false
var facing_direction: int = 1
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _movement_input_axis: float = 0.0
var _stored_lift_velocity: Vector2 = Vector2.ZERO
var _lift_boost_memory_timer: float = 0.0
var _skip_lift_boost_capture_once: bool = false
var is_jumping: bool = false

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group(&"player")
	assert(config != null, "PlayerController requires a GameConfig resource.")
	# Lift boost is applied explicitly by _try_jump(); prevent CharacterBody2D from
	# adding the platform velocity a second time when the player leaves it.
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING


func _unhandled_input(event: InputEvent) -> void:
	if movement_enabled and event.is_action_pressed(&"jump"):
		_jump_buffer_timer = config.jump_buffer_time


func _physics_process(delta: float) -> void:
	_update_lift_boost_memory(delta)

	if is_on_floor():
		_coyote_timer = config.coyote_time
		is_jumping = false
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	_apply_verticle_movement(delta)

	if movement_enabled:
		_apply_horizontal_movement(delta)
		_try_jump()
	else:
		velocity.x = move_toward(velocity.x, 0.0, config.horizontal_deceleration * delta)
		_jump_buffer_timer = 0.0

	move_and_slide()
	_push_rigid_bodies()


func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		_jump_buffer_timer = 0.0


func teleport_to(target_transform: Transform2D) -> void:
	global_transform = target_transform
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_clear_lift_boost()
	_skip_lift_boost_capture_once = true


func _apply_horizontal_movement(delta: float) -> void:
	var input_axis := Input.get_axis(&"move_left", &"move_right")
	_movement_input_axis = input_axis
	var speed_mult := config.slow_move_speed_mult if Input.is_action_pressed(&"slow_move") else 1.0
	var target_speed := input_axis * config.move_speed * speed_mult
	var rate := config.horizontal_acceleration if not is_zero_approx(input_axis) else config.horizontal_deceleration
	var air_control = 1.0 if is_on_floor() else config.air_acc_mult

	if abs(velocity.x) > config.move_speed and sign(velocity.x) == sign(input_axis):
		rate = config.max_speed_deceleration

	velocity.x = move_toward(velocity.x, target_speed, rate * air_control * delta)

	if not is_zero_approx(input_axis):
		facing_direction = 1 if input_axis > 0.0 else -1
		_visual.scale.x = float(facing_direction)


func _apply_verticle_movement(delta:float) -> void:
	var gravity_mult := 1.0

	if velocity.y >= 0:
		gravity_mult *= config.falling_gravity_mult
	if (velocity.y) < 0.0 and is_jumping and Input.is_action_just_released(&"jump"):
		velocity.y *= config.jump_hang_mult
	#if is_jumping and abs(velocity.y) <= 50.0:
		#gravity_mult *= config.jump_hang_mult

	velocity.y = move_toward(velocity.y, config.terminal_velocity, config.gravity * gravity_mult * delta)


func _push_rigid_bodies() -> void:
	if not movement_enabled or is_zero_approx(_movement_input_axis):
		return

	var pushed_instance_ids: Dictionary = {}
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var rigid_body := collision.get_collider() as RigidBody2D
		if rigid_body == null or absf(collision.get_normal().x) < 0.5:
			continue
		if pushed_instance_ids.has(rigid_body.get_instance_id()):
			continue

		pushed_instance_ids[rigid_body.get_instance_id()] = true
		rigid_body.apply_central_force(Vector2(signf(_movement_input_axis) * box_push_force, 0.0))


func _update_lift_boost_memory(delta: float) -> void:
	# is_on_floor() and get_platform_velocity() describe the previous move_and_slide().
	# Only a moving floor refreshes the memory, so a platform stopping does not erase
	# the momentum on the exact frame the player tries to jump.
	if _skip_lift_boost_capture_once:
		_skip_lift_boost_capture_once = false
		return

	if is_on_floor():
		var platform_velocity := get_platform_velocity()
		if not platform_velocity.is_zero_approx():
			_stored_lift_velocity = platform_velocity
			_lift_boost_memory_timer = config.lift_boost_memory_time
			return

	_lift_boost_memory_timer = maxf(_lift_boost_memory_timer - delta, 0.0)
	if is_zero_approx(_lift_boost_memory_timer):
		_stored_lift_velocity = Vector2.ZERO


func _consume_lift_boost() -> Vector2:
	if _lift_boost_memory_timer <= 0.0:
		return Vector2.ZERO

	var lift_boost := Vector2(
		clampf(_stored_lift_velocity.x, -config.max_lift_boost_x, config.max_lift_boost_x),
		clampf(_stored_lift_velocity.y, -config.max_lift_boost_up, 0.0)
	)
	_clear_lift_boost()
	return lift_boost


func _clear_lift_boost() -> void:
	_stored_lift_velocity = Vector2.ZERO
	_lift_boost_memory_timer = 0.0


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return

	var lift_boost := _consume_lift_boost()
	velocity.x += lift_boost.x
	velocity.y = config.jump_velocity + lift_boost.y
	#print("velocity: ", [velocity.x, velocity.y])
	is_jumping = true
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
