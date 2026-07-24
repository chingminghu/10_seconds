class_name Echo
extends AnimatableBody2D

signal playback_completed(echo: Echo)

@onready var _visual: Polygon2D = $Visual
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _playback_controller: PlaybackController = $PlaybackController


func _ready() -> void:
	_playback_controller.playback_finished.connect(_on_playback_finished)


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


func _on_playback_finished() -> void:
	_collision_shape.set_deferred(&"disabled", true)
	hide()
	playback_completed.emit(self)
