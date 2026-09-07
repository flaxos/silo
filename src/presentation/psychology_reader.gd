# src/presentation/psychology_reader.gd
class_name PsychologyReader
extends RefCounted

## Read model adapter for Psychology, Stress, and Absenteeism.
## Read-only queries with zero simulation mutations.

static func get_population_psychology_summary(ws: WorldState) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	var total_living: int = 0
	var sum_stress: float = 0.0
	var sum_fatigue: float = 0.0
	var sum_morale: float = 0.0
	var sum_burnout: float = 0.0
	var absent_count: int = 0
	var acute_stress_count: int = 0
	var burned_out_count: int = 0
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive:
			total_living += 1
			sum_stress += p.stress
			sum_fatigue += p.fatigue
			sum_morale += p.morale
			sum_burnout += p.burnout
			if p.absent_from_work:
				absent_count += 1
			if p.stress >= 75.0:
				acute_stress_count += 1
			if p.burnout >= 50.0:
				burned_out_count += 1
				
	var count_f: float = maxf(1.0, float(total_living))
	return {
		"living_population": total_living,
		"average_stress": sum_stress / count_f,
		"average_fatigue": sum_fatigue / count_f,
		"average_morale": sum_morale / count_f,
		"average_burnout": sum_burnout / count_f,
		"absent_workers_count": absent_count,
		"acute_stress_count": acute_stress_count,
		"burned_out_count": burned_out_count
	}

static func get_person_psychology(ws: WorldState, person_id: int) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry
	var p: Person = registry.get_entity(person_id) as Person
	if not p:
		return {"error": "Person not found"}
		
	return {
		"person_id": p.id,
		"name": "%s %s" % [p.first_name, p.last_name],
		"occupation": p.occupation_id,
		"stress": p.stress,
		"fatigue": p.fatigue,
		"morale": p.morale,
		"burnout": p.burnout,
		"absent_from_work": p.absent_from_work,
		"current_activity": p.current_activity
	}
