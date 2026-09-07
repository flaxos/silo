# src/sim/law/security_invariants.gd
class_name SecurityInvariants
extends RefCounted

## Invariant validation for Sprint 18: Advanced Policing, Investigation & Justice.

const SecurityCase = preload("res://src/sim/law/security_case.gd")
const CrimeIncident = preload("res://src/sim/law/crime_incident.gd")

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = ws.entity_registry
	
	var cases: Array = ws.custom_data.get("security_cases", [])
	for item in cases:
		var sc: SecurityCase = item as SecurityCase
		if not sc:
			errors.append("Invalid SecurityCase in custom_data['security_cases']")
			continue
			
		if sc.id <= 0:
			errors.append("SecurityCase has non-positive ID %d" % sc.id)
			
		if sc.assigned_officer_id > 0:
			var officer: Person = registry.get_entity(sc.assigned_officer_id) as Person
			if not officer:
				errors.append("Case #%d assigned to non-existent officer Person #%d" % [sc.id, sc.assigned_officer_id])
				
		if sc.lead_suspect_id > 0:
			var suspect: Person = registry.get_entity(sc.lead_suspect_id) as Person
			if not suspect:
				errors.append("Case #%d references non-existent suspect Person #%d" % [sc.id, sc.lead_suspect_id])
				
		if sc.confidence < 0.0 or sc.confidence > 1.0001:
			errors.append("Case #%d has confidence out of bounds %f" % [sc.id, sc.confidence])
			
	var detainees: Array = ws.custom_data.get("detainees", [])
	for item in detainees:
		if item is Dictionary:
			var pid: int = int(item.get("person_id", 0))
			var p: Person = registry.get_entity(pid) as Person
			if not p:
				errors.append("Detainee Person #%d does not exist" % pid)
			elif not p.is_alive:
				errors.append("Detainee Person #%d is deceased but still marked as detained" % pid)
				
			var ticks: int = int(item.get("ticks_remaining", 0))
			if ticks < 0:
				errors.append("Detainee Person #%d has negative ticks_remaining %d" % [pid, ticks])
				
	return {
		"is_valid": errors.is_empty(),
		"errors": errors
	}
