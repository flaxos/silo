class_name OperationsReports
extends RefCounted

## Bridges already measured institutional conditions into existing information objects.
## Persistent latches prevent daily duplicates for the same unresolved facility issue.
static func collect(ws: WorldState, reported: Dictionary) -> void:
	var info_sys := ws.custom_data.get("information_system") as InformationSystem
	if not info_sys:
		return
	var attendance := {}
	var enrolled := {}
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var p := ws.entity_registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
		if p.school_room_id > 0:
			enrolled[p.school_room_id] = int(enrolled.get(p.school_room_id, 0)) + 1
		if p.current_activity == Person.ACTIVITY_STUDYING:
			attendance[p.current_location_id] = int(attendance.get(p.current_location_id, 0)) + 1
	var worst: Room = null
	var excess := 0
	for rid in ws.entity_registry.get_entities_by_type("room"):
		var r := ws.entity_registry.get_entity(rid) as Room
		if not r or r.room_type != Room.TYPE_SCHOOL:
			continue
		var key := "school:%d" % rid
		if int(enrolled.get(rid, 0)) <= r.capacity_people:
			reported.erase(key)
		var over := int(attendance.get(rid, 0)) - r.capacity_people
		if over > excess:
			excess = over
			worst = r
	if worst:
		var key := "school:%d" % worst.id
		# One open facility report across schools keeps the operations brief bounded.
		var existing_open := false
		for item in ws.custom_data.get("information_objects", []):
			var info := item as InformationObject
			if info and info.topic == "school_capacity" and info.reach_count == 0:
				existing_open = true
		if not reported.has(key) and not existing_open:
			var facts := {"room_id": worst.id, "observed_tick": ws.sim_clock.get_tick(), "attending_students": int(attendance[worst.id]), "capacity": worst.capacity_people, "enrolled_students": int(enrolled.get(worst.id, 0))}
			var info := info_sys.create_information(ws, "%s:%d" % [key, ws.sim_clock.get_tick()], "institution", 0, "school_capacity", facts, facts, InformationObject.CHANNEL_OFFICIAL, {"type": "all"}, InformationObject.CLASS_INTERNAL)
			# Routine release deadline; the player may release early or withhold.
			info_sys.delay_information(ws, info.id, OperationsConfig.OVERDUE_TICKS)
			reported[key] = info.id
	for item in ws.custom_data.get("illicit_actions", []):
		var act := item as IllicitAction
		if not act or act.discovery_status < IllicitAction.STATUS_EXPOSED:
			continue
		var key := "audit:%d" % act.id
		if reported.has(key):
			continue
		var facts := {"room_id": act.source_room_id, "audit_id": act.id, "observed_tick": act.discovered_tick, "resource": act.target_resource, "reported_discrepancy": act.discrepancy_amount, "evidence_strength": act.evidence_strength}
		var info := info_sys.create_information(ws, key, "institution", 0, "exposed_audit", facts, facts, InformationObject.CHANNEL_OFFICIAL, {"type": "all"}, InformationObject.CLASS_INTERNAL, act.evidence_strength)
		info_sys.delay_information(ws, info.id, OperationsConfig.OVERDUE_TICKS)
		reported[key] = info.id
