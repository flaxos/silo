# src/sim/population/genetics_invariants.gd
class_name GeneticsInvariants
extends RefCounted

const GeneticsModel = preload("res://src/sim/population/genetics_model.gd")

## Invariant validation for Sprint 21: Genetics, Heredity & Population Health.

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		# 1. Blood type validity
		if not p.blood_type in GeneticsModel.VALID_BLOOD_TYPES:
			errors.append("Person #%d has invalid blood type: '%s'" % [p.id, p.blood_type])
			
		# 2. Trait bounds [0.5, 1.5]
		if p.trait_stamina < 0.499 or p.trait_stamina > 1.501:
			errors.append("Person #%d trait_stamina out of bounds: %f" % [p.id, p.trait_stamina])
		if p.trait_resilience < 0.499 or p.trait_resilience > 1.501:
			errors.append("Person #%d trait_resilience out of bounds: %f" % [p.id, p.trait_resilience])
		if p.trait_metabolism < 0.499 or p.trait_metabolism > 1.501:
			errors.append("Person #%d trait_metabolism out of bounds: %f" % [p.id, p.trait_metabolism])
			
		# 3. Parentage bounds
		if p.parent_ids.size() > 2:
			errors.append("Person #%d has more than 2 parents: %s" % [p.id, str(p.parent_ids)])
			
		# 4. Acyclic pedigree check
		var visited: Dictionary = {p.id: true}
		var queue: Array[int] = []
		for parent_id in p.parent_ids:
			queue.append(parent_id)
			
		var max_depth: int = 20
		var depth: int = 0
		while not queue.is_empty() and depth < max_depth:
			var curr_id: int = queue.pop_front()
			if curr_id <= 0:
				continue
			if curr_id == p.id:
				errors.append("Cyclic lineage detected: Person #%d is their own ancestor!" % p.id)
				break
			var ancestor: Person = registry.get_entity(curr_id) as Person
			if ancestor:
				for anc_parent in ancestor.parent_ids:
					if not visited.has(anc_parent):
						visited[anc_parent] = true
						queue.append(anc_parent)
			depth += 1

	return {
		"is_valid": errors.is_empty(),
		"errors": errors
	}
