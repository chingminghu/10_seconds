extends SceneTree

var _failures: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level_scene: PackedScene = load("res://scenes/levels/level_01.tscn")
	var level: Node = level_scene.instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame

	var controller: RunController = level.get_node("RunController")
	var recorder: RecordingController = level.get_node("RecordingController")
	var player: PlayerController = level.get_node("Player")
	var anchor_b: Anchor = level.get_node("Anchors/AnchorB")

	_expect(controller.state == RunController.RunState.ANCHOR_READY, "Run must begin at ANCHOR_READY.")
	_expect(not player.movement_enabled, "Player movement must begin disabled.")

	Input.action_press(&"play_record")
	await process_frame
	Input.action_release(&"play_record")
	await physics_frame
	_expect(controller.state == RunController.RunState.RECORDING, "Play/Record must start RECORDING.")
	_expect(recorder.is_recording, "RecordingController must capture during RECORDING.")
	_expect(recorder.current_segment.frames.size() >= 2, "Recording must include initial and physics frames.")

	player.teleport_to(anchor_b.get_spawn_transform())
	await physics_frame
	await physics_frame
	_expect(controller.state == RunController.RunState.ANCHOR_READY, "Expected Anchor arrival must return to ANCHOR_READY.")
	_expect(controller.completed_segments.size() == 1, "Successful arrival must store one Segment.")
	_expect(controller.completed_segments[0].start_anchor_id == &"A", "Segment must preserve its start Anchor.")
	_expect(controller.completed_segments[0].end_anchor_id == &"B", "Segment must preserve its end Anchor.")

	Input.action_press(&"play_record")
	await process_frame
	Input.action_release(&"play_record")
	await physics_frame
	Input.action_press(&"retry_current")
	await process_frame
	Input.action_release(&"retry_current")
	_expect(controller.state == RunController.RunState.ATTEMPT_FAILED, "Retry Current must fail the active attempt.")
	_expect(not recorder.is_recording, "A failed attempt must discard the active recording.")
	_expect(controller.completed_segments.size() == 1, "Retry must preserve completed Segment history.")

	await create_timer(0.75).timeout
	_expect(controller.state == RunController.RunState.ANCHOR_READY, "Failed attempt must reset to ANCHOR_READY.")
	_expect(player.global_position.is_equal_approx(anchor_b.get_spawn_transform().origin), "Retry must return player to the current Anchor.")

	level.queue_free()
	await process_frame
	if _failures == 0:
		print("Run flow integration tests passed.")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
