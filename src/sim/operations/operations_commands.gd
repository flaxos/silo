class_name OperationsCommands
extends RefCounted

## Gameplay allowlist; legacy observer commands remain developer-only APIs.
static func validate(ws: WorldState, c: Dictionary, action: String) -> String:
	if str(ws.custom_data.get("player_role", "")) != OperationsConfig.ROLE_IT:
		return "Head of IT authority required."
	if c.is_empty() or c.status in OperationsSystem.TERMINAL:
		return "Case is unavailable or closed."
	if not str(c.pending).is_empty():
		return "A decision is already queued for the next tick."
	if action == "monitor":
		return "Already monitoring." if c.monitoring else ""
	if c.kind == "pump":
		var m := ws.entity_registry.get_entity(c.source_id) as WaterPump
		var inst := ws.custom_data.get("institution_system") as InstitutionSystem
		if not m or not inst:
			return "Machine or Engineering delegation unavailable."
		var order := inst.get_active_order(OperationsConfig.ORDER_EARLY_SERVICE)
		if action == "cancel_service":
			return "" if order and order.target_id == str(m.id) else "No service request for this machine."
		if action != "request_service":
			return "IT cannot issue that Engineering action."
		if not bool(ws.custom_data.get("it_service_delegation", false)):
			return "Engineering early-service delegation is not granted."
		if not m.needs_maintenance(OperationsConfig.EARLY_WEAR):
			return "Machine no longer meets the service threshold."
		if order:
			return "The single early-service slot is already occupied."
		return ""
	if c.kind == "information":
		var info := OperationsSystem.find_information(ws, c.source_id)
		if not info or not OperationsSystem._visible_report(info) or not ws.custom_data.get("information_system") is InformationSystem:
			return "Report is outside IT publication authority."
		if info.reach_count > 0:
			return "Report already delivered."
		if action not in ["publish", "delay", "withhold", "request_review"]:
			return "IT cannot issue that information action."
		if action == "request_review":
			var inst := ws.custom_data.get("institution_system") as InstitutionSystem
			if not inst:
				return "Institutional administration unavailable."
			var existing := inst.get_active_order(OperationsConfig.ORDER_CAPACITY_REVIEW)
			if existing and existing.is_active:
				return "An administrative capacity review is already active on the docket."
			return ""
		if action == "withhold" and info.is_suppressed():
			return "Report is already withheld."
		if action == "delay":
			for previous in c.actions:
				if previous.action == "delay": return "One six-hour review extension per report."
		return ""
	return "Unknown case action."

static func queue(ws: WorldState, case_id: String, action: String) -> Dictionary:
	var ops := ws.custom_data.get("operations_system") as OperationsSystem
	if not ops:
		return {"ok": false, "message": "Operations unavailable."}
	var c: Dictionary = ops.cases.get(case_id, {})
	var rejection := validate(ws, c, action)
	if not rejection.is_empty():
		return {"ok": false, "message": rejection}
	var pending_count := 0
	for other in ops.cases.values():
		if other.pending != "": pending_count += 1
	if pending_count >= OperationsConfig.MAX_PENDING_COMMANDS:
		return {"ok": false, "message": "Command queue full."}
	c.pending = action
	ws.event_queue.schedule_delay(ws.sim_clock.get_tick(), 1, OperationsSystem.EVENT_COMMAND, {"case_id": case_id, "action": action})
	ops.append_history(c, ws.sim_clock.get_tick(), "Queued " + action.replace("_", " ") + "; resume time to execute.")
	return {"ok": true, "message": "Decision queued. Resume time; authority and target will be rechecked."}

static func execute(ws: WorldState, c: Dictionary, action: String) -> Dictionary:
	var rejection := validate(ws, c, action)
	if not rejection.is_empty():
		return {"ok": false, "message": rejection}
	var ok := false
	var message := ""
	var inst := ws.custom_data.get("institution_system") as InstitutionSystem
	match action:
		"monitor":
			c.monitoring = true
			ok = true
			message = "Monitor chosen: no service or publication override; normal systems continue."
		"request_service":
			ok = inst.request_it_service(ws, c.source_id)
			message = "Early-service slot reserved for 24h. Target threshold 55%; real local labour and parts still required."
		"cancel_service":
			ok = inst.cancel_order(OperationsConfig.ORDER_EARLY_SERVICE, ws)
			message = "Early-service slot released. Normal Engineering threshold resumes; committed repair labour remains."
		"request_review":
			if inst:
				var order := ExecutiveOrder.new(
					OperationsConfig.ORDER_CAPACITY_REVIEW,
					OperationsConfig.ORDER_CAPACITY_REVIEW,
					"Administrative school capacity review requested by IT",
					Occupation.DEPT_IT,
					str(c.room_id),
					OperationsConfig.SERVICE_TICKS,
					{"room_id": c.room_id, "topic": "school_capacity"}
				)
				ok = inst.issue_order(order, ws)
				message = "Formal capacity review requested from Administration. Recorded on executive docket; does not add classrooms."
		"publish", "delay", "withhold":
			var sys := ws.custom_data.get("information_system") as InformationSystem
			var info := OperationsSystem.find_information(ws, c.source_id)
			if action == "publish":
				ok = sys.release_information(ws, info.id)
				message = "Report released through the official channel; %d real recipient deliveries." % info.reach_count
			elif action == "delay":
				ok = sys.delay_information(ws, info.id, OperationsConfig.REVIEW_DELAY_TICKS)
				message = "Review delay set to six hours. Residents wait for official facts; existing beliefs remain."
			else:
				ok = sys.suppress_information(ws, info.id, "Head of IT withheld pending report")
				message = "Official delivery withheld and logged. Truth remains; undelivered report can escalate."
	if ok and action != "monitor": c.monitoring = false
	return {"ok": ok, "message": message if ok else "Command could not be applied; inspect current authority and target."}
