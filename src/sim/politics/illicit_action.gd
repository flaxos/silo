# src/sim/politics/illicit_action.gd
class_name IllicitAction
extends RefCounted

## Represents an illicit, corrupt, or nepotistic action executed by a citizen.
## Tracks the causal lineage from incentive/relationship through execution,
## hidden record discrepancy creation, discovery path, and institutional consequence.

const ACTION_DIVERSION_STOCK: String = "diversion_stock"
const ACTION_NEPOTISM_JOB: String = "nepotism_job"
const ACTION_NEPOTISM_HOUSING: String = "nepotism_housing"
const ACTION_SECURITY_SHIELD: String = "security_shield"
const ACTION_RECORD_TAMPERING: String = "record_tampering"

const STATUS_CONCEALED: int = 0
const STATUS_SUSPECTED: int = 1
const STATUS_EXPOSED: int = 2
const STATUS_SANCTIONED: int = 3

var id: int = 0
var tick: int = 0
var perpetrator_id: int = 0          # The official/worker who committed the act
var beneficiary_id: int = 0          # The relative/client who benefited
var action_type: String = ACTION_DIVERSION_STOCK

# Material & Spatial details
var target_resource: String = ""     # e.g. "machined_bearing", "metal_stock"
var target_amount: float = 0.0       # e.g. 2.0 units
var source_room_id: int = 0          # Where resources/power originated
var destination_room_id: int = 0     # Where resources were diverted or housed

# Record discrepancy tracking (official claim vs physical ground truth)
var official_record_amount: float = 0.0
var physical_actual_amount: float = 0.0
var discrepancy_amount: float = 0.0

# Concealment & Discovery lifecycle
var concealment_level: float = 0.8   # 0.0 (blatant) to 1.0 (masterfully hidden)
var discovery_status: int = STATUS_CONCEALED
var discovered_tick: int = 0
var discoverer_id: int = 0           # Auditor or whistleblower who uncovered it
var evidence_strength: float = 0.0   # 0.0 to 1.0
var penalty_applied: String = "none" # "none", "formal_warning", "demotion", "clearance_revoked", "detention"
var favour_id: int = 0               # Linked informal favour debt created
var description: String = ""

func _init(
	p_id: int = 0,
	p_tick: int = 0,
	p_perp: int = 0,
	p_ben: int = 0,
	p_type: String = ACTION_DIVERSION_STOCK
) -> void:
	id = p_id
	tick = p_tick
	perpetrator_id = p_perp
	beneficiary_id = p_ben
	action_type = p_type
	target_resource = ""
	target_amount = 0.0
	source_room_id = 0
	destination_room_id = 0
	official_record_amount = 0.0
	physical_actual_amount = 0.0
	discrepancy_amount = 0.0
	concealment_level = 0.8
	discovery_status = STATUS_CONCEALED
	discovered_tick = 0
	discoverer_id = 0
	evidence_strength = 0.0
	penalty_applied = "none"
	favour_id = 0
	description = ""

func get_status_name() -> String:
	match discovery_status:
		STATUS_CONCEALED:
			return "Concealed"
		STATUS_SUSPECTED:
			return "Suspected"
		STATUS_EXPOSED:
			return "Exposed"
		STATUS_SANCTIONED:
			return "Sanctioned"
		_:
			return "Unknown"

func serialize() -> Dictionary:
	return {
		"id": id,
		"tick": tick,
		"perpetrator_id": perpetrator_id,
		"beneficiary_id": beneficiary_id,
		"action_type": action_type,
		"target_resource": target_resource,
		"target_amount": target_amount,
		"source_room_id": source_room_id,
		"destination_room_id": destination_room_id,
		"official_record_amount": official_record_amount,
		"physical_actual_amount": physical_actual_amount,
		"discrepancy_amount": discrepancy_amount,
		"concealment_level": concealment_level,
		"discovery_status": discovery_status,
		"discovered_tick": discovered_tick,
		"discoverer_id": discoverer_id,
		"evidence_strength": evidence_strength,
		"penalty_applied": penalty_applied,
		"favour_id": favour_id,
		"description": description
	}

func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	tick = int(data.get("tick", 0))
	perpetrator_id = int(data.get("perpetrator_id", 0))
	beneficiary_id = int(data.get("beneficiary_id", 0))
	action_type = str(data.get("action_type", ACTION_DIVERSION_STOCK))
	target_resource = str(data.get("target_resource", ""))
	target_amount = float(data.get("target_amount", 0.0))
	source_room_id = int(data.get("source_room_id", 0))
	destination_room_id = int(data.get("destination_room_id", 0))
	official_record_amount = float(data.get("official_record_amount", 0.0))
	physical_actual_amount = float(data.get("physical_actual_amount", 0.0))
	discrepancy_amount = float(data.get("discrepancy_amount", 0.0))
	concealment_level = float(data.get("concealment_level", 0.8))
	discovery_status = int(data.get("discovery_status", STATUS_CONCEALED))
	discovered_tick = int(data.get("discovered_tick", 0))
	discoverer_id = int(data.get("discoverer_id", 0))
	evidence_strength = float(data.get("evidence_strength", 0.0))
	penalty_applied = str(data.get("penalty_applied", "none"))
	favour_id = int(data.get("favour_id", 0))
	description = str(data.get("description", ""))

static func from_dict(data: Dictionary) -> IllicitAction:
	var act: IllicitAction = IllicitAction.new()
	act.deserialize(data)
	return act
