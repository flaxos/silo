# src/sim/politics/opinion_memory.gd
class_name OpinionMemory
extends RefCounted

## Represents a persistent memory of a lived experience that contributes to a citizen's political attitudes.

const HALF_LIFE_TICKS: int = 4320 # 30 days halflife

var event_type: String = ""
var onset_tick: int = 0
var attribution_dept: String = "" # "administration", "engineering", "security", "it", "utilities", "logistics"
var emotional_impact: float = 0.0 # -1.0 (extremely negative) to +1.0 (extremely positive)
var salience: float = 1.0         # 1.0 down to 0.0
var description: String = ""
var source_entity_id: int = 0

func _init(
	p_type: String = "",
	p_tick: int = 0,
	p_dept: String = "",
	p_impact: float = 0.0,
	p_desc: String = "",
	p_source_id: int = 0
) -> void:
	event_type = p_type
	onset_tick = p_tick
	attribution_dept = p_dept
	emotional_impact = clampf(p_impact, -1.0, 1.0)
	description = p_desc
	source_entity_id = p_source_id
	salience = 1.0

func get_current_salience(current_tick: int) -> float:
	var age_ticks: int = maxi(0, current_tick - onset_tick)
	# Exponential decay based on 30-day halflife
	var halflifes: float = float(age_ticks) / float(HALF_LIFE_TICKS)
	return pow(0.5, halflifes)

func serialize() -> Dictionary:
	return {
		"event_type": event_type,
		"onset_tick": onset_tick,
		"attribution_dept": attribution_dept,
		"emotional_impact": emotional_impact,
		"salience": salience,
		"description": description,
		"source_entity_id": source_entity_id
	}

static func from_dict(data: Dictionary) -> RefCounted:
	var script: GDScript = load("res://src/sim/politics/opinion_memory.gd") as GDScript
	var mem: RefCounted = script.new(
		data.get("event_type", ""),
		int(data.get("onset_tick", 0)),
		data.get("attribution_dept", ""),
		float(data.get("emotional_impact", 0.0)),
		data.get("description", ""),
		int(data.get("source_entity_id", 0))
	)
	mem.salience = float(data.get("salience", 1.0))
	return mem
