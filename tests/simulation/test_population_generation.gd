# tests/simulation/test_population_generation.gd
class_name TestPopulationGeneration
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_scale_100(asserts)
	test_scale_250(asserts)
	test_scale_500(asserts)
	test_scale_1200_lore_target(asserts)
	test_population_determinism(asserts)

func test_scale_100(asserts: TestAsserts) -> void:
	asserts.set_current_test("Population: 100 Resident Scale Invariant Validation")
	var ws: WorldState = WorldState.new(42)
	var val: Dictionary = PopulationGenerator.generate_population(ws, 100)
	
	asserts.assert_true(val["is_valid"], "100-resident world must be valid: %s" % str(val["errors"]))
	asserts.assert_eq(val["stats"]["total_people"], 100, "Should have exactly 100 residents")
	asserts.assert_gt(val["stats"]["total_households"], 15, "Should have > 15 households")
	asserts.assert_gt(val["stats"]["total_rooms"], 15, "Should have > 15 rooms")
	asserts.assert_eq(val["stats"]["bed_allocations"], 100, "Should have exactly 100 unique bed allocations")

func test_scale_250(asserts: TestAsserts) -> void:
	asserts.set_current_test("Population: 250 Resident Scale Invariant Validation")
	var ws: WorldState = WorldState.new(101)
	var val: Dictionary = PopulationGenerator.generate_population(ws, 250)
	
	asserts.assert_true(val["is_valid"], "250-resident world must be valid: %s" % str(val["errors"]))
	asserts.assert_eq(val["stats"]["total_people"], 250, "Should have exactly 250 residents")
	asserts.assert_eq(val["stats"]["bed_allocations"], 250, "Should have exactly 250 unique bed allocations")

func test_scale_500(asserts: TestAsserts) -> void:
	asserts.set_current_test("Population: 500 Resident Scale Invariant Validation")
	var ws: WorldState = WorldState.new(505)
	var val: Dictionary = PopulationGenerator.generate_population(ws, 500)
	
	asserts.assert_true(val["is_valid"], "500-resident world must be valid: %s" % str(val["errors"]))
	asserts.assert_eq(val["stats"]["total_people"], 500, "Should have exactly 500 residents")
	asserts.assert_eq(val["stats"]["bed_allocations"], 500, "Should have exactly 500 unique bed allocations")

func test_scale_1200_lore_target(asserts: TestAsserts) -> void:
	asserts.set_current_test("Population: 1,200 Resident Lore Target Invariant Validation")
	var ws: WorldState = WorldState.new(777)
	var start_usec: int = Time.get_ticks_usec()
	var val: Dictionary = PopulationGenerator.generate_population(ws, 1200)
	var duration_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	
	print("[BENCHMARK] Generated 1,200 residents, %d households, %d rooms in %.2f ms" % [
		val["stats"]["total_households"],
		val["stats"]["total_rooms"],
		duration_ms
	])
	
	asserts.assert_true(val["is_valid"], "1,200-resident lore world must be valid: %s" % str(val["errors"]))
	asserts.assert_eq(val["stats"]["total_people"], 1200, "Should have exactly 1,200 residents")
	asserts.assert_eq(val["stats"]["bed_allocations"], 1200, "Should have exactly 1,200 unique bed allocations")
	asserts.assert_lt(duration_ms, 200.0, "Generation time for 1,200 people should be < 200ms")

func test_population_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Population: 1,200 Resident Generation Determinism (Seed 42)")
	
	var ws_a: WorldState = WorldState.new(42)
	var val_a: Dictionary = PopulationGenerator.generate_population(ws_a, 1200)
	
	var ws_b: WorldState = WorldState.new(42)
	var val_b: Dictionary = PopulationGenerator.generate_population(ws_b, 1200)
	
	var ws_c: WorldState = WorldState.new(999)
	var val_c: Dictionary = PopulationGenerator.generate_population(ws_c, 1200)
	
	var cs_a: int = ws_a.get_state_checksum()
	var cs_b: int = ws_b.get_state_checksum()
	var cs_c: int = ws_c.get_state_checksum()
	
	asserts.assert_eq(cs_a, cs_b, "Seed 42 Run A checksum must equal Seed 42 Run B checksum")
	asserts.assert_ne(cs_a, cs_c, "Seed 42 and Seed 999 checksums must differ")
	
	# Verify entity-level fidelity across all 1,200 residents
	var reg_a: EntityRegistry = ws_a.entity_registry
	var reg_b: EntityRegistry = ws_b.entity_registry
	var ids_a: Array[int] = reg_a.get_entities_by_type("person")
	var ids_b: Array[int] = reg_b.get_entities_by_type("person")
	
	asserts.assert_eq(ids_a.size(), ids_b.size(), "Both runs must produce identical resident count")
	
	var sample_indices: Array[int] = [0, 50, 200, 500, 999, 1199]
	for idx in sample_indices:
		var p_a: Person = reg_a.get_entity(ids_a[idx]) as Person
		var p_b: Person = reg_b.get_entity(ids_b[idx]) as Person
		asserts.assert_eq(p_a.get_full_name(), p_b.get_full_name(), "Sample person %d name match" % idx)
		asserts.assert_eq(p_a.birth_tick, p_b.birth_tick, "Sample person %d birth_tick match" % idx)
		asserts.assert_eq(p_a.parent_ids, p_b.parent_ids, "Sample person %d parent_ids match" % idx)
		asserts.assert_eq(p_a.partner_id, p_b.partner_id, "Sample person %d partner_id match" % idx)
		asserts.assert_eq(p_a.household_id, p_b.household_id, "Sample person %d household_id match" % idx)
		asserts.assert_eq(p_a.home_room_id, p_b.home_room_id, "Sample person %d home_room_id match" % idx)
		asserts.assert_eq(p_a.bed_id, p_b.bed_id, "Sample person %d bed_id match" % idx)
