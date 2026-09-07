# src/sim/core/event_queue.gd
class_name EventQueue
extends RefCounted

var _next_event_id: int = 1
var _events_by_tick: Dictionary = {}    # int target_tick -> Array[Dictionary]
var _event_id_to_tick: Dictionary = {}  # int event_id -> int target_tick

func _init() -> void:
	clear()

func clear() -> void:
	_next_event_id = 1
	_events_by_tick.clear()
	_event_id_to_tick.clear()

func schedule_event(target_tick: int, event_type: String, data: Dictionary = {}) -> int:
	var event_id: int = _next_event_id
	_next_event_id += 1
	
	var event_entry: Dictionary = {
		"id": event_id,
		"target_tick": target_tick,
		"type": event_type,
		"data": data
	}
	
	if not _events_by_tick.has(target_tick):
		_events_by_tick[target_tick] = []
	_events_by_tick[target_tick].append(event_entry)
	_event_id_to_tick[event_id] = target_tick
	
	return event_id

func schedule_delay(current_tick: int, delay_ticks: int, event_type: String, data: Dictionary = {}) -> int:
	var target_tick: int = current_tick + maxi(0, delay_ticks)
	return schedule_event(target_tick, event_type, data)

func cancel_event(event_id: int) -> bool:
	if not _event_id_to_tick.has(event_id):
		return false
	
	var target_tick: int = _event_id_to_tick[event_id]
	_event_id_to_tick.erase(event_id)
	
	if _events_by_tick.has(target_tick):
		var list: Array = _events_by_tick[target_tick]
		for i in range(list.size() - 1, -1, -1):
			if list[i]["id"] == event_id:
				list.remove_at(i)
				break
		if list.is_empty():
			_events_by_tick.erase(target_tick)
	
	return true

## Pops and returns all events scheduled for target_tick <= current_tick in chronological and registration order
func pop_due_events(current_tick: int) -> Array[Dictionary]:
	var due_events: Array[Dictionary] = []
	
	var ticks_to_process: Array[int] = []
	for tick_val in _events_by_tick.keys():
		var t: int = int(tick_val)
		if t <= current_tick:
			ticks_to_process.append(t)
	ticks_to_process.sort()
	
	for t in ticks_to_process:
		var events_at_t: Array = _events_by_tick[t]
		for ev in events_at_t:
			due_events.append(ev)
			_event_id_to_tick.erase(ev["id"])
		_events_by_tick.erase(t)
	
	return due_events

func peek_due_events(current_tick: int) -> Array[Dictionary]:
	var due_events: Array[Dictionary] = []
	var ticks_to_process: Array[int] = []
	for tick_val in _events_by_tick.keys():
		var t: int = int(tick_val)
		if t <= current_tick:
			ticks_to_process.append(t)
	ticks_to_process.sort()
	
	for t in ticks_to_process:
		var events_at_t: Array = _events_by_tick[t]
		for ev in events_at_t:
			due_events.append(ev)
			
	return due_events

func get_event_count() -> int:
	return _event_id_to_tick.size()

func get_all_events() -> Array[Dictionary]:
	var all_events: Array[Dictionary] = []
	var ticks: Array[int] = []
	for k in _events_by_tick.keys():
		ticks.append(int(k))
	ticks.sort()
	for t in ticks:
		for ev in _events_by_tick[t]:
			all_events.append(ev)
	return all_events

func serialize() -> Dictionary:
	return {
		"next_event_id": _next_event_id,
		"events": get_all_events()
	}

func deserialize(data: Dictionary) -> void:
	clear()
	_next_event_id = data.get("next_event_id", 1)
	var events_arr: Array = data.get("events", [])
	for ev in events_arr:
		var target_tick: int = ev.get("target_tick", 0)
		var ev_id: int = ev.get("id", 0)
		var ev_type: String = ev.get("type", "")
		var ev_data: Dictionary = ev.get("data", {})
		
		if not _events_by_tick.has(target_tick):
			_events_by_tick[target_tick] = []
		var entry: Dictionary = {
			"id": ev_id,
			"target_tick": target_tick,
			"type": ev_type,
			"data": ev_data
		}
		_events_by_tick[target_tick].append(entry)
		_event_id_to_tick[ev_id] = target_tick
