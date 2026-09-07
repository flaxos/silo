# tests/simulation/test_factions_and_blocs.gd
class_name TestFactionsAndBlocs
extends RefCounted

## Automated Headless Test Suite for Sprint 13: Factions, Movements & Social Networks.

const Faction = preload("res://src/sim/politics/faction.gd")
const FactionSystem = preload("res://src/sim/politics/faction_system.gd")
const SocialGraph = preload("res://src/sim/politics/social_graph.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")
const FactionInvariants = preload("res://src/sim/politics/faction_invariants.gd")

func run_all(asserts: TestAsserts) -> void:
	test_social_graph_bounded_connections(asserts)
	test_emergent_faction_clustering_under_stress(asserts)
	test_social_network_recruitment_and_insulation(asserts)
	test_policy_responsiveness_and_grievance_agenda(asserts)
	test_multi_faction_emergence_and_inter_faction_rivalry(asserts)
	test_faction_invariants_and_serialization_roundtrip(asserts)
	test_faction_determinism_smoke(asserts)

func test_social_graph_bounded_connections(asserts: TestAsserts) -> void:
	asserts.set_current_test("Factions: Bounded Social Network Ties & Influence")
	var eng: SimulationEngine = SimulationEngine.new(101)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var target_p: Person = ws.entity_registry.get_entity(pids[0]) as Person
	
	var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, target_p.id)
	asserts.assert_gt(connections.size(), 0, "Person should have bounded social connections (household/coworkers/family)")
	
	# Verify coworkers are present in connections
	var coworkers: Array[int] = SocialGraph.get_coworkers(ws, target_p.id)
	if not coworkers.is_empty():
		var found_coworker: bool = false
		for c in connections:
			if int(c["target_id"]) == coworkers[0]:
				found_coworker = true
				break
		asserts.assert_true(found_coworker, "Coworker must appear in person's bounded social network")
		
		var coworker_id: int = coworkers[0]
		var inf_coworker: float = SocialGraph.calculate_influence_strength(ws, target_p.id, coworker_id)
		asserts.assert_gt(inf_coworker, 0.0, "Influence between coworkers should be positive")

func test_emergent_faction_clustering_under_stress(asserts: TestAsserts) -> void:
	asserts.set_current_test("Factions: Organic Emergence Under High Grievance & Workplace Ties")
	var eng: SimulationEngine = SimulationEngine.new(202)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	var fact_sys: FactionSystem = FactionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	
	eng.register_system(inst_sys)
	eng.register_system(pol_sys)
	eng.register_system(fact_sys)
	eng.register_system(daily_life)
	
	# Induce stress and lived grievances in Mining workers
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var mining_workers: Array[Person] = []
	for pid in pids:
		var p: Person = ws.entity_registry.get_entity(pid) as Person
		if p and p.occupation_id == "miner":
			mining_workers.append(p)
			p.class_resentment = 0.6
			p.institutional_trust = 0.2
			p.record_opinion_memory(
				PoliticalEvent.EVENT_DEHYDRATION_SUFFERED,
				0,
				PoliticalEvent.DEPT_UTILITIES,
				-0.7,
				"Severe water outage during deep mine shift.",
				0
			)
			
	asserts.assert_gt(mining_workers.size(), 2, "Should have multiple mining workers")
	
	# Step 1 day (144 ticks)
	eng.step(144)
	
	var factions: Array[int] = ws.entity_registry.get_entities_by_type("faction")
	asserts.assert_gt(factions.size(), 0, "Emergent faction should form under high grievance and workplace ties")
	
	if not factions.is_empty():
		var f: Faction = ws.entity_registry.get_entity(factions[0]) as Faction
		asserts.assert_true(f.is_active, "Formed faction must be active")
		asserts.assert_gt(f.member_ids.size(), 2, "Faction must have at least 3 founding members")
		asserts.assert_gt(f.leader_id, 0, "Faction must have an assigned leader")
		asserts.assert_true(f.member_ids.has(f.leader_id), "Leader must be a member of the faction")
		asserts.assert_gt(f.grievance_agenda.size(), 0, "Faction should have active grievances compiled from members")
		asserts.assert_gt(f.cohesion, 0.0, "Faction cohesion should be positive")

func test_social_network_recruitment_and_insulation(asserts: TestAsserts) -> void:
	asserts.set_current_test("Factions: Word-of-Mouth Recruitment vs Insulated Officials")
	var eng: SimulationEngine = SimulationEngine.new(303)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	var fact_sys: FactionSystem = FactionSystem.new()
	
	eng.register_system(inst_sys)
	eng.register_system(pol_sys)
	eng.register_system(fact_sys)
	
	# Manually form a small seed faction
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var founder1: Person = ws.entity_registry.get_entity(pids[0]) as Person
	var founder2: Person = ws.entity_registry.get_entity(pids[1]) as Person
	
	founder1.class_resentment = 0.5
	founder1.institutional_trust = 0.3
	founder2.class_resentment = 0.5
	founder2.institutional_trust = 0.3
	
	var test_faction: Faction = Faction.new(0, "Solidarity Front", founder1.id, 0)
	test_faction.id = ws.entity_registry.register_entity("faction", test_faction)
	test_faction.add_member(founder1.id)
	test_faction.add_member(founder2.id)
	founder1.faction_id = test_faction.id
	founder2.faction_id = test_faction.id
	
	# Insulate a security official (high trust, clearance 3, zero grievances)
	var insulated_p: Person = ws.entity_registry.get_entity(pids[10]) as Person
	insulated_p.institutional_trust = 0.95
	insulated_p.class_resentment = 0.0
	insulated_p.security_clearance = 3
	insulated_p.department_id = "security"
	
	# Step 5 days (720 ticks) to allow recruitment
	eng.step(720)
	
	var summary: Dictionary = SimulationReader.get_factions_summary(ws)
	asserts.assert_gt(summary["total_count"], 0, "Factions summary should register factions")
	
	# Insulated official should not be in the grievance faction
	asserts.assert_eq(insulated_p.faction_id, 0, "Insulated official with high trust should not join opposition faction")

func test_policy_responsiveness_and_grievance_agenda(asserts: TestAsserts) -> void:
	asserts.set_current_test("Factions: Dynamic Policy & Executive Order Response")
	var eng: SimulationEngine = SimulationEngine.new(404)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	var fact_sys: FactionSystem = FactionSystem.new()
	
	eng.register_system(inst_sys)
	eng.register_system(pol_sys)
	eng.register_system(fact_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var leader: Person = ws.entity_registry.get_entity(pids[0]) as Person
	
	var f: Faction = Faction.new(0, "Autonomous Labour Union", leader.id, 0)
	f.ideology_profile = {
		"preference_equality": 0.9,
		"preference_hierarchy": 0.1,
		"preference_reform": 0.8,
		"preference_stability": 0.3,
		"preference_autonomy": 0.9,
		"tolerance_coercion": 0.05
	}
	f.id = ws.entity_registry.register_entity("faction", f)
	f.add_member(leader.id)
	leader.faction_id = f.id
	
	# Issue a coercive mandatory overtime executive order
	var order: ExecutiveOrder = ExecutiveOrder.new(
		"order_overtime_1",
		ExecutiveOrder.ORDER_OVERTIME_SURGE,
		"Emergency 16-hour shifts for all engineers.",
		"engineering",
		"dept_engineering",
		720
	)
	order.is_active = true
	inst_sys.active_orders[order.id] = order
	
	# Step simulation
	eng.step(144)
	
	var f_detail: Dictionary = SimulationReader.get_faction_detail(ws, f.id)
	asserts.assert_true(f_detail["policy_approval_matrix"].has("order_overtime_1"), "Faction must evaluate active executive order")
	if f_detail["policy_approval_matrix"].has("order_overtime_1"):
		var approval: float = float(f_detail["policy_approval_matrix"]["order_overtime_1"])
		asserts.assert_true(approval < 0.0, "High-autonomy low-coercion faction must disapprove of mandatory overtime order")

func test_multi_faction_emergence_and_inter_faction_rivalry(asserts: TestAsserts) -> void:
	asserts.set_current_test("Factions: Multi-Faction Ideological Alignment & Rivalry")
	var eng: SimulationEngine = SimulationEngine.new(505)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var fact_sys: FactionSystem = FactionSystem.new()
	eng.register_system(fact_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var l1: Person = ws.entity_registry.get_entity(pids[0]) as Person
	var l2: Person = ws.entity_registry.get_entity(pids[5]) as Person
	
	# Faction 1: Radical Reform & Autonomy
	var f1: Faction = Faction.new(0, "Radical Reformers", l1.id, 0)
	f1.ideology_profile = {
		"preference_equality": 0.9,
		"preference_hierarchy": 0.1,
		"preference_reform": 0.9,
		"preference_stability": 0.1,
		"preference_autonomy": 0.9,
		"tolerance_coercion": 0.1
	}
	f1.id = ws.entity_registry.register_entity("faction", f1)
	f1.add_member(l1.id)
	l1.faction_id = f1.id
	
	# Faction 2: Authoritarian Order League
	var f2: Faction = Faction.new(0, "Order League", l2.id, 0)
	f2.ideology_profile = {
		"preference_equality": 0.1,
		"preference_hierarchy": 0.9,
		"preference_reform": 0.1,
		"preference_stability": 0.9,
		"preference_autonomy": 0.1,
		"tolerance_coercion": 0.8
	}
	f2.id = ws.entity_registry.register_entity("faction", f2)
	f2.add_member(l2.id)
	l2.faction_id = f2.id
	
	eng.step(144)
	
	var d1: Dictionary = SimulationReader.get_faction_detail(ws, f1.id)
	
	asserts.assert_true(d1["inter_faction_relations"].has(f2.id), "Faction 1 must evaluate relation with Faction 2")
	var relation: float = float(d1["inter_faction_relations"][f2.id])
	asserts.assert_true(relation < 0.0, "Ideologically opposing factions must register a negative relation (rivalry)")

func test_faction_invariants_and_serialization_roundtrip(asserts: TestAsserts) -> void:
	asserts.set_current_test("Factions: System Invariants & Serialization Roundtrip")
	var eng: SimulationEngine = SimulationEngine.new(606)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	var fact_sys: FactionSystem = FactionSystem.new()
	
	eng.register_system(inst_sys)
	eng.register_system(pol_sys)
	eng.register_system(fact_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var leader: Person = ws.entity_registry.get_entity(pids[0]) as Person
	var f: Faction = Faction.new(0, "Guild of Miners", leader.id, 0)
	f.id = ws.entity_registry.register_entity("faction", f)
	f.add_member(leader.id)
	leader.faction_id = f.id
	
	# Validate invariants
	var inv_result: Dictionary = FactionInvariants.validate_all(ws)
	asserts.assert_true(inv_result["is_valid"], "Faction invariants must pass before serialization: %s" % str(inv_result["errors"]))
	
	# Serialization test
	var ser_f: Dictionary = f.serialize()
	var f_restored: Faction = Faction.new()
	f_restored.deserialize(ser_f)
	
	asserts.assert_eq(f_restored.id, f.id, "Deserialized faction ID must match")
	asserts.assert_eq(f_restored.name, f.name, "Deserialized faction name must match")
	asserts.assert_eq(f_restored.leader_id, f.leader_id, "Deserialized leader ID must match")
	asserts.assert_eq(f_restored.member_ids.size(), f.member_ids.size(), "Deserialized member count must match")

func test_faction_determinism_smoke(asserts: TestAsserts) -> void:
	asserts.set_current_test("Factions: 7-Day Multi-System Deterministic Replay")
	var eng_a: SimulationEngine = SimulationEngine.new(777)
	var eng_b: SimulationEngine = SimulationEngine.new(777)
	
	PopulationGenerator.generate_population(eng_a.get_world_state(), 100)
	PopulationGenerator.generate_population(eng_b.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(eng_a.get_world_state())
	OccupationAssignment.setup_workplaces_and_assignments(eng_b.get_world_state())
	
	eng_a.register_system(InstitutionSystem.new())
	eng_a.register_system(PoliticalSystem.new())
	eng_a.register_system(FactionSystem.new())
	eng_a.register_system(DailyLifeSystem.new())
	
	eng_b.register_system(InstitutionSystem.new())
	eng_b.register_system(PoliticalSystem.new())
	eng_b.register_system(FactionSystem.new())
	eng_b.register_system(DailyLifeSystem.new())
	
	for _day in range(7):
		eng_a.step(144)
		eng_b.step(144)
		
	var chk_a: int = eng_a.get_world_state().get_state_checksum()
	var chk_b: int = eng_b.get_world_state().get_state_checksum()
	asserts.assert_eq(chk_a, chk_b, "Faction simulation must be 100% deterministic (Checksum A == Checksum B)")
