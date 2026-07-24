class_name SnapshotController
extends Node

@export var snapshot_root: Node


func _ready() -> void:
	assert(snapshot_root != null, "SnapshotController requires a snapshot root.")


func capture_snapshot() -> AttemptSnapshot:
	var snapshot := AttemptSnapshot.new()
	for candidate in get_tree().get_nodes_in_group(&"resettable"):
		if not _belongs_to_snapshot_root(candidate):
			continue
		assert(candidate.has_method(&"capture_state"), "Resettable objects must implement capture_state().")
		assert(candidate.has_method(&"restore_state"), "Resettable objects must implement restore_state().")
		snapshot.object_states[candidate] = candidate.call(&"capture_state")
	return snapshot


func restore_snapshot(snapshot: AttemptSnapshot) -> void:
	assert(snapshot != null, "Cannot restore a null AttemptSnapshot.")
	for candidate: Variant in snapshot.object_states:
		if not is_instance_valid(candidate):
			push_warning("A resettable object was removed before its Attempt Snapshot could be restored.")
			continue
		candidate.call(&"restore_state", snapshot.object_states[candidate])


func _belongs_to_snapshot_root(candidate: Node) -> bool:
	return candidate == snapshot_root or snapshot_root.is_ancestor_of(candidate)

