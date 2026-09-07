# src/sim/households/room.gd
class_name Room
extends RefCounted

const TYPE_RESIDENTIAL_APARTMENT: int = 0
const TYPE_DORMITORY: int = 1
const TYPE_CANTEEN: int = 2
const TYPE_KITCHEN: int = 3
const TYPE_HYGIENE_FACILITY: int = 4
const TYPE_MACHINE_SHOP: int = 5
const TYPE_FOUNDRY: int = 6
const TYPE_DEEP_MINE: int = 7
const TYPE_WATER_PUMP_STATION: int = 8
const TYPE_SERVER_ROOM: int = 9
const TYPE_CLINIC: int = 10
const TYPE_SCHOOL: int = 11
const TYPE_ADMINISTRATION: int = 12
const TYPE_RECREATION: int = 13
const TYPE_STORAGE: int = 14
const TYPE_SECURITY_POST: int = 15
const TYPE_BIO_FARM: int = 16
const TYPE_FOOD_PROCESSING: int = 17
const TYPE_WASTE_PROCESSING: int = 18
const TYPE_AIR_HANDLER: int = 19
const TYPE_POWER_PLANT: int = 20
const TYPE_STAIRCASE: int = 21
const TYPE_CORRIDOR: int = 22
const TYPE_WASTEWATER_TREATMENT: int = 23

var id: int = 0
var sector_id: int = 1
var level: int = 1
var room_type: int = TYPE_RESIDENTIAL_APARTMENT
var capacity_people: int = 4
var bed_count: int = 4
var occupied_beds: Dictionary = {} # int bed_index -> int person_id
var inventory_id: int = 0

func _init(p_id: int = 0, p_type: int = TYPE_RESIDENTIAL_APARTMENT, p_bed_count: int = 4, p_sector: int = 1, p_level: int = 1) -> void:
	id = p_id
	room_type = p_type
	bed_count = p_bed_count
	capacity_people = p_bed_count
	sector_id = p_sector
	level = p_level
	occupied_beds = {}
	inventory_id = 0

func allocate_bed(person_id: int) -> int:
	for bed_idx in range(bed_count):
		if not occupied_beds.has(bed_idx):
			occupied_beds[bed_idx] = person_id
			return bed_idx
	return -1

func allocate_specific_bed(bed_idx: int, person_id: int) -> bool:
	if bed_idx < 0 or bed_idx >= bed_count:
		return false
	if occupied_beds.has(bed_idx):
		return false
	occupied_beds[bed_idx] = person_id
	return true

func free_bed(person_id: int) -> bool:
	for bed_idx in occupied_beds.keys():
		if occupied_beds[bed_idx] == person_id:
			occupied_beds.erase(bed_idx)
			return true
	return false

func free_bed_index(bed_idx: int) -> bool:
	if occupied_beds.has(bed_idx):
		occupied_beds.erase(bed_idx)
		return true
	return false

func get_occupant_of_bed(bed_idx: int) -> int:
	return occupied_beds.get(bed_idx, 0)

func is_bed_available(bed_idx: int) -> bool:
	if bed_idx < 0 or bed_idx >= bed_count:
		return false
	return not occupied_beds.has(bed_idx)

func get_available_bed_count() -> int:
	return bed_count - occupied_beds.size()

func get_occupied_bed_count() -> int:
	return occupied_beds.size()

func serialize() -> Dictionary:
	var beds_data: Dictionary = {}
	for k in occupied_beds.keys():
		beds_data[str(k)] = occupied_beds[k]
	return {
		"id": id,
		"sector_id": sector_id,
		"level": level,
		"room_type": room_type,
		"capacity_people": capacity_people,
		"bed_count": bed_count,
		"occupied_beds": beds_data,
		"inventory_id": inventory_id
	}

func deserialize(data: Dictionary) -> void:
	id = data.get("id", 0)
	sector_id = data.get("sector_id", 1)
	level = data.get("level", 1)
	room_type = data.get("room_type", TYPE_RESIDENTIAL_APARTMENT)
	capacity_people = data.get("capacity_people", 4)
	bed_count = data.get("bed_count", 4)
	inventory_id = data.get("inventory_id", 0)
	
	occupied_beds.clear()
	var raw_beds: Dictionary = data.get("occupied_beds", {})
	for k in raw_beds.keys():
		occupied_beds[int(k)] = int(raw_beds[k])
