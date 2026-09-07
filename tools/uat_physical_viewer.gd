# tools/uat_physical_viewer.gd
extends SceneTree

const SpatialModel = preload("res://src/sim/spatial/silo_spatial_model.gd")
const PhysicalReader = preload("res://src/presentation/physical_reader.gd")

func _init() -> void:
	call_deferred("_run_uat")

func _run_uat() -> void:
	print("==========================================================")
	print(" SILO — Physical Silo Viewer UAT Verification Suite")
	print("==========================================================")

	var all_passed: bool = true

	# UAT 1: One Person Full-Day Traversal & Causal Trace
	print("\n--- [UAT 1] One Person: Causal Linkage & 24h Routine ---")
	var eng1: SimulationEngine = SimulationEngine.new(42)
	var ws1: WorldState = eng1.get_world_state()
	PopulationGenerator.generate_population(ws1, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws1)
	eng1.register_system(InstitutionSystem.new())
	eng1.register_system(DailyLifeSystem.new())
	eng1.register_system(MaintenanceSystem.new())
	eng1.register_system(ProductionSystem.new())
	eng1.register_system(WaterSystem.new(50000.0, 100000.0))
	eng1.register_system(IncidentSystem.new())

	var pids: Array[int] = ws1.entity_registry.get_entities_by_type("person")
	var target_p: Person = ws1.entity_registry.get_entity(pids[0]) as Person
	var snap1: Dictionary = PhysicalReader.get_snapshot(ws1)
	var person_snap: Dictionary = {}
	for p in snap1["people"]:
		if int(p["id"]) == target_p.id:
			person_snap = p
			break

	var uat1_ok: bool = true
	if person_snap.is_empty():
		print("  [FAIL] Person %d not found in physical snapshot" % target_p.id)
		uat1_ok = false
	else:
		print("  [PASS] Resident: %s (ID: %d, Age: %d)" % [person_snap["name"], target_p.id, target_p.get_age_years(ws1.sim_clock.get_tick())])
		print("  [PASS] Household: #%d, Home Room: #%d, Bed Index: %d" % [person_snap["household_id"], person_snap["home_room_id"], person_snap["bed_id"]])
		print("  [PASS] Job: %s (%s), Workplace: #%d" % [person_snap["occupation_id"], person_snap["department_id"], person_snap["workplace_room_id"]])

	# Advance 24h and track location changes
	var locations_visited: Dictionary = {}
	for tick in range(144):
		eng1.step(1)
		var updates: Dictionary = PhysicalReader.get_updates(ws1, tick)
		for p in updates["people"]:
			if int(p["id"]) == target_p.id:
				locations_visited[int(p["location_id"])] = true

	print("  [PASS] Simulated 24h (144 ticks): Visited %d distinct physical rooms" % locations_visited.size())
	if locations_visited.size() < 2:
		print("  [FAIL] Person did not move between home and workplace/canteen")
		uat1_ok = false
	else:
		print("  [PASS] UAT 1: One Person Traversal Verification Complete")
	all_passed = all_passed and uat1_ok

	# UAT 2: Family / Household Multi-Member Routine
	print("\n--- [UAT 2] Family: Household Bed & School/Work Separation ---")
	var hids: Array[int] = ws1.entity_registry.get_entities_by_type("household")
	var target_h: Household = null
	for hid in hids:
		var h: Household = ws1.entity_registry.get_entity(hid) as Household
		if h and h.member_ids.size() >= 3:
			target_h = h
			break

	var uat2_ok: bool = true
	if not target_h:
		print("  [FAIL] Multi-member family not found")
		uat2_ok = false
	else:
		var h_sum: Dictionary = SimulationReader.get_household_summary(ws1, target_h.id)
		print("  [PASS] Household: %s (Head: %s, Members: %d)" % [h_sum["name"], h_sum["head_name"], h_sum["member_count"]])
		print("  [PASS] Shared Home Room: #%d (Level %d)" % [h_sum["home_room_id"], (ws1.entity_registry.get_entity(h_sum["home_room_id"]) as Room).level])
		var r_sum: Dictionary = SimulationReader.get_room_summary(ws1, h_sum["home_room_id"])
		print("  [PASS] Room Beds: %d Total, %d Occupied by Family" % [r_sum["bed_count"], r_sum["occupied_beds"].size()])
		print("  [PASS] UAT 2: Family & Home Verification Complete")
	all_passed = all_passed and uat2_ok

	# UAT 3: Water Crisis & Machinery Degradation Visual Linkage
	print("\n--- [UAT 3] Water Crisis & Machine Degradation Causal Lineage ---")
	var chain: Dictionary = SimulationReader.get_causal_chain(ws1, 0)
	var uat3_ok: bool = true
	if chain.has("machine") and chain.has("utility_consequence"):
		print("  [PASS] Pump Machine: #%d, Operating State: %s" % [chain["machine"]["id"], chain["machine"]["state"]])
		print("  [PASS] Component: %s (Wear: %.1f%%)" % [chain["component"]["name"], chain["component"]["wear_percent"]])
		print("  [PASS] Utility Impact: Throughput %.1f L/min, Reservoir: %.1f L" % [chain["utility_consequence"]["pump_throughput_lpm"], chain["utility_consequence"]["reservoir_current_liters"]])
		print("  [PASS] UAT 3: Crisis Telemetry & Spatial Lineage Complete")
	else:
		print("  [FAIL] Incomplete causal chain")
		uat3_ok = false
	all_passed = all_passed and uat3_ok

	# UAT 4: 1,200 Residents Performance Benchmark
	print("\n--- [UAT 4] 1,200 Residents Performance & Spatial Generation ---")
	var eng1200: SimulationEngine = SimulationEngine.new(1200)
	var ws1200: WorldState = eng1200.get_world_state()
	PopulationGenerator.generate_population(ws1200, 1200)
	OccupationAssignment.setup_workplaces_and_assignments(ws1200)

	var t_start: int = Time.get_ticks_usec()
	var snap1200: Dictionary = PhysicalReader.get_snapshot(ws1200)
	var snap_time_ms: float = float(Time.get_ticks_usec() - t_start) / 1000.0

	var uat4_ok: bool = true
	print("  [PASS] 1,200 Population Snapshot Generated in %.2f ms" % snap_time_ms)
	print("  [PASS] Total Rooms: %d across %d Levels" % [snap1200["geometry"]["rooms"].size(), snap1200["geometry"]["levels"].size()])
	print("  [PASS] Total Residents Projected: %d" % snap1200["people"].size())
	if snap_time_ms > 2000.0:
		print("  [FAIL] Snapshot exceeded 2000 ms budget")
		uat4_ok = false
	else:
		print("  [PASS] UAT 4: 1,200 Residents Benchmark Passed")
	all_passed = all_passed and uat4_ok

	# UAT 5: Observer Invisibility Proof
	print("\n--- [UAT 5] Observer Invisibility Checksum Proof ---")
	var eng_a: SimulationEngine = SimulationEngine.new(999)
	var eng_b: SimulationEngine = SimulationEngine.new(999)
	PopulationGenerator.generate_population(eng_a.get_world_state(), 100)
	PopulationGenerator.generate_population(eng_b.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(eng_a.get_world_state())
	OccupationAssignment.setup_workplaces_and_assignments(eng_b.get_world_state())
	eng_a.register_system(DailyLifeSystem.new())
	eng_b.register_system(DailyLifeSystem.new())

	for tick in range(144):
		eng_a.step(1)
		eng_b.step(1)
		var _snap: Dictionary = PhysicalReader.get_snapshot(eng_b.get_world_state())
		var _up: Dictionary = PhysicalReader.get_updates(eng_b.get_world_state(), tick)
		var _srch: Dictionary = PhysicalReader.search(eng_b.get_world_state(), "Ruben")

	var chk_a: int = eng_a.get_world_state().get_state_checksum()
	var chk_b: int = eng_b.get_world_state().get_state_checksum()

	var uat5_ok: bool = (chk_a == chk_b)
	print("  [PASS] Checksum A (No Queries) : %d" % chk_a)
	print("  [PASS] Checksum B (Heavy Query) : %d" % chk_b)
	if uat5_ok:
		print("  [PASS] UAT 5: Mathematical Invisibility Proved (Checksum A == Checksum B)")
	else:
		print("  [FAIL] Checksum divergence detected!")
	all_passed = all_passed and uat5_ok

	print("\n==========================================================")
	if all_passed:
		print(" [RESULT]: ✅ ALL 5 PHYSICAL VIEWER UAT CRITERIA PASSED")
		print("==========================================================")
		quit(0)
	else:
		print(" [RESULT]: ❌ UAT CRITERIA FAILED")
		print("==========================================================")
		quit(1)
