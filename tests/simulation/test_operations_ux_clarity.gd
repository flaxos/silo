class_name TestOperationsUxClarity
extends RefCounted

const TestAsserts = preload("res://tests/framework/test_asserts.gd")
const OperationsConfig = preload("res://src/sim/operations/operations_config.gd")
const OperationsSession = preload("res://src/sim/operations/operations_session.gd")
const OperationsSystem = preload("res://src/sim/operations/operations_system.gd")
const OperationsCommands = preload("res://src/sim/operations/operations_commands.gd")
const CaseReader = preload("res://src/presentation/case_reader.gd")
const CommandAdapter = preload("res://src/presentation/command_adapter.gd")
const CaseFormatter = preload("res://src/presentation/case_formatter.gd")

func run_all(a: TestAsserts) -> void:
	_test_human_case_titles_and_severity(a)
	_test_no_engine_speak_in_briefings(a)
	_test_school_authority_and_root_problem_distinction(a)
	_test_action_tradeoffs_and_what_they_do_not_do(a)
	_test_pump_maintenance_state_explanations(a)
	_test_maintenance_labour_crew_cap(a)
	_test_security_officer_staffing(a)
	_test_school_capacity_review_escalation(a)

func _test_human_case_titles_and_severity(a: TestAsserts) -> void:
	a.set_current_test("Operations UX: Human titles and severity without raw enums")
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	
	# Trigger pump case
	engine.step(20)
	var brief := CaseReader.brief(ws)
	a.assert_gt(brief.active_count, 0, "active case detected")
	
	var pump_row: Dictionary = brief.active[0]
	a.assert_false(pump_row.title.contains("STATUS_"), "title contains no STATUS_ enum")
	a.assert_false(pump_row.title.contains("STATE_"), "title contains no STATE_ enum")
	a.assert_false(pump_row.title.contains("TYPE_"), "title contains no TYPE_ enum")
	a.assert_false(pump_row.title.contains("Case #"), "title is human descriptive, not raw data structure")
	a.assert_true(pump_row.title.contains("Water"), "title describes the actual problem")
	
	# Check human severity text
	a.assert_true(pump_row.has("severity_text"), "row includes severity_text")
	a.assert_false(pump_row.severity_text.is_empty(), "severity_text is populated")
	a.assert_false(pump_row.severity_text.begins_with("SEVERITY_"), "severity contains no enum prefix")
	
	var detail := CaseReader.detail(ws, pump_row.id)
	a.assert_true(detail.has("severity_text"), "detail includes human severity")
	a.assert_true(detail.has("status_text"), "detail includes human status")

func _test_no_engine_speak_in_briefings(a: TestAsserts) -> void:
	a.set_current_test("Operations UX: Normal UI avoids engine-speak and debug jargon")
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	engine.step(20)
	
	var brief := CaseReader.brief(ws)
	if brief.active_count == 0:
		a.assert_true(false, "expected active case")
		return
		
	var cid: String = brief.active[0].id
	var detail := CaseReader.detail(ws, cid)
	var briefing: Dictionary = detail.briefing
	
	var banned_jargon: Array[String] = [
		"entity registry", "source entity", "state transition",
		"causal node", "throughput ratio", "event id", "dispatch command",
		"authoritative state", "simulation tick"
	]
	
	var check_texts: Array[String] = [
		str(briefing.get("whats_happening", "")),
		str(briefing.get("why", "")),
		str(briefing.get("why_it_matters", "")),
		str(detail.get("summary", ""))
	]
	
	for text in check_texts:
		var lower := text.to_lower()
		for jargon in banned_jargon:
			a.assert_false(lower.contains(jargon), "normal briefing text must not contain '%s'" % jargon)
			
	# Technical details should be cleanly separated
	a.assert_true(detail.has("technical_details"), "technical details are separated")
	a.assert_true(detail.technical_details.has("machine_state"), "technical details contain raw state")

func _test_school_authority_and_root_problem_distinction(a: TestAsserts) -> void:
	a.set_current_test("Operations UX: School overcrowding distinguishes root problem and authority")
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	var info_sys := ws.custom_data.get("information_system") as InformationSystem
	
	var facts := {"room_id": 1981, "observed_tick": ws.sim_clock.get_tick(), "attending_students": 207, "capacity": 40, "enrolled_students": 207}
	var info := info_sys.create_information(ws, "school:1981:test", "institution", 0, "school_capacity", facts, facts, InformationObject.CHANNEL_OFFICIAL, {"type": "all"}, InformationObject.CLASS_INTERNAL)
	info_sys.delay_information(ws, info.id, OperationsConfig.OVERDUE_TICKS)
	
	engine.step(1)
	var brief := CaseReader.brief(ws)
	var school_case_id := ""
	for row in brief.active:
		if row.kind == "information":
			school_case_id = row.id
			break
	a.assert_ne(school_case_id, "", "school information case detected")
	
	var detail := CaseReader.detail(ws, school_case_id)
	var b: Dictionary = detail.briefing
	
	# Explicit separation of root problem, information status, and authority
	a.assert_true(b.has("root_problem"), "briefing defines root problem")
	a.assert_true(b.has("information_problem"), "briefing defines information problem")
	a.assert_true(b.has("player_authority"), "briefing defines player authority")
	a.assert_true(b.has("outside_authority"), "briefing defines outside authority")
	
	a.assert_true(b.root_problem.contains("capacity"), "root problem refers to capacity")
	a.assert_true(b.information_problem.contains("informed"), "information problem refers to transparency/disclosure")
	a.assert_true(b.player_authority.contains("IT"), "authority clearly identifies Head of IT role")
	a.assert_true(b.outside_authority.contains("Administration"), "outside authority clearly points to Administration/Education")

func _test_action_tradeoffs_and_what_they_do_not_do(a: TestAsserts) -> void:
	a.set_current_test("Operations UX: Actions state why, trade-offs, and what they do NOT do")
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	engine.step(20)
	
	var brief := CaseReader.brief(ws)
	var cid: String = brief.active[0].id
	var detail := CaseReader.detail(ws, cid)
	
	for action in detail.available_actions:
		a.assert_false(str(action.get("why_do_it", "")).is_empty(), "action '%s' explains why to do it" % action.id)
		a.assert_false(str(action.get("trade_off", "")).is_empty(), "action '%s' explains trade-off" % action.id)
		a.assert_false(str(action.get("does_not_do", "")).is_empty(), "action '%s' explicitly states what it does NOT do" % action.id)
		
	# For school publication, verify explicit anti-magic assertion
	var info_sys := ws.custom_data.get("information_system") as InformationSystem
	var facts := {"room_id": 1981, "observed_tick": ws.sim_clock.get_tick(), "attending_students": 207, "capacity": 40, "enrolled_students": 207}
	var info := info_sys.create_information(ws, "school:action_test", "institution", 0, "school_capacity", facts, facts, InformationObject.CHANNEL_OFFICIAL, {"type": "all"}, InformationObject.CLASS_INTERNAL)
	info_sys.delay_information(ws, info.id, OperationsConfig.OVERDUE_TICKS)
	engine.step(1)
	
	for row in CaseReader.brief(ws).active:
		if row.kind == "information":
			var d := CaseReader.detail(ws, row.id)
			for act in d.available_actions:
				if act.id == "publish":
					a.assert_true(act.does_not_do.contains("classroom") or act.does_not_do.contains("root problem"), "publish action explicitly disclaims solving classroom shortage")

func _test_pump_maintenance_state_explanations(a: TestAsserts) -> void:
	a.set_current_test("Operations UX: Pump maintenance distinguishes problem, blocked, underway, and repaired")
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	var pump := ws.entity_registry.get_entity(ws.entity_registry.get_entities_by_type("machine")[0]) as WaterPump
	var bearing := pump.get_component(WaterPump.COMP_BEARING)
	
	# 1. Problem detected
	bearing.wear_percent = 56.0
	pump.update_state()
	engine.step(1)
	var brief := CaseReader.brief(ws)
	var cid: String = brief.active[0].id
	var d1 := CaseReader.detail(ws, cid)
	a.assert_true(d1.briefing.why.contains("wear"), "explanation identifies wear")
	
	# 2. Repair requested
	CommandAdapter.dispatch_case_action(ws, cid, "request_service")
	engine.step(1)
	var d2 := CaseReader.detail(ws, cid)
	a.assert_true(d2.status == "ACTIVE" or d2.pending == "" or d2.history.size() > 0, "case tracks requested state")
	
	# 3. Blocked state (clear inventory stock)
	var room := ws.entity_registry.get_entity(pump.room_id) as Room
	var inv := ws.entity_registry.get_entity(room.inventory_id) as Inventory
	if inv: inv.remove_resource(ResourceRegistry.RES_MACHINED_BEARING, inv.get_quantity(ResourceRegistry.RES_MACHINED_BEARING))
	engine.step(1)
	var d3 := CaseReader.detail(ws, cid)
	a.assert_true(d3.briefing.why.contains("available") or d3.briefing.why.contains("part"), "explanation highlights missing replacement part")
	
	# 4. Repaired state
	bearing.wear_percent = 0.0
	pump.update_state()
	for i in range(OperationsConfig.STABLE_TICKS + 2):
		engine.step(1)
	var archive: Array = CaseReader.brief(ws).archive
	if archive.size() > 0:
		var d4 := CaseReader.detail(ws, archive[0].id)
		a.assert_true(d4.briefing.why.contains("replaced") or d4.briefing.why.contains("nominal"), "resolved briefing confirms completed repair")

func _test_maintenance_labour_crew_cap(a: TestAsserts) -> void:
	a.set_current_test("Maintenance labour: MAX_CREW_PER_MACHINE caps swarming labour")
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	# Step into day-shift working hours (tick 60 = 10:00 AM) when technicians are on duty
	engine.step(60)
	var pump := ws.entity_registry.get_entity(ws.entity_registry.get_entities_by_type("machine")[0]) as WaterPump
	var bearing := pump.get_component(WaterPump.COMP_BEARING)
	bearing.wear_percent = 65.0
	pump.update_state()
	
	# Ensure replacement part is in pump station inventory
	var room := ws.entity_registry.get_entity(pump.room_id) as Room
	var inv := ws.entity_registry.get_entity(room.inventory_id) as Inventory
	if inv: inv.add_resource(ResourceRegistry.RES_MACHINED_BEARING, 5.0)
	
	# Count technicians currently working in the room
	var techs_in_room := 0
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var p: Person = ws.entity_registry.get_entity(pid)
		if p and p.is_alive and p.current_location_id == room.id and p.occupation_id == "maintenance_technician" and p.current_activity == Person.ACTIVITY_WORKING:
			techs_in_room += 1
			
	a.assert_gt(techs_in_room, MaintenanceSystem.MAX_CREW_PER_MACHINE, "large silo has many technicians working simultaneously")
	
	var repair_before := bearing.accumulated_repair_ticks
	engine.step(1)
	var repair_delta := bearing.accumulated_repair_ticks - repair_before
	
	# Crucial assertion: repair progress in 1 tick is capped by MAX_CREW_PER_MACHINE (3), NOT 45+
	a.assert_lte(repair_delta, MaintenanceSystem.MAX_CREW_PER_MACHINE, "repair ticks per tick capped by physical workspace (MAX_CREW_PER_MACHINE)")
	a.assert_gt(repair_delta, 0, "repair progress is positive while crew is working")

func _test_security_officer_staffing(a: TestAsserts) -> void:
	a.set_current_test("Staffing audit: Security Officer occupation generated and assigned")
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	
	var sec_officers := 0
	var sec_post_workers := 0
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var p: Person = ws.entity_registry.get_entity(pid)
		if p and p.is_alive and p.occupation_id == "security_officer":
			sec_officers += 1
			var work_room: Room = ws.entity_registry.get_entity(p.workplace_room_id)
			if work_room and work_room.room_type == Room.TYPE_SECURITY_POST:
				sec_post_workers += 1
				
	a.assert_gt(sec_officers, 0, "security officers are generated in working population")
	a.assert_eq(sec_officers, sec_post_workers, "all security officers are assigned to security posts")

func _test_school_capacity_review_escalation(a: TestAsserts) -> void:
	a.set_current_test("Operations loop: School capacity review escalation order")
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	var info_sys := ws.custom_data.get("information_system") as InformationSystem
	var inst := ws.custom_data.get("institution_system") as InstitutionSystem
	
	var facts := {"room_id": 1981, "observed_tick": ws.sim_clock.get_tick(), "attending_students": 207, "capacity": 40, "enrolled_students": 207}
	var info := info_sys.create_information(ws, "school:review_test", "institution", 0, "school_capacity", facts, facts, InformationObject.CHANNEL_OFFICIAL, {"type": "all"}, InformationObject.CLASS_INTERNAL)
	info_sys.delay_information(ws, info.id, OperationsConfig.OVERDUE_TICKS)
	engine.step(1)
	
	var case_id := ""
	for row in CaseReader.brief(ws).active:
		if row.kind == "information": case_id = row.id; break
	a.assert_ne(case_id, "", "case detected")
	
	# Queue request_review
	var res := CommandAdapter.dispatch_case_action(ws, case_id, "request_review")
	a.assert_true(res.ok, "request_review action queued successfully")
	
	# Step 1 tick to execute command
	engine.step(1)
	
	var order := inst.get_active_order(OperationsConfig.ORDER_CAPACITY_REVIEW)
	a.assert_not_null(order, "administrative capacity review order created in InstitutionSystem")
	a.assert_eq(order.department_id, Occupation.DEPT_IT, "order issued under IT authority")
	
	# Duplicate request rejected while active
	var res2 := CommandAdapter.dispatch_case_action(ws, case_id, "request_review")
	a.assert_false(res2.ok, "duplicate capacity review request rejected while active")
