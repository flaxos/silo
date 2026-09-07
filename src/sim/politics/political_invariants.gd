# src/sim/politics/political_invariants.gd
class_name PoliticalInvariants
extends RefCounted

## Validates mathematical and causal invariants for political perception, memories, and legitimacy.

static func validate_attitude_bounds(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"persons_checked": 0
	}
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p:
			continue
			
		result["persons_checked"] += 1
		
		var fields: Dictionary = {
			"institutional_trust": p.institutional_trust,
			"perceived_fairness": p.perceived_fairness,
			"perceived_security": p.perceived_security,
			"economic_satisfaction": p.economic_satisfaction,
			"class_resentment": p.class_resentment,
			"confidence_leadership": p.confidence_leadership,
			"confidence_it": p.confidence_it,
			"confidence_security": p.confidence_security,
			"confidence_engineering": p.confidence_engineering,
			"tolerance_coercion": p.tolerance_coercion,
			"preference_stability": p.preference_stability,
			"preference_reform": p.preference_reform,
			"preference_autonomy": p.preference_autonomy,
			"preference_equality": p.preference_equality,
			"preference_hierarchy": p.preference_hierarchy
		}
		
		for key in fields:
			var val: float = float(fields[key])
			if val < 0.0 or val > 1.0 or is_nan(val):
				result["is_valid"] = false
				result["errors"].append("Person #%d field %s out of bounds: %f" % [pid, key, val])
				
	return result

static func validate_memory_causality(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"memories_checked": 0
	}
	if not ws or not ws.entity_registry:
		return result
		
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p:
			continue
			
		for mem in p.opinion_memories:
			result["memories_checked"] += 1
			var onset: int = int(mem.get("onset_tick", 0))
			if onset > cur_tick:
				result["is_valid"] = false
				result["errors"].append("Person #%d memory has future onset tick: %d > %d" % [pid, onset, cur_tick])
				
			var imp: float = float(mem.get("emotional_impact", 0.0))
			if imp < -1.0 or imp > 1.0 or is_nan(imp):
				result["is_valid"] = false
				result["errors"].append("Person #%d memory impact out of bounds: %f" % [pid, imp])
				
			var sal: float = float(mem.get("salience", 1.0))
			if sal < 0.0 or sal > 1.0 or is_nan(sal):
				result["is_valid"] = false
				result["errors"].append("Person #%d memory salience out of bounds: %f" % [pid, sal])
				
	return result

static func validate_legitimacy_consistency(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"is_valid": true,
		"errors": []
	}
	if not ws:
		return result
		
	var leg: float = float(ws.custom_data.get("habitat_legitimacy", 0.5))
	if leg < 0.0 or leg > 1.0 or is_nan(leg):
		result["is_valid"] = false
		result["errors"].append("Habitat legitimacy out of bounds: %f" % leg)
		
	var res: float = float(ws.custom_data.get("class_resentment_index", 0.0))
	if res < 0.0 or res > 1.0 or is_nan(res):
		result["is_valid"] = false
		result["errors"].append("Class resentment index out of bounds: %f" % res)
		
	return result

static func validate_all(ws: WorldState) -> Dictionary:
	var b_val: Dictionary = validate_attitude_bounds(ws)
	var m_val: Dictionary = validate_memory_causality(ws)
	var l_val: Dictionary = validate_legitimacy_consistency(ws)
	
	var is_valid: bool = b_val["is_valid"] and m_val["is_valid"] and l_val["is_valid"]
	var all_errors: Array = []
	all_errors.append_array(b_val["errors"])
	all_errors.append_array(m_val["errors"])
	all_errors.append_array(l_val["errors"])
	
	return {
		"is_valid": is_valid,
		"errors": all_errors,
		"persons_checked": b_val.get("persons_checked", 0),
		"memories_checked": m_val.get("memories_checked", 0)
	}
