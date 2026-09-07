# src/sim/incidents/incident_invariants.gd
class_name IncidentInvariants
extends RefCounted

## Invariant validator for the Incident Subsystem.
## Enforces physical correlation: incidents must strictly reflect underlying
## simulation state with zero false positives or artificial game-master injections.

static func validate(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var stats: Dictionary = {
		"active_incidents": 0,
		"resolved_incidents": 0,
		"critical_incidents": 0,
		"detected_conditions": 0
	}

	if not ws:
		errors.append("WorldState is null")
		return {"is_valid": false, "errors": errors, "stats": stats}

	var inc_sys: IncidentSystem = null
	if ws.custom_data.has("incident_system"):
		inc_sys = ws.custom_data["incident_system"] as IncidentSystem

	if not inc_sys:
		errors.append("IncidentSystem is not registered or present in WorldState.custom_data")
		return {"is_valid": false, "errors": errors, "stats": stats}

	var current_tick: int = ws.sim_clock.get_tick()
	var seen_ids: Dictionary = {}

	# 1. Validate Active Incidents Lifecycle & State
	for sig in inc_sys.active_incidents:
		var inc: Incident = inc_sys.active_incidents[sig] as Incident
		if not inc:
			errors.append("Null incident found for signature '%s'" % sig)
			continue

		stats["active_incidents"] += 1
		if inc.severity >= Incident.SEVERITY_CRITICAL:
			stats["critical_incidents"] += 1

		# ID uniqueness
		if seen_ids.has(inc.id):
			errors.append("Duplicate incident ID %d in active incidents" % inc.id)
		seen_ids[inc.id] = true

		# Active state assertions
		if not inc.is_active:
			errors.append("Active incident %d has is_active == false" % inc.id)
		if inc.resolved_tick != -1:
			errors.append("Active incident %d has resolved_tick != -1 (is %d)" % [inc.id, inc.resolved_tick])
		if inc.onset_tick > current_tick:
			errors.append("Active incident %d has onset_tick %d in the future (current: %d)" % [inc.id, inc.onset_tick, current_tick])
		if inc.severity < Incident.SEVERITY_ADVISORY or inc.severity > Incident.SEVERITY_EMERGENCY:
			errors.append("Incident %d has invalid severity level: %d" % [inc.id, inc.severity])

		# Signature consistency
		var expected_sig: String = "%s:%d" % [inc.incident_type, inc.root_cause_entity_id]
		if sig != expected_sig:
			errors.append("Incident signature mismatch: key='%s' vs expected='%s'" % [sig, expected_sig])

	# 2. Validate Resolved Incidents
	for inc in inc_sys.resolved_incidents:
		if not inc:
			errors.append("Null incident found in resolved incidents")
			continue

		stats["resolved_incidents"] += 1

		if seen_ids.has(inc.id):
			errors.append("Duplicate incident ID %d between active and resolved incidents" % inc.id)
		seen_ids[inc.id] = true

		if inc.is_active:
			errors.append("Resolved incident %d has is_active == true" % inc.id)
		if inc.resolved_tick < inc.onset_tick:
			errors.append("Resolved incident %d has resolved_tick %d < onset_tick %d" % [inc.id, inc.resolved_tick, inc.onset_tick])
		if inc.resolved_tick > current_tick:
			errors.append("Resolved incident %d has resolved_tick %d in future (current: %d)" % [inc.id, inc.resolved_tick, current_tick])

	# 3. Validate Physical Ground Truth Correlation
	var detected_conditions: Array[Dictionary] = IncidentDetector.detect_incidents(ws)
	stats["detected_conditions"] = detected_conditions.size()

	var detected_sigs: Dictionary = {}
	for cond in detected_conditions:
		var sig: String = "%s:%d" % [cond["type"], int(cond.get("root_cause_id", 0))]
		detected_sigs[sig] = cond

		# Assert no missed active incident
		if not inc_sys.active_incidents.has(sig):
			errors.append("Uncaptured physical condition: '%s' detected by telemetry but not tracked in active incidents" % sig)

	# Assert no phantom active incidents
	for sig in inc_sys.active_incidents:
		if not detected_sigs.has(sig):
			errors.append("Phantom incident: active incident '%s' has no corresponding physical condition in WorldState" % sig)

	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"stats": stats
	}
