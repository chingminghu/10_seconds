extends SceneTree

const PLATE_SCENE := preload("res://scenes/mechanisms/pressure_plate.tscn")
const DOOR_SCENE := preload("res://scenes/mechanisms/door.tscn")
const TOGGLE_PAD_SCENE := preload("res://scenes/mechanisms/toggle_pad.tscn")
const GATE_SCENE := preload("res://scenes/mechanisms/gate.tscn")
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
	var second_plate := PLATE_SCENE.instantiate() as PressurePlate
	second_plate.global_position = Vector2(100.0, 200.0)
	test_root.add_child(second_plate)

	var door := DOOR_SCENE.instantiate() as Door
	door.pressure_plates.append(plate)
	door.pressure_plates.append(second_plate)
	test_root.add_child(door)

	# Add the Gate before its TogglePad so snapshot restoration exercises the
	# dependency order that previously reopened an already-restored Gate.
	var toggle_pad := TOGGLE_PAD_SCENE.instantiate() as TogglePad
	var second_toggle_pad := TOGGLE_PAD_SCENE.instantiate() as TogglePad
	var gate := GATE_SCENE.instantiate() as Gate
	gate.toggle_pads.append(toggle_pad)
	gate.toggle_pads.append(second_toggle_pad)
	test_root.add_child(gate)
	test_root.add_child(toggle_pad)
	test_root.add_child(second_toggle_pad)

	var snapshots: SnapshotController = SNAPSHOT_CONTROLLER_SCRIPT.new()
	snapshots.snapshot_root = test_root
	test_root.add_child(snapshots)
	await physics_frame

	var neutral_snapshot := snapshots.capture_snapshot()
	assert(neutral_snapshot.object_states.size() == 6, "Snapshot did not capture all resettable mechanisms.")
	assert(not plate.is_active and not second_plate.is_active and not door.is_open, "Plates and Door must begin neutral.")
	assert(
		not toggle_pad.was_pressed and not second_toggle_pad.was_pressed and not gate.is_open,
		"TogglePads and Gate must begin neutral."
	)

	var echo := ECHO_SCENE.instantiate() as Echo
	test_root.add_child(echo)
	echo.play_segment_reverse(_make_stationary_segment(Vector2(100.0, 200.0)))
	for _tick in 3:
		await physics_frame

	assert(plate.is_active and second_plate.is_active, "Echo collision did not activate both PressurePlates.")
	assert(door.is_open, "All-active PressurePlate rule did not open the Door.")
	toggle_pad.toggled.emit()
	assert(gate.is_open, "The first TogglePad did not open the Gate.")
	second_toggle_pad.toggled.emit()
	assert(not gate.is_open, "The second TogglePad did not toggle the Gate closed.")
	toggle_pad.toggled.emit()
	assert(gate.is_open, "The first TogglePad did not toggle the Gate a second time.")

	echo.stop_playback()
	echo.global_position = Vector2(300.0, 200.0)
	snapshots.restore_snapshot(neutral_snapshot)
	for _tick in 2:
		await physics_frame

	assert(not plate.is_active, "PressurePlate did not restore to its captured state.")
	assert(not second_plate.is_active, "Second PressurePlate did not restore to its captured state.")
	assert(not door.is_open, "Door did not restore to its captured state.")
	assert(not door.get_node("CollisionShape2D").disabled, "Closed Door collision was not restored.")
	assert(not toggle_pad.was_pressed, "TogglePad did not restore to its captured state.")
	assert(not second_toggle_pad.was_pressed, "Second TogglePad did not restore to its captured state.")
	assert(not gate.is_open, "Gate was toggled again while restoring its TogglePad.")
	assert(not gate.get_node("CollisionShape2D").disabled, "Closed Gate collision was not restored.")

	print("Mechanism reset smoke test passed: Door and Gate state restore is order-independent.")
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
