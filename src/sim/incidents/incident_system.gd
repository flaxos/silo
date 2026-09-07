# src/sim/incidents/incident_system.gd
class_name IncidentSystem
extends BaseSystem

const SYSTEM_ID: String = "incidents"
const EXECUTION_ORDER: int = 80 # Executes after all domain systems (Water=65, Demographics=40, etc.)

var active_incidents: Dictionary = {} # signature: String -> Incident
var resolved_incidents: Array[Incident] = []
var next_incident_id: int = 1

var total_incidents_raised: int = 0
var total_incidents_resolved: int = 0

func _init() -> void:
	super(SYSTEM_ID, EXECUTION_ORDER)
	_reset_state()

func _reset_state() -> void:
	active_incidents.clear()
	resolved_incidents.clear()
	next_incident_id = 1
	total_incidents_raised = 0
	total_incidents_resolved = 0

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	_sync_to_world_state(ws)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	var current_tick: int = ws.sim_clock.get_tick()

	# 1. Run diagnostic detector on current WorldState
	var detected_conditions: Array[Dictionary] = IncidentDetector.detect_incidents(ws)
	var active_signatures_detected: Dictionary = {}

	# 2. Process detected conditions (raise new or update existing)
	for cond in detected_conditions:
		var inc_type: String = cond["type"]
		var root_id: int = int(cond.get("root_cause_id", 0))
		var sig: String = "%s:%d" % [inc_type, root_id]
		active_signatures_detected[sig] = true

		var sev: int = int(cond.get("severity", Incident.SEVERITY_WARNING))
		var telemetry: Dictionary = cond.get("telemetry", {})

		if active_incidents.has(sig):
			# Update existing active incident
			var existing_inc: Incident = active_incidents[sig]
			existing_inc.update_telemetry(sev, telemetry)
		else:
			# Raise new incident
			var new_inc: Incident = Incident.new(
				next_incident_id,
				inc_type,
				sev,
				current_tick,
				root_id,
				str(cond.get("title", "")),
				str(cond.get("description", "")),
				telemetry
			)
			next_incident_id += 1
			total_incidents_raised += 1
			active_incidents[sig] = new_inc

	# 3. Automatically resolve active incidents whose physical condition normalized
	var resolved_sigs: Array[String] = []
	for sig in active_incidents:
		if not active_signatures_detected.has(sig):
			var inc_to_resolve: Incident = active_incidents[sig]
			inc_to_resolve.resolve(current_tick)
			resolved_incidents.append(inc_to_resolve)
			resolved_sigs.append(sig)
			total_incidents_resolved += 1

	for sig in resolved_sigs:
		active_incidents.erase(sig)

	# 4. Synchronize state with WorldState
	_sync_to_world_state(ws)

func get_active_incidents() -> Array[Incident]:
	var result: Array[Incident] = []
	for sig in active_incidents:
		result.append(active_incidents[sig])
	return result

func get_resolved_incidents() -> Array[Incident]:
	return resolved_incidents.duplicate()

func get_incident_by_id(p_id: int) -> Incident:
	for inc in active_incidents.values():
		var i: Incident = inc as Incident
		if i.id == p_id:
			return i
	for i in resolved_incidents:
		if i.id == p_id:
			return i
	return null

func get_incidents_by_severity(min_severity: int) -> Array[Incident]:
	var result: Array[Incident] = []
	for inc in active_incidents.values():
		var i: Incident = inc as Incident
		if i.severity >= min_severity:
			result.append(i)
	return result

func get_active_incident_count() -> int:
	return active_incidents.size()

func get_critical_incident_count() -> int:
	var count: int = 0
	for inc in active_incidents.values():
		var i: Incident = inc as Incident
		if i.severity >= Incident.SEVERITY_CRITICAL:
			count += 1
	return count

func _sync_to_world_state(ws: WorldState) -> void:
	if not ws:
		return
	ws.custom_data["incident_system"] = self
	ws.custom_data["active_incidents_count"] = get_active_incident_count()
	ws.custom_data["critical_incidents_count"] = get_critical_incident_count()
	ws.custom_data["total_incidents_raised"] = total_incidents_raised
	ws.custom_data["total_incidents_resolved"] = total_incidents_resolved

func serialize() -> Dictionary:
	var active_dict: Dictionary = {}
	for sig in active_incidents:
		var inc: Incident = active_incidents[sig]
		active_dict[sig] = inc.serialize()

	var resolved_arr: Array = []
	for inc in resolved_incidents:
		resolved_arr.append(inc.serialize())

	return {
		"next_incident_id": next_incident_id,
		"total_incidents_raised": total_incidents_raised,
		"total_incidents_resolved": total_incidents_resolved,
		"active_incidents": active_dict,
		"resolved_incidents": resolved_arr
	}

func deserialize(data: Dictionary) -> void:
	next_incident_id = int(data.get("next_incident_id", 1))
	total_incidents_raised = int(data.get("total_incidents_raised", 0))
	total_incidents_resolved = int(data.get("total_incidents_resolved", 0))

	active_incidents.clear()
	var act_dict: Dictionary = data.get("active_incidents", {})
	for sig in act_dict:
		var inc_data: Dictionary = act_dict[sig]
		var inc: Incident = Incident.new()
		inc.deserialize(inc_data)
		active_incidents[sig] = inc

	resolved_incidents.clear()
	var res_arr: Array = data.get("resolved_incidents", [])
	for inc_data in res_arr:
		var inc: Incident = Incident.new()
		inc.deserialize(inc_data)
		resolved_incidents.append(inc)
