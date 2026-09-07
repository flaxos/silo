# src/sim/politics/corruption_invariants.gd
class_name CorruptionInvariants
extends RefCounted

## Validates integrity, mass conservation, discrepancy arithmetic,
## and lifecycle monotonicity for corruption, favours, and patronage.

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	if not ws or not ws.entity_registry:
		return {"is_valid": false, "errors": ["WorldState or EntityRegistry is null"]}
		
	var registry: EntityRegistry = ws.entity_registry
	var favours: Array = ws.custom_data.get("favours", [])
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	
	# 1. Validate Favour Integrity
	for f_item in favours:
		var f: Favour = f_item as Favour
		if not f:
			errors.append("Null or invalid Favour object in custom_data['favours']")
			continue
		if f.granter_id <= 0 or not (registry.get_entity(f.granter_id) is Person):
			errors.append("Favour %d has invalid granter_id %d" % [f.id, f.granter_id])
		if f.recipient_id <= 0 or not (registry.get_entity(f.recipient_id) is Person):
			errors.append("Favour %d has invalid recipient_id %d" % [f.id, f.recipient_id])
		if f.granter_id == f.recipient_id:
			errors.append("Favour %d has identical granter and recipient %d" % [f.id, f.granter_id])
		if f.obligation_value < 0.0 or f.obligation_value > 1.0:
			errors.append("Favour %d obligation_value %f out of bounds [0, 1]" % [f.id, f.obligation_value])
		if f.is_settled and f.settled_tick < f.creation_tick:
			errors.append("Favour %d settled_tick %d precedes creation_tick %d" % [f.id, f.settled_tick, f.creation_tick])
			
	# 2. Validate Illicit Action Integrity & Discrepancies
	var active_discrepancies: int = 0
	for a_item in actions:
		var act: IllicitAction = a_item as IllicitAction
		if not act:
			errors.append("Null or invalid IllicitAction object in custom_data['illicit_actions']")
			continue
		if act.perpetrator_id <= 0 or not (registry.get_entity(act.perpetrator_id) is Person):
			errors.append("IllicitAction %d has invalid perpetrator_id %d" % [act.id, act.perpetrator_id])
		if act.beneficiary_id <= 0 or not (registry.get_entity(act.beneficiary_id) is Person):
			errors.append("IllicitAction %d has invalid beneficiary_id %d" % [act.id, act.beneficiary_id])
		if act.source_room_id > 0 and not (registry.get_entity(act.source_room_id) is Room):
			errors.append("IllicitAction %d has invalid source_room_id %d" % [act.id, act.source_room_id])
		if act.destination_room_id > 0 and not (registry.get_entity(act.destination_room_id) is Room):
			errors.append("IllicitAction %d has invalid destination_room_id %d" % [act.id, act.destination_room_id])
		if act.discrepancy_amount < 0.0:
			errors.append("IllicitAction %d negative discrepancy amount %f" % [act.id, act.discrepancy_amount])
		if act.concealment_level < 0.0 or act.concealment_level > 1.0:
			errors.append("IllicitAction %d concealment_level %f out of bounds [0, 1]" % [act.id, act.concealment_level])
		if act.evidence_strength < 0.0 or act.evidence_strength > 1.0:
			errors.append("IllicitAction %d evidence_strength %f out of bounds [0, 1]" % [act.id, act.evidence_strength])
		if act.discovered_tick > 0 and act.discovered_tick < act.tick:
			errors.append("IllicitAction %d discovered_tick %d precedes commit tick %d" % [act.id, act.discovered_tick, act.tick])
		if act.discovery_status == IllicitAction.STATUS_CONCEALED and act.discrepancy_amount > 0.0:
			active_discrepancies += 1
			
	# 3. Validate Mass Conservation
	var econ_val: Dictionary = EconomyInvariants.validate(ws)
	if not econ_val.get("is_valid", false):
		errors.append("Economy mass conservation invariant violated: %s" % str(econ_val.get("errors", [])))
		
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"favour_count": favours.size(),
		"action_count": actions.size(),
		"active_discrepancies": active_discrepancies,
		"economy_valid": econ_val.get("is_valid", true)
	}
