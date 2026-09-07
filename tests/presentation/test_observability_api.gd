# tests/presentation/test_observability_api.gd
class_name TestObservabilityAPI
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_expanded_simulation_reader_queries(asserts)
	test_8_step_causal_chain_integrity(asserts)
	test_22_system_wiring_matrix(asserts)
	test_observer_invisibility_checksum_proof(asserts)
	test_static_frontend_files_integrity(asserts)

func test_expanded_simulation_reader_queries(asserts: TestAsserts) -> void:
	asserts.set_current_test("ObservabilityAPI: Expanded SimulationReader Endpoints")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var maint_sys: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
	var inc_sys: IncidentSystem = IncidentSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
	engine.register_system(inc_sys)
	
	engine.step(144) # 1 day
	
	# 1. Test People List with pagination and search
	var people_res: Dictionary = SimulationReader.get_people_list(ws, 1, 20, "", "all", "all", "all")
	asserts.assert_eq(people_res["total_count"], 100, "Total count in people list must equal 100")
	asserts.assert_eq(people_res["people"].size(), 20, "Page slice size must equal 20")
	
	var first_person: Dictionary = people_res["people"][0]
	var p_profile: Dictionary = SimulationReader.get_person_profile(ws, first_person["id"])
	asserts.assert_eq(p_profile["id"], first_person["id"], "Person profile ID matches")
	asserts.assert_true(p_profile.has("life_stage"), "Person profile has life stage")
	asserts.assert_true(p_profile.has("current_location_id"), "Person profile has current location")
	
	# 2. Test Households List
	var households: Array[Dictionary] = SimulationReader.get_households_list(ws)
	asserts.assert_gt(households.size(), 20, "Must have households generated")
	var h1: Dictionary = households[0]
	asserts.assert_gt(h1["member_count"], 0, "Household must have members")
	asserts.assert_gt(h1["home_room_id"], 0, "Household must have assigned home room")
	
	# 3. Test Spatial Hierarchy
	var spatial: Dictionary = SimulationReader.get_locations_hierarchy(ws)
	asserts.assert_gt(spatial["total_rooms"], 0, "Spatial hierarchy must contain rooms")
	asserts.assert_true(spatial["sectors"].size() > 0, "Must have sectors mapped")
	
	# 4. Test Labour Summary
	var labour: Dictionary = SimulationReader.get_labour_summary(ws)
	asserts.assert_gt(labour["total_employed"], 30, "Labour summary tracks employed adults")
	asserts.assert_true(labour["departments"].size() > 0, "Must list assigned departments")
	
	# 5. Test Performance Metrics
	var perf: Dictionary = SimulationReader.get_performance_metrics(ws, {"ticks_stepped": 144, "ticks_per_sec": 1000.0})
	asserts.assert_eq(perf["current_tick"], 144, "Performance metrics reflect current tick")
	asserts.assert_eq(perf["entity_counts"]["person"], 100, "Performance metrics report entity counts")
	
	# 6. Test Raw Entity State
	var raw_world: Dictionary = SimulationReader.get_raw_entity_state(ws, "world", 0)
	asserts.assert_true(raw_world.has("sim_clock"), "Raw world serialization contains clock")
	var raw_person: Dictionary = SimulationReader.get_raw_entity_state(ws, "person", 1)
	asserts.assert_eq(raw_person["id"], 1, "Raw person serialization contains id")
	
	# 7. Test Factions and Social Network Queries
	var f_sum: Dictionary = SimulationReader.get_factions_summary(ws)
	asserts.assert_true(f_sum.has("factions"), "Factions summary returns factions list")
	var s_net: Dictionary = SimulationReader.get_person_social_network(ws, 1)
	asserts.assert_eq(s_net["person_id"], 1, "Social network returns queried person ID")
	asserts.assert_true(s_net.has("connections"), "Social network contains connections array")

func test_8_step_causal_chain_integrity(asserts: TestAsserts) -> void:
	asserts.set_current_test("ObservabilityAPI: 8-Step Causal Traceability")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var maint_sys: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
	var inc_sys: IncidentSystem = IncidentSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
	engine.register_system(inc_sys)
	
	engine.step(288) # 2 days
	
	var chain: Dictionary = SimulationReader.get_causal_chain(ws, 0)
	
	# Assert all 8 physical nodes exist
	asserts.assert_true(chain.has("geological_seam"), "Chain Step 1: Geological Seam exists")
	asserts.assert_true(chain.has("mining_crushing"), "Chain Step 2: Mining & Beneficiation exists")
	asserts.assert_true(chain.has("smelting_foundry"), "Chain Step 3: Smelting Foundry exists")
	asserts.assert_true(chain.has("manufacturing_machine_shop"), "Chain Step 4: Machine Shop exists")
	asserts.assert_true(chain.has("required_part"), "Chain Step 5: Required Spare Part exists")
	asserts.assert_true(chain.has("component"), "Chain Step 6: Installed Component Wear exists")
	asserts.assert_true(chain.has("machine"), "Chain Step 7: Machine Operating Status exists")
	asserts.assert_true(chain.has("utility_consequence"), "Chain Step 8: Utility & Hydration Consequence exists")
	
	# Verify physical consistency across chain
	asserts.assert_eq(chain["geological_seam"]["initial_reserve_kg"], 100000.0, "Initial seam starts at 100,000 kg")
	asserts.assert_almost_eq(chain["geological_seam"]["mass_conservation_error_kg"], 0.0, 0.0001, "Zero mass conservation error across chain")
	asserts.assert_gt(chain["utility_consequence"]["pump_throughput_lpm"], 0.0, "Pump throughput active")
	asserts.assert_gt(chain["utility_consequence"]["avg_hydration_percent"], 90.0, "Population hydration maintained")

func test_22_system_wiring_matrix(asserts: TestAsserts) -> void:
	asserts.set_current_test("ObservabilityAPI: Authoritative System Matrix Verification")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	var matrix: Array[Dictionary] = SimulationReader.get_wiring_matrix(ws)
	asserts.assert_eq(matrix.size(), 25, "Matrix must track all 25 authoritative simulation systems")
	
	for entry in matrix:
		asserts.assert_eq(entry["status"], "GREEN", "System %s must report GREEN status" % entry["system"])
		asserts.assert_ne(entry["source"], "", "System %s must specify source file" % entry["system"])
		asserts.assert_ne(entry["endpoint"], "", "System %s must specify API endpoint" % entry["system"])

func test_observer_invisibility_checksum_proof(asserts: TestAsserts) -> void:
	asserts.set_current_test("ObservabilityAPI: Mathematical Proof of Observer Invisibility")
	
	# Run A: authoritatively stepped 500 ticks with ZERO observer queries
	var engine_a: SimulationEngine = SimulationEngine.new(777)
	var ws_a: WorldState = engine_a.get_world_state()
	PopulationGenerator.generate_population(ws_a, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws_a)
	engine_a.register_system(InstitutionSystem.new())
	engine_a.register_system(DailyLifeSystem.new())
	engine_a.register_system(MaintenanceSystem.new())
	engine_a.register_system(ProductionSystem.new())
	engine_a.register_system(WaterSystem.new(50000.0, 100000.0))
	engine_a.register_system(IncidentSystem.new())
	
	for t in range(500):
		engine_a.step(1)
	var checksum_a: int = ws_a.get_state_checksum()
	
	# Run B: identically seeded, but subjected to 1,000+ intense read queries across all subsystems
	var engine_b: SimulationEngine = SimulationEngine.new(777)
	var ws_b: WorldState = engine_b.get_world_state()
	PopulationGenerator.generate_population(ws_b, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws_b)
	engine_b.register_system(InstitutionSystem.new())
	engine_b.register_system(DailyLifeSystem.new())
	engine_b.register_system(MaintenanceSystem.new())
	engine_b.register_system(ProductionSystem.new())
	engine_b.register_system(WaterSystem.new(50000.0, 100000.0))
	engine_b.register_system(IncidentSystem.new())
	
	for t in range(500):
		engine_b.step(1)
		# Heavy read queries on every single tick
		var _clk: Dictionary = SimulationReader.get_clock_summary(ws_b)
		var _pop: Dictionary = SimulationReader.get_population_summary(ws_b)
		var _econ: Dictionary = SimulationReader.get_economy_summary(ws_b)
		var _mach: Dictionary = SimulationReader.get_machinery_summary(ws_b)
		var _util: Dictionary = SimulationReader.get_utilities_summary(ws_b)
		var _chain: Dictionary = SimulationReader.get_causal_chain(ws_b, 0)
		var _matrix: Array[Dictionary] = SimulationReader.get_wiring_matrix(ws_b)
		
	var checksum_b: int = ws_b.get_state_checksum()
	
	asserts.assert_eq(checksum_a, checksum_b, "Checksum(Sim A without reads) must equal Checksum(Sim B with heavy reads) exactly")

func test_static_frontend_files_integrity(asserts: TestAsserts) -> void:
	asserts.set_current_test("ObservabilityAPI: Static Frontend Assets Validation")
	
	asserts.assert_true(FileAccess.file_exists("res://src/viewer/index.html"), "index.html exists")
	asserts.assert_true(FileAccess.file_exists("res://src/viewer/viewer.css"), "viewer.css exists")
	asserts.assert_true(FileAccess.file_exists("res://src/viewer/viewer.js"), "viewer.js exists")
	asserts.assert_true(FileAccess.file_exists("res://tools/observer_server.gd"), "observer_server.gd exists")
	asserts.assert_true(FileAccess.file_exists("res://tools/run_observer.sh"), "run_observer.sh exists")
	
	var html_str: String = FileAccess.get_file_as_string("res://src/viewer/index.html")
	asserts.assert_gt(html_str.length(), 500, "index.html contains substantive HTML content")
	asserts.assert_true(html_str.contains("PROJECT SILO"), "index.html contains application title")
