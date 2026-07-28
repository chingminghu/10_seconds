extends SceneTree

const BOX_SCENE := preload("res://scenes/objects/pushable_box.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ECHO_SCENE := preload("res://scenes/echo/echo.tscn")
const SNAPSHOT_CONTROLLER_SCRIPT := preload("res://scripts/snapshot_controller.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var test_root := Node2D.new()
	root.add_child(test_root)
	_add_floor(test_root)

	var box := BOX_SCENE.instantiate() as PushableBox
	box.global_position = Vector2(200.0, 100.0)
	test_root.add_child(box)
	box.begin_attempt()

	for _tick in 50:
		await physics_frame
	assert(absf(box.global_position.y - 280.0) < 1.0, "Box did not fall and settle on the floor.")
	box.end_attempt()

	var snapshots: SnapshotController = SNAPSHOT_CONTROLLER_SCRIPT.new()
	snapshots.snapshot_root = test_root
	test_root.add_child(snapshots)
	await physics_frame
	var settled_snapshot := snapshots.capture_snapshot()
	box.begin_attempt()

	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.global_position = Vector2(140.0, 300.0)
	player.set_movement_enabled(true)
	test_root.add_child(player)
	Input.action_press(&"move_right")
	for _tick in 50:
		await physics_frame
	Input.action_release(&"move_right")

	assert(box.global_position.x > 220.0, "Player did not push the Box.")

	player.teleport_to(Transform2D(0.0, Vector2(80.0, 300.0)))
	snapshots.restore_snapshot(settled_snapshot)
	for _tick in 3:
		await physics_frame
	assert(
		box.global_position.distance_to(Vector2(200.0, 280.0)) < 1.0,
		"Snapshot did not restore the Box transform."
	)
	box.begin_attempt()

	var echo := ECHO_SCENE.instantiate() as Echo
	test_root.add_child(echo)
	echo.play_segment_reverse(
		_make_horizontal_segment(
			Vector2(280.0, 300.0),
			Vector2(150.0, 300.0),
			1.0
		)
	)
	for _tick in 45:
		await physics_frame

	assert(box.global_position.x > 230.0, "Echo did not push the Box.")
	var box_position_after_echo_push: Vector2 = box.global_position

	for _tick in 18:
		await physics_frame
	assert(
		echo.global_position.is_equal_approx(Vector2(280.0, 300.0)),
		"Pushing the Box changed the Echo's authoritative trajectory."
	)

	print(
		"Pushable Box smoke test passed: gravity, Player push, Echo push, snapshot restore. Echo push ended at %s." %
		box_position_after_echo_push
	)
	test_root.queue_free()
	await physics_frame
	quit(0)


func _add_floor(parent: Node2D) -> void:
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(500.0, 40.0)
	floor_shape.position = Vector2(250.0, 320.0)
	floor_shape.shape = floor_rectangle
	floor_body.add_child(floor_shape)
	parent.add_child(floor_body)


func _make_horizontal_segment(start_position: Vector2, end_position: Vector2, duration: float) -> RecordedSegment:
	var segment := RecordedSegment.new()
	segment.start_anchor_id = &"TEST_START"
	segment.end_anchor_id = &"TEST_END"
	segment.duration = duration

	var first_frame := RecordedFrame.new()
	first_frame.timestamp = 0.0
	first_frame.global_position = start_position
	segment.frames.append(first_frame)

	var last_frame := RecordedFrame.new()
	last_frame.timestamp = duration
	last_frame.global_position = end_position
	segment.frames.append(last_frame)
	return segment
