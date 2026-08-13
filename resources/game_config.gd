class_name GameConfig
extends Resource

@export_category("Traversal")
@export_range(1.0, 60.0, 0.1, "suffix:s") var segment_duration: float = 10.0

@export_category("Player Movement")
@export_range(0.0, 600.0, 1.0, "suffix:px/s") var move_speed: float = 300.0
@export_range(0.1, 1.0, 0.05) var slow_move_speed_mult: float = 0.4

@export_range(0.0, 6000.0, 10.0, "suffix:px/s²") var horizontal_acceleration: float = 3000.0
@export_range(0.0, 6000.0, 10.0, "suffix:px/s²") var horizontal_deceleration: float = 4500.0
@export_range(0.0, 6000.0, 10.0, "suffix:px/s²") var max_speed_deceleration: float = 620
@export_range(0.0, 1.0, 0.01) var air_acc_mult: float = 0.7

@export_range(0.0, 4000.0, 10.0, "suffix:px/s²") var gravity: float = 1800.0
@export_range(-2000.0, 0.0, 1.0, "suffix:px/s") var jump_velocity: float = -620.0
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var terminal_velocity: float = 760.0
@export_range(0.0, 2.0, 0.05) var jump_hang_mult: float = 0.5
@export_range(1.0, 3.0, 0.1) var falling_gravity_mult: float = 1.5

@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time: float = 0.15
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer_time: float = 0.10

@export_range(0.0, 0.5, 0.01, "suffix:s") var lift_boost_memory_time: float = 0.15
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var max_lift_boost_x: float = 800.0
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var max_lift_boost_up: float = 620.0
