class_name PushableBox
extends RigidBody2D

@export_range(20.0, 600.0, 10.0, "suffix:px/s") var maximum_horizontal_speed: float = 180.0


func _ready() -> void:
	add_to_group(&"resettable")


func begin_attempt() -> void:
	freeze = false
	sleeping = false


func end_attempt() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity := state.linear_velocity
	velocity.x = clampf(velocity.x, -maximum_horizontal_speed, maximum_horizontal_speed)
	state.linear_velocity = velocity


func capture_state() -> Variant:
	return {
		&"global_transform": global_transform,
		&"linear_velocity": linear_velocity,
		&"angular_velocity": angular_velocity,
		&"sleeping": sleeping,
		&"freeze": freeze,
	}


func restore_state(state: Variant) -> void:
	assert(state is Dictionary, "PushableBox state must be a Dictionary.")
	var box_state: Dictionary = state
	# Freezing before teleporting prevents the physics server from overwriting
	# the restored transform on the next integration step.
	freeze = true
	global_transform = box_state[&"global_transform"]
	linear_velocity = box_state[&"linear_velocity"]
	angular_velocity = box_state[&"angular_velocity"]
	sleeping = box_state[&"sleeping"]
	freeze = box_state.get(&"freeze", true)
