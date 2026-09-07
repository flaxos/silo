# src/sim/incidents/incident.gd
class_name Incident
extends RefCounted

const SEVERITY_ADVISORY: int = 0   # Informational notice / telemetry drift
const SEVERITY_WARNING: int = 1    # Elevated risk, approaching operating bounds
const SEVERITY_CRITICAL: int = 2   # Urgent degradation, active failure risk
const SEVERITY_EMERGENCY: int = 3  # Critical breakdown, imminent systemic cascade

const INCIDENT_WATER_RESERVOIR_DEPLETING: String = "incident_water_reservoir_depleting"
const INCIDENT_CRITICAL_PUMP_WEAR: String = "incident_critical_pump_wear"
const INCIDENT_SPARE_PARTS_STOCKOUT: String = "incident_spare_parts_stockout"
const INCIDENT_FOUNDRY_LABOR_STARVATION: String = "incident_foundry_labor_starvation"
const INCIDENT_DEHYDRATION_EPIDEMIC: String = "incident_dehydration_epidemic"
const INCIDENT_SOCIAL_UNREST: String = "incident_social_unrest"
const INCIDENT_PRODUCTION_STALLED: String = "incident_production_stalled"
const INCIDENT_INFRASTRUCTURE_FAULT: String = "incident_infrastructure_fault"

var id: int = 0
var incident_type: String = ""
var severity: int = SEVERITY_WARNING
var onset_tick: int = 0
var resolved_tick: int = -1
var is_active: bool = true
var root_cause_entity_id: int = 0
var title: String = ""
var description: String = ""
var telemetry_data: Dictionary = {}

func _init(
	p_id: int = 0,
	p_type: String = "",
	p_severity: int = SEVERITY_WARNING,
	p_onset_tick: int = 0,
	p_root_cause_id: int = 0,
	p_title: String = "",
	p_description: String = "",
	p_telemetry: Dictionary = {}
) -> void:
	id = p_id
	incident_type = p_type
	severity = p_severity
	onset_tick = p_onset_tick
	resolved_tick = -1
	is_active = true
	root_cause_entity_id = p_root_cause_id
	title = p_title if p_title != "" else _default_title_for_type(p_type)
	description = p_description if p_description != "" else _default_desc_for_type(p_type)
	telemetry_data = p_telemetry.duplicate(true)

func resolve(tick: int) -> void:
	is_active = false
	resolved_tick = tick

func update_telemetry(p_severity: int, p_telemetry: Dictionary) -> void:
	severity = p_severity
	for k in p_telemetry:
		telemetry_data[k] = p_telemetry[k]

func get_duration_ticks(current_tick: int) -> int:
	if is_active:
		return maxi(0, current_tick - onset_tick)
	else:
		return maxi(0, resolved_tick - onset_tick)

func get_severity_name() -> String:
	match severity:
		SEVERITY_ADVISORY:
			return "ADVISORY"
		SEVERITY_WARNING:
			return "WARNING"
		SEVERITY_CRITICAL:
			return "CRITICAL"
		SEVERITY_EMERGENCY:
			return "EMERGENCY"
		_:
			return "UNKNOWN"

func get_signature() -> String:
	return "%s:%d" % [incident_type, root_cause_entity_id]

func serialize() -> Dictionary:
	return {
		"id": id,
		"incident_type": incident_type,
		"severity": severity,
		"onset_tick": onset_tick,
		"resolved_tick": resolved_tick,
		"is_active": is_active,
		"root_cause_entity_id": root_cause_entity_id,
		"title": title,
		"description": description,
		"telemetry_data": telemetry_data.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	incident_type = str(data.get("incident_type", ""))
	severity = int(data.get("severity", SEVERITY_WARNING))
	onset_tick = int(data.get("onset_tick", 0))
	resolved_tick = int(data.get("resolved_tick", -1))
	is_active = bool(data.get("is_active", true))
	root_cause_entity_id = int(data.get("root_cause_entity_id", 0))
	title = str(data.get("title", ""))
	description = str(data.get("description", ""))
	telemetry_data = (data.get("telemetry_data", {}) as Dictionary).duplicate(true)

static func _default_title_for_type(type: String) -> String:
	match type:
		INCIDENT_WATER_RESERVOIR_DEPLETING:
			return "Potable Water Reservoir Depleting"
		INCIDENT_CRITICAL_PUMP_WEAR:
			return "Critical Water Pump Degradation"
		INCIDENT_SPARE_PARTS_STOCKOUT:
			return "Machinery Spare Parts Stockout"
		INCIDENT_FOUNDRY_LABOR_STARVATION:
			return "Smelting Foundry Labor Starvation"
		INCIDENT_DEHYDRATION_EPIDEMIC:
			return "Severe Population Dehydration Epidemic"
		INCIDENT_SOCIAL_UNREST:
			return "Escalating Habitat Social Unrest"
		INCIDENT_PRODUCTION_STALLED:
			return "Industrial Manufacturing Stalled"
		INCIDENT_INFRASTRUCTURE_FAULT:
			return "Critical Infrastructure Breakdown"
		_:
			return "Systemic Telemetry Alert"

static func _default_desc_for_type(type: String) -> String:
	match type:
		INCIDENT_WATER_RESERVOIR_DEPLETING:
			return "Potable water reservoir levels have fallen below safety threshold."
		INCIDENT_CRITICAL_PUMP_WEAR:
			return "Centrifugal pump component wear exceeds critical operating bounds."
		INCIDENT_SPARE_PARTS_STOCKOUT:
			return "Stock of replacement components exhausted while equipment requires maintenance."
		INCIDENT_FOUNDRY_LABOR_STARVATION:
			return "Smelting foundry unstaffed, cutting off downstream metal stock supply."
		INCIDENT_DEHYDRATION_EPIDEMIC:
			return "Significant proportion of resident population suffering acute water deprivation."
		INCIDENT_SOCIAL_UNREST:
			return "Social tension across the habitat exceeds institutional equilibrium."
		INCIDENT_PRODUCTION_STALLED:
			return "Critical manufacturing pipeline halted due to material or labor starvation."
		INCIDENT_INFRASTRUCTURE_FAULT:
			return "Vital habitat machinery has entered fault or broken state."
		_:
			return "Emergent operational anomaly detected across habitat telemetry."
