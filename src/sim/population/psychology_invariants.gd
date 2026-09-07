# src/sim/population/psychology_invariants.gd
class_name PsychologyInvariants
extends RefCounted

## Invariant validation for Sprint 19: Psychology, Stress & Adaptation.

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		if p.stress < -0.001 or p.stress > 100.001:
			errors.append("Person #%d stress %f out of [0, 100] bounds" % [p.id, p.stress])
		if p.fatigue < -0.001 or p.fatigue > 100.001:
			errors.append("Person #%d fatigue %f out of [0, 100] bounds" % [p.id, p.fatigue])
		if p.morale < -0.001 or p.morale > 100.001:
			errors.append("Person #%d morale %f out of [0, 100] bounds" % [p.id, p.morale])
		if p.burnout < -0.001 or p.burnout > 100.001:
			errors.append("Person #%d burnout %f out of [0, 100] bounds" % [p.id, p.burnout])
			
	return {
		"is_valid": errors.is_empty(),
		"errors": errors
	}
