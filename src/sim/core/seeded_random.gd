# src/sim/core/seeded_random.gd
class_name SeededRandom
extends RefCounted

var _rng: RandomNumberGenerator
var _initial_seed: int = 0

func _init(p_seed: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	init_with_seed(p_seed)

func init_with_seed(p_seed: int) -> void:
	_initial_seed = p_seed
	_rng.seed = p_seed

func randi() -> int:
	return _rng.randi()

func randf() -> float:
	return _rng.randf()

func randi_range(from_val: int, to_val: int) -> int:
	return _rng.randi_range(from_val, to_val)

func randf_range(from_val: float, to_val: float) -> float:
	return _rng.randf_range(from_val, to_val)

func rand_chance(probability: float) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return _rng.randf() < probability

func choice(array: Array) -> Variant:
	if array.is_empty():
		return null
	var idx: int = _rng.randi_range(0, array.size() - 1)
	return array[idx]

## In-place deterministic Fisher-Yates shuffle
func shuffle(array: Array) -> void:
	var n: int = array.size()
	for i in range(n - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp: Variant = array[i]
		array[i] = array[j]
		array[j] = temp

func get_initial_seed() -> int:
	return _initial_seed

func get_state() -> int:
	return _rng.state

func set_state(p_state: int) -> void:
	_rng.state = p_state

func serialize() -> Dictionary:
	return {
		"initial_seed": _initial_seed,
		"state": _rng.state
	}

func deserialize(data: Dictionary) -> void:
	_initial_seed = data.get("initial_seed", 0)
	_rng.seed = _initial_seed
	if data.has("state"):
		_rng.state = data["state"]
