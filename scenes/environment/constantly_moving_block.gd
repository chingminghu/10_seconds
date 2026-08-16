@tool
class_name ConstantlyMovingBlock
extends Node2D

enum MovingType {
	CIRCULAR,
	POLYGON,
	STRAIGHT_LINE,
}

@export var moving_type: MovingType = MovingType.STRAIGHT_LINE:
	set(value):
		if moving_type == value:
			return
		_stop_straight_tween()
		moving_type = value
		notify_property_list_changed()
		_set_curve_point(moving_type)

@export_range(0.0, 500.0, 0.1, "suffix:px/s") var moving_speed: float = 64.0:
	set(value):
		moving_speed = maxf(value, 0.0)
		if is_node_ready():
			_start_straight_tween()

@export_range(0, 100, 1, "suffix:%") var init_progress: int = 0:
	set(value):
		if init_progress == value:
			return
		init_progress = value
		_apply_initial_progress()


@export_category("Path Settings")
@export_range(0.0, 2000.0, 1.0, "suffix:px") var circular_radius: float = 100.0:
	set(value):
		if circular_radius == value:
			return
		circular_radius = value
		if moving_type == MovingType.CIRCULAR:
			_set_curve_point(MovingType.CIRCULAR)

@export_range(8, 64, 1) var point_number: int = 32:
	set(value):
		if point_number == value:
			return
		point_number = value
		if moving_type == MovingType.CIRCULAR:
			_set_curve_point(MovingType.CIRCULAR)

@export var clockwise: bool = false:
	set(value):
		if clockwise == value:
			return
		clockwise = value
		if moving_type == MovingType.CIRCULAR:
			_set_curve_point(MovingType.CIRCULAR)

@export var polygon_points: PackedVector2Array = PackedVector2Array([
	Vector2.ZERO,
	Vector2(100.0, 0.0),
	Vector2(100.0, 100.0),
]):
	set(value):
		polygon_points = value
		if moving_type == MovingType.POLYGON:
			_set_curve_point(MovingType.POLYGON)

@export var straight_end_point: Vector2 = Vector2(200.0, 0.0):
	set(value):
		straight_end_point = value
		if moving_type == MovingType.STRAIGHT_LINE:
			_set_curve_point(MovingType.STRAIGHT_LINE)

@export_category("Straight Line Tween")
@export var straight_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var straight_ease: Tween.EaseType = Tween.EASE_IN_OUT

func _validate_property(property: Dictionary) -> void:
	var should_show := true

	match property.name:
		&"circular_radius", &"point_number", &"clockwise":
			should_show = moving_type == MovingType.CIRCULAR

		&"polygon_points":
			should_show = moving_type == MovingType.POLYGON

		&"straight_end_point", &"straight_transition", &"straight_ease":
			should_show = moving_type == MovingType.STRAIGHT_LINE

	if not should_show:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _set_curve_point(type: MovingType) -> void:
	var path := get_node_or_null("Path2D") as Path2D
	if path == null:
		return
	if path.curve == null:
		path.curve = Curve2D.new()

	path.curve.clear_points()
	match type:
		MovingType.STRAIGHT_LINE:
			path.curve.add_point(Vector2.ZERO)
			path.curve.add_point(straight_end_point)

		MovingType.POLYGON:
			for point in polygon_points:
				path.curve.add_point(point)
			if polygon_points.size() >= 2 and polygon_points[0] != polygon_points[-1]:
				path.curve.add_point(polygon_points[0])

		MovingType.CIRCULAR:
			var dir = 1.0 if clockwise else -1.0
			for i in range(point_number):
				var angle = (i / float(point_number)) * TAU * dir
				var pos = Vector2(cos(angle), sin(angle)) * circular_radius
				path.curve.add_point(pos)
			path.curve.add_point(Vector2(1, 0) * circular_radius)

	var path_follow := get_node_or_null("Path2D/PathFollow2D") as PathFollow2D
	if path_follow != null:
		path_follow.loop = type != MovingType.STRAIGHT_LINE
		_apply_initial_progress()
	if is_node_ready():
		_start_straight_tween()


@onready var moving_path: Path2D = $Path2D
@onready var follower: PathFollow2D = $Path2D/PathFollow2D
var path_length: float = 0.0
var can_move: bool = false
var _straight_direction: int = 1
var _straight_tween: Tween


func _ready() -> void:
	# Exported properties can be applied before this scene's child nodes exist, so
	# rebuild once more after Path2D and PathFollow2D are guaranteed to be ready.
	if Engine.is_editor_hint():
		return
	
	assert(moving_path.curve != null, "Moving Block requires a path.")
	path_length = moving_path.curve.get_baked_length()
	assert(path_length > 0, "Moving Path needs to be greater than 0.")
	assert(moving_speed > 0, "Moving Speed needs to be greater than 0.")
	_set_curve_point(moving_type)
	_apply_initial_progress()
	add_to_group(&"resettable")


func capture_state() -> Variant:
	return {
		&"progress": follower.progress,
		&"straight_direction": _straight_direction,
	}

func restore_state(state: Variant) -> void:
	_stop_straight_tween()
	can_move = false
	if state is Dictionary:
		follower.progress = clampf(float(state.get(&"progress", 0.0)), 0.0, path_length)
		_straight_direction = signi(int(state.get(&"straight_direction", 1)))
		if is_zero_approx(_straight_direction):
			_straight_direction = 1
	else:
		# Backwards compatibility with snapshots captured before direction was saved.
		follower.progress = clampf(float(state), 0.0, path_length)
		_straight_direction = 1

func begin_attempt() -> void:
	can_move = true
	_start_straight_tween()

func end_attempt() -> void:
	can_move = false
	_stop_straight_tween()


func _physics_process(delta: float) -> void:
	if not can_move:
		return

	if moving_type != MovingType.STRAIGHT_LINE:
		follower.progress = fposmod(follower.progress + moving_speed * delta, path_length)

func _apply_initial_progress() -> void:
	var path_follow := get_node_or_null("Path2D/PathFollow2D") as PathFollow2D
	if path_follow != null:
		path_follow.progress_ratio = float(init_progress) / 100.0


func _start_straight_tween() -> void:
	_stop_straight_tween()
	if Engine.is_editor_hint() or not can_move or moving_type != MovingType.STRAIGHT_LINE:
		return

	var target_progress := path_length if _straight_direction >= 0 else 0.0
	if is_equal_approx(follower.progress, target_progress):
		_straight_direction *= -1
		target_progress = path_length if _straight_direction >= 0 else 0.0

	var travel_distance := absf(target_progress - follower.progress)
	if is_zero_approx(travel_distance):
		return

	var travel_duration := travel_distance / moving_speed
	_straight_tween = create_tween()
	_straight_tween.bind_node(self)
	_straight_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var movement := _straight_tween.tween_property(
		follower,
		^"progress",
		target_progress,
		travel_duration
	)
	movement.set_trans(straight_transition)
	movement.set_ease(straight_ease)
	_straight_tween.finished.connect(_on_straight_tween_finished)

func _stop_straight_tween() -> void:
	if _straight_tween == null:
		return
	if _straight_tween.is_valid():
		_straight_tween.kill()
	_straight_tween = null

func _on_straight_tween_finished() -> void:
	_straight_tween = null
	if not can_move or moving_type != MovingType.STRAIGHT_LINE:
		return
	_straight_direction *= -1
	_start_straight_tween()
