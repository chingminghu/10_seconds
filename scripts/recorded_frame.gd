class_name RecordedFrame
extends RefCounted

var timestamp: float = 0.0
var global_position: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var facing_direction: int = 1
var visual_scale: Vector2 = Vector2.ONE
var animation_name: StringName = &""
var animation_position: float = 0.0


func duplicate_frame() -> RecordedFrame:
	var copy := RecordedFrame.new()
	copy.timestamp = timestamp
	copy.global_position = global_position
	copy.rotation = rotation
	copy.facing_direction = facing_direction
	copy.visual_scale = visual_scale
	copy.animation_name = animation_name
	copy.animation_position = animation_position
	return copy


static func interpolate_frames(from: RecordedFrame, to: RecordedFrame, weight: float, sample_time: float) -> RecordedFrame:
	var result := RecordedFrame.new()
	var clamped_weight := clampf(weight, 0.0, 1.0)
	result.timestamp = sample_time
	result.global_position = from.global_position.lerp(to.global_position, clamped_weight)
	result.rotation = lerp_angle(from.rotation, to.rotation, clamped_weight)

	# Discrete presentation state switches at the midpoint while transform data
	# remains smoothly interpolated.
	var presentation_source := from if clamped_weight < 0.5 else to
	result.facing_direction = presentation_source.facing_direction
	result.visual_scale = Vector2(
		presentation_source.visual_scale.x,
		lerpf(from.visual_scale.y, to.visual_scale.y, clamped_weight)
	)
	result.animation_name = presentation_source.animation_name
	result.animation_position = lerpf(from.animation_position, to.animation_position, clamped_weight)
	return result
