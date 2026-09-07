# src/sim/law/crime_incident.gd
class_name CrimeIncident
extends RefCounted

## Authoritative model representing a systemic criminal offense or violation.
## Every crime references real citizens, real locations, real inventory, and real physical evidence.

const TYPE_THEFT: String = "theft"
const TYPE_DIVERSION: String = "inventory_diversion"
const TYPE_CONTRABAND: String = "contraband"
const TYPE_VANDALISM: String = "vandalism"
const TYPE_ASSAULT: String = "assault"
const TYPE_BLACK_MARKET: String = "black_market_trade"
const TYPE_FRAUD: String = "fraud"

const STATUS_COMMITTED: String = "committed"
const STATUS_DISCOVERED: String = "discovered"
const STATUS_INVESTIGATING: String = "investigating"
const STATUS_SOLVED: String = "solved"
const STATUS_CLOSED_UNSOLVED: String = "closed_unsolved"

var id: int = 0
var crime_type: String = TYPE_THEFT
var perpetrator_id: int = 0
var victim_id: int = 0                   # 0 if state / public inventory
var location_room_id: int = 0
var tick_occurred: int = 0

var resource_id: String = ""             # Physical item involved, if any
var quantity: float = 0.0
var target_machine_id: int = 0           # For vandalism
var target_component_id: String = ""

var motive: String = "scarcity"          # "scarcity", "grievance", "greed", "survival", "black_market"
var concealment_level: float = 0.5       # 0.0 (blatant) to 1.0 (impeccably hidden)
var status: String = STATUS_COMMITTED

# Grounded Physical Evidence
var evidence: Dictionary = {
	"badge_log_recorded": false,
	"cctv_recorded": false,
	"witness_ids": [],
	"inventory_discrepancy": 0.0,
	"physical_traces": ""
}

func _init(
	p_id: int = 0,
	p_type: String = TYPE_THEFT,
	p_perp_id: int = 0,
	p_location: int = 0,
	p_tick: int = 0,
	p_resource_id: String = "",
	p_quantity: float = 0.0
) -> void:
	id = p_id
	crime_type = p_type
	perpetrator_id = p_perp_id
	victim_id = 0
	location_room_id = p_location
	tick_occurred = p_tick
	resource_id = p_resource_id
	quantity = p_quantity
	target_machine_id = 0
	target_component_id = ""
	motive = "scarcity"
	concealment_level = 0.5
	status = STATUS_COMMITTED
	evidence = {
		"badge_log_recorded": false,
		"cctv_recorded": false,
		"witness_ids": [],
		"inventory_discrepancy": 0.0,
		"physical_traces": ""
	}

func serialize() -> Dictionary:
	var w_ids: Array = []
	for wid in evidence.get("witness_ids", []):
		w_ids.append(int(wid))
	w_ids.sort()
	
	return {
		"id": id,
		"crime_type": crime_type,
		"perpetrator_id": perpetrator_id,
		"victim_id": victim_id,
		"location_room_id": location_room_id,
		"tick_occurred": tick_occurred,
		"resource_id": resource_id,
		"quantity": quantity,
		"target_machine_id": target_machine_id,
		"target_component_id": target_component_id,
		"motive": motive,
		"concealment_level": concealment_level,
		"status": status,
		"evidence": {
			"badge_log_recorded": bool(evidence.get("badge_log_recorded", false)),
			"cctv_recorded": bool(evidence.get("cctv_recorded", false)),
			"witness_ids": w_ids,
			"inventory_discrepancy": float(evidence.get("inventory_discrepancy", 0.0)),
			"physical_traces": str(evidence.get("physical_traces", ""))
		}
	}

func deserialize(d: Dictionary) -> void:
	id = int(d.get("id", 0))
	crime_type = str(d.get("crime_type", TYPE_THEFT))
	perpetrator_id = int(d.get("perpetrator_id", 0))
	victim_id = int(d.get("victim_id", 0))
	location_room_id = int(d.get("location_room_id", 0))
	tick_occurred = int(d.get("tick_occurred", 0))
	resource_id = str(d.get("resource_id", ""))
	quantity = float(d.get("quantity", 0.0))
	target_machine_id = int(d.get("target_machine_id", 0))
	target_component_id = str(d.get("target_component_id", ""))
	motive = str(d.get("motive", "scarcity"))
	concealment_level = float(d.get("concealment_level", 0.5))
	status = str(d.get("status", STATUS_COMMITTED))
	
	var ev_dict: Dictionary = d.get("evidence", {})
	var w_ids: Array[int] = []
	for wid in ev_dict.get("witness_ids", []):
		w_ids.append(int(wid))
	w_ids.sort()
	
	evidence = {
		"badge_log_recorded": bool(ev_dict.get("badge_log_recorded", false)),
		"cctv_recorded": bool(ev_dict.get("cctv_recorded", false)),
		"witness_ids": w_ids,
		"inventory_discrepancy": float(ev_dict.get("inventory_discrepancy", 0.0)),
		"physical_traces": str(ev_dict.get("physical_traces", ""))
	}
