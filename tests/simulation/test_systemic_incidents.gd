# tests/simulation/test_systemic_incidents.gd
class_name TestSystemicIncidents
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_bearing_wear_and_repair_lifecycle(asserts)
	test_water_crisis_and_dehydration_cascade(asserts)
	test_spare_parts_stockout_detection(asserts)
	test_foundry_labor_starvation_detection(asserts)
	test_social_unrest_escalation_and_relief(asserts)
	test_incident_invariants_and_serialization(asserts)
	test_systemic_incidents_replay_determinism(asserts)

func test_bearing_wear_and_repair_lifecycle(asserts: TestAsserts) -> void:
	asserts.set_current_test("SystemicIncidents: Bearing Wear Alert and Repair Resolution")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()

	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var production: ProductionSystem = ProductionSystem.new()
	var maintenance: MaintenanceSystem = MaintenanceSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
	var inc_sys: IncidentSystem = IncidentSystem.new()

	engine.register_system(daily_life)
	engine.register_system(production)
	engine.register_system(maintenance)
	engine.register_system(water_sys)
	engine.register_system(inc_sys)

	# Initial 1-day nominal run
	engine.step(SimClock.TICKS_PER_DAY)
	asserts.assert_eq(inc_sys.get_active_incident_count(), 0, "No incidents should be active under nominal conditions")

	# Locate water pump and wear down its roller bearing to 88%
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	asserts.assert_gt(machine_ids.size(), 0, "At least one machine must exist")

	var pump: Machine = registry.get_entity(machine_ids[0]) as Machine
	asserts.assert_not_null(pump, "Water pump machine entity must exist")

	var bearing: MachineComponent = pump.get_component("bearing_roller_50mm")
	asserts.assert_not_null(bearing, "Roller bearing component must exist")
	bearing.wear_percent = 88.0
	pump.update_state()

	# Step engine by 1 tick to trigger incident detection
	engine.step(1)

	asserts.assert_eq(inc_sys.get_active_incident_count(), 1, "Incident should be raised for critical bearing wear")
	var active_incs: Array[Incident] = inc_sys.get_active_incidents()
	asserts.assert_eq(active_incs.size(), 1, "Should have 1 active incident")

	var inc: Incident = active_incs[0]
	asserts.assert_eq(inc.incident_type, Incident.INCIDENT_CRITICAL_PUMP_WEAR, "Incident type should be critical pump wear")
	asserts.assert_eq(inc.root_cause_entity_id, pump.id, "Root cause should link to pump ID")
	asserts.assert_true(inc.is_active, "Incident should be active")
	asserts.assert_eq(inc.resolved_tick, -1, "Resolved tick should be -1 while active")

	# Validate invariants with active incident
	var inv_val: Dictionary = IncidentInvariants.validate(ws)
	asserts.assert_true(inv_val["is_valid"], "Incident invariants must pass during critical wear: %s" % str(inv_val["errors"]))

	# Simulate technician completing repair (bearing restored to 0.0% wear)
	bearing.wear_percent = 0.0
	pump.update_state()

	engine.step(1)

	asserts.assert_eq(inc_sys.get_active_incident_count(), 0, "Incident should automatically resolve after repair")
	asserts.assert_eq(inc_sys.resolved_incidents.size(), 1, "Resolved incidents archive should contain 1 incident")

	var resolved_inc: Incident = inc_sys.resolved_incidents[0]
	asserts.assert_false(resolved_inc.is_active, "Resolved incident should have is_active == false")
	asserts.assert_gt(resolved_inc.resolved_tick, 0, "Resolved incident should record valid resolved_tick")

	# Validate invariants after resolution
	var post_val: Dictionary = IncidentInvariants.validate(ws)
	asserts.assert_true(post_val["is_valid"], "Incident invariants must pass after resolution: %s" % str(post_val["errors"]))

func test_water_crisis_and_dehydration_cascade(asserts: TestAsserts) -> void:
	asserts.set_current_test("SystemicIncidents: Water Depletion & Dehydration Cascade")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()

	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
	var inc_sys: IncidentSystem = IncidentSystem.new()

	engine.register_system(daily_life)
	engine.register_system(water_sys)
	engine.register_system(inc_sys)

	# 1. Stop water pump to simulate outage and deplete reservoir to 15% (15,000 L)
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	var pump: Machine = registry.get_entity(machine_ids[0]) as Machine
	pump.is_running = false
	pump.state = Machine.STATE_OFF

	water_sys.reservoir_current_liters = 15000.0
	ws.custom_data["water_reservoir_liters"] = 15000.0

	engine.step(1)

	asserts.assert_eq(inc_sys.get_active_incident_count(), 1, "Should raise water reservoir depleting incident")
	var active_incs: Array[Incident] = inc_sys.get_active_incidents()
	asserts.assert_eq(active_incs[0].incident_type, Incident.INCIDENT_WATER_RESERVOIR_DEPLETING, "Type must be reservoir depleting")
	asserts.assert_eq(active_incs[0].severity, Incident.SEVERITY_WARNING, "15% should be warning severity")

	# 2. Fully drain reservoir to 0.0 L and cause severe dehydration on 20 residents
	water_sys.reservoir_current_liters = 0.0
	ws.custom_data["water_reservoir_liters"] = 0.0

	var person_ids: Array[int] = registry.get_entities_by_type("person")
	for i in range(20):
		var p: Person = registry.get_entity(person_ids[i]) as Person
		p.hydration_percent = 15.0

	engine.step(1)

	asserts.assert_eq(inc_sys.get_active_incident_count(), 2, "Should have 2 active incidents (reservoir + dehydration)")

	var water_inc: Incident = null
	var dehy_inc: Incident = null
	for inc in inc_sys.get_active_incidents():
		if inc.incident_type == Incident.INCIDENT_WATER_RESERVOIR_DEPLETING:
			water_inc = inc
		elif inc.incident_type == Incident.INCIDENT_DEHYDRATION_EPIDEMIC:
			dehy_inc = inc

	asserts.assert_not_null(water_inc, "Reservoir depleting incident must exist")
	asserts.assert_not_null(dehy_inc, "Dehydration epidemic incident must exist")
	asserts.assert_eq(water_inc.severity, Incident.SEVERITY_EMERGENCY, "Empty reservoir must escalate to EMERGENCY severity")
	asserts.assert_eq(dehy_inc.severity, Incident.SEVERITY_WARNING, "20% dehydrated population should be WARNING severity")

	var inv_val: Dictionary = IncidentInvariants.validate(ws)
	asserts.assert_true(inv_val["is_valid"], "Invariants must hold during multi-incident cascade: %s" % str(inv_val["errors"]))

	# 3. Restart pump, refill reservoir and rehydrate residents to nominal
	pump.is_running = true
	pump.state = Machine.STATE_NOMINAL
	water_sys.reservoir_current_liters = 75000.0
	ws.custom_data["water_reservoir_liters"] = 75000.0
	for i in range(20):
		var p: Person = registry.get_entity(person_ids[i]) as Person
		p.hydration_percent = 100.0

	engine.step(1)

	asserts.assert_eq(inc_sys.get_active_incident_count(), 0, "All incidents should auto-resolve when conditions normalize")
	asserts.assert_eq(inc_sys.resolved_incidents.size(), 2, "2 incidents should be archived in resolved history")

func test_spare_parts_stockout_detection(asserts: TestAsserts) -> void:
	asserts.set_current_test("SystemicIncidents: Spare Parts Stockout Detection")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()

	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var production: ProductionSystem = ProductionSystem.new()
	var maintenance: MaintenanceSystem = MaintenanceSystem.new()
	var inc_sys: IncidentSystem = IncidentSystem.new()

	engine.register_system(daily_life)
	engine.register_system(production)
	engine.register_system(maintenance)
	engine.register_system(inc_sys)

	# Set machine wear to 75% (degraded, requiring maintenance)
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	var m: Machine = registry.get_entity(machine_ids[0]) as Machine
	var comp: MachineComponent = m.get_component("bearing_roller_50mm")
	comp.wear_percent = 75.0
	m.update_state()

	# Remove all machined_bearing from all room inventories
	var room_ids: Array[int] = registry.get_entities_by_type("room")
	for rid in room_ids:
		var r: Room = registry.get_entity(rid) as Room
		if r and r.inventory_id > 0:
			var inv: Inventory = registry.get_entity(r.inventory_id) as Inventory
			if inv and inv.stocks.has(ResourceRegistry.RES_MACHINED_BEARING):
				inv.stocks[ResourceRegistry.RES_MACHINED_BEARING] = 0.0

	engine.step(1)

	asserts.assert_gt(inc_sys.get_active_incident_count(), 0, "Should detect spare parts stockout")
	var found_stockout: bool = false
	for inc in inc_sys.get_active_incidents():
		if inc.incident_type == Incident.INCIDENT_SPARE_PARTS_STOCKOUT:
			found_stockout = true
			asserts.assert_eq(str(inc.telemetry_data.get("resource_id")), ResourceRegistry.RES_MACHINED_BEARING, "Stockout resource should be machined_bearing")
	asserts.assert_true(found_stockout, "INCIDENT_SPARE_PARTS_STOCKOUT must be raised")

	# Add replacement bearings back to a room inventory
	var shop_room: Room = registry.get_entity(m.room_id) as Room
	var shop_inv: Inventory = registry.get_entity(shop_room.inventory_id) as Inventory
	shop_inv.add_resource(ResourceRegistry.RES_MACHINED_BEARING, 5.0)

	engine.step(1)

	var stockout_still_active: bool = false
	for inc in inc_sys.get_active_incidents():
		if inc.incident_type == Incident.INCIDENT_SPARE_PARTS_STOCKOUT:
			stockout_still_active = true
	asserts.assert_false(stockout_still_active, "Stockout incident must resolve when spare parts are restocked")

func test_foundry_labor_starvation_detection(asserts: TestAsserts) -> void:
	asserts.set_current_test("SystemicIncidents: Foundry Labor Starvation Detection")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()

	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var inc_sys: IncidentSystem = IncidentSystem.new()
	engine.register_system(inc_sys)

	# Initial step with standard staffing
	engine.step(1)
	asserts.assert_eq(inc_sys.get_active_incident_count(), 0, "No labor starvation when foundry is staffed")

	# Unassign all foundry operators
	var registry: EntityRegistry = ws.entity_registry
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	var foundry_pids: Array[int] = []
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if p and (p.occupation_id == "foundry_worker" or p.occupation_id == "furnace_operator"):
			p.occupation_id = "unassigned"
			foundry_pids.append(pid)

	engine.step(1)

	asserts.assert_eq(inc_sys.get_active_incident_count(), 1, "Labor starvation incident should be detected")
	var inc: Incident = inc_sys.get_active_incidents()[0]
	asserts.assert_eq(inc.incident_type, Incident.INCIDENT_FOUNDRY_LABOR_STARVATION, "Type must be foundry labor starvation")

	# Re-assign workers back to foundry
	for pid in foundry_pids:
		var p: Person = registry.get_entity(pid) as Person
		p.occupation_id = "foundry_worker"

	engine.step(1)
	asserts.assert_eq(inc_sys.get_active_incident_count(), 0, "Labor starvation incident must resolve upon re-staffing")

func test_social_unrest_escalation_and_relief(asserts: TestAsserts) -> void:
	asserts.set_current_test("SystemicIncidents: Social Unrest Escalation & Relief")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()

	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var inc_sys: IncidentSystem = IncidentSystem.new()

	engine.register_system(inst_sys)
	engine.register_system(inc_sys)

	engine.step(1)
	asserts.assert_eq(inc_sys.get_active_incident_count(), 0, "No social unrest at baseline tension")

	# Escalate tension above warning threshold (e.g. 60.0)
	inst_sys.social_tension_index = 60.0

	engine.step(1)

	asserts.assert_eq(inc_sys.get_active_incident_count(), 1, "Should raise social unrest incident")
	var inc: Incident = inc_sys.get_active_incidents()[0]
	asserts.assert_eq(inc.incident_type, Incident.INCIDENT_SOCIAL_UNREST, "Type must be social unrest")
	asserts.assert_eq(inc.severity, Incident.SEVERITY_WARNING, "Tension 60 should be WARNING severity")

	# Escalate further to 85.0
	inst_sys.social_tension_index = 85.0
	engine.step(1)
	asserts.assert_eq(inc.severity, Incident.SEVERITY_CRITICAL, "Tension 85 should escalate incident to CRITICAL severity")

	# Relax tension to nominal
	inst_sys.social_tension_index = 20.0
	engine.step(1)
	asserts.assert_eq(inc_sys.get_active_incident_count(), 0, "Social unrest incident should resolve when tension normalizes")

func test_incident_invariants_and_serialization(asserts: TestAsserts) -> void:
	asserts.set_current_test("SystemicIncidents: Invariants & Full Serialization Roundtrip")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()

	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)

	var inst_sys: InstitutionSystem = InstitutionSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(15000.0, 100000.0)
	var inc_sys: IncidentSystem = IncidentSystem.new()

	engine.register_system(inst_sys)
	engine.register_system(water_sys)
	engine.register_system(inc_sys)

	# Create conditions for 2 incidents
	inst_sys.social_tension_index = 55.0
	engine.step(1)

	asserts.assert_eq(inc_sys.get_active_incident_count(), 2, "Should have 2 active incidents (reservoir + unrest)")

	# Validate invariants
	var inv_val: Dictionary = IncidentInvariants.validate(ws)
	asserts.assert_true(inv_val["is_valid"], "Incident invariants must pass: %s" % str(inv_val["errors"]))

	# Serialize IncidentSystem
	var saved_dict: Dictionary = inc_sys.serialize()
	asserts.assert_true(saved_dict.has("active_incidents"), "Serialized dict must have active_incidents")
	asserts.assert_true(saved_dict.has("resolved_incidents"), "Serialized dict must have resolved_incidents")
	asserts.assert_eq((saved_dict["active_incidents"] as Dictionary).size(), 2, "Serialized active incidents count must be 2")

	# Deserialize into new system
	var new_inc_sys: IncidentSystem = IncidentSystem.new()
	new_inc_sys.deserialize(saved_dict)

	asserts.assert_eq(new_inc_sys.get_active_incident_count(), 2, "Deserialized system must have 2 active incidents")
	asserts.assert_eq(new_inc_sys.total_incidents_raised, inc_sys.total_incidents_raised, "Total raised count must match")

func test_systemic_incidents_replay_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("SystemicIncidents: Multi-System 7-Day Replay Determinism")

	var run_simulation = func(seed_val: int) -> Dictionary:
		var engine: SimulationEngine = SimulationEngine.new(seed_val)
		var ws: WorldState = engine.get_world_state()

		PopulationGenerator.generate_population(ws, 100)
		OccupationAssignment.setup_workplaces_and_assignments(ws)

		var inst_sys: InstitutionSystem = InstitutionSystem.new()
		var daily_life: DailyLifeSystem = DailyLifeSystem.new()
		var production: ProductionSystem = ProductionSystem.new()
		var maintenance: MaintenanceSystem = MaintenanceSystem.new()
		var water_sys: WaterSystem = WaterSystem.new(50000.0, 100000.0)
		var inc_sys: IncidentSystem = IncidentSystem.new()

		engine.register_system(inst_sys)
		engine.register_system(daily_life)
		engine.register_system(production)
		engine.register_system(maintenance)
		engine.register_system(water_sys)
		engine.register_system(inc_sys)

		# Simulate 7 days (1,008 ticks)
		engine.step(7 * SimClock.TICKS_PER_DAY)

		return {
			"checksum": engine.get_state_checksum(),
			"active_incidents": inc_sys.get_active_incident_count(),
			"resolved_incidents": inc_sys.resolved_incidents.size(),
			"total_raised": inc_sys.total_incidents_raised,
			"reservoir": water_sys.reservoir_current_liters,
			"tension": inst_sys.social_tension_index
		}

	var run_a: Dictionary = run_simulation.call(42)
	var run_b: Dictionary = run_simulation.call(42)

	asserts.assert_eq(run_a["checksum"], run_b["checksum"], "Run A and Run B checksums must match identically (Seed 42)")
	asserts.assert_eq(run_a["active_incidents"], run_b["active_incidents"], "Active incident counts must match")
	asserts.assert_eq(run_a["resolved_incidents"], run_b["resolved_incidents"], "Resolved incident counts must match")
	asserts.assert_eq(run_a["total_raised"], run_b["total_raised"], "Total raised incidents must match")
