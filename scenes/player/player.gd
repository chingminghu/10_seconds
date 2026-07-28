class_name PlayerController
extends CharacterBody2D

@export var config: GameConfig
@export_range(0.0, 5000.0, 50.0, "suffix:N") var box_push_force: float = 1800.0

var movement_enabled: bool = false
var facing_direction: int = 1
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _movement_input_axis: float = 0.0

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group(&"player")
	assert(config != null, "PlayerController requires a GameConfig resource.")


func _unhandled_input(event: InputEvent) -> void:
	if movement_enabled and event.is_action_pressed(&"jump"):
		_jump_buffer_timer = config.jump_buffer_time


func _physics_process(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = config.coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	velocity.y += config.gravity * delta

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


func _apply_horizontal_movement(delta: float) -> void:
	var input_axis := Input.get_axis(&"move_left", &"move_right")
	_movement_input_axis = input_axis
	var speed_multiplier := config.slow_move_speed_multiplier if Input.is_action_pressed(&"slow_move") else 1.0
	var target_speed := input_axis * config.move_speed * speed_multiplier
	var rate := config.horizontal_acceleration if not is_zero_approx(input_axis) else config.horizontal_deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	if not is_zero_approx(input_axis):
		facing_direction = 1 if input_axis > 0.0 else -1
		_visual.scale.x = float(facing_direction)


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


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return

	velocity.y = config.jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
