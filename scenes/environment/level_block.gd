@tool
class_name LevelBlock
extends StaticBody2D

@export var size: Vector2 = Vector2(160.0, 28.0):
	set(value):
		size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_refresh()

@export var block_color: Color = Color(0.33, 0.36, 0.42, 1.0):
	set(value):
		block_color = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return

	var collision_shape := $CollisionShape2D as CollisionShape2D
	var rectangle := collision_shape.shape as RectangleShape2D
	rectangle.size = size

	var half_size := size * 0.5
	var visual := $Visual as Polygon2D
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	visual.color = block_color
