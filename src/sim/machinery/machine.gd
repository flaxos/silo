# src/sim/machinery/machine.gd
class_name Machine
extends RefCounted

const STATE_OFF: int = 0
const STATE_NOMINAL: int = 1
const STATE_DEGRADED: int = 2
const STATE_FAULT: int = 3
const STATE_BROKEN: int = 4

var id: int = 0
var room_id: int = 0
var machine_type: String = "generic_machine"
var state: int = STATE_NOMINAL
var is_running: bool = true
var operating_power_draw_kw: float = 15.0
var total_operating_hours: float = 0.0
var components: Dictionary = {} # String id -> MachineComponent
var active_repair_component_id: String = ""

func _init(p_id: int = 0, p_room_id: int = 0, p_type: String = "generic_machine") -> void:
	id = p_id
	room_id = p_room_id
	machine_type = p_type
	state = STATE_NOMINAL
	is_running = true
	operating_power_draw_kw = 15.0
	total_operating_hours = 0.0
	components = {}
	active_repair_component_id = ""

func add_component(comp: MachineComponent) -> void:
	components[comp.id] = comp

func get_component(comp_id: String) -> MachineComponent:
	return components.get(comp_id, null)

func tick_operation(dt_hours: float) -> void:
	if not is_running or state == STATE_OFF or state == STATE_BROKEN:
		return
	
	total_operating_hours += dt_hours
	for comp in components.values():
		var c: MachineComponent = comp as MachineComponent
		c.add_operating_hours(dt_hours)
	
	update_state()

func update_state() -> void:
	if not is_running:
		state = STATE_OFF
		return
	
	var worst_comp_state: int = MachineComponent.STATE_NOMINAL
	var has_broken_critical: bool = false
	
	for comp in components.values():
		var c: MachineComponent = comp as MachineComponent
		var c_state: int = c.get_wear_state()
		
		if c.is_broken() and c.criticality >= 1.0:
			has_broken_critical = true
			break
		
		if c_state > worst_comp_state:
			worst_comp_state = c_state
	
	if has_broken_critical:
		state = STATE_BROKEN
	elif worst_comp_state == MachineComponent.STATE_BROKEN:
		state = STATE_BROKEN
	elif worst_comp_state == MachineComponent.STATE_FAULT:
		state = STATE_FAULT
	elif worst_comp_state == MachineComponent.STATE_DEGRADED:
		state = STATE_DEGRADED
	else:
		state = STATE_NOMINAL

func get_overall_efficiency() -> float:
	if not is_running or state == STATE_OFF or state == STATE_BROKEN:
		return 0.0
	
	var min_eff: float = 1.0
	for comp in components.values():
		var c: MachineComponent = comp as MachineComponent
		var c_eff: float = c.get_efficiency()
		if c.criticality >= 1.0 and c_eff <= 0.0:
			return 0.0
		if c_eff < min_eff:
			min_eff = c_eff
			
	return min_eff

func get_most_worn_component() -> MachineComponent:
	var worst_comp: MachineComponent = null
	var highest_wear: float = -1.0
	
	# Deterministic iteration by sorted component keys
	var keys: Array = components.keys()
	keys.sort()
	
	for key in keys:
		var c: MachineComponent = components[key] as MachineComponent
		if c.wear_percent > highest_wear:
			highest_wear = c.wear_percent
			worst_comp = c
			
	return worst_comp

func needs_maintenance(threshold_wear: float = 60.0) -> bool:
	for comp in components.values():
		var c: MachineComponent = comp as MachineComponent
		if c.wear_percent >= threshold_wear:
			return true
	return false

func serialize() -> Dictionary:
	var comps_data: Dictionary = {}
	for k in components.keys():
		var c: MachineComponent = components[k] as MachineComponent
		comps_data[str(k)] = c.serialize()
		
	return {
		"id": id,
		"room_id": room_id,
		"machine_type": machine_type,
		"state": state,
		"is_running": is_running,
		"operating_power_draw_kw": operating_power_draw_kw,
		"total_operating_hours": total_operating_hours,
		"active_repair_component_id": active_repair_component_id,
		"components": comps_data
	}

func deserialize(data: Dictionary) -> void:
	id = data.get("id", 0)
	room_id = data.get("room_id", 0)
	machine_type = data.get("machine_type", "generic_machine")
	state = data.get("state", STATE_NOMINAL)
	is_running = data.get("is_running", true)
	operating_power_draw_kw = float(data.get("operating_power_draw_kw", 15.0))
	total_operating_hours = float(data.get("total_operating_hours", 0.0))
	active_repair_component_id = data.get("active_repair_component_id", "")
	
	components.clear()
	var raw_comps: Dictionary = data.get("components", {})
	for k in raw_comps.keys():
		var c: MachineComponent = MachineComponent.new()
		c.deserialize(raw_comps[k])
		components[str(k)] = c
