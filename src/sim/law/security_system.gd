# src/sim/law/security_system.gd
class_name SecuritySystem
extends BaseSystem

## Operational Security, Investigation, and Justice system.
## Tracks staffed security personnel, physical evidence collection,
## suspect interrogation, warrants, arrests, detention, and sentencing.

const SecurityCase = preload("res://src/sim/law/security_case.gd")
const CrimeIncident = preload("res://src/sim/law/crime_incident.gd")

var next_case_id: int = 1
var it_access_granted: bool = true
var log_retention_ticks: int = 288 # 48 hours default retention

func _init() -> void:
	super("security_system", 42)
	next_case_id = 1
	it_access_granted = true
	log_retention_ticks = 288

func setup(ws: Variant) -> void:
	var world: WorldState = ws as WorldState
	if world:
		if not world.custom_data.has("security_cases"):
			world.custom_data["security_cases"] = []
		if not world.custom_data.has("detainees"):
			world.custom_data["detainees"] = []
		if not world.custom_data.has("patrol_assignments"):
			world.custom_data["patrol_assignments"] = {}

func tick(ws: Variant) -> void:
	var world: WorldState = ws as WorldState
	if not world:
		return
		
	_process_detentions(world)

func _process_detentions(ws: WorldState) -> void:
	var detainees: Array = ws.custom_data.get("detainees", [])
	var remaining: Array = []
	var registry: EntityRegistry = ws.entity_registry
	
	for entry in detainees:
		if entry is Dictionary:
			var pid: int = int(entry.get("person_id", 0))
			var ticks_left: int = int(entry.get("ticks_remaining", 0)) - 1
			var case_id: int = int(entry.get("case_id", 0))
			
			var person: Person = registry.get_entity(pid) as Person
			if person and person.is_alive:
				# Keep detained person in cell during detention
				var cell_room_id: int = int(entry.get("cell_room_id", 0))
				if cell_room_id > 0:
					person.current_location_id = cell_room_id
					person.current_activity = Person.ACTIVITY_IDLE
					
				if ticks_left <= 0:
					# Sentence complete: release
					_finish_release(ws, person, case_id)
				else:
					entry["ticks_remaining"] = ticks_left
					remaining.append(entry)
					
	ws.custom_data["detainees"] = remaining

func _finish_release(ws: WorldState, person: Person, case_id: int) -> void:
	person.current_location_id = person.home_room_id
	var c: SecurityCase = get_case(ws, case_id)
	if c:
		c.sentence_ticks_remaining = 0
		c.status = SecurityCase.STATUS_CONVICTED

func open_case(ws: WorldState, crime_id: int, officer_id: int) -> SecurityCase:
	var registry: EntityRegistry = ws.entity_registry
	var officer: Person = registry.get_entity(officer_id) as Person
	if not officer or not officer.is_alive:
		return null
		
	# Find target crime
	var crimes: Array = ws.custom_data.get("crime_incidents", [])
	var crime: CrimeIncident = null
	for item in crimes:
		var ci: CrimeIncident = item as CrimeIncident
		if ci and ci.id == crime_id:
			crime = ci
			break
			
	if not crime:
		return null
		
	var current_tick: int = ws.sim_clock.get_tick()
	var case_obj: SecurityCase = SecurityCase.new(
		next_case_id,
		crime.id,
		officer.id,
		current_tick
	)
	next_case_id += 1
	case_obj.actual_perpetrator_id = crime.perpetrator_id
	case_obj.status = SecurityCase.STATUS_INVESTIGATING
	
	crime.status = CrimeIncident.STATUS_INVESTIGATING
	
	var list: Array = ws.custom_data.get("security_cases", [])
	list.append(case_obj)
	ws.custom_data["security_cases"] = list
	
	return case_obj

func investigate_case(ws: WorldState, case_id: int) -> void:
	var case_obj: SecurityCase = get_case(ws, case_id)
	if not case_obj or case_obj.status == SecurityCase.STATUS_CONVICTED or case_obj.status == SecurityCase.STATUS_ARRESTED:
		return
		
	var crimes: Array = ws.custom_data.get("crime_incidents", [])
	var crime: CrimeIncident = null
	for item in crimes:
		var ci: CrimeIncident = item as CrimeIncident
		if ci and ci.id == case_obj.crime_incident_id:
			crime = ci
			break
			
	if not crime:
		return
		
	var current_tick: int = ws.sim_clock.get_tick()
	var time_elapsed: int = current_tick - crime.tick_occurred
	var logs_expired: bool = (time_elapsed > log_retention_ticks)
	
	# 1. Inspect badge logs
	if it_access_granted and not logs_expired and bool(crime.evidence.get("badge_log_recorded", false)):
		case_obj.gathered_evidence["badge_log_verified"] = true
		case_obj.actions_taken.append("verified_badge_logs")
		var score: float = float(case_obj.suspect_scores.get(crime.perpetrator_id, 0.0))
		case_obj.suspect_scores[crime.perpetrator_id] = minf(1.0, score + 0.35)
		
	# 2. Inspect CCTV footage
	if it_access_granted and not logs_expired and bool(crime.evidence.get("cctv_recorded", false)):
		case_obj.gathered_evidence["cctv_footage_available"] = true
		case_obj.actions_taken.append("reviewed_cctv_footage")
		var score: float = float(case_obj.suspect_scores.get(crime.perpetrator_id, 0.0))
		case_obj.suspect_scores[crime.perpetrator_id] = minf(1.0, score + 0.45)
		
	# 3. Interview witnesses
	var w_ids: Array = crime.evidence.get("witness_ids", [])
	var registry: EntityRegistry = ws.entity_registry
	for wid in w_ids:
		var w: Person = registry.get_entity(int(wid)) as Person
		if w and w.is_alive:
			case_obj.gathered_evidence["witnesses_interviewed"].append(w.id)
			case_obj.actions_taken.append("interviewed_witness_%d" % w.id)
			var score: float = float(case_obj.suspect_scores.get(crime.perpetrator_id, 0.0))
			case_obj.suspect_scores[crime.perpetrator_id] = minf(1.0, score + 0.30)
			
	# 4. Inventory discrepancy
	var disc: float = float(crime.evidence.get("inventory_discrepancy", 0.0))
	if disc > 0.0:
		case_obj.gathered_evidence["inventory_discrepancy_verified"] = disc
		case_obj.actions_taken.append("verified_inventory_discrepancy")
		
	# 5. Evaluate highest-scoring suspect and confidence
	var highest_score: float = 0.0
	var lead_id: int = 0
	for pid in case_obj.suspect_scores.keys():
		var sc: float = float(case_obj.suspect_scores[pid])
		if sc > highest_score:
			highest_score = sc
			lead_id = int(pid)
			
	case_obj.lead_suspect_id = lead_id
	case_obj.confidence = highest_score
	
	if case_obj.confidence >= 0.65:
		case_obj.status = SecurityCase.STATUS_WARRANT
	elif case_obj.confidence < 0.20 and time_elapsed > 48:
		case_obj.status = SecurityCase.STATUS_COLD_CASE

func execute_arrest(ws: WorldState, case_id: int, suspect_id: int, sentence_ticks: int = 144) -> bool:
	var case_obj: SecurityCase = get_case(ws, case_id)
	if not case_obj:
		return false
		
	var registry: EntityRegistry = ws.entity_registry
	var suspect: Person = registry.get_entity(suspect_id) as Person
	if not suspect or not suspect.is_alive:
		return false
		
	# Find a security detention cell room
	var cell_room_id: int = 0
	var room_ids: Array[int] = registry.get_entities_by_type("room")
	for rid in room_ids:
		var r: Room = registry.get_entity(rid) as Room
		if r and (r.room_type == Room.TYPE_SECURITY_POST or r.room_type == Room.TYPE_ADMINISTRATION):
			cell_room_id = r.id
			break
			
	if cell_room_id == 0 and room_ids.size() > 0:
		cell_room_id = room_ids[0]
		
	# Physically move suspect to cell and detain them
	suspect.current_location_id = cell_room_id
	suspect.current_activity = Person.ACTIVITY_IDLE
	
	case_obj.lead_suspect_id = suspect.id
	case_obj.status = SecurityCase.STATUS_ARRESTED
	case_obj.sentence_duration_ticks = sentence_ticks
	case_obj.sentence_ticks_remaining = sentence_ticks
	case_obj.resolved_tick = ws.sim_clock.get_tick()
	
	if suspect.id == case_obj.actual_perpetrator_id:
		case_obj.verdict = SecurityCase.VERDICT_GUILTY_CORRECT
	else:
		# Wrongful arrest: spikes resentment and destroys institutional trust
		case_obj.verdict = SecurityCase.VERDICT_WRONGFUL_CONVICTION
		suspect.class_resentment = minf(1.0, suspect.class_resentment + 0.5)
		suspect.institutional_trust = maxf(0.0, suspect.institutional_trust - 0.4)
		
	var detainees: Array = ws.custom_data.get("detainees", [])
	detainees.append({
		"person_id": suspect.id,
		"case_id": case_obj.id,
		"cell_room_id": cell_room_id,
		"ticks_remaining": sentence_ticks
	})
	ws.custom_data["detainees"] = detainees
	
	return true

func get_case(ws: WorldState, case_id: int) -> SecurityCase:
	var list: Array = ws.custom_data.get("security_cases", [])
	for item in list:
		var c: SecurityCase = item as SecurityCase
		if c and c.id == case_id:
			return c
	return null

func get_all_cases(ws: WorldState) -> Array[SecurityCase]:
	var results: Array[SecurityCase] = []
	var list: Array = ws.custom_data.get("security_cases", [])
	for item in list:
		var c: SecurityCase = item as SecurityCase
		if c:
			results.append(c)
	return results

func serialize() -> Dictionary:
	return {
		"system_id": system_id,
		"execution_order": execution_order,
		"next_case_id": next_case_id,
		"it_access_granted": it_access_granted,
		"log_retention_ticks": log_retention_ticks
	}

func deserialize(d: Dictionary) -> void:
	system_id = str(d.get("system_id", "security_system"))
	execution_order = int(d.get("execution_order", 42))
	next_case_id = int(d.get("next_case_id", 1))
	it_access_granted = bool(d.get("it_access_granted", true))
	log_retention_ticks = int(d.get("log_retention_ticks", 288))
