extends SceneTree


func _init() -> void:
	var queue := RecordingQueueV2.new(2)
	var first := _make_segment(&"FIRST")
	var second := _make_segment(&"SECOND")
	var rejected := _make_segment(&"REJECTED")

	assert(queue.capacity == 2, "RecordingQueueV2 did not preserve its configured capacity.")
	assert(queue.try_push(first), "The first queue push failed.")
	assert(queue.try_push(second), "The second queue push failed.")
	assert(queue.is_full(), "A two-element queue did not report full.")
	assert(not queue.try_push(rejected), "A fixed-size queue accepted an element past capacity.")
	assert(queue.pop_front() == first, "RecordingQueueV2 must pop in FIFO order.")
	assert(queue.pop_front() == second, "RecordingQueueV2 returned the wrong second element.")
	assert(queue.is_empty(), "RecordingQueueV2 did not become empty after both pops.")

	assert(queue.try_push(first), "Queue could not be reused after popping.")
	queue.clear()
	assert(queue.is_empty(), "RecordingQueueV2.clear() did not empty the queue.")
	print("V2 recording queue tests passed: capacity, FIFO pop, reuse, and clear.")
	quit(0)


func _make_segment(id: StringName) -> RecordedSegment:
	var segment := RecordedSegment.new()
	segment.start_anchor_id = id
	segment.end_anchor_id = id
	segment.duration = 1.0
	var first_frame := RecordedFrame.new()
	first_frame.timestamp = 0.0
	segment.frames.append(first_frame)
	var last_frame := first_frame.duplicate_frame()
	last_frame.timestamp = 1.0
	segment.frames.append(last_frame)
	return segment
