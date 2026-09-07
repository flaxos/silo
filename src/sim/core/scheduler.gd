# src/sim/core/scheduler.gd
class_name Scheduler
extends RefCounted

var _systems: Array[BaseSystem] = []
var _system_map: Dictionary = {} # String id -> BaseSystem
var _event_handlers: Dictionary = {} # String event_type -> Array[Callable]

func register_system(system: BaseSystem) -> void:
	if _system_map.has(system.system_id):
		push_warning("Scheduler: System '%s' already registered. Replacing." % system.system_id)
		remove_system(system.system_id)
	
	_systems.append(system)
	_system_map[system.system_id] = system
	_sort_systems()

func remove_system(system_id: String) -> bool:
	if not _system_map.has(system_id):
		return false
	var sys: BaseSystem = _system_map[system_id]
	_system_map.erase(system_id)
	_systems.erase(sys)
	return true

func get_system(system_id: String) -> BaseSystem:
	return _system_map.get(system_id, null)

func has_system(system_id: String) -> bool:
	return _system_map.has(system_id)

func get_all_systems() -> Array[BaseSystem]:
	return _systems.duplicate()

func register_event_listener(event_type: String, handler: Callable) -> void:
	if not _event_handlers.has(event_type):
		_event_handlers[event_type] = []
	var list: Array = _event_handlers[event_type]
	if not list.has(handler):
		list.append(handler)

func unregister_event_listener(event_type: String, handler: Callable) -> void:
	if _event_handlers.has(event_type):
		_event_handlers[event_type].erase(handler)

func setup_all(world_state: Variant) -> void:
	for sys in _systems:
		if sys.is_enabled:
			sys.setup(world_state)

func teardown_all(world_state: Variant) -> void:
	for sys in _systems:
		sys.teardown(world_state)

## Executes one complete discrete simulation tick
func step_tick(world_state: Variant) -> void:
	# 1. Pre-tick: advance clock
	var clock: SimClock = world_state.sim_clock
	clock.advance_tick()
	var current_tick: int = clock.get_tick()
	
	# 2. Event dispatch: pop due events for current tick
	var event_queue: EventQueue = world_state.event_queue
	var due_events: Array[Dictionary] = event_queue.pop_due_events(current_tick)
	
	for ev in due_events:
		var ev_type: String = ev.get("type", "")
		var ev_data: Dictionary = ev.get("data", {})
		
		# Dispatch to registered systems
		for sys in _systems:
			if sys.is_enabled:
				sys.handle_event(world_state, ev_type, ev_data)
		
		# Dispatch to registered specific event listeners
		if _event_handlers.has(ev_type):
			for handler in _event_handlers[ev_type]:
				if handler.is_valid():
					handler.call(world_state, ev_type, ev_data)
	
	# 3. Domain systems execution pipeline
	for sys in _systems:
		if sys.is_enabled:
			sys.tick(world_state)

func _sort_systems() -> void:
	_systems.sort_custom(func(a: BaseSystem, b: BaseSystem) -> bool:
		if a.execution_order != b.execution_order:
			return a.execution_order < b.execution_order
		return a.system_id < b.system_id
	)
