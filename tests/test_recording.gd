extends SceneTree

var _failures: int = 0


func _init() -> void:
	_test_recorded_frame_copy()
	_test_recorded_frame_interpolation()
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
	source.visual_scale = Vector2(-1.0, 1.2)
	var copy := source.duplicate_frame()
	_expect(copy != source, "Frame copy must be a distinct object.")
	_expect(copy.timestamp == source.timestamp, "Frame copy must preserve timestamp.")
	_expect(copy.global_position == source.global_position, "Frame copy must preserve position.")
	_expect(copy.facing_direction == source.facing_direction, "Frame copy must preserve facing.")
	_expect(copy.visual_scale == source.visual_scale, "Frame copy must preserve Visual scale.")


func _test_recorded_frame_interpolation() -> void:
	var from := RecordedFrame.new()
	from.visual_scale = Vector2(1.0, 0.75)
	var to := RecordedFrame.new()
	to.facing_direction = -1
	to.visual_scale = Vector2(-1.0, 1.25)

	var early := RecordedFrame.interpolate_frames(from, to, 0.25, 0.25)
	_expect(early.visual_scale.x == 1.0, "Visual facing scale must remain discrete before midpoint.")
	_expect(is_equal_approx(early.visual_scale.y, 0.875), "Visual Y scale must interpolate smoothly.")
	var late := RecordedFrame.interpolate_frames(from, to, 0.75, 0.75)
	_expect(late.visual_scale.x == -1.0, "Visual facing scale must switch at midpoint.")
	_expect(is_equal_approx(late.visual_scale.y, 1.125), "Visual Y scale interpolation is incorrect.")


func _test_recorded_segment_validation() -> void:
	var segment := RecordedSegment.new()
	_expect(not segment.is_valid(), "An empty Segment must be invalid.")
	segment.start_anchor_id = &"A"
	segment.end_anchor_id = &"B"
	segment.frames.append(RecordedFrame.new())
	segment.frames.append(RecordedFrame.new())
	_expect(segment.is_valid(), "A populated Segment must be valid.")


func _test_transform_source_capture() -> void:
	var target := Node2D.new()
	target.global_position = Vector2(50.0, 75.0)
	target.global_rotation = 0.5
	target.scale = Vector2(-1.0, 1.25)
	var source := RecordableTransformSource.new()
	source.target = target
	source.visual_target = target
	source.facing_property = &""
	var frame := source.capture_frame(2.0)
	_expect(frame.timestamp == 2.0, "Captured frame must preserve its timestamp.")
	_expect(frame.global_position == target.global_position, "Captured frame must use the target position.")
	_expect(frame.rotation == target.global_rotation, "Captured frame must use the target rotation.")
	_expect(frame.visual_scale == target.scale, "Captured frame must use the Visual scale.")
	target.free()
	source.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
