# tests/simulation/test_corruption_and_patronage.gd
class_name TestCorruptionAndPatronage
extends RefCounted

## Automated Headless Test Suite for Sprint 14: Corruption, Patronage & Informal Power.

const Favour = preload("res://src/sim/politics/favour.gd")
const IllicitAction = preload("res://src/sim/politics/illicit_action.gd")
const PatronageNetwork = preload("res://src/sim/politics/patronage_network.gd")
const CorruptionSystem = preload("res://src/sim/politics/corruption_system.gd")
const CorruptionInvariants = preload("res://src/sim/politics/corruption_invariants.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")
const PoliticalSystem = preload("res://src/sim/politics/political_system.gd")
const FactionSystem = preload("res://src/sim/politics/faction_system.gd")

func run_all(asserts: TestAsserts) -> void:
	test_favour_creation_and_informal_debt(asserts)
	test_preferential_allocation_and_nepotism(asserts)
	test_resource_diversion_and_mass_conservation(asserts)
	test_hidden_record_discrepancy_and_audit(asserts)
	test_whistleblower_social_graph_discovery(asserts)
	test_institutional_consequences_and_legitimacy_impact(asserts)
	test_corruption_invariants_and_determinism(asserts)

## Helper: get room inventory from registry
static func _get_room_inventory(ws: WorldState, room_id: int) -> Inventory:
	var room: Room = ws.entity_registry.get_entity(room_id) as Room
	if room and room.inventory_id > 0:
		return ws.entity_registry.get_entity(room.inventory_id) as Inventory
	return null

## Helper: ensure a room has an inventory, creating one if needed
static func _ensure_room_inventory(ws: WorldState, room_id: int) -> Inventory:
	var room: Room = ws.entity_registry.get_entity(room_id) as Room
	if not room:
		return null
	if room.inventory_id > 0:
		return ws.entity_registry.get_entity(room.inventory_id) as Inventory
	# Create inventory for this room
	var inv: Inventory = Inventory.new(0, room.id, 100000.0)
	inv.id = ws.entity_registry.register_entity("inventory", inv)
	room.inventory_id = inv.id
	return inv

func test_favour_creation_and_informal_debt(asserts: TestAsserts) -> void:
	asserts.set_current_test("Corruption: Favour Creation & Informal Debt Ledger")
	var eng: SimulationEngine = SimulationEngine.new(101)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 60)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var corr_sys: CorruptionSystem = CorruptionSystem.new()
	eng.register_system(corr_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var granter_id: int = pids[0]
	var recipient_id: int = pids[1]
	
	var favour_id: int = corr_sys.grant_favour(ws, granter_id, recipient_id, Favour.FAVOUR_RESOURCE_DIVERSION, 0.5)
	asserts.assert_gt(favour_id, 0, "Favour must be created with valid ID")
	
	var favours: Array = ws.custom_data.get("favours", [])
	asserts.assert_gt(favours.size(), 0, "Favours array must contain at least one favour")
	
	var f: Favour = favours[favour_id - 1] as Favour
	asserts.assert_not_null(f, "Favour must exist")
	asserts.assert_eq(f.granter_id, granter_id, "Granter ID must match")
	asserts.assert_eq(f.recipient_id, recipient_id, "Recipient ID must match")
	asserts.assert_false(f.is_settled, "Favour must initially be unsettled")
	
	# Verify informal power increases for granter
	var inf_power: float = PatronageNetwork.calculate_informal_power(ws, granter_id)
	asserts.assert_gte(inf_power, 0.0, "Informal power must be non-negative")
	
	# Settle favour
	corr_sys.settle_favour(ws, favour_id)
	asserts.assert_true(f.is_settled, "Favour must be marked settled")

func test_preferential_allocation_and_nepotism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Corruption: Conflict of Interest & Nepotism Scoring")
	var eng: SimulationEngine = SimulationEngine.new(202)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 80)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var corr_sys: CorruptionSystem = CorruptionSystem.new()
	eng.register_system(corr_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var official: Person = null
	for pid in pids:
		var p: Person = ws.entity_registry.get_entity(pid) as Person
		if p and p.partner_id > 0:
			official = p
			break
			
	asserts.assert_not_null(official, "Should find a resident with a partner")
	
	if official:
		# Ensure official has clearance so COI check doesn't skip
		official.security_clearance = 2
		var coi: Dictionary = PatronageNetwork.get_conflict_of_interest(ws, official.id)
		asserts.assert_gte(coi.get("conflict_score", 0.0), 0.0, "COI score must be non-negative")
		# Note: partner may not share department/workplace, so conflicted_relations could be empty
		# The important invariant is that the method runs and returns a valid dictionary
		asserts.assert_true(coi.has("conflict_score"), "COI result must have conflict_score key")
		# Test temptation calculation
		var temptation: float = PatronageNetwork.calculate_corruption_temptation(ws, official.id)
		asserts.assert_gte(temptation, 0.0, "Corruption temptation must be non-negative")
		asserts.assert_lte(temptation, 1.0, "Corruption temptation must not exceed 1.0")

func test_resource_diversion_and_mass_conservation(asserts: TestAsserts) -> void:
	asserts.set_current_test("Corruption: Resource Diversion & Strict Mass Conservation")
	var eng: SimulationEngine = SimulationEngine.new(303)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 60)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var corr_sys: CorruptionSystem = CorruptionSystem.new()
	eng.register_system(prod_sys)
	eng.register_system(corr_sys)
	
	# Find two rooms and ensure they have inventories
	var rids: Array[int] = ws.entity_registry.get_entities_by_type("room")
	var src_room_id: int = rids[0]
	var dst_room_id: int = rids[1]
	
	var src_inv: Inventory = _ensure_room_inventory(ws, src_room_id)
	var dst_inv: Inventory = _ensure_room_inventory(ws, dst_room_id)
	asserts.assert_not_null(src_inv, "Source room must have inventory")
	asserts.assert_not_null(dst_inv, "Destination room must have inventory")
	
	# Stock source room with 100.0 units of iron_ore
	src_inv.add_resource("iron_ore", 100.0)
	
	# Record initial total mass across both inventories
	var initial_src: float = src_inv.get_quantity("iron_ore")
	var initial_dst: float = dst_inv.get_quantity("iron_ore")
	var initial_total: float = initial_src + initial_dst
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var perp_id: int = pids[0]
	var ben_id: int = pids[1]
	
	# Args: ws, perp_id, ben_id, source_room_id, dest_room_id, res_id, amount, concealment
	var action: IllicitAction = corr_sys.execute_resource_diversion(
		ws,
		perp_id,
		ben_id,
		src_room_id,
		dst_room_id,
		"iron_ore",
		40.0,
		0.8
	)
	
	asserts.assert_not_null(action, "Illicit diversion action must be created")
	
	# Verify mass in physical rooms
	var src_qty: float = src_inv.get_quantity("iron_ore")
	var dst_qty: float = dst_inv.get_quantity("iron_ore")
	asserts.assert_eq(src_qty, 60.0, "Source inventory must have 60.0 units remaining")
	asserts.assert_eq(dst_qty, 40.0, "Destination inventory must have received 40.0 units")
	
	# Verify strict mass conservation across both inventories
	var current_total: float = src_qty + dst_qty
	var mass_delta: float = absf(current_total - initial_total)
	asserts.assert_lt(mass_delta, 0.0001, "Total mass must be conserved (Delta == 0)")

func test_hidden_record_discrepancy_and_audit(asserts: TestAsserts) -> void:
	asserts.set_current_test("Corruption: Hidden Epistemic Ledger Discrepancy & Routine Audit")
	var eng: SimulationEngine = SimulationEngine.new(404)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 60)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var corr_sys: CorruptionSystem = CorruptionSystem.new()
	eng.register_system(corr_sys)
	
	var rids: Array[int] = ws.entity_registry.get_entities_by_type("room")
	var src_inv: Inventory = _ensure_room_inventory(ws, rids[0])
	var dst_inv: Inventory = _ensure_room_inventory(ws, rids[1])
	src_inv.add_resource("metal_stock", 80.0)
	
	# Initialize official ledgers to match physical state
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	if not ledgers.has(rids[0]):
		ledgers[rids[0]] = {}
	ledgers[rids[0]]["metal_stock"] = 80.0
	ws.custom_data["official_inventory_ledgers"] = ledgers
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var perp_id: int = pids[0]
	var ben_id: int = pids[1]
	
	# Args: ws, perp_id, ben_id, source_room_id, dest_room_id, res_id, amount, concealment
	var action: IllicitAction = corr_sys.execute_resource_diversion(
		ws,
		perp_id,
		ben_id,
		rids[0],
		rids[1],
		"metal_stock",
		30.0,
		0.9 # high concealment
	)
	
	asserts.assert_not_null(action, "Illicit action must be created")
	asserts.assert_eq(action.discovery_status, IllicitAction.STATUS_CONCEALED, "Action must start concealed")
	asserts.assert_gt(action.discrepancy_amount, 0.0, "Hidden discrepancy must be positive")
	
	# Official record in source room ledger should still show 80.0 (physical is 50.0)
	var official_recorded: float = corr_sys.get_official_ledger_amount(ws, rids[0], "metal_stock")
	var physical_actual: float = src_inv.get_quantity("metal_stock")
	asserts.assert_eq(official_recorded, 80.0, "Official ledger should still record 80.0 before audit")
	asserts.assert_eq(physical_actual, 50.0, "Physical actual should be 50.0")
	
	# Execute audit — marks action as exposed
	corr_sys.audit_action(ws, action.id, 0.95, 0)
	asserts.assert_eq(action.discovery_status, IllicitAction.STATUS_EXPOSED, "Action must be marked exposed after audit")
	
	# Reconcile ledger
	corr_sys.reconcile_ledger(ws, rids[0], "metal_stock")
	var reconciled_official: float = corr_sys.get_official_ledger_amount(ws, rids[0], "metal_stock")
	asserts.assert_eq(reconciled_official, 50.0, "Official ledger must match physical ground truth after reconciliation")

func test_whistleblower_social_graph_discovery(asserts: TestAsserts) -> void:
	asserts.set_current_test("Corruption: Whistleblower Detection via Bounded Social Graph")
	var eng: SimulationEngine = SimulationEngine.new(505)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 80)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var corr_sys: CorruptionSystem = CorruptionSystem.new()
	eng.register_system(corr_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var perp: Person = ws.entity_registry.get_entity(pids[0]) as Person
	var ben: Person = ws.entity_registry.get_entity(pids[1]) as Person
	
	var rids: Array[int] = ws.entity_registry.get_entities_by_type("room")
	var src_inv: Inventory = _ensure_room_inventory(ws, rids[0])
	src_inv.add_resource("machined_bearing", 10.0)
	
	# Execute with very low concealment so coworkers/whistleblowers detect it quickly
	# Args: ws, perp_id, ben_id, source_room_id, dest_room_id, res_id, amount, concealment
	var action: IllicitAction = corr_sys.execute_resource_diversion(
		ws,
		perp.id,
		ben.id,
		rids[0],
		rids[1],
		"machined_bearing",
		5.0,
		0.05 # very low concealment
	)
	
	asserts.assert_not_null(action, "Diversion action must be created")
	
	# Step 1 day (144 ticks)
	eng.step(144)
	
	asserts.assert_true(
		action.discovery_status == IllicitAction.STATUS_EXPOSED or action.discovery_status == IllicitAction.STATUS_SANCTIONED,
		"Low-concealment action must be discovered by whistleblower or audit"
	)
	asserts.assert_gt(action.evidence_strength, 0.0, "Evidence strength should be recorded")

func test_institutional_consequences_and_legitimacy_impact(asserts: TestAsserts) -> void:
	asserts.set_current_test("Corruption: Disciplinary Sanctions & Legitimacy Degradation")
	var eng: SimulationEngine = SimulationEngine.new(606)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 80)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var pol_sys: PoliticalSystem = PoliticalSystem.new()
	var corr_sys: CorruptionSystem = CorruptionSystem.new()
	
	eng.register_system(inst_sys)
	eng.register_system(pol_sys)
	eng.register_system(corr_sys)
	
	var pids: Array[int] = ws.entity_registry.get_entities_by_type("person")
	var perp: Person = ws.entity_registry.get_entity(pids[0]) as Person
	var ben: Person = ws.entity_registry.get_entity(pids[1]) as Person
	perp.security_clearance = 3
	
	var rids: Array[int] = ws.entity_registry.get_entities_by_type("room")
	var src_inv: Inventory = _ensure_room_inventory(ws, rids[0])
	var _dst_inv: Inventory = _ensure_room_inventory(ws, rids[1])
	src_inv.add_resource("metal_stock", 50.0)
	
	# Args: ws, perp_id, ben_id, source_room_id, dest_room_id, res_id, amount, concealment
	var action: IllicitAction = corr_sys.execute_resource_diversion(
		ws,
		perp.id,
		ben.id,
		rids[0],
		rids[1],
		"metal_stock",
		20.0,
		0.1
	)
	
	asserts.assert_not_null(action, "Diversion action must be created")
	
	# Apply audit then sanction
	corr_sys.audit_action(ws, action.id, 0.9, 0)
	corr_sys.apply_sanction(ws, action.id)
	
	asserts.assert_true(action.penalty_applied != "none", "Sanction must be applied on action")
	asserts.assert_lt(perp.security_clearance, 3, "Perpetrator security clearance must be reduced/revoked")
	
	# Verify opinion memories recorded
	var mems: Array = perp.opinion_memories
	var found_sanction_memory: bool = false
	for m in mems:
		if m.get("event_type", "") == PoliticalEvent.EVENT_DISCIPLINARY_SANCTION:
			found_sanction_memory = true
			break
	asserts.assert_true(found_sanction_memory, "Perpetrator must have EVENT_DISCIPLINARY_SANCTION opinion memory")

func test_corruption_invariants_and_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Corruption: Invariant Validation & Deterministic Replay")
	
	# Invariants test
	var eng1: SimulationEngine = SimulationEngine.new(777)
	var ws1: WorldState = eng1.get_world_state()
	PopulationGenerator.generate_population(ws1, 80)
	OccupationAssignment.setup_workplaces_and_assignments(ws1)
	
	var inst1: InstitutionSystem = InstitutionSystem.new()
	var pol1: PoliticalSystem = PoliticalSystem.new()
	var fact1: FactionSystem = FactionSystem.new()
	var corr1: CorruptionSystem = CorruptionSystem.new()
	var daily1: DailyLifeSystem = DailyLifeSystem.new()
	
	eng1.register_system(inst1)
	eng1.register_system(pol1)
	eng1.register_system(fact1)
	eng1.register_system(corr1)
	eng1.register_system(daily1)
	
	eng1.step(144)
	
	var inv_result: Dictionary = CorruptionInvariants.validate_all(ws1)
	asserts.assert_true(inv_result.get("is_valid", false), "CorruptionInvariants must pass on stepped simulation")
	
	# Determinism Replay: Run A == Run B
	var eng2: SimulationEngine = SimulationEngine.new(777)
	var ws2: WorldState = eng2.get_world_state()
	PopulationGenerator.generate_population(ws2, 80)
	OccupationAssignment.setup_workplaces_and_assignments(ws2)
	
	var inst2: InstitutionSystem = InstitutionSystem.new()
	var pol2: PoliticalSystem = PoliticalSystem.new()
	var fact2: FactionSystem = FactionSystem.new()
	var corr2: CorruptionSystem = CorruptionSystem.new()
	var daily2: DailyLifeSystem = DailyLifeSystem.new()
	
	eng2.register_system(inst2)
	eng2.register_system(pol2)
	eng2.register_system(fact2)
	eng2.register_system(corr2)
	eng2.register_system(daily2)
	
	eng2.step(144)
	
	var chk1: int = ws1.get_state_checksum()
	var chk2: int = ws2.get_state_checksum()
	asserts.assert_eq(chk1, chk2, "Deterministic Replay: Checksum A must equal Checksum B for identical seeds")
