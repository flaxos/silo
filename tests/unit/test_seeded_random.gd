# tests/unit/test_seeded_random.gd
class_name TestSeededRandom
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_determinism(asserts)
	test_range_bounds(asserts)
	test_rand_chance(asserts)
	test_choice_and_shuffle(asserts)
	test_state_save_restore(asserts)

func test_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("SeededRandom: Determinism identical seed")
	var rng1: SeededRandom = SeededRandom.new(12345)
	var rng2: SeededRandom = SeededRandom.new(12345)
	
	for i in range(100):
		var val1: int = rng1.randi()
		var val2: int = rng2.randi()
		if val1 != val2:
			asserts.assert_eq(val1, val2, "Values diverged at iteration %d" % i)
			return
	asserts.assert_true(true, "100 random integers matched identically")
	
	asserts.set_current_test("SeededRandom: Divergence different seed")
	var rng3: SeededRandom = SeededRandom.new(99999)
	var matches: int = 0
	for i in range(100):
		if rng1.randi() == rng3.randi():
			matches += 1
	asserts.assert_lt(matches, 5, "Different seeds should rarely match")

func test_range_bounds(asserts: TestAsserts) -> void:
	asserts.set_current_test("SeededRandom: Integer range bounds")
	var rng: SeededRandom = SeededRandom.new(42)
	for i in range(200):
		var v: int = rng.randi_range(5, 15)
		if v < 5 or v > 15:
			asserts.assert_true(false, "Value %d out of range [5, 15]" % v)
			return
	asserts.assert_true(true, "All 200 values within [5, 15]")
	
	asserts.set_current_test("SeededRandom: Float range bounds")
	for i in range(200):
		var vf: float = rng.randf_range(-2.5, 3.5)
		if vf < -2.5 or vf > 3.5:
			asserts.assert_true(false, "Float %f out of range [-2.5, 3.5]" % vf)
			return
	asserts.assert_true(true, "All 200 floats within [-2.5, 3.5]")

func test_rand_chance(asserts: TestAsserts) -> void:
	asserts.set_current_test("SeededRandom: Chance bounds (0.0 and 1.0)")
	var rng: SeededRandom = SeededRandom.new(42)
	asserts.assert_false(rng.rand_chance(0.0), "0.0 chance should always be false")
	asserts.assert_true(rng.rand_chance(1.0), "1.0 chance should always be true")
	
	asserts.set_current_test("SeededRandom: Chance distribution ~50%")
	var true_count: int = 0
	for i in range(1000):
		if rng.rand_chance(0.5):
			true_count += 1
	asserts.assert_gt(true_count, 420, "Should have roughly 500 trues, got %d" % true_count)
	asserts.assert_lt(true_count, 580, "Should have roughly 500 trues, got %d" % true_count)

func test_choice_and_shuffle(asserts: TestAsserts) -> void:
	asserts.set_current_test("SeededRandom: Choice from array")
	var rng: SeededRandom = SeededRandom.new(42)
	var options: Array = ["A", "B", "C", "D"]
	for i in range(50):
		var c: Variant = rng.choice(options)
		if not options.has(c):
			asserts.assert_true(false, "Chosen item %s not in options" % str(c))
			return
	asserts.assert_true(true, "All choices valid")
	
	asserts.set_current_test("SeededRandom: Shuffle determinism")
	var rng1: SeededRandom = SeededRandom.new(777)
	var rng2: SeededRandom = SeededRandom.new(777)
	var arr1: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var arr2: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	rng1.shuffle(arr1)
	rng2.shuffle(arr2)
	asserts.assert_eq(arr1, arr2, "Shuffles with identical seeds must produce identical ordering")
	asserts.assert_ne(arr1, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "Shuffled array should differ from sorted")

func test_state_save_restore(asserts: TestAsserts) -> void:
	asserts.set_current_test("SeededRandom: State save and restore")
	var rng: SeededRandom = SeededRandom.new(100)
	for i in range(25):
		rng.randi()
	
	var saved_state: Dictionary = rng.serialize()
	var next_values_original: Array[int] = []
	for i in range(10):
		next_values_original.append(rng.randi())
	
	var restored_rng: SeededRandom = SeededRandom.new()
	restored_rng.deserialize(saved_state)
	var next_values_restored: Array[int] = []
	for i in range(10):
		next_values_restored.append(restored_rng.randi())
	
	asserts.assert_eq(next_values_restored, next_values_original, "Restored RNG must match future sequence exactly")
