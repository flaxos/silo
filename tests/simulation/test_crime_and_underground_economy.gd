# tests/simulation/test_crime_and_underground_economy.gd
class_name TestCrimeAndUndergroundEconomy
extends RefCounted

## Automated Headless Test Suite for Sprint 17: Crime & Underground Economy.

const CrimeIncident = preload("res://src/sim/law/crime_incident.gd")
const CrimeSystem = preload("res://src/sim/law/crime_system.gd")
const CrimeInvariants = preload("res://src/sim/law/crime_invariants.gd")
const CrimeReader = preload("res://src/presentation/crime_reader.gd")
const UndergroundEconomy = preload("res://src/sim/law/underground_economy.gd")

const DailyLifeSystem = preload("res://src/sim/population/daily_life_system.gd")
const ProductionSystem = preload("res://src/sim/economy/production_system.gd")
const MaintenanceSystem = preload("res://src/sim/machinery/maintenance_system.gd")
const Machine = preload("res://src/sim/machinery/machine.gd")
const MachineComponent = preload("res://src/sim/machinery/machine_component.gd")

func run_all(asserts: TestAsserts) -> void:
	test_uat_a_grounded_theft_mass_conservation_and_downstream_impact(asserts)
	test_uat_b_motive_and_opportunity_emergence(asserts)
	test_uat_c_grounded_evidence_generation(asserts)
	test_uat_d_black_market_transactions_and_pricing(asserts)
	test_crime_invariants_and_determinism(asserts)
	test_1200_resident_scale_performance(asserts)

func test_uat_a_grounded_theft_mass_conservation_and_downstream_impact(asserts: TestAsserts) -> void:
	asserts.set_current_test("Crime UAT-A: Grounded Theft, Mass Conservation & Downstream Scarcity")
	var eng: SimulationEngine = SimulationEngine.new(401)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var crime_sys: CrimeSystem = CrimeSystem.new()
	eng.register_system(crime_sys)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var perp: Person = null
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.workplace_room_id > 0 and p.home_room_id > 0:
			perp = p
			break

	asserts.assert_not_null(perp, "Must find working resident")
	var work_room: Room = registry.get_entity(perp.workplace_room_id) as Room
	var home_room: Room = registry.get_entity(perp.home_room_id) as Room
	asserts.assert_not_null(work_room, "Must have workplace room")
	asserts.assert_not_null(home_room, "Must have residence room")

	var work_inv: Inventory = CrimeSystem._ensure_room_inventory(ws, work_room)
	var home_inv: Inventory = CrimeSystem._ensure_room_inventory(ws, home_room)

	# Stock workplace with 10 units of finished_bearing (0.5 kg each = 5.0 kg)
	work_inv.add_resource("finished_bearing", 10.0)
	var initial_home_bearings: float = home_inv.get_quantity("finished_bearing")

	var mass_before: float = 0.0
	for inv_id in registry.get_entities_by_type("inventory"):
		var inv: Inventory = registry.get_entity(inv_id) as Inventory
		if inv:
			mass_before += inv.get_total_mass_kg()

	# 1. Commit physical theft: steal 4 bearings
	var incident: CrimeIncident = crime_sys.commit_theft(
		ws,
		perp.id,
		work_room.id,
		home_room.id,
		"finished_bearing",
		4.0,
		0.7
	)

	asserts.assert_not_null(incident, "Theft incident created")
	asserts.assert_eq(incident.crime_type, CrimeIncident.TYPE_THEFT, "Type is theft")
	asserts.assert_eq(incident.quantity, 4.0, "Quantity is 4 units")

	# 2. Verify physical ground truth: goods actually vanished from workshop and moved to home
	asserts.assert_eq(work_inv.get_quantity("finished_bearing"), 6.0, "Workplace inventory decreased to 6 units")
	asserts.assert_eq(home_inv.get_quantity("finished_bearing"), initial_home_bearings + 4.0, "Household inventory increased by 4 units")

	# 3. Material conservation check: mass before == mass after
	var mass_after: float = 0.0
	for inv_id in registry.get_entities_by_type("inventory"):
		var inv: Inventory = registry.get_entity(inv_id) as Inventory
		if inv:
			mass_after += inv.get_total_mass_kg()

	asserts.assert_lt(absf(mass_before - mass_after), 0.0001, "Total system mass conserved perfectly during theft (0 kg created/destroyed)")

	# 4. Check official ledger discrepancy
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	asserts.assert_true(ledgers.has(work_room.id), "Ledger tracks workplace")
	var recorded_stock: float = float(ledgers[work_room.id].get("finished_bearing", 0.0))
	asserts.assert_eq(recorded_stock, 10.0, "Official ledger still records old 10 units (hidden discrepancy exists)")

	# 5. Verify through CrimeReader
	var trace: Dictionary = CrimeReader.get_crime_trace(ws, incident.id)
	asserts.assert_eq(trace["stolen_item"]["resource_id"], "finished_bearing", "Trace reports stolen resource")
	asserts.assert_eq(trace["evidence"]["inventory_discrepancy"], 4.0, "Trace records 4.0 unit discrepancy")

func test_uat_b_motive_and_opportunity_emergence(asserts: TestAsserts) -> void:
	asserts.set_current_test("Crime UAT-B: Motive & Opportunity Emergence")
	var eng: SimulationEngine = SimulationEngine.new(402)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var crime_sys: CrimeSystem = CrimeSystem.new()
	eng.register_system(crime_sys)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var workers: Array[Person] = []
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.life_stage == Person.STAGE_ADULT and p.workplace_room_id > 0 and p.home_room_id > 0:
			workers.append(p)
			if workers.size() >= 2:
				break

	asserts.assert_gt(workers.size(), 1, "Must find at least 2 working adults")
	var citizen_a: Person = workers[0]
	var citizen_b: Person = workers[1]

	# Citizen A: highly satisfied, well-supported -> motive should not trigger
	citizen_a.economic_satisfaction = 0.95
	citizen_a.class_resentment = 0.05
	citizen_a.hydration_percent = 100.0

	# Citizen B: severely deprived, hungry/thirsty, high resentment
	citizen_b.economic_satisfaction = 0.10
	citizen_b.class_resentment = 0.90
	citizen_b.hydration_percent = 10.0 # Severely dehydrated

	# Give citizen B's workplace some inventory
	var b_work: Room = registry.get_entity(citizen_b.workplace_room_id) as Room
	var inv: Inventory = CrimeSystem._ensure_room_inventory(ws, b_work)
	inv.add_resource("finished_bearing", 10.0)
	var b_home: Room = registry.get_entity(citizen_b.home_room_id) as Room
	CrimeSystem._ensure_room_inventory(ws, b_home)

	# Step 24 ticks (evaluation interval)
	eng.step(24)

	var crimes: Array[CrimeIncident] = crime_sys.get_all_crimes(ws)
	var perps: Array[int] = []
	for c in crimes:
		perps.append(c.perpetrator_id)

	asserts.assert_false(perps.has(citizen_a.id), "Satisfied citizen A did not commit crime")
	asserts.assert_true(perps.has(citizen_b.id), "Deprived citizen B was driven by motive and opportunity to commit theft")

func test_uat_c_grounded_evidence_generation(asserts: TestAsserts) -> void:
	asserts.set_current_test("Crime UAT-C: Grounded Physical Evidence Generation & Vandalism")
	var eng: SimulationEngine = SimulationEngine.new(403)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var crime_sys: CrimeSystem = CrimeSystem.new()
	eng.register_system(crime_sys)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var perp: Person = registry.get_entity(pids[0]) as Person
	var witness: Person = registry.get_entity(pids[1]) as Person

	# Place witness in the same room as perp
	var target_room_id: int = perp.workplace_room_id
	perp.current_location_id = target_room_id
	witness.current_location_id = target_room_id

	# Set up a machine in that room
	var machine: Machine = Machine.new(0, target_room_id, "primary_lathe")
	var comp: MachineComponent = MachineComponent.new("drive_spindle", "Spindle", 0.1, 1.0, "bearing", 1.0, 10)
	comp.wear_percent = 5.0
	machine.add_component(comp)
	machine.update_state()
	machine.id = registry.register_entity("machine", machine)

	# Commit vandalism
	var crime: CrimeIncident = crime_sys.commit_vandalism(
		ws,
		perp.id,
		machine.id,
		"drive_spindle",
		60.0,
		0.4
	)

	asserts.assert_not_null(crime, "Vandalism incident created")
	asserts.assert_eq(comp.wear_percent, 65.0, "Component wear increased physically to 65%")
	asserts.assert_eq(machine.state, Machine.STATE_DEGRADED, "Machine state physically degraded to DEGRADED")

	# Check evidence traces
	asserts.assert_true(crime.evidence["badge_log_recorded"], "Access system logged badge entry")
	var recorded_witnesses: Array = crime.evidence.get("witness_ids", [])
	asserts.assert_true(recorded_witnesses.has(witness.id), "Co-located person recorded as witness")
	asserts.assert_true(str(crime.evidence.get("physical_traces", "")).contains("drive_spindle"), "Physical traces identified damaged component")

func test_uat_d_black_market_transactions_and_pricing(asserts: TestAsserts) -> void:
	asserts.set_current_test("Crime UAT-D: Black Market Transactions & Security Pressure Pricing")
	var eng: SimulationEngine = SimulationEngine.new(404)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var buyer: Person = null
	var seller: Person = null
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.home_room_id > 0:
			if buyer == null:
				buyer = p
			elif seller == null and p.home_room_id != buyer.home_room_id:
				seller = p
				break

	asserts.assert_not_null(buyer, "Must find buyer")
	asserts.assert_not_null(seller, "Must find seller in different room")

	var buyer_room: Room = registry.get_entity(buyer.home_room_id) as Room
	var seller_room: Room = registry.get_entity(seller.home_room_id) as Room
	var buyer_inv: Inventory = CrimeSystem._ensure_room_inventory(ws, buyer_room)
	var seller_inv: Inventory = CrimeSystem._ensure_room_inventory(ws, seller_room)

	# Seller has 5 units of smuggled contraband (e.g. tools)
	seller_inv.add_resource("machined_parts", 5.0)
	# Buyer has 10 units of rations
	buyer_inv.add_resource("finished_bearing", 10.0)

	# 1. Verify dynamic pricing scales with security pressure
	var low_sec_price: float = UndergroundEconomy.calculate_black_market_price(10.0, 0.1)
	var high_sec_price: float = UndergroundEconomy.calculate_black_market_price(10.0, 0.9)
	asserts.assert_gt(high_sec_price, low_sec_price, "Black market prices higher under intense security pressure")

	# 2. Execute black market exchange: 2 units of machined_parts for 4 units of finished_bearing
	var res: Dictionary = UndergroundEconomy.execute_trade(
		ws,
		buyer.id,
		seller.id,
		"machined_parts",
		2.0,
		"finished_bearing",
		4.0
	)

	asserts.assert_true(res.get("success", false), "Black market trade succeeded")
	asserts.assert_eq(seller_inv.get_quantity("machined_parts"), 3.0, "Seller delivered goods")
	asserts.assert_eq(buyer_inv.get_quantity("machined_parts"), 2.0, "Buyer received goods")
	asserts.assert_eq(buyer_inv.get_quantity("finished_bearing"), 6.0, "Buyer paid payment")
	asserts.assert_eq(seller_inv.get_quantity("finished_bearing"), 4.0, "Seller received payment")

	var summary: Dictionary = CrimeReader.get_black_market_summary(ws)
	asserts.assert_eq(summary["total_deals_count"], 1, "Transaction recorded in black market read model")

func test_crime_invariants_and_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Crime: Invariants & Deterministic Replay")

	# Run A
	var eng_a: SimulationEngine = SimulationEngine.new(777)
	var ws_a: WorldState = eng_a.get_world_state()
	PopulationGenerator.generate_population(ws_a, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_a)

	var crime_a: CrimeSystem = CrimeSystem.new()
	var prod_a: ProductionSystem = ProductionSystem.new()
	var daily_a: DailyLifeSystem = DailyLifeSystem.new()
	eng_a.register_system(daily_a)
	eng_a.register_system(crime_a)
	eng_a.register_system(prod_a)

	var pids_a: Array[int] = ws_a.entity_registry.get_entities_by_type("person")
	var p_a: Person = ws_a.entity_registry.get_entity(pids_a[0]) as Person
	p_a.economic_satisfaction = 0.1
	p_a.class_resentment = 0.9

	eng_a.step(48)

	var val_a: Dictionary = CrimeInvariants.validate_all(ws_a)
	asserts.assert_true(val_a["is_valid"], "Run A crime invariants must be valid: %s" % str(val_a.get("errors", [])))
	var chk_a: int = ws_a.get_state_checksum()

	# Run B
	var eng_b: SimulationEngine = SimulationEngine.new(777)
	var ws_b: WorldState = eng_b.get_world_state()
	PopulationGenerator.generate_population(ws_b, 40)
	OccupationAssignment.setup_workplaces_and_assignments(ws_b)

	var crime_b: CrimeSystem = CrimeSystem.new()
	var prod_b: ProductionSystem = ProductionSystem.new()
	var daily_b: DailyLifeSystem = DailyLifeSystem.new()
	eng_b.register_system(daily_b)
	eng_b.register_system(crime_b)
	eng_b.register_system(prod_b)

	var pids_b: Array[int] = ws_b.entity_registry.get_entities_by_type("person")
	var p_b: Person = ws_b.entity_registry.get_entity(pids_b[0]) as Person
	p_b.economic_satisfaction = 0.1
	p_b.class_resentment = 0.9

	eng_b.step(48)

	var val_b: Dictionary = CrimeInvariants.validate_all(ws_b)
	asserts.assert_true(val_b["is_valid"], "Run B crime invariants must be valid: %s" % str(val_b.get("errors", [])))
	var chk_b: int = ws_b.get_state_checksum()

	asserts.assert_eq(chk_a, chk_b, "Simulation produces identical checksum (Run A == Run B)")

func test_1200_resident_scale_performance(asserts: TestAsserts) -> void:
	asserts.set_current_test("Crime: 1200 Resident Scale Performance Benchmark")
	var eng: SimulationEngine = SimulationEngine.new(999)
	var ws: WorldState = eng.get_world_state()
	PopulationGenerator.generate_population(ws, 1200)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var crime_sys: CrimeSystem = CrimeSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var prod_sys: ProductionSystem = ProductionSystem.new()
	eng.register_system(daily_life)
	eng.register_system(crime_sys)
	eng.register_system(prod_sys)

	var start_usec: int = Time.get_ticks_usec()

	# Simulate 24 ticks (4 hours)
	eng.step(24)

	var elapsed_ms: float = (Time.get_ticks_usec() - start_usec) / 1000.0
	var avg_ms_per_tick: float = elapsed_ms / 24.0

	asserts.assert_lt(avg_ms_per_tick, 60.0, "Average tick time for 1,200 residents under 60ms budget (actual: %.2f ms/tick)" % avg_ms_per_tick)
	print("  [BENCHMARK] Simulated 1200 residents with CrimeSystem across 24 ticks in %.2f ms (%.2f ms/tick)" % [elapsed_ms, avg_ms_per_tick])

	var val: Dictionary = CrimeInvariants.validate_all(ws)
	asserts.assert_true(val["is_valid"], "Invariants valid at 1200 scale: %s" % str(val.get("errors", [])))
