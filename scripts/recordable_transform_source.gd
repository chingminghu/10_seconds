class_name RecordableTransformSource
extends Node

@export var target: Node2D
@export var facing_property: StringName = &"facing_direction"
@export var visual_target: Node2D
@export var animated_sprite: AnimatedSprite2D


func _ready() -> void:
	assert(target != null, "RecordableTransformSource requires a Node2D target.")


func capture_frame(timestamp: float) -> RecordedFrame:
	var frame := RecordedFrame.new()
	frame.timestamp = timestamp
	frame.global_position = target.global_position
	frame.rotation = target.global_rotation
	frame.facing_direction = _read_facing_direction()
	if visual_target != null:
		frame.visual_scale = visual_target.scale

	if animated_sprite != null:
		frame.animation_name = animated_sprite.animation
		frame.animation_position = animated_sprite.frame + animated_sprite.frame_progress

	return frame


func _read_facing_direction() -> int:
	if facing_property.is_empty():
		return 1

	var property_value: Variant = target.get(facing_property)
	if property_value == null:
		push_warning("Recordable target does not expose property '%s'." % facing_property)
		return 1
	var direction := signi(int(property_value))
	return direction if direction != 0 else 1
