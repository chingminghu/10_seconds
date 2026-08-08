class_name RunControllerV2
extends Node

signal recording_charges_changed(available: int, maximum: int)
signal recording_queue_changed(current_size: int, capacity: int)
signal recording_started(segment: RecordedSegment)
signal recording_finished(segment: RecordedSegment, stopped_by_time_limit: bool)
signal recording_rejected(reason: StringName)
signal playback_started(segment: RecordedSegment)
signal playback_finished
signal playback_rejected(reason: StringName)
signal orb_charge_granted(orb: Orb, amount: int, available: int, maximum: int)
signal orb_charge_blocked(orb: Orb)
signal reset_started
signal reset_completed
signal level_completed

const MANUAL_START_ID: StringName = &"MANUAL_RECORDING_START"
const MANUAL_END_ID: StringName = &"MANUAL_RECORDING_END"
const RECORD_KEY := KEY_J
const PLAYBACK_KEY := KEY_K
const RESET_KEY := KEY_R

@export_category("Scene References")
@export var player: PlayerController
@export var spawn_anchor: Anchor
@export var orbs_root: Node
@export var goal: LevelGoal
@export var recording_controller: RecordingController
@export var config: GameConfig
@export var echo_scene: PackedScene
@export var echo_container: Node2D
@export var snapshot_controller: SnapshotController

@export_category("Recording Rules")
@export_range(1, 5, 1) var recording_capacity: int = 1
@export_range(0, 5, 1) var starting_recording_charges: int = 0
@export_range(1.0, 60.0, 0.1, "suffix:s") var maximum_recording_duration: float = 10.0

@export_category("Optional InputMap Actions")
@export var record_action: StringName = &"record_v2"
@export var playback_action: StringName = &"playback_v2"
@export var reset_action: StringName = &"retry_current"

var recording_queue: RecordingQueueV2
var recording_charges: int = 0
var is_resetting: bool = false
var is_level_complete: bool = false

var _orbs: Array[Orb] = []
var _active_recording_segment: RecordedSegment
var _manual_stop_requested: bool = false
var _active_echo: Echo
var _initial_player_transform: Transform2D
var _initial_snapshot: AttemptSnapshot
var _normal_player_process_mode: int = Node.PROCESS_MODE_INHERIT
var _initialized: bool = false
var _reset_generation: int = 0


func _ready() -> void:
	assert(player != null, "RunControllerV2 requires a PlayerController reference.")
	assert(spawn_anchor != null, "RunControllerV2 requires a spawn Anchor reference.")
	assert(orbs_root != null, "RunControllerV2 requires an Orbs root reference.")
	assert(goal != null, "RunControllerV2 requires a LevelGoal reference.")
	assert(recording_controller != null, "RunControllerV2 requires a RecordingController reference.")
	assert(config != null, "RunControllerV2 requires a GameConfig resource.")
	assert(echo_scene != null, "RunControllerV2 requires an Echo PackedScene.")
	assert(echo_container != null, "RunControllerV2 requires an Echo container.")
	assert(snapshot_controller != null, "RunControllerV2 requires a SnapshotController.")
	
	player.set_movement_enabled(false)
	_initial_player_transform = spawn_anchor.get_spawn_transform()
	player.teleport_to(_initial_player_transform)
	_normal_player_process_mode = player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	spawn_anchor.monitoring = false
	recording_controller.maximum_duration = maximum_recording_duration
	recording_controller.frame_recorded.connect(_on_recording_frame_recorded)
	goal.player_reached_goal.connect(_on_goal_reached)
	_collect_orbs()
	for orb in _orbs:
		orb.touch_requested.connect(_on_orb_touch_requested)

	recording_queue = RecordingQueueV2.new(recording_capacity)
	recording_queue.changed.connect(_on_queue_changed)
	call_deferred(&"_initialize_run")


func _unhandled_input(event: InputEvent) -> void:
	if not _initialized or is_resetting:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if _matches_action_or_key(event, reset_action, RESET_KEY):
		reset_all()
		return
	if is_level_complete:
		return
	if _matches_action_or_key(event, record_action, RECORD_KEY):
		if recording_controller.is_recording:
			stop_recording()
		else:
			start_recording()
	elif _matches_action_or_key(event, playback_action, PLAYBACK_KEY):
		start_playback()


func start_recording() -> bool:
	if not _can_accept_gameplay_input():
		recording_rejected.emit(&"RUN_NOT_ACTIVE")
		return false
	if recording_controller.is_recording:
		recording_rejected.emit(&"ALREADY_RECORDING")
		return false
	if recording_charges <= 0:
		recording_rejected.emit(&"NO_RECORDING_CHARGE")
		return false
	if recording_queue.is_full():
		recording_rejected.emit(&"QUEUE_FULL")
		return false

	recording_controller.start_recording(MANUAL_START_ID)
	_active_recording_segment = recording_controller.current_segment
	var pushed := recording_queue.try_push(_active_recording_segment)
	assert(pushed, "A pre-checked RecordingQueueV2 push must succeed.")
	recording_charges -= 1
	_manual_stop_requested = false
	recording_charges_changed.emit(recording_charges, recording_capacity)
	recording_started.emit(_active_recording_segment)
	return true


func stop_recording() -> bool:
	if not recording_controller.is_recording:
		recording_rejected.emit(&"NOT_RECORDING")
		return false

	# A Segment needs an initial and a later sample. If J is pressed twice in the
	# same physics tick, finish as soon as the next sample arrives.
	if recording_controller.current_segment.frames.size() < 2:
		_manual_stop_requested = true
		return true
	_finish_recording(false)
	return true


func start_playback() -> bool:
	if not _can_accept_gameplay_input():
		playback_rejected.emit(&"RUN_NOT_ACTIVE")
		return false
	if is_instance_valid(_active_echo):
		playback_rejected.emit(&"ECHO_ALREADY_PLAYING")
		return false

	var next_segment := recording_queue.peek_front()
	if next_segment == null:
		playback_rejected.emit(&"QUEUE_EMPTY")
		return false
	if not next_segment.is_valid():
		playback_rejected.emit(&"FRONT_RECORDING_NOT_FINISHED")
		return false

	var segment := recording_queue.pop_front()
	_active_echo = echo_scene.instantiate() as Echo
	assert(_active_echo != null, "The configured Echo scene must instantiate an Echo.")
	echo_container.add_child(_active_echo)
	_active_echo.playback_completed.connect(_on_echo_playback_completed)
	_active_echo.play_segment_reverse(segment)
	playback_started.emit(segment)
	return true


func reset_all() -> void:
	if not _initialized or is_resetting:
		return
	_reset_generation += 1
	_perform_full_reset(_reset_generation)


func _initialize_run() -> void:
	# Capture after one physics synchronization so initial mechanism overlaps are
	# authoritative, while the disabled Player remains at its authored transform.
	await get_tree().physics_frame
	_initial_snapshot = snapshot_controller.capture_snapshot()
	recording_charges = clampi(starting_recording_charges, 0, recording_capacity)
	snapshot_controller.begin_attempt()
	player.process_mode = _normal_player_process_mode
	player.set_movement_enabled(true)
	_initialized = true
	recording_charges_changed.emit(recording_charges, recording_capacity)
	recording_queue_changed.emit(recording_queue.size(), recording_queue.capacity)
	_try_collect_overlapping_orbs()


func _perform_full_reset(reset_generation: int) -> void:
	is_resetting = true
	is_level_complete = false
	reset_started.emit()
	player.set_movement_enabled(false)
	var previous_player_process_mode := player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	snapshot_controller.end_attempt()

	_cancel_active_recording()
	_remove_active_echo(false)
	recording_queue.clear()
	recording_charges = clampi(starting_recording_charges, 0, recording_capacity)
	snapshot_controller.restore_snapshot(_initial_snapshot)
	player.teleport_to(_initial_player_transform)
	recording_charges_changed.emit(recording_charges, recording_capacity)

	# Let restored transforms and deferred collision changes reach the physics
	# server before resettable objects establish their next-attempt baselines.
	await get_tree().physics_frame
	if reset_generation != _reset_generation:
		return
	snapshot_controller.begin_attempt()
	player.process_mode = previous_player_process_mode
	player.set_movement_enabled(true)
	is_resetting = false
	_try_collect_overlapping_orbs()
	reset_completed.emit()


func _on_orb_touch_requested(orb: Orb, touched_player: PlayerController) -> void:
	if not _initialized or is_resetting or is_level_complete:
		return
	if touched_player != player or not is_instance_valid(orb) or not orb.is_active:
		return
	if recording_charges >= recording_capacity:
		orb_charge_blocked.emit(orb)
		return

	var granted_amount := mini(orb.charge_amount, recording_capacity - recording_charges)
	if granted_amount <= 0 or not orb.touched():
		return
	recording_charges += granted_amount
	recording_charges_changed.emit(recording_charges, recording_capacity)
	orb_charge_granted.emit(orb, granted_amount, recording_charges, recording_capacity)


func _on_recording_frame_recorded(_frame_count: int) -> void:
	if not recording_controller.is_recording:
		return
	if recording_controller.elapsed_time >= maximum_recording_duration:
		_finish_recording(true)
	elif _manual_stop_requested and recording_controller.current_segment.frames.size() >= 2:
		_finish_recording(false)


func _finish_recording(stopped_by_time_limit: bool) -> void:
	assert(recording_controller.is_recording, "Cannot finish when no v2 recording is active.")
	var completed_segment := recording_controller.complete_recording(MANUAL_END_ID)
	assert(completed_segment == _active_recording_segment, "RecordingQueueV2 contains a mismatched active Segment.")
	_active_recording_segment = null
	_manual_stop_requested = false
	recording_finished.emit(completed_segment, stopped_by_time_limit)


func _cancel_active_recording() -> void:
	if not recording_controller.is_recording:
		_active_recording_segment = null
		_manual_stop_requested = false
		return
	var discarded_segment := _active_recording_segment
	recording_controller.discard_recording()
	if discarded_segment != null:
		recording_queue.remove(discarded_segment)
	_active_recording_segment = null
	_manual_stop_requested = false


func _on_echo_playback_completed(completed_echo: Echo) -> void:
	if completed_echo != _active_echo:
		return
	_active_echo.queue_free()
	_active_echo = null
	playback_finished.emit()


func _remove_active_echo(emit_finished: bool) -> void:
	if not is_instance_valid(_active_echo):
		_active_echo = null
		return
	_active_echo.stop_playback()
	_active_echo.queue_free()
	_active_echo = null
	if emit_finished:
		playback_finished.emit()


func _on_goal_reached() -> void:
	if not _can_accept_gameplay_input():
		return
	if recording_controller.is_recording:
		if recording_controller.current_segment.frames.size() >= 2:
			_finish_recording(false)
		else:
			_cancel_active_recording()
	_remove_active_echo(false)
	snapshot_controller.end_attempt()
	player.set_movement_enabled(false)
	is_level_complete = true
	level_completed.emit()


func _on_queue_changed(current_size: int, capacity: int) -> void:
	recording_queue_changed.emit(current_size, capacity)


func _collect_orbs() -> void:
	_orbs.clear()
	for node in orbs_root.get_children():
		_orbs.append(node as Orb)


func _try_collect_overlapping_orbs() -> void:
	for orb in _orbs:
		if orb.is_active and orb.overlaps_body(player):
			_on_orb_touch_requested(orb, player)


func _can_accept_gameplay_input() -> bool:
	return _initialized and not is_resetting and not is_level_complete


func _matches_action_or_key(event: InputEvent, action: StringName, fallback_key: Key) -> bool:
	if InputMap.has_action(action) and event.is_action_pressed(action):
		return true
	var key_event := event as InputEventKey
	return (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and (key_event.physical_keycode == fallback_key or key_event.keycode == fallback_key)
	)
