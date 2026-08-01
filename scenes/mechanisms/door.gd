@tool
class_name Door
extends StaticBody2D

enum ActivationRule {
	ALL_ACTIVE,
	ANY_ACTIVE,
}

@export_category("Configuration")
@export var pressure_plates: Array[PressurePlate] = []
@export var activation_rule: ActivationRule = ActivationRule.ANY_ACTIVE
@export var is_open_initial: bool = false

@export_category("Appearance")
@export var door_size: Vector2 = Vector2(28.0, 120.0):
	set(value):
		door_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_apply_appearance()

@export var door_color: Color = Color(0.82, 0.3, 0.22, 1.0):
	set(value):
		door_color = value
		_apply_appearance()

var is_open: bool = is_open_initial


func _ready() -> void:
	_apply_appearance()
	if Engine.is_editor_hint():
		return

	assert(not pressure_plates.is_empty(), "Door requires at least one PressurePlate reference.")
	add_to_group(&"resettable")
	for pressure_plate in pressure_plates:
		assert(pressure_plate != null, "Door pressure_plates cannot contain null entries.")
		if not pressure_plate.activation_changed.is_connected(_on_plate_activation_changed):
			pressure_plate.activation_changed.connect(_on_plate_activation_changed)
	_sync_from_pressure_plates()


func capture_state() -> Variant:
	return is_open


func restore_state(state: Variant) -> void:
	_set_open(bool(state))


func _on_plate_activation_changed(_active: bool) -> void:
	_sync_from_pressure_plates()


func _sync_from_pressure_plates() -> void:
	var condition_met := activation_rule == ActivationRule.ALL_ACTIVE
	for pressure_plate in pressure_plates:
		if pressure_plate == null:
			continue
		if activation_rule == ActivationRule.ALL_ACTIVE:
			condition_met = condition_met and pressure_plate.is_active
		else:
			condition_met = condition_met or pressure_plate.is_active
	_set_open(condition_met != is_open_initial)


func _set_open(open: bool) -> void:
	if is_open == open and is_node_ready():
		_apply_state()
		return
	is_open = open
	if is_node_ready():
		_apply_state()


func _apply_state() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var visual := get_node_or_null("Visual") as Polygon2D
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", is_open)
	if visual != null:
		visual.modulate = Color(1.0, 1.0, 1.0, 0.18) if is_open else Color.WHITE


func _apply_appearance() -> void:
	var half_width := door_size.x * 0.5

	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.polygon = PackedVector2Array([
			Vector2(-half_width, 0.0),
			Vector2(half_width, 0.0),
			Vector2(half_width, -door_size.y),
			Vector2(-half_width, -door_size.y),
		])
		visual.color = door_color

	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.position = Vector2(0.0, -door_size.y * 0.5)
		var rectangle := collision_shape.shape as RectangleShape2D
		if rectangle != null:
			rectangle.size = door_size

	var label := get_node_or_null("Label") as Label
	if label != null:
		var label_half_width := maxf(36.0, half_width)
		label.offset_left = -label_half_width
		label.offset_right = label_half_width
		label.offset_top = -door_size.y - 34.0
		label.offset_bottom = -door_size.y - 10.0
