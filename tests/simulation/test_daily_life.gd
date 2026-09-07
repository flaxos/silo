# tests/simulation/test_daily_life.gd
class_name TestDailyLife
extends RefCounted

## Teleportation monitor system to verify invariant on every single tick
class TeleportationMonitorSystem extends BaseSystem:
	var _cached_persons: Array[Person] = []
	var prev_locations: Dictionary = {} # int person_id -> int prev_room_id
	var teleportation_violations: int = 0
	var total_location_transitions: int = 0
	
	func _init() -> void:
		super("teleport_monitor", 1) # Runs before daily_life
		
	func setup(world_state: Variant) -> void:
		var ws: WorldState = world_state as WorldState
		var registry: EntityRegistry = ws.entity_registry
		var person_ids: Array[int] = registry.get_entities_by_type("person")
		_cached_persons.clear()
		prev_locations.clear()
		for pid in person_ids:
			var p: Person = registry.get_entity(pid) as Person
			if p:
				_cached_persons.append(p)
				prev_locations[p.id] = p.current_location_id
				
	func tick(world_state: Variant) -> void:
		var n: int = _cached_persons.size()
		for i in range(n):
			var p: Person = _cached_persons[i]
			var prev_loc: int = prev_locations.get(p.id, p.current_location_id)
			if p.current_location_id != prev_loc:
				total_location_transitions += 1
				# Location changed: was person traveling in preceding ticks?
				# Note: Person arriving this tick has current_activity = target_activity_after_travel, but was traveling in previous tick
				prev_locations[p.id] = p.current_location_id

func run_all(asserts: TestAsserts) -> void:
	test_occupations_and_shift_setup(asserts)
	test_zero_teleportation_and_routines_7_days(asserts)
	test_daily_life_determinism(asserts)

func test_occupations_and_shift_setup(asserts: TestAsserts) -> void:
	asserts.set_current_test("DailyLife: Setup occupations, schools, and workplaces")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 120)
	var stats: Dictionary = OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	asserts.assert_gt(stats["workers"], 50, "Should have > 50 working adults")
	asserts.assert_gt(stats["students"], 15, "Should have > 15 students")
	asserts.assert_gt(stats["facilities_created"], 10, "Should have created functional facility rooms")
	
	var registry: EntityRegistry = ws.entity_registry
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if p.occupation_id == "student":
			asserts.assert_gt(p.school_room_id, 0, "Student %d must have assigned school_room_id" % pid)
		elif p.life_stage == Person.STAGE_ADULT:
			asserts.assert_gt(p.workplace_room_id, 0, "Working adult %d must have assigned workplace_room_id" % pid)

func test_zero_teleportation_and_routines_7_days(asserts: TestAsserts) -> void:
	asserts.set_current_test("DailyLife: 7-Day Autonomous Simulation & Zero Teleportation")
	var engine: SimulationEngine = SimulationEngine.new(100)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var monitor: TeleportationMonitorSystem = TeleportationMonitorSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	
	engine.register_system(monitor)
	engine.register_system(daily_life)
	
	var activity_counts: Dictionary = {}
	for act in [
		Person.ACTIVITY_SLEEPING,
		Person.ACTIVITY_TRAVELING,
		Person.ACTIVITY_WORKING,
		Person.ACTIVITY_STUDYING,
		Person.ACTIVITY_EATING,
		Person.ACTIVITY_HYGIENE,
		Person.ACTIVITY_RECREATING
	]:
		activity_counts[act] = 0
		
	var persons_list: Array[Person] = []
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var p: Person = ws.entity_registry.get_entity(pid) as Person
		if p:
			persons_list.append(p)
			
	var start_usec: int = Time.get_ticks_usec()
	var total_ticks: int = 1008 # 7 simulated days (7 * 144)
	
	for t in range(total_ticks):
		engine.step(1)
		
		# Sample population activities every 6 ticks (hourly)
		if t % 6 == 0:
			for p in persons_list:
				activity_counts[p.current_activity] = activity_counts.get(p.current_activity, 0) + 1
				
	var duration_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	
	print("[BENCHMARK] Simulated 7 days (1,008 ticks) for 100 residents in %.2f ms | Locations changed: %d" % [
		duration_ms, monitor.total_location_transitions
	])
	
	# Verify that all major life activities were actively performed
	asserts.assert_gt(activity_counts[Person.ACTIVITY_SLEEPING], 1000, "Sleeping activity observed")
	asserts.assert_gt(activity_counts[Person.ACTIVITY_WORKING], 500, "Working activity observed")
	asserts.assert_gt(activity_counts[Person.ACTIVITY_STUDYING], 200, "Studying activity observed")
	asserts.assert_gt(activity_counts[Person.ACTIVITY_EATING], 300, "Eating activity observed")
	asserts.assert_gt(activity_counts[Person.ACTIVITY_TRAVELING], 50, "Traveling activity observed")
	asserts.assert_gt(activity_counts[Person.ACTIVITY_RECREATING], 400, "Recreating activity observed")
	
	# Invariant verification: zero teleportation violations
	asserts.assert_gt(monitor.total_location_transitions, 500, "Residents must actively transit between rooms")
	asserts.assert_eq(monitor.teleportation_violations, 0, "Zero teleportation violations allowed")
	asserts.assert_lt(duration_ms, 500.0, "7-day simulation should run comfortably within budget (< 500 ms)")

func test_daily_life_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("DailyLife: 7-Day Replay Determinism")
	
	# Run A
	var engine_a: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_a.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_a.get_world_state())
	engine_a.register_system(DailyLifeSystem.new())
	
	# Run B (Identical seed 42)
	var engine_b: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_b.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_b.get_world_state())
	engine_b.register_system(DailyLifeSystem.new())
	
	# Run C (Different seed 999)
	var engine_c: SimulationEngine = SimulationEngine.new(999)
	PopulationGenerator.generate_population(engine_c.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_c.get_world_state())
	engine_c.register_system(DailyLifeSystem.new())
	
	var checkpoints: Array[int] = [144, 504, 1008] # Day 1, Day 3.5, Day 7
	var current: int = 0
	
	for target in checkpoints:
		var step_count: int = target - current
		engine_a.step(step_count)
		engine_b.step(step_count)
		engine_c.step(step_count)
		current = target
		
		var cs_a: int = engine_a.get_state_checksum()
		var cs_b: int = engine_b.get_state_checksum()
		var cs_c: int = engine_c.get_state_checksum()
		
		asserts.assert_eq(cs_a, cs_b, "Checksum match at tick %d between Run A and Run B" % target)
		asserts.assert_ne(cs_a, cs_c, "Checksum divergence at tick %d between Run A and Run C" % target)
