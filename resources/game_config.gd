class_name GameConfig
extends Resource

@export_category("Traversal")
@export_range(1.0, 60.0, 0.1, "suffix:s") var segment_duration: float = 10.0

@export_category("Player Movement")
@export_range(0.0, 600.0, 1.0, "suffix:px/s") var move_speed: float = 220.0
@export_range(0.0, 3000.0, 10.0, "suffix:px/s²") var horizontal_acceleration: float = 1800.0
@export_range(0.0, 3000.0, 10.0, "suffix:px/s²") var horizontal_deceleration: float = 2200.0
@export_range(-1000.0, 0.0, 1.0, "suffix:px/s") var jump_velocity: float = -500.0
@export_range(0.0, 4000.0, 10.0, "suffix:px/s²") var gravity: float = 1200.0
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time: float = 0.10
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer_time: float = 0.10
