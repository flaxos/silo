# src/sim/machinery/machinery_invariants.gd
class_name MachineryInvariants
extends RefCounted

static func validate(world_state: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = world_state.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	
	var total_machines: int = machine_ids.size()
	var nominal_count: int = 0
	var degraded_count: int = 0
	var fault_count: int = 0
	var broken_count: int = 0
	var total_throughput_lpm: float = 0.0
	
	for mid in machine_ids:
		var machine: Machine = registry.get_entity(mid) as Machine
		if machine == null:
			errors.append("Entity ID %d in machine registry is null or not a Machine" % mid)
			continue
			
		# 1. State counting
		match machine.state:
			Machine.STATE_NOMINAL:
				nominal_count += 1
			Machine.STATE_DEGRADED:
				degraded_count += 1
			Machine.STATE_FAULT:
				fault_count += 1
			Machine.STATE_BROKEN:
				broken_count += 1
			Machine.STATE_OFF:
				pass
			_:
				errors.append("Machine ID %d has invalid state %d" % [mid, machine.state])
				
		# 2. Check components wear limits and state consistency
		var has_critical_broken: bool = false
		var worst_comp_state: int = MachineComponent.STATE_NOMINAL
		
		for comp in machine.components.values():
			var c: MachineComponent = comp as MachineComponent
			if c.wear_percent < 0.0 or c.wear_percent > 100.000001:
				errors.append("Machine ID %d component '%s' wear out of bounds: %.3f%%" % [mid, c.id, c.wear_percent])
				
			var c_state: int = c.get_wear_state()
			if c.is_broken() and c.criticality >= 1.0:
				has_critical_broken = true
			if c_state > worst_comp_state:
				worst_comp_state = c_state
				
		# 3. Broken machine invariant
		if has_critical_broken and machine.state != Machine.STATE_BROKEN and machine.is_running:
			errors.append("Machine ID %d has broken critical component but state is %d (expected BROKEN)" % [mid, machine.state])
			
		# 4. WaterPump specific checks
		if machine is WaterPump:
			var pump: WaterPump = machine as WaterPump
			total_throughput_lpm += pump.current_water_throughput_lpm
			
			if pump.current_water_throughput_lpm < 0.0 or pump.current_water_throughput_lpm > (pump.max_water_throughput_lpm + 0.001):
				errors.append("Pump ID %d throughput out of bounds: %.2f (max %.2f)" % [mid, pump.current_water_throughput_lpm, pump.max_water_throughput_lpm])
				
			if pump.state == Machine.STATE_BROKEN and pump.current_water_throughput_lpm > 0.000001:
				errors.append("Broken pump ID %d has non-zero throughput: %.2f L/min" % [mid, pump.current_water_throughput_lpm])
				
			if pump.state == Machine.STATE_NOMINAL and pump.is_running and pump.current_water_throughput_lpm <= 0.000001:
				errors.append("Nominal pump ID %d has zero throughput" % mid)
				
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"stats": {
			"total_machines": total_machines,
			"nominal_count": nominal_count,
			"degraded_count": degraded_count,
			"fault_count": fault_count,
			"broken_count": broken_count,
			"total_throughput_lpm": total_throughput_lpm
		}
	}
