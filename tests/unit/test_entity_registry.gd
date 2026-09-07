# tests/unit/test_entity_registry.gd
class_name TestEntityRegistry
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_monotonic_id_generation(asserts)
	test_registration_and_retrieval(asserts)
	test_type_indexing(asserts)
	test_removal(asserts)
	test_deterministic_id_sorting(asserts)
	test_serialization_roundtrip(asserts)

func test_monotonic_id_generation(asserts: TestAsserts) -> void:
	asserts.set_current_test("EntityRegistry: Monotonic sequential IDs")
	var registry: EntityRegistry = EntityRegistry.new()
	asserts.assert_eq(registry.generate_id(), 1, "First ID should be 1")
	asserts.assert_eq(registry.generate_id(), 2, "Second ID should be 2")
	asserts.assert_eq(registry.generate_id(), 3, "Third ID should be 3")

func test_registration_and_retrieval(asserts: TestAsserts) -> void:
	asserts.set_current_test("EntityRegistry: Registration and retrieval")
	var registry: EntityRegistry = EntityRegistry.new()
	var person_data: Dictionary = {"name": "Alice", "age": 30}
	var id: int = registry.register_entity("person", person_data)
	
	asserts.assert_eq(id, 1, "Registered ID should be 1")
	asserts.assert_true(registry.has_entity(id), "Should have entity 1")
	asserts.assert_eq(registry.get_entity_type(id), "person", "Type should be person")
	asserts.assert_eq(registry.get_entity(id), person_data, "Data should match")
	asserts.assert_eq(registry.get_entity_count(), 1, "Count should be 1")

func test_type_indexing(asserts: TestAsserts) -> void:
	asserts.set_current_test("EntityRegistry: Type indexing")
	var registry: EntityRegistry = EntityRegistry.new()
	var p1: int = registry.register_entity("person", {"name": "P1"})
	var p2: int = registry.register_entity("person", {"name": "P2"})
	var m1: int = registry.register_entity("machine", {"name": "M1"})
	
	var people: Array[int] = registry.get_entities_by_type("person")
	var machines: Array[int] = registry.get_entities_by_type("machine")
	var rooms: Array[int] = registry.get_entities_by_type("room")
	
	asserts.assert_eq(people.size(), 2, "Should find 2 people")
	asserts.assert_true(people.has(p1), "Should contain p1")
	asserts.assert_true(people.has(p2), "Should contain p2")
	asserts.assert_eq(machines.size(), 1, "Should find 1 machine")
	asserts.assert_true(machines.has(m1), "Should contain m1")
	asserts.assert_true(rooms.is_empty(), "Unknown type should return empty array")

func test_removal(asserts: TestAsserts) -> void:
	asserts.set_current_test("EntityRegistry: Entity removal and index cleanup")
	var registry: EntityRegistry = EntityRegistry.new()
	var id: int = registry.register_entity("person", {"name": "Bob"})
	asserts.assert_true(registry.remove_entity(id), "Remove should return true")
	asserts.assert_false(registry.has_entity(id), "Should not have entity after removal")
	asserts.assert_null(registry.get_entity(id), "get_entity should return null")
	asserts.assert_true(registry.get_entities_by_type("person").is_empty(), "Type index should be cleaned up")
	asserts.assert_false(registry.remove_entity(999), "Removing non-existent ID should return false")

func test_deterministic_id_sorting(asserts: TestAsserts) -> void:
	asserts.set_current_test("EntityRegistry: Deterministic ID sorting")
	var registry: EntityRegistry = EntityRegistry.new()
	registry.register_entity("item", {}, 10)
	registry.register_entity("item", {}, 2)
	registry.register_entity("item", {}, 5)
	
	var sorted_ids: Array[int] = registry.get_all_ids()
	asserts.assert_eq(sorted_ids, [2, 5, 10], "IDs must always be returned in ascending order")

func test_serialization_roundtrip(asserts: TestAsserts) -> void:
	asserts.set_current_test("EntityRegistry: Serialization roundtrip")
	var registry: EntityRegistry = EntityRegistry.new()
	registry.register_entity("person", {"name": "Charlie", "age": 45})
	registry.register_entity("machine", {"type": "pump", "wear": 12.5})
	
	var data: Dictionary = registry.serialize()
	var restored: EntityRegistry = EntityRegistry.new()
	restored.deserialize(data)
	
	asserts.assert_eq(restored.get_entity_count(), 2, "Restored count should be 2")
	asserts.assert_eq(restored.get_entities_by_type("person").size(), 1, "Should have 1 person")
	asserts.assert_eq(restored.get_entities_by_type("machine").size(), 1, "Should have 1 machine")
	asserts.assert_eq(restored.get_next_id(), registry.get_next_id(), "Next ID must match")
