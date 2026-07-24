class_name CenteredArrivalDetector
extends Node

signal player_centered(player: PlayerController)

@export var detection_area: Area2D
@export var center_target: Node2D
@export_range(1.0, 64.0, 1.0, "suffix:px") var horizontal_tolerance: float = 10.0
@export var require_grounded: bool = true

var _tracked_player: PlayerController
var _triggered_for_current_overlap: bool = false


func _ready() -> void:
	assert(detection_area != null, "CenteredArrivalDetector requires a detection Area2D.")
	assert(center_target != null, "CenteredArrivalDetector requires a center target.")
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if _tracked_player == null or _triggered_for_current_overlap:
		return
	if not is_player_centered(_tracked_player):
		return

	_triggered_for_current_overlap = true
	player_centered.emit(_tracked_player)


func is_player_centered(player: PlayerController) -> bool:
	if player == null:
		return false
	if require_grounded and not player.is_on_floor():
		return false
	return absf(player.global_position.x - center_target.global_position.x) <= horizontal_tolerance


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		_tracked_player = body as PlayerController
		_triggered_for_current_overlap = false


func _on_body_exited(body: Node2D) -> void:
	if body == _tracked_player:
		_tracked_player = null
		_triggered_for_current_overlap = false
