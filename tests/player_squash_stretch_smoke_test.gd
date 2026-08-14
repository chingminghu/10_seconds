extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ECHO_SCENE := preload("res://scenes/echo/echo.tscn")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	await process_frame

	var visual := player.get_node("Visual") as Polygon2D
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var capsule := collision.shape as CapsuleShape2D
	var original_collision_scale := collision.scale
	var original_radius := capsule.radius
	var original_height := capsule.height
	var original_visual_scale := visual.scale
	var original_visual_position := visual.position

	player._trigger_vertical_deformation(300.0, true)
	var weak_jump_scale := visual.scale.y
	player._trigger_vertical_deformation(700.0, true)
	var strong_jump_scale := visual.scale.y
	assert(weak_jump_scale > original_visual_scale.y, "A jump did not stretch the Player visual.")
	assert(
		strong_jump_scale > weak_jump_scale,
		"A larger jump speed difference did not produce a larger stretch."
	)
	assert(visual.position == original_visual_position, "Stretching changed the anchored Visual position.")

	player._trigger_vertical_deformation(300.0, false)
	var weak_landing_scale := visual.scale.y
	player._trigger_vertical_deformation(700.0, false)
	var strong_landing_scale := visual.scale.y
	assert(weak_landing_scale < original_visual_scale.y, "A landing did not squash the Player visual.")
	assert(
		strong_landing_scale < weak_landing_scale,
		"A larger landing speed difference did not produce a larger squash."
	)
	assert(visual.position == original_visual_position, "Squashing changed the anchored Visual position.")

	player._recover_visual_deformation(0.1)
	assert(
		visual.scale.is_equal_approx(original_visual_scale),
		"The Player visual did not recover to its original scale."
	)
	assert(collision.scale == original_collision_scale, "Visual deformation changed the collision scale.")
	assert(capsule.radius == original_radius, "Visual deformation changed the collision radius.")
	assert(capsule.height == original_height, "Visual deformation changed the collision height.")

	player._trigger_vertical_deformation(700.0, true)
	var source := player.get_node("RecordableTransformSource") as RecordableTransformSource
	var frame := source.capture_frame(0.25)
	assert(frame.visual_scale == visual.scale, "Recording did not capture the Player Visual scale.")

	var echo := ECHO_SCENE.instantiate() as Echo
	root.add_child(echo)
	await process_frame
	echo.apply_recorded_presentation(frame)
	assert(
		(echo.get_node("Visual") as Polygon2D).scale == frame.visual_scale,
		"Echo did not apply the recorded Visual scale."
	)
	assert(
		(echo.get_node("GhostOutline") as Line2D).scale == frame.visual_scale,
		"Echo outline did not apply the recorded Visual scale."
	)

	print(
		"Player squash/stretch smoke test passed: event strength, recovery, recording, Echo, and unchanged collision."
	)
	echo.queue_free()
	player.queue_free()
	await process_frame
	quit(0)
