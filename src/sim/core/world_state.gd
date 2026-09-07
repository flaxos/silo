# src/sim/core/world_state.gd
class_name WorldState
extends RefCounted

var sim_clock: SimClock
var rng: SeededRandom
var entity_registry: EntityRegistry
var event_queue: EventQueue
var custom_data: Dictionary = {}
var initial_seed: int = 0

func _init(p_seed: int = 42) -> void:
	initial_seed = p_seed
	sim_clock = SimClock.new()
	rng = SeededRandom.new(p_seed)
	entity_registry = EntityRegistry.new()
	event_queue = EventQueue.new()
	custom_data = {}

func get_state_checksum() -> int:
	return StateChecksum.compute_world_checksum(self)

func get_summary() -> Dictionary:
	return {
		"tick": sim_clock.get_tick(),
		"formatted_time": sim_clock.get_formatted_time(),
		"seed": initial_seed,
		"entity_count": entity_registry.get_entity_count(),
		"queued_events": event_queue.get_event_count(),
		"checksum": get_state_checksum()
	}

func serialize() -> Dictionary:
	return {
		"format_version": 1,
		"initial_seed": initial_seed,
		"sim_clock": sim_clock.serialize(),
		"rng": rng.serialize(),
		"entity_registry": entity_registry.serialize(),
		"event_queue": event_queue.serialize(),
		"custom_data": custom_data,
		"checksum": get_state_checksum()
	}

func deserialize(data: Dictionary) -> void:
	initial_seed = data.get("initial_seed", 0)
	sim_clock.deserialize(data.get("sim_clock", {}))
	rng.deserialize(data.get("rng", {}))
	entity_registry.deserialize(data.get("entity_registry", {}))
	event_queue.deserialize(data.get("event_queue", {}))
	custom_data = data.get("custom_data", {})
