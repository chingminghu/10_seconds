extends SceneTree

var _failures: int = 0


func _init() -> void:
	_test_recorded_frame_copy()
	_test_recorded_segment_validation()
	_test_transform_source_capture()
	if _failures == 0:
		print("Recording data tests passed.")
	quit(_failures)


func _test_recorded_frame_copy() -> void:
	var source := RecordedFrame.new()
	source.timestamp = 1.25
	source.global_position = Vector2(12.0, 34.0)
	source.facing_direction = -1
	var copy := source.duplicate_frame()
	_expect(copy != source, "Frame copy must be a distinct object.")
	_expect(copy.timestamp == source.timestamp, "Frame copy must preserve timestamp.")
	_expect(copy.global_position == source.global_position, "Frame copy must preserve position.")
	_expect(copy.facing_direction == source.facing_direction, "Frame copy must preserve facing.")


func _test_recorded_segment_validation() -> void:
	var segment := RecordedSegment.new()
	_expect(not segment.is_valid(), "An empty Segment must be invalid.")
	segment.start_anchor_id = &"A"
	segment.end_anchor_id = &"B"
	segment.frames.append(RecordedFrame.new())
	_expect(segment.is_valid(), "A populated Segment must be valid.")


func _test_transform_source_capture() -> void:
	var target := Node2D.new()
	target.global_position = Vector2(50.0, 75.0)
	target.global_rotation = 0.5
	var source := RecordableTransformSource.new()
	source.target = target
	source.facing_property = &""
	var frame := source.capture_frame(2.0)
	_expect(frame.timestamp == 2.0, "Captured frame must preserve its timestamp.")
	_expect(frame.global_position == target.global_position, "Captured frame must use the target position.")
	_expect(frame.rotation == target.global_rotation, "Captured frame must use the target rotation.")
	target.free()
	source.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
