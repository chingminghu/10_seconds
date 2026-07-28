class_name Echo
extends AnimatableBody2D

signal playback_completed(echo: Echo)

@export_range(0.0, 5000.0, 50.0, "suffix:N") var box_push_force: float = 1800.0

@onready var _visual: Polygon2D = $Visual
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _playback_controller: PlaybackController = $PlaybackController
@onready var _box_interaction_area: Area2D = $BoxInteractionArea


func _ready() -> void:
	_playback_controller.playback_finished.connect(_on_playback_finished)
	_playback_controller.playback_motion_applied.connect(_on_playback_motion_applied)


func play_segment_reverse(segment: RecordedSegment) -> void:
	show()
	_playback_controller.play_reverse(segment)
	_collision_shape.set_deferred(&"disabled", false)


func stop_playback() -> void:
	_playback_controller.stop()
	_collision_shape.set_deferred(&"disabled", true)
	hide()


func apply_recorded_presentation(frame: RecordedFrame) -> void:
	_visual.scale.x = float(frame.facing_direction)


func _on_playback_motion_applied(motion: Vector2, _delta: float) -> void:
	if is_zero_approx(motion.x):
		return

	var push_force := Vector2(signf(motion.x) * box_push_force, 0.0)
	for body in _box_interaction_area.get_overlapping_bodies():
		if body is RigidBody2D:
			(body as RigidBody2D).apply_central_force(push_force)


func _on_playback_finished() -> void:
	_collision_shape.set_deferred(&"disabled", true)
	hide()
	playback_completed.emit(self)
