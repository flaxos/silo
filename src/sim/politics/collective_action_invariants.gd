# src/sim/politics/collective_action_invariants.gd
class_name CollectiveActionInvariants
extends RefCounted

## Validates integrity, identified participant persistence, physical consequence validity,
## and determinism for strikes, sabotage, and collective actions.

const CollectiveAction = preload("res://src/sim/politics/collective_action.gd")

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	if not ws or not ws.entity_registry:
		return {"is_valid": false, "errors": ["WorldState or EntityRegistry is null"]}
		
	var registry: EntityRegistry = ws.entity_registry
	var actions: Array = ws.custom_data.get("collective_actions", [])
	var striking_map: Dictionary = ws.custom_data.get("striking_person_ids", {})
	var seen_ids: Dictionary = {}
	var last_id: int = 0
	
	var active_strikes: int = 0
	var total_participants_recorded: int = 0
	
	# 1. Validate CollectiveAction Objects
	for item in actions:
		var act: CollectiveAction = item as CollectiveAction
		if not act:
			errors.append("Null or invalid CollectiveAction object in custom_data['collective_actions']")
			continue
			
		if act.id <= 0:
			errors.append("CollectiveAction has non-positive id: %d" % act.id)
		if seen_ids.has(act.id):
			errors.append("Duplicate CollectiveAction id: %d" % act.id)
		seen_ids[act.id] = true
		
		if act.id < last_id:
			errors.append("CollectiveAction id non-monotonic: %d after %d" % [act.id, last_id])
		last_id = act.id
		
		# Invariant: Identified participants only (no phantom generic crowd spawns)
		if act.participant_ids.is_empty() and act.is_active():
			errors.append("Active CollectiveAction %d has empty participant_ids (must have identified citizens)" % act.id)
			
		for pid in act.participant_ids:
			if pid <= 0 or not (registry.get_entity(pid) is Person):
				errors.append("CollectiveAction %d references invalid participant person id %d" % [act.id, pid])
			total_participants_recorded += 1
			
		for oid in act.organizer_ids:
			if oid <= 0 or not (registry.get_entity(oid) is Person):
				errors.append("CollectiveAction %d references invalid organizer person id %d" % [act.id, oid])
				
		# Invariant: Physical validity of sabotage target
		if act.action_type == CollectiveAction.TYPE_SABOTAGE:
			var mach_id: int = int(act.sabotage_details.get("machine_id", act.target_id))
			var mach: Machine = registry.get_entity(mach_id) as Machine
			if not mach:
				errors.append("Sabotage action %d references non-existent machine %d" % [act.id, mach_id])
			else:
				var cid: String = str(act.sabotage_details.get("component_id", ""))
				var comp: MachineComponent = mach.get_component(cid)
				if not comp:
					errors.append("Sabotage action %d references non-existent component '%s' on machine %d" % [act.id, cid, mach_id])
				elif comp.wear_percent < 0.0 or comp.wear_percent > 100.0 or is_nan(comp.wear_percent):
					errors.append("Sabotaged component wear out of bounds: %f" % comp.wear_percent)
					
		# Invariant: Physical validity of strike target room
		if act.action_type == CollectiveAction.TYPE_STRIKE:
			var room: Room = registry.get_entity(act.target_id) as Room
			if not room:
				errors.append("Strike action %d references non-existent workplace room %d" % [act.id, act.target_id])
			if act.is_active():
				active_strikes += 1
				
	# 2. Validate Striking Participant Map
	for pid in striking_map.keys():
		var p: Person = registry.get_entity(int(pid)) as Person
		if not p:
			errors.append("striking_person_ids contains invalid or deceased person id %d" % int(pid))
			
	# 3. Validate Mass Balance Invariant
	var econ_val: Dictionary = EconomyInvariants.validate(ws)
	if not econ_val.get("is_valid", false):
		errors.append("Economy mass conservation invariant violated during collective action: %s" % str(econ_val.get("errors", [])))
		
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"actions_count": actions.size(),
		"active_strikes": active_strikes,
		"striking_workers_count": striking_map.size(),
		"economy_valid": econ_val.get("is_valid", true)
	}
