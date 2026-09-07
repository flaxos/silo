class_name SpatialTravelModel
extends RefCounted

## Deterministic authoritative pedestrian travel over the silo's central stair.
## All mutable state is plain data in WorldState.custom_data so saves, checksums,
## observer reads, and replay see the same truth.

const STATE_KEY: String = "spatial_travel"
const SEGMENT_CAPACITY: int = 64
const SEGMENT_TRAVEL_TICKS: int = 1

static func initialize(ws: WorldState) -> Dictionary:
	var levels: Array[int] = _levels(ws)
	var segments: Dictionary = {}
	for i in range(maxi(0, levels.size() - 1)):
		var low: int = levels[i]
		var high: int = levels[i + 1]
		var segment_id: String = segment_id_for(low, high)
		segments[segment_id] = {
			"id": segment_id, "from_level": low, "to_level": high,
			"capacity": SEGMENT_CAPACITY, "base_travel_ticks": SEGMENT_TRAVEL_TICKS,
			"occupants": {}, "queue": [], "peak_occupancy": 0,
			"total_queue_ticks": 0
		}
	var state: Dictionary = {
		"version": 1, "segments": segments, "journeys": {},
		"active_person_ids": [],
		"completed_journeys": 0, "maximum_queue": 0
	}
	ws.custom_data[STATE_KEY] = state
	return state

static func get_state(ws: WorldState) -> Dictionary:
	var state: Variant = ws.custom_data.get(STATE_KEY, null)
	if not state is Dictionary or not state.has("segments"):
		return initialize(ws)
	return state

static func segment_id_for(level_a: int, level_b: int) -> String:
	return "stair_%d_%d" % [mini(level_a, level_b), maxi(level_a, level_b)]

static func route_between_levels(from_level: int, to_level: int) -> Array[String]:
	var route: Array[String] = []
	if from_level == to_level:
		return route
	var direction: int = 1 if to_level > from_level else -1
	var level: int = from_level
	while level != to_level:
		route.append(segment_id_for(level, level + direction))
		level += direction
	return route

static func compute_base_ticks(ws: WorldState, from_room_id: int, to_room_id: int) -> int:
	if from_room_id == to_room_id or from_room_id <= 0 or to_room_id <= 0:
		return 0
	var from_room: Room = ws.entity_registry.get_entity(from_room_id) as Room
	var to_room: Room = ws.entity_registry.get_entity(to_room_id) as Room
	if not from_room or not to_room:
		return 0
	var local_ticks: int = 1 + abs(from_room.sector_id - to_room.sector_id)
	if from_room.level == to_room.level:
		return local_ticks
	return local_ticks + 1 + abs(from_room.level - to_room.level) * SEGMENT_TRAVEL_TICKS

static func begin_journey(ws: WorldState, person: Person, destination_id: int, target_activity: int) -> void:
	var from_room: Room = ws.entity_registry.get_entity(person.current_location_id) as Room
	var to_room: Room = ws.entity_registry.get_entity(destination_id) as Room
	if not from_room or not to_room:
		person.current_activity = Person.ACTIVITY_IDLE
		person.target_location_id = 0
		person.travel_ticks_remaining = 0
		var warnings: Array = ws.custom_data.get("spatial_mapping_warnings", [])
		warnings.append({"person_id": person.id, "from_room_id": person.current_location_id, "to_room_id": destination_id})
		ws.custom_data["spatial_mapping_warnings"] = warnings
		return
	var total: int = compute_base_ticks(ws, from_room.id, to_room.id)
	if total <= 0:
		person.start_travel(destination_id, target_activity, 0)
		return
	var route: Array[String] = route_between_levels(from_room.level, to_room.level)
	person.start_travel(destination_id, target_activity, total)
	var state: Dictionary = get_state(ws)
	var journeys: Dictionary = state["journeys"]
	var active_ids: Array = state["active_person_ids"]
	if not active_ids.has(person.id):
		active_ids.append(person.id)
	var phase: String = "egress" if route.is_empty() else "approach"
	journeys[str(person.id)] = {
		"person_id": person.id, "origin_room_id": from_room.id,
		"destination_room_id": destination_id, "target_activity": target_activity,
		"from_level": from_room.level, "to_level": to_room.level,
		"route": route, "segment_index": -1, "phase": phase,
		"phase_ticks_remaining": total if route.is_empty() else 1 + abs(from_room.sector_id - to_room.sector_id),
		"base_travel_ticks": total, "elapsed_ticks": 0, "queue_ticks": 0
	}

static func step(ws: WorldState) -> void:
	var state: Dictionary = get_state(ws)
	var journeys: Dictionary = state["journeys"]
	var active_ids: Array = state.get("active_person_ids", [])
	var completed_ids: Array[int] = []

	# Progress and release first. Admissions occur only after every release, making
	# capacity independent of person iteration and queues strictly FIFO.
	for person_id_value in active_ids:
		var key: String = str(int(person_id_value))
		if not journeys.has(key):
			completed_ids.append(int(person_id_value))
			continue
		var journey: Dictionary = journeys[key]
		var person: Person = ws.entity_registry.get_entity(int(journey["person_id"])) as Person
		if not person or not person.is_alive:
			_remove_from_circulation(state, int(journey["person_id"]))
			journeys.erase(key)
			completed_ids.append(int(person_id_value))
			continue
		journey["elapsed_ticks"] = int(journey["elapsed_ticks"]) + 1
		match str(journey["phase"]):
			"approach", "egress":
				journey["phase_ticks_remaining"] = int(journey["phase_ticks_remaining"]) - 1
				if int(journey["phase_ticks_remaining"]) <= 0:
					if str(journey["phase"]) == "egress":
						_arrive(person, journey)
						journeys.erase(key)
						completed_ids.append(int(person_id_value))
						state["completed_journeys"] = int(state["completed_journeys"]) + 1
					else:
						_queue_next_segment(state, journey)
			"segment":
				journey["phase_ticks_remaining"] = int(journey["phase_ticks_remaining"]) - 1
				if int(journey["phase_ticks_remaining"]) <= 0:
					var route: Array = journey["route"]
					var idx: int = int(journey["segment_index"])
					var segment: Dictionary = state["segments"][route[idx]]
					segment["occupants"].erase(str(person.id))
					if idx + 1 >= route.size():
						journey["phase"] = "egress"
						journey["phase_ticks_remaining"] = 1
					else:
						_queue_next_segment(state, journey)
			"queued":
				journey["queue_ticks"] = int(journey["queue_ticks"]) + 1
				var route: Array = journey["route"]
				var next_idx: int = int(journey["segment_index"]) + 1
				var queued_segment: Dictionary = state["segments"][route[next_idx]]
				queued_segment["total_queue_ticks"] = int(queued_segment["total_queue_ticks"]) + 1
		_update_person_remaining(person, journey)

	_admit_queues(state, journeys, ws.entity_registry)
	for person_id in completed_ids:
		active_ids.erase(person_id)

static func _queue_next_segment(state: Dictionary, journey: Dictionary) -> void:
	var route: Array = journey["route"]
	var next_idx: int = int(journey["segment_index"]) + 1
	if next_idx >= route.size():
		journey["phase"] = "egress"
		journey["phase_ticks_remaining"] = 1
		return
	var segment: Dictionary = state["segments"][route[next_idx]]
	(segment["queue"] as Array).append(int(journey["person_id"]))
	journey["phase"] = "queued"
	state["maximum_queue"] = maxi(int(state["maximum_queue"]), (segment["queue"] as Array).size())

static func _admit_queues(state: Dictionary, journeys: Dictionary, registry: EntityRegistry) -> void:
	var segment_ids: Array = state["segments"].keys()
	segment_ids.sort()
	for segment_id in segment_ids:
		var segment: Dictionary = state["segments"][segment_id]
		var queue: Array = segment["queue"]
		var occupants: Dictionary = segment["occupants"]
		while not queue.is_empty() and occupants.size() < int(segment["capacity"]):
			var person_id: int = int(queue.pop_front())
			var key: String = str(person_id)
			if not journeys.has(key) or not registry.get_entity(person_id):
				continue
			var journey: Dictionary = journeys[key]
			journey["segment_index"] = int(journey["segment_index"]) + 1
			journey["phase"] = "segment"
			journey["phase_ticks_remaining"] = int(segment["base_travel_ticks"])
			occupants[key] = int(segment["base_travel_ticks"])
		segment["peak_occupancy"] = maxi(int(segment["peak_occupancy"]), occupants.size())

static func _update_person_remaining(person: Person, journey: Dictionary) -> void:
	var route: Array = journey["route"]
	var remaining_segments: int = maxi(0, route.size() - int(journey["segment_index"]) - 1)
	var remaining: int = maxi(1, int(journey["phase_ticks_remaining"]))
	if str(journey["phase"]) != "egress":
		remaining += remaining_segments * SEGMENT_TRAVEL_TICKS + 1
	person.travel_ticks_remaining = remaining

static func _arrive(person: Person, journey: Dictionary) -> void:
	person.current_location_id = int(journey["destination_room_id"])
	person.current_activity = int(journey["target_activity"])
	person.target_location_id = 0
	person.travel_ticks_remaining = 0
	person.target_activity_after_travel = Person.ACTIVITY_IDLE

static func _remove_from_circulation(state: Dictionary, person_id: int) -> void:
	for segment in state["segments"].values():
		segment["occupants"].erase(str(person_id))
		(segment["queue"] as Array).erase(person_id)

static func _levels(ws: WorldState) -> Array[int]:
	var seen: Dictionary = {}
	for room_id in ws.entity_registry.get_entities_by_type("room"):
		var room: Room = ws.entity_registry.get_entity(room_id) as Room
		if room:
			seen[room.level] = true
	var present: Array = seen.keys()
	present.sort()
	var result: Array[int] = []
	if present.is_empty():
		return result
	for level in range(int(present[0]), int(present[present.size() - 1]) + 1):
		result.append(level)
	return result
