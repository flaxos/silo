# src/sim/politics/information_object.gd
class_name InformationObject
extends RefCounted

## Authoritative model representing an informational message, broadcast, leak, or rumour.
## Links claims to an underlying truth basis without rewriting simulation truth.

const CHANNEL_OFFICIAL: String = "OFFICIAL_ANNOUNCEMENT"
const CHANNEL_NOTICE_BOARD: String = "NOTICE_BOARD"
const CHANNEL_WORKPLACE: String = "WORKPLACE_COMM"
const CHANNEL_FACTION: String = "FACTION_CHANNEL"
const CHANNEL_WORD_OF_MOUTH: String = "WORD_OF_MOUTH"

const STATE_ACTIVE: String = "ACTIVE"
const STATE_DELAYED: String = "DELAYED"
const STATE_REDACTED: String = "REDACTED"
const STATE_SUPPRESSED: String = "SUPPRESSED"
const STATE_DENIED: String = "DENIED"

const CLASS_PUBLIC: String = "PUBLIC"
const CLASS_INTERNAL: String = "INTERNAL"
const CLASS_CONFIDENTIAL: String = "CONFIDENTIAL"
const CLASS_RESTRICTED: String = "RESTRICTED"
const CLASS_CLANDESTINE: String = "CLANDESTINE"

var id: int = 0
var originating_event_id: String = ""
var source_entity_type: String = "institution" # "institution", "citizen", "faction"
var source_entity_id: int = 0
var topic: String = "general"

# Physical and simulation truth referenced by this message (read-only facts)
var truth_basis: Dictionary = {}

# The assertion or framing presented to recipients (may be truthful, biased, or outright fabricated)
var claim: Dictionary = {}

var certainty: float = 1.0          # 0.0 to 1.0: certainty asserted in message
var credibility: float = 0.8        # 0.0 to 1.0: base objective plausibility/evidence backing
var emotional_salience: float = 0.5 # 0.0 to 1.0: how urgently citizens react/spread it
var classification: String = CLASS_PUBLIC
var created_tick: int = 0
var channel_type: String = CHANNEL_OFFICIAL
var target_audience: Dictionary = {"type": "all"} # "all", "department", "workplace", "faction", "sector"

# Censorship and transmission lifecycle
var censorship_state: String = STATE_ACTIVE
var redacted_fields: Array[String] = []
var delay_ticks_remaining: int = 0
var disseminated_count: int = 0
var reach_count: int = 0

func _init(
	p_id: int = 0,
	p_event_id: String = "",
	p_source_type: String = "institution",
	p_source_id: int = 0,
	p_topic: String = "general",
	p_truth_basis: Dictionary = {},
	p_claim: Dictionary = {},
	p_channel: String = CHANNEL_OFFICIAL,
	p_created_tick: int = 0
) -> void:
	id = p_id
	originating_event_id = p_event_id
	source_entity_type = p_source_type
	source_entity_id = p_source_id
	topic = p_topic
	truth_basis = p_truth_basis.duplicate(true)
	claim = p_claim.duplicate(true)
	channel_type = p_channel
	created_tick = p_created_tick
	censorship_state = STATE_ACTIVE
	redacted_fields = []
	delay_ticks_remaining = 0
	disseminated_count = 0
	reach_count = 0

## Returns the claim as visible to recipients after applying active redactions
func get_visible_claim() -> Dictionary:
	var visible: Dictionary = claim.duplicate(true)
	if censorship_state == STATE_REDACTED:
		for field in redacted_fields:
			if visible.has(field):
				visible[field] = "[REDACTED BY EXECUTIVE CENSORSHIP]"
	return visible

func is_suppressed() -> bool:
	return censorship_state == STATE_SUPPRESSED

func is_delayed() -> bool:
	return censorship_state == STATE_DELAYED and delay_ticks_remaining > 0

func serialize() -> Dictionary:
	return {
		"id": id,
		"originating_event_id": originating_event_id,
		"source_entity_type": source_entity_type,
		"source_entity_id": source_entity_id,
		"topic": topic,
		"truth_basis": truth_basis.duplicate(true),
		"claim": claim.duplicate(true),
		"certainty": certainty,
		"credibility": credibility,
		"emotional_salience": emotional_salience,
		"classification": classification,
		"created_tick": created_tick,
		"channel_type": channel_type,
		"target_audience": target_audience.duplicate(true),
		"censorship_state": censorship_state,
		"redacted_fields": redacted_fields.duplicate(),
		"delay_ticks_remaining": delay_ticks_remaining,
		"disseminated_count": disseminated_count,
		"reach_count": reach_count
	}

func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	originating_event_id = str(data.get("originating_event_id", ""))
	source_entity_type = str(data.get("source_entity_type", "institution"))
	source_entity_id = int(data.get("source_entity_id", 0))
	topic = str(data.get("topic", "general"))
	truth_basis = data.get("truth_basis", {}).duplicate(true)
	claim = data.get("claim", {}).duplicate(true)
	certainty = float(data.get("certainty", 1.0))
	credibility = float(data.get("credibility", 0.8))
	emotional_salience = float(data.get("emotional_salience", 0.5))
	classification = str(data.get("classification", CLASS_PUBLIC))
	created_tick = int(data.get("created_tick", 0))
	channel_type = str(data.get("channel_type", CHANNEL_OFFICIAL))
	target_audience = data.get("target_audience", {"type": "all"}).duplicate(true)
	censorship_state = str(data.get("censorship_state", STATE_ACTIVE))
	redacted_fields = []
	for rf in data.get("redacted_fields", []):
		redacted_fields.append(str(rf))
	delay_ticks_remaining = int(data.get("delay_ticks_remaining", 0))
	disseminated_count = int(data.get("disseminated_count", 0))
	reach_count = int(data.get("reach_count", 0))
