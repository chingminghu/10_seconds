class_name RunController
extends Node

signal state_changed(previous_state: RunState, current_state: RunState)
signal anchor_changed(current_anchor: Anchor, expected_anchor: Anchor)
signal time_remaining_changed(time_remaining: float)
signal segment_completed(segment: RecordedSegment)
signal attempt_failed
signal echo_playback_started
signal echo_playback_finished
signal progress_history_changed(can_return_previous: bool)
signal level_completed

enum RunState {
	ANCHOR_READY,
	COUNT_IN,
	RECORDING,
	ARRIVAL_TRANSITION,
	ATTEMPT_FAILED,
	ROLLING_BACK,
	LEVEL_COMPLETE,
	PAUSED,
}

@export var player: PlayerController
@export var anchors_root: Node
@export var goal: LevelGoal
@export var recording_controller: RecordingController
@export var config: GameConfig
@export var echo_scene: PackedScene
@export var echo_container: Node2D
@export var snapshot_controller: SnapshotController

var state: RunState = RunState.ANCHOR_READY
var current_anchor: Anchor
var expected_anchor: Anchor
var time_remaining: float = 0.0
var completed_segments: Array[RecordedSegment] = []
var anchor_progress: Array[AnchorProgressEntry] = []
var _ordered_anchors: Array[Anchor] = []
var _attempt_token: int = 0
var _active_echo: Echo
var _attempt_snapshot: AttemptSnapshot


func _ready() -> void:
	assert(player != null, "RunController requires a PlayerController reference.")
	assert(anchors_root != null, "RunController requires an Anchors root reference.")
	assert(goal != null, "RunController requires a LevelGoal reference.")
	assert(recording_controller != null, "RunController requires a RecordingController reference.")
	assert(config != null, "RunController requires a GameConfig resource.")
	assert(echo_scene != null, "RunController requires an Echo PackedScene.")
	assert(echo_container != null, "RunController requires an Echo container.")
	assert(snapshot_controller != null, "RunController requires a SnapshotController.")
	recording_controller.maximum_duration = config.segment_duration

	_collect_and_validate_anchors()
	for anchor in _ordered_anchors:
		anchor.player_arrived.connect(_on_anchor_arrived)
	goal.player_reached_goal.connect(_on_goal_reached)

	current_anchor = _ordered_anchors[0]
	expected_anchor = _ordered_anchors[1] if _ordered_anchors.size() > 1 else null
	call_deferred(&"_initialize_run")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"play_record") and state == RunState.ANCHOR_READY:
		_start_traversal()
	elif event.is_action_pressed(&"retry_current") and state == RunState.RECORDING:
		_fail_attempt()
	elif (
		event.is_action_pressed(&"return_previous_anchor")
		and state in [RunState.ANCHOR_READY, RunState.RECORDING]
	):
		return_to_previous_anchor()


func _physics_process(delta: float) -> void:
	if state != RunState.RECORDING:
		return
	time_remaining = maxf(time_remaining - delta, 0.0)
	time_remaining_changed.emit(time_remaining)
	if is_zero_approx(time_remaining):
		_fail_attempt()


func get_state_name() -> String:
	return RunState.keys()[state]


func can_return_to_previous_anchor() -> bool:
	return anchor_progress.size() > 1


func _initialize_run() -> void:
	player.teleport_to(current_anchor.get_spawn_transform())
	anchor_progress.clear()
	anchor_progress.append(
		AnchorProgressEntry.create(
			current_anchor,
			null,
			snapshot_controller.capture_snapshot()
		)
	)
	time_remaining = config.segment_duration
	_set_state(RunState.ANCHOR_READY)
	_update_anchor_visuals()
	anchor_changed.emit(current_anchor, expected_anchor)
	time_remaining_changed.emit(time_remaining)
	progress_history_changed.emit(can_return_to_previous_anchor())


func _start_traversal() -> void:
	_attempt_token += 1
	time_remaining = config.segment_duration
	_attempt_snapshot = snapshot_controller.capture_snapshot()
	anchor_progress[-1].level_snapshot = _attempt_snapshot
	recording_controller.start_recording(current_anchor.anchor_id)
	_spawn_previous_echo()
	player.set_movement_enabled(true)
	_set_state(RunState.RECORDING)
	time_remaining_changed.emit(time_remaining)


func _on_anchor_arrived(anchor: Anchor) -> void:
	if state != RunState.RECORDING or anchor != expected_anchor:
		return

	_set_state(RunState.ARRIVAL_TRANSITION)
	player.set_movement_enabled(false)
	_remove_active_echo()
	var segment := recording_controller.complete_recording(anchor.anchor_id)
	completed_segments.append(segment)
	segment_completed.emit(segment)
	_attempt_snapshot = null
	current_anchor = anchor
	anchor_progress.append(AnchorProgressEntry.create(current_anchor, segment))
	expected_anchor = _get_next_anchor(anchor)
	time_remaining = config.segment_duration
	_update_anchor_visuals()
	anchor_changed.emit(current_anchor, expected_anchor)
	_set_state(RunState.ANCHOR_READY)
	time_remaining_changed.emit(time_remaining)
	progress_history_changed.emit(can_return_to_previous_anchor())


func _on_goal_reached() -> void:
	if state != RunState.RECORDING or expected_anchor != null:
		return

	player.set_movement_enabled(false)
	_remove_active_echo()
	var segment := recording_controller.complete_recording(&"GOAL")
	completed_segments.append(segment)
	segment_completed.emit(segment)
	_attempt_snapshot = null
	_set_state(RunState.LEVEL_COMPLETE)
	level_completed.emit()


func _fail_attempt() -> void:
	if state != RunState.RECORDING:
		return

	_attempt_token += 1
	var failure_token := _attempt_token
	player.set_movement_enabled(false)
	_remove_active_echo()
	recording_controller.discard_recording()
	_set_state(RunState.ATTEMPT_FAILED)
	attempt_failed.emit()
	await get_tree().create_timer(0.65).timeout

	# A token prevents an obsolete delayed reset from mutating a newer attempt.
	if failure_token != _attempt_token or state != RunState.ATTEMPT_FAILED:
		return
	if _attempt_snapshot != null:
		snapshot_controller.restore_snapshot(_attempt_snapshot)
		_attempt_snapshot = null
	player.teleport_to(current_anchor.get_spawn_transform())
	time_remaining = config.segment_duration
	time_remaining_changed.emit(time_remaining)
	_set_state(RunState.ANCHOR_READY)


func return_to_previous_anchor() -> void:
	if state not in [RunState.ANCHOR_READY, RunState.RECORDING]:
		return
	if not can_return_to_previous_anchor():
		return

	_attempt_token += 1
	player.set_movement_enabled(false)
	_remove_active_echo()
	if recording_controller.is_recording:
		recording_controller.discard_recording()

	_set_state(RunState.ROLLING_BACK)
	_attempt_snapshot = null

	var removed_progress: AnchorProgressEntry = anchor_progress.pop_back()
	assert(removed_progress.incoming_segment != null, "A non-start Anchor must have an incoming Segment.")
	assert(not completed_segments.is_empty(), "Segment history is inconsistent with Anchor progress.")
	var removed_segment: RecordedSegment = completed_segments.pop_back()
	assert(removed_segment == removed_progress.incoming_segment, "Rollback removed a mismatched Segment.")

	var restored_progress: AnchorProgressEntry = anchor_progress[-1]
	assert(restored_progress.level_snapshot != null, "Previous Anchor is missing its level snapshot.")
	snapshot_controller.restore_snapshot(restored_progress.level_snapshot)

	current_anchor = _find_anchor(restored_progress.anchor_id)
	expected_anchor = _get_next_anchor(current_anchor)
	player.teleport_to(restored_progress.player_spawn_transform)
	time_remaining = config.segment_duration
	_update_anchor_visuals()
	anchor_changed.emit(current_anchor, expected_anchor)
	time_remaining_changed.emit(time_remaining)
	progress_history_changed.emit(can_return_to_previous_anchor())
	_set_state(RunState.ANCHOR_READY)


func _spawn_previous_echo() -> void:
	_remove_active_echo()
	if completed_segments.is_empty():
		return

	_active_echo = echo_scene.instantiate() as Echo
	assert(_active_echo != null, "The configured Echo scene must instantiate an Echo.")
	echo_container.add_child(_active_echo)
	_active_echo.playback_completed.connect(_on_echo_playback_completed)
	_active_echo.play_segment_reverse(completed_segments[-1])
	echo_playback_started.emit()


func _remove_active_echo() -> void:
	if not is_instance_valid(_active_echo):
		_active_echo = null
		return

	_active_echo.stop_playback()
	_active_echo.queue_free()
	_active_echo = null
	echo_playback_finished.emit()


func _on_echo_playback_completed(completed_echo: Echo) -> void:
	if completed_echo != _active_echo:
		return
	_active_echo.queue_free()
	_active_echo = null
	echo_playback_finished.emit()


func _get_next_anchor(anchor: Anchor) -> Anchor:
	var next_index := anchor.order_index + 1
	if next_index >= _ordered_anchors.size():
		return null
	return _ordered_anchors[next_index]


func _find_anchor(anchor_id: StringName) -> Anchor:
	for anchor in _ordered_anchors:
		if anchor.anchor_id == anchor_id:
			return anchor
	assert(false, "Anchor history references an unknown Anchor ID: %s" % anchor_id)
	return null


func _set_state(new_state: RunState) -> void:
	if state == new_state:
		return
	var previous_state := state
	state = new_state
	state_changed.emit(previous_state, state)


func _update_anchor_visuals() -> void:
	for anchor in _ordered_anchors:
		anchor.set_active_visual(anchor == current_anchor)


func _collect_and_validate_anchors() -> void:
	for child in anchors_root.get_children():
		if child is Anchor:
			_ordered_anchors.append(child as Anchor)

	assert(not _ordered_anchors.is_empty(), "The level requires at least one Anchor.")
	_ordered_anchors.sort_custom(func(a: Anchor, b: Anchor) -> bool: return a.order_index < b.order_index)

	var start_anchor_count := 0
	for index in _ordered_anchors.size():
		var anchor := _ordered_anchors[index]
		assert(not anchor.anchor_id.is_empty(), "Every Anchor requires a non-empty anchor_id.")
		assert(anchor.order_index == index, "Anchor order_index values must be unique and contiguous from zero.")
		if anchor.is_start_anchor:
			start_anchor_count += 1

	assert(start_anchor_count == 1, "The level requires exactly one start Anchor.")
	assert(_ordered_anchors[0].is_start_anchor, "The start Anchor must have order_index 0.")
