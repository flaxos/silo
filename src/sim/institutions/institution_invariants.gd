# src/sim/institutions/institution_invariants.gd
class_name InstitutionInvariants
extends RefCounted

static func validate(world_state: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var stats: Dictionary = {
		"active_policies": 0,
		"active_orders": 0,
		"social_tension": 0.0,
		"water_ration_rate": 0.0,
		"maintenance_wear_threshold": 0.0,
		"shift_work_hours": 0
	}
	
	if not world_state:
		errors.append("WorldState is null")
		return {"is_valid": false, "errors": errors, "stats": stats}
		
	var inst_sys: InstitutionSystem = world_state.custom_data.get("institution_system", null) as InstitutionSystem
	if not inst_sys:
		# If no InstitutionSystem registered, check world state fallback values
		return {"is_valid": true, "errors": errors, "stats": stats}
		
	stats["active_policies"] = inst_sys.active_policies.size()
	stats["active_orders"] = inst_sys.active_orders.size()
	stats["social_tension"] = inst_sys.social_tension_index
	stats["water_ration_rate"] = inst_sys.get_water_ration_rate()
	stats["maintenance_wear_threshold"] = inst_sys.get_maintenance_trigger_wear()
	stats["shift_work_hours"] = inst_sys.get_shift_work_hours()
	
	# 1. Validate Social Tension Bounds
	if inst_sys.social_tension_index < 0.0 or inst_sys.social_tension_index > 100.0:
		errors.append("Social tension index out of bounds [0, 100]: %f" % inst_sys.social_tension_index)
		
	# 2. Validate Policy Category Exclusivity & Integrity
	var seen_categories: Dictionary = {}
	for cat in inst_sys.active_policies:
		var pol: Policy = inst_sys.active_policies[cat] as Policy
		if not pol:
			errors.append("Null policy in category: %s" % cat)
			continue
			
		if not pol.is_active:
			errors.append("Policy marked inactive present in active_policies: %s" % pol.id)
			
		if pol.category != cat:
			errors.append("Policy category mismatch: registered in '%s' but policy.category is '%s'" % [cat, pol.category])
			
		if seen_categories.has(pol.category):
			errors.append("Duplicate active policy for category '%s'" % pol.category)
		seen_categories[pol.category] = true
		
		if pol.id == "":
			errors.append("Active policy has empty ID")
		if pol.department_id == "":
			errors.append("Active policy '%s' has empty department_id" % pol.id)
			
	# 3. Validate Parameter Bounds
	var ration_rate: float = inst_sys.get_water_ration_rate()
	if ration_rate <= 0.0 or ration_rate > 1.0:
		errors.append("Water ration rate out of physical bounds (0.0, 1.0]: %f" % ration_rate)
		
	var maint_threshold: float = inst_sys.get_maintenance_trigger_wear()
	if maint_threshold < 10.0 or maint_threshold > 100.0:
		errors.append("Maintenance trigger wear out of bounds [10.0, 100.0]: %f" % maint_threshold)
		
	var shift_hours: int = inst_sys.get_shift_work_hours()
	if shift_hours < 4 or shift_hours > 20:
		errors.append("Shift work hours out of human physical limits [4, 20]: %d" % shift_hours)
		
	var wear_mult: float = inst_sys.get_machine_wear_rate_multiplier()
	if wear_mult < 0.1:
		errors.append("Machine wear multiplier cannot be negative or near-zero: %f" % wear_mult)
		
	# 4. Validate Active Executive Orders
	for oid in inst_sys.active_orders:
		var ord: ExecutiveOrder = inst_sys.active_orders[oid] as ExecutiveOrder
		if not ord:
			errors.append("Null executive order with key: %s" % oid)
			continue
			
		if not ord.is_active:
			errors.append("Executive order '%s' marked inactive present in active_orders" % oid)
			
		if ord.duration_ticks > 0 and ord.ticks_elapsed > ord.duration_ticks:
			errors.append("Executive order '%s' exceeded duration: %d / %d" % [oid, ord.ticks_elapsed, ord.duration_ticks])
			
		if ord.consequences.get("extra_wear_acc", 0.0) < 0.0:
			errors.append("Executive order '%s' has negative accumulated wear consequence" % oid)
			
		if ord.consequences.get("social_tension_acc", 0.0) < 0.0:
			errors.append("Executive order '%s' has negative accumulated tension consequence" % oid)
			
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"stats": stats
	}
