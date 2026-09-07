# tests/simulation/test_dependency_loop.gd
class_name TestDependencyLoop
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_30_day_closed_loop_steady_state(asserts)
	test_worker_strike_causes_closed_loop_collapse(asserts)
	test_closed_loop_replay_determinism(asserts)

func test_30_day_closed_loop_steady_state(asserts: TestAsserts) -> void:
	asserts.set_current_test("DependencyLoop: 30-Day Steady-State Closed Feedback Loop")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var production: ProductionSystem = ProductionSystem.new()
	var maintenance: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
	
	engine.register_system(daily_life)
	engine.register_system(production)
	engine.register_system(maintenance)
	engine.register_system(water_sys)
	
	var initial_mass: float = EconomyInvariants.compute_total_system_mass_kg(ws)
	var initial_reservoir: float = 50000.0
	
	var start_usec: int = Time.get_ticks_usec()
	var total_ticks: int = 4320 # 30 days (30 * 144)
	
	# Step through in 5-day increments to check invariants continuously
	for day_block in range(6):
		engine.step(720) # 5 days
		
		var w_val: Dictionary = WaterInvariants.validate(ws, initial_reservoir, water_sys)
		if not w_val["is_valid"]:
			asserts.assert_true(false, "Water invariants failed at day %d: %s" % [(day_block + 1) * 5, str(w_val["errors"])])
			return
			
		var e_val: Dictionary = EconomyInvariants.validate(ws, initial_mass)
		if not e_val["is_valid"]:
			asserts.assert_true(false, "Economy mass conservation failed at day %d: %s" % [(day_block + 1) * 5, str(e_val["errors"])])
			return
			
		var m_val: Dictionary = MachineryInvariants.validate(ws)
		if not m_val["is_valid"]:
			asserts.assert_true(false, "Machinery invariants failed at day %d: %s" % [(day_block + 1) * 5, str(m_val["errors"])])
			return
			
	var duration_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var final_water: Dictionary = WaterInvariants.validate(ws, initial_reservoir, water_sys)
	var final_econ: Dictionary = EconomyInvariants.validate(ws, initial_mass)
	var final_mach: Dictionary = MachineryInvariants.validate(ws)
	
	var stats: Dictionary = final_water["stats"]
	
	print("[BENCHMARK] Simulated 30 days (4,320 ticks) full closed loop in %.2f ms" % duration_ms)
	print("  - Water Reservoir Current: %.1f L (Pumped: %.1f L, Consumed: %.1f L)" % [
		stats["reservoir_current_liters"],
		stats["total_pumped_liters"],
		stats["total_consumed_liters"]
	])
	print("  - Living Population: %d / %d (Avg Hydration: %.1f%%, Dehydrated: %d)" % [
		stats["alive_count"],
		stats["total_people"],
		stats["avg_hydration_percent"],
		stats["dehydrated_count"]
	])
	print("  - Economy Total Mass Error: %.6f kg" % absf(final_econ["stats"]["total_system_mass_kg"] - initial_mass))
	
	# Assertions for 30-day steady state
	asserts.assert_true(final_water["is_valid"], "30-day water invariants must hold")
	asserts.assert_true(final_econ["is_valid"], "30-day mass conservation must hold")
	asserts.assert_true(final_mach["is_valid"], "30-day machinery invariants must hold")
	asserts.assert_eq(stats["alive_count"], 100, "All 100 residents must survive 30-day steady state")
	asserts.assert_eq(stats["dehydrated_count"], 0, "Zero residents should be dehydrated in steady state")
	asserts.assert_gt(stats["avg_hydration_percent"], 95.0, "Average hydration should remain above 95%")
	asserts.assert_gt(stats["reservoir_current_liters"], 10000.0, "Reservoir should maintain buffer")
	asserts.assert_lt(duration_ms, 2500.0, "30-day simulation should execute within budget (< 2500 ms)")

func test_worker_strike_causes_closed_loop_collapse(asserts: TestAsserts) -> void:
	asserts.set_current_test("DependencyLoop: Worker Strike Triggers Organic Systemic Cascade")
	var engine: SimulationEngine = SimulationEngine.new(101)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var initial_reservoir: float = 1000.0 # Lean reservoir buffer to trigger dehydration after pump halts
	var water_sys: WaterSystem = WaterSystem.new(initial_reservoir, 100000.0)
	
	engine.register_system(DailyLifeSystem.new())
	engine.register_system(ProductionSystem.new())
	engine.register_system(MaintenanceSystem.new())
	engine.register_system(water_sys)
	
	var initial_mass: float = EconomyInvariants.compute_total_system_mass_kg(ws)
	var registry: EntityRegistry = ws.entity_registry
	
	# Step 1: Run 2 days (288 ticks) in normal operation
	engine.step(288)
	var pump_id: int = registry.get_entities_by_type("machine")[0]
	var pump: WaterPump = registry.get_entity(pump_id) as WaterPump
	asserts.assert_gt(pump.current_water_throughput_lpm, 0.0, "Pump should be running initially")
	
	# Step 2: Disruption — Reassign all miners to retired (strike / absence)
	var miner_count: int = 0
	for pid in registry.get_entities_by_type("person"):
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "miner":
			p.occupation_id = "retired"
			p.shift_id = Occupation.SHIFT_OFF
			p.workplace_room_id = 0
			miner_count += 1
			
	asserts.assert_gt(miner_count, 0, "Miners should be reassigned")
	
	# Clear out any residual bearings in shop/pump inventories to simulate exhausted stock
	for rid in registry.get_entities_by_type("room"):
		var r: Room = registry.get_entity(rid) as Room
		if r and r.inventory_id > 0:
			var inv: Inventory = registry.get_entity(r.inventory_id) as Inventory
			if inv:
				inv.remove_resource(ResourceRegistry.RES_MACHINED_BEARING, 99999.0)
				inv.remove_resource(ResourceRegistry.RES_METAL_STOCK, 99999.0)
				inv.remove_resource(ResourceRegistry.RES_PROCESSED_ORE, 99999.0)
				inv.remove_resource(ResourceRegistry.RES_IRON_ORE, 99999.0)
				
	# Step 3: Break water pump bearing (simulating natural wearout with 0 spare bearings available)
	var bearing: MachineComponent = pump.get_component(WaterPump.COMP_BEARING)
	bearing.wear_percent = 100.0
	pump.update_state()
	asserts.assert_eq(pump.state, Machine.STATE_BROKEN, "Pump must be BROKEN")
	asserts.assert_almost_eq(pump.current_water_throughput_lpm, 0.0, 0.001, "Throughput must drop to 0.0 L/min")
	
	# Set reservoir to 500 L (2 days of water for 100 residents) to observe the drought cascade over 5 days
	var post_break_res: float = 500.0
	water_sys.reservoir_current_liters = post_break_res
	water_sys.total_pumped_liters = 0.0
	water_sys.total_consumed_liters = 0.0
	
	# Step 4: Step simulation for 5 days (720 ticks) without pump inflow
	engine.step(720)
	
	# Physical Causality Assertions:
	# 1. Pump is STILL broken because no bearings could be fabricated without mined ore
	asserts.assert_eq(pump.state, Machine.STATE_BROKEN, "Pump must remain broken without replacement bearings")
	asserts.assert_almost_eq(pump.current_water_throughput_lpm, 0.0, 0.001, "Pump throughput must remain 0.0 L/min")
	
	# 2. Water reservoir drained completely to 0.0 L
	asserts.assert_almost_eq(water_sys.reservoir_current_liters, 0.0, 0.01, "Water reservoir must drain to 0.0 L")
	
	# 3. Population suffers severe dehydration without water
	var w_val: Dictionary = WaterInvariants.validate(ws, post_break_res, water_sys)
	var stats: Dictionary = w_val["stats"]
	
	print("[CRISIS TELEMETRY] Post-strike status after 5 days without water:")
	print("  - Reservoir: %.2f L" % stats["reservoir_current_liters"])
	print("  - Average Hydration: %.2f%%" % stats["avg_hydration_percent"])
	print("  - Severely Dehydrated Citizens: %d / %d" % [stats["dehydrated_count"], stats["total_people"]])
	
	asserts.assert_gt(stats["dehydrated_count"], 50, "Majority of population must be dehydrated")
	asserts.assert_lt(stats["avg_hydration_percent"], 30.0, "Average hydration must plummet below 30%")

func test_closed_loop_replay_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("DependencyLoop: 30-Day Multi-System Replay Determinism")
	
	# Run A (Seed 42)
	var engine_a: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_a.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_a.get_world_state())
	engine_a.register_system(DailyLifeSystem.new())
	engine_a.register_system(ProductionSystem.new())
	engine_a.register_system(MaintenanceSystem.new())
	engine_a.register_system(WaterSystem.new(50000.0, 100000.0))
	
	# Run B (Seed 42)
	var engine_b: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_b.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_b.get_world_state())
	engine_b.register_system(DailyLifeSystem.new())
	engine_b.register_system(ProductionSystem.new())
	engine_b.register_system(MaintenanceSystem.new())
	engine_b.register_system(WaterSystem.new(50000.0, 100000.0))
	
	# Run C (Seed 999)
	var engine_c: SimulationEngine = SimulationEngine.new(999)
	PopulationGenerator.generate_population(engine_c.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_c.get_world_state())
	engine_c.register_system(DailyLifeSystem.new())
	engine_c.register_system(ProductionSystem.new())
	engine_c.register_system(MaintenanceSystem.new())
	engine_c.register_system(WaterSystem.new(50000.0, 100000.0))
	
	var checkpoints: Array[int] = [144, 1440, 2880, 4320] # Day 1, Day 10, Day 20, Day 30
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
		
		asserts.assert_eq(cs_a, cs_b, "Checksum match at tick %d (Day %d) between Run A and Run B" % [target, target / 144])
		asserts.assert_ne(cs_a, cs_c, "Checksum divergence at tick %d between Run A and Run C" % target)
