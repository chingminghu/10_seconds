extends SceneTree

const TOGGLE_PAD_SCENE := preload("res://scenes/mechanisms/toggle_pad.tscn")

var _toggle_count: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var test_root := Node2D.new()
	root.add_child(test_root)

	var pad := TOGGLE_PAD_SCENE.instantiate() as TogglePad
	pad.global_position = Vector2(100.0, 200.0)
	pad.toggled.connect(_on_toggled)
	test_root.add_child(pad)

	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var body_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12.0, 12.0)
	body_shape.shape = rectangle
	body.add_child(body_shape)
	body.global_position = Vector2(300.0, 194.0)
	test_root.add_child(body)
	for _tick in 2:
		await physics_frame

	pad.begin_attempt()
	body.global_position = Vector2(100.0, 194.0)
	for _tick in 2:
		await physics_frame
	assert(_toggle_count == 1, "A real empty-to-occupied transition must toggle once.")
	assert(pad.was_pressed, "TogglePad did not record its occupied state.")

	# Reproduce both restore mismatches while attempt input is disabled: an
	# occupied Pad becoming empty, then a body being restored onto an empty Pad.
	pad.end_attempt()
	body.global_position = Vector2(300.0, 194.0)
	pad.restore_state(false)
	for _tick in 2:
		await physics_frame
	assert(_toggle_count == 1, "Removing a body during restore emitted a toggle pulse.")

	body.global_position = Vector2(100.0, 194.0)
	pad.restore_state(false)
	for _tick in 2:
		await physics_frame
	assert(_toggle_count == 1, "Restoring a body onto the Pad emitted a toggle pulse.")

	# Starting the next attempt adopts the restored overlap as its baseline. The
	# body must leave and re-enter before another legitimate pulse is emitted.
	pad.begin_attempt()
	assert(pad.was_pressed, "begin_attempt() did not synchronize restored occupancy.")
	body.global_position = Vector2(300.0, 194.0)
	for _tick in 2:
		await physics_frame
	body.global_position = Vector2(100.0, 194.0)
	for _tick in 2:
		await physics_frame
	assert(_toggle_count == 2, "A post-restore re-entry did not toggle exactly once.")

	print("TogglePad restore smoke test passed: restore overlap changes emit no false toggle.")
	test_root.queue_free()
	await process_frame
	quit(0)


func _on_toggled() -> void:
	_toggle_count += 1
