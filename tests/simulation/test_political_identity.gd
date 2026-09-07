# tests/simulation/test_political_identity.gd
class_name TestPoliticalIdentity
extends RefCounted

const PoliticalSystem = preload("res://src/sim/politics/political_system.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")
const OpinionMemory = preload("res://src/sim/politics/opinion_memory.gd")
const LegitimacyModel = preload("res://src/sim/politics/legitimacy_model.gd")
const PoliticalInvariants = preload("res://src/sim/politics/political_invariants.gd")

func run_all(asserts: TestAsserts) -> void:
	test_divergent_lived_experiences(asserts)
	test_causal_traceability_of_attitudes(asserts)
	test_memory_decay_over_time(asserts)
	test_invariants_and_serialization(asserts)
	test_political_simulation_replay_determinism(asserts)

func test_divergent_lived_experiences(asserts: TestAsserts) -> void:
	asserts.set_current_test("PoliticalIdentity: Divergent Lived Experiences Produce Distinct Attitudes")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var maint_sys: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
	var inc_sys: IncidentSystem = IncidentSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(pol_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
	engine.register_system(inc_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	asserts.assert_gt(pids.size(), 1, "At least two persons generated")
	var p_privileged: Person = ws.entity_registry.get_entity(pids[0]) as Person
	var p_deprived: Person = ws.entity_registry.get_entity(pids[1]) as Person
	
	asserts.assert_not_null(p_privileged, "Person 1 exists")
	asserts.assert_not_null(p_deprived, "Person 2 exists")
	
	# Simulate lived experiences
	# Privileged citizen receives promotion, upgraded housing, and crisis resolution honors
	pol_sys.record_citizen_event(
		ws,
		p_privileged.id,
		PoliticalEvent.EVENT_PROMOTION_HONOR,
		PoliticalEvent.DEPT_ADMINISTRATION,
		0.8,
		"Promoted to Senior Technical Lead with security clearance."
	)
	pol_sys.record_citizen_event(
		ws,
		p_privileged.id,
		PoliticalEvent.EVENT_HOUSING_UPGRADED,
		PoliticalEvent.DEPT_ADMINISTRATION,
		0.6,
		"Allocated spacious private residential apartment."
	)
	pol_sys.record_citizen_event(
		ws,
		p_privileged.id,
		PoliticalEvent.EVENT_CRISIS_RESOLVED,
		PoliticalEvent.DEPT_ADMINISTRATION,
		0.5,
		"Successfully resolved habitat engineering anomaly."
	)
	
	# Deprived citizen suffers industrial accident, bereavement, severe thirst, and demotion
	pol_sys.record_citizen_event(
		ws,
		p_deprived.id,
		PoliticalEvent.EVENT_INDUSTRIAL_ACCIDENT,
		PoliticalEvent.DEPT_ENGINEERING,
		-0.7,
		"Injured in preventable mine shaft collapse."
	)
	pol_sys.record_citizen_event(
		ws,
		p_deprived.id,
		PoliticalEvent.EVENT_FAMILY_BEREAVEMENT,
		PoliticalEvent.DEPT_ADMINISTRATION,
		-0.8,
		"Lost immediate family member in habitat outage."
	)
	pol_sys.record_citizen_event(
		ws,
		p_deprived.id,
		PoliticalEvent.EVENT_HOUSING_OVERCROWDED,
		PoliticalEvent.DEPT_ADMINISTRATION,
		-0.6,
		"Relegated to overcrowded dormitory without assigned bed."
	)
	pol_sys.record_citizen_event(
		ws,
		p_deprived.id,
		PoliticalEvent.EVENT_DEMOTION_PENALTY,
		PoliticalEvent.DEPT_ADMINISTRATION,
		-0.7,
		"Demoted after institutional disciplinary hearing."
	)
	
	# Step 1 day
	engine.step(144)
	
	var prof_priv: Dictionary = SimulationReader.get_person_political_profile(ws, p_privileged.id)
	var prof_dep: Dictionary = SimulationReader.get_person_political_profile(ws, p_deprived.id)
	
	var trust_priv: float = prof_priv["attitudes"]["institutional_trust"]
	var trust_dep: float = prof_dep["attitudes"]["institutional_trust"]
	
	var res_priv: float = prof_priv["attitudes"]["class_resentment"]
	var res_dep: float = prof_dep["attitudes"]["class_resentment"]
	
	asserts.assert_gt(trust_priv, trust_dep, "Privileged citizen must have higher trust than deprived citizen")
	asserts.assert_gt(trust_priv, 0.70, "Privileged citizen trust > 0.70")
	asserts.assert_lt(trust_dep, 0.30, "Deprived citizen trust < 0.30")
	asserts.assert_gt(res_dep, 0.50, "Deprived citizen class resentment > 0.50")
	asserts.assert_lt(res_priv, 0.10, "Privileged citizen class resentment < 0.10")

func test_causal_traceability_of_attitudes(asserts: TestAsserts) -> void:
	asserts.set_current_test("PoliticalIdentity: Causal Traceability to Underlying Lived Memories")
	var engine: SimulationEngine = SimulationEngine.new(101)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(pol_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var target_pid: int = pids[4]
	pol_sys.record_citizen_event(
		ws,
		target_pid,
		PoliticalEvent.EVENT_DEHYDRATION_SUFFERED,
		PoliticalEvent.DEPT_UTILITIES,
		-0.6,
		"Dehydration suffered during pump outage",
		183 # Machine room ID
	)
	
	var profile: Dictionary = SimulationReader.get_person_political_profile(ws, target_pid)
	asserts.assert_eq(profile["id"], target_pid, "Profile ID matches")
	asserts.assert_gt(profile["opinion_memories"].size(), 0, "Memory items must be recorded")
	
	var mem: Dictionary = profile["opinion_memories"][0]
	asserts.assert_eq(mem["event_type"], PoliticalEvent.EVENT_DEHYDRATION_SUFFERED, "Event type correctly traced")
	asserts.assert_eq(mem["attribution_dept"], PoliticalEvent.DEPT_UTILITIES, "Attribution department correctly traced")
	asserts.assert_eq(mem["source_entity_id"], 183, "Source entity ID correctly traced")
	asserts.assert_almost_eq(mem["salience"], 1.0, 0.05, "Fresh memory has high salience")

func test_memory_decay_over_time(asserts: TestAsserts) -> void:
	asserts.set_current_test("PoliticalIdentity: Multi-Month Memory Decay and Baseline Adaptation")
	var engine: SimulationEngine = SimulationEngine.new(202)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(pol_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var target_pid: int = pids[9]
	pol_sys.record_citizen_event(
		ws,
		target_pid,
		PoliticalEvent.EVENT_DEMOTION_PENALTY,
		PoliticalEvent.DEPT_ADMINISTRATION,
		-0.8,
		"Demoted"
	)
	
	var prof_initial: Dictionary = SimulationReader.get_person_political_profile(ws, target_pid)
	var trust_initial: float = prof_initial["attitudes"]["institutional_trust"]
	asserts.assert_lt(trust_initial, 0.35, "Initial trust dropped sharply after demotion")
	
	# Step 30 days (4,320 ticks / 1 halflife)
	engine.step(OpinionMemory.HALF_LIFE_TICKS)
	
	var prof_30d: Dictionary = SimulationReader.get_person_political_profile(ws, target_pid)
	var salience_30d: float = prof_30d["opinion_memories"][0]["salience"]
	var trust_30d: float = prof_30d["attitudes"]["institutional_trust"]
	
	asserts.assert_almost_eq(salience_30d, 0.50, 0.05, "Salience decays to ~50% after 1 halflife (30 days)")
	asserts.assert_gt(trust_30d, trust_initial, "Trust recovers towards baseline as memory fades")
	
	# Step another 60 days (2 more halflives)
	engine.step(OpinionMemory.HALF_LIFE_TICKS * 2)
	var prof_90d: Dictionary = SimulationReader.get_person_political_profile(ws, target_pid)
	var salience_90d: float = prof_90d["opinion_memories"][0]["salience"]
	var trust_90d: float = prof_90d["attitudes"]["institutional_trust"]
	
	asserts.assert_almost_eq(salience_90d, 0.125, 0.05, "Salience decays to ~12.5% after 3 halflives (90 days)")
	asserts.assert_gt(trust_90d, trust_30d, "Trust continues recovering towards baseline")

func test_invariants_and_serialization(asserts: TestAsserts) -> void:
	asserts.set_current_test("PoliticalIdentity: Invariants & Full Serialization Roundtrip")
	var engine: SimulationEngine = SimulationEngine.new(303)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(pol_sys)
	engine.register_system(daily_life)
	
	# Inject a variety of events
	var pids_inv: Array[int] = ws.entity_registry.get_entities_by_type("person")
	for i in range(mini(20, pids_inv.size())):
		pol_sys.record_citizen_event(
			ws,
			pids_inv[i],
			PoliticalEvent.EVENT_HOUSING_OVERCROWDED if i % 2 == 0 else PoliticalEvent.EVENT_PROMOTION_HONOR,
			PoliticalEvent.DEPT_ADMINISTRATION,
			-0.5 if i % 2 == 0 else 0.5,
			"Test event"
		)
		
	engine.step(288) # 2 days
	
	# Invariant Check
	var val: Dictionary = PoliticalInvariants.validate_all(ws)
	asserts.assert_true(val["is_valid"], "All political invariants must hold")
	asserts.assert_eq(val["errors"].size(), 0, "Zero invariant errors reported")
	asserts.assert_gt(val["memories_checked"], 15, "Memories validated")
	
	# Serialization Roundtrip Check
	var checksum_before: int = ws.get_state_checksum()
	var saved_dict: Dictionary = engine.save_to_dict()
	
	var engine2: SimulationEngine = SimulationEngine.new(303)
	engine2.register_system(InstitutionSystem.new())
	engine2.register_system(PoliticalSystem.new())
	engine2.register_system(DailyLifeSystem.new())
	engine2.load_from_dict(saved_dict)
	var checksum_after: int = engine2.get_state_checksum()
	
	asserts.assert_eq(checksum_before, checksum_after, "Checksum before and after serialization roundtrip must match exactly")

func test_political_simulation_replay_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("PoliticalIdentity: 5-Day Replay Determinism Check (Run A == Run B)")
	
	var run_sim = func(seed_val: int) -> int:
		var eng: SimulationEngine = SimulationEngine.new(seed_val)
		var world: WorldState = eng.get_world_state()
		PopulationGenerator.generate_population(world, 100)
		OccupationAssignment.setup_workplaces_and_assignments(world)
		eng.register_system(InstitutionSystem.new())
		eng.register_system(PoliticalSystem.new())
		eng.register_system(DailyLifeSystem.new())
		eng.register_system(MaintenanceSystem.new())
		eng.register_system(ProductionSystem.new())
		eng.register_system(WaterSystem.new(50000.0, 100000.0))
		eng.register_system(IncidentSystem.new())
		
		# Step 5 days (720 ticks)
		eng.step(720)
		return world.get_state_checksum()
		
	var checksum_a: int = run_sim.call(555)
	var checksum_b: int = run_sim.call(555)
	
	asserts.assert_eq(checksum_a, checksum_b, "Run A == Run B checksum exact match across multi-day political simulation")
