# src/sim/economy/inventory.gd
class_name Inventory
extends RefCounted

var id: int = 0
var owner_entity_id: int = 0
var max_mass_kg: float = 100000.0
var stocks: Dictionary = {} # String resource_id -> float quantity

func _init(p_id: int = 0, p_owner_id: int = 0, p_max_mass: float = 100000.0) -> void:
	id = p_id
	owner_entity_id = p_owner_id
	max_mass_kg = p_max_mass
	stocks = {}

func add_resource(resource_id: String, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var current: float = stocks.get(resource_id, 0.0)
	var unit_mass: float = ResourceRegistry.get_unit_mass(resource_id)
	var available_capacity_kg: float = maxf(0.0, max_mass_kg - get_total_mass_kg())
	var max_addable_units: float = available_capacity_kg / maxf(0.001, unit_mass)
	
	var actual_add: float = minf(amount, max_addable_units)
	if actual_add > 0.0:
		stocks[resource_id] = current + actual_add
	return actual_add

func remove_resource(resource_id: String, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var current: float = stocks.get(resource_id, 0.0)
	var actual_remove: float = minf(current, amount)
	if actual_remove > 0.0:
		var remaining: float = current - actual_remove
		if remaining <= 0.000001:
			stocks.erase(resource_id)
		else:
			stocks[resource_id] = remaining
	return actual_remove

func get_quantity(resource_id: String) -> float:
	return float(stocks.get(resource_id, 0.0))

## Alias for get_quantity — used by corruption/audit ledger code
func get_stock(resource_id: String) -> float:
	return get_quantity(resource_id)

func has_resource(resource_id: String, amount: float) -> bool:
	return get_quantity(resource_id) >= (amount - 0.000001)

func transfer_to(target_inventory: Inventory, resource_id: String, amount: float) -> float:
	if not target_inventory or amount <= 0.0:
		return 0.0
	var available: float = get_quantity(resource_id)
	var desired: float = minf(available, amount)
	if desired <= 0.0:
		return 0.0
		
	var actual_added: float = target_inventory.add_resource(resource_id, desired)
	if actual_added > 0.0:
		remove_resource(resource_id, actual_added)
	return actual_added

func get_total_mass_kg() -> float:
	var total_mass: float = 0.0
	for res_id in stocks.keys():
		var qty: float = float(stocks[res_id])
		var unit_m: float = ResourceRegistry.get_unit_mass(str(res_id))
		total_mass += qty * unit_m
	return total_mass

func serialize() -> Dictionary:
	var stocks_data: Dictionary = {}
	for k in stocks.keys():
		stocks_data[str(k)] = float(stocks[k])
	return {
		"id": id,
		"owner_entity_id": owner_entity_id,
		"max_mass_kg": max_mass_kg,
		"stocks": stocks_data
	}

func deserialize(data: Dictionary) -> void:
	id = data.get("id", 0)
	owner_entity_id = data.get("owner_entity_id", 0)
	max_mass_kg = data.get("max_mass_kg", 100000.0)
	stocks.clear()
	var raw_stocks: Dictionary = data.get("stocks", {})
	for k in raw_stocks.keys():
		stocks[str(k)] = float(raw_stocks[k])
