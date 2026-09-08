# src/presentation/security_reader.gd
class_name SecurityReader
extends RefCounted

## Read model adapter for Security, Investigation, and Justice.
## Read-only queries with zero simulation mutations.

const SecurityCase = preload("res://src/sim/law/security_case.gd")

static func get_security_summary(ws: WorldState) -> Dictionary:
	var cases: Array = ws.custom_data.get("security_cases", [])
	var total: int = cases.size()
	var by_status: Dictionary = {}
	var solved_correctly: int = 0
	var wrongful: int = 0
	
	for item in cases:
		var sc: SecurityCase = item as SecurityCase
		if sc:
			by_status[sc.status] = int(by_status.get(sc.status, 0)) + 1
			if sc.verdict == SecurityCase.VERDICT_GUILTY_CORRECT:
				solved_correctly += 1
			elif sc.verdict == SecurityCase.VERDICT_WRONGFUL_CONVICTION:
				wrongful += 1
				
	var detainees: Array = ws.custom_data.get("detainees", [])
	
	return {
		"total_cases_count": total,
		"cases_by_status": by_status,
		"solved_correctly": solved_correctly,
		"wrongful_convictions": wrongful,
		"active_detainees_count": detainees.size()
	}

static func get_all_cases(ws: WorldState) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var cases: Array = ws.custom_data.get("security_cases", [])
	var registry: EntityRegistry = ws.entity_registry
	
	for item in cases:
		var sc: SecurityCase = item as SecurityCase
		if sc:
			var off_name: String = "Officer #%d" % sc.assigned_officer_id
			var officer: Person = registry.get_entity(sc.assigned_officer_id) as Person
			if officer:
				off_name = "%s %s" % [officer.first_name, officer.last_name]
				
			var susp_name: String = "None"
			if sc.lead_suspect_id > 0:
				var susp: Person = registry.get_entity(sc.lead_suspect_id) as Person
				if susp:
					susp_name = "%s %s" % [susp.first_name, susp.last_name]
					
			results.append({
				"id": sc.id,
				"crime_id": sc.crime_incident_id,
				"officer_id": sc.assigned_officer_id,
				"officer_name": off_name,
				"lead_suspect_id": sc.lead_suspect_id,
				"lead_suspect_name": susp_name,
				"confidence": sc.confidence,
				"status": sc.status,
				"verdict": sc.verdict,
				"actions_taken": sc.actions_taken
			})
	return results

static func get_detainees(ws: WorldState) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var list: Array = ws.custom_data.get("detainees", [])
	var registry: EntityRegistry = ws.entity_registry
	
	for item in list:
		if item is Dictionary:
			var pid: int = int(item.get("person_id", 0))
			var p: Person = registry.get_entity(pid) as Person
			var p_name: String = "Person #%d" % pid
			var occ: String = "Unknown"
			if p:
				p_name = "%s %s" % [p.first_name, p.last_name]
				occ = p.occupation_id
				
			results.append({
				"person_id": pid,
				"name": p_name,
				"occupation": occ,
				"case_id": int(item.get("case_id", 0)),
				"cell_room_id": int(item.get("cell_room_id", 0)),
				"ticks_remaining": int(item.get("ticks_remaining", 0))
			})
	return results
