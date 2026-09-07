# tests/simulation/test_information_and_propaganda.gd
class_name TestInformationAndPropaganda
extends RefCounted

## Automated Headless Test Suite for Sprint 15: Propaganda, Information & Censorship.

const InformationObject = preload("res://src/sim/politics/information_object.gd")
const CitizenBelief = preload("res://src/sim/politics/citizen_belief.gd")
const InformationChannel = preload("res://src/sim/politics/information_channel.gd")
const InformationSystem = preload("res://src/sim/politics/information_system.gd")
const InformationInvariants = preload("res://src/sim/politics/information_invariants.gd")
const InformationReader = preload("res://src/presentation/information_reader.gd")
const CorruptionSystem = preload("res://src/sim/politics/corruption_system.gd")
const IllicitAction = preload("res://src/sim/politics/illicit_action.gd")
const FactionSystem = preload("res://src/sim/politics/faction_system.gd")
const Faction = preload("res://src/sim/politics/faction.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")

func run_all(asserts: TestAsserts) -> void:
	test_information_creation_and_dissemination(asserts)
	test_eyewitness_vs_official_denial(asserts)
	test_censorship_suppression_and_truth_preservation(asserts)
	test_redaction_and_delay_mechanics(asserts)
	test_corruption_audit_leak_vs_denial(asserts)
	test_word_of_mouth_social_propagation(asserts)
	test_bounded_memory_invariant(asserts)
	test_information_invariants_and_determinism(asserts)
	test_1200_resident_performance(asserts)

func test_information_creation_and_dissemination(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: Creation & Official Dissemination")
	var eng: SimulationEngine = SimulationEngine.new(201)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 60)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var info_sys: InformationSystem = InformationSystem.new()
	eng.register_system(info_sys)

	var truth: Dictionary = {"water_level_litres": 50000.0, "pumping_rate_lpm": 450.0}
	var claim: Dictionary = {"water_level_litres": 50000.0, "status": "nominal"}

	var info: InformationObject = info_sys.create_information(
		ws,
		"ev_water_report_01",
		"institution",
		0,
		"water_supply",
		truth,
		claim,
		InformationObject.CHANNEL_OFFICIAL,
		{"type": "all"},
		InformationObject.CLASS_PUBLIC,
		0.85,
		0.4,
		1.0
	)

	asserts.assert_not_null(info, "InformationObject should be created")
	asserts.assert_gt(info.id, 0, "InformationObject ID must be positive")
	asserts.assert_eq(info.censorship_state, InformationObject.STATE_ACTIVE, "Initial state should be ACTIVE")

	var delivered: int = info_sys.disseminate(ws, info)
	asserts.assert_gt(delivered, 0, "Official announcement should reach eligible residents")
	asserts.assert_eq(info.disseminated_count, 1, "Disseminated count incremented")
	asserts.assert_eq(info.reach_count, delivered, "Reach count matches delivered count")

	# Check recipient belief
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var p: Person = registry.get_entity(pids[0]) as Person
	asserts.assert_true(p.has_belief("ev_water_report_01"), "Resident should hold belief about event")
	var b: CitizenBelief = p.get_belief("ev_water_report_01")
	asserts.assert_eq(b.believed_info_id, info.id, "Resident belief should reference info id")
	asserts.assert_gt(b.confidence, 0.5, "Confidence should be positive")

func test_eyewitness_vs_official_denial(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: Eyewitness Detects Official Propaganda Denial")
	var eng: SimulationEngine = SimulationEngine.new(202)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var info_sys: InformationSystem = InformationSystem.new()
	eng.register_system(info_sys)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var witness: Person = registry.get_entity(pids[0]) as Person
	var initial_trust: float = witness.institutional_trust

	# Citizen personally witnesses a machinery failure and water pipe burst
	var ev_id: String = "ev_pipe_burst_level_4"
	var physical_truth: Dictionary = {
		"actual_diverted_kg": 0.0,
		"true_cause": "corrosion_rupture",
		"water_lost_litres": 820.0
	}
	witness.record_direct_experience(ev_id, "infrastructure_failure", physical_truth)

	var wb: CitizenBelief = witness.get_belief(ev_id)
	asserts.assert_true(wb.has_direct_experience, "Citizen is direct eyewitness")
	asserts.assert_eq(wb.confidence, 1.0, "Eyewitness confidence is 1.0")
	asserts.assert_eq(wb.doubt, 0.0, "Eyewitness doubt is initially 0.0")

	# Government issues official denial: "Routine maintenance drill, no water was lost"
	var counter_claim: Dictionary = {
		"framing": "denial",
		"true_cause": "scheduled_drill",
		"water_lost_litres": 0.0
	}
	info_sys.issue_official_denial(ws, ev_id, "infrastructure_failure", counter_claim)

	# Witness processes official denial
	asserts.assert_eq(wb.confidence, 1.0, "Eyewitness confidence in physical truth remains 1.0")
	asserts.assert_gt(wb.doubt, 0.2, "Eyewitness doubt in official story increases")
	asserts.assert_lt(witness.institutional_trust, initial_trust, "Institutional trust drops after catching government in a lie")
	asserts.assert_gt(witness.opinion_memories.size(), 0, "Opinion memory recorded for official denial of known reality")

func test_censorship_suppression_and_truth_preservation(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: Censorship != Deletion (Truth Preserved)")
	var eng: SimulationEngine = SimulationEngine.new(203)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var info_sys: InformationSystem = InformationSystem.new()
	eng.register_system(info_sys)

	var ev_id: String = "ev_reactor_temperature_spike"
	var truth: Dictionary = {"core_temp_celsius": 845.0, "safety_threshold": 800.0}
	var claim: Dictionary = {"core_temp_celsius": 845.0, "warning": "Core overheating"}

	var info: InformationObject = info_sys.create_information(
		ws,
		ev_id,
		"citizen",
		1,
		"safety",
		truth,
		claim,
		InformationObject.CHANNEL_OFFICIAL
	)

	# Executive censors the warning
	var ok: bool = info_sys.suppress_information(ws, info.id, "Prevent widespread silo panic")
	asserts.assert_true(ok, "Suppression action succeeds")
	asserts.assert_true(info.is_suppressed(), "Information is flagged as SUPPRESSED")

	# Attempt to disseminate over official channels
	var delivered: int = info_sys.disseminate(ws, info)
	asserts.assert_eq(delivered, 0, "Suppressed information is blocked from transmission")

	# Invariant verification: truth_basis is intact and NOT deleted or zeroed out
	asserts.assert_eq(info.truth_basis["core_temp_celsius"], 845.0, "Underlying physical truth preserved in object")
	var log: Array = ws.custom_data.get("censorship_audit_log", [])
	asserts.assert_eq(log.size(), 1, "Censorship action recorded in audit log")
	asserts.assert_eq(log[0]["action"], "suppress", "Audit record specifies suppression")
	asserts.assert_eq(log[0]["reason"], "Prevent widespread silo panic", "Audit record logs reason")

func test_redaction_and_delay_mechanics(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: Redaction & Delay Mechanics")
	var eng: SimulationEngine = SimulationEngine.new(204)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var info_sys: InformationSystem = InformationSystem.new()
	eng.register_system(info_sys)

	var ev_id: String = "ev_food_spoilage"
	var truth: Dictionary = {"spoiled_kg": 150.0, "responsible_officer_id": 42}
	var claim: Dictionary = {"spoiled_kg": 150.0, "responsible_officer_id": 42, "status": "investigating"}

	var info: InformationObject = info_sys.create_information(
		ws,
		ev_id,
		"institution",
		0,
		"rations",
		truth,
		claim
	)

	# Redact responsible officer
	var red_fields: Array[String] = ["responsible_officer_id"]
	info_sys.redact_information(ws, info.id, red_fields)
	asserts.assert_eq(info.censorship_state, InformationObject.STATE_REDACTED, "State is REDACTED")
	var visible: Dictionary = info.get_visible_claim()
	asserts.assert_true(visible["responsible_officer_id"].begins_with("[REDACTED"), "Field replaced with redaction notice")
	asserts.assert_eq(visible["spoiled_kg"], 150.0, "Unredacted fields visible")

	# Delay transmission by 2 ticks
	info_sys.delay_information(ws, info.id, 2)
	asserts.assert_true(info.is_delayed(), "Information is DELAYED")
	var del_count: int = info_sys.disseminate(ws, info)
	asserts.assert_eq(del_count, 0, "Delayed info not delivered immediately")

	# Tick 1: still pending
	eng.step(1)
	asserts.assert_eq(info.reach_count, 0, "Still pending at tick 1")

	# Tick 2: timer expires and disseminates
	eng.step(1)
	asserts.assert_gt(info.reach_count, 0, "Automatically disseminated once delay expired")

func test_corruption_audit_leak_vs_denial(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: Corruption Divergence (Leak vs Denial)")
	var eng: SimulationEngine = SimulationEngine.new(205)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 60)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var fact_sys: FactionSystem = FactionSystem.new()
	var corr_sys: CorruptionSystem = CorruptionSystem.new()
	var info_sys: InformationSystem = InformationSystem.new()
	eng.register_system(fact_sys)
	eng.register_system(corr_sys)
	eng.register_system(info_sys)

	# Create a faction
	var f: Faction = Faction.new(0, "Workers Solidarity", 1, 0)
	var target_fid: int = ws.entity_registry.register_entity("faction", f)
	f.id = target_fid

	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var leaker: Person = ws.entity_registry.get_entity(pids[0]) as Person
	var loyalist: Person = ws.entity_registry.get_entity(pids[1]) as Person
	var faction_member: Person = ws.entity_registry.get_entity(pids[2]) as Person

	leaker.faction_id = target_fid
	faction_member.faction_id = target_fid
	loyalist.faction_id = 0
	loyalist.institutional_trust = 0.9

	# Physical corruption event: 120 kg grain diverted
	var ev_id: String = "ev_grain_heist_01"
	var truth: Dictionary = {
		"actual_diverted_kg": 120.0,
		"resource": "grain",
		"perpetrator_id": 999
	}

	# 1. Whistleblower leaks truth basis to faction channel
	var leak_info: InformationObject = info_sys.leak_to_faction(
		ws,
		ev_id,
		"corruption",
		truth,
		leaker.id,
		target_fid,
		0.92
	)
	asserts.assert_not_null(leak_info, "Leak info object created")
	asserts.assert_true(faction_member.has_belief(ev_id), "Faction member received leak")
	var fb: CitizenBelief = faction_member.get_belief(ev_id)
	asserts.assert_eq(fb.believed_info_id, leak_info.id, "Faction member believes whistleblower leak")

	# 2. Administration issues public official denial
	var counter_claim: Dictionary = {
		"actual_diverted_kg": 0.0,
		"framing": "denial",
		"statement": "Inventory audit confirmed zero discrepancy."
	}
	var denial_info: InformationObject = info_sys.issue_official_denial(ws, ev_id, "corruption", counter_claim)
	asserts.assert_not_null(denial_info, "Denial info object created")

	# 3. Check divergent beliefs:
	# Loyalist believes government denial
	var lb: CitizenBelief = loyalist.get_belief(ev_id)
	asserts.assert_not_null(lb, "Loyalist received denial broadcast")
	asserts.assert_eq(lb.believed_info_id, denial_info.id, "Loyalist accepts official denial")

	# Faction member heard denial but maintains belief in the leak (or develops acute doubt towards government)
	asserts.assert_gt(fb.heard_claims.size(), 1, "Faction member heard multiple claims")
	asserts.assert_eq(fb.believed_info_id, leak_info.id, "Faction member maintains belief in whistleblower leak")

	# Verify through InformationReader
	var narr: Dictionary = InformationReader.get_competing_narratives(ws, ev_id)
	asserts.assert_eq(narr["claims"].size(), 2, "Reader reports two competing claims")
	asserts.assert_gt(narr["citizen_breakdown"]["total_aware"], 1, "Reader reports multiple aware citizens")

func test_word_of_mouth_social_propagation(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: Word-of-Mouth Social Network Propagation")
	var eng: SimulationEngine = SimulationEngine.new(206)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var info_sys: InformationSystem = InformationSystem.new()
	eng.register_system(info_sys)

	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var spreader: Person = ws.entity_registry.get_entity(pids[0]) as Person
	var friend: Person = ws.entity_registry.get_entity(pids[1]) as Person

	# Connect spreader and friend via shared workplace and shift
	var target_workplace: int = spreader.workplace_room_id if spreader.workplace_room_id > 0 else 10
	spreader.workplace_room_id = target_workplace
	friend.workplace_room_id = target_workplace
	friend.shift_id = spreader.shift_id

	var ev_id: String = "ev_secret_tunnel_discovery"
	var truth: Dictionary = {"depth_m": 45.0, "type": "unmapped_vent"}
	var claim: Dictionary = {"rumour": "Found an unmapped tunnel near pump room 3"}

	var info: InformationObject = info_sys.create_information(
		ws,
		ev_id,
		"citizen",
		spreader.id,
		"silo_structure",
		truth,
		claim,
		InformationObject.CHANNEL_WORD_OF_MOUTH,
		{"type": "all"},
		InformationObject.CLASS_CLANDESTINE,
		0.75,
		0.8 # High salience
	)

	# Spreader receives initial belief
	info_sys.evaluate_citizen_exposure(ws, spreader, info)
	asserts.assert_true(spreader.has_belief(ev_id), "Spreader knows rumour")
	asserts.assert_false(friend.has_belief(ev_id), "Friend does not yet know rumour")

	# Propagate along social graph
	var reached: int = info_sys.propagate_word_of_mouth(ws, ev_id, 5)
	asserts.assert_gt(reached, 0, "Word of mouth reached at least one contact")
	asserts.assert_true(friend.has_belief(ev_id), "Friend adopted rumour through social network")
	var fb: CitizenBelief = friend.get_belief(ev_id)
	asserts.assert_eq(fb.believed_info_id, info.id, "Friend's belief points to rumour info id")

func test_bounded_memory_invariant(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: Bounded Memory Invariant (<= 5 Claims)")
	var b: CitizenBelief = CitizenBelief.new("ev_bounded_test", "general", false, {})

	for i in range(12):
		b.add_heard_claim(
			i + 1,
			{"claim_idx": i},
			"citizen",
			100 + i,
			0.5,
			i * 10
		)
		asserts.assert_true(b.heard_claims.size() <= CitizenBelief.MAX_HEARD_CLAIMS, "Heard claims never exceeds MAX_HEARD_CLAIMS (5)")

	asserts.assert_eq(b.heard_claims.size(), CitizenBelief.MAX_HEARD_CLAIMS, "Heard claims bounded exactly at 5")

func test_information_invariants_and_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: Invariants & Deterministic Replay")

	# Run A
	var eng_a: SimulationEngine = SimulationEngine.new(777)
	var ws_a: WorldState = eng_a.get_world_state()
	PopulationGenerator.generate_population(ws_a, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_a)
	var sys_a: InformationSystem = InformationSystem.new()
	eng_a.register_system(sys_a)

	sys_a.create_information(ws_a, "ev_det_1", "institution", 0, "rations", {}, {"ratio": 1.0})
	eng_a.step(50)

	var val_a: Dictionary = InformationInvariants.validate_all(ws_a)
	asserts.assert_true(val_a["is_valid"], "Run A information invariants must be valid: %s" % str(val_a.get("errors", [])))
	var chk_a: int = ws_a.get_state_checksum()

	# Run B
	var eng_b: SimulationEngine = SimulationEngine.new(777)
	var ws_b: WorldState = eng_b.get_world_state()
	PopulationGenerator.generate_population(ws_b, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_b)
	var sys_b: InformationSystem = InformationSystem.new()
	eng_b.register_system(sys_b)

	sys_b.create_information(ws_b, "ev_det_1", "institution", 0, "rations", {}, {"ratio": 1.0})
	eng_b.step(50)

	var val_b: Dictionary = InformationInvariants.validate_all(ws_b)
	asserts.assert_true(val_b["is_valid"], "Run B information invariants must be valid: %s" % str(val_b.get("errors", [])))
	var chk_b: int = ws_b.get_state_checksum()

	asserts.assert_eq(chk_a, chk_b, "Simulation with identical seed produces identical checksum (Run A == Run B)")

func test_1200_resident_performance(asserts: TestAsserts) -> void:
	asserts.set_current_test("Information: 1200 Resident Scale Performance Benchmark")
	var eng: SimulationEngine = SimulationEngine.new(999)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 1200)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var info_sys: InformationSystem = InformationSystem.new()
	eng.register_system(info_sys)

	var start_usec: int = Time.get_ticks_usec()

	# Create announcement and broadcast to all 1200
	var info: InformationObject = info_sys.create_information(
		ws,
		"ev_scale_broadcast",
		"institution",
		0,
		"directive",
		{"quota": 100},
		{"quota": 100}
	)
	var delivered: int = info_sys.disseminate(ws, info)

	# Run periodic social spread
	info_sys.propagate_word_of_mouth(ws, "ev_scale_broadcast", 15)

	var elapsed_ms: float = (Time.get_ticks_usec() - start_usec) / 1000.0

	asserts.assert_gt(delivered, 600, "Broadcast reached majority of eligible residents")
	asserts.assert_lt(elapsed_ms, 250.0, "Broadcast + Word-of-Mouth for 1,200 residents under 250ms budget (actual: %.2f ms)" % elapsed_ms)
	print("  [BENCHMARK] Disseminated info to %d / 1200 residents in %.2f ms" % [delivered, elapsed_ms])

	var val: Dictionary = InformationInvariants.validate_all(ws)
	asserts.assert_true(val["is_valid"], "Invariants hold at 1,200 resident scale: %s" % str(val.get("errors", [])))
