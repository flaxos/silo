# src/presentation/collective_action_reader.gd
class_name CollectiveActionReader
extends RefCounted

## Read-only queries and telemetry projections for strikes, walkouts,
## sabotage incidents, and resolution states without mutating simulation state.

const CollectiveAction = preload("res://src/sim/politics/collective_action.gd")

static func get_collective_action_summary(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"total_actions_count": 0,
		"active_actions_count": 0,
		"active_strikes_count": 0,
		"active_protests_count": 0,
		"sabotage_incidents_count": 0,
		"striking_workers_count": 0,
		"affected_workplace_ids": []
	}
	
	if not ws:
		return result
		
	var actions: Array = ws.custom_data.get("collective_actions", [])
	result["total_actions_count"] = actions.size()
	
	var striking_map: Dictionary = ws.custom_data.get("striking_person_ids", {})
	result["striking_workers_count"] = striking_map.size()
	
	for item in actions:
		var act: CollectiveAction = item as CollectiveAction
		if not act:
			continue
			
		if act.action_type == CollectiveAction.TYPE_SABOTAGE:
			result["sabotage_incidents_count"] += 1
			
		if act.is_active():
			result["active_actions_count"] += 1
			if act.action_type == CollectiveAction.TYPE_STRIKE:
				result["active_strikes_count"] += 1
				if not result["affected_workplace_ids"].has(act.target_id):
					result["affected_workplace_ids"].append(act.target_id)
			elif act.action_type == CollectiveAction.TYPE_PROTEST:
				result["active_protests_count"] += 1
				
	return result

static func get_active_actions(ws: WorldState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ws:
		return result
		
	var actions: Array = ws.custom_data.get("collective_actions", [])
	for item in actions:
		var act: CollectiveAction = item as CollectiveAction
		if act and act.is_active():
			result.append(act.serialize())
			
	return result

static func get_workplace_strike_status(ws: WorldState, room_id: int) -> Dictionary:
	var result: Dictionary = {
		"room_id": room_id,
		"is_on_strike": false,
		"action_id": 0,
		"striking_workers": [],
		"demands": []
	}
	
	if not ws or not ws.entity_registry:
		return result
		
	var actions: Array = ws.custom_data.get("collective_actions", [])
	var active_strike: CollectiveAction = null
	
	for item in actions:
		var act: CollectiveAction = item as CollectiveAction
		if act and act.is_active() and act.action_type == CollectiveAction.TYPE_STRIKE and act.target_id == room_id:
			active_strike = act
			break
			
	if active_strike:
		result["is_on_strike"] = true
		result["action_id"] = active_strike.id
		result["demands"] = active_strike.demands.duplicate(true)
		
		var registry: EntityRegistry = ws.entity_registry
		for pid in active_strike.participant_ids:
			var p: Person = registry.get_entity(pid) as Person
			if p:
				result["striking_workers"].append({
					"id": p.id,
					"name": p.get_full_name(),
					"occupation": p.occupation_id
				})
				
	return result

static func get_sabotage_log(ws: WorldState) -> Array[Dictionary]:
	if not ws:
		return []
	var list: Array = ws.custom_data.get("sabotage_incidents", [])
	var copy: Array[Dictionary] = []
	for item in list:
		if item is Dictionary:
			copy.append((item as Dictionary).duplicate(true))
	return copy
