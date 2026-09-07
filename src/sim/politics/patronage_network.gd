# src/sim/politics/patronage_network.gd
class_name PatronageNetwork
extends RefCounted

## Analytical service modeling informal power, patron-client dependencies,
## nepotism incentives, and conflicts of interest across the habitat.

static func calculate_informal_power(ws: WorldState, person_id: int) -> float:
	if not ws or not ws.entity_registry:
		return 0.0
	var registry: EntityRegistry = ws.entity_registry
	var person: Person = registry.get_entity(person_id) as Person
	if not person or not person.is_alive:
		return 0.0
		
	var power: float = 0.0
	
	# 1. Formal Clearance & Seniority Base
	power += float(person.security_clearance) * 15.0
	power += float(person.seniority_level) * 5.0
	power += (person.education_score / 100.0) * 10.0
	
	# 2. Favour Leverage (Debts owed to this person by clients)
	var favours: Array = ws.custom_data.get("favours", [])
	for f_item in favours:
		var f: Favour = f_item as Favour
		if f and not f.is_settled and f.granter_id == person_id:
			power += f.obligation_value * 12.0
		elif f and not f.is_settled and f.recipient_id == person_id:
			# Being indebted slightly reduces net informal autonomy
			power -= f.obligation_value * 3.0
			
	# 3. Faction Leadership & Influence
	if person.faction_id > 0:
		var faction: Faction = registry.get_entity(person.faction_id) as Faction
		if faction and faction.is_active:
			if faction.leader_id == person_id:
				power += 25.0 # Faction Leader
			else:
				power += 5.0  # Faction Member
				
	# 4. Social Network Connectivity
	var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, person_id)
	power += float(connections.size()) * 1.5
	
	return maxf(0.0, power)

static func get_patron_client_clusters(ws: WorldState) -> Array[Dictionary]:
	var clusters: Array[Dictionary] = []
	if not ws or not ws.entity_registry:
		return clusters
		
	var registry: EntityRegistry = ws.entity_registry
	var favours: Array = ws.custom_data.get("favours", [])
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	# Map granters to their active unsettled clients
	var patron_clients: Dictionary = {} # patron_id -> Array of Dictionary { client_id, total_debt, favour_count }
	
	for f_item in favours:
		var f: Favour = f_item as Favour
		if not f or f.is_settled:
			continue
		if not patron_clients.has(f.granter_id):
			patron_clients[f.granter_id] = {}
		var client_map: Dictionary = patron_clients[f.granter_id]
		if not client_map.has(f.recipient_id):
			client_map[f.recipient_id] = {"total_debt": 0.0, "favour_count": 0}
		client_map[f.recipient_id]["total_debt"] += f.obligation_value
		client_map[f.recipient_id]["favour_count"] += 1
		
	for patron_id in patron_clients.keys():
		var patron: Person = registry.get_entity(patron_id) as Person
		if not patron or not patron.is_alive:
			continue
			
		var client_list: Array[Dictionary] = []
		var client_map: Dictionary = patron_clients[patron_id]
		var total_network_debt: float = 0.0
		
		for client_id in client_map.keys():
			var client: Person = registry.get_entity(client_id) as Person
			if client and client.is_alive:
				var debt_val: float = float(client_map[client_id]["total_debt"])
				total_network_debt += debt_val
				client_list.append({
					"client_id": client.id,
					"client_name": client.get_full_name(),
					"occupation": client.occupation_id,
					"debt_value": debt_val,
					"favour_count": int(client_map[client_id]["favour_count"])
				})
				
		client_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("debt_value", 0.0)) > float(b.get("debt_value", 0.0))
		)
		
		clusters.append({
			"patron_id": patron.id,
			"patron_name": patron.get_full_name(),
			"occupation": patron.occupation_id,
			"department": patron.department_id,
			"clearance": patron.security_clearance,
			"informal_power": calculate_informal_power(ws, patron.id),
			"client_count": client_list.size(),
			"total_debt_held": total_network_debt,
			"clients": client_list
		})
		
	clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("informal_power", 0.0)) > float(b.get("informal_power", 0.0))
	)
	
	return clusters

static func get_conflict_of_interest(ws: WorldState, official_id: int) -> Dictionary:
	var result: Dictionary = {
		"official_id": official_id,
		"has_conflict": false,
		"conflict_score": 0.0,
		"conflicted_relations": []
	}
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var official: Person = registry.get_entity(official_id) as Person
	if not official or not official.is_alive or official.security_clearance < 1:
		return result
		
	var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, official_id)
	var score: float = 0.0
	var relations: Array[Dictionary] = []
	
	for conn in connections:
		var target_id: int = int(conn.get("target_id", 0))
		var target: Person = registry.get_entity(target_id) as Person
		if not target or not target.is_alive:
			continue
			
		var rel_type: String = str(conn.get("relation_type", ""))
		var tie_w: float = float(conn.get("weight", 0.0))
		
		# Departmental jurisdiction conflict
		var dept_match: bool = (target.department_id == official.department_id and target.department_id != "")
		var workplace_match: bool = (target.workplace_room_id == official.workplace_room_id and official.workplace_room_id > 0)
		var faction_match: bool = (target.faction_id == official.faction_id and official.faction_id > 0)
		
		if dept_match or workplace_match or faction_match:
			var sub_score: float = tie_w * (1.5 if rel_type == SocialGraph.RELATION_FAMILY else 1.0)
			if dept_match:
				sub_score += 0.5
			if faction_match:
				sub_score += 0.3
				
			score += sub_score
			relations.append({
				"person_id": target.id,
				"name": target.get_full_name(),
				"relation_type": rel_type,
				"department_match": dept_match,
				"workplace_match": workplace_match,
				"faction_match": faction_match,
				"sub_score": sub_score
			})
			
	result["conflict_score"] = clampf(score / 5.0, 0.0, 1.0)
	result["has_conflict"] = (result["conflict_score"] > 0.25)
	result["conflicted_relations"] = relations
	return result

static func calculate_corruption_temptation(ws: WorldState, person_id: int) -> float:
	if not ws or not ws.entity_registry:
		return 0.0
	var registry: EntityRegistry = ws.entity_registry
	var person: Person = registry.get_entity(person_id) as Person
	if not person or not person.is_alive:
		return 0.0
		
	# 1. Base Disaffection & Resentment (Higher class resentment + lower trust = higher temptation)
	var disaffection: float = (1.0 - person.institutional_trust) * 0.4 + person.class_resentment * 0.4 + (1.0 - person.perceived_fairness) * 0.2
	
	# 2. Opportunity / Access Factor (Clearance or workplace access)
	var opportunity: float = 0.2
	if person.security_clearance >= 1:
		opportunity += float(person.security_clearance) * 0.15
	if person.workplace_room_id > 0:
		opportunity += 0.2 # Access to inventory or physical equipment
		
	# 3. Social Pressure / Needy Family Factor
	var social_pressure: float = 0.0
	var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, person_id)
	for conn in connections:
		var target_id: int = int(conn.get("target_id", 0))
		var target: Person = registry.get_entity(target_id) as Person
		if target and target.is_alive:
			if target.economic_satisfaction < 0.4:
				social_pressure += 0.1
			if target.is_severely_dehydrated():
				social_pressure += 0.3
				
	social_pressure = clampf(social_pressure, 0.0, 0.5)
	
	var total_temptation: float = (disaffection * 0.4) + (opportunity * 0.3) + (social_pressure * 0.3)
	return clampf(total_temptation, 0.0, 1.0)
