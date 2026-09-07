# src/sim/population/relationship_invariants.gd
class_name RelationshipInvariants
extends RefCounted

const Relationship = preload("res://src/sim/population/relationship.gd")
const RelationshipSystem = preload("res://src/sim/population/relationship_system.gd")

## Invariant validation for Sprint 20: Relationships, Romance & Household Dynamics.

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = ws.entity_registry
	var rel_sys: RelationshipSystem = null
	
	if ws.custom_data.has("relationships"):
		var rels: Dictionary = ws.custom_data["relationships"]
		for key in rels:
			var rel: Relationship = rels[key]
			if rel.person_a_id >= rel.person_b_id:
				errors.append("Relationship key %s invalid ID order (%d >= %d)" % [key, rel.person_a_id, rel.person_b_id])
				
			var p1: Person = registry.get_entity(rel.person_a_id) as Person
			var p2: Person = registry.get_entity(rel.person_b_id) as Person
			if not p1:
				errors.append("Relationship %s references non-existent person A #%d" % [key, rel.person_a_id])
			if not p2:
				errors.append("Relationship %s references non-existent person B #%d" % [key, rel.person_b_id])
				
			if rel.familiarity < -0.001 or rel.familiarity > 100.001:
				errors.append("Relationship %s familiarity out of bounds: %f" % [key, rel.familiarity])
			if rel.affection < -0.001 or rel.affection > 100.001:
				errors.append("Relationship %s affection out of bounds: %f" % [key, rel.affection])
			if rel.attraction < -0.001 or rel.attraction > 100.001:
				errors.append("Relationship %s attraction out of bounds: %f" % [key, rel.attraction])
			if rel.trust < -0.001 or rel.trust > 100.001:
				errors.append("Relationship %s trust out of bounds: %f" % [key, rel.trust])
			if rel.conflict < -0.001 or rel.conflict > 100.001:
				errors.append("Relationship %s conflict out of bounds: %f" % [key, rel.conflict])
				
			# Incest taboo invariant
			if rel.status == Relationship.STATUS_PARTNER and p1 and p2:
				if p1.id in p2.parent_ids or p2.id in p1.parent_ids:
					errors.append("Illegal incestuous partnership between parent and child: #%d and #%d" % [p1.id, p2.id])
				for pid in p1.parent_ids:
					if pid > 0 and pid in p2.parent_ids:
						errors.append("Illegal incestuous partnership between siblings: #%d and #%d" % [p1.id, p2.id])

	# Check partner reciprocity on living persons
	var pids: Array[int] = registry.get_entities_by_type("person")
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.partner_id > 0:
			var partner: Person = registry.get_entity(p.partner_id) as Person
			if not partner:
				errors.append("Person #%d references non-existent partner #%d" % [p.id, p.partner_id])
			elif partner.is_alive and partner.partner_id != p.id:
				errors.append("Non-reciprocal partnership: #%d points to #%d, but partner points to #%d" % [p.id, partner.id, partner.partner_id])

	return {
		"is_valid": errors.is_empty(),
		"errors": errors
	}
