class_name RecordingQueueV2
extends RefCounted

signal changed(current_size: int, capacity: int)

var capacity: int
var _items: Array[RecordedSegment] = []


func _init(maximum_size: int = 1) -> void:
	capacity = maxi(maximum_size, 1)


func size() -> int:
	return _items.size()


func is_empty() -> bool:
	return _items.is_empty()


func is_full() -> bool:
	return _items.size() >= capacity


func try_push(segment: RecordedSegment) -> bool:
	if segment == null or is_full():
		return false
	_items.push_back(segment)
	changed.emit(_items.size(), capacity)
	return true


func peek_front() -> RecordedSegment:
	return null if _items.is_empty() else _items[0]


func pop_front() -> RecordedSegment:
	if _items.is_empty():
		return null
	var segment: RecordedSegment = _items.pop_front()
	changed.emit(_items.size(), capacity)
	return segment


func remove(segment: RecordedSegment) -> bool:
	var index := _items.find(segment)
	if index < 0:
		return false
	_items.remove_at(index)
	changed.emit(_items.size(), capacity)
	return true


func clear() -> void:
	_items.clear()
	changed.emit(0, capacity)
