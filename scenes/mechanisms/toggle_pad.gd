@tool
class_name TogglePad
extends Area2D

signal toggled()

@export_category("Geometry")
@export_range(8.0, 512.0, 1.0, "suffix:px") var width: float = 44.0:
	set(value):
		width = maxf(value, 8.0)
		_apply_geometry()

@export_category("Appearance")
@export var pad_color: Color = Color(1.0, 0.35, 0.25, 1.0):
	set(value):
		pad_color = value
		_apply_visual_state()

var was_pressed: bool = false
var _attempt_active: bool = false


func _ready() -> void:
	_apply_geometry()
	_apply_visual_state()
	if Engine.is_editor_hint():
		return

	add_to_group(&"resettable")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _attempt_active:
		return

	var is_pressed: bool = not get_overlapping_bodies().is_empty()
	if is_pressed and not was_pressed:
		toggled.emit()
	_set_pressed(is_pressed)


func begin_attempt() -> void:
	# Objects restored onto the Pad establish its initial occupancy; they did not
	# enter during this attempt and must not emit a toggle pulse.
	_set_pressed(not get_overlapping_bodies().is_empty())
	_attempt_active = true


func end_attempt() -> void:
	_attempt_active = false

func capture_state() -> Variant:
	return was_pressed

func restore_state(state: Variant) -> void:
	# Physics overlap data is refreshed after transforms are restored. Keep edge
	# detection disabled until begin_attempt() establishes the new baseline.
	_attempt_active = false
	_set_pressed(bool(state))

func _set_pressed(is_pressed: bool) -> void:
	if was_pressed == is_pressed:
		return
	was_pressed = is_pressed
	_apply_visual_state()


func _apply_visual_state() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.modulate = Color(1.0, 1.0, 1.0, 0.4) if was_pressed else Color.WHITE


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
		visual.color = pad_color
