# src/sim/politics/citizen_belief.gd
class_name CitizenBelief
extends RefCounted

## Represents a citizen's mental model, conviction, and doubt regarding a specific
## topic or simulation event. Bounded to prevent state bloat.

const MAX_HEARD_CLAIMS: int = 5

var topic: String = "general"
var originating_event_id: String = ""

# If the citizen directly observed or participated in the physical event
var has_direct_experience: bool = false
var known_truth: Dictionary = {}

# What the citizen currently accepts as most plausible
var believed_claim: Dictionary = {}
var believed_info_id: int = 0
var confidence: float = 0.5 # 0.0 (total uncertainty) to 1.0 (firm conviction)
var doubt: float = 0.0      # 0.0 (no skepticism) to 1.0 (acute doubt / suspicion)

# Bounded history of different claims heard for this topic
var heard_claims: Array[Dictionary] = []
var last_updated_tick: int = 0

func _init(
	p_event_id: String = "",
	p_topic: String = "general",
	p_direct: bool = false,
	p_truth: Dictionary = {}
) -> void:
	originating_event_id = p_event_id
	topic = p_topic
	has_direct_experience = p_direct
	known_truth = p_truth.duplicate(true)
	believed_claim = p_truth.duplicate(true) if p_direct else {}
	believed_info_id = 0
	confidence = 1.0 if p_direct else 0.5
	doubt = 0.0
	heard_claims = []
	last_updated_tick = 0

func is_convinced() -> bool:
	return confidence >= 0.65 and doubt < 0.35

func is_skeptical() -> bool:
	return doubt >= 0.5 or (confidence < 0.4 and not heard_claims.is_empty())

func is_aware() -> bool:
	return has_direct_experience or not heard_claims.is_empty()

## Records exposure to a claim from an information object
func add_heard_claim(
	info_id: int,
	claim_data: Dictionary,
	source_type: String,
	source_id: int,
	perceived_credibility: float,
	current_tick: int
) -> void:
	last_updated_tick = current_tick
	
	# Check if claim from this info_id already recorded
	for item in heard_claims:
		if int(item.get("info_id", 0)) == info_id:
			# Update credibility and tick
			item["perceived_credibility"] = perceived_credibility
			item["tick"] = current_tick
			return
			
	# If capacity reached, remove the oldest non-believed claim
	if heard_claims.size() >= MAX_HEARD_CLAIMS:
		var remove_idx: int = -1
		for i in range(heard_claims.size()):
			if int(heard_claims[i].get("info_id", 0)) != believed_info_id:
				remove_idx = i
				break
		if remove_idx >= 0:
			heard_claims.remove_at(remove_idx)
		else:
			heard_claims.pop_front()
			
	heard_claims.append({
		"info_id": info_id,
		"claim": claim_data.duplicate(true),
		"source_type": source_type,
		"source_id": source_id,
		"perceived_credibility": perceived_credibility,
		"tick": current_tick
	})

func serialize() -> Dictionary:
	return {
		"topic": topic,
		"originating_event_id": originating_event_id,
		"has_direct_experience": has_direct_experience,
		"known_truth": known_truth.duplicate(true),
		"believed_claim": believed_claim.duplicate(true),
		"believed_info_id": believed_info_id,
		"confidence": confidence,
		"doubt": doubt,
		"heard_claims": heard_claims.duplicate(true),
		"last_updated_tick": last_updated_tick
	}

func deserialize(data: Dictionary) -> void:
	topic = str(data.get("topic", "general"))
	originating_event_id = str(data.get("originating_event_id", ""))
	has_direct_experience = bool(data.get("has_direct_experience", false))
	known_truth = data.get("known_truth", {}).duplicate(true)
	believed_claim = data.get("believed_claim", {}).duplicate(true)
	believed_info_id = int(data.get("believed_info_id", 0))
	confidence = float(data.get("confidence", 0.5))
	doubt = float(data.get("doubt", 0.0))
	heard_claims = []
	for hc in data.get("heard_claims", []):
		if hc is Dictionary:
			heard_claims.append(hc.duplicate(true))
	last_updated_tick = int(data.get("last_updated_tick", 0))
