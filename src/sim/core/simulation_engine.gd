# src/sim/core/simulation_engine.gd
class_name SimulationEngine
extends RefCounted

var world_state: WorldState
var scheduler: Scheduler
var is_initialized: bool = false

func _init(p_seed: int = 42) -> void:
	initialize(p_seed)

func initialize(p_seed: int = 42) -> void:
	world_state = WorldState.new(p_seed)
	scheduler = Scheduler.new()
	is_initialized = true

func register_system(system: BaseSystem) -> void:
	scheduler.register_system(system)
	if is_initialized:
		system.setup(world_state)

func step(num_ticks: int = 1) -> void:
	for i in range(maxi(0, num_ticks)):
		scheduler.step_tick(world_state)

func run_until_tick(target_tick: int) -> void:
	var current: int = world_state.sim_clock.get_tick()
	if target_tick > current:
		step(target_tick - current)

func get_world_state() -> WorldState:
	return world_state

func get_scheduler() -> Scheduler:
	return scheduler

func get_state_checksum() -> int:
	return world_state.get_state_checksum()

func reset(p_seed: int = 42) -> void:
	scheduler.teardown_all(world_state)
	initialize(p_seed)

func save_to_dict() -> Dictionary:
	return world_state.serialize()

func load_from_dict(data: Dictionary) -> void:
	world_state.deserialize(data)
