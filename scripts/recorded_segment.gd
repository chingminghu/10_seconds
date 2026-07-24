class_name RecordedSegment
extends Resource

@export var start_anchor_id: StringName = &""
@export var end_anchor_id: StringName = &""
@export var duration: float = 0.0

var frames: Array[RecordedFrame] = []
var events: Array[Variant] = []


func is_valid() -> bool:
	return (
		not start_anchor_id.is_empty()
		and not end_anchor_id.is_empty()
		and frames.size() >= 2
		and duration >= 0.0
	)


func get_first_frame() -> RecordedFrame:
	assert(not frames.is_empty(), "Cannot read the first frame of an empty Segment.")
	return frames[0]


func get_last_frame() -> RecordedFrame:
	assert(not frames.is_empty(), "Cannot read the last frame of an empty Segment.")
	return frames[-1]


func sample_at(sample_time: float) -> RecordedFrame:
	assert(not frames.is_empty(), "Cannot sample an empty Segment.")
	var clamped_time := clampf(sample_time, 0.0, duration)

	if clamped_time <= frames[0].timestamp:
		return frames[0].duplicate_frame()
	if clamped_time >= frames[-1].timestamp:
		return frames[-1].duplicate_frame()

	# Binary search supports non-uniform sample intervals and avoids assuming a
	# particular physics tick rate during playback.
	var lower_index := 0
	var upper_index := frames.size() - 1
	while upper_index - lower_index > 1:
		var middle_index := int((lower_index + upper_index) / 2.0)
		if frames[middle_index].timestamp <= clamped_time:
			lower_index = middle_index
		else:
			upper_index = middle_index

	var lower_frame := frames[lower_index]
	var upper_frame := frames[upper_index]
	var interval := upper_frame.timestamp - lower_frame.timestamp
	var weight := 0.0 if is_zero_approx(interval) else (clamped_time - lower_frame.timestamp) / interval
	return RecordedFrame.interpolate_frames(lower_frame, upper_frame, weight, clamped_time)
