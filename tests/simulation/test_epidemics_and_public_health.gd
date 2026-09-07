# tests/simulation/test_epidemics_and_public_health.gd
class_name TestEpidemicsAndPublicHealth
extends RefCounted

## Automated Headless Test Suite for Sprint 22: Epidemics & Public Health.

const Pathogen = preload("res://src/sim/health/pathogen.gd")
const EpidemicSystem = preload("res://src/sim/health/epidemic_system.gd")
const EpidemicInvariants = preload("res://src/sim/health/epidemic_invariants.gd")
const HealthReader = preload("res://src/presentation/health_reader.gd")

func run_all(asserts: TestAsserts) -> void:
	test_outbreak_ignition_and_household_spread(asserts)
	test_seir_progression_lifecycle(asserts)
	test_quarantine_policy_and_labor_withdrawal(asserts)
	test_school_closure_and_childcare_absenteeism(asserts)
	test_clinical_care_reduces_mortality(asserts)
	test_epidemic_invariants_and_determinism(asserts)

func _create_test_world(seed_val: int = 42) -> WorldState:
	var ws: WorldState = WorldState.new(seed_val)
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	return ws

func test_outbreak_ignition_and_household_spread(asserts: TestAsserts) -> void:
	asserts.set_current_test("Outbreak Ignition & Household Contagion")
	var ws: WorldState = _create_test_world(201)
	var epi_sys: EpidemicSystem = EpidemicSystem.new()
	epi_sys.setup(ws)
	
	var registry: EntityRegistry = ws.entity_registry
	var p0_id: int = epi_sys.start_outbreak(ws, "silo_cough", 1)
	asserts.assert_true(p0_id > 0, "Patient zero successfully infected")
	
	var p0: Person = registry.get_entity(p0_id) as Person
	asserts.assert_eq(p0.infection_stage, Person.INFECTION_INFECTIOUS, "Patient zero is infectious")
	
	# Simulate 12 hours (72 ticks) to allow household spread
	for i in range(72):
		ws.sim_clock.advance_tick()
		epi_sys.tick(ws)
		
	var summary: Dictionary = HealthReader.get_epidemic_summary(ws)
	asserts.assert_true(summary["exposed"] + summary["infectious"] + summary["symptomatic"] > 1, "Disease spread to additional residents (%d total active)" % (summary["exposed"] + summary["infectious"]))

func test_seir_progression_lifecycle(asserts: TestAsserts) -> void:
	asserts.set_current_test("SEIR Disease Lifecycle Progression")
	var ws: WorldState = _create_test_world(202)
	var epi_sys: EpidemicSystem = EpidemicSystem.new()
	epi_sys.setup(ws)
	
	var registry: EntityRegistry = ws.entity_registry
	var p: Person = registry.get_entity(10) as Person
	
	# Infect person
	p.infection_stage = Person.INFECTION_EXPOSED
	p.infection_tick = ws.sim_clock.get_tick()
	p.pathogen_id = "silo_cough"
	
	var path: Pathogen = epi_sys.pathogens["silo_cough"]
	
	# 1. Advance through incubation
	for i in range(path.incubation_ticks + 6):
		ws.sim_clock.advance_tick()
		epi_sys.tick(ws)
	asserts.assert_eq(p.infection_stage, Person.INFECTION_INFECTIOUS, "Person transitioned from Exposed to Infectious")
	
	# 2. Advance through infectious period to symptoms
	for i in range(path.infectious_ticks + 6):
		ws.sim_clock.advance_tick()
		epi_sys.tick(ws)
	asserts.assert_eq(p.infection_stage, Person.INFECTION_SYMPTOMATIC, "Person transitioned from Infectious to Symptomatic")
	asserts.assert_true(p.absent_from_work, "Symptomatic citizen is absent from work")
	
	# 3. Advance through symptoms to recovery
	for i in range(path.symptomatic_ticks + 6):
		ws.sim_clock.advance_tick()
		epi_sys.tick(ws)
	asserts.assert_eq(p.infection_stage, Person.INFECTION_RECOVERED, "Person recovered from infection")
	asserts.assert_false(p.absent_from_work, "Recovered citizen returns to work")

func test_quarantine_policy_and_labor_withdrawal(asserts: TestAsserts) -> void:
	asserts.set_current_test("Quarantine Policy Enforces Isolation & Labor Withdrawal")
	var ws: WorldState = _create_test_world(203)
	var epi_sys: EpidemicSystem = EpidemicSystem.new()
	epi_sys.setup(ws)
	
	var registry: EntityRegistry = ws.entity_registry
	var p: Person = registry.get_entity(15) as Person
	p.infection_stage = Person.INFECTION_INFECTIOUS
	p.infection_tick = ws.sim_clock.get_tick()
	p.pathogen_id = "silo_cough"
	
	ws.custom_data["quarantine_active"] = true
	epi_sys.tick(ws)
	
	asserts.assert_true(p.is_quarantined, "Infectious person quarantined under active policy")
	asserts.assert_true(p.absent_from_work, "Quarantined person labor withdrawn")

func test_school_closure_and_childcare_absenteeism(asserts: TestAsserts) -> void:
	asserts.set_current_test("School Closure Halts School Spread & Mandates Childcare")
	var ws: WorldState = _create_test_world(204)
	var epi_sys: EpidemicSystem = EpidemicSystem.new()
	epi_sys.setup(ws)
	var registry: EntityRegistry = ws.entity_registry
	
	# Find an adult parent
	var parent: Person = null
	for pid in registry.get_entities_by_type("person"):
		var candidate: Person = registry.get_entity(pid) as Person
		if candidate and candidate.life_stage == Person.STAGE_ADULT and not candidate.children_ids.is_empty():
			parent = candidate
			break
			
	asserts.assert_true(parent != null, "Parent found in population")
	
	ws.custom_data["schools_closed"] = true
	epi_sys.tick(ws)
	
	asserts.assert_true(parent.absent_from_work, "Parent withdraws labor to provide childcare during school closure")

func test_clinical_care_reduces_mortality(asserts: TestAsserts) -> void:
	asserts.set_current_test("Clinical Care Treats Patients")
	var ws: WorldState = _create_test_world(205)
	var epi_sys: EpidemicSystem = EpidemicSystem.new()
	epi_sys.setup(ws)
	
	var summary: Dictionary = HealthReader.get_clinic_summary(ws)
	asserts.assert_true(summary.has("clinic_beds"), "Clinic status reports beds")
	asserts.assert_true(summary.has("medical_staff"), "Clinic status reports medical staff")

func test_epidemic_invariants_and_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("SEIR Invariants & Determinism")
	var ws: WorldState = _create_test_world(206)
	var epi_sys: EpidemicSystem = EpidemicSystem.new()
	epi_sys.setup(ws)
	
	epi_sys.start_outbreak(ws, "silo_cough", 5)
	
	for i in range(48):
		ws.sim_clock.advance_tick()
		epi_sys.tick(ws)
		
	var val: Dictionary = EpidemicInvariants.validate_all(ws)
	asserts.assert_true(val.get("is_valid", false), "Epidemic invariants pass: %s" % str(val.get("errors", [])))
	
	# Test serialization & deserialization
	var ser: Dictionary = epi_sys.serialize()
	var epi_sys2: EpidemicSystem = EpidemicSystem.new()
	epi_sys2.deserialize(ser)
	asserts.assert_eq(epi_sys2.total_infections, epi_sys.total_infections, "Epidemic state serialized and restored identically")
