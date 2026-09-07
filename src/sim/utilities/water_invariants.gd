# src/sim/utilities/water_invariants.gd
class_name WaterInvariants
extends RefCounted

static func validate(world_state: WorldState, initial_reservoir_liters: float, water_system: WaterSystem) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = world_state.entity_registry
	
	var current_res: float = water_system.reservoir_current_liters
	var capacity: float = water_system.reservoir_capacity_liters
	var pumped: float = water_system.total_pumped_liters
	var consumed: float = water_system.total_consumed_liters
	
	# 1. Reservoir boundary checks
	if current_res < -0.0001:
		errors.append("Water reservoir is negative: %.4f L" % current_res)
	if current_res > (capacity + 0.001):
		errors.append("Water reservoir exceeds maximum capacity: %.4f L (max %.4f L)" % [current_res, capacity])
		
	# 2. Strict conservation of water volume: Initial + Inflow - Outflow == Current
	var expected_current: float = initial_reservoir_liters + pumped - consumed
	var water_error: float = absf(current_res - expected_current)
	if water_error > 0.001:
		errors.append("Water conservation violated! Expected %.4f L, Actual %.4f L (Discrepancy: %.6f L)" % [expected_current, current_res, water_error])
		
	# 3. Citizen hydration & health metrics check
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	var total_people: int = person_ids.size()
	var alive_count: int = 0
	var dehydrated_count: int = 0
	var critical_dehydrated_count: int = 0
	var avg_hydration: float = 0.0
	
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if not p:
			continue
			
		if p.hydration_percent < -0.001 or p.hydration_percent > 100.001:
			errors.append("Person ID %d hydration out of bounds: %.2f%%" % [pid, p.hydration_percent])
			
		if p.health_percent < -0.001 or p.health_percent > 100.001:
			errors.append("Person ID %d health out of bounds: %.2f%%" % [pid, p.health_percent])
			
		if p.is_alive:
			alive_count += 1
			avg_hydration += p.hydration_percent
			if p.is_severely_dehydrated():
				dehydrated_count += 1
			if p.hydration_percent <= 0.001:
				critical_dehydrated_count += 1
				
	if alive_count > 0:
		avg_hydration /= float(alive_count)
		
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"stats": {
			"total_people": total_people,
			"alive_count": alive_count,
			"dehydrated_count": dehydrated_count,
			"critical_dehydrated_count": critical_dehydrated_count,
			"avg_hydration_percent": avg_hydration,
			"reservoir_current_liters": current_res,
			"total_pumped_liters": pumped,
			"total_consumed_liters": consumed,
			"conservation_error_liters": water_error
		}
	}
