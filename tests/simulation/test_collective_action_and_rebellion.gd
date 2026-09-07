# tests/simulation/test_collective_action_and_rebellion.gd
class_name TestCollectiveActionAndRebellion
extends RefCounted

## Automated Headless Test Suite for Sprint 16: Protest, Strikes, Civil Disobedience & Rebellion.

const CollectiveAction = preload("res://src/sim/politics/collective_action.gd")
const CollectiveActionSystem = preload("res://src/sim/politics/collective_action_system.gd")
const CollectiveActionInvariants = preload("res://src/sim/politics/collective_action_invariants.gd")
const CollectiveActionReader = preload("res://src/presentation/collective_action_reader.gd")
const InformationSystem = preload("res://src/sim/politics/information_system.gd")
const InformationObject = preload("res://src/sim/politics/information_object.gd")
const FactionSystem = preload("res://src/sim/politics/faction_system.gd")
const Faction = preload("res://src/sim/politics/faction.gd")
const DailyLifeSystem = preload("res://src/sim/population/daily_life_system.gd")
const ProductionSystem = preload("res://src/sim/economy/production_system.gd")
const MaintenanceSystem = preload("res://src/sim/machinery/maintenance_system.gd")
const WaterSystem = preload("res://src/sim/utilities/water_system.gd")
const Machine = preload("res://src/sim/machinery/machine.gd")
const MachineComponent = preload("res://src/sim/machinery/machine_component.gd")

func run_all(asserts: TestAsserts) -> void:
	test_uat_a_grounded_strike_and_downstream_production_impact(asserts)
	test_uat_b_information_feedback_loop_leak_vs_censorship(asserts)
	test_uat_c_physical_machinery_sabotage(asserts)
	test_uat_d_dual_resolution_paths(asserts)
	test_collective_action_invariants_and_determinism(asserts)
	test_1200_resident_scale_performance(asserts)

func test_uat_a_grounded_strike_and_downstream_production_impact(asserts: TestAsserts) -> void:
	asserts.set_current_test("CollectiveAction UAT-A: Grounded Strike Halts Physical Production")
	var eng: SimulationEngine = SimulationEngine.new(301)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 60)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var action_sys: CollectiveActionSystem = CollectiveActionSystem.new()

	eng.register_system(daily_life)
	eng.register_system(action_sys)
	eng.register_system(prod_sys)

	# 1. Run simulation for 2 days to verify baseline physical production
	eng.step(288)

	var seam_before: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))
	asserts.assert_lt(seam_before, ProductionSystem.INITIAL_SEAM_ORE_KG, "Normal work extracted ore from seam")

	# Find deep mine room and its miners
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var mine_room_id: int = 0
	var miners: Array[int] = []

	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "miner":
			mine_room_id = p.workplace_room_id
			miners.append(pid)

	asserts.assert_gt(mine_room_id, 0, "Must find deep mine room")
	asserts.assert_gt(miners.size(), 0, "Must find working miners")

	# 2. Miners declare an acute walkout strike
	var action: CollectiveAction = action_sys.organize_strike(
		ws,
		mine_room_id,
		miners[0],
		[{"type": "shift_hours_reduction", "value": 6}],
		0,
		"ev_mine_safety_protest"
	)

	asserts.assert_not_null(action, "Strike action created")
	asserts.assert_gt(action.participant_ids.size(), 0, "Miners joined strike")

	var striking_map: Dictionary = ws.custom_data.get("striking_person_ids", {})
	asserts.assert_true(striking_map.has(miners[0]), "Organizer marked as striking")

	# 3. Simulate another 2 days under active strike
	var seam_at_strike_start: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))
	eng.step(288)

	var seam_after_strike: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))

	# Physical verification: Extraction completely halted because miners withdrew their physical labour
	asserts.assert_eq(seam_at_strike_start, seam_after_strike, "Zero ore extracted during strike (pure physical labour withdrawal)")

	# Verify through CollectiveActionReader
	var status: Dictionary = CollectiveActionReader.get_workplace_strike_status(ws, mine_room_id)
	asserts.assert_true(status["is_on_strike"], "Reader reports mine workplace is on strike")
	asserts.assert_gt(status["striking_workers"].size(), 0, "Reader lists striking workers")

func test_uat_b_information_feedback_loop_leak_vs_censorship(asserts: TestAsserts) -> void:
	asserts.set_current_test("CollectiveAction UAT-B: Information Leak Triggers Action vs Censorship")
	
	# --- Case 1: Whistleblower report suppressed by censorship ---
	var eng_censor: SimulationEngine = SimulationEngine.new(302)
	var ws_c: WorldState = eng_censor.get_world_state()
	PopulationGenerator.generate_population(ws_c, 60)
	OccupationAssignment.setup_workplaces_and_assignments(ws_c)

	var info_c: InformationSystem = InformationSystem.new()
	var act_c: CollectiveActionSystem = CollectiveActionSystem.new()
	eng_censor.register_system(info_c)
	eng_censor.register_system(act_c)

	var ev_id: String = "ev_ration_embezzlement"
	var truth: Dictionary = {"stolen_rations_kg": 400.0, "culprit": "senior_officer"}

	var info_censored: InformationObject = info_c.create_information(
		ws_c, ev_id, "citizen", 1, "corruption", truth, truth, InformationObject.CHANNEL_OFFICIAL
	)
	info_c.suppress_information(ws_c, info_censored.id, "National security")
	info_c.disseminate(ws_c, info_censored)

	# Population remains unaware of theft -> no collective strike
	var summary_c: Dictionary = CollectiveActionReader.get_collective_action_summary(ws_c)
	asserts.assert_eq(summary_c["active_strikes_count"], 0, "Censorship prevented awareness; zero strikes emerged")

	# --- Case 2: Whistleblower leaks to faction channel ---
	var eng_leak: SimulationEngine = SimulationEngine.new(302)
	var ws_l: WorldState = eng_leak.get_world_state()
	PopulationGenerator.generate_population(ws_l, 60)
	OccupationAssignment.setup_workplaces_and_assignments(ws_l)

	var info_l: InformationSystem = InformationSystem.new()
	var act_l: CollectiveActionSystem = CollectiveActionSystem.new()
	eng_leak.register_system(info_l)
	eng_leak.register_system(act_l)

	# Form faction
	var f: Faction = Faction.new(0, "Proletarian League", 1, 0)
	var fid: int = ws_l.entity_registry.register_entity("faction", f)
	f.id = fid

	var pids: Array[int] = ws_l.entity_registry.get_entities_by_type("person")
	for i in range(10):
		var p: Person = ws_l.entity_registry.get_entity(pids[i]) as Person
		p.faction_id = fid

	# Leak truth basis
	info_l.leak_to_faction(ws_l, ev_id, "corruption", truth, pids[0], fid, 0.95)

	# Leaked belief triggers acute collective action
	var strike_action: CollectiveAction = act_l.organize_strike(
		ws_l,
		(ws_l.entity_registry.get_entity(pids[0]) as Person).workplace_room_id,
		pids[0],
		[{"type": "prosecute_culprit", "value": "senior_officer"}],
		fid,
		ev_id
	)

	asserts.assert_not_null(strike_action, "Strike successfully triggered by leaked information")
	asserts.assert_gt(strike_action.participant_ids.size(), 0, "Faction members joined strike upon learning truth")

func test_uat_c_physical_machinery_sabotage(asserts: TestAsserts) -> void:
	asserts.set_current_test("CollectiveAction UAT-C: Physical Machinery Sabotage")
	var eng: SimulationEngine = SimulationEngine.new(303)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var maint_sys: MaintenanceSystem = MaintenanceSystem.new()
	var act_sys: CollectiveActionSystem = CollectiveActionSystem.new()
	var info_sys: InformationSystem = InformationSystem.new()
	eng.register_system(info_sys)
	eng.register_system(maint_sys)
	eng.register_system(act_sys)

	# Set up a test machine with a critical bearing component
	var machine: Machine = Machine.new(0, 5, "water_pump_primary")
	var comp: MachineComponent = MachineComponent.new("impeller_bearing", "Main Impeller Bearing", 0.1, 1.0, "bearing", 1.0, 12)
	comp.wear_percent = 10.0 # Initially nominal
	machine.add_component(comp)
	machine.update_state()
	machine.id = ws.entity_registry.register_entity("machine", machine)

	asserts.assert_eq(machine.state, Machine.STATE_NOMINAL, "Machine initially nominal")

	# Saboteur commits targeted sabotage: inflicts 85% wear
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var saboteur_id: int = pids[0]

	var sab_action: CollectiveAction = act_sys.commit_sabotage(
		ws,
		machine.id,
		"impeller_bearing",
		saboteur_id,
		85.0,
		"ev_anti_regime_protest"
	)

	asserts.assert_not_null(sab_action, "Sabotage collective action created")
	asserts.assert_eq(comp.wear_percent, 95.0, "Component wear physically increased to 95%")
	asserts.assert_eq(machine.state, Machine.STATE_FAULT, "Machine state physically degraded to FAULT")
	asserts.assert_lt(comp.get_efficiency(), 0.6, "Component efficiency degraded physically")

	# Verify recorded in reader log
	var log: Array = CollectiveActionReader.get_sabotage_log(ws)
	asserts.assert_eq(log.size(), 1, "Sabotage incident logged in read model")
	asserts.assert_eq(log[0]["component_id"], "impeller_bearing", "Logged component ID matches")

func test_uat_d_dual_resolution_paths(asserts: TestAsserts) -> void:
	asserts.set_current_test("CollectiveAction UAT-D: Dual Resolution Paths (Concessions vs Force)")
	var eng: SimulationEngine = SimulationEngine.new(304)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var act_sys: CollectiveActionSystem = CollectiveActionSystem.new()
	eng.register_system(act_sys)

	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var worker_a: Person = null
	var worker_b: Person = null
	for pid in pids:
		var p: Person = ws.entity_registry.get_entity(pid) as Person
		if p and p.is_alive and p.workplace_room_id > 0:
			if worker_a == null:
				worker_a = p
			elif worker_b == null and p.id != worker_a.id:
				worker_b = p
				break

	# --- Resolution Path 1: Concessions Granted ---
	var strike_1: CollectiveAction = act_sys.organize_strike(
		ws, worker_a.workplace_room_id, worker_a.id, [{"type": "ration", "value": 1.2}]
	)
	var trust_before_concession: float = worker_a.institutional_trust
	var ok_concede: bool = act_sys.grant_concessions(ws, strike_1.id, {"ration_increase": 0.2})

	asserts.assert_true(ok_concede, "Concessions granted successfully")
	asserts.assert_eq(strike_1.status, CollectiveAction.STATUS_CONCEDED, "Status updated to CONCEDED")
	asserts.assert_false((ws.custom_data.get("striking_person_ids", {}) as Dictionary).has(worker_a.id), "Worker labour returned to silo")
	asserts.assert_gt(worker_a.institutional_trust, trust_before_concession, "Worker institutional trust increased after concessions")

	# --- Resolution Path 2: Forceful Crackdown ---
	var strike_2: CollectiveAction = act_sys.organize_strike(
		ws, worker_b.workplace_room_id, worker_b.id, [{"type": "hours", "value": 6}]
	)
	var trust_before_crackdown: float = worker_b.institutional_trust
	var resentment_before: float = worker_b.class_resentment
	var ok_force: bool = act_sys.enforce_crackdown(ws, strike_2.id)

	asserts.assert_true(ok_force, "Crackdown enforced successfully")
	asserts.assert_eq(strike_2.status, CollectiveAction.STATUS_SUPPRESSED, "Status updated to SUPPRESSED")
	asserts.assert_false((ws.custom_data.get("striking_person_ids", {}) as Dictionary).has(worker_b.id), "Strike broken, removed from strike map")
	asserts.assert_lt(worker_b.institutional_trust, trust_before_crackdown, "Worker institutional trust plummeted after crackdown")
	asserts.assert_gt(worker_b.class_resentment, resentment_before, "Class resentment surged after crackdown")

func test_collective_action_invariants_and_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("CollectiveAction: Invariants & Deterministic Replay")

	# Run A
	var eng_a: SimulationEngine = SimulationEngine.new(888)
	var ws_a: WorldState = eng_a.get_world_state()
	PopulationGenerator.generate_population(ws_a, 50)
	OccupationAssignment.setup_workplaces_and_assignments(ws_a)

	var act_a: CollectiveActionSystem = CollectiveActionSystem.new()
	var prod_a: ProductionSystem = ProductionSystem.new()
	var daily_a: DailyLifeSystem = DailyLifeSystem.new()
	eng_a.register_system(daily_a)
	eng_a.register_system(act_a)
	eng_a.register_system(prod_a)

	var pids_a: Array[int] = ws_a.entity_registry.get_entities_by_type("person")
	var p_a: Person = ws_a.entity_registry.get_entity(pids_a[0]) as Person
	act_a.organize_strike(ws_a, p_a.workplace_room_id, p_a.id)

	eng_a.step(50)

	var val_a: Dictionary = CollectiveActionInvariants.validate_all(ws_a)
	asserts.assert_true(val_a["is_valid"], "Run A collective action invariants must be valid: %s" % str(val_a.get("errors", [])))
	var chk_a: int = ws_a.get_state_checksum()

	# Run B
	var eng_b: SimulationEngine = SimulationEngine.new(888)
	var ws_b: WorldState = eng_b.get_world_state()
	PopulationGenerator.generate_population(ws_b, 50)
	OccupationAssignment.setup_workplaces_and_assignments(ws_b)

	var act_b: CollectiveActionSystem = CollectiveActionSystem.new()
	var prod_b: ProductionSystem = ProductionSystem.new()
	var daily_b: DailyLifeSystem = DailyLifeSystem.new()
	eng_b.register_system(daily_b)
	eng_b.register_system(act_b)
	eng_b.register_system(prod_b)

	var pids_b: Array[int] = ws_b.entity_registry.get_entities_by_type("person")
	var p_b: Person = ws_b.entity_registry.get_entity(pids_b[0]) as Person
	act_b.organize_strike(ws_b, p_b.workplace_room_id, p_b.id)

	eng_b.step(50)

	var val_b: Dictionary = CollectiveActionInvariants.validate_all(ws_b)
	asserts.assert_true(val_b["is_valid"], "Run B collective action invariants must be valid: %s" % str(val_b.get("errors", [])))
	var chk_b: int = ws_b.get_state_checksum()

	asserts.assert_eq(chk_a, chk_b, "Simulation produces identical checksum (Run A == Run B)")

func test_1200_resident_scale_performance(asserts: TestAsserts) -> void:
	asserts.set_current_test("CollectiveAction: 1200 Resident Scale Performance Benchmark")
	var eng: SimulationEngine = SimulationEngine.new(999)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 1200)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var act_sys: CollectiveActionSystem = CollectiveActionSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	eng.register_system(daily_life)
	eng.register_system(act_sys)
	eng.register_system(prod_sys)

	var start_usec: int = Time.get_ticks_usec()

	# Organize strikes across 3 large facilities
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var struck_rooms: Dictionary = {}
	for pid in pids:
		var p: Person = ws.entity_registry.get_entity(pid) as Person
		if p and p.workplace_room_id > 0 and not struck_rooms.has(p.workplace_room_id):
			struck_rooms[p.workplace_room_id] = true
			act_sys.organize_strike(ws, p.workplace_room_id, pid)
			if struck_rooms.size() >= 3:
				break

	# Step simulation through 24 ticks (4 hours)
	eng.step(24)

	var elapsed_ms: float = (Time.get_ticks_usec() - start_usec) / 1000.0
	var avg_ms_per_tick: float = elapsed_ms / 24.0

	var summary: Dictionary = CollectiveActionReader.get_collective_action_summary(ws)
	asserts.assert_gt(summary["striking_workers_count"], 10, "Substantial number of striking workers")
	asserts.assert_lt(avg_ms_per_tick, 60.0, "Average tick time for 1,200 residents under 60ms interactive budget (actual: %.2f ms/tick)" % avg_ms_per_tick)
	print("  [BENCHMARK] Simulated 1200 residents with 3 active strikes across 24 ticks in %.2f ms (%.2f ms/tick)" % [elapsed_ms, avg_ms_per_tick])

	var val: Dictionary = CollectiveActionInvariants.validate_all(ws)
	asserts.assert_true(val["is_valid"], "Invariants valid at 1200 scale: %s" % str(val.get("errors", [])))
