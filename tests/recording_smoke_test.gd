extends SceneTree

const RecordableSourceScript := preload("res://scripts/recordable_transform_source.gd")
const RecordingControllerScript := preload("res://scripts/recording_controller.gd")
const PlaybackControllerScript := preload("res://scripts/playback_controller.gd")


func _initialize() -> void:
	var root_node := Node.new()
	root.add_child(root_node)

	var target := Node2D.new()
	root_node.add_child(target)

	var source: RecordableTransformSource = RecordableSourceScript.new()
	source.target = target
	source.facing_property = &""
	root_node.add_child(source)

	var recorder: RecordingController = RecordingControllerScript.new()
	recorder.state_source = source
	recorder.maximum_duration = 10.0
	root_node.add_child(recorder)

	recorder.start_recording(&"A")
	for tick in 60:
		target.global_position = Vector2(float(tick + 1), 0.0)
		recorder._physics_process(1.0 / 60.0)

	var segment := recorder.complete_recording(&"B")
	assert(segment.is_valid(), "Smoke test produced an invalid Segment.")
	assert(segment.frames.size() == 61, "Expected one initial frame plus 60 physics samples.")
	assert(is_equal_approx(segment.duration, 1.0), "One second of samples must produce a one-second Segment.")
	assert(segment.get_first_frame().global_position == Vector2.ZERO, "The initial transform was not captured.")
	assert(segment.get_last_frame().global_position == Vector2(60.0, 0.0), "The final transform was not captured.")

	var playback_target := Node2D.new()
	root_node.add_child(playback_target)
	var playback: PlaybackController = PlaybackControllerScript.new()
	playback.playback_target = playback_target
	root_node.add_child(playback)

	playback.play_reverse(segment)
	assert(playback_target.global_position == Vector2(60.0, 0.0), "Reverse playback must start at the final frame.")
	playback._physics_process(0.5)
	assert(playback_target.global_position.is_equal_approx(Vector2(30.0, 0.0)), "Timestamp interpolation produced the wrong midpoint.")
	playback._physics_process(0.5)
	assert(playback_target.global_position == Vector2.ZERO, "Reverse playback must end at the initial frame.")
	assert(not playback.is_playing, "Reverse playback must stop instead of looping.")

	print("Recording and playback smoke test passed: %d frames, %.3f seconds." % [segment.frames.size(), segment.duration])
	quit(0)
