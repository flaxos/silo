class_name CaseFormatter
extends RefCounted

## Presentation and narrative translation layer.
## Converts technical simulation data into clear, human-focused operations briefings.
## Authoritative simulation state and terminology remain unchanged.

static func get_human_title(c: Dictionary, data: Dictionary = {}) -> String:
	var kind := str(c.get("kind", ""))
	if kind == "pump":
		var state := int(data.get("state", Machine.STATE_NOMINAL))
		var wear := float(data.get("wear", 0.0))
		if state == Machine.STATE_BROKEN:
			return "Main water pump has stopped"
		elif wear >= 85.0:
			return "Water pump is near critical failure"
		elif wear >= OperationsConfig.EARLY_WEAR:
			return "Water output is falling"
		elif str(c.get("status", "")) == "RESOLVED":
			return "Water pump operating normally"
		return "Water pump wear needs attention"
	elif kind == "information":
		var topic := str(data.get("report", {}).get("topic", ""))
		if topic == "":
			topic = str(c.get("key", "")).split(":")[0]
		if "school" in topic or topic == "school_capacity":
			var info_state := str(data.get("last_snapshot", {}).get("state", ""))
			if info_state == InformationObject.STATE_SUPPRESSED:
				return "School overcrowding report withheld"
			elif str(c.get("status", "")) == "RESOLVED":
				return "School overcrowding report delivered"
			return "The school is over capacity"
		elif "audit" in topic or topic == "exposed_audit":
			return "Audit report on resource discrepancy"
		return "Official institutional report awaiting review"
	return str(c.get("title", "Operational advisory"))

static func get_human_severity(c: Dictionary, data: Dictionary = {}) -> String:
	var status := str(c.get("status", ""))
	var severity := int(c.get("severity", 1))
	if status == "RESOLVED":
		return "Resolved — operating normally"
	elif status == "STABILISED":
		return "Stable for now"
	elif status == "ESCALATING":
		if str(c.get("kind", "")) == "pump" and int(data.get("state", 0)) == Machine.STATE_BROKEN:
			return "Immediate risk to water supply"
		return "Getting worse"
	elif severity >= 3:
		return "Immediate risk to water supply"
	elif severity >= 2:
		return "High priority — needs attention"
	return "Needs attention soon"

static func get_human_status(status: String) -> String:
	match status:
		"NEW": return "New problem detected"
		"ACTIVE": return "Action in progress"
		"MONITORING": return "Monitoring without intervention"
		"ESCALATING": return "Condition deteriorating"
		"STABILISED": return "Recovering — confirming stability"
		"RESOLVED": return "Resolved"
		"FAILED": return "Closed — unresolvable"
		_: return status

static func build_briefing(ws: WorldState, c: Dictionary, detail: Dictionary) -> Dictionary:
	var briefing := {}
	var kind := str(c.get("kind", ""))
	
	if kind == "pump":
		_build_pump_briefing(ws, c, detail, briefing)
	elif kind == "information":
		_build_information_briefing(ws, c, detail, briefing)
	else:
		_build_generic_briefing(ws, c, detail, briefing)
		
	return briefing

static func _build_pump_briefing(ws: WorldState, c: Dictionary, detail: Dictionary, out: Dictionary) -> void:
	var wear := float(detail.get("wear", 0.0))
	var output := float(detail.get("output", 0.0))
	var max_output := 500.0
	var reservoir := float(ws.custom_data.get("water_reservoir_liters", 0.0))
	var room_id := int(c.get("room_id", 0))
	var room := ws.entity_registry.get_entity(room_id) as Room
	var level := room.level if room else 18
	var state := int(detail.get("state", Machine.STATE_NOMINAL))
	var stock := float(detail.get("stock", 0.0))
	var needs_part := bool(detail.get("needs_part", false))
	var on_duty := int(detail.get("on_duty", 0))
	var threshold := float(detail.get("threshold", 60.0))
	var comp_name := str(detail.get("component_id", "main bearing")).replace("_", " ")
	
	# WHAT'S HAPPENING
	if state == Machine.STATE_BROKEN:
		out["whats_happening"] = "The main water pump on Level %d has stopped due to mechanical failure." % level
	elif wear >= 85.0:
		out["whats_happening"] = "The main water pump on Level %d is running under severe mechanical stress and risks stopping." % level
	elif wear >= OperationsConfig.EARLY_WEAR:
		out["whats_happening"] = "The main water pump on Level %d is showing elevated wear and needs preventative servicing." % level
	else:
		out["whats_happening"] = "The main water pump on Level %d is running within normal operating parameters." % level
		
	# WHY IT'S HAPPENING
	var why_text := "The pump's %s has reached %.1f%% wear from continuous operation. " % [comp_name, wear]
	if str(c.get("status", "")) == "RESOLVED":
		why_text = "The worn %s was successfully replaced with a new machined bearing, and water output is fully nominal." % comp_name
	elif needs_part:
		why_text += "Maintenance has identified the problem, but cannot complete repairs because no replacement %s is currently available in the pump station inventory." % comp_name
	elif on_duty == 0:
		why_text += "A replacement %s is in local stock, but no maintenance technicians are currently on shift in this room." % comp_name
	elif wear < threshold:
		why_text += "Normal scheduled service triggers at %.0f%% wear. Technicians will not begin service until the threshold is reached or an early service window is requested." % threshold
	else:
		why_text += "Maintenance technicians on duty have the required parts and are performing repair work."
	out["why"] = why_text
	
	# WHY IT MATTERS
	if state == Machine.STATE_BROKEN:
		out["why_it_matters"] = "Water production has ceased entirely. The silo is running entirely on stored reservoir reserves (%.0f L remaining). If reserves run dry, all 1,200 residents will suffer dehydration." % reservoir
	else:
		out["why_it_matters"] = "The water reservoir currently holds %.0f L, covering current demand. If pumping falls or fails, stored water will cover the deficit until reserves deplete, threatening the entire silo's water supply." % reservoir
		
	# WHO / WHAT IS AFFECTED
	var affected_current: Array[String] = [
		"Water Pump (Level %d, Room #%d)" % [level, room_id],
		"Water Treatment and pump station maintenance crew"
	]
	var affected_potential: Array[String] = [
		"All 1,200 silo residents if reservoir reserves drop to zero",
		"Hospital and clinic sanitation if water pressure declines"
	]
	out["affected_current"] = affected_current
	out["affected_potential"] = affected_potential
	
	# WHAT WE KNOW
	var known: Array[String] = [
		"Direct telemetry confirms %s wear is at %.1f%%." % [comp_name, wear],
		"Current water throughput is %.1f L/min (rated maximum: %.1f L/min)." % [output, max_output],
		"Local inventory holds %.1f replacement bearings." % stock,
		"Maintenance shift status: %d assigned technicians, %d currently working on duty." % [int(detail.get("assigned", 60)), on_duty]
	]
	out["what_we_know"] = known
	
	# WHAT WE DON'T KNOW
	var unknown: Array[String] = [
		"Exact arrival times of future scheduled technicians cannot be guaranteed during shift transitions.",
		"Upstream machine shop bearing production depends on machinist shift availability and metal stock deliveries."
	]
	out["what_we_dont_know"] = unknown
	
	# AUTHORITY
	out["player_authority"] = "As Head of IT, you have delegated authority to request one priority early-service window from Engineering (lowering service threshold to 55%). You do not command technicians directly or fabricate spare parts."

static func _build_information_briefing(ws: WorldState, c: Dictionary, detail: Dictionary, out: Dictionary) -> void:
	var report: Dictionary = detail.get("report", {})
	var topic := str(report.get("topic", c.get("key", ""))).split(":")[0]
	var room_id := int(c.get("room_id", 0))
	var room := ws.entity_registry.get_entity(room_id) as Room
	var level := room.level if room else 16
	
	if "school" in topic or topic == "school_capacity":
		var attending := int(report.get("attending_students", 0))
		var capacity := int(report.get("capacity", 40))
		var enrolled := int(report.get("enrolled_students", 0))
		var deliveries := int(detail.get("delivery", {}).get("recipient_deliveries", 0))
		
		# WHAT'S HAPPENING
		out["whats_happening"] = "School #%d on Level %d is operating far beyond its capacity, with %d students attending in a facility built for %d." % [room_id, level, attending, capacity]
		
		# WHY IT'S HAPPENING
		out["why"] = "Demographic growth has produced 427 school-age residents across the silo, while total educational capacity across all three schools is only 120 places. Classroom construction and teacher recruitment have not kept pace with student enrolment (%d enrolled here)." % enrolled
		
		# WHY IT MATTERS
		out["why_it_matters"] = "Classrooms are severely overcrowded. Educational quality suffers, and parents are growing anxious. If overcrowding continues unaddressed, frustration will erode public morale and institutional trust."
		
		# WHO / WHAT IS AFFECTED
		out["affected_current"] = [
			"School #%d (Level %d)" % [room_id, level],
			"%d students attending and teachers assigned to this facility" % attending
		]
		out["affected_potential"] = [
			"Parent trust and social cohesion across surrounding residential quarters",
			"General population sentiment toward Administration"
		]
		
		# AUTHORITY SEPARATION (Crucial requirement from Section 8)
		out["root_problem"] = "School capacity (%d places) is far too low for current enrolment (%d students)." % [capacity, enrolled]
		out["information_problem"] = "Residents have not been officially informed of how severe the classroom crowding is."
		out["player_authority"] = "As Head of IT, you control publication and timing of the official report across communication channels. You do NOT directly control school construction, classroom allocation, or teacher hiring."
		out["outside_authority"] = "Expanding school capacity or reassigning attendance zones requires executive action by Administration and Education."
		
		# WHAT WE KNOW
		out["what_we_know"] = [
			"Actual recorded attendance: %d students attending during school hours; declared capacity is %d." % [attending, capacity],
			"Enrolment at this facility stands at %d students." % enrolled,
			"Internal administrative report has been compiled and is pending distribution (%d deliveries so far)." % deliveries
		]
		
		# WHAT WE DON'T KNOW
		out["what_we_dont_know"] = [
			"Informal word-of-mouth rumors among parents cannot be monitored or silenced by IT.",
			"How individual households will adjust their political confidence once the facts are known."
		]
	else:
		_build_generic_briefing(ws, c, detail, out)

static func _build_generic_briefing(_ws: WorldState, c: Dictionary, detail: Dictionary, out: Dictionary) -> void:
	out["whats_happening"] = "An administrative report requires operational review."
	out["why"] = "Internal reporting has documented an anomaly that awaits official publication decisions."
	out["why_it_matters"] = "Official communication affects resident trust, awareness, and institutional credibility."
	out["affected_current"] = ["Affected department and reporting office"]
	out["affected_potential"] = ["General silo population"]
	out["what_we_know"] = ["An official document has been recorded in the communication queue."]
	out["what_we_dont_know"] = ["Public reaction cannot be predicted with certainty."]
	out["player_authority"] = "As Head of IT, you control publication timing across official channels."

static func format_action(action_id: String, kind: String, c: Dictionary) -> Dictionary:
	var result := {
		"id": action_id,
		"label": "",
		"description": "",
		"why_do_it": "",
		"trade_off": "",
		"does_not_do": ""
	}
	
	match action_id:
		"request_service":
			result["label"] = "Prioritise Maintenance"
			result["description"] = "Ask Maintenance to prioritize this pump under delegated IT early-service authority."
			result["why_do_it"] = "Lowers the service threshold to 55% for 24 hours, allowing technicians to begin repairs before standard 60% wear."
			result["trade_off"] = "Occupies the silo's single early-service scheduling slot; consumes real spare parts and technician hours sooner."
			result["does_not_do"] = "Will NOT create replacement parts out of thin air, conscript off-duty staff, or instantly repair the machine."
			
		"cancel_service":
			result["label"] = "Release Early-Service Slot"
			result["description"] = "Cancel the early-service request and restore standard maintenance scheduling."
			result["why_do_it"] = "Frees the single early-service slot for another critical facility in the silo."
			result["trade_off"] = "The pump will not be serviced until it reaches normal 60% wear or breakdown."
			result["does_not_do"] = "Does NOT undo repair progress already completed by technicians."
			
		"monitor":
			result["label"] = "Monitor Normal Process"
			result["description"] = "Take no immediate action and observe existing operations."
			result["why_do_it"] = "Conserves administrative attention and leaves priority slots open for sudden emergencies."
			result["trade_off"] = "The problem may worsen while you wait for normal maintenance thresholds or routine release timers."
			result["does_not_do"] = "Does NOT intervene or change any operational schedules."
			
		"publish":
			result["label"] = "Publish Report Now"
			result["description"] = "Release the official report immediately across all public communication channels."
			result["why_do_it"] = "Informs residents about the facts, maintaining official transparency and preempting rumors."
			result["trade_off"] = "Residents will learn about the severe problem, which may damage confidence in silo leadership."
			result["does_not_do"] = "Informs people; it does NOT create classroom space, hire teachers, or solve the root problem."
			
		"delay":
			result["label"] = "Review for Six Hours"
			result["description"] = "Delay publication for six hours to allow administrative review."
			result["why_do_it"] = "Gives leadership time to prepare an official response or mitigation strategy before disclosure."
			result["trade_off"] = "Delay may look like concealment if rumors spread first. Allowed only once."
			result["does_not_do"] = "Does NOT cancel the report or fix the underlying facility issue."
			
		"withhold":
			result["label"] = "Withhold Official Report"
			result["description"] = "Suppress official distribution of this report indefinitely."
			result["why_do_it"] = "Prevents public alarm or unrest by keeping the report internal."
			result["trade_off"] = "Censorship is permanently logged in the audit log. If residents discover the truth, trust will drop sharply."
			result["does_not_do"] = "Does NOT erase the underlying facts or solve the overcrowding."
			
		"request_review":
			result["label"] = "Request Capacity Review"
			result["description"] = "Formally request an administrative review of school capacity from Executive Leadership."
			result["why_do_it"] = "Places school expansion onto the formal executive docket for administrative evaluation."
			result["trade_off"] = "Takes 24 hours of administrative review time; requires approval from Executive Leadership."
			result["does_not_do"] = "Does NOT directly build classrooms or transfer students."
			
		_:
			result["label"] = action_id.capitalize()
			result["description"] = "Execute %s action." % action_id
			result["why_do_it"] = "Applies standard operational directive."
			result["trade_off"] = "Normal operational consequences apply."
			result["does_not_do"] = "Does not bypass simulation rules."
			
	return result

static func format_feedback(action: String, ok: bool, c: Dictionary, extra_info: Dictionary = {}) -> String:
	if not ok:
		return "Action could not be executed: inspect current authority and requirements."
		
	match action:
		"request_service":
			return "Early-service slot reserved for 24h. Maintenance threshold lowered to 55%; technicians will repair once parts and shift workers are present."
		"cancel_service":
			return "Early-service slot released. Normal 60% maintenance threshold restored; completed repair work remains intact."
		"monitor":
			return "Monitoring confirmed. No operational overrides applied; normal scheduled systems continue."
		"publish":
			var reach := int(extra_info.get("reach_count", 0))
			return "Report released on official channels; %d residents have received the official findings. Note: publication informs residents, but does not add classrooms." % reach
		"delay":
			return "Review extension granted: publication held for six hours. Residents wait for official facts; existing private beliefs remain."
		"withhold":
			return "Report withheld from official release and logged in the censorship audit. The underlying truth remains and may surface via informal channels."
		"request_review":
			return "Formal capacity review requested from Administration. Recorded on executive docket; does not add classrooms."
		_:
			return "Action recorded and applied."

static func build_os_telemetry(ws: WorldState, c: Dictionary, detail: Dictionary) -> Dictionary:
	var out := {}
	var kind := str(c.get("kind", ""))
	
	if kind == "pump":
		var wear := float(detail.get("wear", 0.0))
		var output := float(detail.get("output", 0.0))
		var max_output := 500.0
		var reservoir := float(ws.custom_data.get("water_reservoir_liters", 0.0))
		var stock := float(detail.get("stock", 0.0))
		var on_duty := int(detail.get("on_duty", 0))
		var state := int(detail.get("state", Machine.STATE_NOMINAL))
		var threshold := float(detail.get("threshold", 60.0))
		var room_id := int(c.get("room_id", 0))
		var room := ws.entity_registry.get_entity(room_id) as Room
		var level := room.level if room else 18
		
		# 10-block visual gauge bar
		var wear_blocks := clampi(int(wear / 10.0), 0, 10)
		var wear_bar := "█".repeat(wear_blocks) + "░".repeat(10 - wear_blocks)
		var wear_color := "#ff3366" if wear >= 85.0 or state == Machine.STATE_BROKEN else ("#ffb703" if wear >= threshold else "#06d6a0")
		
		var output_blocks := clampi(int((output / max_output) * 10.0), 0, 10)
		var output_bar := "█".repeat(output_blocks) + "░".repeat(10 - output_blocks)
		var output_color := "#ff3366" if output <= 0.0 else ("#ffb703" if output < 350.0 else "#06d6a0")
		
		out["gauges"] = [
			{"label": "BEARING WEAR", "val": "%.1f%%" % wear, "bar": wear_bar, "color": wear_color, "limit": "%.0f%% limit" % threshold},
			{"label": "WATER OUTPUT", "val": "%.0f L/m" % output, "bar": output_bar, "color": output_color, "limit": "%.0f max" % max_output}
		]
		
		out["chips"] = [
			{"icon": "💧", "text": "%.0f L Reserves" % reservoir, "color": "#4cc9f0"},
			{"icon": "⚙️", "text": "%.1f kg Bearing in Stock" % stock, "color": "#06d6a0" if stock > 0.0 else "#ff3366"},
			{"icon": "👷", "text": "%d Techs on Shift" % on_duty, "color": "#06d6a0" if on_duty > 0 else "#ffb703"},
			{"icon": "📍", "text": "L%d · Room #%d" % [level, room_id], "color": "#8da9c4"}
		]
		
		if state == Machine.STATE_BROKEN:
			out["situation"] = "Main pump stopped. Water output halted."
			out["stakes"] = "Reservoir depleting (%.0f L left)." % reservoir
		elif wear >= 85.0:
			out["situation"] = "Bearing wear critical (%.1f%%). Imminent stoppage." % wear
			out["stakes"] = "Requires urgent service before reserves deplete."
		elif wear >= OperationsConfig.EARLY_WEAR:
			out["situation"] = "Bearing wear elevated (%.1f%%). Output stable." % wear
			out["stakes"] = "Early service prevents emergency breakdown."
		else:
			out["situation"] = "Pump nominal. Bearing wear at %.1f%%." % wear
			out["stakes"] = "Water reserves healthy."
			
		out["authority_chip"] = "IT Scope: Reserve 1 early service window. Engineering performs physical repair."

	elif kind == "information":
		var room_id := int(c.get("room_id", 0))
		var room := ws.entity_registry.get_entity(room_id) as Room
		var level := room.level if room else 16
		var enrolled := 207
		var capacity := 40
		var staff := 34
		if detail.has("report") and detail.report.has("facts"):
			var facts: Dictionary = detail.report.facts
			enrolled = int(facts.get("attending_students", enrolled))
			capacity = int(facts.get("capacity", capacity))
		
		var pct := (float(enrolled) / float(capacity)) * 100.0 if capacity > 0 else 100.0
		var cap_blocks := clampi(int(pct / 20.0), 0, 10)
		var cap_bar := "█".repeat(cap_blocks) + "░".repeat(10 - cap_blocks)
		var cap_color := "#ff3366" if pct > 150.0 else ("#ffb703" if pct > 100.0 else "#06d6a0")
		
		var info_state := str(detail.get("last_snapshot", {}).get("state", "PENDING"))
		var state_text := "REPORT WITHHELD" if info_state == InformationObject.STATE_SUPPRESSED else ("REPORT DELIVERED" if str(c.get("status", "")) == "RESOLVED" else "PENDING REVIEW")
		var state_color := "#ffb703" if info_state == InformationObject.STATE_SUPPRESSED else ("#06d6a0" if str(c.get("status", "")) == "RESOLVED" else "#4cc9f0")
		
		out["gauges"] = [
			{"label": "ROOM DENSITY", "val": "%d / %d (%.0f%%)" % [enrolled, capacity, pct], "bar": cap_bar, "color": cap_color, "limit": "%d cap" % capacity}
		]
		
		out["chips"] = [
			{"icon": "🏫", "text": "School #%d (L%d)" % [room_id, level], "color": "#4cc9f0"},
			{"icon": "👥", "text": "%d Students" % enrolled, "color": "#ff3366" if pct > 100.0 else "#06d6a0"},
			{"icon": "👨‍🏫", "text": "%d Teachers" % staff, "color": "#06d6a0"},
			{"icon": "📢", "text": state_text, "color": state_color}
		]
		
		out["situation"] = "School #%d: %d students for %d desks." % [room_id, enrolled, capacity]
		out["stakes"] = "Report pending release. Publishing does not build rooms."
		out["authority_chip"] = "IT Scope: Information governance & capacity review request. Construction requires Board action."
		
	else:
		out["gauges"] = []
		out["chips"] = []
		out["situation"] = str(c.get("summary", "Operational advisory active."))
		out["stakes"] = "Monitor telemetry for updates."
		out["authority_chip"] = "IT Scope: Standard operational monitoring."
		
	return out

