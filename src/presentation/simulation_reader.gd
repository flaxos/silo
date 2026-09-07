# src/presentation/simulation_reader.gd
class_name SimulationReader
extends RefCounted

const PoliticalSystem = preload("res://src/sim/politics/political_system.gd")
const LegitimacyModel = preload("res://src/sim/politics/legitimacy_model.gd")
const OpinionMemory = preload("res://src/sim/politics/opinion_memory.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")
const Faction = preload("res://src/sim/politics/faction.gd")
const FactionSystem = preload("res://src/sim/politics/faction_system.gd")
const SocialGraph = preload("res://src/sim/politics/social_graph.gd")
const Favour = preload("res://src/sim/politics/favour.gd")
const IllicitAction = preload("res://src/sim/politics/illicit_action.gd")
const PatronageNetwork = preload("res://src/sim/politics/patronage_network.gd")
const CorruptionSystem = preload("res://src/sim/politics/corruption_system.gd")

## Extracts read-only projections and summaries from authoritative WorldState without mutating state.

static func get_clock_summary(ws: WorldState) -> Dictionary:
	if not ws or not ws.sim_clock:
		return {"tick": 0, "formatted_time": "Year 1, Day 1 (00:00)"}
	var clock: SimClock = ws.sim_clock
	return {
		"tick": clock.get_tick(),
		"year": clock.get_year(),
		"day_of_year": clock.get_day_of_year(),
		"hour": clock.get_hour_of_day(),
		"minute": clock.get_minute_of_hour(),
		"tick_of_day": clock.get_tick_of_day(),
		"formatted_time": clock.get_formatted_time(),
		"checksum": ws.get_state_checksum()
	}

static func get_population_summary(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"total_recorded": 0,
		"living_count": 0,
		"deceased_count": 0,
		"infants": 0,
		"children": 0,
		"students": 0,
		"adults": 0,
		"elders": 0,
		"employed_count": 0,
		"avg_hydration": 0.0,
		"avg_health": 0.0,
		"avg_education": 0.0,
		"dehydrated_count": 0,
		"activity_counts": {
			"SLEEPING": 0,
			"TRAVELING": 0,
			"WORKING": 0,
			"STUDYING": 0,
			"EATING": 0,
			"HYGIENE": 0,
			"RECREATING": 0,
			"IDLE": 0
		}
	}
	
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	result["total_recorded"] = pids.size()
	
	var total_hyd: float = 0.0
	var total_hlth: float = 0.0
	var total_edu: float = 0.0
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p:
			continue
			
		if not p.is_alive:
			result["deceased_count"] += 1
			continue
			
		result["living_count"] += 1
		total_hyd += p.hydration_percent
		total_hlth += p.health_percent
		total_edu += p.education_score
		
		if p.is_severely_dehydrated():
			result["dehydrated_count"] += 1
			
		match p.life_stage:
			Person.STAGE_INFANT:
				result["infants"] += 1
			Person.STAGE_CHILD:
				result["children"] += 1
			Person.STAGE_STUDENT:
				result["students"] += 1
			Person.STAGE_ADULT:
				result["adults"] += 1
				if p.occupation_id != "unassigned" and p.occupation_id != "none":
					result["employed_count"] += 1
			Person.STAGE_ELDER:
				result["elders"] += 1
				
		match p.current_activity:
			Person.ACTIVITY_SLEEPING:
				result["activity_counts"]["SLEEPING"] += 1
			Person.ACTIVITY_TRAVELING:
				result["activity_counts"]["TRAVELING"] += 1
			Person.ACTIVITY_WORKING:
				result["activity_counts"]["WORKING"] += 1
			Person.ACTIVITY_STUDYING:
				result["activity_counts"]["STUDYING"] += 1
			Person.ACTIVITY_EATING:
				result["activity_counts"]["EATING"] += 1
			Person.ACTIVITY_HYGIENE:
				result["activity_counts"]["HYGIENE"] += 1
			Person.ACTIVITY_RECREATING:
				result["activity_counts"]["RECREATING"] += 1
			Person.ACTIVITY_IDLE:
				result["activity_counts"]["IDLE"] += 1
				
	var living: int = result["living_count"]
	if living > 0:
		result["avg_hydration"] = total_hyd / float(living)
		result["avg_health"] = total_hlth / float(living)
		result["avg_education"] = total_edu / float(living)
		
	return result

static func get_person_profile(ws: WorldState, person_id: int) -> Dictionary:
	if not ws or not ws.entity_registry:
		return {}
	var registry: EntityRegistry = ws.entity_registry
	var p: Person = registry.get_entity(person_id) as Person
	if not p:
		return {}
		
	var stage_name: String = "ADULT"
	match p.life_stage:
		Person.STAGE_INFANT: stage_name = "INFANT"
		Person.STAGE_CHILD: stage_name = "CHILD"
		Person.STAGE_STUDENT: stage_name = "STUDENT"
		Person.STAGE_ADULT: stage_name = "ADULT"
		Person.STAGE_ELDER: stage_name = "ELDER"
		
	var activity_name: String = "IDLE"
	match p.current_activity:
		Person.ACTIVITY_SLEEPING: activity_name = "SLEEPING"
		Person.ACTIVITY_TRAVELING: activity_name = "TRAVELING"
		Person.ACTIVITY_WORKING: activity_name = "WORKING"
		Person.ACTIVITY_STUDYING: activity_name = "STUDYING"
		Person.ACTIVITY_EATING: activity_name = "EATING"
		Person.ACTIVITY_HYGIENE: activity_name = "HYGIENE"
		Person.ACTIVITY_RECREATING: activity_name = "RECREATING"
		Person.ACTIVITY_IDLE: activity_name = "IDLE"
		
	var shift_name: String = "DAY"
	match p.shift_id:
		Occupation.SHIFT_DAY: shift_name = "DAY"
		Occupation.SHIFT_SWING: shift_name = "SWING"
		Occupation.SHIFT_NIGHT: shift_name = "NIGHT"
		Occupation.SHIFT_OFF: shift_name = "OFF"
		
	var current_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	var age: int = p.get_age_years(current_tick)
	
	return {
		"id": p.id,
		"first_name": p.first_name,
		"last_name": p.last_name,
		"full_name": p.get_full_name(),
		"sex": "Female" if p.sex == Person.SEX_FEMALE else "Male",
		"age_years": age,
		"life_stage": stage_name,
		"is_alive": p.is_alive,
		"hydration_percent": p.hydration_percent,
		"health_percent": p.health_percent,
		"education_score": p.education_score,
		"tenure_ticks": p.tenure_ticks,
		"seniority_level": p.seniority_level,
		"security_clearance": p.security_clearance,
		"occupation_id": p.occupation_id,
		"department_id": p.department_id,
		"shift": shift_name,
		"activity": activity_name,
		"household_id": p.household_id,
		"home_room_id": p.home_room_id,
		"workplace_room_id": p.workplace_room_id,
		"school_room_id": p.school_room_id,
		"canteen_room_id": p.canteen_room_id,
		"current_location_id": p.current_location_id,
		"parent_ids": p.parent_ids.duplicate(),
		"children_ids": p.children_ids.duplicate(),
		"partner_id": p.partner_id,
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
		"preference_hierarchy": p.preference_hierarchy,
		"opinion_memories": p.opinion_memories.duplicate(true)
	}

static func get_household_summary(ws: WorldState, household_id: int) -> Dictionary:
	if not ws or not ws.entity_registry:
		return {}
	var registry: EntityRegistry = ws.entity_registry
	var h: Household = registry.get_entity(household_id) as Household
	if not h:
		return {}
		
	var members_info: Array[Dictionary] = []
	for mid in h.member_ids:
		var p: Person = registry.get_entity(mid) as Person
		if p:
			members_info.append({
				"id": p.id,
				"name": p.get_full_name(),
				"is_alive": p.is_alive,
				"life_stage": p.life_stage,
				"occupation": p.occupation_id
			})
			
	var head_name: String = "None"
	var head: Person = registry.get_entity(h.head_id) as Person if h.head_id > 0 else null
	if head:
		head_name = head.get_full_name()
		
	return {
		"id": h.id,
		"name": h.name,
		"head_id": h.head_id,
		"head_name": head_name,
		"home_room_id": h.home_room_id,
		"member_count": h.member_ids.size(),
		"members": members_info
	}

static func get_room_summary(ws: WorldState, room_id: int) -> Dictionary:
	if not ws or not ws.entity_registry:
		return {}
	var registry: EntityRegistry = ws.entity_registry
	var r: Room = registry.get_entity(room_id) as Room
	if not r:
		return {}
		
	var type_name: String = "UNKNOWN"
	match r.room_type:
		Room.TYPE_RESIDENTIAL_APARTMENT: type_name = "RESIDENTIAL_APARTMENT"
		Room.TYPE_DORMITORY: type_name = "DORMITORY"
		Room.TYPE_CANTEEN: type_name = "CANTEEN"
		Room.TYPE_KITCHEN: type_name = "KITCHEN"
		Room.TYPE_HYGIENE_FACILITY: type_name = "HYGIENE_FACILITY"
		Room.TYPE_MACHINE_SHOP: type_name = "MACHINE_SHOP"
		Room.TYPE_FOUNDRY: type_name = "FOUNDRY"
		Room.TYPE_DEEP_MINE: type_name = "DEEP_MINE"
		Room.TYPE_WATER_PUMP_STATION: type_name = "WATER_PUMP_STATION"
		Room.TYPE_SERVER_ROOM: type_name = "SERVER_ROOM"
		Room.TYPE_CLINIC: type_name = "CLINIC"
		Room.TYPE_SCHOOL: type_name = "SCHOOL"
		
	var occupants: Array[Dictionary] = []
	var pids: Array[int] = registry.get_entities_by_type("person")
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.current_activity != Person.ACTIVITY_TRAVELING and p.current_location_id == room_id:
			occupants.append({
				"id": p.id,
				"name": p.get_full_name(),
				"activity": p.current_activity
			})
			
	var inv_stocks: Dictionary = {}
	if r.inventory_id > 0:
		var inv: Inventory = registry.get_entity(r.inventory_id) as Inventory
		if inv:
			inv_stocks = inv.stocks.duplicate()
			
	return {
		"id": r.id,
		"sector_id": r.sector_id,
		"level": r.level,
		"room_type": r.room_type,
		"room_type_name": type_name,
		"capacity_people": r.capacity_people,
		"bed_count": r.bed_count,
		"occupied_beds": r.occupied_beds.duplicate(),
		"occupant_count": occupants.size(),
		"occupants": occupants,
		"inventory_id": r.inventory_id,
		"inventory_stocks": inv_stocks
	}

static func get_economy_summary(ws: WorldState) -> Dictionary:
	var seam_ore: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0)) if ws else 0.0
	var installed_mass: float = float(ws.custom_data.get("maintenance_installed_mass_kg", 0.0)) if ws else 0.0
	
	var totals: Dictionary = {
		ResourceRegistry.RES_IRON_ORE: 0.0,
		ResourceRegistry.RES_PROCESSED_ORE: 0.0,
		ResourceRegistry.RES_METAL_STOCK: 0.0,
		ResourceRegistry.RES_MACHINED_BEARING: 0.0,
		ResourceRegistry.RES_SLAG_TAILINGS: 0.0,
		ResourceRegistry.RES_METAL_SWARF: 0.0
	}
	
	var facility_stocks: Dictionary = {
		"mines": {},
		"foundries": {},
		"machine_shops": {},
		"pump_stations": {}
	}
	
	var inventory_mass: float = 0.0
	if ws and ws.entity_registry:
		var registry: EntityRegistry = ws.entity_registry
		var inv_ids: Array[int] = registry.get_entities_by_type("inventory")
		for iid in inv_ids:
			var inv: Inventory = registry.get_entity(iid) as Inventory
			if inv:
				inventory_mass += inv.get_total_mass_kg()
				for res in totals.keys():
					totals[res] += inv.get_quantity(res)
					
	var total_mass: float = seam_ore + inventory_mass + installed_mass
	var mass_error: float = absf(total_mass - ProductionSystem.INITIAL_SEAM_ORE_KG)
	
	return {
		"seam_ore_kg": seam_ore,
		"installed_maintenance_mass_kg": installed_mass,
		"inventory_mass_kg": inventory_mass,
		"total_system_mass_kg": total_mass,
		"mass_balance_error_kg": mass_error,
		"resource_totals": totals
	}

static func get_machinery_summary(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"total_machines": 0,
		"states": {
			"NOMINAL": 0,
			"DEGRADED": 0,
			"FAULT": 0,
			"BROKEN": 0
		},
		"machines_list": []
	}
	
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	result["total_machines"] = machine_ids.size()
	
	for mid in machine_ids:
		var m: Machine = registry.get_entity(mid) as Machine
		if not m:
			continue
			
		var state_str: String = "NOMINAL"
		match m.state:
			Machine.STATE_NOMINAL:
				state_str = "NOMINAL"
				result["states"]["NOMINAL"] += 1
			Machine.STATE_DEGRADED:
				state_str = "DEGRADED"
				result["states"]["DEGRADED"] += 1
			Machine.STATE_FAULT:
				state_str = "FAULT"
				result["states"]["FAULT"] += 1
			Machine.STATE_BROKEN:
				state_str = "BROKEN"
				result["states"]["BROKEN"] += 1
				
		var comps: Dictionary = {}
		for cid in m.components:
			var comp: MachineComponent = m.components[cid] as MachineComponent
			if comp:
				comps[cid] = {
					"wear_percent": comp.wear_percent,
					"is_broken": comp.is_broken(),
					"repair_ticks_progress": comp.accumulated_repair_ticks,
					"repair_ticks_required": comp.repair_ticks_required
				}
				
		var throughput: float = 0.0
		if m is WaterPump:
			throughput = (m as WaterPump).current_water_throughput_lpm
			
		result["machines_list"].append({
			"id": m.id,
			"type": m.machine_type,
			"room_id": m.room_id,
			"state": state_str,
			"operating_hours": m.total_operating_hours,
			"active_repair": m.active_repair_component_id,
			"throughput_lpm": throughput,
			"components": comps
		})
		
	return result

static func get_utilities_summary(ws: WorldState) -> Dictionary:
	var res_cap: float = float(ws.custom_data.get("water_reservoir_capacity_liters", 100000.0)) if ws else 100000.0
	var res_cur: float = float(ws.custom_data.get("water_reservoir_liters", 50000.0)) if ws else 50000.0
	var total_pumped: float = float(ws.custom_data.get("total_water_pumped_liters", 0.0)) if ws else 0.0
	var total_consumed: float = float(ws.custom_data.get("total_water_consumed_liters", 0.0)) if ws else 0.0
	
	var fill_pct: float = (res_cur / res_cap) * 100.0 if res_cap > 0.0 else 0.0
	
	return {
		"reservoir_capacity_liters": res_cap,
		"reservoir_current_liters": res_cur,
		"fill_percent": fill_pct,
		"total_pumped_liters": total_pumped,
		"total_consumed_liters": total_consumed,
		"net_volume_change_liters": total_pumped - total_consumed
	}

static func get_institutions_summary(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"social_tension_index": 0.0,
		"active_policies": {},
		"active_orders": [],
		"total_policies_enacted": 0,
		"total_orders_dispatched": 0
	}
	
	if not ws:
		return result
		
	var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
	if inst_sys:
		result["social_tension_index"] = inst_sys.social_tension_index
		result["total_policies_enacted"] = inst_sys.total_policies_enacted
		result["total_orders_dispatched"] = inst_sys.total_orders_dispatched
		
		for cat in inst_sys.active_policies:
			var pol: Policy = inst_sys.active_policies[cat] as Policy
			if pol and pol.is_active:
				result["active_policies"][cat] = {
					"id": pol.id,
					"name": pol.name,
					"department": pol.department_id,
					"parameters": pol.parameters.duplicate(true)
				}
				
		for oid in inst_sys.active_orders:
			var ord: ExecutiveOrder = inst_sys.active_orders[oid] as ExecutiveOrder
			if ord and ord.is_active:
				result["active_orders"].append({
					"id": ord.id,
					"name": ord.name,
					"department": ord.department_id,
					"target": ord.target_id,
					"duration_ticks": ord.duration_ticks,
					"ticks_elapsed": ord.ticks_elapsed,
					"consequences": ord.consequences.duplicate(true)
				})
	else:
		result["social_tension_index"] = float(ws.custom_data.get("social_tension_index", 0.0))
		
	return result

static func get_incidents_summary(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"active_count": 0,
		"critical_count": 0,
		"resolved_count": 0,
		"active_incidents": []
	}
	
	if not ws:
		return result
		
	var inc_sys: IncidentSystem = ws.custom_data.get("incident_system", null) as IncidentSystem
	if inc_sys:
		result["active_count"] = inc_sys.get_active_incident_count()
		result["critical_count"] = inc_sys.get_critical_incident_count()
		result["resolved_count"] = inc_sys.resolved_incidents.size()
		
		var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
		for inc in inc_sys.get_active_incidents():
			result["active_incidents"].append({
				"id": inc.id,
				"type": inc.incident_type,
				"severity": inc.severity,
				"severity_name": inc.get_severity_name(),
				"title": inc.title,
				"description": inc.description,
				"onset_tick": inc.onset_tick,
				"duration_ticks": inc.get_duration_ticks(cur_tick),
				"root_cause_id": inc.root_cause_entity_id,
				"telemetry": inc.telemetry_data.duplicate(true)
			})
	else:
		result["active_count"] = int(ws.custom_data.get("active_incidents_count", 0))
		result["critical_count"] = int(ws.custom_data.get("critical_incidents_count", 0))
		
	return result

static func get_full_telemetry_snapshot(ws: WorldState) -> Dictionary:
	return {
		"clock": get_clock_summary(ws),
		"population": get_population_summary(ws),
		"economy": get_economy_summary(ws),
		"machinery": get_machinery_summary(ws),
		"utilities": get_utilities_summary(ws),
		"institutions": get_institutions_summary(ws),
		"incidents": get_incidents_summary(ws),
		"politics": get_political_summary(ws),
		"corruption": get_corruption_summary(ws)
	}

static func get_people_list(
	ws: WorldState,
	page: int = 1,
	limit: int = 50,
	search: String = "",
	filter_stage: String = "",
	filter_job: String = "",
	filter_status: String = ""
) -> Dictionary:
	var result: Dictionary = {
		"total_count": 0,
		"page": page,
		"limit": limit,
		"people": []
	}
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	var search_lower: String = search.strip_edges().to_lower()
	var stage_filter_lower: String = filter_stage.strip_edges().to_lower()
	var job_filter_lower: String = filter_job.strip_edges().to_lower()
	var status_filter_lower: String = filter_status.strip_edges().to_lower()
	
	var filtered: Array[Dictionary] = []
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p:
			continue
			
		var full_name: String = p.get_full_name()
		var stage_str: String = "ADULT"
		match p.life_stage:
			Person.STAGE_INFANT: stage_str = "INFANT"
			Person.STAGE_CHILD: stage_str = "CHILD"
			Person.STAGE_STUDENT: stage_str = "STUDENT"
			Person.STAGE_ADULT: stage_str = "ADULT"
			Person.STAGE_ELDER: stage_str = "ELDER"
			
		# Filter by Search
		if search_lower != "":
			var matches_id: bool = str(p.id) == search_lower
			var matches_name: bool = full_name.to_lower().contains(search_lower)
			if not matches_id and not matches_name:
				continue
				
		# Filter by Stage
		if stage_filter_lower != "" and stage_filter_lower != "all":
			if stage_str.to_lower() != stage_filter_lower:
				continue
				
		# Filter by Job
		if job_filter_lower != "" and job_filter_lower != "all":
			if p.occupation_id.to_lower() != job_filter_lower and p.department_id.to_lower() != job_filter_lower:
				continue
				
		# Filter by Status
		if status_filter_lower != "" and status_filter_lower != "all":
			if status_filter_lower == "living" and not p.is_alive:
				continue
			elif status_filter_lower == "deceased" and p.is_alive:
				continue
			elif status_filter_lower == "dehydrated" and not p.is_severely_dehydrated():
				continue
				
		var act_str: String = "IDLE"
		match p.current_activity:
			Person.ACTIVITY_SLEEPING: act_str = "SLEEPING"
			Person.ACTIVITY_TRAVELING: act_str = "TRAVELING"
			Person.ACTIVITY_WORKING: act_str = "WORKING"
			Person.ACTIVITY_STUDYING: act_str = "STUDYING"
			Person.ACTIVITY_EATING: act_str = "EATING"
			Person.ACTIVITY_HYGIENE: act_str = "HYGIENE"
			Person.ACTIVITY_RECREATING: act_str = "RECREATING"
			Person.ACTIVITY_IDLE: act_str = "IDLE"
			
		filtered.append({
			"id": p.id,
			"first_name": p.first_name,
			"last_name": p.last_name,
			"full_name": full_name,
			"sex": "Female" if p.sex == Person.SEX_FEMALE else "Male",
			"age_years": p.get_age_years(cur_tick),
			"life_stage": stage_str,
			"is_alive": p.is_alive,
			"occupation_id": p.occupation_id,
			"department_id": p.department_id,
			"activity": act_str,
			"hydration_percent": p.hydration_percent,
			"health_percent": p.health_percent,
			"security_clearance": p.security_clearance,
			"home_room_id": p.home_room_id,
			"current_location_id": p.current_location_id,
			"household_id": p.household_id
		})
		
	result["total_count"] = filtered.size()
	
	var page_idx: int = maxi(1, page)
	var limit_val: int = clamp(limit, 1, 500)
	var offset_val: int = (page_idx - 1) * limit_val
	
	var page_slice: Array[Dictionary] = []
	for i in range(offset_val, mini(filtered.size(), offset_val + limit_val)):
		page_slice.append(filtered[i])
		
	result["people"] = page_slice
	return result

static func get_households_list(ws: WorldState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ws or not ws.entity_registry:
		return result
	var registry: EntityRegistry = ws.entity_registry
	var hids: Array[int] = registry.get_entities_by_type("household")
	for hid in hids:
		var h_sum: Dictionary = get_household_summary(ws, hid)
		if not h_sum.is_empty():
			result.append(h_sum)
	return result

static func get_locations_hierarchy(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"total_rooms": 0,
		"sectors": {}
	}
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var room_ids: Array[int] = registry.get_entities_by_type("room")
	result["total_rooms"] = room_ids.size()
	
	for rid in room_ids:
		var r_sum: Dictionary = get_room_summary(ws, rid)
		if r_sum.is_empty():
			continue
			
		var sec_key: String = "Sector %d" % r_sum["sector_id"]
		var lvl_key: String = "Level %d" % r_sum["level"]
		
		if not result["sectors"].has(sec_key):
			result["sectors"][sec_key] = {}
		if not result["sectors"][sec_key].has(lvl_key):
			result["sectors"][sec_key][lvl_key] = []
			
		result["sectors"][sec_key][lvl_key].append(r_sum)
		
	return result

static func get_labour_summary(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"total_employed": 0,
		"departments": {},
		"occupations": {},
		"students_count": 0,
		"students": []
	}
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		if p.life_stage == Person.STAGE_STUDENT or p.occupation_id == "student":
			result["students_count"] += 1
			result["students"].append({
				"id": p.id,
				"name": p.get_full_name(),
				"age_years": p.get_age_years(cur_tick),
				"education_score": p.education_score,
				"school_room_id": p.school_room_id
			})
			
		if p.occupation_id != "unassigned" and p.occupation_id != "none" and p.occupation_id != "student":
			result["total_employed"] += 1
			var dept: String = p.department_id if p.department_id != "" else "unassigned"
			var occ: String = p.occupation_id
			
			if not result["departments"].has(dept):
				result["departments"][dept] = {"worker_count": 0, "workers": []}
			result["departments"][dept]["worker_count"] += 1
			result["departments"][dept]["workers"].append({
				"id": p.id,
				"name": p.get_full_name(),
				"occupation": occ,
				"shift": p.shift_id,
				"workplace_id": p.workplace_room_id,
				"clearance": p.security_clearance
			})
			
			result["occupations"][occ] = int(result["occupations"].get(occ, 0)) + 1
			
	return result

static func get_causal_chain(ws: WorldState, machine_id: int = 0) -> Dictionary:
	var chain: Dictionary = {
		"machine": {},
		"component": {},
		"required_part": {},
		"inventory_stock": {},
		"manufacturing_machine_shop": {},
		"smelting_foundry": {},
		"mining_crushing": {},
		"geological_seam": {},
		"utility_consequence": {}
	}
	if not ws or not ws.entity_registry:
		return chain
		
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	if machine_ids.is_empty():
		return chain
		
	var target_mid: int = machine_id if machine_id > 0 else machine_ids[0]
	var m: Machine = registry.get_entity(target_mid) as Machine
	if not m:
		m = registry.get_entity(machine_ids[0]) as Machine
		target_mid = m.id
		
	# 1. Machine Details
	chain["machine"] = {
		"id": m.id,
		"type": m.machine_type,
		"state": m.state,
		"state_name": "NOMINAL" if m.state == 1 else ("DEGRADED" if m.state == 2 else ("FAULT" if m.state == 3 else "BROKEN")),
		"operating_hours": m.total_operating_hours,
		"room_id": m.room_id
	}
	
	# 2. Worst component
	var worst_comp: MachineComponent = null
	var max_wear: float = -1.0
	for cid in m.components:
		var comp: MachineComponent = m.components[cid] as MachineComponent
		if comp and comp.wear_percent > max_wear:
			max_wear = comp.wear_percent
			worst_comp = comp
			
	if worst_comp:
		chain["component"] = {
			"id": worst_comp.id,
			"name": worst_comp.name,
			"wear_percent": worst_comp.wear_percent,
			"wear_rate_per_hour": worst_comp.wear_rate_per_hour,
			"criticality": worst_comp.criticality,
			"required_spare_resource_id": worst_comp.required_spare_resource_id,
			"required_spare_quantity": worst_comp.required_spare_quantity
		}
		
	# 3. Inventory Stock of required spare
	var spare_res: String = worst_comp.required_spare_resource_id if worst_comp else ResourceRegistry.RES_MACHINED_BEARING
	var total_spare_stock: float = 0.0
	var room_inv_stock: float = 0.0
	
	var room: Room = registry.get_entity(m.room_id) as Room
	if room and room.inventory_id > 0:
		var r_inv: Inventory = registry.get_entity(room.inventory_id) as Inventory
		if r_inv:
			room_inv_stock = r_inv.get_quantity(spare_res)
			
	var all_inv_ids: Array[int] = registry.get_entities_by_type("inventory")
	for iid in all_inv_ids:
		var inv: Inventory = registry.get_entity(iid) as Inventory
		if inv:
			total_spare_stock += inv.get_quantity(spare_res)
			
	chain["required_part"] = {
		"resource_id": spare_res,
		"required_quantity": worst_comp.required_spare_quantity if worst_comp else 1.0,
		"room_inventory_quantity": room_inv_stock,
		"habitat_total_stock": total_spare_stock,
		"is_stockout": total_spare_stock < (worst_comp.required_spare_quantity if worst_comp else 1.0)
	}
	
	# 4. Manufacturing Machine Shop
	var econ_sum: Dictionary = get_economy_summary(ws)
	chain["manufacturing_machine_shop"] = {
		"process": "Machining Lathes (metal_stock -> machined_bearing + swarf)",
		"input_resource": ResourceRegistry.RES_METAL_STOCK,
		"input_stock": econ_sum["resource_totals"].get(ResourceRegistry.RES_METAL_STOCK, 0.0),
		"output_stock": econ_sum["resource_totals"].get(ResourceRegistry.RES_MACHINED_BEARING, 0.0),
		"swarf_waste": econ_sum["resource_totals"].get(ResourceRegistry.RES_METAL_SWARF, 0.0)
	}
	
	# 5. Smelting Foundry
	chain["smelting_foundry"] = {
		"process": "Electric Induction Smelting (processed_ore -> metal_stock + slag)",
		"input_resource": ResourceRegistry.RES_PROCESSED_ORE,
		"input_stock": econ_sum["resource_totals"].get(ResourceRegistry.RES_PROCESSED_ORE, 0.0),
		"output_stock": econ_sum["resource_totals"].get(ResourceRegistry.RES_METAL_STOCK, 0.0),
		"slag_tailings": econ_sum["resource_totals"].get(ResourceRegistry.RES_SLAG_TAILINGS, 0.0)
	}
	
	# 6. Deep Mine / Ore Crushing
	chain["mining_crushing"] = {
		"process": "Seam Extraction & Beneficiation (iron_ore -> processed_ore)",
		"iron_ore_stock": econ_sum["resource_totals"].get(ResourceRegistry.RES_IRON_ORE, 0.0),
		"processed_ore_stock": econ_sum["resource_totals"].get(ResourceRegistry.RES_PROCESSED_ORE, 0.0)
	}
	
	# 7. Geological Seam
	chain["geological_seam"] = {
		"initial_reserve_kg": ProductionSystem.INITIAL_SEAM_ORE_KG,
		"remaining_reserve_kg": econ_sum["seam_ore_kg"],
		"total_system_mass_kg": econ_sum["total_system_mass_kg"],
		"mass_conservation_error_kg": econ_sum["mass_balance_error_kg"]
	}
	
	# 8. Downstream Utility Impact
	var util_sum: Dictionary = get_utilities_summary(ws)
	var pop_sum: Dictionary = get_population_summary(ws)
	chain["utility_consequence"] = {
		"pump_throughput_lpm": (m as WaterPump).current_water_throughput_lpm if m is WaterPump else 0.0,
		"reservoir_current_liters": util_sum["reservoir_current_liters"],
		"reservoir_fill_percent": util_sum["fill_percent"],
		"avg_hydration_percent": pop_sum["avg_hydration"],
		"dehydrated_residents_count": pop_sum["dehydrated_count"]
	}
	
	return chain

static func get_wiring_matrix(_ws: WorldState) -> Array[Dictionary]:
	return [
		{"system": "SimClock", "source": "src/sim/core/sim_clock.gd", "order": "Core Time (10m/tick)", "endpoint": "/api/overview", "status": "GREEN"},
		{"system": "SeededRandom", "source": "src/sim/core/seeded_random.gd", "order": "PRNG Core (Deterministic)", "endpoint": "/api/overview", "status": "GREEN"},
		{"system": "EntityRegistry", "source": "src/sim/core/entity_registry.gd", "order": "Monotonic Entity Store", "endpoint": "/api/raw", "status": "GREEN"},
		{"system": "EventQueue", "source": "src/sim/core/event_queue.gd", "order": "Scheduled Events Engine", "endpoint": "/api/timeline", "status": "GREEN"},
		{"system": "Scheduler", "source": "src/sim/core/scheduler.gd", "order": "Pipeline Dispatcher", "endpoint": "/api/wiring", "status": "GREEN"},
		{"system": "StateChecksum", "source": "src/sim/core/checksum.gd", "order": "64-bit FNV-1a Checksum", "endpoint": "/api/invariants", "status": "GREEN"},
		{"system": "WorldState", "source": "src/sim/core/world_state.gd", "order": "Authoritative World State", "endpoint": "/api/overview", "status": "GREEN"},
		{"system": "SimulationEngine", "source": "src/sim/core/simulation_engine.gd", "order": "Engine Controller", "endpoint": "/api/step", "status": "GREEN"},
		{"system": "PopulationGenerator", "source": "src/sim/population/population_generator.gd", "order": "Population Synthesis", "endpoint": "/api/people", "status": "GREEN"},
		{"system": "DailyLifeSystem", "source": "src/sim/population/daily_life_system.gd", "order": "Order 50 (Routines & Spatial Transit)", "endpoint": "/api/locations", "status": "GREEN"},
		{"system": "OccupationAssignment", "source": "src/sim/population/occupation_assignment.gd", "order": "Workplace Setup & Assignment", "endpoint": "/api/labour", "status": "GREEN"},
		{"system": "DemographicsSystem", "source": "src/sim/population/demographics_system.gd", "order": "Order 40 (Lifespans, Marriages, Births)", "endpoint": "/api/people", "status": "GREEN"},
		{"system": "ProductionSystem", "source": "src/sim/economy/production_system.gd", "order": "Order 60 (4-Stage Material Pipeline)", "endpoint": "/api/economy", "status": "GREEN"},
		{"system": "ResourceRegistry", "source": "src/sim/economy/resource_registry.gd", "order": "Material Resource Defs", "endpoint": "/api/economy", "status": "GREEN"},
		{"system": "MaintenanceSystem", "source": "src/sim/machinery/maintenance_system.gd", "order": "Order 55 (Wear Curves & Servicing)", "endpoint": "/api/machinery", "status": "GREEN"},
		{"system": "WaterSystem", "source": "src/sim/utilities/water_system.gd", "order": "Order 65 (Aquifer, Storage & Hydration)", "endpoint": "/api/utilities", "status": "GREEN"},
		{"system": "InstitutionSystem", "source": "src/sim/institutions/institution_system.gd", "order": "Order 30 (Policies, Orders & Tension)", "endpoint": "/api/institutions", "status": "GREEN"},
		{"system": "PoliticalSystem", "source": "src/sim/politics/political_system.gd", "order": "Order 35 (Political Identity & Legitimacy)", "endpoint": "/api/politics", "status": "GREEN"},
		{"system": "FactionSystem", "source": "src/sim/politics/faction_system.gd", "order": "Order 36 (Emergent Factions & Blocs)", "endpoint": "/api/factions", "status": "GREEN"},
		{"system": "SocialGraph", "source": "src/sim/politics/social_graph.gd", "order": "Bounded Social Ties & Influence", "endpoint": "/api/social_network", "status": "GREEN"},
		{"system": "CorruptionSystem", "source": "src/sim/politics/corruption_system.gd", "order": "Order 37 (Informal Power & Discrepancies)", "endpoint": "/api/corruption", "status": "GREEN"},
		{"system": "PatronageNetwork", "source": "src/sim/politics/patronage_network.gd", "order": "Informal Power & Patron-Client Graph", "endpoint": "/api/patronage_network", "status": "GREEN"},
		{"system": "IncidentDetector", "source": "src/sim/incidents/incident_detector.gd", "order": "Diagnostic Telemetry Engine", "endpoint": "/api/incidents", "status": "GREEN"},
		{"system": "IncidentSystem", "source": "src/sim/incidents/incident_system.gd", "order": "Order 80 (Emergent Crises Lifecycle)", "endpoint": "/api/incidents", "status": "GREEN"},
		{"system": "SimulationReader", "source": "src/presentation/simulation_reader.gd", "order": "Pure Read Projection Layer", "endpoint": "All /api/*", "status": "GREEN"},
		{"system": "SimulationViewer", "source": "src/presentation/simulation_viewer.gd", "order": "ASCII & Visual Formatter", "endpoint": "/api/overview", "status": "GREEN"},
		{"system": "CommandAdapter", "source": "src/presentation/command_adapter.gd", "order": "Decoupled Action Dispatcher", "endpoint": "/api/policy/*, /api/order/*", "status": "GREEN"}
	]

static func get_performance_metrics(ws: WorldState, last_benchmark: Dictionary = {}) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry if ws else null
	return {
		"current_tick": ws.sim_clock.get_tick() if ws and ws.sim_clock else 0,
		"entity_counts": {
			"person": registry.get_entities_by_type("person").size() if registry else 0,
			"household": registry.get_entities_by_type("household").size() if registry else 0,
			"room": registry.get_entities_by_type("room").size() if registry else 0,
			"inventory": registry.get_entities_by_type("inventory").size() if registry else 0,
			"machine": registry.get_entities_by_type("machine").size() if registry else 0
		},
		"event_queue_size": ws.event_queue.get_event_count() if ws and ws.event_queue else 0,
		"checksum": ws.get_state_checksum() if ws else 0,
		"benchmark": last_benchmark.duplicate(true)
	}

static func get_raw_entity_state(ws: WorldState, entity_type: String, entity_id: int) -> Dictionary:
	if not ws or not ws.entity_registry:
		return {}
	var registry: EntityRegistry = ws.entity_registry
	if entity_type == "world":
		return ws.serialize()
	if not registry.has_entity(entity_id):
		return {"error": "Entity ID %d not found" % entity_id}
	var ent: Variant = registry.get_entity(entity_id)
	if ent is Object and ent.has_method("serialize"):
		return ent.serialize()
	return {"id": entity_id, "type": registry.get_entity_type(entity_id), "data": str(ent)}

static func get_timeline_events(ws: WorldState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not ws:
		return events
		
	# 1. Extract events from incident system
	var inc_sys: IncidentSystem = ws.custom_data.get("incident_system", null) as IncidentSystem
	if inc_sys:
		for inc in inc_sys.get_active_incidents():
			events.append({
				"tick": inc.onset_tick,
				"category": "INCIDENT_ONSET",
				"severity": inc.get_severity_name(),
				"title": inc.title,
				"description": inc.description,
				"entity_id": inc.root_cause_entity_id
			})
		for inc in inc_sys.resolved_incidents:
			events.append({
				"tick": inc.resolved_tick,
				"category": "INCIDENT_RESOLVED",
				"severity": inc.get_severity_name(),
				"title": "Resolved: " + inc.title,
				"description": "Incident cleared after normalizing underlying physical conditions.",
				"entity_id": inc.root_cause_entity_id
			})
			
	# 2. Extract active orders from institutions
	var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
	if inst_sys:
		for oid in inst_sys.active_orders:
			var ord: ExecutiveOrder = inst_sys.active_orders[oid]
			events.append({
				"tick": ord.enacted_tick,
				"category": "EXECUTIVE_ORDER",
				"severity": "WARNING",
				"title": "Order Enacted: " + ord.name,
				"description": "Department: %s, Target: %s, Duration: %d ticks" % [ord.department_id, ord.target_id, ord.duration_ticks],
				"entity_id": 0
			})
			
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tick", 0)) > int(b.get("tick", 0)))
	return events

static func get_political_summary(ws: WorldState) -> Dictionary:
	var pol_sys: PoliticalSystem = ws.custom_data.get("political_system", null) as PoliticalSystem if ws else null
	return {
		"overall_legitimacy": LegitimacyModel.calculate_overall_legitimacy(ws),
		"departmental_trust": LegitimacyModel.calculate_departmental_trust(ws),
		"class_resentment_index": LegitimacyModel.calculate_class_resentment_index(ws),
		"spectrum": LegitimacyModel.calculate_political_spectrum(ws),
		"total_memories_created": pol_sys.total_memories_created if pol_sys else 0
	}

static func get_person_political_profile(ws: WorldState, person_id: int) -> Dictionary:
	if not ws or not ws.entity_registry:
		return {}
	var p: Person = ws.entity_registry.get_entity(person_id) as Person
	if not p:
		return {}
		
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	
	var mems_formatted: Array[Dictionary] = []
	for mem in p.opinion_memories:
		var age: int = maxi(0, cur_tick - int(mem.get("onset_tick", 0)))
		var halflifes: float = float(age) / float(OpinionMemory.HALF_LIFE_TICKS)
		var salience: float = pow(0.5, halflifes)
		mems_formatted.append({
			"event_type": mem.get("event_type", ""),
			"onset_tick": mem.get("onset_tick", 0),
			"attribution_dept": mem.get("attribution_dept", ""),
			"emotional_impact": mem.get("emotional_impact", 0.0),
			"salience": salience,
			"description": mem.get("description", ""),
			"source_entity_id": mem.get("source_entity_id", 0)
		})
		
	return {
		"id": p.id,
		"name": p.get_full_name(),
		"is_alive": p.is_alive,
		"life_stage": p.life_stage,
		"occupation_id": p.occupation_id,
		"department_id": p.department_id,
		"clearance": p.security_clearance,
		"attitudes": {
			"institutional_trust": p.institutional_trust,
			"perceived_fairness": p.perceived_fairness,
			"perceived_security": p.perceived_security,
			"economic_satisfaction": p.economic_satisfaction,
			"class_resentment": p.class_resentment
		},
		"department_confidence": {
			"leadership": p.confidence_leadership,
			"it": p.confidence_it,
			"security": p.confidence_security,
			"engineering": p.confidence_engineering
		},
		"political_values": {
			"preference_stability": p.preference_stability,
			"preference_reform": p.preference_reform,
			"preference_autonomy": p.preference_autonomy,
			"preference_equality": p.preference_equality,
			"preference_hierarchy": p.preference_hierarchy,
			"tolerance_coercion": p.tolerance_coercion
		},
		"faction_id": p.faction_id,
		"sympathiser_faction_id": p.sympathiser_faction_id,
		"opinion_memories": mems_formatted
	}

static func get_factions_summary(ws: WorldState) -> Dictionary:
	var factions_list: Array[Dictionary] = []
	if not ws or not ws.entity_registry:
		return {"factions": factions_list, "total_count": 0, "active_count": 0}
		
	var registry: EntityRegistry = ws.entity_registry
	var fids: Array[int] = registry.get_entities_by_type("faction")
	var active_cnt: int = 0
	
	for fid in fids:
		var f: Faction = registry.get_entity(fid) as Faction
		if not f:
			continue
		if f.is_active:
			active_cnt += 1
		var leader: Person = registry.get_entity(f.leader_id) as Person if f.leader_id > 0 else null
		var leader_name: String = leader.get_full_name() if leader else "Unassigned"
		
		factions_list.append({
			"id": f.id,
			"name": f.name,
			"manifesto": f.manifesto,
			"leader_id": f.leader_id,
			"leader_name": leader_name,
			"member_count": f.member_ids.size(),
			"sympathiser_count": f.sympathiser_ids.size(),
			"cohesion": f.cohesion,
			"resources": f.resources,
			"is_active": f.is_active,
			"creation_tick": f.creation_tick,
			"grievance_count": f.grievance_agenda.size(),
			"institutional_penetration": f.institutional_penetration
		})
		
	var fact_sys: FactionSystem = ws.custom_data.get("faction_system", null) as FactionSystem
	return {
		"factions": factions_list,
		"total_count": fids.size(),
		"active_count": active_cnt,
		"total_factions_spawned": fact_sys.total_factions_spawned if fact_sys else fids.size(),
		"total_recruitment_events": fact_sys.total_recruitment_events if fact_sys else 0
	}

static func get_faction_detail(ws: WorldState, faction_id: int) -> Dictionary:
	if not ws or not ws.entity_registry:
		return {}
	var registry: EntityRegistry = ws.entity_registry
	var f: Faction = registry.get_entity(faction_id) as Faction
	if not f:
		return {}
		
	var leader: Person = registry.get_entity(f.leader_id) as Person if f.leader_id > 0 else null
	var members_summary: Array[Dictionary] = []
	for mid in f.member_ids:
		var mp: Person = registry.get_entity(mid) as Person
		if mp:
			members_summary.append({
				"id": mp.id,
				"name": mp.get_full_name(),
				"occupation": mp.occupation_id,
				"department": mp.department_id,
				"seniority": mp.seniority_level,
				"trust": mp.institutional_trust
			})
			
	var relation_names: Dictionary = {}
	for other_id in f.inter_faction_relations.keys():
		var of: Faction = registry.get_entity(int(other_id)) as Faction
		if of:
			relation_names[of.name] = f.inter_faction_relations[other_id]
			
	return {
		"id": f.id,
		"name": f.name,
		"manifesto": f.manifesto,
		"ideology_profile": f.ideology_profile,
		"leader_id": f.leader_id,
		"leader_name": leader.get_full_name() if leader else "Unassigned",
		"leader_occupation": leader.occupation_id if leader else "N/A",
		"leader_department": leader.department_id if leader else "N/A",
		"member_count": f.member_ids.size(),
		"sympathiser_count": f.sympathiser_ids.size(),
		"cohesion": f.cohesion,
		"resources": f.resources,
		"is_active": f.is_active,
		"creation_tick": f.creation_tick,
		"grievance_agenda": f.grievance_agenda,
		"policy_approval_matrix": f.policy_approval_matrix,
		"inter_faction_relations": f.inter_faction_relations,
		"inter_faction_relations_by_name": relation_names,
		"institutional_penetration": f.institutional_penetration,
		"members": members_summary
	}

static func get_person_social_network(ws: WorldState, person_id: int) -> Dictionary:
	if not ws or not ws.entity_registry:
		return {}
	var registry: EntityRegistry = ws.entity_registry
	var p: Person = registry.get_entity(person_id) as Person
	if not p:
		return {}
		
	var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, person_id)
	return {
		"person_id": p.id,
		"person_name": p.get_full_name(),
		"occupation": p.occupation_id,
		"department": p.department_id,
		"faction_id": p.faction_id,
		"sympathiser_faction_id": p.sympathiser_faction_id,
		"connections": connections,
		"total_connections": connections.size()
	}

static func get_corruption_summary(ws: WorldState) -> Dictionary:
	var favours: Array = ws.custom_data.get("favours", []) if ws else []
	var actions: Array = ws.custom_data.get("illicit_actions", []) if ws else []
	
	var active_debts: int = 0
	var total_debt_val: float = 0.0
	for f in favours:
		if f is Favour and not f.is_settled:
			active_debts += 1
			total_debt_val += f.obligation_value
			
	var concealed_count: int = 0
	var exposed_count: int = 0
	var sanctioned_count: int = 0
	var total_diverted_mass: float = 0.0
	var total_discrepancy: float = 0.0
	
	for a in actions:
		if a is IllicitAction:
			match a.discovery_status:
				IllicitAction.STATUS_CONCEALED:
					concealed_count += 1
					total_discrepancy += a.discrepancy_amount
				IllicitAction.STATUS_EXPOSED:
					exposed_count += 1
				IllicitAction.STATUS_SANCTIONED:
					sanctioned_count += 1
			total_diverted_mass += a.target_amount
			
	var patron_clusters: Array[Dictionary] = PatronageNetwork.get_patron_client_clusters(ws) if ws else []
	
	return {
		"total_favours": favours.size(),
		"active_favours": active_debts,
		"total_debt_value": total_debt_val,
		"total_illicit_actions": actions.size(),
		"concealed_actions": concealed_count,
		"exposed_actions": exposed_count,
		"sanctioned_actions": sanctioned_count,
		"total_diverted_mass_kg": total_diverted_mass,
		"total_active_discrepancy": total_discrepancy,
		"top_patrons_count": patron_clusters.size(),
		"patron_clusters": patron_clusters
	}

static func get_patronage_network(ws: WorldState) -> Dictionary:
	var clusters: Array[Dictionary] = PatronageNetwork.get_patron_client_clusters(ws) if ws else []
	var conflicts: Array[Dictionary] = []
	if ws and ws.entity_registry:
		var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
		for pid in pids:
			var p: Person = ws.entity_registry.get_entity(pid) as Person
			if p and p.is_alive and p.security_clearance >= 1:
				var c_info: Dictionary = PatronageNetwork.get_conflict_of_interest(ws, p.id)
				if c_info.get("has_conflict", false):
					conflicts.append(c_info)
					
	return {
		"patron_clusters": clusters,
		"total_patrons": clusters.size(),
		"conflicts_of_interest": conflicts,
		"conflict_count": conflicts.size()
	}

static func get_audit_log(ws: WorldState, limit: int = 50, filter_status: String = "") -> Array[Dictionary]:
	var log_entries: Array[Dictionary] = []
	if not ws:
		return log_entries
		
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	var registry: EntityRegistry = ws.entity_registry
	
	for a_item in actions:
		var act: IllicitAction = a_item as IllicitAction
		if not act:
			continue
			
		var status_str: String = act.get_status_name().to_lower()
		if filter_status != "" and filter_status != "all" and status_str != filter_status.to_lower():
			continue
			
		var perp: Person = registry.get_entity(act.perpetrator_id) as Person if registry else null
		var ben: Person = registry.get_entity(act.beneficiary_id) as Person if registry else null
		var disc: Person = registry.get_entity(act.discoverer_id) as Person if registry and act.discoverer_id > 0 else null
		
		log_entries.append({
			"id": act.id,
			"tick": act.tick,
			"action_type": act.action_type,
			"perpetrator_id": act.perpetrator_id,
			"perpetrator_name": perp.get_full_name() if perp else "Unknown",
			"perpetrator_job": perp.occupation_id if perp else "N/A",
			"beneficiary_id": act.beneficiary_id,
			"beneficiary_name": ben.get_full_name() if ben else "Unknown",
			"target_resource": act.target_resource,
			"target_amount": act.target_amount,
			"source_room_id": act.source_room_id,
			"destination_room_id": act.destination_room_id,
			"official_recorded": act.official_record_amount,
			"physical_actual": act.physical_actual_amount,
			"discrepancy": act.discrepancy_amount,
			"concealment": act.concealment_level,
			"status": act.get_status_name(),
			"discovered_tick": act.discovered_tick,
			"discoverer_name": disc.get_full_name() if disc else ("Official Audit" if act.discovered_tick > 0 else "None"),
			"evidence": act.evidence_strength,
			"penalty": act.penalty_applied,
			"description": act.description
		})
		
	log_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tick", 0)) > int(b.get("tick", 0)))
	if log_entries.size() > limit:
		return log_entries.slice(0, limit)
	return log_entries

static func get_illicit_action_trace(ws: WorldState, action_id: int) -> Dictionary:
	var trace: Dictionary = {
		"step_1_actor": {},
		"step_2_relationship_incentive": {},
		"step_3_illicit_action": {},
		"step_4_affected_target": {},
		"step_5_hidden_record_discrepancy": {},
		"step_6_discovery_path": {},
		"step_7_institutional_consequence": {}
	}
	if not ws:
		return trace
		
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	var target_act: IllicitAction = null
	for a in actions:
		var act: IllicitAction = a as IllicitAction
		if act and act.id == action_id:
			target_act = act
			break
			
	if not target_act and not actions.is_empty():
		target_act = actions[actions.size() - 1] as IllicitAction
		
	if not target_act:
		return trace
		
	var registry: EntityRegistry = ws.entity_registry
	var perp: Person = registry.get_entity(target_act.perpetrator_id) as Person if registry else null
	var ben: Person = registry.get_entity(target_act.beneficiary_id) as Person if registry else null
	var disc: Person = registry.get_entity(target_act.discoverer_id) as Person if registry and target_act.discoverer_id > 0 else null
	
	# Step 1: Actor
	trace["step_1_actor"] = {
		"id": perp.id if perp else target_act.perpetrator_id,
		"name": perp.get_full_name() if perp else "Unknown",
		"occupation": perp.occupation_id if perp else "N/A",
		"department": perp.department_id if perp else "N/A",
		"clearance": perp.security_clearance if perp else 0,
		"seniority": perp.seniority_level if perp else 0,
		"institutional_trust": perp.institutional_trust if perp else 0.5,
		"class_resentment": perp.class_resentment if perp else 0.0
	}
	
	# Step 2: Relationship / Incentive
	var rel_type: String = "informal_contact"
	var tie_w: float = 0.5
	if perp and ben:
		var conns: Array[Dictionary] = SocialGraph.get_social_connections(ws, perp.id)
		for c in conns:
			if int(c.get("target_id", 0)) == ben.id:
				rel_type = str(c.get("relation_type", ""))
				tie_w = float(c.get("weight", 0.0))
				break
				
	trace["step_2_relationship_incentive"] = {
		"beneficiary_id": ben.id if ben else target_act.beneficiary_id,
		"beneficiary_name": ben.get_full_name() if ben else "Unknown",
		"relation_type": rel_type,
		"tie_weight": tie_w,
		"temptation_score": PatronageNetwork.calculate_corruption_temptation(ws, perp.id) if perp else 0.0,
		"favour_id": target_act.favour_id
	}
	
	# Step 3: Illicit Action
	trace["step_3_illicit_action"] = {
		"id": target_act.id,
		"tick": target_act.tick,
		"type": target_act.action_type,
		"description": target_act.description,
		"concealment_level": target_act.concealment_level
	}
	
	# Step 4: Affected Target
	trace["step_4_affected_target"] = {
		"resource_id": target_act.target_resource,
		"quantity": target_act.target_amount,
		"source_room_id": target_act.source_room_id,
		"destination_room_id": target_act.destination_room_id
	}
	
	# Step 5: Hidden Record Discrepancy
	trace["step_5_hidden_record_discrepancy"] = {
		"official_record_amount": target_act.official_record_amount,
		"physical_actual_amount": target_act.physical_actual_amount,
		"discrepancy_amount": target_act.discrepancy_amount,
		"is_concealed": target_act.discovery_status == IllicitAction.STATUS_CONCEALED
	}
	
	# Step 6: Discovery Path
	trace["step_6_discovery_path"] = {
		"status": target_act.get_status_name(),
		"discovered_tick": target_act.discovered_tick,
		"discoverer_id": target_act.discoverer_id,
		"discoverer_name": disc.get_full_name() if disc else ("Official Audit" if target_act.discovered_tick > 0 else "Undiscovered"),
		"evidence_strength": target_act.evidence_strength
	}
	
	# Step 7: Institutional Consequence
	trace["step_7_institutional_consequence"] = {
		"penalty_applied": target_act.penalty_applied,
		"is_sanctioned": target_act.discovery_status == IllicitAction.STATUS_SANCTIONED,
		"record_reconciled": target_act.discovery_status == IllicitAction.STATUS_SANCTIONED
	}
	
	return trace


