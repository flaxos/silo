# tests/simulation/test_society_across_time.gd
class_name TestSocietyAcrossTime
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_2_year_demographic_turnover(asserts)
	test_schooling_and_workforce_replenishment(asserts)
	test_genealogy_and_succession_invariants(asserts)
	test_society_replay_determinism(asserts)

func test_2_year_demographic_turnover(asserts: TestAsserts) -> void:
	asserts.set_current_test("SocietyAcrossTime: 2-Year Multi-Generational Demographic Progression")
	var engine: SimulationEngine = SimulationEngine.new(42)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var demo_sys: DemographicsSystem = DemographicsSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(1000000.0, 1000000.0) # Abundant water for social focus
	
	engine.register_system(demo_sys)
	engine.register_system(daily_life)
	engine.register_system(water_sys)
	
	var ticks_per_year: int = SimClock.TICKS_PER_YEAR # 52,560 ticks
	var start_usec: int = Time.get_ticks_usec()
	
	# Simulate 2 consecutive years (105,120 ticks)
	for year in range(2):
		engine.step(ticks_per_year)
		
		var s_val: Dictionary = SocietyInvariants.validate(ws)
		if not s_val["is_valid"]:
			asserts.assert_true(false, "Society invariants failed in Year %d: %s" % [year + 1, str(s_val["errors"])])
			return
			
	var duration_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var final_val: Dictionary = SocietyInvariants.validate(ws)
	var stats: Dictionary = final_val["stats"]
	
	print("[BENCHMARK] Simulated 2 years (105,120 ticks) demographic progression in %.2f ms" % duration_ms)
	print("  - Total Population Recorded: %d (Living: %d, Deceased: %d)" % [
		stats["total_people"], stats["living_count"], stats["deceased_count"]
	])
	print("  - Demographic Breakdown: %d Infants, %d Children, %d Students, %d Adults, %d Elders" % [
		stats["infants"], stats["children"], stats["students"], stats["adults"], stats["elders"]
	])
	print("  - Life Events: %d Births, %d Deaths, %d Graduations, %d Retirements, %d Partnerships" % [
		demo_sys.total_births, demo_sys.total_deaths, demo_sys.total_graduations, demo_sys.total_retirements, demo_sys.total_marriages
	])
	
	asserts.assert_true(final_val["is_valid"], "2-year society invariants must hold")
	asserts.assert_gt(stats["living_count"], 50, "Living population must remain viable")
	asserts.assert_gt(demo_sys.total_births, 0, "Births should occur over 2 simulated years")
	asserts.assert_gt(demo_sys.total_graduations, 0, "Students should graduate into adulthood over 2 simulated years")
	asserts.assert_lt(duration_ms, 90000.0, "2-year simulation should execute within budget (< 90,000 ms)")

func test_schooling_and_workforce_replenishment(asserts: TestAsserts) -> void:
	asserts.set_current_test("SocietyAcrossTime: Education Accumulation & Workforce Graduation")
	var engine: SimulationEngine = SimulationEngine.new(101)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var demo_sys: DemographicsSystem = DemographicsSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(500000.0, 500000.0)
	
	engine.register_system(demo_sys)
	engine.register_system(daily_life)
	engine.register_system(water_sys)
	
	var registry: EntityRegistry = ws.entity_registry
	
	# Find an existing student
	var target_student: Person = null
	for pid in registry.get_entities_by_type("person"):
		var p: Person = registry.get_entity(pid) as Person
		if p and p.occupation_id == "student" and p.is_alive:
			target_student = p
			break
			
	asserts.assert_not_null(target_student, "Student must exist in initial population")
	var student_initial_education: float = target_student.education_score
	asserts.assert_almost_eq(student_initial_education, 0.0, 0.01, "Initial student education should be 0")
	
	# Set student birth_tick to exactly 17 years ago so they graduate in 1 year
	target_student.birth_tick = - (17 * SimClock.TICKS_PER_YEAR)
	
	# Step 1 simulated year (52,560 ticks)
	engine.step(SimClock.TICKS_PER_YEAR)
	
	# Assert student accumulated education and graduated into adult occupation
	asserts.assert_gt(target_student.education_score, 5.0, "Student must accumulate education points through schooling")
	asserts.assert_ne(target_student.occupation_id, "student", "18-year-old student must graduate from student status")
	asserts.assert_eq(target_student.life_stage, Person.STAGE_ADULT, "Graduated student must be in STAGE_ADULT")
	asserts.assert_gt(target_student.workplace_room_id, 0, "Graduated adult must be assigned a workplace")
	asserts.assert_ne(target_student.department_id, "", "Graduated adult must belong to a functional department")

func test_genealogy_and_succession_invariants(asserts: TestAsserts) -> void:
	asserts.set_current_test("SocietyAcrossTime: Reciprocal Lineages & Household Succession Under Mortality")
	var engine: SimulationEngine = SimulationEngine.new(202)
	var ws: WorldState = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	var demo_sys: DemographicsSystem = DemographicsSystem.new()
	var daily_life: DailyLifeSystem = DailyLifeSystem.new()
	var water_sys: WaterSystem = WaterSystem.new(500000.0, 500000.0)
	
	engine.register_system(demo_sys)
	engine.register_system(daily_life)
	engine.register_system(water_sys)
	
	var registry: EntityRegistry = ws.entity_registry
	
	# Find a household with elder head and adult members
	var target_hh: Household = null
	var elder_head: Person = null
	for hhid in registry.get_entities_by_type("household"):
		var hh: Household = registry.get_entity(hhid) as Household
		if hh and hh.head_id > 0 and hh.member_ids.size() >= 2:
			var head: Person = registry.get_entity(hh.head_id) as Person
			if head and head.life_stage == Person.STAGE_ELDER:
				target_hh = hh
				elder_head = head
				break
				
	if not elder_head:
		# Pick any multi-person household
		for hhid in registry.get_entities_by_type("household"):
			var hh: Household = registry.get_entity(hhid) as Household
			if hh and hh.head_id > 0 and hh.member_ids.size() >= 2:
				target_hh = hh
				elder_head = registry.get_entity(hh.head_id) as Person
				break
				
	asserts.assert_not_null(elder_head, "Target household head should exist")
	var initial_head_id: int = elder_head.id
	var initial_bed_id: int = elder_head.bed_id
	var home_room_id: int = elder_head.home_room_id
	
	# Trigger natural death of household head
	elder_head.health_percent = 0.0
	engine.step(144) # 1 day
	
	# Invariant checks:
	# 1. Elder is deceased
	asserts.assert_false(elder_head.is_alive, "Elder head must be deceased")
	# 2. Bed is freed
	asserts.assert_eq(elder_head.bed_id, -1, "Deceased person bed_id must be reset to -1")
	var room: Room = registry.get_entity(home_room_id) as Room
	if room and initial_bed_id >= 0:
		asserts.assert_ne(room.get_occupant_of_bed(initial_bed_id), initial_head_id, "Room bed must no longer be occupied by deceased")
	# 3. Household head succeeded to living member
	asserts.assert_ne(target_hh.head_id, initial_head_id, "Household head must be succeeded upon death")
	
	# 4. Invariant validation
	var s_val: Dictionary = SocietyInvariants.validate(ws)
	asserts.assert_true(s_val["is_valid"], "Society invariants must hold after mortality and succession")

func test_society_replay_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("SocietyAcrossTime: 1-Year Demographic Replay Determinism")
	
	# Run A (Seed 42)
	var engine_a: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_a.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_a.get_world_state())
	engine_a.register_system(DemographicsSystem.new())
	engine_a.register_system(DailyLifeSystem.new())
	engine_a.register_system(WaterSystem.new(500000.0, 500000.0))
	
	# Run B (Seed 42)
	var engine_b: SimulationEngine = SimulationEngine.new(42)
	PopulationGenerator.generate_population(engine_b.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_b.get_world_state())
	engine_b.register_system(DemographicsSystem.new())
	engine_b.register_system(DailyLifeSystem.new())
	engine_b.register_system(WaterSystem.new(500000.0, 500000.0))
	
	# Run C (Seed 999)
	var engine_c: SimulationEngine = SimulationEngine.new(999)
	PopulationGenerator.generate_population(engine_c.get_world_state(), 100)
	OccupationAssignment.setup_workplaces_and_assignments(engine_c.get_world_state())
	engine_c.register_system(DemographicsSystem.new())
	engine_c.register_system(DailyLifeSystem.new())
	engine_c.register_system(WaterSystem.new(500000.0, 500000.0))
	
	var checkpoints: Array[int] = [4320, 25920, 52560] # Day 30, Day 180, Day 365
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
		
		asserts.assert_eq(cs_a, cs_b, "Checksum match at tick %d (Day %d) between Run A and Run B" % [target, target / 144])
		asserts.assert_ne(cs_a, cs_c, "Checksum divergence at tick %d between Run A and Run C" % target)
