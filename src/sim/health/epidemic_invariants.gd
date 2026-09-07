# src/sim/health/epidemic_invariants.gd
class_name EpidemicInvariants
extends RefCounted

## Invariant validation for Sprint 22: Epidemics & Public Health.

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	var total_living: int = 0
	var seir_sum: int = 0
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		total_living += 1
		
		# 1. Valid infection stage
		if p.infection_stage < 0 or p.infection_stage > 4:
			errors.append("Person #%d invalid infection stage: %d" % [p.id, p.infection_stage])
		else:
			seir_sum += 1
			
		# 2. Health percent bounds
		if p.health_percent < -0.001 or p.health_percent > 100.001:
			errors.append("Person #%d health_percent out of bounds: %f" % [p.id, p.health_percent])
			
		# 3. Quarantine validity
		if p.is_quarantined and p.infection_stage == Person.INFECTION_SUSCEPTIBLE:
			errors.append("Person #%d is quarantined while susceptible" % p.id)
			
	# 4. SEIR conservation check
	if seir_sum != total_living:
		errors.append("SEIR conservation error: sum (%d) != living count (%d)" % [seir_sum, total_living])

	return {
		"is_valid": errors.is_empty(),
		"errors": errors
	}
