class_name Door
extends StaticBody2D

@export var pressure_plate: PressurePlate

var is_open: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	assert(pressure_plate != null, "Door requires a PressurePlate reference.")
	add_to_group(&"resettable")
	pressure_plate.activation_changed.connect(_on_plate_activation_changed)
	_set_open(pressure_plate.is_active)


func capture_state() -> Variant:
	return is_open


func restore_state(state: Variant) -> void:
	_set_open(bool(state))


func _on_plate_activation_changed(active: bool) -> void:
	_set_open(active)


func _set_open(open: bool) -> void:
	if is_open == open and is_node_ready():
		_apply_state()
		return
	is_open = open
	if is_node_ready():
		_apply_state()


func _apply_state() -> void:
	_collision_shape.set_deferred(&"disabled", is_open)
	_visual.modulate = Color(1.0, 1.0, 1.0, 0.18) if is_open else Color.WHITE

