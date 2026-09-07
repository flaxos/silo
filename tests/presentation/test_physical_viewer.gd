class_name TestPhysicalViewer
extends RefCounted

const SpatialModel = preload("res://src/sim/spatial/silo_spatial_model.gd")
const Reader = preload("res://src/presentation/physical_reader.gd")

func run_all(asserts: TestAsserts) -> void:
	test_geometry_and_references(asserts)
	test_updates_resolution_and_read_only(asserts)
	test_1200_snapshot_performance(asserts)
	test_full_day_observer_determinism(asserts)

func _world(population: int, seed: int) -> Array:
	var engine: SimulationEngine = SimulationEngine.new(seed)
	var ws: WorldState = engine.get_world_state()
	PopulationGenerator.generate_population(ws, population)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	engine.register_system(InstitutionSystem.new())
	engine.register_system(DailyLifeSystem.new())
	engine.register_system(MaintenanceSystem.new())
	engine.register_system(ProductionSystem.new())
	engine.register_system(WaterSystem.new(50000.0, 100000.0))
	engine.register_system(IncidentSystem.new())
	return [engine, ws]

func test_geometry_and_references(asserts: TestAsserts) -> void:
	asserts.set_current_test("PhysicalViewer: deterministic geometry and references")
	var a: Array = _world(100, 42)
	var before: int = a[1].get_state_checksum()
	var one: Dictionary = SpatialModel.build(a[1])
	var two: Dictionary = SpatialModel.build(a[1])
	asserts.assert_eq(one, two, "geometry is stable")
	asserts.assert_eq(before, a[1].get_state_checksum(), "geometry query is read-only")
	asserts.assert_gt(one["rooms"].size(), 0, "rooms physicalised")
	var snapshot: Dictionary = Reader.get_snapshot(a[1])
	print("  PHYSICAL_VIEWER_UNRESOLVED=%s" % str(snapshot["unresolved_links"]))
	asserts.assert_eq(snapshot["people"].size(), 100, "all residents projected")
	var unresolved_work: int = 0
	for person in snapshot["people"]:
		asserts.assert_true(a[1].entity_registry.get_entity(int(person["home_room_id"])) is Room, "person home resolves")
		if person["occupation_id"] not in ["unassigned", "none", "student"] and int(person["workplace_room_id"]) <= 0:
			unresolved_work += 1
	asserts.assert_eq(snapshot["unresolved_links"].size(), unresolved_work, "every actual unwired workplace is explicitly audited")
	for machine in snapshot["machines"]:
		asserts.assert_true(int(machine["room_id"]) > 0 and a[1].entity_registry.get_entity(int(machine["room_id"])) is Room, "machine location resolves")

func test_updates_resolution_and_read_only(asserts: TestAsserts) -> void:
	asserts.set_current_test("PhysicalViewer: API projections, deltas, selection")
	var a: Array = _world(100, 77)
	var engine: SimulationEngine = a[0]
	var ws: WorldState = a[1]
	var first: Person = ws.entity_registry.get_entity(ws.entity_registry.get_entities_by_type("person")[0]) as Person
	var checksum: int = ws.get_state_checksum()
	var selected: Dictionary = Reader.resolve_entity(ws, "person", str(first.id))
	asserts.assert_eq(selected["room_id"], first.current_location_id, "person selection focuses actual room")
	asserts.assert_eq(checksum, ws.get_state_checksum(), "selection is read-only")
	asserts.assert_eq(Reader.get_updates(ws, 0)["people"].size(), 0, "same revision returns no people")
	engine.step(1)
	var update: Dictionary = Reader.get_updates(ws, 0)
	asserts.assert_eq(update["people"].size(), 100, "advanced revision emits live residents")
	asserts.assert_true(update.has("machines") and update.has("utilities") and update.has("incidents"), "live systems included")

func test_1200_snapshot_performance(asserts: TestAsserts) -> void:
	asserts.set_current_test("PhysicalViewer: 1200 resident snapshot performance")
	var a: Array = _world(1200, 42)
	var start: int = Time.get_ticks_usec()
	var snapshot: Dictionary = Reader.get_snapshot(a[1])
	var elapsed_ms: float = float(Time.get_ticks_usec() - start) / 1000.0
	asserts.assert_eq(snapshot["people"].size(), 1200, "all 1200 residents inspectable")
	asserts.assert_lt(elapsed_ms, 2000.0, "snapshot generated within two seconds (%s ms)" % elapsed_ms)
	print("  PHYSICAL_VIEWER_1200_SNAPSHOT_MS=%.3f ROOMS=%d HOUSEHOLDS=%d MACHINES=%d" % [elapsed_ms, snapshot["rooms"].size(), snapshot["households"].size(), snapshot["machines"].size()])

func test_full_day_observer_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("PhysicalViewer: full-day observer determinism")
	var a: Array = _world(100, 901)
	var b: Array = _world(100, 901)
	for tick in range(SimClock.TICKS_PER_DAY):
		a[0].step(1)
		b[0].step(1)
		var _updates: Dictionary = Reader.get_updates(b[1], tick)
		if tick % 12 == 0:
			var _snapshot: Dictionary = Reader.get_snapshot(b[1])
	var checksum_a: int = a[1].get_state_checksum()
	var checksum_b: int = b[1].get_state_checksum()
	print("  PHYSICAL_VIEWER_CHECKSUM_A=%d CHECKSUM_B=%d" % [checksum_a, checksum_b])
	asserts.assert_eq(checksum_a, checksum_b, "viewer queries do not affect authoritative simulation")
