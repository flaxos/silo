class_name PhysicalReader
extends RefCounted

const SpatialModel = preload("res://src/sim/spatial/silo_spatial_model.gd")

static func get_snapshot(ws: WorldState, reset_revision: int = 0) -> Dictionary:
	var geometry: Dictionary = SpatialModel.build(ws)
	var registry: EntityRegistry = ws.entity_registry
	var people: Array[Dictionary] = []
	var households: Array[Dictionary] = []
	var rooms: Array[Dictionary] = []
	var warnings: Array[String] = []
	var room_ids: Array[int] = registry.get_entities_by_type("room").duplicate()
	room_ids.sort()
	for rid in room_ids:
		var summary: Dictionary = SimulationReader.get_room_summary(ws, rid)
		if not summary.is_empty(): rooms.append(summary)
	var household_ids: Array[int] = registry.get_entities_by_type("household").duplicate()
	household_ids.sort()
	for hid in household_ids:
		var h: Dictionary = SimulationReader.get_household_summary(ws, hid)
		if not h.is_empty(): households.append(h)
	var person_ids: Array[int] = registry.get_entities_by_type("person").duplicate()
	person_ids.sort()
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if not p: continue
		people.append(_person_identity(ws, p))
		if p.home_room_id <= 0 or not registry.get_entity(p.home_room_id) is Room:
			warnings.append("person:%d unresolved home_room:%d" % [p.id, p.home_room_id])
		if p.occupation_id not in ["unassigned", "none", "student"] and (p.workplace_room_id <= 0 or not registry.get_entity(p.workplace_room_id) is Room):
			warnings.append("person:%d unresolved workplace_room:%d" % [p.id, p.workplace_room_id])
	var clock: Dictionary = SimulationReader.get_clock_summary(ws)
	clock["checksum"] = str(clock["checksum"])
	return {
		"contract_version": 1, "reset_revision": reset_revision,
		"revision": ws.sim_clock.get_tick(), "seed": ws.initial_seed,
		"clock": clock, "geometry": geometry,
		"rooms": rooms, "households": households, "people": people,
		"machines": SimulationReader.get_machinery_summary(ws)["machines_list"],
		"capabilities": {"utilities": ["water"], "institutions": true, "incidents": true},
		"dependency_links": _dependency_links(ws), "unresolved_links": warnings
	}

static func get_updates(ws: WorldState, since_tick: int, reset_revision: int = 0, include_checksum: bool = true) -> Dictionary:
	var current_tick: int = ws.sim_clock.get_tick()
	var people: Array[Dictionary] = []
	var ids: Array[int] = ws.entity_registry.get_entities_by_type("person").duplicate()
	ids.sort()
	# State is tick-granular. A current revision response is intentionally empty.
	if since_tick < current_tick:
		for pid in ids:
			var p: Person = ws.entity_registry.get_entity(pid) as Person
			if p: people.append(_person_live(ws, p))
	var clock: Dictionary
	if include_checksum:
		clock = SimulationReader.get_clock_summary(ws)
		clock["checksum"] = str(clock["checksum"])
		clock["time"] = "%02d:%02d" % [clock.get("hour", 0), clock.get("minute", 0)]
	else:
		clock = {
			"tick": current_tick,
			"year": ws.sim_clock.get_year(),
			"day_of_year": ws.sim_clock.get_day_of_year(),
			"hour": ws.sim_clock.get_hour_of_day(),
			"minute": ws.sim_clock.get_minute_of_hour(),
			"formatted_time": ws.sim_clock.get_formatted_time(),
			"time": "%02d:%02d" % [ws.sim_clock.get_hour_of_day(), ws.sim_clock.get_minute_of_hour()]
		} 
	return {
		"reset_revision": reset_revision, "revision": current_tick,
		"clock": clock, "people": people, "removed_person_ids": [],
		"machines": SimulationReader.get_machinery_summary(ws)["machines_list"] if since_tick < current_tick else [],
		"incidents": get_incident_locations(ws),
		"utilities": SimulationReader.get_utilities_summary(ws),
		"institutions": SimulationReader.get_institutions_summary(ws),
		"stairs": get_stairs(ws)
	}

static func resolve_entity(ws: WorldState, type: String, id_text: String) -> Dictionary:
	var id: int = id_text.to_int()
	var details: Dictionary = {}
	match type:
		"stair":
			for stair in get_stairs(ws):
				if str(stair["id"]) == id_text: details = stair
		"person": details = get_person_details(ws, id)
		"household": details = SimulationReader.get_household_summary(ws, id)
		"room": details = get_room_details(ws, id)
		"machine": details = get_machine_details(ws, id)
		"incident": details = _find_by_id(SimulationReader.get_incidents_summary(ws).get("active_incidents", []), id)
		"resource": details = {"id": id_text, "economy": SimulationReader.get_economy_summary(ws)}
	if details.is_empty(): return {}
	var room_id: int = _resolve_room_id(ws, type, id, details)
	return {"type": type, "id": id_text, "room_id": room_id, "details": details}

static func search(ws: WorldState, query: String, limit: int = 30) -> Dictionary:
	var q: String = query.strip_edges().to_lower()
	var results: Array[Dictionary] = []
	if q.is_empty(): return {"query": query, "results": results}
	var registry: EntityRegistry = ws.entity_registry
	for pid in registry.get_entities_by_type("person"):
		var p: Person = registry.get_entity(pid) as Person
		if p and (str(p.id) == q or p.get_full_name().to_lower().contains(q)):
			results.append({"type": "person", "id": str(p.id), "label": p.get_full_name(), "room_id": p.current_location_id})
			if results.size() >= limit: return {"query": query, "results": results}
	for hid in registry.get_entities_by_type("household"):
		var h: Household = registry.get_entity(hid) as Household
		if h and (str(h.id) == q or h.name.to_lower().contains(q)):
			results.append({"type": "household", "id": str(h.id), "label": h.name, "room_id": h.home_room_id})
	for rid in registry.get_entities_by_type("room"):
		var r: Room = registry.get_entity(rid) as Room
		var label: String = SimulationReader.get_room_summary(ws, rid).get("room_type_name", "Room") + " " + str(rid)
		if str(rid) == q or label.to_lower().contains(q): results.append({"type": "room", "id": str(rid), "label": label, "room_id": rid})
	for mid in registry.get_entities_by_type("machine"):
		var m: Machine = registry.get_entity(mid) as Machine
		if m and (str(m.id) == q or m.machine_type.to_lower().contains(q)):
			results.append({"type": "machine", "id": str(m.id), "label": m.machine_type, "room_id": m.room_id})
	if results.size() > limit: results.resize(limit)
	return {"query": query, "results": results}

static func _person_identity(ws: WorldState, p: Person) -> Dictionary:
	var d: Dictionary = _person_live(ws, p)
	d.merge({"name": p.get_full_name(), "life_stage": p.get_life_stage_name(), "household_id": p.household_id,
		"home_room_id": p.home_room_id, "bed_id": p.bed_id, "workplace_room_id": p.workplace_room_id,
		"school_room_id": p.school_room_id, "occupation_id": p.occupation_id, "department_id": p.department_id,
		"schedule": _schedule_projection(p)})
	return d

static func _person_live(ws: WorldState, p: Person) -> Dictionary:
	var travel_state: Dictionary = ws.custom_data.get("spatial_travel", {})
	var journeys: Dictionary = travel_state.get("journeys", {})
	var journey: Dictionary = journeys.get(str(p.id), {})
	var total: int = int(journey.get("base_travel_ticks", 0))
	if total == 0 and p.current_activity == Person.ACTIVITY_TRAVELING:
		total = _travel_ticks(ws, p.current_location_id, p.target_location_id)
	return {"id": p.id, "location_id": p.current_location_id, "destination_id": p.target_location_id,
		"activity": p.get_activity_name().to_upper(), "is_alive": p.is_alive, "health": p.health_percent,
		"hydration": p.hydration_percent, "travel_ticks_remaining": p.travel_ticks_remaining,
		"travel_ticks_total": total, "travel_progress": clampf(1.0 - float(p.travel_ticks_remaining) / float(maxi(1, total)), 0.0, 1.0),
		"journey": journey.duplicate(true)}

static func _travel_ticks(ws: WorldState, from_id: int, to_id: int) -> int:
	if from_id == to_id or from_id <= 0 or to_id <= 0: return 0
	var from_room: Room = ws.entity_registry.get_entity(from_id) as Room
	var to_room: Room = ws.entity_registry.get_entity(to_id) as Room
	if not from_room or not to_room: return 0
	var ds: int = absi(from_room.sector_id - to_room.sector_id)
	var dl: int = absi(from_room.level - to_room.level)
	if ds == 0: return 1 if dl == 0 else 1 + dl / 5
	return 2 + ds + dl / 5

static func _schedule_projection(p: Person) -> Dictionary:
	# Named schedule slots mirror DailyLifeSystem's authoritative tick-of-day
	# contract and reference the person's actual assigned rooms.
	return {"source": "DailyLifeSystem", "shift_id": p.shift_id,
		"home_room_id": p.home_room_id, "workplace_room_id": p.workplace_room_id,
		"school_room_id": p.school_room_id, "canteen_room_id": p.canteen_room_id}

static func _dependency_links(ws: WorldState) -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	var machines: Array = SimulationReader.get_machinery_summary(ws)["machines_list"]
	for m in machines:
		if int(m.get("room_id", 0)) > 0:
			links.append({"kind": "system_dependency", "system": "water", "entity_type": "machine", "entity_id": m["id"], "room_id": m["room_id"]})
	return links

static func _resolve_room_id(ws: WorldState, type: String, id: int, details: Dictionary) -> int:
	if type == "room": return id
	if type == "person": return int(details.get("current_location_id", 0))
	if type == "household": return int(details.get("home_room_id", 0))
	if type == "machine":
		var m: Machine = ws.entity_registry.get_entity(id) as Machine
		return m.room_id if m else 0
	if type == "incident":
		var root_id: int = int(details.get("root_cause_id", 0))
		var root: Variant = ws.entity_registry.get_entity(root_id)
		if root is Machine: return root.room_id
		if root is Room: return root.id
		if root is Person: return root.current_location_id
		if root is Inventory:
			var owner: Variant = ws.entity_registry.get_entity(root.owner_entity_id)
			if owner is Room: return owner.id
		return 0
	return 0

static func _find_by_id(items: Array, id: int) -> Dictionary:
	for item in items:
		if int(item.get("id", 0)) == id: return item
	return {}

## Rich inspection is queried only for the selection, never per citizen/frame.
static func get_person_details(ws: WorldState, id: int) -> Dictionary:
	var p: Person = ws.entity_registry.get_entity(id) as Person
	if not p: return {}
	var details: Dictionary = SimulationReader.get_person_profile(ws, id)
	details.merge(_person_identity(ws, p), true)
	details["destination_id"] = p.target_location_id
	details["bed_id"] = p.bed_id
	details["household"] = SimulationReader.get_household_summary(ws, p.household_id)
	details["workplace_required"] = p.shift_id != Occupation.SHIFT_OFF and p.occupation_id != "student"
	return details

static func get_room_details(ws: WorldState, id: int) -> Dictionary:
	var r: Room = ws.entity_registry.get_entity(id) as Room
	if not r: return {}
	var details: Dictionary = SimulationReader.get_room_summary(ws, id)
	details["backend_binding"] = room_backend_binding(r.room_type)
	var workers: Array[Dictionary] = []
	var students: Array[Dictionary] = []
	var households: Array[Dictionary] = []
	var shifts: Dictionary = {}
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var p: Person = ws.entity_registry.get_entity(pid) as Person
		if not p or not p.is_alive: continue
		if p.workplace_room_id == id:
			workers.append({"id": p.id, "name": p.get_full_name(), "department": p.department_id,
				"job": p.occupation_id, "shift": Occupation.get_shift_name(p.shift_id),
				"present": p.current_location_id == id and p.current_activity == Person.ACTIVITY_WORKING})
			var shift: String = Occupation.get_shift_name(p.shift_id)
			shifts[shift] = int(shifts.get(shift, 0)) + 1
		if p.school_room_id == id:
			students.append({"id": p.id, "name": p.get_full_name(), "household_id": p.household_id,
				"present": p.current_location_id == id and p.current_activity == Person.ACTIVITY_STUDYING})
	for hid in ws.entity_registry.get_entities_by_type("household"):
		var h: Household = ws.entity_registry.get_entity(hid) as Household
		if h and h.home_room_id == id: households.append(SimulationReader.get_household_summary(ws, hid))
	details["workers"] = workers
	details["students"] = students
	details["households"] = households
	details["shifts"] = shifts
	details["machines"] = []
	for m in SimulationReader.get_machinery_summary(ws)["machines_list"]:
		if int(m["room_id"]) == id: details["machines"].append(m)
	return details

static func get_machine_details(ws: WorldState, id: int) -> Dictionary:
	var m: Machine = ws.entity_registry.get_entity(id) as Machine
	if not m: return {}
	var details: Dictionary = SimulationReader.get_causal_chain(ws, id)
	details["record"] = m.serialize().duplicate(true)
	details["operator"] = "No individual operator assignment exists in backend"
	details["maintenance_workers"] = []
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var p: Person = ws.entity_registry.get_entity(pid) as Person
		if p and p.is_alive and p.workplace_room_id == m.room_id and p.occupation_id == "maintenance_technician":
			details["maintenance_workers"].append({"id": p.id, "name": p.get_full_name(),
				"present": p.current_location_id == m.room_id and p.current_activity == Person.ACTIVITY_WORKING})
	return details

static func room_backend_binding(room_type: int) -> String:
	match room_type:
		Room.TYPE_RESIDENTIAL_APARTMENT, Room.TYPE_DORMITORY: return "Live household, bed and resident occupancy"
		Room.TYPE_DEEP_MINE, Room.TYPE_FOUNDRY, Room.TYPE_MACHINE_SHOP: return "Live worker-dependent material production and room inventory; transfers are abstract"
		Room.TYPE_WATER_PUMP_STATION: return "Live pump, component maintenance and water supply; treatment chemistry is not implemented"
		Room.TYPE_SCHOOL: return "Live student/teacher assignments and attendance; education progression belongs to demographics"
		Room.TYPE_CLINIC: return "Live medical staff attendance; patient treatment is not implemented"
		Room.TYPE_CANTEEN, Room.TYPE_KITCHEN: return "Live meals/cook schedules; food stocks and production are not implemented"
		Room.TYPE_HYGIENE_FACILITY: return "Live sanitation worker attendance; resident hygiene occurs at home; sanitation processing is not implemented"
		Room.TYPE_SERVER_ROOM: return "Live IT/electrician attendance; network and electrical operation are not implemented"
		Room.TYPE_BIO_FARM: return "PHYSICAL HOOK ONLY - agriculture/food production integration pending"
		Room.TYPE_STORAGE: return "PHYSICAL HOOK ONLY - no inventory is assigned to this storage hook"
		_: return "PHYSICAL HOOK ONLY - backend operation integration pending"

static func get_incident_locations(ws: WorldState) -> Dictionary:
	var result: Dictionary = SimulationReader.get_incidents_summary(ws)
	for incident in result["active_incidents"]:
		incident["room_id"] = _resolve_room_id(ws, "incident", int(incident["id"]), incident)
		incident["physical_status"] = "Located at root cause" if int(incident["room_id"]) > 0 else "Silo-wide or unresolved root; no invented room"
	return result

static func get_stairs(ws: WorldState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var state: Dictionary = ws.custom_data.get("spatial_travel", {})
	var segments: Dictionary = state.get("segments", {})
	var ids: Array = segments.keys()
	ids.sort()
	for id in ids:
		var segment: Dictionary = segments[id]
		var row: Dictionary = segment.duplicate(true)
		row["occupancy"] = (segment["occupants"] as Dictionary).size()
		row["queue_length"] = (segment["queue"] as Array).size()
		row["congestion"] = float(row["occupancy"]) / float(maxi(1, int(row["capacity"])))
		row["queue_penalty_ticks_estimate"] = ceili(float(row["queue_length"]) / float(maxi(1, int(row["capacity"])))) * int(row["base_travel_ticks"])
		row["travel_time_ticks_estimate"] = int(row["base_travel_ticks"]) + int(row["queue_penalty_ticks_estimate"])
		result.append(row)
	return result
