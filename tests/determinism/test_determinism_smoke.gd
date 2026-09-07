# tests/determinism/test_determinism_smoke.gd
class_name TestDeterminismSmoke
extends RefCounted

## Mock system that generates deterministic activity (RNG calls, entity modifications, scheduled events)
class MockActivitySystem extends BaseSystem:
	func _init() -> void:
		super("mock_activity", 10)
	
	func setup(world_state: Variant) -> void:
		var ws: WorldState = world_state as WorldState
		# Register some mock initial entities
		for i in range(10):
			var name_val: String = "Citizen_%d" % i
			ws.entity_registry.register_entity("person", {
				"name": name_val,
				"fatigue": 0.0,
				"actions_taken": 0
			})
	
	func tick(world_state: Variant) -> void:
		var ws: WorldState = world_state as WorldState
		var tick: int = ws.sim_clock.get_tick()
		
		# Deterministic RNG operations
		var ids: Array[int] = ws.entity_registry.get_entities_by_type("person")
		for id in ids:
			var person: Dictionary = ws.entity_registry.get_entity(id)
			if ws.rng.rand_chance(0.3):
				person["actions_taken"] = person.get("actions_taken", 0) + 1
				person["fatigue"] = person.get("fatigue", 0.0) + ws.rng.randf_range(0.1, 0.5)
		
		# Occasionally schedule future events
		if tick % 50 == 0:
			ws.event_queue.schedule_delay(tick, 10, "mock_pulse", {"origin_tick": tick})
	
	func handle_event(world_state: Variant, event_type: String, event_data: Dictionary) -> void:
		var ws: WorldState = world_state as WorldState
		if event_type == "mock_pulse":
			ws.custom_data["last_pulse"] = event_data.get("origin_tick", 0)

func run_all(asserts: TestAsserts) -> void:
	test_1000_tick_determinism(asserts)

func test_1000_tick_determinism(asserts: TestAsserts) -> void:
	asserts.set_current_test("Sprint 0 Acceptance: 1,000 Tick Deterministic Replay")
	
	var engine_a: SimulationEngine = SimulationEngine.new(42)
	engine_a.register_system(MockActivitySystem.new())
	
	var engine_b: SimulationEngine = SimulationEngine.new(42)
	engine_b.register_system(MockActivitySystem.new())
	
	var engine_c: SimulationEngine = SimulationEngine.new(999)
	engine_c.register_system(MockActivitySystem.new())
	
	var checkpoints: Array[int] = [100, 250, 500, 750, 1000]
	var current_step: int = 0
	
	for target in checkpoints:
		var ticks_to_step: int = target - current_step
		engine_a.step(ticks_to_step)
		engine_b.step(ticks_to_step)
		engine_c.step(ticks_to_step)
		current_step = target
		
		var cs_a: int = engine_a.get_state_checksum()
		var cs_b: int = engine_b.get_state_checksum()
		var cs_c: int = engine_c.get_state_checksum()
		
		if cs_a != cs_b:
			asserts.assert_eq(cs_a, cs_b, "Determinism divergence at tick %d! Seed 42 Run A != Run B" % target)
			return
		
		if cs_a == cs_c:
			asserts.assert_ne(cs_a, cs_c, "Seed 42 and Seed 999 unexpectedly produced identical checksum at tick %d" % target)
			return
	
	asserts.assert_true(true, "1,000 ticks completed with 100% checksum match between Run A and Run B across all checkpoints")
	asserts.assert_ne(engine_a.get_state_checksum(), engine_c.get_state_checksum(), "Run A and Run C diverged as expected")
