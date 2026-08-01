class_name LevelManager
extends Node

signal level_loaded(level_index: int, level: Node)
signal level_unloaded(level_index: int)
signal campaign_completed

@export var level_scenes: Array[PackedScene] = []
@export var level_container: Node
@export_range(0.0, 10.0, 0.1, "suffix:s") var level_complete_delay: float = 1.0

var current_level_index: int = -1
var current_level: Node
var _load_generation: int = 0


func _ready() -> void:
	assert(level_container != null, "LevelManager requires a level container.")
	assert(not level_scenes.is_empty(), "LevelManager requires at least one level scene.")
	call_deferred(&"load_level", 0)


func load_level(level_index: int) -> void:
	print("loading level %d" % [level_index])
	assert(
		level_index >= 0 and level_index < level_scenes.size(),
		"Level index %d is outside the configured level list." % level_index
	)
	_load_generation += 1
	_unload_current_level()

	var level_scene := level_scenes[level_index]
	assert(level_scene != null, "Level scene %d is not assigned." % level_index)
	current_level = level_scene.instantiate()
	current_level_index = level_index
	level_container.add_child(current_level)

	var run_controller := current_level.get_node_or_null("%RunController") as RunController
	assert(run_controller != null, "Every managed level requires a unique RunController node.")
	run_controller.level_completed.connect(_on_current_level_completed.bind(current_level))
	level_loaded.emit(current_level_index, current_level)


func reload_current_level() -> void:
	assert(current_level_index >= 0, "Cannot reload before a level has been loaded.")
	load_level(current_level_index)


func _unload_current_level() -> void:
	if not is_instance_valid(current_level):
		current_level = null
		return

	var unloaded_index := current_level_index
	level_container.remove_child(current_level)
	current_level.queue_free()
	current_level = null
	current_level_index = -1
	level_unloaded.emit(unloaded_index)


func _on_current_level_completed(completed_level: Node) -> void:
	if completed_level != current_level:
		return

	var next_level_index := current_level_index + 1
	if next_level_index >= level_scenes.size():
		campaign_completed.emit()
		return

	var completion_generation := _load_generation
	if level_complete_delay > 0.0:
		await get_tree().create_timer(level_complete_delay).timeout
	if completion_generation != _load_generation or completed_level != current_level:
		return
	load_level(next_level_index)
