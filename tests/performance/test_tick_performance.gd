# tests/performance/test_tick_performance.gd
class_name TestTickPerformance
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_headless_tick_throughput(asserts)

func test_headless_tick_throughput(asserts: TestAsserts) -> void:
	asserts.set_current_test("Performance: Headless 10,000 tick baseline benchmark")
	
	var engine: SimulationEngine = SimulationEngine.new(42)
	
	# Register mock system with 50 entities
	var ws: WorldState = engine.get_world_state()
	for i in range(50):
		ws.entity_registry.register_entity("person", {
			"name": "Person_%d" % i,
			"energy": 100.0,
			"pos": [i, i * 2]
		})
	
	var total_ticks: int = 10000
	var start_time_usec: int = Time.get_ticks_usec()
	
	engine.step(total_ticks)
	
	var elapsed_usec: int = Time.get_ticks_usec() - start_time_usec
	var elapsed_sec: float = float(elapsed_usec) / 1000000.0
	var ticks_per_sec: float = float(total_ticks) / maxf(0.0001, elapsed_sec)
	var avg_ms_per_tick: float = (float(elapsed_usec) / 1000.0) / float(total_ticks)
	
	print("[BENCHMARK] Executed %d ticks in %.3f s | Throughput: %.0f ticks/sec | Avg tick: %.4f ms" % [
		total_ticks, elapsed_sec, ticks_per_sec, avg_ms_per_tick
	])
	
	# Budget: baseline core should comfortably exceed 10,000 ticks/sec (< 0.10 ms/tick)
	asserts.assert_lt(avg_ms_per_tick, 0.10, "Average tick time should be < 0.10 ms")
	asserts.assert_gt(ticks_per_sec, 10000.0, "Throughput should exceed 10,000 ticks/sec")
