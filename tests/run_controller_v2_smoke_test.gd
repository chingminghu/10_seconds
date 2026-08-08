extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ANCHOR_SCENE := preload("res://scenes/anchor/anchor.tscn")
const ORB_SCENE := preload("res://scenes/objects/orb.tscn")
const GOAL_SCENE := preload("res://scenes/goal/goal.tscn")
const ECHO_SCENE := preload("res://scenes/echo/echo.tscn")
const GAME_CONFIG := preload("res://resources/game_config.tres")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var level := Node2D.new()
	root.add_child(level)

	var test_config := GAME_CONFIG.duplicate() as GameConfig
	test_config.gravity = 0.0
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.config = test_config
	level.add_child(player)

	var anchor := ANCHOR_SCENE.instantiate() as Anchor
	anchor.anchor_id = &"SPAWN"
	anchor.global_position = Vector2(100.0, 300.0)
	level.add_child(anchor)

	var objects_root := Node2D.new()
	objects_root.name = "Objects"
	level.add_child(objects_root)
	var orb := ORB_SCENE.instantiate() as Orb
	orb.global_position = Vector2(400.0, 300.0)
	orb.renewable_time = 0.05
	objects_root.add_child(orb)

	var goal := GOAL_SCENE.instantiate() as LevelGoal
	goal.global_position = Vector2(800.0, 300.0)
	level.add_child(goal)

	var echo_container := Node2D.new()
	echo_container.name = "EchoContainer"
	level.add_child(echo_container)

	var recorder := RecordingController.new()
	recorder.state_source = player.get_node("RecordableTransformSource") as RecordableTransformSource
	level.add_child(recorder)

	var snapshots := SnapshotController.new()
	snapshots.snapshot_root = level
	level.add_child(snapshots)

	var controller := RunControllerV2.new()
	controller.player = player
	controller.spawn_anchor = anchor
	controller.orbs_root = objects_root
	controller.goal = goal
	controller.recording_controller = recorder
	controller.config = test_config
	controller.echo_scene = ECHO_SCENE
	controller.echo_container = echo_container
	controller.snapshot_controller = snapshots
	controller.recording_capacity = 1
	controller.starting_recording_charges = 0
	level.add_child(controller)
	await process_frame
	await physics_frame

	assert(player.movement_enabled, "V2 must enable movement without waiting at an Anchor.")
	assert(
		player.global_transform.is_equal_approx(anchor.get_spawn_transform()),
		"V2 did not use its Anchor exclusively as the Player spawn point."
	)
	assert(controller.recording_charges == 0, "V2 used the wrong starting charge count.")
	anchor.body_entered.emit(player)
	assert(controller.recording_charges == 0, "The spawn Anchor still granted a recording charge.")

	orb._on_body_entered(player)
	assert(controller.recording_charges == 1, "Touching an Orb did not grant its recording charge.")
	assert(not orb.is_active, "A successfully touched Orb did not enter cooldown.")

	orb._physics_process(0.04)
	assert(not orb.is_active, "The Orb renewed before renewable_time elapsed.")
	orb._physics_process(0.01)
	assert(orb.is_active, "The Orb did not renew after renewable_time elapsed.")
	orb._on_body_entered(player)
	assert(controller.recording_charges == 1, "A full charge inventory exceeded its capacity.")
	assert(orb.is_active, "A full charge inventory incorrectly triggered Orb.touched().")

	assert(controller.start_recording(), "J-equivalent recording start was rejected.")
	assert(controller.recording_charges == 0, "Starting a recording did not consume its charge.")
	assert(controller.recording_queue.size() == 1, "Recording start did not push into the fixed queue.")
	orb._on_body_entered(player)
	assert(controller.recording_charges == 1, "An Orb did not grant a charge after capacity became available.")
	assert(not orb.is_active, "The granted Orb charge did not start cooldown.")
	await physics_frame
	assert(controller.stop_recording(), "J-equivalent recording stop was rejected.")
	assert(controller.recording_queue.peek_front().is_valid(), "Manual stop did not finalize the queued Segment.")

	assert(controller.start_playback(), "K-equivalent playback was rejected.")
	assert(controller.recording_queue.is_empty(), "Playback did not pop the FIFO queue front.")
	assert(echo_container.get_child_count() == 1, "Playback did not spawn an Echo.")

	controller.reset_all()
	for _tick in 3:
		await physics_frame
	await process_frame
	assert(not controller.is_resetting, "R-equivalent full reset did not finish.")
	assert(controller.recording_queue.is_empty(), "Full reset did not clear the recording queue.")
	assert(controller.recording_charges == 0, "Full reset did not restore starting charges.")
	assert(echo_container.get_child_count() == 0, "Full reset left an Echo behind.")
	assert(orb.is_active, "Full reset did not restore the Orb's initial active state.")
	orb._on_body_entered(player)
	assert(controller.recording_charges == 1, "The restored Orb did not grant a recording charge.")
	controller.maximum_recording_duration = 0.05
	recorder.maximum_duration = 0.05
	assert(controller.start_recording(), "Post-reset recording was rejected.")
	recorder._physics_process(0.05)
	assert(not recorder.is_recording, "Recording did not stop automatically at its duration limit.")
	assert(
		is_equal_approx(controller.recording_queue.peek_front().duration, 0.05),
		"Automatically stopped recording has the wrong duration."
	)

	print("RunControllerV2 smoke test passed: Orb charge, spawn Anchor, J/K/R flow, and automatic stop.")
	level.queue_free()
	await process_frame
	quit(0)
