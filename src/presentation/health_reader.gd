# src/presentation/health_reader.gd
class_name HealthReader
extends RefCounted

## Decoupled read-model adapter for epidemic metrics, public health, and clinic operations.

static func get_epidemic_summary(ws: WorldState) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	var counts: Dictionary = {
		"susceptible": 0,
		"exposed": 0,
		"infectious": 0,
		"symptomatic": 0,
		"recovered": 0,
		"quarantined": 0
	}
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		match p.infection_stage:
			Person.INFECTION_SUSCEPTIBLE:
				counts["susceptible"] += 1
			Person.INFECTION_EXPOSED:
				counts["exposed"] += 1
			Person.INFECTION_INFECTIOUS:
				counts["infectious"] += 1
			Person.INFECTION_SYMPTOMATIC:
				counts["symptomatic"] += 1
			Person.INFECTION_RECOVERED:
				counts["recovered"] += 1
				
		if p.is_quarantined:
			counts["quarantined"] += 1
			
	return counts

static func get_clinic_summary(ws: WorldState) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry
	var rids: Array[int] = registry.get_entities_by_type("room")
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	var total_beds: int = 0
	for rid in rids:
		var room: Room = registry.get_entity(rid) as Room
		if room and room.room_type == Room.TYPE_CLINIC:
			total_beds += room.bed_count
			
	var staff_count: int = 0
	var symptomatic_patients: int = 0
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
		if p.occupation_id in ["doctor", "nurse"]:
			staff_count += 1
		if p.infection_stage == Person.INFECTION_SYMPTOMATIC:
			symptomatic_patients += 1
			
	return {
		"clinic_beds": total_beds,
		"medical_staff": staff_count,
		"symptomatic_patients": symptomatic_patients,
		"quarantine_active": ws.custom_data.get("quarantine_active", false),
		"schools_closed": ws.custom_data.get("schools_closed", false)
	}
