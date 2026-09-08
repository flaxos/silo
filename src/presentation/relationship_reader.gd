# src/presentation/relationship_reader.gd
class_name RelationshipReader
extends RefCounted

const Relationship = preload("res://src/sim/population/relationship.gd")

## Decoupled read-model adapter for interpersonal relationships, romance and households.

static func get_relationships_summary(ws: WorldState) -> Dictionary:
	var total_rels: int = 0
	var partners_count: int = 0
	var friends_count: int = 0
	var romantic_count: int = 0
	var estranged_count: int = 0
	
	if ws.custom_data.has("relationships"):
		var rels: Dictionary = ws.custom_data["relationships"]
		total_rels = rels.size()
		for k in rels:
			var r: Relationship = rels[k]
			match r.status:
				Relationship.STATUS_PARTNER:
					partners_count += 1
				Relationship.STATUS_FRIEND, Relationship.STATUS_CLOSE_FRIEND:
					friends_count += 1
				Relationship.STATUS_ROMANTIC_INTEREST:
					romantic_count += 1
				Relationship.STATUS_ESTRANGED:
					estranged_count += 1
					
	return {
		"total_relationships_tracked": total_rels,
		"active_partnerships": partners_count,
		"friendships": friends_count,
		"romantic_interests": romantic_count,
		"estranged_partnerships": estranged_count
	}

static func get_person_relationships(ws: WorldState, person_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ws.custom_data.has("relationships"):
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var rels: Dictionary = ws.custom_data["relationships"]
	for k in rels:
		var r: Relationship = rels[k]
		if r.person_a_id == person_id or r.person_b_id == person_id:
			var other_id: int = r.person_b_id if r.person_a_id == person_id else r.person_a_id
			var other: Person = registry.get_entity(other_id) as Person
			var other_name: String = "%s %s" % [other.first_name, other.last_name] if other else "Unknown #%d" % other_id
			result.append({
				"target_id": other_id,
				"target_name": other_name,
				"familiarity": r.familiarity,
				"affection": r.affection,
				"attraction": r.attraction,
				"trust": r.trust,
				"conflict": r.conflict,
				"status": r.status,
				"shared_history_ticks": r.shared_history_ticks
			})
	return result

static func get_household_dynamics(ws: WorldState, household_id: int) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry
	var hh: Household = registry.get_entity(household_id) as Household
	if not hh:
		return {"error": "Household not found"}
		
	var avg_affection: float = 0.0
	var avg_conflict: float = 0.0
	var pair_count: int = 0
	
	if ws.custom_data.has("relationships"):
		var rels: Dictionary = ws.custom_data["relationships"]
		for i in range(hh.member_ids.size()):
			for j in range(i + 1, hh.member_ids.size()):
				var id1: int = hh.member_ids[i]
				var id2: int = hh.member_ids[j]
				var key: String = Relationship.make_key(id1, id2)
				if rels.has(key):
					var r: Relationship = rels[key]
					avg_affection += r.affection
					avg_conflict += r.conflict
					pair_count += 1
					
	if pair_count > 0:
		avg_affection /= pair_count
		avg_conflict /= pair_count
		
	return {
		"household_id": household_id,
		"head_id": hh.head_id,
		"members_count": hh.member_ids.size(),
		"internal_harmony": avg_affection,
		"internal_tension": avg_conflict,
		"active_pairs_tracked": pair_count
	}
