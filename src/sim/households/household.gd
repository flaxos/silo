# src/sim/households/household.gd
class_name Household
extends RefCounted

var id: int = 0
var name: String = ""
var home_room_id: int = 0
var head_id: int = 0
var member_ids: Array[int] = []
var ration_tier: int = 1

func _init(p_id: int = 0, p_name: String = "", p_home_room_id: int = 0, p_head_id: int = 0) -> void:
	id = p_id
	name = p_name
	home_room_id = p_home_room_id
	head_id = p_head_id
	member_ids = []
	ration_tier = 1
	if head_id > 0:
		member_ids.append(head_id)

func add_member(person_id: int) -> void:
	if not member_ids.has(person_id):
		member_ids.append(person_id)
		if head_id == 0:
			head_id = person_id

func remove_member(person_id: int) -> bool:
	var idx: int = member_ids.find(person_id)
	if idx != -1:
		member_ids.remove_at(idx)
		if head_id == person_id:
			head_id = member_ids[0] if not member_ids.is_empty() else 0
		return true
	return false

func has_member(person_id: int) -> bool:
	return member_ids.has(person_id)

func get_member_count() -> int:
	return member_ids.size()

func serialize() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"home_room_id": home_room_id,
		"head_id": head_id,
		"member_ids": member_ids.duplicate(),
		"ration_tier": ration_tier
	}

func deserialize(data: Dictionary) -> void:
	id = data.get("id", 0)
	name = data.get("name", "")
	home_room_id = data.get("home_room_id", 0)
	head_id = data.get("head_id", 0)
	ration_tier = data.get("ration_tier", 1)
	
	member_ids = []
	for mid in data.get("member_ids", []):
		member_ids.append(int(mid))
