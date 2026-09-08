# src/sim/politics/information_invariants.gd
class_name InformationInvariants
extends RefCounted

## Validates integrity, ID monotonicity, truth-basis preservation under censorship,
## direct experience immutability, and bounded memory for the Information & Belief system.

const InformationObject = preload("res://src/sim/politics/information_object.gd")
const CitizenBelief = preload("res://src/sim/politics/citizen_belief.gd")

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	if not ws:
		return {"is_valid": false, "errors": ["WorldState is null"]}

	var info_objects: Array = ws.custom_data.get("information_objects", [])
	var seen_ids: Dictionary = {}
	var last_id: int = 0

	# 1. Validate Information Object Invariants
	for obj in info_objects:
		var info: InformationObject = obj as InformationObject
		if not info:
			errors.append("Null or invalid InformationObject in custom_data['information_objects']")
			continue

		if info.id <= 0:
			errors.append("InformationObject has non-positive id: %d" % info.id)
		if seen_ids.has(info.id):
			errors.append("Duplicate InformationObject id detected: %d" % info.id)
		seen_ids[info.id] = true

		if info.id < last_id:
			errors.append("InformationObject id non-monotonic: %d after %d" % [info.id, last_id])
		last_id = info.id

		if is_nan(info.credibility) or is_inf(info.credibility) or info.credibility < 0.0 or info.credibility > 1.0:
			errors.append("InformationObject %d credibility out of bounds: %f" % [info.id, info.credibility])

		if is_nan(info.certainty) or is_inf(info.certainty) or info.certainty < 0.0 or info.certainty > 1.0:
			errors.append("InformationObject %d certainty out of bounds: %f" % [info.id, info.certainty])

		if is_nan(info.emotional_salience) or is_inf(info.emotional_salience) or info.emotional_salience < 0.0 or info.emotional_salience > 1.0:
			errors.append("InformationObject %d emotional_salience out of bounds: %f" % [info.id, info.emotional_salience])

		# Invariant: Censorship != Deletion
		# If suppressed, truth_basis must remain intact if provided
		if info.is_suppressed() and info.truth_basis == null:
			errors.append("InformationObject %d suppressed but truth_basis is null" % info.id)

		if info.is_delayed() and info.delay_ticks_remaining < 0:
			errors.append("InformationObject %d delayed with negative delay_ticks_remaining: %d" % [info.id, info.delay_ticks_remaining])

	# 2. Validate Citizen Belief Invariants
	var citizens_with_beliefs: int = 0
	if ws.entity_registry:
		var registry: EntityRegistry = ws.entity_registry
		var pids: Array[int] = registry.get_entities_by_type("person")
		for pid in pids:
			var p: Person = registry.get_entity(pid) as Person
			if not p:
				continue

			if not p.beliefs.is_empty():
				citizens_with_beliefs += 1

			for ev_id in p.beliefs.keys():
				var belief: CitizenBelief = p.beliefs[ev_id] as CitizenBelief
				if not belief:
					errors.append("Person %d has invalid belief object for event '%s'" % [pid, str(ev_id)])
					continue

				# Key match
				if belief.originating_event_id != str(ev_id):
					errors.append("Person %d belief key '%s' does not match belief.originating_event_id '%s'" % [pid, str(ev_id), belief.originating_event_id])

				# Bounded memory invariant
				if belief.heard_claims.size() > CitizenBelief.MAX_HEARD_CLAIMS:
					errors.append("Person %d belief '%s' exceeded MAX_HEARD_CLAIMS (%d > %d)" % [pid, str(ev_id), belief.heard_claims.size(), CitizenBelief.MAX_HEARD_CLAIMS])

				# Probability/confidence bounds
				if is_nan(belief.confidence) or is_inf(belief.confidence) or belief.confidence < 0.0 or belief.confidence > 1.0:
					errors.append("Person %d belief '%s' confidence out of bounds: %f" % [pid, str(ev_id), belief.confidence])

				if is_nan(belief.doubt) or is_inf(belief.doubt) or belief.doubt < 0.0 or belief.doubt > 1.0:
					errors.append("Person %d belief '%s' doubt out of bounds: %f" % [pid, str(ev_id), belief.doubt])

				# Direct experience immutability invariant
				if belief.has_direct_experience:
					if belief.confidence < 0.99:
						errors.append("Person %d direct eyewitness belief '%s' confidence degraded below 1.0: %f" % [pid, str(ev_id), belief.confidence])
					if belief.known_truth.is_empty():
						errors.append("Person %d direct eyewitness belief '%s' has empty known_truth" % [pid, str(ev_id)])

	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"info_count": info_objects.size(),
		"citizens_with_beliefs": citizens_with_beliefs
	}
