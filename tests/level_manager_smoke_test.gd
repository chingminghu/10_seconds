extends SceneTree

const MAIN_SCENE := preload("res://scenes/entry.tscn")

var _campaign_completed_count: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var manager := MAIN_SCENE.instantiate() as LevelManager
	root.add_child(manager)
	await process_frame
	await physics_frame

	assert(manager.current_level_index == 0, "LevelManager did not load the first configured level.")
	assert(is_instance_valid(manager.current_level), "LevelManager did not retain the current level.")
	assert(manager.level_container.get_child_count() == 1, "LevelManager must keep exactly one active level.")
	assert(
		manager.current_level.get_node_or_null("%RunController") is RunController,
		"The loaded level does not expose its RunController."
	)

	var first_level := manager.current_level
	manager.reload_current_level()
	await process_frame
	await physics_frame
	assert(manager.current_level != first_level, "Reload must replace the active level instance.")
	assert(manager.current_level_index == 0, "Reload changed the active level index.")
	assert(manager.level_container.get_child_count() == 1, "Reload left duplicate levels in the container.")

	manager.campaign_completed.connect(_on_campaign_completed)
	var run_controller := manager.current_level.get_node("%RunController") as RunController
	run_controller.level_completed.emit()
	assert(_campaign_completed_count == 1, "Completing the final level did not complete the campaign.")
	assert(manager.current_level_index == 0, "Final completion should leave the completed level visible.")

	print("Level manager smoke test passed: initial load, reload, and campaign completion.")
	manager.queue_free()
	await process_frame
	quit(0)


func _on_campaign_completed() -> void:
	_campaign_completed_count += 1
