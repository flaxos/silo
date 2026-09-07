# src/sim/economy/resource_registry.gd
class_name ResourceRegistry
extends RefCounted

const RES_IRON_ORE: String = "iron_ore"
const RES_PROCESSED_ORE: String = "processed_ore"
const RES_METAL_STOCK: String = "metal_stock"
const RES_MACHINED_BEARING: String = "machined_bearing"
const RES_SLAG_TAILINGS: String = "slag_tailings"
const RES_METAL_SWARF: String = "metal_swarf"

const RESOURCES: Dictionary = {
	RES_IRON_ORE: {
		"name": "Raw Iron Ore",
		"unit_mass_kg": 1.0,
		"category": "raw_material"
	},
	RES_PROCESSED_ORE: {
		"name": "Processed Sintered Ore",
		"unit_mass_kg": 0.8,
		"category": "intermediate"
	},
	RES_METAL_STOCK: {
		"name": "Cast Metal Stock",
		"unit_mass_kg": 0.75,
		"category": "intermediate"
	},
	RES_MACHINED_BEARING: {
		"name": "Machined Roller Bearing",
		"unit_mass_kg": 0.5,
		"category": "finished_component"
	},
	RES_SLAG_TAILINGS: {
		"name": "Mineral Slag & Tailings",
		"unit_mass_kg": 0.2,
		"category": "waste"
	},
	RES_METAL_SWARF: {
		"name": "Machining Swarf & Scrap",
		"unit_mass_kg": 0.25,
		"category": "waste"
	}
}

static func get_unit_mass(resource_id: String) -> float:
	var def: Dictionary = RESOURCES.get(resource_id, {})
	return float(def.get("unit_mass_kg", 1.0))

static func get_resource_name(resource_id: String) -> String:
	var def: Dictionary = RESOURCES.get(resource_id, {})
	return str(def.get("name", resource_id))

static func is_valid_resource(resource_id: String) -> bool:
	return RESOURCES.has(resource_id)
