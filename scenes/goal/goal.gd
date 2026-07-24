class_name LevelGoal
extends Area2D

signal player_reached_goal


func _ready() -> void:
	$CenteredArrivalDetector.player_centered.connect(_on_player_centered)


func _on_player_centered(_player: PlayerController) -> void:
	player_reached_goal.emit()
