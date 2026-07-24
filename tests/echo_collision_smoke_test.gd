extends SceneTree

const ECHO_SCENE := preload("res://scenes/echo/echo.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var test_root := Node2D.new()
	root.add_child(test_root)

	var echo := ECHO_SCENE.instantiate() as Echo
	test_root.add_child(echo)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.global_position = Vector2(300.0, 258.0)
	test_root.add_child(player)

	var segment := _make_horizontal_segment(
		Vector2(100.0, 300.0),
		Vector2(300.0, 300.0),
		1.0
	)
	echo.play_segment_reverse(segment)

	# Allow the deferred collision enable to reach the physics server.
	await physics_frame
	await physics_frame
	var starting_player_x := player.global_position.x

	for _tick in 28:
		await physics_frame

	print(
		"Carry diagnostic: player %.2f -> %.2f, echo %.2f" %
		[starting_player_x, player.global_position.x, echo.global_position.x]
	)
	assert(
		player.global_position.x < starting_player_x - 50.0,
		"Player was not carried by the backward-moving Echo."
	)

	var jump_event := InputEventAction.new()
	jump_event.action = &"jump"
	jump_event.pressed = true
	player.set_movement_enabled(true)
	player._unhandled_input(jump_event)
	await physics_frame
	assert(player.velocity.y < 0.0, "Player could not jump from the moving Echo.")
	print("Jump diagnostic passed.")

	for _tick in 32:
		await physics_frame

	assert(
		echo.global_position.is_equal_approx(Vector2(100.0, 300.0)),
		"Player collision changed the Echo trajectory or it missed the exact start frame."
	)
	assert(not echo.visible, "Echo must hide after reverse playback reaches the beginning.")
	print("First Echo endpoint diagnostic passed.")

	echo.queue_free()
	player.queue_free()
	await physics_frame
	print("Starting side-push diagnostic.")

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(500.0, 40.0)
	floor_shape.position = Vector2(250.0, 320.0)
	floor_shape.shape = floor_rectangle
	floor_body.add_child(floor_shape)
	test_root.add_child(floor_body)

	var pushing_echo := ECHO_SCENE.instantiate() as Echo
	test_root.add_child(pushing_echo)

	var pushed_player := PLAYER_SCENE.instantiate() as PlayerController
	pushed_player.global_position = Vector2(272.0, 300.0)
	test_root.add_child(pushed_player)

	var pushing_segment := _make_horizontal_segment(
		Vector2(200.0, 300.0),
		Vector2(300.0, 300.0),
		1.0
	)
	pushing_echo.play_segment_reverse(pushing_segment)
	await physics_frame
	await physics_frame
	var player_x_before_push := pushed_player.global_position.x
	print("Push contact initialized: player %.2f, echo %.2f" % [player_x_before_push, pushing_echo.global_position.x])

	for _tick in 28:
		await physics_frame

	print("Push diagnostic midpoint: player %.2f, echo %.2f" % [pushed_player.global_position.x, pushing_echo.global_position.x])
	assert(
		pushed_player.global_position.x < player_x_before_push - 25.0,
		"Echo did not push the player from the side."
	)

	for _tick in 32:
		await physics_frame

	print("Push endpoint diagnostic: player %.2f, echo %.2f" % [pushed_player.global_position.x, pushing_echo.global_position.x])
	assert(
		pushing_echo.global_position.is_equal_approx(Vector2(200.0, 300.0)),
		"Pushing the player changed the Echo's authoritative trajectory."
	)

	print("Echo collision smoke test passed: carry, jump, push, and immutable trajectory.")
	test_root.queue_free()
	await physics_frame
	quit(0)


func _make_horizontal_segment(start_position: Vector2, end_position: Vector2, segment_duration: float) -> RecordedSegment:
	var segment := RecordedSegment.new()
	segment.start_anchor_id = &"TEST_START"
	segment.end_anchor_id = &"TEST_END"
	segment.duration = segment_duration

	var first_frame := RecordedFrame.new()
	first_frame.timestamp = 0.0
	first_frame.global_position = start_position
	segment.frames.append(first_frame)

	var last_frame := RecordedFrame.new()
	last_frame.timestamp = segment_duration
	last_frame.global_position = end_position
	segment.frames.append(last_frame)
	return segment
