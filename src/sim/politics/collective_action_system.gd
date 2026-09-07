# src/sim/politics/collective_action_system.gd
class_name CollectiveActionSystem
extends BaseSystem

## Domain system managing strikes, walkouts, civil disobedience, protests,
## machinery sabotage, and institutional resolutions.
## Feeds into physical production and machinery without artificial modifiers.

const CollectiveAction = preload("res://src/sim/politics/collective_action.gd")
const InformationSystem = preload("res://src/sim/politics/information_system.gd")
const InformationObject = preload("res://src/sim/politics/information_object.gd")
const CitizenBelief = preload("res://src/sim/politics/citizen_belief.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")
const SocialGraph = preload("res://src/sim/politics/social_graph.gd")

const SYSTEM_ID: String = "collective_action"
const EXECUTION_ORDER: int = 39 # Runs after InformationSystem (38) and before Demographics/DailyLife (40/50)

var last_emergence_check_tick: int = -1

func _init() -> void:
	super._init(SYSTEM_ID, EXECUTION_ORDER)

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws:
		return
		
	ws.custom_data["collective_action_system"] = self
	if not ws.custom_data.has("collective_actions"):
		ws.custom_data["collective_actions"] = []
	if not ws.custom_data.has("striking_person_ids"):
		ws.custom_data["striking_person_ids"] = {}
	if not ws.custom_data.has("next_action_id"):
		ws.custom_data["next_action_id"] = 1
	if not ws.custom_data.has("sabotage_incidents"):
		ws.custom_data["sabotage_incidents"] = []

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws or not ws.sim_clock:
		return
		
	var cur_tick: int = ws.sim_clock.get_tick()
	
	# Periodic evaluation of emergent strikes and protests from boiling grievances (every 72 ticks = 12 hours)
	if cur_tick % 72 == 0 and cur_tick != last_emergence_check_tick:
		last_emergence_check_tick = cur_tick
		_evaluate_emergent_collective_actions(ws, cur_tick)

## Declares a physical strike at a specific workplace room
func organize_strike(
	ws: WorldState,
	workplace_room_id: int,
	organizer_id: int,
	demands: Array[Dictionary] = [],
	faction_id: int = 0,
	trigger_event_id: String = ""
) -> CollectiveAction:
	if not ws or not ws.entity_registry:
		return null
		
	var next_id: int = int(ws.custom_data.get("next_action_id", 1))
	ws.custom_data["next_action_id"] = next_id + 1
	
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	
	# Default gathering room is the workplace entrance or common area
	var gathering_room: int = workplace_room_id
	
	var action: CollectiveAction = CollectiveAction.new(
		next_id,
		CollectiveAction.TYPE_STRIKE,
		"workplace",
		workplace_room_id,
		gathering_room,
		faction_id,
		cur_tick
	)
	action.trigger_event_id = trigger_event_id
	
	for d in demands:
		action.add_demand(str(d.get("type", "grievance")), d.get("value", 1.0), str(d.get("description", "")))
		
	if organizer_id > 0:
		action.add_organizer(organizer_id)
		
	# Recruit workers from this workplace
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var striking_map: Dictionary = ws.custom_data.get("striking_person_ids", {})
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive or p.workplace_room_id != workplace_room_id:
			continue
			
		# Workers join if they are the organizer, or aligned with the faction,
		# or have high class resentment (> 0.4), or share belief in the trigger event
		var should_join: bool = (pid == organizer_id)
		if not should_join and faction_id > 0 and (p.faction_id == faction_id or p.sympathiser_faction_id == faction_id):
			should_join = true
		elif not should_join and p.class_resentment >= 0.35:
			should_join = true
		elif not should_join and trigger_event_id != "" and p.has_belief(trigger_event_id):
			var b: CitizenBelief = p.get_belief(trigger_event_id)
			if b and (b.is_convinced() or b.has_direct_experience):
				should_join = true
		elif not should_join and organizer_id > 0:
			# Coworkers who trust the organizer join solidarity walkout
			var conns: Array[Dictionary] = SocialGraph.get_social_connections(ws, organizer_id)
			for c in conns:
				if int(c.get("target_id", 0)) == pid and float(c.get("weight", 0.0)) >= 0.5:
					should_join = true
					break
					
		if should_join:
			action.add_participant(pid)
			striking_map[pid] = gathering_room
			
	ws.custom_data["striking_person_ids"] = striking_map
	
	var action_list: Array = ws.custom_data.get("collective_actions", [])
	action_list.append(action)
	ws.custom_data["collective_actions"] = action_list
	
	# Broadcast or log information object regarding strike emergence
	_create_strike_information(ws, action)
	
	return action

## Organizes a protest or civil disobedience assembly
func organize_protest(
	ws: WorldState,
	gathering_room_id: int,
	organizer_id: int,
	demands: Array[Dictionary] = [],
	faction_id: int = 0,
	trigger_event_id: String = ""
) -> CollectiveAction:
	if not ws or not ws.entity_registry:
		return null
		
	var next_id: int = int(ws.custom_data.get("next_action_id", 1))
	ws.custom_data["next_action_id"] = next_id + 1
	
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	
	var action: CollectiveAction = CollectiveAction.new(
		next_id,
		CollectiveAction.TYPE_PROTEST,
		"room",
		gathering_room_id,
		gathering_room_id,
		faction_id,
		cur_tick
	)
	action.trigger_event_id = trigger_event_id
	
	for d in demands:
		action.add_demand(str(d.get("type", "protest")), d.get("value", 1.0), str(d.get("description", "")))
		
	if organizer_id > 0:
		action.add_organizer(organizer_id)
		
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var striking_map: Dictionary = ws.custom_data.get("striking_person_ids", {})
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		var joins: bool = (pid == organizer_id)
		if not joins and faction_id > 0 and (p.faction_id == faction_id or p.sympathiser_faction_id == faction_id):
			joins = true
		elif not joins and p.class_resentment >= 0.5:
			joins = true
		elif not joins and trigger_event_id != "" and p.has_belief(trigger_event_id):
			var b: CitizenBelief = p.get_belief(trigger_event_id)
			if b and (b.is_convinced() or b.has_direct_experience):
				joins = true
				
		if joins:
			action.add_participant(pid)
			striking_map[pid] = gathering_room_id
			
	ws.custom_data["striking_person_ids"] = striking_map
	
	var action_list: Array = ws.custom_data.get("collective_actions", [])
	action_list.append(action)
	ws.custom_data["collective_actions"] = action_list
	
	return action

## Executes targeted physical machinery sabotage
func commit_sabotage(
	ws: WorldState,
	machine_id: int,
	component_id: String,
	saboteur_id: int,
	damage_percent: float = 100.0,
	trigger_event_id: String = ""
) -> CollectiveAction:
	if not ws or not ws.entity_registry:
		return null
		
	var registry: EntityRegistry = ws.entity_registry
	var machine: Machine = registry.get_entity(machine_id) as Machine
	if not machine:
		return null
		
	var comp: MachineComponent = machine.get_component(component_id)
	if not comp:
		return null
		
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	
	# 1. Inflict real physical wear on the component
	var inflicted: float = clampf(damage_percent, 0.0, 100.0)
	comp.wear_percent = minf(100.0, comp.wear_percent + inflicted)
	machine.update_state()
	
	# 2. Record collective action entry
	var next_id: int = int(ws.custom_data.get("next_action_id", 1))
	ws.custom_data["next_action_id"] = next_id + 1
	
	var action: CollectiveAction = CollectiveAction.new(
		next_id,
		CollectiveAction.TYPE_SABOTAGE,
		"machine",
		machine_id,
		machine.room_id,
		0,
		cur_tick
	)
	action.status = CollectiveAction.STATUS_ACTIVE
	action.trigger_event_id = trigger_event_id
	action.sabotage_details = {
		"machine_id": machine_id,
		"component_id": component_id,
		"damage_inflicted": inflicted,
		"component_wear_after": comp.wear_percent,
		"machine_state_after": machine.state
	}
	if saboteur_id > 0:
		action.add_organizer(saboteur_id)
		var sab: Person = registry.get_entity(saboteur_id) as Person
		if sab:
			action.faction_id = sab.faction_id
			
	var action_list: Array = ws.custom_data.get("collective_actions", [])
	action_list.append(action)
	ws.custom_data["collective_actions"] = action_list
	
	var sab_list: Array = ws.custom_data.get("sabotage_incidents", [])
	sab_list.append(action.sabotage_details.duplicate(true))
	ws.custom_data["sabotage_incidents"] = sab_list
	
	# Create information object for sabotage discovery
	var ev_id: String = "ev_sabotage_%d" % action.id
	var info_sys: Variant = ws.custom_data.get("information_system", null)
	if info_sys:
		var truth: Dictionary = {
			"machine_id": machine_id,
			"component_id": component_id,
			"true_cause": "sabotage",
			"damage": inflicted
		}
		var claim: Dictionary = {
			"machine_id": machine_id,
			"status": "critical_failure",
			"suspected_cause": "unauthorized_tampering"
		}
		info_sys.create_information(
			ws,
			ev_id,
			"institution",
			0,
			"machinery_sabotage",
			truth,
			claim,
			InformationObject.CHANNEL_WORKPLACE,
			{"type": "workplace", "workplace_room_id": machine.room_id},
			InformationObject.CLASS_CONFIDENTIAL,
			0.9,
			0.7
		)
		
	return action

## Administration resolution path A: Concessions granted
func grant_concessions(ws: WorldState, action_id: int, concessions: Dictionary = {}) -> bool:
	var action: CollectiveAction = _find_action(ws, action_id)
	if not action or not action.is_active():
		return false
		
	var cur_tick: int = ws.sim_clock.get_tick() if (ws and ws.sim_clock) else 0
	action.status = CollectiveAction.STATUS_CONCEDED
	action.end_tick = cur_tick
	action.concessions_granted = concessions.duplicate(true)
	
	# Release participants from strike: workers return to their jobs!
	var striking_map: Dictionary = ws.custom_data.get("striking_person_ids", {})
	var registry: EntityRegistry = ws.entity_registry
	
	for pid in action.participant_ids:
		striking_map.erase(pid)
		var p: Person = registry.get_entity(pid) as Person if registry else null
		if p and p.is_alive:
			p.institutional_trust = clampf(p.institutional_trust + 0.15, 0.0, 1.0)
			p.perceived_fairness = clampf(p.perceived_fairness + 0.15, 0.0, 1.0)
			p.class_resentment = clampf(p.class_resentment - 0.20, 0.0, 1.0)
			p.record_opinion_memory(
				PoliticalEvent.EVENT_CRISIS_RESOLVED,
				cur_tick,
				PoliticalEvent.DEPT_ADMINISTRATION,
				0.25,
				"Demands conceded by administration; returned to work.",
				action.id
			)
			
	ws.custom_data["striking_person_ids"] = striking_map
	return true

## Administration resolution path B: Forceful crackdown / suppression
func enforce_crackdown(ws: WorldState, action_id: int, security_officer_id: int = 0) -> bool:
	var action: CollectiveAction = _find_action(ws, action_id)
	if not action or not action.is_active():
		return false
		
	var cur_tick: int = ws.sim_clock.get_tick() if (ws and ws.sim_clock) else 0
	action.status = CollectiveAction.STATUS_SUPPRESSED
	action.end_tick = cur_tick
	
	var striking_map: Dictionary = ws.custom_data.get("striking_person_ids", {})
	var registry: EntityRegistry = ws.entity_registry
	
	for pid in action.participant_ids:
		striking_map.erase(pid)
		var p: Person = registry.get_entity(pid) as Person if registry else null
		if p and p.is_alive:
			# Severe political resentment towards administration
			p.institutional_trust = clampf(p.institutional_trust - 0.25, 0.0, 1.0)
			p.class_resentment = clampf(p.class_resentment + 0.30, 0.0, 1.0)
			p.perceived_fairness = clampf(p.perceived_fairness - 0.20, 0.0, 1.0)
			p.record_opinion_memory(
				PoliticalEvent.EVENT_COERCIVE_ORDER,
				cur_tick,
				PoliticalEvent.DEPT_SECURITY,
				-0.4,
				"Strike forcefully broken by security apparatus.",
				action.id
			)
			
	# Organizers receive additional sanctions
	for oid in action.organizer_ids:
		var org: Person = registry.get_entity(oid) as Person if registry else null
		if org and org.is_alive:
			org.security_clearance = maxi(1, org.security_clearance - 1)
			
	ws.custom_data["striking_person_ids"] = striking_map
	return true

# --- Internal Helper Methods ---

func _find_action(ws: WorldState, action_id: int) -> CollectiveAction:
	if not ws:
		return null
	var list: Array = ws.custom_data.get("collective_actions", [])
	for item in list:
		var act: CollectiveAction = item as CollectiveAction
		if act and act.id == action_id:
			return act
	return null

func _evaluate_emergent_collective_actions(ws: WorldState, cur_tick: int) -> void:
	if not ws or not ws.entity_registry:
		return
		
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	# Find workplaces with high average class resentment and active faction presence
	var room_resentment: Dictionary = {} # room_id -> {"total": float, "count": int, "workers": Array[int]}
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive or p.workplace_room_id <= 0:
			continue
		var rid: int = p.workplace_room_id
		if not room_resentment.has(rid):
			room_resentment[rid] = {"total": 0.0, "count": 0, "workers": []}
		room_resentment[rid]["total"] += p.class_resentment
		room_resentment[rid]["count"] += 1
		room_resentment[rid]["workers"].append(pid)
		
	for rid in room_resentment.keys():
		var data: Dictionary = room_resentment[rid]
		var count: int = int(data["count"])
		if count < 2:
			continue
		var avg_resentment: float = float(data["total"]) / float(count)
		
		# Boiling point threshold: average resentment >= 0.6
		if avg_resentment >= 0.6:
			# Check if room already has active action
			var already_active: bool = false
			var actions: Array = ws.custom_data.get("collective_actions", [])
			for a_item in actions:
				var a: CollectiveAction = a_item as CollectiveAction
				if a and a.is_active() and a.target_id == rid:
					already_active = true
					break
					
			if not already_active:
				var workers: Array = data["workers"]
				var organizer_id: int = workers[0]
				organize_strike(
					ws,
					rid,
					organizer_id,
					[{"type": "workload_reduction", "value": 0.8}],
					0,
					"ev_emergent_workplace_friction"
				)

func _create_strike_information(ws: WorldState, action: CollectiveAction) -> void:
	var info_sys: Variant = ws.custom_data.get("information_system", null)
	if not info_sys:
		return
		
	var ev_id: String = "ev_strike_%d" % action.id
	var truth: Dictionary = {
		"action_type": action.action_type,
		"workplace_room_id": action.target_id,
		"participants_count": action.participant_ids.size(),
		"organizer_ids": action.organizer_ids.duplicate()
	}
	var claim: Dictionary = {
		"action_type": action.action_type,
		"workplace_room_id": action.target_id,
		"message": "Workers have walked out on strike demanding concessions."
	}
	info_sys.create_information(
		ws,
		ev_id,
		"citizen",
		action.organizer_ids[0] if not action.organizer_ids.is_empty() else 0,
		"strike_declaration",
		truth,
		claim,
		InformationObject.CHANNEL_WORKPLACE,
		{"type": "workplace", "workplace_room_id": action.target_id},
		InformationObject.CLASS_PUBLIC,
		0.85,
		0.8
	)

func serialize() -> Dictionary:
	return {
		"last_emergence_check_tick": last_emergence_check_tick
	}

func deserialize(data: Dictionary) -> void:
	last_emergence_check_tick = int(data.get("last_emergence_check_tick", -1))
