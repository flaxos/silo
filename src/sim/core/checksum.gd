# src/sim/core/checksum.gd
class_name StateChecksum
extends RefCounted

const FNV_OFFSET_BASIS_64: int = -3750763034362895579 # 0xcbf29ce484222325 as signed 64-bit int
const FNV_PRIME_64: int = 1099511628211 # 0x100000001b3

## Computes a 64-bit FNV-1a hash over raw string bytes
static func hash_string(text: String, current_hash: int = FNV_OFFSET_BASIS_64) -> int:
	var h: int = current_hash
	var bytes: PackedByteArray = text.to_utf8_buffer()
	for b in bytes:
		h = (h ^ int(b)) * FNV_PRIME_64
	return h

## Computes a 64-bit hash combining an integer
static func hash_int(val: int, current_hash: int = FNV_OFFSET_BASIS_64) -> int:
	var h: int = current_hash
	for i in range(8):
		var b: int = (val >> (i * 8)) & 0xFF
		h = (h ^ b) * FNV_PRIME_64
	return h

## Computes a 64-bit hash combining a float (scaled to integer for determinism)
static func hash_float(val: float, precision: float = 10000.0, current_hash: int = FNV_OFFSET_BASIS_64) -> int:
	var int_rep: int = int(round(val * precision))
	return hash_int(int_rep, current_hash)

## Recursively hashes any Variant value deterministically
static func hash_variant(val: Variant, current_hash: int = FNV_OFFSET_BASIS_64) -> int:
	var h: int = current_hash
	match typeof(val):
		TYPE_NIL:
			h = hash_int(0, h)
		TYPE_BOOL:
			h = hash_int(1 if val else 0, h)
		TYPE_INT:
			h = hash_int(val, h)
		TYPE_FLOAT:
			h = hash_float(val, 10000.0, h)
		TYPE_STRING, TYPE_STRING_NAME:
			h = hash_string(str(val), h)
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			h = hash_int(val.size(), h)
			for item in val:
				h = hash_variant(item, h)
		TYPE_DICTIONARY:
			var keys: Array = val.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			h = hash_int(keys.size(), h)
			for k in keys:
				h = hash_string(str(k), h)
				h = hash_variant(val[k], h)
		_:
			if val is Object and val.has_method("serialize"):
				h = hash_variant(val.serialize(), h)
			else:
				h = hash_string(str(val), h)
	return h

## Computes a complete state checksum from a WorldState instance
static func compute_world_checksum(world_state: Variant) -> int:
	var h: int = FNV_OFFSET_BASIS_64
	
	# 1. SimClock state
	var clock: SimClock = world_state.sim_clock
	h = hash_int(clock.get_tick(), h)
	
	# 2. PRNG state
	var rng: SeededRandom = world_state.rng
	h = hash_int(rng.get_initial_seed(), h)
	h = hash_int(rng.get_state(), h)
	
	# 3. Entity Registry state (sorted by ID)
	var registry: EntityRegistry = world_state.entity_registry
	var all_ids: Array[int] = registry.get_all_ids()
	h = hash_int(all_ids.size(), h)
	for id in all_ids:
		h = hash_int(id, h)
		h = hash_string(registry.get_entity_type(id), h)
		var ent_data: Variant = registry.get_entity(id)
		h = hash_variant(ent_data, h)
	
	# 4. Event Queue state
	var event_queue: EventQueue = world_state.event_queue
	var all_events: Array[Dictionary] = event_queue.get_all_events()
	h = hash_int(all_events.size(), h)
	for ev in all_events:
		h = hash_int(ev.get("target_tick", 0), h)
		h = hash_int(ev.get("id", 0), h)
		h = hash_string(ev.get("type", ""), h)
		h = hash_variant(ev.get("data", {}), h)
	
	# 5. Custom / global world state data
	if world_state.custom_data is Dictionary:
		h = hash_variant(world_state.custom_data, h)
	
	return h
