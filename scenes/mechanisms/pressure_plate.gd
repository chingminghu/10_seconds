class_name PressurePlate
extends Area2D

signal activation_changed(active: bool)

var is_active: bool = false

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group(&"resettable")


func _physics_process(_delta: float) -> void:
	_set_active(not get_overlapping_bodies().is_empty())


func capture_state() -> Variant:
	return is_active


func restore_state(state: Variant) -> void:
	_set_active(bool(state))


func _set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	_visual.color = Color(1.0, 0.35, 0.25, 1.0) if is_active else Color(0.55, 0.18, 0.16, 1.0)
	activation_changed.emit(is_active)

