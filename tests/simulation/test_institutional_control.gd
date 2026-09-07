# tests/simulation/test_institutional_control.gd
class_name TestInstitutionalControl
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_policy_enactment_and_friction(asserts)
	test_executive_order_crisis_intervention(asserts)
	test_security_quarantine_transit_override(asserts)
	test_institution_invariants_and_category_exclusivity(asserts)
	test_institutional_replay_determinism(asserts)

func test_policy_enactment_and_friction(asserts: TestAsserts) -> void:
	asserts.set_current_test("InstitutionalControl: Policy Enactment & Physical Friction")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
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
	
	# Initial 3 days under baseline standard policies
	engine.step(3 * SimClock.TICKS_PER_DAY) # 432 ticks
	
	var initial_inv_val: Dictionary = InstitutionInvariants.validate(ws)
	asserts.assert_true(initial_inv_val["is_valid"], "Initial institutional invariants must hold")
	asserts.assert_almost_eq(inst_sys.social_tension_index, 0.0, 0.01, "Baseline social tension should be near zero")
	
	var baseline_ration_rate: float = inst_sys.get_water_ration_rate()
	asserts.assert_almost_eq(baseline_ration_rate, 2.5 / 144.0, 0.0001, "Baseline water ration should be 2.5 L/day")
	
	# Enact 10-Hour Extended Shifts and Strict Rationing (1.8 L/day)
	inst_sys.enact_policy(Policy.POLICY_WORK_EXTENDED_10H, ws)
	inst_sys.enact_policy(Policy.POLICY_RATION_STRICT, ws)
	
	asserts.assert_eq(inst_sys.get_shift_work_hours(), 10, "Active shift work hours should now be 10")
	asserts.assert_almost_eq(inst_sys.get_water_ration_rate(), 1.8 / 144.0, 0.0001, "Active water ration should now be 1.8 L/day")
	
	# Simulate 4 days under extended shifts and strict rationing
	var start_seam: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))
	var water_start: float = water_sys.total_consumed_liters
	
	engine.step(4 * SimClock.TICKS_PER_DAY) # 576 ticks
	
	var post_seam: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))
	var mined_kg: float = start_seam - post_seam
	var water_consumed_4days: float = water_sys.total_consumed_liters - water_start
	
	# Verify physical consequences
	asserts.assert_gt(mined_kg, 0.0, "Mining should be active under extended shifts")
	asserts.assert_gt(inst_sys.social_tension_index, 0.1, "Strict rationing and overtime must authentically raise social tension")
	
	# Strict water consumption for 100 people across 4 days @ 1.8 L/day = ~720 L (compared to 1000 L baseline)
	asserts.assert_lt(water_consumed_4days, 850.0, "Strict rationing must reduce total water consumption below standard baseline")
	
	# Verify mass conservation
	var econ_val: Dictionary = EconomyInvariants.validate(ws)
	asserts.assert_true(econ_val["is_valid"], "Economy mass conservation must hold under policy modulation")
	
	var final_inst_val: Dictionary = InstitutionInvariants.validate(ws)
	asserts.assert_true(final_inst_val["is_valid"], "Final institutional invariants must hold")

func test_executive_order_crisis_intervention(asserts: TestAsserts) -> void:
	asserts.set_current_test("InstitutionalControl: Executive Order Crisis Intervention")
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
	
	# Find water pump machine
	var registry: EntityRegistry = ws.entity_registry
	var pump_id: int = 0
	for mid in registry.get_entities_by_type("machine"):
		var m: Machine = registry.get_entity(mid) as Machine
		if m is WaterPump:
			pump_id = mid
			break
			
	asserts.assert_gt(pump_id, 0, "Water pump must exist in simulation")
	var pump: WaterPump = registry.get_entity(pump_id) as WaterPump
	
	# Issue 2-day Machine Overdrive on pump and Emergency Water Cuts
	var overdrive_order: ExecutiveOrder = ExecutiveOrder.create_order(ExecutiveOrder.ORDER_MACHINE_OVERDRIVE, str(pump_id), 288) # 2 days = 288 ticks
	var water_cut_order: ExecutiveOrder = ExecutiveOrder.create_order(ExecutiveOrder.ORDER_WATER_CUTS, "", 288)
	
	inst_sys.issue_order(overdrive_order, ws)
	inst_sys.issue_order(water_cut_order, ws)
	
	asserts.assert_eq(inst_sys.active_orders.size(), 2, "Two executive orders must be active")
	asserts.assert_almost_eq(inst_sys.get_machine_throughput_multiplier(pump_id), 1.25, 0.01, "Pump throughput should be boosted to 125%")
	asserts.assert_almost_eq(inst_sys.get_machine_wear_rate_multiplier(pump_id), 2.50, 0.01, "Machine wear rate should be 2.5x normal")
	
	var initial_bearing_wear: float = pump.components["bearing_roller_50mm"].wear_percent
	
	# Step 1 day (144 ticks)
	engine.step(144)
	
	var mid_bearing_wear: float = pump.components["bearing_roller_50mm"].wear_percent
	var wear_delta: float = mid_bearing_wear - initial_bearing_wear
	
	# Under 2.5x wear rate, 1 day (24 operating hours) produces 24 * 0.05 * 2.5 = 3.0% wear
	asserts.assert_gt(wear_delta, 2.0, "Machine overdrive must produce accelerated physical wear on components")
	asserts.assert_gt(overdrive_order.consequences["extra_wear_acc"], 0.0, "Consequences must track accumulated wear")
	asserts.assert_gt(inst_sys.social_tension_index, 0.05, "Water cuts order must raise social tension")
	
	# Step remaining 144 ticks until order auto-expires (total 288 ticks)
	engine.step(144)
	
	asserts.assert_true(overdrive_order.is_expired(), "Overdrive order must expire after 288 ticks")
	asserts.assert_true(water_cut_order.is_expired(), "Water cuts order must expire after 288 ticks")
	
	# Step 1 additional tick so InstitutionSystem flushes expired orders
	engine.step(1)
	asserts.assert_eq(inst_sys.active_orders.size(), 0, "Expired orders must be automatically cleaned up")
	asserts.assert_almost_eq(inst_sys.get_machine_throughput_multiplier(pump_id), 1.0, 0.01, "Pump throughput multiplier must return to 1.0")

func test_security_quarantine_transit_override(asserts: TestAsserts) -> void:
	asserts.set_current_test("InstitutionalControl: Security Clearance & Quarantine Transit Controls")
	var engine: SimulationEngine = SimulationEngine.new(202)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(daily_life)
	
	var registry: EntityRegistry = ws.entity_registry
	var all_pids: Array[int] = registry.get_entities_by_type("person")
	asserts.assert_gt(all_pids.size(), 2, "At least 2 persons must exist")
	
	var civilian: Person = registry.get_entity(all_pids[0]) as Person
	civilian.security_clearance = 0
	
	var officer: Person = registry.get_entity(all_pids[1]) as Person
	officer.security_clearance = 2
	
	asserts.assert_not_null(civilian, "Civilian with clearance 0 must exist")
	asserts.assert_not_null(officer, "Officer with clearance >= 2 must exist")
	
	# Under standard open policy, sector transit is allowed for all
	asserts.assert_true(inst_sys.is_sector_travel_allowed(civilian.security_clearance, 1, 2), "Open policy allows civilian inter-sector travel")
	asserts.assert_true(inst_sys.is_sector_travel_allowed(officer.security_clearance, 1, 2), "Open policy allows officer inter-sector travel")
	
	# Enact Quarantine Policy (requires clearance >= 2)
	inst_sys.enact_policy(Policy.POLICY_SECURITY_QUARANTINE, ws)
	
	asserts.assert_false(inst_sys.is_sector_travel_allowed(civilian.security_clearance, 1, 2), "Quarantine must block civilian inter-sector travel")
	asserts.assert_true(inst_sys.is_sector_travel_allowed(officer.security_clearance, 1, 2), "Quarantine allows clearance >= 2 officer inter-sector travel")
	
	# Intra-sector travel is always allowed
	asserts.assert_true(inst_sys.is_sector_travel_allowed(civilian.security_clearance, 1, 1), "Intra-sector travel remains allowed")
	
	# Revoke Quarantine Policy (restores open policy)
	inst_sys.revoke_policy(Policy.CATEGORY_SECURITY, ws)
	asserts.assert_true(inst_sys.is_sector_travel_allowed(civilian.security_clearance, 1, 2), "Revoking quarantine restores open civilian transit")

func test_institution_invariants_and_category_exclusivity(asserts: TestAsserts) -> void:
	asserts.set_current_test("InstitutionalControl: Category Exclusivity & Invariant Checks")
	var engine: SimulationEngine = SimulationEngine.new(303)
	var ws: WorldState = engine.get_world_state()
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	engine.register_system(inst_sys)
	
	# Enacting different policies in same category replaces the active one
	inst_sys.enact_policy(Policy.POLICY_RATION_STANDARD, ws)
	asserts.assert_eq(inst_sys.get_active_policy(Policy.CATEGORY_RATIONING).id, Policy.POLICY_RATION_STANDARD)
	
	inst_sys.enact_policy(Policy.POLICY_RATION_EMERGENCY, ws)
	asserts.assert_eq(inst_sys.get_active_policy(Policy.CATEGORY_RATIONING).id, Policy.POLICY_RATION_EMERGENCY)
	asserts.assert_false(inst_sys.available_policies[Policy.POLICY_RATION_STANDARD].is_active, "Previous policy should be deactivated")
	
	var val: Dictionary = InstitutionInvariants.validate(ws)
	asserts.assert_true(val["is_valid"], "Valid institutional state passes invariants")
	
	# Test invariant detection of corruption: tension > 100
	inst_sys.social_tension_index = 120.0
	var bad_val: Dictionary = InstitutionInvariants.validate(ws)
	asserts.assert_false(bad_val["is_valid"], "Invariants must reject out-of-bounds social tension")
	inst_sys.social_tension_index = 0.0

func test_institutional_replay_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("InstitutionalControl: Deterministic Replay Verification")
	
	var checksum_run_a: int = _run_deterministic_institution_sim(42)
	var checksum_run_b: int = _run_deterministic_institution_sim(42)
	
	asserts.assert_eq(checksum_run_a, checksum_run_b, "Two runs with identical seeds, policies and orders must produce identical checksums")

func _run_deterministic_institution_sim(seed_val: int) -> int:
	var engine: SimulationEngine = SimulationEngine.new(seed_val)
	var ws: WorldState = engine.get_world_state()
	
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
	
	# Step 1 day baseline
	engine.step(144)
	
	# Enact 10h overtime policy
	inst_sys.enact_policy(Policy.POLICY_WORK_EXTENDED_10H, ws)
	engine.step(144)
	
	# Issue temporary 1-day emergency water cuts
	var order: ExecutiveOrder = ExecutiveOrder.create_order(ExecutiveOrder.ORDER_WATER_CUTS, "", 144)
	inst_sys.issue_order(order, ws)
	engine.step(288) # 2 days
	
	return engine.get_state_checksum()
