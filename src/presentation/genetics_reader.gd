# src/presentation/genetics_reader.gd
class_name GeneticsReader
extends RefCounted

const GeneticsModel = preload("res://src/sim/population/genetics_model.gd")

## Decoupled read-model adapter for population genetics and hereditary traits.

static func get_population_genetics_summary(ws: WorldState) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	var blood_counts: Dictionary = {}
	for b in GeneticsModel.VALID_BLOOD_TYPES:
		blood_counts[b] = 0
		
	var living_count: int = 0
	var sum_stamina: float = 0.0
	var sum_resilience: float = 0.0
	var sum_metabolism: float = 0.0
	var condition_counts: Dictionary = {}
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		living_count += 1
		var bt: String = p.blood_type if p.blood_type in blood_counts else "O+"
		blood_counts[bt] += 1
		
		sum_stamina += p.trait_stamina
		sum_resilience += p.trait_resilience
		sum_metabolism += p.trait_metabolism
		
		for cond in p.congenital_conditions:
			condition_counts[cond] = condition_counts.get(cond, 0) + 1
			
	var avg_stamina: float = (sum_stamina / living_count) if living_count > 0 else 1.0
	var avg_resilience: float = (sum_resilience / living_count) if living_count > 0 else 1.0
	var avg_metabolism: float = (sum_metabolism / living_count) if living_count > 0 else 1.0
	
	return {
		"living_population": living_count,
		"blood_type_distribution": blood_counts,
		"average_stamina": avg_stamina,
		"average_resilience": avg_resilience,
		"average_metabolism": avg_metabolism,
		"congenital_conditions_count": condition_counts
	}

static func get_person_genetics(ws: WorldState, person_id: int) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry
	var p: Person = registry.get_entity(person_id) as Person
	if not p:
		return {"error": "Person not found"}
		
	var partner_rel: float = 0.0
	if p.partner_id > 0:
		var partner: Person = registry.get_entity(p.partner_id) as Person
		if partner:
			partner_rel = GeneticsModel.compute_relatedness(registry, p, partner)
			
	return {
		"person_id": p.id,
		"name": "%s %s" % [p.first_name, p.last_name],
		"blood_type": p.blood_type,
		"trait_stamina": p.trait_stamina,
		"trait_resilience": p.trait_resilience,
		"trait_metabolism": p.trait_metabolism,
		"congenital_conditions": p.congenital_conditions,
		"parent_ids": p.parent_ids,
		"partner_relatedness": partner_rel
	}
