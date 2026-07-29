class_name AnchorProgressEntry
extends RefCounted

var anchor_id: StringName = &""
var player_spawn_transform: Transform2D = Transform2D.IDENTITY
var incoming_segment: RecordedSegment
var level_snapshot: AttemptSnapshot


static func create(
	for_anchor: Anchor,
	segment_ending_here: RecordedSegment = null,
	snapshot_at_anchor: AttemptSnapshot = null
) -> AnchorProgressEntry:
	assert(for_anchor != null, "AnchorProgressEntry requires an Anchor.")
	var entry := AnchorProgressEntry.new()
	entry.anchor_id = for_anchor.anchor_id
	entry.player_spawn_transform = for_anchor.get_spawn_transform()
	entry.incoming_segment = segment_ending_here
	entry.level_snapshot = snapshot_at_anchor
	return entry
