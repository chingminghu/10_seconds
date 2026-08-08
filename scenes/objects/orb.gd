class_name Orb
extends Area2D

signal touch_requested(orb: Orb, player: PlayerController)

@export_range(1, 5, 1) var charge_amount: int = 1
@export var renewable: bool = true
@export_range(0.1, 10.0, 0.1, "suffix:s") var renewable_time: float = 2.0

var is_active: bool = true
var _attempt_active: bool = false
var renewable_timer: float = 0.0


func _ready() -> void:
	_apply_state()
	add_to_group(&"resettable")


func _physics_process(delta: float) -> void:
	if not _attempt_active or is_active or not renewable:
		return

	renewable_timer = maxf(renewable_timer - delta, 0.0)
	if is_zero_approx(renewable_timer):
		renewable_timer = 0.0
		_set_active(true)
		_request_touch_for_overlapping_player()


func _on_body_entered(body: Node2D) -> void:
	if _attempt_active and is_active and body is PlayerController:
		touch_requested.emit(self, body as PlayerController)


func begin_attempt() -> void:
	_attempt_active = true


func end_attempt() -> void:
	_attempt_active = false


func capture_state() -> Variant:
	return {
		&"is_active": is_active,
		&"renewable_timer": renewable_timer
	}

func restore_state(state: Variant) -> void:
	_attempt_active = false
	renewable_timer = maxf(float(state[&"renewable_timer"]), 0.0)
	_set_active(bool(state[&"is_active"]))


func touched() -> bool:
	if not _attempt_active or not is_active:
		return false
	_set_active(false)
	renewable_timer = renewable_time if renewable else 0.0
	return true


func _set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	_apply_state()

func _apply_state() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	var inner_mark := get_node_or_null("InnerMark") as Line2D
	if visual != null:
		visual.visible = is_active
	#if inner_mark != null:
		#inner_mark.visible = is_active


func _request_touch_for_overlapping_player() -> void:
	if not _attempt_active or not is_active:
		return
	for body in get_overlapping_bodies():
		if not is_active:
			return
		if body is PlayerController:
			touch_requested.emit(self, body as PlayerController)
