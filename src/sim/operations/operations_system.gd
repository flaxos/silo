class_name OperationsSystem
extends BaseSystem

## Authoritative workflow only. Incidents, machinery and beliefs retain domain ownership.
const EVENT_COMMAND := "operations_command"
const TERMINAL := ["RESOLVED", "FAILED"]
var cases: Dictionary = {}
var open_keys: Dictionary = {}
var reported: Dictionary = {}
var next_id := 1

func _init() -> void:
	super("operations", 85)

func setup(world_state: Variant) -> void:
	world_state.custom_data["operations_system"] = self

func tick(world_state: Variant) -> void:
	var ws := world_state as WorldState
	var now := ws.sim_clock.get_tick()
	if now % OperationsConfig.REPORT_CHECK_TICKS == 0:
		OperationsReports.collect(ws, reported)
	for mid in ws.entity_registry.get_entities_by_type("machine"):
		var m := ws.entity_registry.get_entity(mid) as WaterPump
		if m and m.needs_maintenance(OperationsConfig.EARLY_WEAR):
			_ensure("pump:%d" % mid, "pump", mid, m.room_id, now, "Pump maintenance risk")
	for item in ws.custom_data.get("information_objects", []):
		var info := item as InformationObject
		if info and _visible_report(info) and info.reach_count == 0:
			_ensure("information:%d" % info.id, "information", info.id, int(info.get_visible_claim().get("room_id", 0)), now, "Review: " + info.topic.replace("_", " "))
	for cid in cases.keys():
		var c: Dictionary = cases[cid]
		if c.status in TERMINAL:
			continue
		if c.kind == "pump":
			_update_pump(ws, c, now)
		else:
			_update_information(ws, c, now)
	_prune()

func _ensure(key: String, kind: String, source_id: int, room_id: int, now: int, title: String) -> void:
	if open_keys.has(key):
		return
	var id := "OP-%04d" % next_id
	next_id += 1
	var c := {"id": id, "key": key, "kind": kind, "source_id": source_id, "room_id": room_id,
		"detected_tick": now, "status": "NEW", "severity": 1, "title": title,
		"history": [], "actions": [], "pending": "", "monitoring": false,
		"stable_since": -1, "resolved_tick": -1, "last_fingerprint": "", "last_snapshot": {}, "incident_ids": []}
	cases[id] = c
	open_keys[key] = id
	append_history(c, now, "Detected from authoritative %s state." % kind)

func _update_pump(ws: WorldState, c: Dictionary, now: int) -> void:
	var evidence := OperationsEvidence.pump(ws, c.source_id)
	if evidence.is_empty():
		_transition(c, "FAILED", now, "Source machine no longer exists; location unresolved.")
		return
	c.room_id = evidence.room_id
	c.last_snapshot = evidence
	c.incident_ids = []
	var incidents := ws.custom_data.get("incident_system") as IncidentSystem
	if incidents:
		for inc in incidents.get_active_incidents():
			if inc.root_cause_entity_id == int(c.source_id):
				c.incident_ids.append(inc.id)
	c.severity = 3 if int(evidence.state) == Machine.STATE_BROKEN else (2 if evidence.wear >= 85.0 else 1)
	var fingerprint := "%d:%d:%d:%s:%d" % [int(evidence.state), int(evidence.repair_ticks), int(evidence.stock), str(evidence.needs_part), int(evidence.on_duty)]
	if fingerprint != c.last_fingerprint:
		append_history(c, now, "Wear %.2f%%; output %.1f L/min; repair %d/%d; local parts %.1f. %s" % [evidence.wear, evidence.output, evidence.repair_ticks, evidence.required_ticks, evidence.stock, evidence.summary])
		c.last_fingerprint = fingerprint
	if evidence.wear < OperationsConfig.RECOVERY_WEAR and int(evidence.state) == Machine.STATE_NOMINAL and float(evidence.output) > 0.0:
		if c.stable_since < 0: c.stable_since = now
		if now - int(c.stable_since) >= OperationsConfig.STABLE_TICKS:
			_transition(c, "RESOLVED", now, "Telemetry stayed nominal after real maintenance. Pump workflow resolved; reservoir balance remains live.")
			var inst := ws.custom_data.get("institution_system") as InstitutionSystem
			var order := inst.get_active_order(OperationsConfig.ORDER_EARLY_SERVICE) if inst else null
			if order and order.target_id == str(c.source_id):
				inst.cancel_order(order.id, ws)
		else:
			_transition(c, "STABILISED", now, "Wear and throughput recovered; confirming sustained operation.")
	else:
		c.stable_since = -1
		if int(c.severity) >= 2 or now - int(c.detected_tick) >= OperationsConfig.OVERDUE_TICKS:
			_transition(c, "ESCALATING", now, "Risk is critical or the maintenance review is overdue. Inspect current blockers.")
		elif c.monitoring:
			_transition(c, "MONITORING", now, "Monitoring normal Engineering service.")
		elif not c.actions.is_empty():
			_transition(c, "ACTIVE", now, "Service request is being followed against actual telemetry.")

func _update_information(ws: WorldState, c: Dictionary, now: int) -> void:
	var info := find_information(ws, c.source_id)
	if not info or not _visible_report(info):
		_transition(c, "FAILED", now, "Report unavailable under the current information classification.")
		return
	c.last_snapshot = {"reach_count": info.reach_count, "state": info.censorship_state, "delay": info.delay_ticks_remaining}
	var fingerprint := "%s:%d" % [info.censorship_state, info.reach_count]
	if fingerprint != c.last_fingerprint:
		append_history(c, now, "Report %s; %d recipient deliveries. Publication affects knowledge, not the underlying facility." % [info.censorship_state, info.reach_count])
		c.last_fingerprint = fingerprint
	if info.reach_count > 0:
		_transition(c, "RESOLVED", now, "Report delivered to real citizens; communication workflow complete. Inspect readership for belief feedback.")
		var inst := ws.custom_data.get("institution_system") as InstitutionSystem
		var order := inst.get_active_order(OperationsConfig.ORDER_CAPACITY_REVIEW) if inst else null
		if order and order.target_id == str(c.room_id):
			inst.cancel_order(order.id, ws)
	elif now - int(c.detected_tick) >= OperationsConfig.OVERDUE_TICKS:
		c.severity = 2
		_transition(c, "ESCALATING", now, "Report remains undelivered beyond its review deadline.")
	elif c.monitoring:
		_transition(c, "MONITORING", now, "Routine release timer continues unless the report is withheld.")
	elif not c.actions.is_empty():
		_transition(c, "ACTIVE", now, "Information decision applied; awaiting actual recipient delivery.")

func _transition(c: Dictionary, status: String, now: int, reason: String) -> void:
	if c.status == status or c.status in TERMINAL:
		return
	c.status = status
	append_history(c, now, status + ": " + reason)
	if status in TERMINAL:
		c.resolved_tick = now
		open_keys.erase(c.key)

func append_history(c: Dictionary, now: int, message: String) -> void:
	c.history.append({"tick": now, "text": message})
	while c.history.size() > OperationsConfig.HISTORY_LIMIT:
		c.history.pop_front()

func _prune() -> void:
	var archived: Array = []
	for id in cases:
		if cases[id].status in TERMINAL: archived.append(id)
	while archived.size() > OperationsConfig.ARCHIVE_LIMIT:
		cases.erase(archived.pop_front())

static func _visible_report(info: InformationObject) -> bool:
	return info.source_entity_type == "institution" and info.channel_type == InformationObject.CHANNEL_OFFICIAL and info.classification in [InformationObject.CLASS_PUBLIC, InformationObject.CLASS_INTERNAL]

static func find_information(ws: WorldState, info_id: int) -> InformationObject:
	for item in ws.custom_data.get("information_objects", []):
		var info := item as InformationObject
		if info and info.id == info_id: return info
	return null

func handle_event(world_state: Variant, event_type: String, data: Dictionary) -> void:
	if event_type != EVENT_COMMAND:
		return
	var ws := world_state as WorldState
	var c: Dictionary = cases.get(str(data.get("case_id", "")), {})
	if c.is_empty() or str(c.pending) != str(data.get("action", "")):
		return
	var action := str(c.pending)
	c.pending = ""
	var rejection := OperationsCommands.validate(ws, c, action)
	if not rejection.is_empty():
		append_history(c, ws.sim_clock.get_tick(), "Command rejected: " + rejection)
		return
	var result := OperationsCommands.execute(ws, c, action)
	append_history(c, ws.sim_clock.get_tick(), result.message)
	if result.ok:
		c.actions.append({"tick": ws.sim_clock.get_tick(), "action": action, "effect": result.message})
		while c.actions.size() > OperationsConfig.HISTORY_LIMIT: c.actions.pop_front()

func serialize() -> Dictionary:
	return {"cases": cases.duplicate(true), "open_keys": open_keys.duplicate(true), "reported": reported.duplicate(true), "next_id": next_id}

func deserialize(data: Dictionary) -> void:
	cases = data.get("cases", {}).duplicate(true)
	open_keys = data.get("open_keys", {}).duplicate(true)
	reported = data.get("reported", {}).duplicate(true)
	next_id = int(data.get("next_id", 1))
