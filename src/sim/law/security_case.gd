# src/sim/law/security_case.gd
class_name SecurityCase
extends RefCounted

## Authoritative representation of a security case investigation,
## evidence collection, suspect evaluation, arrest, and sentencing.

const STATUS_OPEN: String = "open"
const STATUS_INVESTIGATING: String = "investigating"
const STATUS_WARRANT: String = "warrant_issued"
const STATUS_ARRESTED: String = "arrested"
const STATUS_CONVICTED: String = "convicted"
const STATUS_COLD_CASE: String = "cold_case"
const STATUS_DISMISSED: String = "dismissed"

const VERDICT_NONE: String = "none"
const VERDICT_GUILTY_CORRECT: String = "guilty_correct"
const VERDICT_WRONGFUL_CONVICTION: String = "wrongful_conviction"
const VERDICT_UNSOLVED: String = "unsolved"

var id: int = 0
var crime_incident_id: int = 0
var assigned_officer_id: int = 0
var lead_suspect_id: int = 0
var actual_perpetrator_id: int = 0

var suspect_scores: Dictionary = {} # int person_id -> float score (0.0 to 1.0)
var gathered_evidence: Dictionary = {
	"badge_log_verified": false,
	"cctv_footage_available": false,
	"witnesses_interviewed": [],
	"physical_traces_analyzed": false,
	"inventory_discrepancy_verified": 0.0
}

var actions_taken: Array[String] = []
var confidence: float = 0.0
var status: String = STATUS_OPEN
var verdict: String = VERDICT_NONE
var start_tick: int = 0
var resolved_tick: int = 0

var sentence_duration_ticks: int = 0
var sentence_ticks_remaining: int = 0

func _init(
	p_id: int = 0,
	p_crime_id: int = 0,
	p_officer_id: int = 0,
	p_start_tick: int = 0
) -> void:
	id = p_id
	crime_incident_id = p_crime_id
	assigned_officer_id = p_officer_id
	lead_suspect_id = 0
	actual_perpetrator_id = 0
	suspect_scores = {}
	gathered_evidence = {
		"badge_log_verified": false,
		"cctv_footage_available": false,
		"witnesses_interviewed": [],
		"physical_traces_analyzed": false,
		"inventory_discrepancy_verified": 0.0
	}
	actions_taken = []
	confidence = 0.0
	status = STATUS_OPEN
	verdict = VERDICT_NONE
	start_tick = p_start_tick
	resolved_tick = 0
	sentence_duration_ticks = 0
	sentence_ticks_remaining = 0

func serialize() -> Dictionary:
	var w_interviewed: Array = []
	for wid in gathered_evidence.get("witnesses_interviewed", []):
		w_interviewed.append(int(wid))
	w_interviewed.sort()
	
	var sorted_suspects: Dictionary = {}
	var s_keys: Array = suspect_scores.keys()
	s_keys.sort()
	for k in s_keys:
		sorted_suspects[str(k)] = float(suspect_scores[k])
		
	var sorted_actions: Array = actions_taken.duplicate()
	sorted_actions.sort()
	
	return {
		"id": id,
		"crime_incident_id": crime_incident_id,
		"assigned_officer_id": assigned_officer_id,
		"lead_suspect_id": lead_suspect_id,
		"actual_perpetrator_id": actual_perpetrator_id,
		"suspect_scores": sorted_suspects,
		"gathered_evidence": {
			"badge_log_verified": bool(gathered_evidence.get("badge_log_verified", false)),
			"cctv_footage_available": bool(gathered_evidence.get("cctv_footage_available", false)),
			"witnesses_interviewed": w_interviewed,
			"physical_traces_analyzed": bool(gathered_evidence.get("physical_traces_analyzed", false)),
			"inventory_discrepancy_verified": float(gathered_evidence.get("inventory_discrepancy_verified", 0.0))
		},
		"actions_taken": sorted_actions,
		"confidence": confidence,
		"status": status,
		"verdict": verdict,
		"start_tick": start_tick,
		"resolved_tick": resolved_tick,
		"sentence_duration_ticks": sentence_duration_ticks,
		"sentence_ticks_remaining": sentence_ticks_remaining
	}

func deserialize(d: Dictionary) -> void:
	id = int(d.get("id", 0))
	crime_incident_id = int(d.get("crime_incident_id", 0))
	assigned_officer_id = int(d.get("assigned_officer_id", 0))
	lead_suspect_id = int(d.get("lead_suspect_id", 0))
	actual_perpetrator_id = int(d.get("actual_perpetrator_id", 0))
	confidence = float(d.get("confidence", 0.0))
	status = str(d.get("status", STATUS_OPEN))
	verdict = str(d.get("verdict", VERDICT_NONE))
	start_tick = int(d.get("start_tick", 0))
	resolved_tick = int(d.get("resolved_tick", 0))
	sentence_duration_ticks = int(d.get("sentence_duration_ticks", 0))
	sentence_ticks_remaining = int(d.get("sentence_ticks_remaining", 0))
	
	suspect_scores = {}
	var s_dict: Dictionary = d.get("suspect_scores", {})
	for k in s_dict.keys():
		suspect_scores[int(k)] = float(s_dict[k])
		
	var ev: Dictionary = d.get("gathered_evidence", {})
	var w_list: Array[int] = []
	for wid in ev.get("witnesses_interviewed", []):
		w_list.append(int(wid))
	w_list.sort()
	
	gathered_evidence = {
		"badge_log_verified": bool(ev.get("badge_log_verified", false)),
		"cctv_footage_available": bool(ev.get("cctv_footage_available", false)),
		"witnesses_interviewed": w_list,
		"physical_traces_analyzed": bool(ev.get("physical_traces_analyzed", false)),
		"inventory_discrepancy_verified": float(ev.get("inventory_discrepancy_verified", 0.0))
	}
	
	actions_taken = []
	for act in d.get("actions_taken", []):
		actions_taken.append(str(act))
	actions_taken.sort()
