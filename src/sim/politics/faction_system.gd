# src/sim/politics/faction_system.gd
class_name FactionSystem
extends BaseSystem

const Faction = preload("res://src/sim/politics/faction.gd")
const SocialGraph = preload("res://src/sim/politics/social_graph.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")

## Domain system managing organic faction emergence, social network recruitment,
## policy response matrices, and inter-faction rivalry dynamics.

const EVALUATION_INTERVAL_TICKS: int = 144 # Evaluated once per simulated day

var last_evaluation_tick: int = -1
var total_factions_spawned: int = 0
var total_recruitment_events: int = 0

func _init() -> void:
	system_id = "faction_system"
	execution_order = 36 # Executes immediately after PoliticalSystem (35)

func setup(_world_state: Variant) -> void:
	var ws: WorldState = _world_state as WorldState
	if ws:
		ws.custom_data["faction_system"] = self

func tick(_world_state: Variant) -> void:
	var ws: WorldState = _world_state as WorldState
	if not ws or not ws.sim_clock:
		return
		
	var cur_tick: int = ws.sim_clock.get_tick()
	
	if cur_tick % EVALUATION_INTERVAL_TICKS == 0 and cur_tick != last_evaluation_tick:
		last_evaluation_tick = cur_tick
		_evaluate_emergent_faction_clustering(ws, cur_tick)
		_evaluate_social_recruitment(ws, cur_tick)
		_update_faction_agendas_and_metrics(ws, cur_tick)
		_update_inter_faction_relations(ws)
		_evaluate_faction_attrition(ws)

func _evaluate_emergent_faction_clustering(ws: WorldState, cur_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	if not registry:
		return
		
	var pids: Array[int] = registry.get_entities_by_type("person")
	var unaligned_adults: Array[Person] = []
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.life_stage in [Person.STAGE_ADULT, Person.STAGE_ELDER] and p.faction_id == 0:
			unaligned_adults.append(p)
			
	if unaligned_adults.size() < 3:
		return
		
	# Find candidate seed groups sharing grievances and social ties
	# Cluster criteria: Shared department or workplace + high class resentment (>0.3) OR low institutional trust (<0.45)
	var dept_candidates: Dictionary = {}
	for p in unaligned_adults:
		var is_aggrieved: bool = (p.class_resentment >= 0.3) or (p.institutional_trust <= 0.45) or (not p.opinion_memories.is_empty())
		if is_aggrieved and p.department_id != "":
			if not dept_candidates.has(p.department_id):
				dept_candidates[p.department_id] = []
			dept_candidates[p.department_id].append(p)
			
	for dept in dept_candidates.keys():
		var candidates: Array = dept_candidates[dept]
		if candidates.size() >= 3:
			# Check if at least 3 share mutual social ties (coworkers or household)
			var cluster: Array[Person] = []
			for p in candidates:
				var person: Person = p as Person
				var ties: Array[Dictionary] = SocialGraph.get_social_connections(ws, person.id)
				var connected_count: int = 0
				for t in ties:
					var target_id: int = int(t.get("target_id", 0))
					for other in candidates:
						if (other as Person).id == target_id:
							connected_count += 1
				if connected_count >= 1:
					cluster.append(person)
					if cluster.size() >= 5: # Cap initial founding cell size
						break
						
			if cluster.size() >= 3:
				_form_new_faction(ws, cluster, dept, cur_tick)

func _form_new_faction(ws: WorldState, founders: Array[Person], dept: String, cur_tick: int) -> Faction:
	var registry: EntityRegistry = ws.entity_registry
	
	# Select leader: highest seniority level, then education
	var leader: Person = founders[0]
	for p in founders:
		if p.seniority_level > leader.seniority_level or (p.seniority_level == leader.seniority_level and p.education_score > leader.education_score):
			leader = p
			
	total_factions_spawned += 1
	var f_id: int = registry.get_entities_by_type("faction").size() + 1
	
	var f_name: String = _generate_faction_name(dept, leader.last_name, total_factions_spawned)
	var faction: Faction = Faction.new(0, f_name, leader.id, cur_tick)
	
	# Calculate initial centroid ideology
	var sum_eq: float = 0.0
	var sum_hier: float = 0.0
	var sum_ref: float = 0.0
	var sum_stab: float = 0.0
	var sum_auto: float = 0.0
	var sum_coerc: float = 0.0
	
	for p in founders:
		sum_eq += p.preference_equality
		sum_hier += p.preference_hierarchy
		sum_ref += p.preference_reform
		sum_stab += p.preference_stability
		sum_auto += p.preference_autonomy
		sum_coerc += p.tolerance_coercion
		
	var n: float = float(founders.size())
	faction.ideology_profile = {
		"preference_equality": sum_eq / n,
		"preference_hierarchy": sum_hier / n,
		"preference_reform": sum_ref / n,
		"preference_stability": sum_stab / n,
		"preference_autonomy": sum_auto / n,
		"tolerance_coercion": sum_coerc / n
	}
	
	faction.manifesto = "Solidarity and collective self-determination for habitat %s workers." % dept
	
	# Register entity
	faction.id = registry.register_entity("faction", faction)
	
	# Assign founders to faction
	for p in founders:
		faction.add_member(p.id)
		p.faction_id = faction.id
		p.sympathiser_faction_id = 0
		
	faction.recalculate_cohesion(ws)
	faction.recalculate_institutional_penetration(ws)
	faction.recalculate_policy_approvals(ws)
	
	return faction

func _evaluate_social_recruitment(ws: WorldState, _cur_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	if not registry:
		return
		
	var fids: Array[int] = registry.get_entities_by_type("faction")
	for fid in fids:
		var faction: Faction = registry.get_entity(fid) as Faction
		if not faction or not faction.is_active:
			continue
			
		# Active members reach out to their social network
		var member_ids_copy: Array[int] = faction.member_ids.duplicate()
		for mid in member_ids_copy:
			var recruiter: Person = registry.get_entity(mid) as Person
			if not recruiter or not recruiter.is_alive:
				continue
				
			var ties: Array[Dictionary] = SocialGraph.get_social_connections(ws, mid)
			for tie in ties:
				var target_id: int = int(tie.get("target_id", 0))
				var target: Person = registry.get_entity(target_id) as Person
				if not target or not target.is_alive or target.faction_id == faction.id:
					continue
					
				# Insulated citizens (e.g. security or high clearance with zero grievances) resist
				var influence: float = SocialGraph.calculate_influence_strength(ws, mid, target_id)
				
				# Sympathiser threshold
				if target.faction_id == 0 and target.sympathiser_faction_id == 0:
					if influence >= 0.25:
						target.sympathiser_faction_id = faction.id
						faction.add_sympathiser(target.id)
						total_recruitment_events += 1
				# Upgrade to full member
				elif target.sympathiser_faction_id == faction.id and target.faction_id == 0:
					var grievance_readiness: bool = (target.class_resentment >= 0.25) or (target.institutional_trust <= 0.5)
					if influence >= 0.40 and grievance_readiness:
						target.faction_id = faction.id
						target.sympathiser_faction_id = 0
						faction.add_member(target.id)
						total_recruitment_events += 1

func _update_faction_agendas_and_metrics(ws: WorldState, _cur_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	if not registry:
		return
		
	var fids: Array[int] = registry.get_entities_by_type("faction")
	for fid in fids:
		var faction: Faction = registry.get_entity(fid) as Faction
		if not faction or not faction.is_active:
			continue
			
		# Compile top grievances from members
		var grievance_counts: Dictionary = {}
		var grievance_severities: Dictionary = {}
		var grievance_depts: Dictionary = {}
		
		for mid in faction.member_ids:
			var p: Person = registry.get_entity(mid) as Person
			if p and p.is_alive:
				for m in p.opinion_memories:
					var et: String = str(m.get("event_type", ""))
					var impact: float = absf(float(m.get("emotional_impact", 0.0)))
					var dept: String = str(m.get("attribution_dept", "administration"))
					if et != "":
						grievance_counts[et] = int(grievance_counts.get(et, 0)) + 1
						grievance_severities[et] = float(grievance_severities.get(et, 0.0)) + impact
						grievance_depts[et] = dept
						
		faction.grievance_agenda.clear()
		for et in grievance_counts.keys():
			var count: int = int(grievance_counts[et])
			var avg_sev: float = float(grievance_severities[et]) / float(count)
			var salience: float = clampf(float(count) / float(max(1, faction.member_ids.size())), 0.1, 1.0)
			faction.grievance_agenda.append({
				"type": et,
				"severity": avg_sev,
				"salience": salience,
				"target_dept": str(grievance_depts.get(et, "administration")),
				"description": _format_grievance_description(et)
			})
			
		# Sort grievances by salience * severity descending
		faction.grievance_agenda.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (float(a.get("salience", 0.0)) * float(a.get("severity", 0.0))) > (float(b.get("salience", 0.0)) * float(b.get("severity", 0.0)))
		)
		
		faction.recalculate_cohesion(ws)
		faction.recalculate_institutional_penetration(ws)
		faction.recalculate_policy_approvals(ws)

func _update_inter_faction_relations(ws: WorldState) -> void:
	var registry: EntityRegistry = ws.entity_registry
	if not registry:
		return
		
	var fids: Array[int] = registry.get_entities_by_type("faction")
	for i in range(fids.size()):
		var f1: Faction = registry.get_entity(fids[i]) as Faction
		if not f1 or not f1.is_active:
			continue
		for j in range(i + 1, fids.size()):
			var f2: Faction = registry.get_entity(fids[j]) as Faction
			if not f2 or not f2.is_active:
				continue
				
			# Calculate ideological compatibility
			var p1_eq: float = float(f1.ideology_profile.get("preference_equality", 0.5))
			var p2_eq: float = float(f2.ideology_profile.get("preference_equality", 0.5))
			var p1_hier: float = float(f1.ideology_profile.get("preference_hierarchy", 0.5))
			var p2_hier: float = float(f2.ideology_profile.get("preference_hierarchy", 0.5))
			var p1_ref: float = float(f1.ideology_profile.get("preference_reform", 0.5))
			var p2_ref: float = float(f2.ideology_profile.get("preference_reform", 0.5))
			var p1_stab: float = float(f1.ideology_profile.get("preference_stability", 0.5))
			var p2_stab: float = float(f2.ideology_profile.get("preference_stability", 0.5))
			
			var diff: float = (absf(p1_eq - p2_eq) + absf(p1_hier - p2_hier) + absf(p1_ref - p2_ref) + absf(p1_stab - p2_stab)) / 4.0
			var score: float = clampf(1.0 - (diff * 2.0), -1.0, 1.0)
			
			f1.inter_faction_relations[f2.id] = score
			f2.inter_faction_relations[f1.id] = score

func _evaluate_faction_attrition(ws: WorldState) -> void:
	var registry: EntityRegistry = ws.entity_registry
	if not registry:
		return
		
	var fids: Array[int] = registry.get_entities_by_type("faction")
	for fid in fids:
		var faction: Faction = registry.get_entity(fid) as Faction
		if not faction:
			continue
			
		var living_members: Array[int] = []
		for mid in faction.member_ids:
			var p: Person = registry.get_entity(mid) as Person
			if p and p.is_alive:
				living_members.append(mid)
			elif p and not p.is_alive:
				p.faction_id = 0
				
		faction.member_ids = living_members
		
		var living_symps: Array[int] = []
		for sid in faction.sympathiser_ids:
			var sp: Person = registry.get_entity(sid) as Person
			if sp and sp.is_alive:
				living_symps.append(sid)
			elif sp and not sp.is_alive:
				sp.sympathiser_faction_id = 0
				
		faction.sympathiser_ids = living_symps
		
		if faction.member_ids.is_empty():
			faction.is_active = false
		elif not faction.member_ids.has(faction.leader_id):
			faction.leader_id = faction.member_ids[0]

func _generate_faction_name(dept: String, leader_surname: String, count: int) -> String:
	if dept.begins_with("industry") or dept == "industry":
		return "Foundry & Mining Solidarity Pact" if count % 2 == 1 else "Industrial Guild of %s" % leader_surname
	elif dept.begins_with("engineering") or dept == "engineering":
		return "Engineering Technics Union" if count % 2 == 1 else "Infrastructure Preservation Front"
	elif dept.begins_with("medical"):
		return "Public Health & Bio-Safety Bloc"
	elif dept.begins_with("education"):
		return "Civil Pedagogy & Reform League"
	elif dept.begins_with("security"):
		return "Order & Security Coalition"
	elif dept.begins_with("executive") or dept == "it":
		return "Data Autonomy Collective"
	else:
		return "Labour Coalition of %s" % leader_surname

func _format_grievance_description(event_type: String) -> String:
	match event_type:
		PoliticalEvent.EVENT_DEHYDRATION_SUFFERED:
			return "Critical Habitat Water Shortages & Utility Neglect"
		PoliticalEvent.EVENT_WATER_RATIONED:
			return "Involuntary Water Consumption Quotas"
		PoliticalEvent.EVENT_HOUSING_OVERCROWDED:
			return "Overcrowded Residential Quarters & Bed Deficits"
		PoliticalEvent.EVENT_COERCIVE_ORDER:
			return "Authoritarian Executive Labor Directives"
		PoliticalEvent.EVENT_FAMILY_BEREAVEMENT:
			return "Preventable Habitat Mortality & Workplace Casualties"
		_:
			return "Systemic Workplace & Living Discontent (%s)" % event_type

func serialize() -> Dictionary:
	return {
		"last_evaluation_tick": last_evaluation_tick,
		"total_factions_spawned": total_factions_spawned,
		"total_recruitment_events": total_recruitment_events
	}

func deserialize(data: Dictionary) -> void:
	last_evaluation_tick = int(data.get("last_evaluation_tick", -1))
	total_factions_spawned = int(data.get("total_factions_spawned", 0))
	total_recruitment_events = int(data.get("total_recruitment_events", 0))
