class_name GameHUDV2
extends CanvasLayer

@export var run_controller: RunControllerV2

@onready var _charge_label: Label = %ChargeLabel
@onready var _recording_panel: Control = %RecordingPanel
@onready var _recording_label: Label = %RecordingLabel


func _ready() -> void:
	assert(run_controller != null, "HUD_V2 requires a RunControllerV2 reference.")

	run_controller.recording_charges_changed.connect(_on_recording_charges_changed)
	run_controller.recording_started.connect(_on_recording_started)
	run_controller.recording_finished.connect(_on_recording_finished)
	run_controller.reset_started.connect(_on_reset_started)
	run_controller.level_completed.connect(_on_level_completed)

	_on_recording_charges_changed(
		run_controller.recording_charges,
		run_controller.recording_capacity
	)
	_update_recording_display()


func _process(_delta: float) -> void:
	_update_recording_display()


func _on_recording_charges_changed(available: int, maximum: int) -> void:
	_charge_label.text = "CHARGE  %d / %d" % [available, maximum]


func _on_recording_started(_segment: RecordedSegment) -> void:
	_update_recording_display()


func _on_recording_finished(
	_segment: RecordedSegment,
	_stopped_by_time_limit: bool
) -> void:
	_recording_panel.hide()


func _on_reset_started() -> void:
	_recording_panel.hide()


func _on_level_completed() -> void:
	_recording_panel.hide()


func _update_recording_display() -> void:
	var recorder := run_controller.recording_controller
	if recorder == null or not recorder.is_recording:
		_recording_panel.hide()
		return

	var remaining_seconds := maxf(
		run_controller.maximum_recording_duration - recorder.elapsed_time,
		0.0
	)
	_recording_label.text = "REC\n%.1f s" % remaining_seconds
	_recording_panel.show()
