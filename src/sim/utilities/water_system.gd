# src/sim/utilities/water_system.gd
class_name WaterSystem
extends BaseSystem

const SYSTEM_ID: String = "water_utility"
const EXECUTION_ORDER: int = 65

const INITIAL_RESERVOIR_LITERS: float = 50000.0
const MAX_RESERVOIR_CAPACITY_LITERS: float = 100000.0
const BASE_CONSUMPTION_L_PER_TICK: float = 2.5 / 144.0 # ~0.017361 L per person per 10-min tick (2.5 L/day)

var reservoir_capacity_liters: float = MAX_RESERVOIR_CAPACITY_LITERS
var reservoir_current_liters: float = INITIAL_RESERVOIR_LITERS
var total_pumped_liters: float = 0.0
var total_consumed_liters: float = 0.0
var last_tick_inflow_liters: float = 0.0
var last_tick_outflow_liters: float = 0.0

var _cached_pumps: Array[WaterPump] = []
var _cached_persons: Array[Person] = []
var _cached_person_count: int = 0
var _is_cached: bool = false

func _init(p_initial_reservoir: float = INITIAL_RESERVOIR_LITERS, p_max_capacity: float = MAX_RESERVOIR_CAPACITY_LITERS) -> void:
	super(SYSTEM_ID, EXECUTION_ORDER)
	reservoir_current_liters = p_initial_reservoir
	reservoir_capacity_liters = p_max_capacity
	total_pumped_liters = 0.0
	total_consumed_liters = 0.0
	last_tick_inflow_liters = 0.0
	last_tick_outflow_liters = 0.0

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	ws.custom_data["water_reservoir_liters"] = reservoir_current_liters
	ws.custom_data["water_reservoir_capacity_liters"] = reservoir_capacity_liters
	ws.custom_data["total_water_pumped_liters"] = total_pumped_liters
	ws.custom_data["total_water_consumed_liters"] = total_consumed_liters
	_rebuild_caches(ws)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	
	if not _is_cached or _cached_person_count == 0:
		_rebuild_caches(ws)
		
	# 1. Inflow from active Water Pumps (1 tick = 10 minutes)
	last_tick_inflow_liters = 0.0
	var throughput_mult: float = float(ws.custom_data.get("machine_throughput_multiplier", 1.0))
	var pump_count: int = _cached_pumps.size()
	for i in range(pump_count):
		var pump: WaterPump = _cached_pumps[i]
		if pump.is_running and pump.state != Machine.STATE_OFF and pump.state != Machine.STATE_BROKEN:
			var pump_inflow: float = pump.current_water_throughput_lpm * throughput_mult * 10.0
			last_tick_inflow_liters += pump_inflow
			
	var reservoir_space: float = maxf(0.0, reservoir_capacity_liters - reservoir_current_liters)
	var actual_inflow: float = minf(last_tick_inflow_liters, reservoir_space)
	reservoir_current_liters += actual_inflow
	total_pumped_liters += actual_inflow
	
	# 2. Outflow & Metabolic Hydration Distribution
	last_tick_outflow_liters = 0.0
	var base_ration: float = float(ws.custom_data.get("water_ration_rate", BASE_CONSUMPTION_L_PER_TICK))
	for i in range(_cached_person_count):
		var p: Person = _cached_persons[i]
		if not p.is_alive:
			continue
			
		p.apply_metabolic_decay(1)
		
		# Water demand: baseline drink + recovery if hydration is below 100%
		var demand_liters: float = base_ration
		if p.hydration_percent < 100.0:
			var deficit_liters: float = (100.0 - p.hydration_percent) / 40.0
			demand_liters = maxf(base_ration, minf(0.50, deficit_liters))
			
		if reservoir_current_liters > 0.0:
			var actual_drink: float = minf(reservoir_current_liters, demand_liters)
			reservoir_current_liters -= actual_drink
			last_tick_outflow_liters += actual_drink
			total_consumed_liters += actual_drink
			p.drink_water(actual_drink)
			
	ws.custom_data["water_reservoir_liters"] = reservoir_current_liters
	ws.custom_data["water_reservoir_capacity_liters"] = reservoir_capacity_liters
	ws.custom_data["total_water_pumped_liters"] = total_pumped_liters
	ws.custom_data["total_water_consumed_liters"] = total_consumed_liters

func _rebuild_caches(ws: WorldState) -> void:
	var registry: EntityRegistry = ws.entity_registry
	_cached_pumps.clear()
	
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	for mid in machine_ids:
		var m: Variant = registry.get_entity(mid)
		if m is WaterPump:
			_cached_pumps.append(m as WaterPump)
			
	_cached_persons.clear()
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if p:
			_cached_persons.append(p)
	_cached_person_count = _cached_persons.size()
	_is_cached = true

func serialize() -> Dictionary:
	return {
		"reservoir_capacity_liters": reservoir_capacity_liters,
		"reservoir_current_liters": reservoir_current_liters,
		"total_pumped_liters": total_pumped_liters,
		"total_consumed_liters": total_consumed_liters,
		"last_tick_inflow_liters": last_tick_inflow_liters,
		"last_tick_outflow_liters": last_tick_outflow_liters
	}

func deserialize(data: Dictionary) -> void:
	reservoir_capacity_liters = float(data.get("reservoir_capacity_liters", MAX_RESERVOIR_CAPACITY_LITERS))
	reservoir_current_liters = float(data.get("reservoir_current_liters", INITIAL_RESERVOIR_LITERS))
	total_pumped_liters = float(data.get("total_pumped_liters", 0.0))
	total_consumed_liters = float(data.get("total_consumed_liters", 0.0))
	last_tick_inflow_liters = float(data.get("last_tick_inflow_liters", 0.0))
	last_tick_outflow_liters = float(data.get("last_tick_outflow_liters", 0.0))
