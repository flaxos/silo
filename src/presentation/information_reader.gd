# src/presentation/information_reader.gd
class_name InformationReader
extends RefCounted

## Read-only queries and projections for information objects, citizen beliefs,
## competing narratives, and censorship audits without mutating simulation state.

const InformationObject = preload("res://src/sim/politics/information_object.gd")
const CitizenBelief = preload("res://src/sim/politics/citizen_belief.gd")

static func get_information_summary(ws: WorldState) -> Dictionary:
	var result: Dictionary = {
		"total_count": 0,
		"active_count": 0,
		"delayed_count": 0,
		"suppressed_count": 0,
		"redacted_count": 0,
		"channel_breakdown": {
			InformationObject.CHANNEL_OFFICIAL: 0,
			InformationObject.CHANNEL_NOTICE_BOARD: 0,
			InformationObject.CHANNEL_WORKPLACE: 0,
			InformationObject.CHANNEL_FACTION: 0,
			InformationObject.CHANNEL_WORD_OF_MOUTH: 0
		},
		"recent_information": []
	}

	if not ws:
		return result

	var obj_list: Array = ws.custom_data.get("information_objects", [])
	result["total_count"] = obj_list.size()

	for item in obj_list:
		var info: InformationObject = item as InformationObject
		if not info:
			continue

		match info.censorship_state:
			InformationObject.STATE_ACTIVE:
				result["active_count"] += 1
			InformationObject.STATE_DELAYED:
				result["delayed_count"] += 1
			InformationObject.STATE_SUPPRESSED:
				result["suppressed_count"] += 1
			InformationObject.STATE_REDACTED:
				result["redacted_count"] += 1

		if result["channel_breakdown"].has(info.channel_type):
			result["channel_breakdown"][info.channel_type] += 1

	var start_idx: int = maxi(0, obj_list.size() - 20)
	for i in range(start_idx, obj_list.size()):
		var info: InformationObject = obj_list[i] as InformationObject
		if info:
			result["recent_information"].append(info.serialize())

	return result

static func get_citizen_beliefs(ws: WorldState, person_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ws or not ws.entity_registry:
		return result

	var p: Person = ws.entity_registry.get_entity(person_id) as Person
	if not p:
		return result

	for ev_id in p.beliefs.keys():
		var b: CitizenBelief = p.beliefs[ev_id] as CitizenBelief
		if b:
			result.append({
				"event_id": b.originating_event_id,
				"topic": b.topic,
				"has_direct_experience": b.has_direct_experience,
				"confidence": b.confidence,
				"doubt": b.doubt,
				"is_convinced": b.is_convinced(),
				"is_skeptical": b.is_skeptical(),
				"believed_info_id": b.believed_info_id,
				"believed_claim": b.believed_claim.duplicate(true),
				"heard_claims_count": b.heard_claims.size(),
				"last_updated_tick": b.last_updated_tick
			})

	return result

static func get_competing_narratives(ws: WorldState, event_id: String) -> Dictionary:
	var result: Dictionary = {
		"event_id": event_id,
		"ground_truth": {},
		"claims": [],
		"citizen_breakdown": {
			"total_aware": 0,
			"direct_witnesses": 0,
			"convinced_count": 0,
			"skeptical_count": 0,
			"claim_distribution": {}
		}
	}

	if not ws:
		return result

	# Find ground truth and registered claims
	var obj_list: Array = ws.custom_data.get("information_objects", [])
	for item in obj_list:
		var info: InformationObject = item as InformationObject
		if not info or info.originating_event_id != event_id:
			continue

		if result["ground_truth"].is_empty() and not info.truth_basis.is_empty():
			result["ground_truth"] = info.truth_basis.duplicate(true)

		result["claims"].append({
			"info_id": info.id,
			"source_type": info.source_entity_type,
			"source_id": info.source_entity_id,
			"channel": info.channel_type,
			"censorship_state": info.censorship_state,
			"claim": info.get_visible_claim(),
			"reach": info.reach_count
		})

	# Survey population awareness and belief distribution
	if ws.entity_registry:
		var registry: EntityRegistry = ws.entity_registry
		var pids: Array[int] = registry.get_entities_by_type("person")
		for pid in pids:
			var p: Person = registry.get_entity(pid) as Person
			if not p or not p.is_alive or not p.has_belief(event_id):
				continue

			var b: CitizenBelief = p.get_belief(event_id)
			if not b:
				continue

			result["citizen_breakdown"]["total_aware"] += 1
			if b.has_direct_experience:
				result["citizen_breakdown"]["direct_witnesses"] += 1
				if result["ground_truth"].is_empty() and not b.known_truth.is_empty():
					result["ground_truth"] = b.known_truth.duplicate(true)

			if b.is_convinced():
				result["citizen_breakdown"]["convinced_count"] += 1
			if b.is_skeptical():
				result["citizen_breakdown"]["skeptical_count"] += 1

			var claim_key: String = str(b.believed_info_id)
			var cur_c: int = int(result["citizen_breakdown"]["claim_distribution"].get(claim_key, 0))
			result["citizen_breakdown"]["claim_distribution"][claim_key] = cur_c + 1

	return result

static func get_censorship_log(ws: WorldState) -> Array[Dictionary]:
	if not ws:
		return []
	var list: Array = ws.custom_data.get("censorship_audit_log", [])
	var copy: Array[Dictionary] = []
	for item in list:
		if item is Dictionary:
			copy.append((item as Dictionary).duplicate(true))
	return copy
