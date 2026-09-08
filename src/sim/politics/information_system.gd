# src/sim/politics/information_system.gd
class_name InformationSystem
extends BaseSystem

## Domain system managing simulated information objects, official announcements,
## notice boards, workplace communications, faction channels, word-of-mouth propagation,
## censorship, redaction, delay, and citizen belief updating.

const InformationObject = preload("res://src/sim/politics/information_object.gd")
const CitizenBelief = preload("res://src/sim/politics/citizen_belief.gd")
const InformationChannel = preload("res://src/sim/politics/information_channel.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")
const SocialGraph = preload("res://src/sim/politics/social_graph.gd")

const SYSTEM_ID: String = "information_system"
const EXECUTION_ORDER: int = 38 # Runs after CorruptionSystem (37) and before Demographics/DailyLife (40/50)

var last_social_spread_tick: int = -1

func _init() -> void:
	super._init(SYSTEM_ID, EXECUTION_ORDER)

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws:
		return
		
	ws.custom_data["information_system"] = self
	if not ws.custom_data.has("information_objects"):
		ws.custom_data["information_objects"] = []
	if not ws.custom_data.has("pending_delayed_information"):
		ws.custom_data["pending_delayed_information"] = []
	if not ws.custom_data.has("next_info_id"):
		ws.custom_data["next_info_id"] = 1
	if not ws.custom_data.has("censorship_audit_log"):
		ws.custom_data["censorship_audit_log"] = []

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws or not ws.sim_clock:
		return
		
	var cur_tick: int = ws.sim_clock.get_tick()
	
	# 1. Process delayed announcements whose timer expired
	_process_pending_delays(ws, cur_tick)
	
	# 2. Bounded word-of-mouth social dissemination during shift changes/canteen meals (every 36 ticks = 6 hours)
	if cur_tick % 36 == 0 and cur_tick != last_social_spread_tick:
		last_social_spread_tick = cur_tick
		_evaluate_periodic_social_spread(ws, cur_tick)

## Creates and registers an authoritative information object
func create_information(
	ws: WorldState,
	originating_event_id: String,
	source_type: String,
	source_id: int,
	topic: String,
	truth_basis: Dictionary,
	claim_data: Dictionary,
	channel_type: String = InformationObject.CHANNEL_OFFICIAL,
	target_audience: Dictionary = {"type": "all"},
	classification: String = InformationObject.CLASS_PUBLIC,
	credibility: float = 0.8,
	emotional_salience: float = 0.5,
	certainty: float = 1.0
) -> InformationObject:
	if not ws:
		return null
		
	var next_id: int = int(ws.custom_data.get("next_info_id", 1))
	ws.custom_data["next_info_id"] = next_id + 1
	
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	
	var info: InformationObject = InformationObject.new(
		next_id,
		originating_event_id,
		source_type,
		source_id,
		topic,
		truth_basis,
		claim_data,
		channel_type,
		cur_tick
	)
	info.target_audience = target_audience.duplicate(true)
	info.classification = classification
	info.credibility = clampf(credibility, 0.0, 1.0)
	info.emotional_salience = clampf(emotional_salience, 0.0, 1.0)
	info.certainty = clampf(certainty, 0.0, 1.0)
	
	var obj_list: Array = ws.custom_data.get("information_objects", [])
	obj_list.append(info)
	ws.custom_data["information_objects"] = obj_list
	
	return info

## Disseminates an information object to its target audience across its channel
func disseminate(ws: WorldState, info: InformationObject) -> int:
	if not ws or not info:
		return 0
		
	# If suppressed: message is blocked from transmission. Truth remains intact!
	if info.is_suppressed():
		return 0
		
	# If delayed: queue for later transmission
	if info.is_delayed():
		var pending: Array = ws.custom_data.get("pending_delayed_information", [])
		if not pending.has(info):
			pending.append(info)
			ws.custom_data["pending_delayed_information"] = pending
		return 0
		
	var recipient_ids: Array[int] = InformationChannel.resolve_target_recipients(ws, info)
	var registry: EntityRegistry = ws.entity_registry
	var delivered_count: int = 0
	
	for pid in recipient_ids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive:
			evaluate_citizen_exposure(ws, p, info)
			delivered_count += 1
			
	info.disseminated_count += 1
	info.reach_count += delivered_count
	return delivered_count

## Evaluates how an individual citizen processes an information message
func evaluate_citizen_exposure(ws: WorldState, person: Person, info: InformationObject) -> void:
	if not ws or not person or not info:
		return
		
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	var ev_id: String = info.originating_event_id
	
	# Case A: Citizen has direct experience/witness of the event
	if person.has_belief(ev_id) and person.get_belief(ev_id).has_direct_experience:
		var belief: CitizenBelief = person.get_belief(ev_id)
		# Record the claim in heard claims
		belief.add_heard_claim(
			info.id,
			info.get_visible_claim(),
			info.source_entity_type,
			info.source_entity_id,
			info.credibility,
			cur_tick
		)
		
		# Check if the claim contradicts known truth
		var visible_claim: Dictionary = info.get_visible_claim()
		var is_contradictory: bool = false
		
		if visible_claim.get("framing", "") == "denial":
			is_contradictory = true
		elif visible_claim.has("reported_diverted_kg") and belief.known_truth.has("actual_diverted_kg"):
			if absf(float(visible_claim["reported_diverted_kg"]) - float(belief.known_truth["actual_diverted_kg"])) > 0.01:
				is_contradictory = true
		elif visible_claim.has("framed_cause") and belief.known_truth.has("true_cause"):
			if str(visible_claim["framed_cause"]) != str(belief.known_truth["true_cause"]):
				is_contradictory = true
				
		if is_contradictory:
			# Eyewitness detects government/sender propaganda!
			# Confidence in own truth remains 1.0; skepticism towards institution increases
			belief.doubt = clampf(belief.doubt + 0.3, 0.0, 1.0)
			if info.source_entity_type == "institution":
				person.institutional_trust = clampf(person.institutional_trust - 0.08, 0.0, 1.0)
				person.perceived_fairness = clampf(person.perceived_fairness - 0.06, 0.0, 1.0)
				person.record_opinion_memory(
					PoliticalEvent.EVENT_COERCIVE_ORDER,
					cur_tick,
					PoliticalEvent.DEPT_ADMINISTRATION,
					-0.3,
					"Observed official denial of a known reality.",
					0
				)
		return
		
	# Case B: Citizen does not have direct experience. Calculates perceived credibility.
	var perceived_cred: float = _calculate_perceived_credibility(ws, person, info)
	
	var b: CitizenBelief = person.get_belief(ev_id)
	if not b:
		b = CitizenBelief.new(ev_id, info.topic, false, {})
		b.believed_claim = info.get_visible_claim()
		b.believed_info_id = info.id
		b.confidence = perceived_cred
		b.doubt = clampf(1.0 - perceived_cred, 0.0, 1.0)
		b.add_heard_claim(
			info.id,
			info.get_visible_claim(),
			info.source_entity_type,
			info.source_entity_id,
			perceived_cred,
			cur_tick
		)
		person.record_belief(ev_id, b)
	else:
		b.add_heard_claim(
			info.id,
			info.get_visible_claim(),
			info.source_entity_type,
			info.source_entity_id,
			perceived_cred,
			cur_tick
		)
		
		# If this new claim has higher perceived credibility than current belief, adopt it
		if perceived_cred > b.confidence:
			b.believed_claim = info.get_visible_claim()
			b.believed_info_id = info.id
			b.confidence = perceived_cred
			b.doubt = clampf(1.0 - perceived_cred, 0.0, 1.0)
		elif absf(perceived_cred - b.confidence) < 0.15 and b.believed_info_id != info.id:
			# Competing plausible claims create cognitive dissonance and doubt!
			b.doubt = clampf(b.doubt + 0.25, 0.0, 1.0)

## Propagates information along social graph edges (Word-of-Mouth)
func propagate_word_of_mouth(
	ws: WorldState,
	originating_event_id: String,
	max_spreaders: int = 15
) -> int:
	if not ws or not ws.entity_registry:
		return 0
		
	var registry: EntityRegistry = ws.entity_registry
	var all_pids: Array[int] = registry.get_entities_by_type("person")
	var spreaders: Array[Person] = []
	
	# Find citizens who are convinced or direct witnesses of this event
	for pid in all_pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and p.has_belief(originating_event_id):
			var b: CitizenBelief = p.get_belief(originating_event_id)
			if b.is_convinced() or b.has_direct_experience:
				spreaders.append(p)
				if spreaders.size() >= max_spreaders:
					break
					
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	var new_recipients_count: int = 0
	
	for spreader in spreaders:
		var b: CitizenBelief = spreader.get_belief(originating_event_id)
		var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, spreader.id)
		
		# Spread to close social ties
		for conn in connections:
			var weight: float = float(conn.get("weight", 0.0))
			if weight < 0.5:
				continue
			var target_id: int = int(conn.get("target_id", 0))
			var target_p: Person = registry.get_entity(target_id) as Person
			if not target_p or not target_p.is_alive:
				continue
				
			# Check if target already holds this belief
			if target_p.has_belief(originating_event_id):
				var tb: CitizenBelief = target_p.get_belief(originating_event_id)
				if tb.is_convinced():
					continue # Already convinced
					
			# Create or update rumour belief
			var edge_trust: float = float(conn.get("trust", 0.6))
			var perceived_cred: float = clampf(b.confidence * edge_trust, 0.1, 0.95)
			
			var tb: CitizenBelief = target_p.get_belief(originating_event_id)
			if not tb:
				tb = CitizenBelief.new(originating_event_id, b.topic, false, {})
				tb.believed_claim = b.believed_claim.duplicate(true)
				tb.believed_info_id = b.believed_info_id
				tb.confidence = perceived_cred
				tb.doubt = clampf(1.0 - perceived_cred, 0.0, 1.0)
				tb.add_heard_claim(
					b.believed_info_id,
					b.believed_claim,
					"citizen",
					spreader.id,
					perceived_cred,
					cur_tick
				)
				target_p.record_belief(originating_event_id, tb)
				new_recipients_count += 1
			else:
				tb.add_heard_claim(
					b.believed_info_id,
					b.believed_claim,
					"citizen",
					spreader.id,
					perceived_cred,
					cur_tick
				)
				# Social reinforcement: hearing from multiple trusted peers increases confidence
				if tb.believed_info_id == b.believed_info_id:
					tb.confidence = clampf(tb.confidence + 0.1, 0.0, 1.0)
					tb.doubt = clampf(tb.doubt - 0.1, 0.0, 1.0)
					
	return new_recipients_count

# --- Institutional Actions ---

## Release an existing report, removing its pending timer to prevent double delivery.
## This is a domain API; gameplay classification/role checks live in OperationsCommands.
func release_information(ws: WorldState, info_id: int) -> bool:
	var info := _find_information(ws, info_id)
	if not info or info.reach_count > 0:
		return false
	var pending: Array = ws.custom_data.get("pending_delayed_information", [])
	pending.erase(info)
	ws.custom_data["pending_delayed_information"] = pending
	info.censorship_state = InformationObject.STATE_ACTIVE
	info.delay_ticks_remaining = 0
	var audit: Array = ws.custom_data.get("censorship_audit_log", [])
	audit.append({"action": "release", "info_id": info_id, "tick": ws.sim_clock.get_tick()})
	ws.custom_data["censorship_audit_log"] = audit
	disseminate(ws, info)
	return true

## Suppresses an information object. Halts official dissemination without deleting underlying truth.
func suppress_information(ws: WorldState, info_id: int, reason: String = "") -> bool:
	var info: InformationObject = _find_information(ws, info_id)
	if not info:
		return false
		
	info.censorship_state = InformationObject.STATE_SUPPRESSED
	
	var cur_tick: int = ws.sim_clock.get_tick() if (ws and ws.sim_clock) else 0
	var audit_log: Array = ws.custom_data.get("censorship_audit_log", [])
	audit_log.append({
		"action": "suppress",
		"info_id": info_id,
		"originating_event_id": info.originating_event_id,
		"topic": info.topic,
		"reason": reason,
		"tick": cur_tick
	})
	ws.custom_data["censorship_audit_log"] = audit_log
	return true

## Delays an official information object for a designated number of ticks
func delay_information(ws: WorldState, info_id: int, delay_ticks: int) -> bool:
	var info: InformationObject = _find_information(ws, info_id)
	if not info:
		return false
		
	info.censorship_state = InformationObject.STATE_DELAYED
	info.delay_ticks_remaining = maxi(1, delay_ticks)
	
	var pending: Array = ws.custom_data.get("pending_delayed_information", [])
	if not pending.has(info):
		pending.append(info)
		ws.custom_data["pending_delayed_information"] = pending
	return true

## Redacts specific fields from an information object
func redact_information(ws: WorldState, info_id: int, fields: Array[String]) -> bool:
	var info: InformationObject = _find_information(ws, info_id)
	if not info:
		return false
		
	info.censorship_state = InformationObject.STATE_REDACTED
	for f in fields:
		if not info.redacted_fields.has(f):
			info.redacted_fields.append(f)
	return true

## Issues an authoritative official denial broadcast
func issue_official_denial(
	ws: WorldState,
	originating_event_id: String,
	topic: String,
	counter_claim: Dictionary
) -> InformationObject:
	counter_claim["framing"] = "denial"
	var info: InformationObject = create_information(
		ws,
		originating_event_id,
		"institution",
		0,
		topic,
		{}, # Truth basis not exposed in denial
		counter_claim,
		InformationObject.CHANNEL_OFFICIAL,
		{"type": "all"},
		InformationObject.CLASS_PUBLIC,
		0.85, # Official seal credibility
		0.6
	)
	disseminate(ws, info)
	return info

## Leaks truth basis or dissenting claim to a specific faction channel
func leak_to_faction(
	ws: WorldState,
	originating_event_id: String,
	topic: String,
	truth_basis: Dictionary,
	whistleblower_id: int,
	faction_id: int,
	evidence_strength: float = 0.9
) -> InformationObject:
	var claim_data: Dictionary = truth_basis.duplicate(true)
	claim_data["framing"] = "whistleblower_leak"
	claim_data["leaker_id"] = whistleblower_id
	
	var info: InformationObject = create_information(
		ws,
		originating_event_id,
		"citizen",
		whistleblower_id,
		topic,
		truth_basis,
		claim_data,
		InformationObject.CHANNEL_FACTION,
		{"type": "faction", "faction_id": faction_id},
		InformationObject.CLASS_CLANDESTINE,
		evidence_strength,
		0.85 # High emotional salience
	)
	disseminate(ws, info)
	return info

# --- Internal Helper Methods ---

func _calculate_perceived_credibility(ws: WorldState, person: Person, info: InformationObject) -> float:
	var base: float = info.credibility
	
	match info.source_entity_type:
		"institution":
			# High institutional trust makes official announcements credible
			# Low institutional trust makes citizens skeptical
			var trust_mod: float = (person.institutional_trust - 0.5) * 0.4
			base += trust_mod
			
		"faction":
			var fid: int = int(info.target_audience.get("faction_id", info.source_entity_id))
			if person.faction_id == fid or person.sympathiser_faction_id == fid:
				base += 0.25 # Faction in-group trust bonus
			elif person.faction_id > 0 and person.faction_id != fid:
				base -= 0.25 # Faction rival skepticism penalty
				
		"citizen":
			if info.source_entity_id == person.id:
				return 1.0 # Source citizen fully believes own claim
			if info.source_entity_id > 0:
				var ties: Array[Dictionary] = SocialGraph.get_social_connections(ws, info.source_entity_id)
				var tie_trust: float = 0.5
				for t in ties:
					if int(t.get("target_id", 0)) == person.id:
						tie_trust = float(t.get("trust", 0.6))
						break
				base = (base * 0.5) + (tie_trust * 0.5)
				
	# If claim contains explicit evidence, boost credibility
	if info.claim.has("evidence") or info.claim.has("framing") and info.claim["framing"] == "whistleblower_leak":
		base += 0.15
		
	return clampf(base, 0.05, 0.98)

func _find_information(ws: WorldState, info_id: int) -> InformationObject:
	if not ws:
		return null
	var list: Array = ws.custom_data.get("information_objects", [])
	for item in list:
		var info: InformationObject = item as InformationObject
		if info and info.id == info_id:
			return info
	return null

func _process_pending_delays(ws: WorldState, cur_tick: int) -> void:
	var pending: Array = ws.custom_data.get("pending_delayed_information", [])
	if pending.is_empty():
		return
		
	var to_disseminate: Array[InformationObject] = []
	var remaining: Array = []
	
	for item in pending:
		var info: InformationObject = item as InformationObject
		if not info:
			continue
		info.delay_ticks_remaining -= 1
		if info.delay_ticks_remaining <= 0 and not info.is_suppressed():
			info.censorship_state = InformationObject.STATE_ACTIVE
			to_disseminate.append(info)
		elif not info.is_suppressed():
			remaining.append(info)
			
	ws.custom_data["pending_delayed_information"] = remaining
	
	for info in to_disseminate:
		disseminate(ws, info)

func _evaluate_periodic_social_spread(ws: WorldState, cur_tick: int) -> void:
	var obj_list: Array = ws.custom_data.get("information_objects", [])
	for item in obj_list:
		var info: InformationObject = item as InformationObject
		if not info or info.is_suppressed():
			continue
		# Only active, high-salience events spread organically via word-of-mouth
		if info.emotional_salience >= 0.5:
			propagate_word_of_mouth(ws, info.originating_event_id, 10)

func serialize() -> Dictionary:
	return {
		"last_social_spread_tick": last_social_spread_tick
	}

func deserialize(data: Dictionary) -> void:
	last_social_spread_tick = int(data.get("last_social_spread_tick", -1))
