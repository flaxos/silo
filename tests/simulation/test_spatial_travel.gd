extends RefCounted

const TravelModel = preload("res://src/sim/spatial/spatial_travel_model.gd")

func run_all(asserts: TestAsserts) -> void:
	test_layout_and_real_mappings(asserts)
	test_vertical_cost_and_stair_capacity(asserts)
	test_layout_and_travel_determinism(asserts)
	test_1200_resident_setup_performance(asserts)

func _world(seed: int, population: int) -> WorldState:
	var engine := SimulationEngine.new(seed)
	PopulationGenerator.generate_population(engine.get_world_state(), population)
	OccupationAssignment.setup_workplaces_and_assignments(engine.get_world_state())
	TravelModel.initialize(engine.get_world_state())
	return engine.get_world_state()

func test_layout_and_real_mappings(asserts: TestAsserts) -> void:
	asserts.set_current_test("Spatial: deterministic hierarchy and real mappings")
	var ws := _world(404, 120)
	var layout := SiloSpatialModel.build(ws)
	asserts.assert_eq(layout["levels"].size(), 20, "All populated silo levels are physical")
	asserts.assert_eq(layout["stair_segments"].size(), 19, "Adjacent levels have central stair segments")
	asserts.assert_eq(layout["landings"].size(), 20, "Every level has a landing")
	asserts.assert_eq(layout["portals"].size(), layout["rooms"].size(), "Every room has a portal")
	var housed := 0
	var mapped_workers := 0
	var mapped_students := 0
	for person_id in ws.entity_registry.get_entities_by_type("person"):
		var person: Person = ws.entity_registry.get_entity(person_id) as Person
		var home: Room = ws.entity_registry.get_entity(person.home_room_id) as Room
		if home and person.bed_id >= 0 and home.get_occupant_of_bed(person.bed_id) == person.id:
			housed += 1
		if person.occupation_id == "student" and ws.entity_registry.get_entity(person.school_room_id) is Room:
			mapped_students += 1
		elif person.workplace_room_id > 0 and ws.entity_registry.get_entity(person.workplace_room_id) is Room:
			mapped_workers += 1
	asserts.assert_eq(housed, 120, "Every resident maps to their real household bed")
	asserts.assert_gt(mapped_workers, 0, "Workers map to real workplace rooms")
	asserts.assert_gt(mapped_students, 0, "Students map to real school rooms")
	for machine_id in ws.entity_registry.get_entities_by_type("machine"):
		var machine: Machine = ws.entity_registry.get_entity(machine_id) as Machine
		asserts.assert_true(ws.entity_registry.get_entity(machine.room_id) is Room, "Machine maps to a real room")

func test_vertical_cost_and_stair_capacity(asserts: TestAsserts) -> void:
	asserts.set_current_test("Spatial: vertical cost, FIFO capacity, and congestion")
	var ws := _world(505, 80)
	var rooms: Array[int] = ws.entity_registry.get_entities_by_type("room")
	var level_one := 0
	var level_twenty := 0
	for room_id in rooms:
		var room: Room = ws.entity_registry.get_entity(room_id) as Room
		if room.level == 1 and level_one == 0: level_one = room.id
		if room.level == 20 and level_twenty == 0: level_twenty = room.id
	var near_ticks := TravelModel.compute_base_ticks(ws, level_one, level_one)
	var far_ticks := TravelModel.compute_base_ticks(ws, level_one, level_twenty)
	asserts.assert_gt(far_ticks, near_ticks, "Vertical distance increases commute time")
	var people: Array[int] = ws.entity_registry.get_entities_by_type("person")
	for i in range(TravelModel.SEGMENT_CAPACITY + 6):
		var person: Person = ws.entity_registry.get_entity(people[i]) as Person
		person.current_location_id = level_one
		TravelModel.begin_journey(ws, person, level_twenty, Person.ACTIVITY_WORKING)
	TravelModel.step(ws) # approach -> queue, then deterministic admission
	var state := TravelModel.get_state(ws)
	var first_segment: Dictionary = state["segments"][TravelModel.segment_id_for(1, 2)]
	asserts.assert_eq(first_segment["occupants"].size(), TravelModel.SEGMENT_CAPACITY, "Segment capacity is never exceeded")
	asserts.assert_eq(first_segment["queue"].size(), 6, "Excess travelers wait in a FIFO queue")
	TravelModel.step(ws)
	asserts.assert_gt(int(state["segments"][TravelModel.segment_id_for(2, 3)]["occupants"].size()), 0, "Capacity pressure propagates through the stair")
	asserts.assert_gt(int(state["maximum_queue"]), 0, "Congestion is recorded authoritatively")

func test_layout_and_travel_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Spatial: same seed same layout and queue state")
	var a := _world(606, 100)
	var b := _world(606, 100)
	asserts.assert_eq(SiloSpatialModel.build(a), SiloSpatialModel.build(b), "Same seed produces identical spatial layout")
	var a_people: Array[int] = a.entity_registry.get_entities_by_type("person")
	var b_people: Array[int] = b.entity_registry.get_entities_by_type("person")
	for i in range(40):
		var pa: Person = a.entity_registry.get_entity(a_people[i]) as Person
		var pb: Person = b.entity_registry.get_entity(b_people[i]) as Person
		TravelModel.begin_journey(a, pa, pa.canteen_room_id, Person.ACTIVITY_EATING)
		TravelModel.begin_journey(b, pb, pb.canteen_room_id, Person.ACTIVITY_EATING)
	for tick in range(20):
		TravelModel.step(a)
		TravelModel.step(b)
	asserts.assert_eq(a.get_state_checksum(), b.get_state_checksum(), "Travel occupancy and queues replay deterministically")

func test_1200_resident_setup_performance(asserts: TestAsserts) -> void:
	asserts.set_current_test("Spatial: 1200 resident setup performance")
	var start := Time.get_ticks_msec()
	var ws := _world(707, 1200)
	var layout := SiloSpatialModel.build(ws)
	var elapsed := Time.get_ticks_msec() - start
	asserts.assert_eq(ws.entity_registry.get_entities_by_type("person").size(), 1200, "Performance fixture contains 1200 residents")
	asserts.assert_gt(layout["rooms"].size(), 0, "1200-resident layout is generated")
	asserts.assert_lt(elapsed, 2000, "1200-resident spatial setup remains within 2 seconds")
