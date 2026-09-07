# src/sim/politics/legitimacy_model.gd
class_name LegitimacyModel
extends RefCounted

## Calculates derived habitat legitimacy, departmental trust, and social spectrum metrics from living citizen perception state.

static func calculate_overall_legitimacy(ws: WorldState) -> float:
	if not ws or not ws.entity_registry:
		return 0.5
		
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	if pids.is_empty():
		return 0.5
		
	var total_score: float = 0.0
	var count: int = 0
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.life_stage >= Person.STAGE_STUDENT:
			# Weighted composite: 40% trust, 30% fairness, 30% security
			var citizen_legitimacy: float = (p.institutional_trust * 0.40) + (p.perceived_fairness * 0.30) + (p.perceived_security * 0.30)
			total_score += citizen_legitimacy
			count += 1
			
	return (total_score / float(count)) if count > 0 else 0.5

static func calculate_departmental_trust(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"leadership": 0.5,
		"it": 0.5,
		"security": 0.5,
		"engineering": 0.5
	}
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var count: int = 0
	
	var sum_lead: float = 0.0
	var sum_it: float = 0.0
	var sum_sec: float = 0.0
	var sum_eng: float = 0.0
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.life_stage >= Person.STAGE_STUDENT:
			sum_lead += p.confidence_leadership
			sum_it += p.confidence_it
			sum_sec += p.confidence_security
			sum_eng += p.confidence_engineering
			count += 1
			
	if count > 0:
		result["leadership"] = sum_lead / float(count)
		result["it"] = sum_it / float(count)
		result["security"] = sum_sec / float(count)
		result["engineering"] = sum_eng / float(count)
		
	return result

static func calculate_class_resentment_index(ws: WorldState) -> float:
	if not ws or not ws.entity_registry:
		return 0.0
		
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var count: int = 0
	var total_resentment: float = 0.0
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive:
			total_resentment += p.class_resentment
			count += 1
			
	return (total_resentment / float(count)) if count > 0 else 0.0

static func calculate_political_spectrum(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"avg_trust": 0.5,
		"avg_fairness": 0.5,
		"avg_security": 0.5,
		"avg_satisfaction": 0.5,
		"avg_class_resentment": 0.0,
		"preference_stability": 0.6,
		"preference_reform": 0.4,
		"preference_autonomy": 0.5,
		"preference_equality": 0.5,
		"preference_hierarchy": 0.5,
		"tolerance_coercion": 0.3
	}
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var count: int = 0
	
	var s_trust: float = 0.0
	var s_fair: float = 0.0
	var s_sec: float = 0.0
	var s_sat: float = 0.0
	var s_res: float = 0.0
	var s_stab: float = 0.0
	var s_ref: float = 0.0
	var s_auto: float = 0.0
	var s_eq: float = 0.0
	var s_hier: float = 0.0
	var s_coerc: float = 0.0
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.life_stage >= Person.STAGE_STUDENT:
			s_trust += p.institutional_trust
			s_fair += p.perceived_fairness
			s_sec += p.perceived_security
			s_sat += p.economic_satisfaction
			s_res += p.class_resentment
			s_stab += p.preference_stability
			s_ref += p.preference_reform
			s_auto += p.preference_autonomy
			s_eq += p.preference_equality
			s_hier += p.preference_hierarchy
			s_coerc += p.tolerance_coercion
			count += 1
			
	if count > 0:
		result["avg_trust"] = s_trust / float(count)
		result["avg_fairness"] = s_fair / float(count)
		result["avg_security"] = s_sec / float(count)
		result["avg_satisfaction"] = s_sat / float(count)
		result["avg_class_resentment"] = s_res / float(count)
		result["preference_stability"] = s_stab / float(count)
		result["preference_reform"] = s_ref / float(count)
		result["preference_autonomy"] = s_auto / float(count)
		result["preference_equality"] = s_eq / float(count)
		result["preference_hierarchy"] = s_hier / float(count)
		result["tolerance_coercion"] = s_coerc / float(count)
		
	return result
