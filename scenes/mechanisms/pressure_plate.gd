@tool
class_name PressurePlate
extends Area2D

signal activation_changed(active: bool)

@export_category("Geometry")
@export_range(8.0, 512.0, 1.0, "suffix:px") var width: float = 44.0:
	set(value):
		width = maxf(value, 8.0)
		_apply_geometry()

@export_category("Appearance")
@export var plate_color: Color = Color(1.0, 0.35, 0.25, 1.0):
	set(value):
		plate_color = value
		_apply_visual_state()

var is_active: bool = false


func _ready() -> void:
	_apply_geometry()
	_apply_visual_state()
	if Engine.is_editor_hint():
		return

	add_to_group(&"resettable")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_set_active(not get_overlapping_bodies().is_empty())


func capture_state() -> Variant:
	return is_active


func restore_state(state: Variant) -> void:
	_set_active(bool(state))


func _set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	_apply_visual_state()
	activation_changed.emit(is_active)


func _apply_visual_state() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.modulate = Color(1.0, 1.0, 1.0, 0.4) if is_active else Color.WHITE


func _apply_geometry() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		var rectangle := collision_shape.shape as RectangleShape2D
		if rectangle != null:
			rectangle.size.x = width

	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		var half_width := width * 0.5
		var corner_inset := minf(4.0, width * 0.25)
		visual.polygon = PackedVector2Array([
			Vector2(-half_width, 0.0),
			Vector2(half_width, 0.0),
			Vector2(half_width - corner_inset, -8.0),
			Vector2(-half_width + corner_inset, -8.0),
		])
		visual.color = plate_color
