# src/sim/politics/collective_action.gd
class_name CollectiveAction
extends RefCounted

## Authoritative model representing collective resistance: strikes, walkouts,
## slowdowns, protests, sabotage, and rebellions by identified citizens.

const TYPE_PETITION: String = "petition"
const TYPE_SLOWDOWN: String = "slowdown"
const TYPE_STRIKE: String = "strike"
const TYPE_PROTEST: String = "protest"
const TYPE_SABOTAGE: String = "sabotage"
const TYPE_REBELLION: String = "rebellion"

const STATUS_ORGANIZING: String = "organizing"
const STATUS_ACTIVE: String = "active"
const STATUS_NEGOTIATING: String = "negotiating"
const STATUS_CONCEDED: String = "conceded"
const STATUS_SUPPRESSED: String = "suppressed"
const STATUS_COLLAPSED: String = "collapsed"

var id: int = 0
var action_type: String = TYPE_STRIKE
var target_type: String = "workplace" # "workplace", "machine", "department", "silo"
var target_id: int = 0                # Room ID or Machine ID
var gathering_room_id: int = 0        # Location where strikers/protesters assemble
var faction_id: int = 0               # Sponsoring faction (0 = wildcat/grassroots)

var organizer_ids: Array[int] = []
var participant_ids: Array[int] = []
var demands: Array[Dictionary] = []   # e.g. [{"type": "ration_increase", "value": 1.2}]
var trigger_event_id: String = ""     # Associated Information/Event ID from Sprint 15

var status: String = STATUS_ACTIVE
var start_tick: int = 0
var end_tick: int = 0

var concessions_granted: Dictionary = {}
var sabotage_details: Dictionary = {} # {"machine_id": 1, "component_id": "c1", "damage": 50.0}

func _init(
	p_id: int = 0,
	p_type: String = TYPE_STRIKE,
	p_target_type: String = "workplace",
	p_target_id: int = 0,
	p_gathering_room: int = 0,
	p_faction_id: int = 0,
	p_start_tick: int = 0
) -> void:
	id = p_id
	action_type = p_type
	target_type = p_target_type
	target_id = p_target_id
	gathering_room_id = p_gathering_room
	faction_id = p_faction_id
	start_tick = p_start_tick
	end_tick = 0
	status = STATUS_ACTIVE
	organizer_ids = []
	participant_ids = []
	demands = []
	trigger_event_id = ""
	concessions_granted = {}
	sabotage_details = {}

func is_active() -> bool:
	return status in [STATUS_ACTIVE, STATUS_NEGOTIATING, STATUS_ORGANIZING]

func add_participant(person_id: int) -> void:
	if not participant_ids.has(person_id) and person_id > 0:
		participant_ids.append(person_id)

func add_organizer(person_id: int) -> void:
	if not organizer_ids.has(person_id) and person_id > 0:
		organizer_ids.append(person_id)
	add_participant(person_id)

func add_demand(demand_type: String, target_val: Variant, description: String = "") -> void:
	demands.append({
		"type": demand_type,
		"value": target_val,
		"description": description
	})

func serialize() -> Dictionary:
	return {
		"id": id,
		"action_type": action_type,
		"target_type": target_type,
		"target_id": target_id,
		"gathering_room_id": gathering_room_id,
		"faction_id": faction_id,
		"organizer_ids": organizer_ids.duplicate(),
		"participant_ids": participant_ids.duplicate(),
		"demands": demands.duplicate(true),
		"trigger_event_id": trigger_event_id,
		"status": status,
		"start_tick": start_tick,
		"end_tick": end_tick,
		"concessions_granted": concessions_granted.duplicate(true),
		"sabotage_details": sabotage_details.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	action_type = str(data.get("action_type", TYPE_STRIKE))
	target_type = str(data.get("target_type", "workplace"))
	target_id = int(data.get("target_id", 0))
	gathering_room_id = int(data.get("gathering_room_id", 0))
	faction_id = int(data.get("faction_id", 0))
	
	organizer_ids = []
	for oid in data.get("organizer_ids", []):
		organizer_ids.append(int(oid))
		
	participant_ids = []
	for pid in data.get("participant_ids", []):
		participant_ids.append(int(pid))
		
	demands = []
	for d in data.get("demands", []):
		if d is Dictionary:
			demands.append(d.duplicate(true))
			
	trigger_event_id = str(data.get("trigger_event_id", ""))
	status = str(data.get("status", STATUS_ACTIVE))
	start_tick = int(data.get("start_tick", 0))
	end_tick = int(data.get("end_tick", 0))
	concessions_granted = data.get("concessions_granted", {}).duplicate(true)
	sabotage_details = data.get("sabotage_details", {}).duplicate(true)
