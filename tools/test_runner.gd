# tools/test_runner.gd
extends SceneTree

const TestAsserts = preload("res://tests/framework/test_asserts.gd")

const SUITES: Dictionary = {
	"unit": [
		"res://tests/unit/test_seeded_random.gd",
		"res://tests/unit/test_sim_clock.gd",
		"res://tests/unit/test_entity_registry.gd",
		"res://tests/unit/test_event_queue.gd",
		"res://tests/unit/test_checksum.gd",
	],
	"determinism": [
		"res://tests/determinism/test_determinism_smoke.gd",
	],
	"performance": [
		"res://tests/performance/test_tick_performance.gd",
	],
	"simulation": [
		"res://tests/simulation/test_population_generation.gd",
		"res://tests/simulation/test_daily_life.gd",
		"res://tests/simulation/test_spatial_travel.gd",
		"res://tests/simulation/test_material_economy.gd",
		"res://tests/simulation/test_machinery_maintenance.gd",
		"res://tests/simulation/test_dependency_loop.gd",
		"res://tests/simulation/test_society_across_time.gd",
		"res://tests/simulation/test_institutional_control.gd",
		"res://tests/simulation/test_systemic_incidents.gd",
		"res://tests/simulation/test_political_identity.gd",
		"res://tests/simulation/test_factions_and_blocs.gd",
		"res://tests/simulation/test_corruption_and_patronage.gd",
	],
	"presentation": [
		"res://tests/presentation/test_simulation_viewer.gd",
		"res://tests/presentation/test_observability_api.gd",
		"res://tests/presentation/test_physical_viewer.gd",
		"res://tests/presentation/test_godot_world.gd",
	]
}

func _init() -> void:
	# Run tests on next idle frame
	call_deferred("_run_test_suite")

func _run_test_suite() -> void:
	print("==========================================================")
	print(" SILO — Headless Test Runner")
	print("==========================================================")
	
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var filter: String = "all"
	if not user_args.is_empty():
		filter = user_args[0].to_lower()
	
	print("[INFO] Target Suite Filter: %s" % filter)
	
	var asserts: TestAsserts = TestAsserts.new()
	var suites_to_run: Array[String] = []
	
	if filter == "all":
		for category in SUITES.keys():
			for path in SUITES[category]:
				suites_to_run.append(path)
	elif SUITES.has(filter):
		for path in SUITES[filter]:
			suites_to_run.append(path)
	else:
		# Check if filter matches a specific path or prefix
		for category in SUITES.keys():
			for path in SUITES[category]:
				if path.contains(filter):
					suites_to_run.append(path)
	
	if suites_to_run.is_empty():
		print("[ERROR] No test suites matched filter '%s'" % filter)
		quit(1)
		return
	
	var total_suite_start: int = Time.get_ticks_msec()
	
	for suite_path in suites_to_run:
		var suite_name: String = suite_path.get_file().get_basename()
		print("\n--- Running Suite: %s ---" % suite_name)
		
		var script: GDScript = load(suite_path) as GDScript
		if not script:
			asserts.record_fail("Failed to load test script: %s" % suite_path)
			continue
		
		var suite_instance: RefCounted = script.new() as RefCounted
		if not suite_instance.has_method("run_all"):
			asserts.record_fail("Suite %s missing run_all(asserts) method" % suite_name)
			continue
		
		var start_time: int = Time.get_ticks_msec()
		suite_instance.run_all(asserts)
		var duration: int = Time.get_ticks_msec() - start_time
		print("  Completed in %d ms" % duration)
	
	var total_duration: int = Time.get_ticks_msec() - total_suite_start
	
	print("\n==========================================================")
	print(" TEST RESULTS SUMMARY")
	print("==========================================================")
	print(" Total Assertions Passed : %d" % asserts.passed_count)
	print(" Total Assertions Failed : %d" % asserts.failed_count)
	print(" Total Execution Time    : %d ms" % total_duration)
	print("==========================================================")
	
	if asserts.failed_count > 0:
		print("\n[FAILED TESTS DETAILS]:")
		for fail_msg in asserts.failures:
			print("  %s" % fail_msg)
		print("\n[RESULT]: ❌ TEST SUITE FAILED (Exit Code 1)\n")
		quit(1)
	else:
		print("\n[RESULT]: ✅ ALL TESTS PASSED (Exit Code 0)\n")
		quit(0)
