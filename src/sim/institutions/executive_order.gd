# src/sim/institutions/executive_order.gd
class_name ExecutiveOrder
extends RefCounted

const ORDER_WATER_CUTS: String = "order_water_cuts"
const ORDER_OVERTIME_SURGE: String = "order_overtime_surge"
const ORDER_MACHINE_OVERDRIVE: String = "order_machine_overdrive"
const ORDER_CONSCRIPT_LABOR: String = "order_conscript_labor"
const ORDER_LOCKDOWN_SECTOR: String = "order_lockdown_sector"

var id: String = ""
var order_type: String = ""
var name: String = ""
var department_id: String = ""
var target_id: String = ""
var is_active: bool = false
var duration_ticks: int = 0
var ticks_elapsed: int = 0
var enacted_tick: int = 0
var parameters: Dictionary = {}
var consequences: Dictionary = {}

func _init(
	p_id: String = "",
	p_type: String = "",
	p_name: String = "",
	p_dept: String = "",
	p_target: String = "",
	p_duration: int = 0,
	p_params: Dictionary = {}
) -> void:
	id = p_id if p_id != "" else p_type
	order_type = p_type
	name = p_name
	department_id = p_dept
	target_id = p_target
	duration_ticks = p_duration
	ticks_elapsed = 0
	enacted_tick = 0
	is_active = false
	parameters = p_params.duplicate(true)
	consequences = {
		"extra_wear_acc": 0.0,
		"extra_fatigue_acc": 0.0,
		"social_tension_acc": 0.0,
		"water_saved_liters": 0.0,
		"labor_conscripted_count": 0
	}

static func create_order(type: String, target: String = "", duration: int = 0) -> ExecutiveOrder:
	match type:
		ORDER_WATER_CUTS:
			return ExecutiveOrder.new(
				ORDER_WATER_CUTS + ("_" + target if target != "" else ""),
				ORDER_WATER_CUTS,
				"Executive Order: Emergency Water Cuts (-50%)",
				"utilities",
				target,
				duration,
				{
					"water_consumption_mult": 0.50,
					"social_tension_rate_per_day": 0.50,
					"hydration_penalty_per_day": 5.0
				}
			)
			
		ORDER_OVERTIME_SURGE:
			return ExecutiveOrder.new(
				ORDER_OVERTIME_SURGE + ("_" + target if target != "" else ""),
				ORDER_OVERTIME_SURGE,
				"Executive Order: Mandatory 12-Hour Labor Surge",
				"industry",
				target,
				duration,
				{
					"labor_output_mult": 1.50,
					"machine_wear_mult": 1.50,
					"worker_fatigue_rate_mult": 2.00,
					"social_tension_rate_per_day": 0.35
				}
			)
			
		ORDER_MACHINE_OVERDRIVE:
			return ExecutiveOrder.new(
				ORDER_MACHINE_OVERDRIVE + ("_" + target if target != "" else ""),
				ORDER_MACHINE_OVERDRIVE,
				"Executive Order: Machine Overdrive Mode (+25% Throughput)",
				"engineering",
				target,
				duration,
				{
					"throughput_mult": 1.25,
					"wear_rate_mult": 2.50,
					"breakdown_chance_per_tick": 0.002
				}
			)
			
		ORDER_CONSCRIPT_LABOR:
			return ExecutiveOrder.new(
				ORDER_CONSCRIPT_LABOR + ("_" + target if target != "" else ""),
				ORDER_CONSCRIPT_LABOR,
				"Executive Order: Emergency Workforce Conscription",
				"administration",
				target,
				duration,
				{
					"target_occupation": target if target != "" else "maintenance_technician",
					"social_tension_rate_per_day": 0.40
				}
			)
			
		ORDER_LOCKDOWN_SECTOR:
			return ExecutiveOrder.new(
				ORDER_LOCKDOWN_SECTOR + ("_" + target if target != "" else ""),
				ORDER_LOCKDOWN_SECTOR,
				"Executive Order: Complete Sector Quarantine",
				"security",
				target,
				duration,
				{
					"locked_sector_id": int(target) if target.is_valid_int() else 1,
					"social_tension_rate_per_day": 0.60
				}
			)
			
		_:
			return ExecutiveOrder.new(type, type, "Custom Order: " + type, "administration", target, duration, {})

func is_expired() -> bool:
	if duration_ticks <= 0:
		return false # Indefinite until manually cancelled
	return ticks_elapsed >= duration_ticks

func step_order(_ws: Variant) -> void:
	if not is_active:
		return
	ticks_elapsed += 1

func serialize() -> Dictionary:
	return {
		"id": id,
		"order_type": order_type,
		"name": name,
		"department_id": department_id,
		"target_id": target_id,
		"is_active": is_active,
		"duration_ticks": duration_ticks,
		"ticks_elapsed": ticks_elapsed,
		"enacted_tick": enacted_tick,
		"parameters": parameters.duplicate(true),
		"consequences": consequences.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	id = data.get("id", "")
	order_type = data.get("order_type", "")
	name = data.get("name", "")
	department_id = data.get("department_id", "")
	target_id = data.get("target_id", "")
	is_active = bool(data.get("is_active", false))
	duration_ticks = int(data.get("duration_ticks", 0))
	ticks_elapsed = int(data.get("ticks_elapsed", 0))
	enacted_tick = int(data.get("enacted_tick", 0))
	parameters = data.get("parameters", {}).duplicate(true)
	consequences = data.get("consequences", {}).duplicate(true)
