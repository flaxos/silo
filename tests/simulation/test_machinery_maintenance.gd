# tests/simulation/test_machinery_maintenance.gd
class_name TestMachineryMaintenance
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_water_pump_degradation_over_time(asserts)
	test_repair_fails_without_replacement_parts(asserts)
	test_successful_repair_with_technician_and_bearing(asserts)
	test_closed_loop_economy_and_maintenance(asserts)
	test_machinery_determinism(asserts)

func test_water_pump_degradation_over_time(asserts: TestAsserts) -> void:
	asserts.set_current_test("MachineryMaintenance: Water Pump Degradation Over 1,000 Operating Hours")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	# Register only maintenance system so no technician repairs happen during this isolation test
	engine.register_system(MaintenanceSystem.new())
	
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	asserts.assert_gt(machine_ids.size(), 0, "Water pump machine should be registered")
	
	var pump: WaterPump = registry.get_entity(machine_ids[0]) as WaterPump
	asserts.assert_not_null(pump, "Registered machine should be a WaterPump instance")
	
	# Initial State Verification
	asserts.assert_eq(pump.state, Machine.STATE_NOMINAL, "Initial pump state should be NOMINAL")
	asserts.assert_almost_eq(pump.current_water_throughput_lpm, 500.0, 0.01, "Initial throughput should be 500 L/min")
	
	var bearing: MachineComponent = pump.get_component(WaterPump.COMP_BEARING)
	asserts.assert_not_null(bearing, "Bearing component should exist")
	asserts.assert_almost_eq(bearing.wear_percent, 0.0, 0.001, "Initial bearing wear should be 0.0%")
	
	# Step 1: Run for 600 hours (3,600 ticks) -> Bearing wear = 60%, state enters DEGRADED
	engine.step(3600)
	asserts.assert_almost_eq(pump.total_operating_hours, 600.0, 0.01, "Operating hours should reach 600.0 hrs")
	asserts.assert_almost_eq(bearing.wear_percent, 60.0, 0.01, "Bearing wear should reach 60.0%")
	asserts.assert_eq(pump.state, Machine.STATE_DEGRADED, "Pump state should be DEGRADED at 60% wear")
	
	# Step 2: Run another 300 hours (1,800 ticks, total 900 hrs) -> Bearing wear = 90%, state enters FAULT
	engine.step(1800)
	asserts.assert_almost_eq(pump.total_operating_hours, 900.0, 0.01, "Operating hours should reach 900.0 hrs")
	asserts.assert_almost_eq(bearing.wear_percent, 90.0, 0.01, "Bearing wear should reach 90.0%")
	asserts.assert_eq(pump.state, Machine.STATE_FAULT, "Pump state should be FAULT at 90% wear")
	asserts.assert_almost_eq(pump.current_water_throughput_lpm, 350.0, 0.01, "Pump throughput should drop to 350 L/min at 90% wear")
	
	# Step 3: Run another 100 hours (600 ticks, total 1,000 hrs) -> Bearing wear reaches 100%, pump BREAKS
	engine.step(600)
	asserts.assert_almost_eq(pump.total_operating_hours, 1000.0, 0.01, "Operating hours should reach 1,000.0 hrs")
	asserts.assert_almost_eq(bearing.wear_percent, 100.0, 0.01, "Bearing wear should reach 100.0%")
	asserts.assert_eq(pump.state, Machine.STATE_BROKEN, "Pump state must be BROKEN at 100% bearing wear")
	asserts.assert_almost_eq(pump.current_water_throughput_lpm, 0.0, 0.0001, "Broken pump throughput must be exactly 0.0 L/min")
	
	var inv_result: Dictionary = MachineryInvariants.validate(ws)
	asserts.assert_true(inv_result["is_valid"], "Machinery invariants must hold on broken pump: %s" % str(inv_result.get("errors", [])))

func test_repair_fails_without_replacement_parts(asserts: TestAsserts) -> void:
	asserts.set_current_test("MachineryMaintenance: Repair Blocked When Spare Parts Absent")
	var engine: SimulationEngine = SimulationEngine.new(101)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	engine.register_system(MaintenanceSystem.new())
	
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	var pump: WaterPump = registry.get_entity(machine_ids[0]) as WaterPump
	var bearing: MachineComponent = pump.get_component(WaterPump.COMP_BEARING)
	
	# Break bearing manually (100% wear)
	bearing.wear_percent = 100.0
	pump.update_state()
	asserts.assert_eq(pump.state, Machine.STATE_BROKEN, "Pump should be in STATE_BROKEN")
	asserts.assert_almost_eq(pump.current_water_throughput_lpm, 0.0, 0.001, "Throughput should be 0.0 L/min")
	
	# Place a technician directly inside the pump station room and working
	var tech: Person = null
	for pid in registry.get_entities_by_type("person"):
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "maintenance_technician":
			tech = p
			break
			
	asserts.assert_not_null(tech, "Maintenance technician must exist")
	tech.current_location_id = pump.room_id
	tech.current_activity = Person.ACTIVITY_WORKING
	
	# Verify room inventory is empty of bearings
	var pump_room: Room = registry.get_entity(pump.room_id) as Room
	if pump_room.inventory_id > 0:
		var inv: Inventory = registry.get_entity(pump_room.inventory_id) as Inventory
		inv.remove_resource(ResourceRegistry.RES_MACHINED_BEARING, 99999.0)
		
	# Step 144 ticks (1 full day of technician presence without parts)
	engine.step(144)
	
	# Invariant: Bearing remains broken at 100% wear, throughput remains 0.0 L/min
	asserts.assert_almost_eq(bearing.wear_percent, 100.0, 0.001, "Bearing must remain at 100% wear without replacement parts")
	asserts.assert_eq(pump.state, Machine.STATE_BROKEN, "Pump must remain BROKEN without replacement parts")
	asserts.assert_almost_eq(pump.current_water_throughput_lpm, 0.0, 0.0001, "Throughput must remain 0.0 L/min")

func test_successful_repair_with_technician_and_bearing(asserts: TestAsserts) -> void:
	asserts.set_current_test("MachineryMaintenance: Successful Repair With Technician & Machined Bearing")
	var engine: SimulationEngine = SimulationEngine.new(202)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	engine.register_system(MaintenanceSystem.new())
	
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	var pump: WaterPump = registry.get_entity(machine_ids[0]) as WaterPump
	var bearing: MachineComponent = pump.get_component(WaterPump.COMP_BEARING)
	
	# Break bearing (100% wear)
	bearing.wear_percent = 100.0
	pump.update_state()
	asserts.assert_eq(pump.state, Machine.STATE_BROKEN, "Pump should be in STATE_BROKEN")
	
	# Position technician in room
	var tech: Person = null
	for pid in registry.get_entities_by_type("person"):
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "maintenance_technician":
			tech = p
			break
			
	asserts.assert_not_null(tech, "Maintenance technician must exist")
	tech.current_location_id = pump.room_id
	tech.current_activity = Person.ACTIVITY_WORKING
	
	# Supply 2 machined bearings (1.0 kg) into the pump station inventory
	var pump_room: Room = registry.get_entity(pump.room_id) as Room
	var inv: Inventory = null
	if pump_room.inventory_id > 0:
		inv = registry.get_entity(pump_room.inventory_id) as Inventory
	else:
		inv = Inventory.new(0, pump_room.id, 500000.0)
		inv.id = registry.register_entity("inventory", inv)
		pump_room.inventory_id = inv.id
		
	inv.add_resource(ResourceRegistry.RES_MACHINED_BEARING, 2.0)
	asserts.assert_almost_eq(inv.get_quantity(ResourceRegistry.RES_MACHINED_BEARING), 2.0, 0.001, "Pump station should have 2 bearings")
	
	# Step 12 ticks (bearing requires exactly 12 repair ticks)
	engine.step(12)
	
	# Assert repair completion:
	# 1. Bearing wear reset to 0.0%
	asserts.assert_almost_eq(bearing.wear_percent, 0.0, 0.001, "Bearing wear must be restored to 0.0%")
	# 2. Pump state restored to NOMINAL
	asserts.assert_eq(pump.state, Machine.STATE_NOMINAL, "Pump state must be restored to NOMINAL")
	# 3. Throughput restored to full 500.0 L/min
	asserts.assert_almost_eq(pump.current_water_throughput_lpm, 500.0, 0.01, "Pump throughput must be restored to 500.0 L/min")
	# 4. Exactly 1 bearing consumed from inventory (leaving 1.0 unit)
	asserts.assert_almost_eq(inv.get_quantity(ResourceRegistry.RES_MACHINED_BEARING), 1.0, 0.001, "Exactly 1 machined bearing must be consumed during repair")

func test_closed_loop_economy_and_maintenance(asserts: TestAsserts) -> void:
	asserts.set_current_test("MachineryMaintenance: Closed Loop Economy & Infrastructure Service")
	var engine: SimulationEngine = SimulationEngine.new(303)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	engine.register_system(DailyLifeSystem.new())
	engine.register_system(ProductionSystem.new())
	engine.register_system(MaintenanceSystem.new())
	
	var initial_mass: float = EconomyInvariants.compute_total_system_mass_kg(ws)
	
	# Simulate 7 days (1,008 ticks) with people working, producing, and machines operating
	var start_usec: int = Time.get_ticks_usec()
	engine.step(1008)
	var duration_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	
	var mach_val: Dictionary = MachineryInvariants.validate(ws)
	var econ_val: Dictionary = EconomyInvariants.validate(ws, initial_mass)
	
	print("[BENCHMARK] Simulated 7 days (1,008 ticks) DailyLife + Production + Maintenance in %.2f ms" % duration_ms)
	print("  - Total Machines: %d (Nominal: %d, Degraded: %d, Fault: %d, Broken: %d)" % [
		mach_val["stats"]["total_machines"],
		mach_val["stats"]["nominal_count"],
		mach_val["stats"]["degraded_count"],
		mach_val["stats"]["fault_count"],
		mach_val["stats"]["broken_count"]
	])
	print("  - Total Water Pump Throughput: %.2f L/min" % mach_val["stats"]["total_throughput_lpm"])
	print("  - System Mass Invariant Error: %.6f kg" % absf(econ_val["stats"]["total_system_mass_kg"] - initial_mass))
	
	asserts.assert_true(mach_val["is_valid"], "Machinery invariants must hold: %s" % str(mach_val.get("errors", [])))
	asserts.assert_true(econ_val["is_valid"], "Economy mass conservation must hold: %s" % str(econ_val.get("errors", [])))
	asserts.assert_gt(mach_val["stats"]["total_throughput_lpm"], 0.0, "Total water pump throughput should be positive")
	asserts.assert_lt(duration_ms, 800.0, "7-day integrated simulation should execute within budget (< 800 ms)")

func test_machinery_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("MachineryMaintenance: 14-Day Integrated Simulation Replay Determinism")
	
	# Run A (Seed 42)
	var engine_a: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_a.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_a.get_world_state())
	engine_a.register_system(DailyLifeSystem.new())
	engine_a.register_system(ProductionSystem.new())
	engine_a.register_system(MaintenanceSystem.new())
	
	# Run B (Seed 42)
	var engine_b: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_b.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_b.get_world_state())
	engine_b.register_system(DailyLifeSystem.new())
	engine_b.register_system(ProductionSystem.new())
	engine_b.register_system(MaintenanceSystem.new())
	
	# Run C (Seed 999)
	var engine_c: SimulationEngine = SimulationEngine.new(999)
	PopulationGenerator.generate_population(engine_c.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_c.get_world_state())
	engine_c.register_system(DailyLifeSystem.new())
	engine_c.register_system(ProductionSystem.new())
	engine_c.register_system(MaintenanceSystem.new())
	
	var checkpoints: Array[int] = [144, 1008, 2016] # Day 1, Day 7, Day 14
	var current: int = 0
	
	for target in checkpoints:
		var step_count: int = target - current
		engine_a.step(step_count)
		engine_b.step(step_count)
		engine_c.step(step_count)
		current = target
		
		var cs_a: int = engine_a.get_state_checksum()
		var cs_b: int = engine_b.get_state_checksum()
		var cs_c: int = engine_c.get_state_checksum()
		
		asserts.assert_eq(cs_a, cs_b, "Checksum match at tick %d between Run A and Run B" % target)
		asserts.assert_ne(cs_a, cs_c, "Checksum divergence at tick %d between Run A and Run C" % target)
