class_name PlaybackController
extends Node

signal playback_started(segment: RecordedSegment)
signal playback_time_changed(playback_time: float, duration: float)
signal playback_motion_applied(motion: Vector2, delta: float)
signal playback_finished

@export var playback_target: Node2D

var is_playing: bool = false
var playback_time: float = 0.0
var _segment: RecordedSegment


func _ready() -> void:
	assert(playback_target != null, "PlaybackController requires a Node2D playback_target.")


func play_reverse(segment: RecordedSegment) -> void:
	assert(segment != null and segment.is_valid(), "Playback requires a valid RecordedSegment.")
	_segment = segment
	playback_time = segment.duration
	is_playing = true
	_apply_frame(_segment.get_last_frame())
	playback_started.emit(segment)
	playback_time_changed.emit(playback_time, _segment.duration)


func stop() -> void:
	is_playing = false
	_segment = null
	playback_time = 0.0


func _physics_process(delta: float) -> void:
	if not is_playing:
		return

	# Snap before sampling when this tick consumes the remaining duration. This
	# guarantees the exact first frame despite accumulated floating-point error.
	var reaches_start := playback_time <= delta or is_equal_approx(playback_time, delta)
	playback_time = 0.0 if reaches_start else playback_time - delta
	var previous_position := playback_target.global_position
	_apply_frame(_segment.sample_at(playback_time))
	playback_motion_applied.emit(playback_target.global_position - previous_position, delta)
	playback_time_changed.emit(playback_time, _segment.duration)

	if playback_time == 0.0:
		is_playing = false
		playback_finished.emit()


func _apply_frame(frame: RecordedFrame) -> void:
	playback_target.global_position = frame.global_position
	playback_target.global_rotation = frame.rotation
	if playback_target.has_method(&"apply_recorded_presentation"):
		playback_target.call(&"apply_recorded_presentation", frame)
