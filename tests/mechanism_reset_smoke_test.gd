extends SceneTree

const PLATE_SCENE := preload("res://scenes/mechanisms/pressure_plate.tscn")
const DOOR_SCENE := preload("res://scenes/mechanisms/door.tscn")
const ECHO_SCENE := preload("res://scenes/echo/echo.tscn")
const SNAPSHOT_CONTROLLER_SCRIPT := preload("res://scripts/snapshot_controller.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var test_root := Node2D.new()
	root.add_child(test_root)

	var plate := PLATE_SCENE.instantiate() as PressurePlate
	plate.global_position = Vector2(100.0, 200.0)
	test_root.add_child(plate)

	var door := DOOR_SCENE.instantiate() as Door
	door.pressure_plate = plate
	test_root.add_child(door)

	var snapshots: SnapshotController = SNAPSHOT_CONTROLLER_SCRIPT.new()
	snapshots.snapshot_root = test_root
	test_root.add_child(snapshots)
	await physics_frame

	var neutral_snapshot := snapshots.capture_snapshot()
	assert(neutral_snapshot.object_states.size() == 2, "Snapshot did not capture both resettable mechanisms.")
	assert(not plate.is_active and not door.is_open, "Mechanisms must begin in their neutral state.")

	var echo := ECHO_SCENE.instantiate() as Echo
	test_root.add_child(echo)
	echo.play_segment_reverse(_make_stationary_segment(Vector2(100.0, 200.0)))
	for _tick in 3:
		await physics_frame

	assert(plate.is_active, "Echo collision did not activate the PressurePlate.")
	assert(door.is_open, "PressurePlate activation did not open the Door.")

	echo.stop_playback()
	echo.global_position = Vector2(300.0, 200.0)
	snapshots.restore_snapshot(neutral_snapshot)
	for _tick in 2:
		await physics_frame

	assert(not plate.is_active, "PressurePlate did not restore to its captured state.")
	assert(not door.is_open, "Door did not restore to its captured state.")
	assert(not door.get_node("CollisionShape2D").disabled, "Closed Door collision was not restored.")

	print("Mechanism reset smoke test passed: Echo activation, Door response, and snapshot restore.")
	test_root.queue_free()
	await physics_frame
	quit(0)


func _make_stationary_segment(position: Vector2) -> RecordedSegment:
	var segment := RecordedSegment.new()
	segment.start_anchor_id = &"TEST_START"
	segment.end_anchor_id = &"TEST_END"
	segment.duration = 1.0

	var first_frame := RecordedFrame.new()
	first_frame.timestamp = 0.0
	first_frame.global_position = position
	segment.frames.append(first_frame)

	var last_frame := first_frame.duplicate_frame()
	last_frame.timestamp = 1.0
	segment.frames.append(last_frame)
	return segment

