# src/sim/politics/favour.gd
class_name Favour
extends RefCounted

## Represents an informal social obligation or debt between two citizens.
## Arises when one citizen uses their position or resources to benefit another outside formal channels.

const FAVOUR_RESOURCE_DIVERSION: String = "resource_diversion"
const FAVOUR_HOUSING_ASSIGNMENT: String = "housing_assignment"
const FAVOUR_WORK_PREFERENCE: String = "work_preference"
const FAVOUR_SECURITY_LENIENCY: String = "security_leniency"
const FAVOUR_RECORD_TAMPERING: String = "record_tampering"

var id: int = 0
var granter_id: int = 0     # The patron / person who granted the favour
var recipient_id: int = 0   # The client / person who received benefit and owes the debt
var creation_tick: int = 0
var favour_type: String = FAVOUR_RESOURCE_DIVERSION
var obligation_value: float = 0.5 # 0.1 (minor) to 1.0 (life-altering / deep leverage)
var is_settled: bool = false
var settled_tick: int = 0
var description: String = ""

func _init(
	p_id: int = 0,
	p_granter: int = 0,
	p_recipient: int = 0,
	p_tick: int = 0,
	p_type: String = FAVOUR_RESOURCE_DIVERSION,
	p_value: float = 0.5,
	p_desc: String = ""
) -> void:
	id = p_id
	granter_id = p_granter
	recipient_id = p_recipient
	creation_tick = p_tick
	favour_type = p_type
	obligation_value = clampf(p_value, 0.0, 1.0)
	is_settled = false
	settled_tick = 0
	description = p_desc

func settle(tick: int) -> void:
	is_settled = true
	settled_tick = tick

func serialize() -> Dictionary:
	return {
		"id": id,
		"granter_id": granter_id,
		"recipient_id": recipient_id,
		"creation_tick": creation_tick,
		"favour_type": favour_type,
		"obligation_value": obligation_value,
		"is_settled": is_settled,
		"settled_tick": settled_tick,
		"description": description
	}

func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	granter_id = int(data.get("granter_id", 0))
	recipient_id = int(data.get("recipient_id", 0))
	creation_tick = int(data.get("creation_tick", 0))
	favour_type = str(data.get("favour_type", FAVOUR_RESOURCE_DIVERSION))
	obligation_value = float(data.get("obligation_value", 0.5))
	is_settled = bool(data.get("is_settled", false))
	settled_tick = int(data.get("settled_tick", 0))
	description = str(data.get("description", ""))

static func from_dict(data: Dictionary) -> Favour:
	var f: Favour = Favour.new()
	f.deserialize(data)
	return f
