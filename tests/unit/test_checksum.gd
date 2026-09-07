# tests/unit/test_checksum.gd
class_name TestChecksum
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_primitive_hashing(asserts)
	test_dictionary_order_independence(asserts)
	test_world_state_checksum_equality(asserts)
	test_world_state_checksum_sensitivity(asserts)

func test_primitive_hashing(asserts: TestAsserts) -> void:
	asserts.set_current_test("StateChecksum: Primitive deterministic hashing")
	var h1: int = StateChecksum.hash_int(42)
	var h2: int = StateChecksum.hash_int(42)
	var h3: int = StateChecksum.hash_int(43)
	
	asserts.assert_eq(h1, h2, "Identical ints must produce identical hashes")
	asserts.assert_ne(h1, h3, "Different ints must produce different hashes")
	
	var hs1: int = StateChecksum.hash_string("silo_test")
	var hs2: int = StateChecksum.hash_string("silo_test")
	var hs3: int = StateChecksum.hash_string("silo_test_2")
	asserts.assert_eq(hs1, hs2, "Identical strings must match")
	asserts.assert_ne(hs1, hs3, "Different strings must differ")

func test_dictionary_order_independence(asserts: TestAsserts) -> void:
	asserts.set_current_test("StateChecksum: Dictionary key order independence")
	var d1: Dictionary = {"alpha": 1, "beta": 2, "gamma": 3}
	var d2: Dictionary = {"gamma": 3, "alpha": 1, "beta": 2}
	
	var h1: int = StateChecksum.hash_variant(d1)
	var h2: int = StateChecksum.hash_variant(d2)
	
	asserts.assert_eq(h1, h2, "Dictionaries with identical contents in different key orders must hash identically")

func test_world_state_checksum_equality(asserts: TestAsserts) -> void:
	asserts.set_current_test("StateChecksum: Identical WorldStates hash identically")
	var ws1: WorldState = WorldState.new(42)
	var ws2: WorldState = WorldState.new(42)
	
	# Add identical entities
	ws1.entity_registry.register_entity("person", {"name": "Alice", "age": 28}, 1)
	ws2.entity_registry.register_entity("person", {"name": "Alice", "age": 28}, 1)
	
	# Add identical event
	ws1.event_queue.schedule_event(10, "alarm", {"code": 1})
	ws2.event_queue.schedule_event(10, "alarm", {"code": 1})
	
	asserts.assert_eq(ws1.get_state_checksum(), ws2.get_state_checksum(), "Identical world states must have identical checksum")

func test_world_state_checksum_sensitivity(asserts: TestAsserts) -> void:
	asserts.set_current_test("StateChecksum: Checksum changes on state mutation")
	var ws1: WorldState = WorldState.new(42)
	var ws2: WorldState = WorldState.new(42)
	
	var base_checksum: int = ws1.get_state_checksum()
	
	# Mutate clock
	ws1.sim_clock.advance_tick()
	asserts.assert_ne(ws1.get_state_checksum(), base_checksum, "Clock advance must change checksum")
	
	# Mutate RNG
	ws2.rng.randi()
	asserts.assert_ne(ws2.get_state_checksum(), base_checksum, "RNG step must change checksum")
