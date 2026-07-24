class_name Anchor
extends Area2D

signal player_arrived(anchor: Anchor)

@export var anchor_id: StringName
@export var order_index: int = 0
@export var player_spawn_offset: Vector2 = Vector2.ZERO
@export var is_start_anchor: bool = false

@onready var _indicator: Polygon2D = $Indicator
@onready var _label: Label = $Label
@onready var _arrival_detector: CenteredArrivalDetector = $CenteredArrivalDetector


func _ready() -> void:
	_arrival_detector.player_centered.connect(_on_player_centered)
	_label.text = str(anchor_id)
	set_active_visual(is_start_anchor)


func get_spawn_transform() -> Transform2D:
	var spawn_transform := global_transform
	spawn_transform.origin += player_spawn_offset
	return spawn_transform


func set_active_visual(active: bool) -> void:
	if not is_node_ready():
		return
	_indicator.color = Color(1.0, 0.82, 0.25, 0.95) if active else Color(0.35, 0.38, 0.45, 0.75)


func _on_player_centered(_player: PlayerController) -> void:
	player_arrived.emit(self)
