# src/sim/economy/economy_invariants.gd
class_name EconomyInvariants
extends RefCounted

static func compute_total_system_mass_kg(world_state: WorldState) -> float:
	var total_mass: float = float(world_state.custom_data.get("geological_seam_ore_kg", 0.0))
	total_mass += float(world_state.custom_data.get("maintenance_installed_mass_kg", 0.0))
	var registry: EntityRegistry = world_state.entity_registry
	var inv_ids: Array[int] = registry.get_entities_by_type("inventory")
	
	for inv_id in inv_ids:
		var inv: Inventory = registry.get_entity(inv_id) as Inventory
		if inv:
			total_mass += inv.get_total_mass_kg()
			
	return total_mass

static func validate(world_state: WorldState, expected_initial_mass_kg: float = -1.0) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = world_state.entity_registry
	var inv_ids: Array[int] = registry.get_entities_by_type("inventory")
	
	var current_total_mass: float = compute_total_system_mass_kg(world_state)
	var total_inventory_mass: float = 0.0
	var resource_totals: Dictionary = {}
	
	for inv_id in inv_ids:
		var inv: Inventory = registry.get_entity(inv_id) as Inventory
		if not inv:
			errors.append("Entity %d registered as 'inventory' is not an Inventory object" % inv_id)
			continue
			
		for res_id in inv.stocks.keys():
			var qty: float = float(inv.stocks[res_id])
			if qty < -0.000001:
				errors.append("Inventory %d has negative stock for resource %s: %f" % [inv_id, res_id, qty])
			resource_totals[res_id] = resource_totals.get(res_id, 0.0) + qty
			
		total_inventory_mass += inv.get_total_mass_kg()
		
	# Mass conservation check
	if expected_initial_mass_kg > 0.0:
		var delta_mass: float = absf(current_total_mass - expected_initial_mass_kg)
		if delta_mass > 0.001:
			errors.append("Conservation of Mass VIOLATION! Expected total mass %f kg, got %f kg (delta %f kg)" % [
				expected_initial_mass_kg, current_total_mass, delta_mass
			])
			
	var stats: Dictionary = {
		"total_system_mass_kg": current_total_mass,
		"geological_seam_ore_kg": float(world_state.custom_data.get("geological_seam_ore_kg", 0.0)),
		"total_inventory_mass_kg": total_inventory_mass,
		"inventories_count": inv_ids.size(),
		"resource_totals": resource_totals
	}
	
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"stats": stats
	}
