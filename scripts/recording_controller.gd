class_name RecordingController
extends Node

signal recording_started(segment: RecordedSegment)
signal recording_discarded
signal recording_completed(segment: RecordedSegment)
signal frame_recorded(frame_count: int)

@export var state_source: RecordableTransformSource
@export_range(1.0, 60.0, 0.1, "suffix:s") var maximum_duration: float = 10.0

var is_recording: bool = false
var elapsed_time: float = 0.0
var current_segment: RecordedSegment


func _ready() -> void:
	assert(state_source != null, "RecordingController requires a RecordableTransformSource.")


func _physics_process(delta: float) -> void:
	if not is_recording:
		return
	elapsed_time = minf(elapsed_time + delta, maximum_duration)
	_append_frame(elapsed_time)


func start_recording(start_anchor_id: StringName) -> void:
	assert(not is_recording, "Cannot start a recording while another recording is active.")
	assert(not start_anchor_id.is_empty(), "A recording requires a start Anchor ID.")

	current_segment = RecordedSegment.new()
	current_segment.start_anchor_id = start_anchor_id
	elapsed_time = 0.0
	is_recording = true
	_append_frame(0.0)
	recording_started.emit(current_segment)


func complete_recording(end_anchor_id: StringName) -> RecordedSegment:
	assert(is_recording, "Cannot complete a recording when none is active.")
	assert(not end_anchor_id.is_empty(), "A completed recording requires an end ID.")

	is_recording = false
	current_segment.end_anchor_id = end_anchor_id
	current_segment.duration = elapsed_time
	_ensure_exact_final_frame()

	var completed_segment := current_segment
	current_segment = null
	assert(completed_segment.is_valid(), "A completed Segment must contain valid endpoints and frames.")
	recording_completed.emit(completed_segment)
	return completed_segment


func discard_recording() -> void:
	if not is_recording:
		return
	is_recording = false
	elapsed_time = 0.0
	current_segment = null
	recording_discarded.emit()


func _append_frame(timestamp: float) -> void:
	var frame := state_source.capture_frame(timestamp)
	current_segment.frames.append(frame)
	frame_recorded.emit(current_segment.frames.size())


func _ensure_exact_final_frame() -> void:
	var final_frame := state_source.capture_frame(elapsed_time)
	var frames := current_segment.frames
	if not frames.is_empty() and is_equal_approx(frames[-1].timestamp, elapsed_time):
		frames[-1] = final_frame
	else:
		frames.append(final_frame)
