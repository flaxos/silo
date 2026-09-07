# tests/unit/test_event_queue.gd
class_name TestEventQueue
extends RefCounted

func run_all(asserts: TestAsserts) -> void:
	test_event_scheduling_and_dispatch(asserts)
	test_delay_scheduling(asserts)
	test_cancellation(asserts)
	test_deterministic_ordering_at_same_tick(asserts)
	test_serialization(asserts)

func test_event_scheduling_and_dispatch(asserts: TestAsserts) -> void:
	asserts.set_current_test("EventQueue: Event scheduling and dispatch")
	var queue: EventQueue = EventQueue.new()
	var ev1: int = queue.schedule_event(10, "shift_start", {"shift": "day"})
	var ev2: int = queue.schedule_event(20, "shift_end", {"shift": "day"})
	
	asserts.assert_eq(queue.get_event_count(), 2, "Event count should be 2")
	
	# Check at tick 5 (nothing due)
	var due_5: Array[Dictionary] = queue.pop_due_events(5)
	asserts.assert_true(due_5.is_empty(), "No events should be due at tick 5")
	
	# Check at tick 10 (ev1 due)
	var due_10: Array[Dictionary] = queue.pop_due_events(10)
	asserts.assert_eq(due_10.size(), 1, "1 event should be due at tick 10")
	asserts.assert_eq(due_10[0]["id"], ev1, "Due event should be ev1")
	asserts.assert_eq(due_10[0]["type"], "shift_start", "Event type should match")
	asserts.assert_eq(queue.get_event_count(), 1, "Remaining count should be 1")
	
	# Check at tick 25 (ev2 due)
	var due_25: Array[Dictionary] = queue.pop_due_events(25)
	asserts.assert_eq(due_25.size(), 1, "1 event should be due at tick 25")
	asserts.assert_eq(due_25[0]["id"], ev2, "Due event should be ev2")
	asserts.assert_true(queue.get_event_count() == 0, "Queue should be empty")

func test_delay_scheduling(asserts: TestAsserts) -> void:
	asserts.set_current_test("EventQueue: Delay scheduling")
	var queue: EventQueue = EventQueue.new()
	var current_tick: int = 100
	var ev_id: int = queue.schedule_delay(current_tick, 14, "breakdown", {})
	
	var due: Array[Dictionary] = queue.pop_due_events(113)
	asserts.assert_true(due.is_empty(), "Should not be due at tick 113")
	
	due = queue.pop_due_events(114)
	asserts.assert_eq(due.size(), 1, "Should be due at tick 114")
	asserts.assert_eq(due[0]["id"], ev_id, "ID should match")

func test_cancellation(asserts: TestAsserts) -> void:
	asserts.set_current_test("EventQueue: Event cancellation")
	var queue: EventQueue = EventQueue.new()
	var ev_id: int = queue.schedule_event(50, "alarm", {})
	asserts.assert_true(queue.cancel_event(ev_id), "Cancel should return true")
	asserts.assert_false(queue.cancel_event(ev_id), "Second cancel should return false")
	asserts.assert_eq(queue.get_event_count(), 0, "Queue should be empty")
	
	var due: Array[Dictionary] = queue.pop_due_events(50)
	asserts.assert_true(due.is_empty(), "Cancelled event must not fire")

func test_deterministic_ordering_at_same_tick(asserts: TestAsserts) -> void:
	asserts.set_current_test("EventQueue: Deterministic ordering at same tick")
	var queue: EventQueue = EventQueue.new()
	queue.schedule_event(100, "action_A", {"seq": 1})
	queue.schedule_event(100, "action_B", {"seq": 2})
	queue.schedule_event(100, "action_C", {"seq": 3})
	
	var due: Array[Dictionary] = queue.pop_due_events(100)
	asserts.assert_eq(due.size(), 3, "3 events due")
	asserts.assert_eq(due[0]["type"], "action_A", "First scheduled must be first dispatched")
	asserts.assert_eq(due[1]["type"], "action_B", "Second scheduled must be second dispatched")
	asserts.assert_eq(due[2]["type"], "action_C", "Third scheduled must be third dispatched")

func test_serialization(asserts: TestAsserts) -> void:
	asserts.set_current_test("EventQueue: Serialization and deserialization")
	var queue: EventQueue = EventQueue.new()
	queue.schedule_event(15, "ev1", {"x": 10})
	queue.schedule_event(30, "ev2", {"y": 20})
	
	var data: Dictionary = queue.serialize()
	var restored: EventQueue = EventQueue.new()
	restored.deserialize(data)
	
	asserts.assert_eq(restored.get_event_count(), 2, "Restored count should be 2")
	var due_15: Array[Dictionary] = restored.pop_due_events(15)
	asserts.assert_eq(due_15.size(), 1, "Restored queue must dispatch at tick 15")
	asserts.assert_eq(due_15[0]["type"], "ev1", "Type should match")
