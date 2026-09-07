class_name TestGodotWorld
extends RefCounted

const Reader = preload("res://src/presentation/physical_reader.gd")

func run_all(asserts: TestAsserts) -> void:
	_test_inspection_and_mappings(asserts)
	_test_scale_and_viewer_parity(asserts)

func make_engine(population: int, seed: int = 42) -> SimulationEngine:
	var engine := SimulationEngine.new(seed)
	var ws := engine.get_world_state()
	PopulationGenerator.generate_population(ws, population)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	engine.register_system(InstitutionSystem.new())
	engine.register_system(DailyLifeSystem.new())
	engine.register_system(MaintenanceSystem.new())
	engine.register_system(ProductionSystem.new())
	engine.register_system(WaterSystem.new())
	engine.register_system(IncidentSystem.new())
	return engine

func _test_inspection_and_mappings(asserts: TestAsserts) -> void:
	asserts.set_current_test("Godot physical world: real mappings and inspector")
	var engine := make_engine(1200)
	var ws := engine.get_world_state()
	var reg := ws.entity_registry
	var mapped := {"homes": 0, "beds": 0, "workers": 0, "workers_total": 0, "students": 0, "students_total": 0, "households": 0, "machines": 0}
	for pid in reg.get_entities_by_type("person"):
		var p: Person = reg.get_entity(pid)
		var room: Room = reg.get_entity(p.home_room_id)
		var household: Household = reg.get_entity(p.household_id)
		if room and household and household.home_room_id == room.id and p.id in household.member_ids: mapped["homes"] += 1
		if room and room.get_occupant_of_bed(p.bed_id) == p.id: mapped["beds"] += 1
		if p.shift_id != Occupation.SHIFT_OFF and p.occupation_id != "student":
			mapped["workers_total"] += 1
			if reg.get_entity(p.workplace_room_id) is Room: mapped["workers"] += 1
		if p.occupation_id == "student":
			mapped["students_total"] += 1
			var school: Room = reg.get_entity(p.school_room_id)
			if school and school.room_type == Room.TYPE_SCHOOL: mapped["students"] += 1
	for hid in reg.get_entities_by_type("household"):
		var h: Household = reg.get_entity(hid)
		if reg.get_entity(h.home_room_id) is Room: mapped["households"] += 1
	for mid in reg.get_entities_by_type("machine"):
		var m: Machine = reg.get_entity(mid)
		if reg.get_entity(m.room_id) is Room: mapped["machines"] += 1
	asserts.assert_eq(mapped["homes"], 1200, "every citizen belongs to a real household and home")
	asserts.assert_eq(mapped["beds"], 1200, "every citizen has their actual unique bed")
	asserts.assert_eq(mapped["workers"], mapped["workers_total"], "all working residents map to workplaces")
	asserts.assert_eq(mapped["students"], mapped["students_total"], "all students map to actual schools")
	asserts.assert_eq(mapped["households"], reg.get_entities_by_type("household").size(), "every household maps to quarters")
	asserts.assert_eq(mapped["machines"], reg.get_entities_by_type("machine").size(), "every machine maps to a real room")
	var first: Person = reg.get_entity(reg.get_entities_by_type("person")[0])
	var before := ws.get_state_checksum()
	var person := Reader.resolve_entity(ws, "person", str(first.id))
	asserts.assert_eq(person["details"]["bed_id"], first.bed_id, "inspector includes zero-based bed index")
	asserts.assert_eq(person["details"]["destination_id"], first.target_location_id, "inspector includes actual destination")
	asserts.assert_true(person["details"].has("schedule"), "inspector includes schedule source and assignments")
	var home := Reader.resolve_entity(ws, "room", str(first.home_room_id))
	asserts.assert_gt(home["details"]["households"].size(), 0, "home inspection exposes household")
	asserts.assert_gt(home["details"]["occupants"].size(), 0, "home inspection exposes people actually at home")
	asserts.assert_true(Reader.resolve_entity(ws, "machine", "999999").is_empty(), "unknown machine never falls back to another machine")
	var search := Reader.search(ws, str(first.id))
	asserts.assert_eq(search["results"][0]["id"], str(first.id), "ID search selects actual citizen")
	# Mutating returned copies must not alter authoritative household/bed records.
	home["details"]["occupied_beds"].clear()
	person["details"]["parent_ids"].clear()
	asserts.assert_eq(before, ws.get_state_checksum(), "inspection and returned copies are read-only")
	engine.step(1)
	var mapped_inventories := 0
	for iid in reg.get_entities_by_type("inventory"):
		var inv: Inventory = reg.get_entity(iid)
		var owner: Room = reg.get_entity(inv.owner_entity_id)
		if owner and owner.inventory_id == inv.id: mapped_inventories += 1
	asserts.assert_eq(mapped_inventories, reg.get_entities_by_type("inventory").size(), "production inventories map through actual room ownership")
	print("  GODOT_WORLD_MAPPING %s rooms=%d" % [JSON.stringify(mapped), reg.get_entities_by_type("room").size()])

func _test_scale_and_viewer_parity(asserts: TestAsserts) -> void:
	for population in [100, 500, 1200]:
		asserts.set_current_test("Godot physical world: %d population live day and determinism" % population)
		var a := make_engine(population)
		var b := make_engine(population)
		var wa := a.get_world_state()
		var wb := b.get_world_state()
		var activities := {}
		var work_arrivals := {}
		var school_arrivals := {}
		var max_queue := 0
		var max_occupancy := 0
		var capacity_valid := true
		var sim_usec := 0
		var projection_usec := 0
		var layout_a := SiloSpatialModel.build(wa)
		asserts.assert_eq(layout_a, SiloSpatialModel.build(wb), "same seed gives identical physical layout")
		for tick in range(144):
			var start := Time.get_ticks_usec()
			a.step(1)
			sim_usec += Time.get_ticks_usec() - start
			b.step(1)
			start = Time.get_ticks_usec()
			var live := Reader.get_updates(wb, tick, 0, false)
			projection_usec += Time.get_ticks_usec() - start
			for p in live["people"]:
				activities[p["activity"]] = true
				if p["activity"] == "WORKING": work_arrivals[p["id"]] = true
				if p["activity"] == "STUDYING": school_arrivals[p["id"]] = true
			for stair in live["stairs"]:
				max_queue = maxi(max_queue, int(stair["queue_length"]))
				max_occupancy = maxi(max_occupancy, int(stair["occupancy"]))
				capacity_valid = capacity_valid and int(stair["occupancy"]) <= int(stair["capacity"])
		asserts.assert_eq(wa.get_state_checksum(), wb.get_state_checksum(), "Godot live projections do not alter checksum through a day")
		asserts.assert_true(capacity_valid, "all stair occupancies obey capacity throughout day")
		asserts.assert_gt(max_occupancy, 0, "real residents traverse stairs")
		asserts.assert_gt(work_arrivals.size(), 0, "real workers reach work")
		asserts.assert_gt(school_arrivals.size(), 0, "real students reach school")
		asserts.assert_true(activities.has("SLEEPING") and activities.has("EATING") and activities.has("TRAVELING") and activities.has("RECREATING"), "daily life includes home, meals, travel and recreation")
		asserts.assert_lt(float(sim_usec) / 144000.0, 30.0, "physical simulation average tick under 30ms interactive budget")
		if population == 1200: asserts.assert_gt(max_queue, 0, "1200 resident shift traffic produces genuine queueing")
		print("  GODOT_WORLD_SCALE population=%d ticks=144 sim_ms_per_tick=%.3f projection_ms=%.3f max_occupancy=%d max_queue=%d workers_arrived=%d students_arrived=%d checksum=%s" % [population, float(sim_usec) / 144000.0, float(projection_usec) / 144000.0, max_occupancy, max_queue, work_arrivals.size(), school_arrivals.size(), str(wa.get_state_checksum())])
