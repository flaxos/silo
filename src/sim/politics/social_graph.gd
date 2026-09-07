# src/sim/politics/social_graph.gd
class_name SocialGraph
extends RefCounted

## Bounded social relationship graph and network query service.
## Computes meaningful, realistic social ties between citizens (family, coworkers, neighbors, cohorts)
## without maintaining an unbounded all-to-all dense matrix.

const RELATION_FAMILY: String = "family"
const RELATION_HOUSEHOLD: String = "household"
const RELATION_COWORKER: String = "coworker"
const RELATION_SCHOOL_COHORT: String = "school_cohort"
const RELATION_NEIGHBOR: String = "neighbor"
const RELATION_SHARED_INCIDENT: String = "shared_incident"

const WEIGHT_FAMILY: float = 0.95
const WEIGHT_HOUSEHOLD: float = 0.85
const WEIGHT_COWORKER: float = 0.65
const WEIGHT_SCHOOL_COHORT: float = 0.60
const WEIGHT_SHARED_INCIDENT: float = 0.50
const WEIGHT_NEIGHBOR: float = 0.35

static func get_social_connections(ws: WorldState, person_id: int) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	if not ws or not ws.entity_registry:
		return connections
		
	var registry: EntityRegistry = ws.entity_registry
	var person: Person = registry.get_entity(person_id) as Person
	if not person or not person.is_alive:
		return connections
		
	var seen: Dictionary = {} # target_id -> index in connections
	
	# 1. Family & Partner Ties
	if person.partner_id > 0 and person.partner_id != person_id:
		var p_partner: Person = registry.get_entity(person.partner_id) as Person
		if p_partner and p_partner.is_alive:
			_add_connection(connections, seen, p_partner.id, "%s %s" % [p_partner.first_name, p_partner.last_name], RELATION_FAMILY, WEIGHT_FAMILY, 0.9)
			
	for pid in person.parent_ids:
		if pid > 0 and pid != person_id:
			var p_parent: Person = registry.get_entity(pid) as Person
			if p_parent and p_parent.is_alive:
				_add_connection(connections, seen, p_parent.id, "%s %s" % [p_parent.first_name, p_parent.last_name], RELATION_FAMILY, WEIGHT_FAMILY, 0.85)
				
	for cid in person.children_ids:
		if cid > 0 and cid != person_id:
			var p_child: Person = registry.get_entity(cid) as Person
			if p_child and p_child.is_alive:
				_add_connection(connections, seen, p_child.id, "%s %s" % [p_child.first_name, p_child.last_name], RELATION_FAMILY, WEIGHT_FAMILY, 0.9)
				
	# 2. Household Co-Residents
	if person.household_id > 0:
		var hh: Household = registry.get_entity(person.household_id) as Household
		if hh:
			for mid in hh.member_ids:
				if mid != person_id and mid > 0:
					var p_mate: Person = registry.get_entity(mid) as Person
					if p_mate and p_mate.is_alive:
						_add_connection(connections, seen, p_mate.id, "%s %s" % [p_mate.first_name, p_mate.last_name], RELATION_HOUSEHOLD, WEIGHT_HOUSEHOLD, 0.8)
						
	# 3. Coworkers (same workplace room)
	if person.workplace_room_id > 0:
		var pids: Array[int] = registry.get_entities_by_type("person")
		for other_id in pids:
			if other_id == person_id:
				continue
			var other_p: Person = registry.get_entity(other_id) as Person
			if other_p and other_p.is_alive and other_p.workplace_room_id == person.workplace_room_id:
				var shift_bonus: float = 0.1 if other_p.shift_id == person.shift_id else 0.0
				_add_connection(connections, seen, other_p.id, "%s %s" % [other_p.first_name, other_p.last_name], RELATION_COWORKER, WEIGHT_COWORKER + shift_bonus, 0.65)
				
	# 4. School Cohort
	if person.school_room_id > 0 and person.life_stage in [Person.STAGE_CHILD, Person.STAGE_STUDENT]:
		var pids: Array[int] = registry.get_entities_by_type("person")
		for other_id in pids:
			if other_id == person_id:
				continue
			var other_p: Person = registry.get_entity(other_id) as Person
			if other_p and other_p.is_alive and other_p.school_room_id == person.school_room_id:
				_add_connection(connections, seen, other_p.id, "%s %s" % [other_p.first_name, other_p.last_name], RELATION_SCHOOL_COHORT, WEIGHT_SCHOOL_COHORT, 0.6)
				
	# 5. Neighbors (living in same room or adjacent residential rooms on same level)
	if person.home_room_id > 0:
		var home_room: Room = registry.get_entity(person.home_room_id) as Room
		if home_room:
			var pids: Array[int] = registry.get_entities_by_type("person")
			for other_id in pids:
				if other_id == person_id:
					continue
				var other_p: Person = registry.get_entity(other_id) as Person
				if other_p and other_p.is_alive and other_p.home_room_id > 0:
					var other_room: Room = registry.get_entity(other_p.home_room_id) as Room
					if other_room and other_room.level == home_room.level and other_room.sector_id == home_room.sector_id:
						_add_connection(connections, seen, other_p.id, "%s %s" % [other_p.first_name, other_p.last_name], RELATION_NEIGHBOR, WEIGHT_NEIGHBOR, 0.45)
						
	# 6. Shared Incident Memory (shared acute events)
	if not person.opinion_memories.is_empty():
		var p_event_types: Dictionary = {}
		for m in person.opinion_memories:
			p_event_types[m.get("event_type", "")] = true
			
		var pids: Array[int] = registry.get_entities_by_type("person")
		for other_id in pids:
			if other_id == person_id or seen.has(other_id):
				continue
			var other_p: Person = registry.get_entity(other_id) as Person
			if other_p and other_p.is_alive and not other_p.opinion_memories.is_empty():
				for om in other_p.opinion_memories:
					var et: String = om.get("event_type", "")
					if p_event_types.has(et) and et != "":
						_add_connection(connections, seen, other_p.id, "%s %s" % [other_p.first_name, other_p.last_name], RELATION_SHARED_INCIDENT, WEIGHT_SHARED_INCIDENT, 0.5)
						break
						
	# Sort connections by weight descending
	connections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0))
	)
	
	return connections

static func get_coworkers(ws: WorldState, person_id: int) -> Array[int]:
	var result: Array[int] = []
	if not ws or not ws.entity_registry:
		return result
	var registry: EntityRegistry = ws.entity_registry
	var person: Person = registry.get_entity(person_id) as Person
	if not person or person.workplace_room_id <= 0:
		return result
		
	var pids: Array[int] = registry.get_entities_by_type("person")
	for pid in pids:
		if pid == person_id:
			continue
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.workplace_room_id == person.workplace_room_id:
			result.append(pid)
	return result

static func get_household_mates(ws: WorldState, person_id: int) -> Array[int]:
	var result: Array[int] = []
	if not ws or not ws.entity_registry:
		return result
	var registry: EntityRegistry = ws.entity_registry
	var person: Person = registry.get_entity(person_id) as Person
	if not person or person.household_id <= 0:
		return result
	var hh: Household = registry.get_entity(person.household_id) as Household
	if not hh:
		return result
	for mid in hh.member_ids:
		if mid != person_id and mid > 0:
			result.append(mid)
	return result

static func calculate_influence_strength(ws: WorldState, recruiter_id: int, target_id: int) -> float:
	if not ws or not ws.entity_registry:
		return 0.0
	var registry: EntityRegistry = ws.entity_registry
	var recruiter: Person = registry.get_entity(recruiter_id) as Person
	var target: Person = registry.get_entity(target_id) as Person
	if not recruiter or not target or not recruiter.is_alive or not target.is_alive:
		return 0.0
		
	# Find tie weight
	var ties: Array[Dictionary] = get_social_connections(ws, recruiter_id)
	var tie_weight: float = 0.0
	for t in ties:
		if int(t.get("target_id", 0)) == target_id:
			tie_weight = float(t.get("weight", 0.0))
			break
			
	if tie_weight <= 0.0:
		return 0.0
			
	# Recruiter status / credibility
	var seniority_bonus: float = 1.0 + (float(recruiter.seniority_level) * 0.1)
	var education_bonus: float = 1.0 + (recruiter.education_score / 200.0)
	var credibility: float = seniority_bonus * education_bonus
	
	# Ideological alignment (Euclidean or Dot similarity in political vector)
	var similarity: float = calculate_ideological_similarity(recruiter, target)
	
	# Target openness: Lower institutional trust increases receptivity to unofficial movements
	# High trust officials (trust > 0.8) have 0 openness to grievance movements
	var openness: float = clampf(1.0 - target.institutional_trust, 0.0, 1.0)
	if target.security_clearance >= 2 and target.institutional_trust >= 0.75:
		openness *= 0.1 # High clearance loyalty resistance
	
	var score: float = tie_weight * credibility * similarity * openness
	return clampf(score, 0.0, 1.0)

static func calculate_ideological_similarity(p1: Person, p2: Person) -> float:
	if not p1 or not p2:
		return 0.5
	var d_eq: float = absf(p1.preference_equality - p2.preference_equality)
	var d_hier: float = absf(p1.preference_hierarchy - p2.preference_hierarchy)
	var d_ref: float = absf(p1.preference_reform - p2.preference_reform)
	var d_stab: float = absf(p1.preference_stability - p2.preference_stability)
	var d_auto: float = absf(p1.preference_autonomy - p2.preference_autonomy)
	var d_coerc: float = absf(p1.tolerance_coercion - p2.tolerance_coercion)
	
	var avg_diff: float = (d_eq + d_hier + d_ref + d_stab + d_auto + d_coerc) / 6.0
	return clampf(1.0 - avg_diff, 0.0, 1.0)

static func _add_connection(
	connections: Array[Dictionary],
	seen: Dictionary,
	target_id: int,
	target_name: String,
	relation_type: String,
	weight: float,
	trust: float
) -> void:
	if seen.has(target_id):
		var idx: int = seen[target_id]
		# Keep higher weight if multiple relations exist (e.g. family + coworker)
		if weight > float(connections[idx].get("weight", 0.0)):
			connections[idx]["weight"] = weight
			connections[idx]["relation_type"] = relation_type
			connections[idx]["trust"] = trust
		return
		
	seen[target_id] = connections.size()
	connections.append({
		"target_id": target_id,
		"target_name": target_name,
		"relation_type": relation_type,
		"weight": weight,
		"trust": trust
	})
