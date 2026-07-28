class_name GameHUD
extends CanvasLayer

@export var run_controller: RunController

@onready var _state_label: Label = %StateLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _anchor_label: Label = %AnchorLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _rewind_label: Label = %RewindLabel


func _ready() -> void:
	assert(run_controller != null, "GameHUD requires a RunController reference.")
	run_controller.state_changed.connect(_on_state_changed)
	run_controller.anchor_changed.connect(_on_anchor_changed)
	run_controller.time_remaining_changed.connect(_on_time_remaining_changed)
	run_controller.echo_playback_started.connect(_on_echo_playback_started)
	run_controller.echo_playback_finished.connect(_on_echo_playback_finished)
	run_controller.progress_history_changed.connect(_on_progress_history_changed)
	_refresh_state(run_controller.state)
	_on_time_remaining_changed(run_controller.time_remaining)


func _on_state_changed(_previous_state: RunController.RunState, current_state: RunController.RunState) -> void:
	_refresh_state(current_state)


func _on_anchor_changed(current_anchor: Anchor, expected_anchor: Anchor) -> void:
	_anchor_label.text = "ANCHOR %s" % current_anchor.anchor_id
	if expected_anchor != null:
		_anchor_label.text += "  >  %s" % expected_anchor.anchor_id
	else:
		_anchor_label.text += "  >  GOAL"


func _on_time_remaining_changed(time_remaining: float) -> void:
	_timer_label.text = "%04.1f" % time_remaining
	_timer_label.modulate = Color(1.0, 0.3, 0.3) if time_remaining <= 3.0 else Color.WHITE


func _on_echo_playback_started() -> void:
	_rewind_label.show()


func _on_echo_playback_finished() -> void:
	_rewind_label.hide()


func _on_progress_history_changed(_can_return_previous: bool) -> void:
	_refresh_state(run_controller.state)


func _refresh_state(current_state: RunController.RunState) -> void:
	_state_label.text = run_controller.get_state_name()
	match current_state:
		RunController.RunState.ANCHOR_READY:
			_prompt_label.text = "Press [ENTER / E] to PLAY / RECORD"
			if run_controller.can_return_to_previous_anchor():
				_prompt_label.text += "  •  [Q / BACKSPACE] RETURN"
		RunController.RunState.RECORDING:
			_prompt_label.text = "[SHIFT] SLOW  |  [R] RETRY CURRENT"
			if run_controller.can_return_to_previous_anchor():
				_prompt_label.text += "  •  [Q / BACKSPACE] RETURN"
		RunController.RunState.ATTEMPT_FAILED:
			_prompt_label.text = "RECORDING FAILED"
		RunController.RunState.LEVEL_COMPLETE:
			_prompt_label.text = "PLAYBACK COMPLETE"
		_:
			_prompt_label.text = ""
