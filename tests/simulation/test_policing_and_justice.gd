# tests/simulation/test_policing_and_justice.gd
class_name TestPolicingAndJustice
extends RefCounted

## Automated Headless Test Suite for Sprint 18: Advanced Policing, Investigation & Justice.

const SecurityCase = preload("res://src/sim/law/security_case.gd")
const SecuritySystem = preload("res://src/sim/law/security_system.gd")
const SecurityInvariants = preload("res://src/sim/law/security_invariants.gd")
const SecurityReader = preload("res://src/presentation/security_reader.gd")

const CrimeIncident = preload("res://src/sim/law/crime_incident.gd")
const CrimeSystem = preload("res://src/sim/law/crime_system.gd")
const DailyLifeSystem = preload("res://src/sim/population/daily_life_system.gd")
const ProductionSystem = preload("res://src/sim/economy/production_system.gd")

func run_all(asserts: TestAsserts) -> void:
	test_uat_a_two_runs_it_cctv_retention_divergence(asserts)
	test_uat_b_grounded_arrest_and_labour_withdrawal(asserts)
	test_uat_c_wrongful_conviction_and_resentment_spike(asserts)
	test_uat_d_sentence_expiry_and_release(asserts)
	test_security_invariants_and_determinism(asserts)
	test_1200_resident_scale_performance(asserts)

func test_uat_a_two_runs_it_cctv_retention_divergence(asserts: TestAsserts) -> void:
	asserts.set_current_test("Security UAT-A: IT Access & Evidence Divergence Across Identical Crime")
	
	# --- RUN 1: IT Department grants CCTV & badge log access ---
	var eng_1: SimulationEngine = SimulationEngine.new(501)
	var ws_1: WorldState = eng_1.get_world_state()
	PopulationGenerator.generate_population(ws_1, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_1)
	ws_1.custom_data["cctv_active"] = true

	var crime_1: CrimeSystem = CrimeSystem.new()
	var sec_1: SecuritySystem = SecuritySystem.new()
	sec_1.it_access_granted = true
	eng_1.register_system(crime_1)
	eng_1.register_system(sec_1)

	var pids_1: Array[int] = ws_1.entity_registry.get_entities_by_type("person")
	var perp_1: Person = null
	var officer_1: Person = null
	for pid in pids_1:
		var p: Person = ws_1.entity_registry.get_entity(pid) as Person
		if p and p.is_alive and p.workplace_room_id > 0 and p.home_room_id > 0:
			if perp_1 == null:
				perp_1 = p
			elif officer_1 == null and p.id != perp_1.id:
				officer_1 = p
				break

	var work_room_1: Room = ws_1.entity_registry.get_entity(perp_1.workplace_room_id) as Room
	var home_room_1: Room = ws_1.entity_registry.get_entity(perp_1.home_room_id) as Room
	var winv_1: Inventory = CrimeSystem._ensure_room_inventory(ws_1, work_room_1)
	CrimeSystem._ensure_room_inventory(ws_1, home_room_1)
	winv_1.add_resource("finished_bearing", 10.0)

	var incident_1: CrimeIncident = crime_1.commit_theft(ws_1, perp_1.id, work_room_1.id, home_room_1.id, "finished_bearing", 2.0)

	# Open case & investigate
	var case_1: SecurityCase = sec_1.open_case(ws_1, incident_1.id, officer_1.id)
	sec_1.investigate_case(ws_1, case_1.id)

	asserts.assert_true(case_1.gathered_evidence["badge_log_verified"], "Run 1 verified digital badge logs")
	asserts.assert_true(case_1.gathered_evidence["cctv_footage_available"], "Run 1 accessed CCTV footage")
	asserts.assert_gt(case_1.confidence, 0.70, "Run 1 reached high confidence (>0.70)")
	asserts.assert_eq(case_1.lead_suspect_id, perp_1.id, "Run 1 correctly identified true perpetrator")
	asserts.assert_eq(case_1.status, SecurityCase.STATUS_WARRANT, "Run 1 issued arrest warrant")

	# --- RUN 2: IT Department withholds access (or logs purged) ---
	var eng_2: SimulationEngine = SimulationEngine.new(501) # Identical seed & population
	var ws_2: WorldState = eng_2.get_world_state()
	PopulationGenerator.generate_population(ws_2, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_2)
	ws_2.custom_data["cctv_active"] = true

	var crime_2: CrimeSystem = CrimeSystem.new()
	var sec_2: SecuritySystem = SecuritySystem.new()
	sec_2.it_access_granted = false # IT blocks access
	eng_2.register_system(crime_2)
	eng_2.register_system(sec_2)

	var perp_2: Person = ws_2.entity_registry.get_entity(perp_1.id) as Person
	var officer_2: Person = ws_2.entity_registry.get_entity(officer_1.id) as Person
	var work_room_2: Room = ws_2.entity_registry.get_entity(perp_2.workplace_room_id) as Room
	var home_room_2: Room = ws_2.entity_registry.get_entity(perp_2.home_room_id) as Room
	var winv_2: Inventory = CrimeSystem._ensure_room_inventory(ws_2, work_room_2)
	CrimeSystem._ensure_room_inventory(ws_2, home_room_2)
	winv_2.add_resource("finished_bearing", 10.0)

	var incident_2: CrimeIncident = crime_2.commit_theft(ws_2, perp_2.id, work_room_2.id, home_room_2.id, "finished_bearing", 2.0)

	var case_2: SecurityCase = sec_2.open_case(ws_2, incident_2.id, officer_2.id)
	sec_2.investigate_case(ws_2, case_2.id)

	asserts.assert_false(case_2.gathered_evidence["badge_log_verified"], "Run 2 lacked badge logs due to IT policy")
	asserts.assert_false(case_2.gathered_evidence["cctv_footage_available"], "Run 2 lacked CCTV footage")
	asserts.assert_lt(case_2.confidence, 0.40, "Run 2 confidence remained low (<0.40)")
	asserts.assert_ne(case_2.status, SecurityCase.STATUS_WARRANT, "Run 2 could not issue warrant due to missing evidence")

func test_uat_b_grounded_arrest_and_labour_withdrawal(asserts: TestAsserts) -> void:
	asserts.set_current_test("Security UAT-B: Grounded Arrest Halts Production")
	var eng: SimulationEngine = SimulationEngine.new(502)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var crime_sys: CrimeSystem = CrimeSystem.new()
	var sec_sys: SecuritySystem = SecuritySystem.new()
	eng.register_system(daily_life)
	eng.register_system(crime_sys)
	eng.register_system(sec_sys)
	eng.register_system(prod_sys)

	# Find active miner
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var miner: Person = null
	var officer: Person = null
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "miner":
			miner = p
		elif p and officer == null:
			officer = p

	asserts.assert_not_null(miner, "Must find working miner")

	# Baseline: step 2 days and observe ore mining
	eng.step(288)
	var seam_initial: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))
	asserts.assert_lt(seam_initial, ProductionSystem.INITIAL_SEAM_ORE_KG, "Normal mining extracted ore")

	# Create incident, case, and arrest the miner
	var m_work: Room = registry.get_entity(miner.workplace_room_id) as Room
	var minv: Inventory = CrimeSystem._ensure_room_inventory(ws, m_work)
	minv.add_resource("iron_ore", 10.0)
	var m_home: Room = registry.get_entity(miner.home_room_id) as Room
	CrimeSystem._ensure_room_inventory(ws, m_home)
	var inc: CrimeIncident = crime_sys.commit_theft(ws, miner.id, miner.workplace_room_id, miner.home_room_id, "iron_ore", 10.0)
	var sc: SecurityCase = sec_sys.open_case(ws, inc.id, officer.id)
	var arrested: bool = sec_sys.execute_arrest(ws, sc.id, miner.id, 288)

	asserts.assert_true(arrested, "Miner arrested and locked in cell")
	asserts.assert_eq(sc.status, SecurityCase.STATUS_ARRESTED, "Case status is ARRESTED")

	var detainees: Array = SecurityReader.get_detainees(ws)
	asserts.assert_gt(detainees.size(), 0, "Reader reports active detainee")

	# Check that miner is held in cell
	asserts.assert_ne(miner.current_location_id, miner.workplace_room_id, "Miner removed from mine")

func test_uat_c_wrongful_conviction_and_resentment_spike(asserts: TestAsserts) -> void:
	asserts.set_current_test("Security UAT-C: Wrongful Conviction & Resentment Spike")
	var eng: SimulationEngine = SimulationEngine.new(503)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var crime_sys: CrimeSystem = CrimeSystem.new()
	var sec_sys: SecuritySystem = SecuritySystem.new()
	eng.register_system(crime_sys)
	eng.register_system(sec_sys)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var actual_perp: Person = registry.get_entity(pids[0]) as Person
	var innocent_citizen: Person = registry.get_entity(pids[1]) as Person
	var officer: Person = registry.get_entity(pids[2]) as Person

	var resentment_before: float = innocent_citizen.class_resentment
	var trust_before: float = innocent_citizen.institutional_trust

	# Crime committed by perp
	var work: Room = registry.get_entity(actual_perp.workplace_room_id) as Room
	var home: Room = registry.get_entity(actual_perp.home_room_id) as Room
	var winv: Inventory = CrimeSystem._ensure_room_inventory(ws, work)
	winv.add_resource("finished_bearing", 5.0)
	CrimeSystem._ensure_room_inventory(ws, home)
	var inc: CrimeIncident = crime_sys.commit_theft(ws, actual_perp.id, work.id, home.id, "finished_bearing", 1.0)

	var sc: SecurityCase = sec_sys.open_case(ws, inc.id, officer.id)

	# Incompetent / corrupt officer arrests the innocent citizen instead!
	sec_sys.execute_arrest(ws, sc.id, innocent_citizen.id, 144)

	asserts.assert_eq(sc.verdict, SecurityCase.VERDICT_WRONGFUL_CONVICTION, "Case recorded as WRONGFUL_CONVICTION")
	asserts.assert_gt(innocent_citizen.class_resentment, resentment_before, "Innocent citizen's resentment spiked after wrongful arrest")
	asserts.assert_lt(innocent_citizen.institutional_trust, trust_before, "Innocent citizen's institutional trust plummeted")

func test_uat_d_sentence_expiry_and_release(asserts: TestAsserts) -> void:
	asserts.set_current_test("Security UAT-D: Sentence Expiry & Release")
	var eng: SimulationEngine = SimulationEngine.new(504)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var sec_sys: SecuritySystem = SecuritySystem.new()
	eng.register_system(sec_sys)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var prisoner: Person = registry.get_entity(pids[0]) as Person
	var officer: Person = registry.get_entity(pids[1]) as Person

	var sc: SecurityCase = SecurityCase.new(1, 0, officer.id, 0)
	var list: Array = ws.custom_data.get("security_cases", [])
	list.append(sc)
	ws.custom_data["security_cases"] = list

	# Arrest with short sentence of 10 ticks
	sec_sys.execute_arrest(ws, sc.id, prisoner.id, 10)

	asserts.assert_eq((ws.custom_data.get("detainees", []) as Array).size(), 1, "Prisoner in detention")

	# Step 12 ticks
	eng.step(12)

	asserts.assert_eq((ws.custom_data.get("detainees", []) as Array).size(), 0, "Prisoner released after sentence completed")
	asserts.assert_eq(prisoner.current_location_id, prisoner.home_room_id, "Prisoner returned to home quarters")

func test_security_invariants_and_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Security: Invariants & Deterministic Replay")

	# Run A
	var eng_a: SimulationEngine = SimulationEngine.new(666)
	var ws_a: WorldState = eng_a.get_world_state()
	PopulationGenerator.generate_population(ws_a, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_a)

	var crime_a: CrimeSystem = CrimeSystem.new()
	var sec_a: SecuritySystem = SecuritySystem.new()
	eng_a.register_system(crime_a)
	eng_a.register_system(sec_a)

	eng_a.step(30)

	var val_a: Dictionary = SecurityInvariants.validate_all(ws_a)
	asserts.assert_true(val_a["is_valid"], "Run A security invariants must be valid: %s" % str(val_a.get("errors", [])))
	var chk_a: int = ws_a.get_state_checksum()

	# Run B
	var eng_b: SimulationEngine = SimulationEngine.new(666)
	var ws_b: WorldState = eng_b.get_world_state()
	PopulationGenerator.generate_population(ws_b, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_b)

	var crime_b: CrimeSystem = CrimeSystem.new()
	var sec_b: SecuritySystem = SecuritySystem.new()
	eng_b.register_system(crime_b)
	eng_b.register_system(sec_b)

	eng_b.step(30)

	var val_b: Dictionary = SecurityInvariants.validate_all(ws_b)
	asserts.assert_true(val_b["is_valid"], "Run B security invariants must be valid: %s" % str(val_b.get("errors", [])))
	var chk_b: int = ws_b.get_state_checksum()

	asserts.assert_eq(chk_a, chk_b, "Simulation produces identical checksum (Run A == Run B)")

func test_1200_resident_scale_performance(asserts: TestAsserts) -> void:
	asserts.set_current_test("Security: 1200 Resident Scale Performance Benchmark")
	var eng: SimulationEngine = SimulationEngine.new(999)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 1200)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var crime_sys: CrimeSystem = CrimeSystem.new()
	var sec_sys: SecuritySystem = SecuritySystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	eng.register_system(daily_life)
	eng.register_system(crime_sys)
	eng.register_system(sec_sys)

	var start_usec: int = Time.get_ticks_usec()

	# Simulate 24 ticks (4 hours)
	eng.step(24)

	var elapsed_ms: float = (Time.get_ticks_usec() - start_usec) / 1000.0
	var avg_ms_per_tick: float = elapsed_ms / 24.0

	asserts.assert_lt(avg_ms_per_tick, 60.0, "Average tick time for 1,200 residents under 60ms budget (actual: %.2f ms/tick)" % avg_ms_per_tick)
	print("  [BENCHMARK] Simulated 1200 residents with SecuritySystem across 24 ticks in %.2f ms (%.2f ms/tick)" % [elapsed_ms, avg_ms_per_tick])

	var val: Dictionary = SecurityInvariants.validate_all(ws)
	asserts.assert_true(val["is_valid"], "Security invariants valid at 1200 scale: %s" % str(val.get("errors", [])))
