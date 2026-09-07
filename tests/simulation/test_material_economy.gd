# tests/simulation/test_material_economy.gd
class_name TestMaterialEconomy
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_14_day_pipeline_and_mass_conservation(asserts)
	test_upstream_worker_starvation_dynamics(asserts)
	test_material_economy_determinism(asserts)

func test_14_day_pipeline_and_mass_conservation(asserts: TestAsserts) -> void:
	asserts.set_current_test("MaterialEconomy: 14-Day Production Pipeline & Conservation of Mass")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	engine.register_system(DailyLifeSystem.new())
	engine.register_system(ProductionSystem.new())
	
	var initial_mass: float = EconomyInvariants.compute_total_system_mass_kg(ws)
	asserts.assert_gt(initial_mass, 50000.0, "Initial mass should include geological seam")
	
	var total_ticks: int = 2016 # 14 days (14 * 144)
	var start_usec: int = Time.get_ticks_usec()
	
	# Step through in daily blocks to verify continuous mass conservation
	for day in range(14):
		engine.step(144)
		var val: Dictionary = EconomyInvariants.validate(ws, initial_mass)
		if not val["is_valid"]:
			asserts.assert_true(false, "Mass conservation violated on Day %d: %s" % [day + 1, str(val["errors"])])
			return
			
	var duration_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var final_val: Dictionary = EconomyInvariants.validate(ws, initial_mass)
	var stats: Dictionary = final_val["stats"]
	var res_totals: Dictionary = stats["resource_totals"]
	
	print("[BENCHMARK] Simulated 14 days (2,016 ticks) production in %.2f ms" % duration_ms)
	print("  - Mined Ore Consumed: %.1f kg" % (ProductionSystem.INITIAL_SEAM_ORE_KG - stats["geological_seam_ore_kg"]))
	print("  - Finished Bearings Produced: %.1f units (%.1f kg)" % [
		res_totals.get(ResourceRegistry.RES_MACHINED_BEARING, 0.0),
		res_totals.get(ResourceRegistry.RES_MACHINED_BEARING, 0.0) * ResourceRegistry.get_unit_mass(ResourceRegistry.RES_MACHINED_BEARING)
	])
	print("  - Total System Mass: %.3f kg (Invariant Error: %.6f kg)" % [
		stats["total_system_mass_kg"],
		absf(stats["total_system_mass_kg"] - initial_mass)
	])
	
	asserts.assert_true(final_val["is_valid"], "14-day production world must strictly conserve mass")
	asserts.assert_gt(res_totals.get(ResourceRegistry.RES_MACHINED_BEARING, 0.0), 50.0, "Finished bearings must be produced")
	asserts.assert_gt(res_totals.get(ResourceRegistry.RES_SLAG_TAILINGS, 0.0), 50.0, "Slag tailings must be produced")
	asserts.assert_gt(res_totals.get(ResourceRegistry.RES_METAL_SWARF, 0.0), 20.0, "Machining swarf must be produced")
	asserts.assert_lt(duration_ms, 800.0, "14-day economy simulation should execute within budget (< 800 ms)")

func test_upstream_worker_starvation_dynamics(asserts: TestAsserts) -> void:
	asserts.set_current_test("MaterialEconomy: Upstream Worker Removal Causes Downstream Starvation")
	var engine: SimulationEngine = SimulationEngine.new(101)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	engine.register_system(DailyLifeSystem.new())
	engine.register_system(ProductionSystem.new())
	
	var initial_mass: float = EconomyInvariants.compute_total_system_mass_kg(ws)
	
	# Run 3 days (432 ticks) normally to build pipeline flow
	engine.step(432)
	var mid_stats: Dictionary = EconomyInvariants.validate(ws, initial_mass)["stats"]
	var seam_at_day_3: float = mid_stats["geological_seam_ore_kg"]
	
	# Disruption: Reassign ALL miners to retired
	var registry: EntityRegistry = ws.entity_registry
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	var miners_reassigned: int = 0
	
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "miner":
			p.occupation_id = "retired"
			p.shift_id = Occupation.SHIFT_OFF
			p.workplace_room_id = 0
			miners_reassigned += 1
			
	asserts.assert_gt(miners_reassigned, 5, "Should have reassigned > 5 miners")
	
	# Run next 7 days (1,008 ticks) with zero miners
	engine.step(1008)
	var post_stats: Dictionary = EconomyInvariants.validate(ws, initial_mass)["stats"]
	var seam_at_day_10: float = post_stats["geological_seam_ore_kg"]
	
	# Invariant: Seam extraction halted completely because 0 miners were present
	asserts.assert_eq(seam_at_day_10, seam_at_day_3, "Ore extraction must freeze when miners are removed")
	
	# Check mine inventory: raw iron ore must be completely depleted by downstream processing
	var mine_room: Room = null
	for rid in registry.get_entities_by_type("room"):
		var r: Room = registry.get_entity(rid) as Room
		if r and r.room_type == Room.TYPE_DEEP_MINE:
			mine_room = r
			break
			
	asserts.assert_not_null(mine_room, "Mine room should exist")
	if mine_room and mine_room.inventory_id > 0:
		var mine_inv: Inventory = registry.get_entity(mine_room.inventory_id) as Inventory
		asserts.assert_almost_eq(mine_inv.get_quantity(ResourceRegistry.RES_IRON_ORE), 0.0, 0.001, "Mine raw ore inventory should be depleted")
		asserts.assert_almost_eq(mine_inv.get_quantity(ResourceRegistry.RES_PROCESSED_ORE), 0.0, 0.001, "Mine processed ore should be transferred downstream")

func test_material_economy_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("MaterialEconomy: 14-Day Production Replay Determinism")
	
	# Run A
	var engine_a: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_a.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_a.get_world_state())
	engine_a.register_system(DailyLifeSystem.new())
	engine_a.register_system(ProductionSystem.new())
	
	# Run B (Identical seed 42)
	var engine_b: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_b.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_b.get_world_state())
	engine_b.register_system(DailyLifeSystem.new())
	engine_b.register_system(ProductionSystem.new())
	
	# Run C (Different seed 999)
	var engine_c: SimulationEngine = SimulationEngine.new(999)
	PopulationGenerator.generate_population(engine_c.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_c.get_world_state())
	engine_c.register_system(DailyLifeSystem.new())
	engine_c.register_system(ProductionSystem.new())
	
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
