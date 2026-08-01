@tool
class_name Gate
extends StaticBody2D

@export_category("Configuration")
@export var toggle_pads: Array[TogglePad] = []
@export var is_open_initial: bool = false

@export_category("Appearance")
@export var size: Vector2 = Vector2(28.0, 120.0):
	set(value):
		size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_apply_appearance()

@export var gate_color: Color = Color(0.82, 0.3, 0.22, 1.0):
	set(value):
		gate_color = value
		_apply_appearance()

var is_open: bool = is_open_initial


func _ready() -> void:
	_apply_appearance()
	if Engine.is_editor_hint():
		return

	assert(not toggle_pads.is_empty(), "Gate requires at least one TogglePad reference.")
	add_to_group(&"resettable")
	for toggle_pad in toggle_pads:
		assert(toggle_pad != null, "Gate toggle_pads cannot contain null entries.")
		if not toggle_pad.toggled.is_connected(_on_pad_toggled):
			toggle_pad.toggled.connect(_on_pad_toggled)
	_set_open(is_open_initial)


func capture_state() -> Variant:
	return is_open


func restore_state(state: Variant) -> void:
	_set_open(bool(state))


func _on_pad_toggled() -> void:
	# Every configured Pad emits the same action pulse; any one of them toggles
	# this Gate exactly once.
	_set_open(!is_open)


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
	var half_width := size.x * 0.5

	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.polygon = PackedVector2Array([
			Vector2(-half_width, 0.0),
			Vector2(half_width, 0.0),
			Vector2(half_width, -size.y),
			Vector2(-half_width, -size.y),
		])
		visual.color = gate_color
	
	var visualInner := visual.get_node_or_null("VisualInner") as Polygon2D
	if visualInner != null:
		visualInner.transform = Transform2D.IDENTITY

		var maximum_inset := maxf(0.0,minf(size.x, size.y) * 0.5 - 0.5)
		var inset := minf(8, maximum_inset)

		visualInner.polygon = PackedVector2Array([
			Vector2(-half_width + inset, -inset),
			Vector2(half_width - inset, -inset),
			Vector2(half_width - inset, -size.y + inset),
			Vector2(-half_width + inset, -size.y + inset),
		])

	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.position = Vector2(0.0, -size.y * 0.5)
		var rectangle := collision_shape.shape as RectangleShape2D
		if rectangle != null:
			rectangle.size = size

	var label := get_node_or_null("Label") as Label
	if label != null:
		var label_half_width := maxf(36.0, half_width)
		label.offset_left = -label_half_width
		label.offset_right = label_half_width
		label.offset_top = -size.y - 34.0
		label.offset_bottom = -size.y - 10.0
