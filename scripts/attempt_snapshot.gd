class_name AttemptSnapshot
extends RefCounted

var object_states: Dictionary = {}


func is_empty() -> bool:
	return object_states.is_empty()

