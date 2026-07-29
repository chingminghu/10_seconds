extends SceneTree

const LEVEL_SCENE := preload("res://scenes/levels/level_01.tscn")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	for _tick in 3:
		await physics_frame

	var run_controller := level.get_node("RunController") as RunController
	var anchor_b := level.get_node("Anchors/AnchorB") as Anchor
	var anchor_c := level.get_node("Anchors/AnchorC") as Anchor
	var door := level.get_node("Mechanisms/Door") as Door
	var echo_container := level.get_node("EchoContainer") as Node2D
	var box := level.get_node("Objects/PushableBox") as PushableBox

	assert(run_controller.anchor_progress.size() == 1, "Run must begin with one Anchor progress entry.")
	assert(not run_controller.can_return_to_previous_anchor(), "Start Anchor must not allow rollback.")

	run_controller._start_traversal()
	await physics_frame
	await physics_frame
	box.global_position.x = 250.0
	run_controller._on_anchor_arrived(anchor_b)

	run_controller._start_traversal()
	await physics_frame
	await physics_frame
	box.global_position.x = 300.0
	run_controller._on_anchor_arrived(anchor_c)

	assert(run_controller.anchor_progress.size() == 3, "A→B→C did not create three progress entries.")
	assert(run_controller.completed_segments.size() == 2, "A→B→C did not preserve both Segments.")
	assert(run_controller.can_return_to_previous_anchor(), "Anchor C should allow rollback.")

	run_controller._start_traversal()
	assert(run_controller.state == RunController.RunState.RECORDING, "Final traversal did not start.")
	assert(echo_container.get_child_count() == 1, "Current traversal did not spawn the previous Echo.")
	door.restore_state(true)
	box.global_position.x = 350.0

	run_controller.return_to_previous_anchor()
	await physics_frame
	await physics_frame

	assert(run_controller.state == RunController.RunState.ANCHOR_READY, "Rollback did not return to ANCHOR_READY.")
	assert(run_controller.current_anchor == anchor_b, "Rollback from C did not return to B.")
	assert(run_controller.expected_anchor == anchor_c, "Rollback restored the wrong expected Anchor.")
	assert(run_controller.anchor_progress.size() == 2, "Rollback removed the wrong progress entry.")
	assert(run_controller.completed_segments.size() == 1, "Rollback removed the wrong number of Segments.")
	assert(run_controller.completed_segments[-1].end_anchor_id == &"B", "Rollback did not restore Segment A→B as previous.")
	assert(not run_controller.recording_controller.is_recording, "Rollback preserved an incomplete recording.")
	assert(echo_container.get_child_count() == 0, "Rollback left an active Echo behind.")
	assert(not door.is_open, "Rollback did not restore the previous Anchor mechanism snapshot.")
	assert(is_equal_approx(box.global_position.x, 250.0), "Rollback did not restore the Box to its Anchor B position.")
	assert(box.freeze, "Box must remain frozen while planning at an Anchor.")

	run_controller._start_traversal()
	box.global_position.x = 330.0
	run_controller._fail_attempt()
	for _tick in 45:
		await physics_frame
	assert(run_controller.state == RunController.RunState.ANCHOR_READY, "Failed attempt did not return to ANCHOR_READY.")
	assert(is_equal_approx(box.global_position.x, 250.0), "Failed attempt did not restore the Box attempt position.")
	assert(box.freeze, "Box must remain frozen after a failed attempt.")

	run_controller._start_traversal()
	await physics_frame
	run_controller.return_to_previous_anchor()
	await physics_frame

	assert(run_controller.current_anchor.anchor_id == &"A", "Second rollback did not return to the start Anchor.")
	assert(run_controller.anchor_progress.size() == 1, "Start Anchor history should contain exactly one entry.")
	assert(run_controller.completed_segments.is_empty(), "Returning to A did not remove Segment A→B.")
	assert(not run_controller.can_return_to_previous_anchor(), "Rollback must be disabled at the start Anchor.")

	print("Rollback smoke test passed: history pop, Segment restore, snapshot restore, and recording cleanup.")
	level.queue_free()
	await physics_frame
	quit(0)
