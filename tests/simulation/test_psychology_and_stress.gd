# tests/simulation/test_psychology_and_stress.gd
class_name TestPsychologyAndStress
extends RefCounted

## Automated Headless Test Suite for Sprint 19: Psychology, Stress & Adaptation.

const PsychologySystem = preload("res://src/sim/population/psychology_system.gd")
const PsychologyInvariants = preload("res://src/sim/population/psychology_invariants.gd")
const PsychologyReader = preload("res://src/presentation/psychology_reader.gd")

const DailyLifeSystem = preload("res://src/sim/population/daily_life_system.gd")
const ProductionSystem = preload("res://src/sim/economy/production_system.gd")
const Machine = preload("res://src/sim/machinery/machine.gd")
const MachineComponent = preload("res://src/sim/machinery/machine_component.gd")

func run_all(asserts: TestAsserts) -> void:
	test_uat_a_cohort_divergence_experience_driven(asserts)
	test_uat_b_fatigue_induced_workplace_machine_wear(asserts)
	test_uat_c_absenteeism_halts_physical_production(asserts)
	test_uat_d_recreation_and_restoration(asserts)
	test_psychology_invariants_and_determinism(asserts)
	test_1200_resident_scale_performance(asserts)

func test_uat_a_cohort_divergence_experience_driven(asserts: TestAsserts) -> void:
	asserts.set_current_test("Psychology UAT-A: Lived-Experience Cohort Divergence & Absenteeism")
	var eng: SimulationEngine = SimulationEngine.new(601)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var psych_sys: PsychologySystem = PsychologySystem.new()
	eng.register_system(psych_sys)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")

	# Cohort A (Overburdened & Deprived)
	var distressed_workers: Array[Person] = []
	# Cohort B (Well-supported & Rested)
	var supported_workers: Array[Person] = []

	for i in range(10):
		var p_a: Person = registry.get_entity(pids[i]) as Person
		p_a.hydration_percent = 20.0 # Chronic thirst
		p_a.economic_satisfaction = 0.10
		p_a.class_resentment = 0.85
		p_a.fatigue = 75.0
		p_a.current_activity = Person.ACTIVITY_WORKING
		distressed_workers.append(p_a)

		var p_b: Person = registry.get_entity(pids[i + 10]) as Person
		p_b.hydration_percent = 100.0
		p_b.economic_satisfaction = 0.90
		p_b.class_resentment = 0.05
		p_b.fatigue = 15.0
		p_b.current_activity = Person.ACTIVITY_RECREATING
		supported_workers.append(p_b)

	# Simulate 24 ticks
	eng.step(24)

	var avg_distressed_stress: float = 0.0
	var avg_distressed_morale: float = 0.0
	var distressed_absent: int = 0
	for p in distressed_workers:
		avg_distressed_stress += p.stress
		avg_distressed_morale += p.morale
		if p.absent_from_work:
			distressed_absent += 1
	avg_distressed_stress /= distressed_workers.size()
	avg_distressed_morale /= distressed_workers.size()

	var avg_supported_stress: float = 0.0
	var avg_supported_morale: float = 0.0
	var supported_absent: int = 0
	for p in supported_workers:
		avg_supported_stress += p.stress
		avg_supported_morale += p.morale
		if p.absent_from_work:
			supported_absent += 1
	avg_supported_stress /= supported_workers.size()
	avg_supported_morale /= supported_workers.size()

	asserts.assert_gt(avg_distressed_stress, avg_supported_stress + 30.0, "Distressed cohort has drastically higher stress (>30 pt difference)")
	asserts.assert_lt(avg_distressed_morale, avg_supported_morale - 30.0, "Distressed cohort has drastically lower morale (>30 pt difference)")
	asserts.assert_gt(distressed_absent, 0, "Distressed cohort developed emergent absenteeism")
	asserts.assert_eq(supported_absent, 0, "Supported cohort had zero absenteeism")

func test_uat_b_fatigue_induced_workplace_machine_wear(asserts: TestAsserts) -> void:
	asserts.set_current_test("Psychology UAT-B: Operator Fatigue Inflicts Accelerated Machine Wear")
	var eng: SimulationEngine = SimulationEngine.new(602)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var psych_sys: PsychologySystem = PsychologySystem.new()
	eng.register_system(psych_sys)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var worker: Person = null
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.workplace_room_id > 0:
			worker = p
			break

	asserts.assert_not_null(worker, "Must find worker")

	# Create machine in worker's room
	var machine: Machine = Machine.new(0, worker.workplace_room_id, "lathe")
	var comp: MachineComponent = MachineComponent.new("chuck_gear", "Chuck Gear", 0.0, 1.0, "bearing", 1.0, 10)
	comp.wear_percent = 10.0
	machine.add_component(comp)
	machine.id = registry.register_entity("machine", machine)

	# Case 1: Normal worker (low fatigue) -> zero extra wear
	worker.fatigue = 20.0
	worker.current_activity = Person.ACTIVITY_WORKING
	eng.step(10)
	asserts.assert_eq(comp.wear_percent, 10.0, "Rested worker inflicts zero mistake wear")

	# Case 2: Exhausted worker (fatigue = 80.0) -> inflicts mistake wear
	worker.fatigue = 80.0
	worker.current_activity = Person.ACTIVITY_WORKING
	eng.step(10)
	asserts.assert_gt(comp.wear_percent, 10.0, "Exhausted worker made mistakes, causing physical component wear")

func test_uat_c_absenteeism_halts_physical_production(asserts: TestAsserts) -> void:
	asserts.set_current_test("Psychology UAT-C: Absenteeism Halts Physical Production")
	var eng: SimulationEngine = SimulationEngine.new(603)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var psych_sys: PsychologySystem = PsychologySystem.new()
	eng.register_system(daily_life)
	eng.register_system(psych_sys)
	eng.register_system(prod_sys)

	# Find miner
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var miner: Person = null
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "miner":
			miner = p
			break

	asserts.assert_not_null(miner, "Must find working miner")

	# Step 2 days to confirm normal baseline production
	eng.step(288)
	var seam_initial: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))
	asserts.assert_lt(seam_initial, ProductionSystem.INITIAL_SEAM_ORE_KG, "Normal work mined ore")

	# All miners suffer acute burnout / exhaustion -> triggers absenteeism
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "miner":
			p.fatigue = 95.0
			p.stress = 95.0
			p.burnout = 90.0
			p.absent_from_work = true

	# Step another day (144 ticks)
	var seam_at_absent_start: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))
	eng.step(144)
	var seam_after_absent: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))

	# Extraction halted completely because miners stayed home sick
	asserts.assert_eq(seam_at_absent_start, seam_after_absent, "Zero ore extracted while miners are absent due to exhaustion")
	asserts.assert_eq(miner.current_location_id, miner.home_room_id, "Absent miner stayed resting in home room")

func test_uat_d_recreation_and_restoration(asserts: TestAsserts) -> void:
	asserts.set_current_test("Psychology UAT-D: Recreation & Sleep Restoration")
	var eng: SimulationEngine = SimulationEngine.new(604)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)

	var psych_sys: PsychologySystem = PsychologySystem.new()
	eng.register_system(psych_sys)

	var registry: EntityRegistry = ws.entity_registry
	var p: Person = registry.get_entity(registry.get_entities_by_type("person")[0]) as Person
	p.stress = 80.0
	p.fatigue = 80.0
	p.morale = 25.0
	p.current_activity = Person.ACTIVITY_RECREATING

	eng.step(24)

	asserts.assert_lt(p.stress, 80.0, "Stress decreased during recreation")
	asserts.assert_lt(p.fatigue, 80.0, "Fatigue decreased during recreation")
	asserts.assert_gt(p.morale, 25.0, "Morale recovered during recreation")

func test_psychology_invariants_and_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Psychology: Invariants & Deterministic Replay")

	# Run A
	var eng_a: SimulationEngine = SimulationEngine.new(555)
	var ws_a: WorldState = eng_a.get_world_state()
	PopulationGenerator.generate_population(ws_a, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_a)

	var psych_a: PsychologySystem = PsychologySystem.new()
	var daily_a: DailyLifeSystem = DailyLifeSystem.new()
	eng_a.register_system(daily_a)
	eng_a.register_system(psych_a)

	eng_a.step(50)

	var val_a: Dictionary = PsychologyInvariants.validate_all(ws_a)
	asserts.assert_true(val_a["is_valid"], "Run A psychology invariants must be valid: %s" % str(val_a.get("errors", [])))
	var chk_a: int = ws_a.get_state_checksum()

	# Run B
	var eng_b: SimulationEngine = SimulationEngine.new(555)
	var ws_b: WorldState = eng_b.get_world_state()
	PopulationGenerator.generate_population(ws_b, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_b)

	var psych_b: PsychologySystem = PsychologySystem.new()
	var daily_b: DailyLifeSystem = DailyLifeSystem.new()
	eng_b.register_system(daily_b)
	eng_b.register_system(psych_b)

	eng_b.step(50)

	var val_b: Dictionary = PsychologyInvariants.validate_all(ws_b)
	asserts.assert_true(val_b["is_valid"], "Run B psychology invariants must be valid: %s" % str(val_b.get("errors", [])))
	var chk_b: int = ws_b.get_state_checksum()

	asserts.assert_eq(chk_a, chk_b, "Simulation produces identical checksum (Run A == Run B)")

func test_1200_resident_scale_performance(asserts: TestAsserts) -> void:
	asserts.set_current_test("Psychology: 1200 Resident Scale Performance Benchmark")
	var eng: SimulationEngine = SimulationEngine.new(999)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 1200)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var psych_sys: PsychologySystem = PsychologySystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	eng.register_system(daily_life)
	eng.register_system(psych_sys)

	var start_usec: int = Time.get_ticks_usec()

	# Step 24 ticks (4 hours)
	eng.step(24)

	var elapsed_ms: float = (Time.get_ticks_usec() - start_usec) / 1000.0
	var avg_ms_per_tick: float = elapsed_ms / 24.0

	asserts.assert_lt(avg_ms_per_tick, 60.0, "Average tick time for 1,200 residents under 60ms budget (actual: %.2f ms/tick)" % avg_ms_per_tick)
	print("  [BENCHMARK] Simulated 1200 residents with PsychologySystem across 24 ticks in %.2f ms (%.2f ms/tick)" % [elapsed_ms, avg_ms_per_tick])

	var val: Dictionary = PsychologyInvariants.validate_all(ws)
	asserts.assert_true(val["is_valid"], "Psychology invariants valid at 1200 scale: %s" % str(val.get("errors", [])))
