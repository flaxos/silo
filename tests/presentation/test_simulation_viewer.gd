# tests/presentation/test_simulation_viewer.gd
class_name TestSimulationViewer
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_read_model_accuracy(asserts)
	test_read_model_side_effect_freedom(asserts)
	test_dashboard_rendering_and_telemetry(asserts)
	test_command_adapter_routing(asserts)
	test_simulation_viewer_decoupling_determinism(asserts)

func test_read_model_accuracy(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimulationViewer: Read Model Accuracy & State Projection")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var maint_sys: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(60000.0, 100000.0)
	
	engine.register_system(inst_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
	
	# Step 1 day (144 ticks)
	engine.step(144)
	
	# Query population summary
	var pop: Dictionary = SimulationReader.get_population_summary(ws)
	asserts.assert_eq(pop["total_recorded"], 100, "Total population recorded should be 100")
	asserts.assert_eq(pop["living_count"], 100, "Living count should be 100")
	asserts.assert_eq(pop["deceased_count"], 0, "Deceased count should be 0")
	asserts.assert_gt(pop["employed_count"], 40, "Working adults should be employed")
	asserts.assert_almost_eq(pop["avg_hydration"], 100.0, 1.0, "Average hydration should remain high")
	
	# Query individual person profile
	var person_profile: Dictionary = SimulationReader.get_person_profile(ws, 1)
	asserts.assert_eq(person_profile["id"], 1, "Person profile must have valid ID")
	asserts.assert_ne(person_profile["full_name"], "", "Person profile must have full name")
	asserts.assert_gt(person_profile["age_years"], 0, "Person profile must have positive age")
	
	# Query economy summary
	var econ: Dictionary = SimulationReader.get_economy_summary(ws)
	asserts.assert_almost_eq(econ["total_system_mass_kg"], 100000.0, 0.001, "Total mass must equal 100,000 kg")
	asserts.assert_almost_eq(econ["mass_balance_error_kg"], 0.0, 0.0001, "Mass error must be zero")
	
	# Query machinery summary
	var mach: Dictionary = SimulationReader.get_machinery_summary(ws)
	asserts.assert_gt(mach["total_machines"], 0, "Machines must be detected")
	asserts.assert_eq(mach["states"]["BROKEN"], 0, "Zero machines broken after 1 day")
	
	# Query utilities summary
	var util: Dictionary = SimulationReader.get_utilities_summary(ws)
	asserts.assert_gt(util["total_pumped_liters"], 0.0, "Pumping should be recorded")
	asserts.assert_gt(util["total_consumed_liters"], 0.0, "Consumption should be recorded")

func test_read_model_side_effect_freedom(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimulationViewer: Zero Side-Effects on Authoritative State")
	var engine: SimulationEngine = SimulationEngine.new(101)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var maint_sys: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
	
	engine.register_system(inst_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
	
	engine.step(72) # 12 hours
	
	var val: Dictionary = ViewerInvariants.validate_side_effect_freedom(ws)
	asserts.assert_true(val["is_valid"], "Read models and viewer must produce zero authoritative state mutations")
	asserts.assert_eq(val["checksum_before"], val["checksum_after"], "Checksum before and after inspection must match exactly")

func test_dashboard_rendering_and_telemetry(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimulationViewer: ASCII Telemetry Dashboard Rendering")
	var engine: SimulationEngine = SimulationEngine.new(202)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var maint_sys: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
	
	engine.register_system(inst_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
	
	engine.step(144) # 1 day
	
	var header_str: String = SimulationViewer.render_header(ws)
	var pop_str: String = SimulationViewer.render_population_dashboard(ws)
	var econ_str: String = SimulationViewer.render_economy_dashboard(ws)
	var mach_str: String = SimulationViewer.render_machinery_dashboard(ws)
	var util_str: String = SimulationViewer.render_utilities_dashboard(ws)
	var inst_str: String = SimulationViewer.render_institutions_dashboard(ws)
	var full_report: String = SimulationViewer.render_full_status_report(ws)
	
	asserts.assert_true(header_str.contains("PROJECT SILO"), "Header must contain project title")
	asserts.assert_true(pop_str.contains("POPULATION & DEMOGRAPHICS"), "Pop dashboard must render")
	asserts.assert_true(econ_str.contains("MATERIAL ECONOMY"), "Economy dashboard must render")
	asserts.assert_true(mach_str.contains("MACHINERY & INFRASTRUCTURE"), "Machinery dashboard must render")
	asserts.assert_true(util_str.contains("UTILITIES & WATER SUPPLY"), "Utilities dashboard must render")
	asserts.assert_true(inst_str.contains("INSTITUTIONAL GOVERNANCE"), "Institutions dashboard must render")
	asserts.assert_gt(full_report.length(), 500, "Full status report must format rich multi-line telemetry")

func test_command_adapter_routing(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimulationViewer: CommandAdapter Decoupled Action Routing")
	var engine: SimulationEngine = SimulationEngine.new(303)
	var ws: WorldState = engine.get_world_state()
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	engine.register_system(inst_sys)
	
	# Enact policy via CommandAdapter
	var enacted: bool = CommandAdapter.enact_policy(ws, Policy.POLICY_WORK_EXTENDED_10H)
	asserts.assert_true(enacted, "CommandAdapter must succeed in enacting policy")
	asserts.assert_eq(inst_sys.get_shift_work_hours(), 10, "10-hour shift policy must be active")
	
	# Dispatch executive order via CommandAdapter
	var order: ExecutiveOrder = ExecutiveOrder.create_order(ExecutiveOrder.ORDER_WATER_CUTS, "", 144)
	var dispatched: bool = CommandAdapter.dispatch_order(ws, order)
	asserts.assert_true(dispatched, "CommandAdapter must succeed in dispatching executive order")
	asserts.assert_eq(inst_sys.active_orders.size(), 1, "Order must be active in InstitutionSystem")
	
	# Cancel order via CommandAdapter
	var cancelled: bool = CommandAdapter.cancel_order(ws, order.id)
	asserts.assert_true(cancelled, "CommandAdapter must succeed in cancelling executive order")
	asserts.assert_eq(inst_sys.active_orders.size(), 0, "Order must be removed from active orders")

func test_simulation_viewer_decoupling_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimulationViewer: Headless Decoupling Determinism Verification")
	
	# Run A: Simulation running headlessly with NO viewer inspections
	var engine_a: SimulationEngine = SimulationEngine.new(42)
	var ws_a: WorldState = engine_a.get_world_state()
	_setup_test_habitat(engine_a, ws_a)
	
	for day in range(3):
		engine_a.step(SimClock.TICKS_PER_DAY)
		
	var checksum_a: int = engine_a.get_state_checksum()
	
	# Run B: Simulation running with active SimulationReader and SimulationViewer rendered every tick
	var engine_b: SimulationEngine = SimulationEngine.new(42)
	var ws_b: WorldState = engine_b.get_world_state()
	_setup_test_habitat(engine_b, ws_b)
	
	for day in range(3):
		for t in range(SimClock.TICKS_PER_DAY):
			engine_b.step(1)
			# Actively query and render projections on every tick
			var _snap: Dictionary = SimulationReader.get_full_telemetry_snapshot(ws_b)
			var _rep: String = SimulationViewer.render_full_status_report(ws_b)
			
	var checksum_b: int = engine_b.get_state_checksum()
	
	asserts.assert_eq(checksum_a, checksum_b, "Running with active UI viewers must yield 100% identical state checksums to headless execution")

func _setup_test_habitat(engine: SimulationEngine, ws: WorldState) -> void:
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var maint_sys: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(100000.0, 100000.0)
	
	engine.register_system(inst_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
