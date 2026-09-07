# src/sim/population/relationship.gd
class_name Relationship
extends RefCounted

## Authoritative model representing a bilateral interpersonal relationship.

const STATUS_STRANGER: int = 0
const STATUS_ACQUAINTANCE: int = 1
const STATUS_FRIEND: int = 2
const STATUS_CLOSE_FRIEND: int = 3
const STATUS_ROMANTIC_INTEREST: int = 4
const STATUS_PARTNER: int = 5
const STATUS_ESTRANGED: int = 6

var person_a_id: int = 0
var person_b_id: int = 0
var familiarity: float = 0.0      # 0.0 to 100.0
var affection: float = 50.0       # 0.0 to 100.0
var attraction: float = 0.0      # 0.0 to 100.0
var trust: float = 50.0           # 0.0 to 100.0
var conflict: float = 0.0        # 0.0 to 100.0
var status: int = STATUS_STRANGER
var shared_history_ticks: int = 0

func _init(p_a: int = 0, p_b: int = 0) -> void:
	if p_a < p_b:
		person_a_id = p_a
		person_b_id = p_b
	else:
		person_a_id = p_b
		person_b_id = p_a
	familiarity = 0.0
	affection = 50.0
	attraction = 0.0
	trust = 50.0
	conflict = 0.0
	status = STATUS_STRANGER
	shared_history_ticks = 0

static func make_key(id1: int, id2: int) -> String:
	var low: int = mini(id1, id2)
	var high: int = maxi(id1, id2)
	return "%d_%d" % [low, high]

func clamp_values() -> void:
	familiarity = clampf(familiarity, 0.0, 100.0)
	affection = clampf(affection, 0.0, 100.0)
	attraction = clampf(attraction, 0.0, 100.0)
	trust = clampf(trust, 0.0, 100.0)
	conflict = clampf(conflict, 0.0, 100.0)

func update_status() -> void:
	clamp_values()
	if status == STATUS_PARTNER:
		if conflict >= 85.0 and affection <= 15.0:
			status = STATUS_ESTRANGED
		return
	elif status == STATUS_ESTRANGED:
		if conflict < 40.0 and affection > 50.0:
			status = STATUS_ACQUAINTANCE
		return
		
	if attraction >= 50.0 and affection >= 50.0 and familiarity >= 40.0:
		status = STATUS_ROMANTIC_INTEREST
	elif familiarity >= 70.0 and affection >= 70.0 and conflict < 30.0:
		status = STATUS_CLOSE_FRIEND
	elif familiarity >= 35.0 and affection >= 50.0:
		status = STATUS_FRIEND
	elif familiarity >= 15.0:
		status = STATUS_ACQUAINTANCE
	else:
		status = STATUS_STRANGER

func serialize() -> Dictionary:
	return {
		"person_a_id": person_a_id,
		"person_b_id": person_b_id,
		"familiarity": familiarity,
		"affection": affection,
		"attraction": attraction,
		"trust": trust,
		"conflict": conflict,
		"status": status,
		"shared_history_ticks": shared_history_ticks
	}

func deserialize(data: Dictionary) -> void:
	person_a_id = int(data.get("person_a_id", 0))
	person_b_id = int(data.get("person_b_id", 0))
	familiarity = float(data.get("familiarity", 0.0))
	affection = float(data.get("affection", 50.0))
	attraction = float(data.get("attraction", 0.0))
	trust = float(data.get("trust", 50.0))
	conflict = float(data.get("conflict", 0.0))
	status = int(data.get("status", STATUS_STRANGER))
	shared_history_ticks = int(data.get("shared_history_ticks", 0))
	clamp_values()
