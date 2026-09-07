# src/sim/core/entity_registry.gd
class_name EntityRegistry
extends RefCounted

var _next_id: int = 1
var _entities: Dictionary = {}        # int id -> Variant entity
var _entity_types: Dictionary = {}    # int id -> String type_name
var _type_indices: Dictionary = {}    # String type_name -> Array[int] entity_ids

func _init() -> void:
	clear()

func clear() -> void:
	_next_id = 1
	_entities.clear()
	_entity_types.clear()
	_type_indices.clear()

func generate_id() -> int:
	var id: int = _next_id
	_next_id += 1
	return id

func register_entity(entity_type: String, entity_data: Variant, explicit_id: int = 0) -> int:
	var id: int = explicit_id
	if id <= 0:
		id = generate_id()
	else:
		if id >= _next_id:
			_next_id = id + 1
	
	if _entities.has(id):
		push_error("EntityRegistry: ID %d already registered. Overwriting." % id)
		var old_type: String = _entity_types.get(id, "")
		if _type_indices.has(old_type):
			var old_list: Array[int] = _type_indices[old_type]
			old_list.erase(id)
	
	_entities[id] = entity_data
	_entity_types[id] = entity_type
	
	if not _type_indices.has(entity_type):
		var new_list: Array[int] = []
		_type_indices[entity_type] = new_list
	var type_list: Array[int] = _type_indices[entity_type]
	if not type_list.has(id):
		type_list.append(id)
	
	return id

func get_entity(id: int) -> Variant:
	return _entities.get(id, null)

func has_entity(id: int) -> bool:
	return _entities.has(id)

func get_entity_type(id: int) -> String:
	return _entity_types.get(id, "")

func remove_entity(id: int) -> bool:
	if not _entities.has(id):
		return false
	
	var entity_type: String = _entity_types.get(id, "")
	_entities.erase(id)
	_entity_types.erase(id)
	
	if _type_indices.has(entity_type):
		var type_list: Array[int] = _type_indices[entity_type]
		type_list.erase(id)
		if type_list.is_empty():
			_type_indices.erase(entity_type)
	
	return true

func get_entities_by_type(entity_type: String) -> Array[int]:
	if not _type_indices.has(entity_type):
		return []
	return _type_indices[entity_type]

## Returns all entity IDs sorted in ascending order for deterministic iteration
func get_all_ids() -> Array[int]:
	var ids: Array[int] = []
	for k in _entities.keys():
		ids.append(int(k))
	ids.sort()
	return ids

func get_entity_count() -> int:
	return _entities.size()

func get_next_id() -> int:
	return _next_id

func serialize() -> Dictionary:
	var serialized_entities: Array[Dictionary] = []
	var ids: Array[int] = get_all_ids()
	for id in ids:
		var ent: Variant = _entities[id]
		var ent_data: Variant = ent
		if ent is Object and ent.has_method("serialize"):
			ent_data = ent.serialize()
		serialized_entities.append({
			"id": id,
			"type": _entity_types[id],
			"data": ent_data
		})
	
	return {
		"next_id": _next_id,
		"entities": serialized_entities
	}

func deserialize(data: Dictionary) -> void:
	clear()
	_next_id = data.get("next_id", 1)
	var serialized_entities: Array = data.get("entities", [])
	for item in serialized_entities:
		var id: int = item.get("id", 0)
		var ent_type: String = item.get("type", "")
		var ent_data: Variant = item.get("data", null)
		if id > 0:
			register_entity(ent_type, ent_data, id)
