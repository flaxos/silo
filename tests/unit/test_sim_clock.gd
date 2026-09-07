# tests/unit/test_sim_clock.gd
class_name TestSimClock
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_initial_state(asserts)
	test_tick_progression(asserts)
	test_hourly_and_daily_rollover(asserts)
	test_yearly_rollover(asserts)
	test_helper_conversions(asserts)
	test_serialization(asserts)

func test_initial_state(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimClock: Initial state at tick 0")
	var clock: SimClock = SimClock.new()
	asserts.assert_eq(clock.get_tick(), 0, "Initial tick should be 0")
	asserts.assert_eq(clock.get_hour_of_day(), 0, "Hour should be 0")
	asserts.assert_eq(clock.get_minute_of_hour(), 0, "Minute should be 0")
	asserts.assert_eq(clock.get_day_of_year(), 1, "Day of year should be 1")
	asserts.assert_eq(clock.get_year(), 1, "Year should be 1")
	asserts.assert_eq(clock.get_formatted_clock(), "00:00", "Clock should format as 00:00")

func test_tick_progression(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimClock: Tick progression (10 mins/tick)")
	var clock: SimClock = SimClock.new()
	clock.advance_tick()
	asserts.assert_eq(clock.get_tick(), 1, "Tick should be 1")
	asserts.assert_eq(clock.get_minute_of_hour(), 10, "Minute should be 10")
	asserts.assert_eq(clock.get_hour_of_day(), 0, "Hour should be 0")
	asserts.assert_eq(clock.get_formatted_clock(), "00:10", "Clock should format as 00:10")

func test_hourly_and_daily_rollover(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimClock: Hourly rollover at 6 ticks")
	var clock: SimClock = SimClock.new()
	clock.advance_ticks(6)
	asserts.assert_eq(clock.get_tick(), 6, "Tick should be 6")
	asserts.assert_eq(clock.get_hour_of_day(), 1, "Hour should be 1")
	asserts.assert_eq(clock.get_minute_of_hour(), 0, "Minute should be 0")
	asserts.assert_eq(clock.get_formatted_clock(), "01:00", "Clock should format as 01:00")
	
	asserts.set_current_test("SimClock: Daily rollover at 144 ticks")
	clock.advance_ticks(138) # Total 144 ticks = exactly 24 hours
	asserts.assert_eq(clock.get_tick(), 144, "Tick should be 144")
	asserts.assert_eq(clock.get_day_of_year(), 2, "Day of year should be 2")
	asserts.assert_eq(clock.get_hour_of_day(), 0, "Hour should reset to 0")
	asserts.assert_eq(clock.get_minute_of_hour(), 0, "Minute should reset to 0")
	asserts.assert_eq(clock.get_formatted_clock(), "00:00", "Clock should format as 00:00")

func test_yearly_rollover(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimClock: Yearly rollover at 52,560 ticks")
	var clock: SimClock = SimClock.new()
	clock.advance_ticks(52560) # 365 days
	asserts.assert_eq(clock.get_tick(), 52560, "Tick should be 52560")
	asserts.assert_eq(clock.get_year(), 2, "Year should advance to 2")
	asserts.assert_eq(clock.get_day_of_year(), 1, "Day of year should reset to 1")
	asserts.assert_eq(clock.get_hour_of_day(), 0, "Hour should be 0")
	asserts.assert_eq(clock.get_minute_of_hour(), 0, "Minute should be 0")

func test_helper_conversions(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimClock: Helper static conversions")
	asserts.assert_eq(SimClock.ticks_for_minutes(10), 1, "10 min = 1 tick")
	asserts.assert_eq(SimClock.ticks_for_minutes(25), 3, "25 min rounds up to 3 ticks")
	asserts.assert_eq(SimClock.ticks_for_hours(8), 48, "8 hours = 48 ticks")
	asserts.assert_eq(SimClock.ticks_for_days(7), 1008, "7 days = 1008 ticks")

func test_serialization(asserts: TestAsserts) -> void:
	asserts.set_current_test("SimClock: Serialization and deserialization")
	var clock: SimClock = SimClock.new(8420)
	var data: Dictionary = clock.serialize()
	var restored: SimClock = SimClock.new()
	restored.deserialize(data)
	asserts.assert_eq(restored.get_tick(), 8420, "Deserialized tick must match original")
	asserts.assert_eq(restored.get_year(), clock.get_year(), "Year must match")
	asserts.assert_eq(restored.get_day_of_year(), clock.get_day_of_year(), "Day must match")
