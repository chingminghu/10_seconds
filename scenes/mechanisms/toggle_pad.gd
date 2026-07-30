@tool
class_name TogglePad
extends Area2D

signal toggled()

@export_category("Appearance")
@export var pad_color: Color = Color(1.0, 0.35, 0.25, 1.0):
	set(value):
		pad_color = value
		_apply_visual_state()

var is_active: bool = false

func _ready() -> void:
	_apply_visual_state()
	if Engine.is_editor_hint():
		return

	add_to_group(&"resettable")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	#is_pressed = not get_overlapping_bodies().is_empty()

func _on_body_entered(body: Node2D) -> void:
	if get_overlapping_bodies().size() == 1:
		_set_active(!is_active)

func capture_state() -> Variant:
	return is_active

func restore_state(state: Variant) -> void:
	_set_active(bool(state))

func _set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	_apply_visual_state()
	toggled.emit()


func _apply_visual_state() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.color = pad_color
		visual.modulate = Color(1.0, 1.0, 1.0, 0.4) if is_active else Color.WHITE
