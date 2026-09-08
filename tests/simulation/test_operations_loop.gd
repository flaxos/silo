class_name TestOperationsLoop
extends RefCounted

func run_all(a: TestAsserts) -> void:
	_test_normal_water(a)
	_test_blockers_and_escalation(a)
	_test_information(a)
	_test_authority_and_readonly(a)
	_test_order_persistence_and_expiry(a)
	_test_replay_save_and_performance(a)

func _ops(ws: WorldState) -> OperationsSystem:
	return ws.custom_data.operations_system as OperationsSystem

func _case(ws: WorldState, kind: String) -> Dictionary:
	for c in _ops(ws).cases.values():
		if c.kind == kind and not c.status in OperationsSystem.TERMINAL: return c
	return {}

func _pump(ws: WorldState) -> WaterPump:
	return ws.entity_registry.get_entity(ws.entity_registry.get_entities_by_type("machine")[0]) as WaterPump

func _test_normal_water(a: TestAsserts) -> void:
	a.set_current_test("Operations: normal water detection → authorized request → actual repair")
	var engine := OperationsSession.create()
	var control := OperationsSession.create()
	var ws := engine.world_state
	var p := _pump(ws)
	a.assert_eq(p.state, Machine.STATE_NOMINAL, "inherited silo starts functioning")
	a.assert_eq(CaseReader.brief(ws).active_count, 0, "no forced initial crisis")
	engine.step(18); control.step(18)
	var c := _case(ws, "pump")
	if not a.assert_false(c.is_empty(), "ordinary wear creates pump case"): return
	a.assert_eq(c.source_id, p.id, "stable machine reference")
	a.assert_eq(c.room_id, p.room_id, "real physical room reference")
	a.assert_eq(_ops(ws).cases.size(), 1, "no duplicate unresolved pump cases")
	var before := p.get_component(WaterPump.COMP_BEARING).wear_percent
	var response := CommandAdapter.dispatch_case_action(ws, c.id, "request_service")
	a.assert_true(response.ok, "IT scheduling action queues")
	a.assert_eq(p.get_component(WaterPump.COMP_BEARING).wear_percent, before, "click does not repair")
	a.assert_eq(c.status, "NEW", "click does not resolve")
	a.assert_false(CommandAdapter.dispatch_case_action(ws, c.id, "request_service").ok, "duplicate queued input rejected")
	var d := CaseReader.detail(ws, c.id)
	a.assert_gte(d.why.size(), 4, "causal drilldown includes machine, labour and inventory")
	engine.step(1); control.step(1)
	var inst := ws.custom_data.institution_system as InstitutionSystem
	a.assert_not_null(inst.get_active_order(OperationsConfig.ORDER_EARLY_SERVICE), "request dispatches an actual executive order")
	a.assert_ne(c.status, "RESOLVED", "execution alone cannot resolve")
	engine.step(110); control.step(110)
	a.assert_eq(c.status, "RESOLVED", "actual staffed repair and stable telemetry resolve the case")
	a.assert_lt(p.get_component(WaterPump.COMP_BEARING).wear_percent, 5.0, "real component replacement occurred")
	a.assert_gt(_pump(control.world_state).get_component(WaterPump.COMP_BEARING).wear_percent, 55.0, "monitor counterfactual has not yet replaced the bearing")
	a.assert_gt(float(ws.custom_data.get("maintenance_installed_mass_kg", 0.0)), 0.0, "repair installed physical material")
	a.assert_null(inst.get_active_order(OperationsConfig.ORDER_EARLY_SERVICE), "resolved service frees opportunity-cost slot")
	a.assert_true(EconomyInvariants.validate(ws, ProductionSystem.INITIAL_SEAM_ORE_KG).get("is_valid", false), "all material remains conserved")
	var count := _ops(ws).next_id
	engine.step(12)
	a.assert_eq(c.status, "RESOLVED", "terminal outcome remains stable")
	a.assert_eq(_ops(ws).next_id, count, "healthy pump creates no replacement case")
	print("  WATER_UAT normal_seed=42 pop=1200 detection_tick=%d resolved_tick=%d installed_kg=%.2f" % [c.detected_tick, c.resolved_tick, ws.custom_data.get("maintenance_installed_mass_kg", 0.0)])

func _test_blockers_and_escalation(a: TestAsserts) -> void:
	a.set_current_test("Operations: blocked repairs escalate without magic")
	var e := OperationsSession.create(100)
	var ws := e.world_state
	var p := _pump(ws)
	# UAT fixture: inherited critical bearing and unavailable local labour/stock.
	p.get_component(WaterPump.COMP_BEARING).wear_percent = 99.0
	p.update_state()
	e.scheduler.remove_system("daily_life")
	e.scheduler.remove_system("production")
	e.step(1)
	var c := _case(ws, "pump")
	a.assert_eq(c.status, "ESCALATING", "critical authoritative wear escalates")
	a.assert_gt(c.incident_ids.size(), 0, "case references existing incident instead of replacing it")
	a.assert_true(CommandAdapter.dispatch_case_action(ws, c.id, "request_service").ok, "request remains allowed under real critical condition")
	e.step(72)
	a.assert_eq(p.state, Machine.STATE_BROKEN, "ordinary wear causes physical failure")
	a.assert_eq(c.status, "ESCALATING", "request cannot repair without inputs")
	a.assert_eq(p.get_component(WaterPump.COMP_BEARING).accumulated_repair_ticks, 0, "no fabricated labour")
	var room := ws.entity_registry.get_entity(p.room_id) as Room
	var inv := Inventory.new(0, room.id, 100.0)
	inv.id = ws.entity_registry.register_entity("inventory", inv)
	room.inventory_id = inv.id
	# Explicit fixture stock moved from a real source inventory; no action mints resources.
	var source := Inventory.new(0, 0, 100.0)
	source.add_resource(ResourceRegistry.RES_MACHINED_BEARING, 1.0)
	source.transfer_to(inv, ResourceRegistry.RES_MACHINED_BEARING, 1.0)
	var tech: Person = null
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var person := ws.entity_registry.get_entity(pid) as Person
		if person.occupation_id == "maintenance_technician": tech = person; break
	if not a.assert_not_null(tech, "fixture has a real qualified technician"): return
	tech.current_location_id = p.room_id; tech.current_activity = Person.ACTIVITY_WORKING
	e.step(15)
	a.assert_eq(c.status, "RESOLVED", "real labour plus consumed part restore output")
	a.assert_gt(p.current_water_throughput_lpm, 0.0, "systemic throughput recovers")
	a.assert_eq(inv.get_quantity(ResourceRegistry.RES_MACHINED_BEARING), 0.0, "replacement part consumed")
	# A new physical episode gets a distinct workflow ID.
	p.get_component(WaterPump.COMP_BEARING).wear_percent = 85.0; p.update_state()
	tech.current_activity = Person.ACTIVITY_SLEEPING
	e.step(1)
	var recurring := _case(ws, "pump")
	a.assert_ne(recurring.id, c.id, "genuine recurrence has a new case ID")
	ws.entity_registry.remove_entity(p.id)
	_ops(ws).tick(ws)
	a.assert_eq(recurring.status, "FAILED", "missing source fails honestly, never resolves")
	print("  WATER_UAT critical_fixture failure_after_real_wear=true repair_requires_part_and_worker=true")

func _test_information(a: TestAsserts) -> void:
	a.set_current_test("Operations: non-infrastructure institutional information loop")
	var e := OperationsSession.create()
	var ws := e.world_state
	e.step(90)
	var c := _case(ws, "information")
	if not a.assert_false(c.is_empty(), "real school attendance produces institutional report"): return
	var info := OperationsSystem.find_information(ws, c.source_id)
	a.assert_gt(info.claim.attending_students, info.claim.capacity, "report grounded in observed capacity exceedance")
	a.assert_eq(info.topic, "school_capacity", "second domain independent of pump")
	a.assert_eq(info.reach_count, 0, "unreleased report has not been delivered")
	var evidence := CaseReader.detail(ws, c.id)
	a.assert_eq(evidence.room_id, info.claim.room_id, "information case links real school")
	var physical := PhysicalReader.resolve_entity(ws, "room", str(c.room_id))
	a.assert_false(physical.is_empty(), "school can be located in existing physical reader")
	var truths := info.truth_basis.duplicate(true)
	a.assert_true(CommandAdapter.dispatch_case_action(ws, c.id, "withhold").ok, "IT can withhold official report")
	e.step(1)
	a.assert_true(info.is_suppressed(), "existing censorship system handles action")
	a.assert_ne(c.status, "RESOLVED", "withholding is not resolution")
	e.step(OperationsConfig.OVERDUE_TICKS)
	a.assert_eq(info.reach_count, 0, "suppression prevents official delivery")
	a.assert_eq(c.status, "ESCALATING", "overdue withheld information escalates")
	a.assert_true(CommandAdapter.dispatch_case_action(ws, c.id, "delay").ok, "IT can replace hold with bounded review")
	e.step(1)
	a.assert_true(info.is_delayed(), "existing information delay applied")
	a.assert_false(CommandAdapter.dispatch_case_action(ws, c.id, "delay").ok, "cannot extend review indefinitely")
	e.step(OperationsConfig.REVIEW_DELAY_TICKS)
	a.assert_gt(info.reach_count, 0, "elapsed simulation delivers to real recipients")
	a.assert_eq(c.status, "RESOLVED", "actual delivery resolves communication workflow")
	a.assert_eq(info.truth_basis, truths, "publication never changes source truth")
	var believers := 0
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var person := ws.entity_registry.get_entity(pid) as Person
		if person.has_belief(info.originating_event_id): believers += 1
	a.assert_gt(believers, 0, "real citizen beliefs change downstream")
	a.assert_false(CaseReader.detail(ws, c.id).has("beliefs"), "private citizen beliefs stay outside IT gameplay knowledge")
	print("  SECOND_DOMAIN_UAT school_room=%d info_id=%d observed_students=%d capacity=%d deliveries=%d citizen_beliefs=%d" % [c.room_id, info.id, info.claim.attending_students, info.claim.capacity, info.reach_count, believers])

func _test_authority_and_readonly(a: TestAsserts) -> void:
	a.set_current_test("Operations: authority, stale commands and read-only projections")
	var e := OperationsSession.create(100)
	var ws := e.world_state
	e.step(18)
	var c := _case(ws, "pump")
	var before := ws.get_state_checksum()
	var detail := CaseReader.detail(ws, c.id)
	detail.history.clear(); detail.why.clear(); detail.actions.clear()
	var brief := CaseReader.brief(ws); brief.active.clear()
	a.assert_eq(ws.get_state_checksum(), before, "read models and mutated copies are read-only")
	a.assert_false(CommandAdapter.dispatch_case_action(ws, c.id, "fix_pump").ok, "magic repair rejected")
	a.assert_false(CommandAdapter.dispatch_case_action(ws, c.id, ExecutiveOrder.ORDER_CONSCRIPT_LABOR).ok, "IT cannot conscript")
	ws.custom_data.player_role = "observer"
	a.assert_false(CommandAdapter.dispatch_case_action(ws, c.id, "request_service").ok, "observer has no gameplay authority")
	ws.custom_data.player_role = OperationsConfig.ROLE_IT
	a.assert_true(CommandAdapter.dispatch_case_action(ws, c.id, "request_service").ok, "authorized input accepted")
	ws.custom_data.it_service_delegation = false
	e.step(1)
	var inst := ws.custom_data.institution_system as InstitutionSystem
	a.assert_null(inst.get_active_order(OperationsConfig.ORDER_EARLY_SERVICE), "authority rechecked at execution time")
	a.assert_true(str(c.history.back().text).contains("rejected") or str(c.history[c.history.size() - 2].text).contains("rejected"), "rejection trace retained")
	ws.custom_data.it_service_delegation = true
	a.assert_true(CommandAdapter.dispatch_case_action(ws, c.id, "request_service").ok, "retry after authority restoration")
	e.step(1)
	a.assert_false(CommandAdapter.dispatch_case_action(ws, c.id, "request_service").ok, "single slot cannot be duplicated")
	a.assert_true(CommandAdapter.dispatch_case_action(ws, c.id, "cancel_service").ok, "IT may cancel its request")
	e.step(1)
	a.assert_null(inst.get_active_order(OperationsConfig.ORDER_EARLY_SERVICE), "cancellation dispatch reaches institutions")
	var infos := ws.custom_data.information_system as InformationSystem
	var private_info := infos.create_information(ws, "secret", "institution", 0, "private", {"hidden_perpetrator": 999}, {"summary": "redacted"}, InformationObject.CHANNEL_OFFICIAL, {"type": "all"}, InformationObject.CLASS_RESTRICTED)
	e.step(1)
	a.assert_false(_ops(ws).open_keys.has("information:%d" % private_info.id), "restricted report never surfaces as gameplay case")
	var public_info := infos.create_information(ws, "public", "institution", 0, "report", {"hidden_perpetrator": 999}, {"summary": "known report"})
	e.step(1)
	var info_case := _case(ws, "information")
	var visible := CaseReader.detail(ws, info_case.id)
	a.assert_false(str(visible).contains("hidden_perpetrator"), "hidden truth basis does not leak")
	a.assert_true(CommandAdapter.dispatch_case_action(ws, info_case.id, "publish").ok, "publication goes through gameplay authority")
	e.step(1)
	a.assert_gt(public_info.reach_count, 0, "publish dispatch delivers")
	a.assert_eq(info_case.status, "RESOLVED", "publish outcome derives from actual recipients")

func _test_order_persistence_and_expiry(a: TestAsserts) -> void:
	a.set_current_test("Operations: pending/active order persistence, expiry and invalid saves")
	var e := OperationsSession.create(100)
	e.step(18)
	var ws := e.world_state
	var c := _case(ws, "pump")
	CommandAdapter.dispatch_case_action(ws, c.id, "request_service")
	var restored := OperationsSession.restore(OperationsSession.capture(e))
	a.assert_eq(e.get_state_checksum(), restored.get_state_checksum(), "pending service command survives save")
	e.step(1); restored.step(1)
	a.assert_eq(e.get_state_checksum(), restored.get_state_checksum(), "restored queued request executes identically")
	var active := OperationsSession.restore(OperationsSession.capture(e))
	a.assert_eq(e.get_state_checksum(), active.get_state_checksum(), "active executive order survives save")
	e.step(144); active.step(144)
	a.assert_eq(e.get_state_checksum(), active.get_state_checksum(), "active order and in-flight travel continue identically")
	a.assert_null(OperationsSession.restore({"operations_format": 1}), "incomplete file rejected safely")
	a.assert_null(OperationsSession.restore({"operations_format": 99}), "unsupported file version rejected")
	var blocked := OperationsSession.create(100)
	blocked.step(18)
	var bw := blocked.world_state
	var bc := _case(bw, "pump")
	blocked.scheduler.remove_system("daily_life")
	for pid in bw.entity_registry.get_entities_by_type("person"):
		var person := bw.entity_registry.get_entity(pid) as Person
		person.current_activity = Person.ACTIVITY_SLEEPING
	CommandAdapter.dispatch_case_action(bw, bc.id, "request_service")
	blocked.step(OperationsConfig.SERVICE_TICKS + 1)
	var inst := bw.custom_data.institution_system as InstitutionSystem
	a.assert_null(inst.get_active_order(OperationsConfig.ORDER_EARLY_SERVICE), "blocked one-day order expires without repair")
	a.assert_eq(bc.status, "ESCALATING", "expired request leaves real unresolved case escalating")
	a.assert_almost_eq(inst.get_machine_maintenance_threshold(_pump(bw).id), 60.0, 0.001, "normal threshold restored after duration")

func _test_replay_save_and_performance(a: TestAsserts) -> void:
	a.set_current_test("Operations: 1200 population deterministic replay and persistence")
	var e := OperationsSession.create()
	var replay := OperationsSession.create()
	var elapsed := 0
	var max_usec := 0
	var peak_cases := 0
	for tick in range(1000):
		for sim in [e, replay]:
			var ws: WorldState = sim.world_state
			for c in _ops(ws).cases.values():
				if c.status == "NEW" and c.pending == "":
					CommandAdapter.dispatch_case_action(ws, c.id, "request_service" if c.kind == "pump" else "publish")
		var start := Time.get_ticks_usec()
		e.step(1)
		var duration := Time.get_ticks_usec() - start
		elapsed += duration; max_usec = maxi(max_usec, duration)
		replay.step(1)
		peak_cases = maxi(peak_cases, CaseReader.brief(e.world_state).active_count)
	a.assert_eq(e.get_state_checksum(), replay.get_state_checksum(), "1000 ticks + identical player inputs replay identically")
	a.assert_lte(peak_cases, 3, "normal session stays within 0–3 open cases")
	a.assert_lt(float(elapsed) / 1000000.0, 30.0, "1200 pop operations average tick below existing 30ms interactive gate")
	# Save before a queued input executes, and with a pending information release timer.
	var info_sys := e.world_state.custom_data.information_system as InformationSystem
	var info := info_sys.create_information(e.world_state, "save_probe", "institution", 0, "review", {}, {"room_id": _pump(e.world_state).room_id})
	info_sys.delay_information(e.world_state, info.id, 36)
	e.step(1)
	var c := _case(e.world_state, "information")
	CommandAdapter.dispatch_case_action(e.world_state, c.id, "publish")
	var path := "/tmp/silo-operations-test.save"
	a.assert_eq(OperationsSession.save_file(e, path), OK, "save writes value-only typed session")
	var loaded := OperationsSession.load_file(path)
	if not a.assert_not_null(loaded, "save rehydrates supported session"): return
	a.assert_eq(e.get_state_checksum(), loaded.get_state_checksum(), "save/load preserves exact state, IDs, queued input and timers")
	e.step(144); loaded.step(144)
	a.assert_eq(e.get_state_checksum(), loaded.get_state_checksum(), "restored session continues deterministic simulation")
	a.assert_eq(OperationsSystem.find_information(loaded.world_state, info.id).disseminated_count, 1, "manual publication removes delayed duplicate")
	print("  OPERATIONS_SCALE population=1200 ticks=1000 avg_tick_ms=%.3f max_tick_ms=%.3f peak_open_cases=%d replay=PASS save_continuation=PASS" % [float(elapsed) / 1000000.0, float(max_usec) / 1000.0, peak_cases])
