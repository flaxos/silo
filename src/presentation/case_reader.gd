class_name CaseReader
extends RefCounted

const Formatter = preload("res://src/presentation/case_formatter.gd")

static func brief(ws: WorldState) -> Dictionary:
	var ops := ws.custom_data.get("operations_system") as OperationsSystem
	var result := {"active": [], "archive": [], "active_count": 0, "tick": ws.sim_clock.get_tick()}
	if not ops: return result
	for c in ops.cases.values():
		var row := {
			"id": c.id,
			"title": Formatter.get_human_title(c),
			"severity": c.severity,
			"severity_text": Formatter.get_human_severity(c),
			"status": c.status,
			"status_text": Formatter.get_human_status(str(c.status)),
			"age_ticks": ws.sim_clock.get_tick() - int(c.detected_tick),
			"room_id": c.room_id,
			"location": location(ws, c.room_id),
			"kind": c.kind
		}
		if c.status in OperationsSystem.TERMINAL: result.archive.push_front(row)
		else: result.active.append(row)
	result.active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.severity != b.severity: return a.severity > b.severity
		return a.id < b.id)
	result.active_count = result.active.size()
	return result

static func location(ws: WorldState, room_id: int) -> String:
	var room := ws.entity_registry.get_entity(room_id) as Room
	return "Level %d · Room #%d" % [room.level, room.id] if room else "Location unresolved"

static func detail(ws: WorldState, case_id: String) -> Dictionary:
	var ops := ws.custom_data.get("operations_system") as OperationsSystem
	if not ops or not ops.cases.has(case_id): return {}
	var c: Dictionary = ops.cases[case_id]
	var result := c.duplicate(true)
	result.location = location(ws, c.room_id)
	result.age_ticks = ws.sim_clock.get_tick() - int(c.detected_tick)
	result.focus = OperationsEvidence.link("machine" if c.kind == "pump" else "room", c.source_id if c.kind == "pump" else c.room_id, c.room_id, "Locate affected area")
	
	if c.kind == "pump":
		var evidence := OperationsEvidence.pump(ws, c.source_id)
		result.merge(evidence, true)
		result.why = evidence.get("why", [])
		for iid in c.incident_ids:
			result.why.append(OperationsEvidence.link("incident", iid, c.room_id, "Related incident report #%d" % iid))
	else:
		_information_detail(ws, c, result)
		
	# Build structured human briefing layer
	var briefing := Formatter.build_briefing(ws, c, result)
	result.briefing = briefing
	result.title = Formatter.get_human_title(c, result)
	result.severity_text = Formatter.get_human_severity(c, result)
	result.status_text = Formatter.get_human_status(str(c.status))
	result.summary = briefing.get("whats_happening", str(c.get("title", "")))
	result.available_actions = _actions(ws, c, result)
	
	# Extract technical details cleanly segregated for advanced inspection
	result.technical_details = _extract_technical_details(ws, c, result)
	result.os_telemetry = Formatter.build_os_telemetry(ws, c, result)
	
	return result

static func _information_detail(ws: WorldState, c: Dictionary, result: Dictionary) -> void:
	var info := OperationsSystem.find_information(ws, c.source_id)
	result.why = []
	result.known = []; result.suspected = []; result.unknown = []
	if not info or not OperationsSystem._visible_report(info):
		result.unknown = ["Report unavailable under current classification."]
		return
		
	var claim := info.get_visible_claim().duplicate(true)
	claim["topic"] = info.topic
	result.report = claim
	result.summary = "Official report %s; %d recipient deliveries. Delay remaining: %d ticks." % [info.censorship_state, info.reach_count, info.delay_ticks_remaining]
	result.known = ["Internal report #%d observed at tick %d." % [info.id, int(claim.get("observed_tick", info.created_tick))], result.summary]
	if info.certainty < 1.0:
		result.suspected = ["Report asserts %.0f%% certainty; claim is not independently verified." % (info.certainty * 100.0)]
	result.unknown = ["Individual private beliefs and word-of-mouth rumors cannot be monitored."]
	
	if info.topic == "school_capacity":
		var att := int(claim.get("attending_students", 0))
		var cap := int(claim.get("capacity", 0))
		var enr := int(claim.get("enrolled_students", 0))
		result.why.append(OperationsEvidence.link("room", c.room_id, c.room_id, "Attendance record: %d students attending in a room built for %d (%d enrolled)." % [att, cap, enr]))
		result.why.append(OperationsEvidence.link("room", c.room_id, c.room_id, "Daily schedule caused the recorded attendance. Expanding school capacity requires action by Administration/Education."))
	else:
		for key in claim:
			result.why.append(OperationsEvidence.link("room", c.room_id, c.room_id, "%s: %s" % [str(key).replace("_", " ").capitalize(), str(claim[key])]))
			
	result.delivery = {"recipient_deliveries": info.reach_count, "broadcasts": info.disseminated_count}

static func _actions(ws: WorldState, c: Dictionary, detail: Dictionary) -> Array[Dictionary]:
	var action_ids: Array[String] = []
	if c.kind == "pump":
		action_ids = ["request_service", "cancel_service", "monitor"]
	else:
		action_ids = ["publish", "delay", "withhold"]
		if "school" in str(detail.get("report", {}).get("topic", "")):
			action_ids.append("request_review")
		action_ids.append("monitor")
		
	var result: Array[Dictionary] = []
	for aid in action_ids:
		var formatted := Formatter.format_action(aid, str(c.kind), c)
		var reason := OperationsCommands.validate(ws, c, aid)
		formatted["cost"] = formatted["trade_off"]
		formatted["enabled"] = reason.is_empty()
		formatted["reason"] = reason
		result.append(formatted)
		
	return result

static func _extract_technical_details(_ws: WorldState, c: Dictionary, detail: Dictionary) -> Dictionary:
	var tech := {
		"case_id": c.get("id", ""),
		"source_kind": c.get("kind", ""),
		"source_id": c.get("source_id", 0),
		"room_id": c.get("room_id", 0),
		"detected_tick": c.get("detected_tick", 0),
		"raw_status": c.get("status", ""),
		"raw_severity": c.get("severity", 1),
	}
	if str(c.get("kind", "")) == "pump":
		tech["machine_state"] = detail.get("state", 0)
		tech["component_id"] = detail.get("component_id", "")
		tech["component_wear_pct"] = detail.get("wear", 0.0)
		tech["current_output_lpm"] = detail.get("output", 0.0)
		tech["repair_ticks_accumulated"] = detail.get("repair_ticks", 0)
		tech["repair_ticks_required"] = detail.get("required_ticks", 0)
		tech["local_spare_stock"] = detail.get("stock", 0.0)
		tech["technicians_on_duty"] = detail.get("on_duty", 0)
		tech["service_threshold"] = detail.get("threshold", 60.0)
	elif str(c.get("kind", "")) == "information":
		var report: Dictionary = detail.get("report", {})
		tech["report_topic"] = report.get("topic", "")
		tech["observed_tick"] = report.get("observed_tick", 0)
		tech["reach_count"] = detail.get("delivery", {}).get("recipient_deliveries", 0)
	return tech
