# tools/sim_cli.gd
extends SceneTree

## Interactive Terminal UAT Tool for Project SILO.
## Can be run directly inside tmux, SSH sessions, or local terminal.
## Usage:
##   Interactive REPL:  godot --headless -s tools/sim_cli.gd
##   Batch Command:     godot --headless -s tools/sim_cli.gd -- status
##                      godot --headless -s tools/sim_cli.gd -- day 7 status

var engine: SimulationEngine
var ws: WorldState
var inst_sys: InstitutionSystem
var daily_life: DailyLifeSystem
var prod_sys: ProductionSystem
var maint_sys: MaintenanceSystem
var water_sys: WaterSystem
var inc_sys: IncidentSystem

func _init() -> void:
	call_deferred("_start")

func _start() -> void:
	_init_simulation(100, 42)
	
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		_execute_batch_args(user_args)
		quit(0)
		return
		
	_run_interactive_repl()
	quit(0)

func _init_simulation(population_size: int, seed_val: int) -> void:
	engine = SimulationEngine.new(seed_val)
	ws = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, population_size)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	inst_sys = InstitutionSystem.new()
	daily_life = DailyLifeSystem.new()
	prod_sys = ProductionSystem.new()
	maint_sys = MaintenanceSystem.new()
	water_sys = WaterSystem.new(50000.0, 100000.0)
	inc_sys = IncidentSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
	engine.register_system(inc_sys)

func _resolve_entity_id(entity_type: String, user_input_id: int) -> int:
	var registry: EntityRegistry = ws.entity_registry
	var all_ids: Array[int] = registry.get_entities_by_type(entity_type)
	if all_ids.is_empty():
		return 0
	if registry.has_entity(user_input_id) and registry.get_entity_type(user_input_id) == entity_type:
		return user_input_id
	if user_input_id >= 1 and user_input_id <= all_ids.size():
		return all_ids[user_input_id - 1]
	return user_input_id

func _execute_batch_args(args: PackedStringArray) -> void:
	var i: int = 0
	while i < args.size():
		var cmd: String = args[i].to_lower()
		var param: String = args[i + 1] if i + 1 < args.size() else ""
		
		if cmd == "day" or cmd == "days" or cmd == "step_days":
			var days: int = param.to_int() if param != "" and param.is_valid_int() else 1
			engine.step(days * SimClock.TICKS_PER_DAY)
			i += 2
		elif cmd == "step":
			var ticks: int = param.to_int() if param != "" and param.is_valid_int() else 1
			engine.step(ticks)
			i += 2
		elif cmd == "status" or cmd == "report":
			print(SimulationViewer.render_full_status_report(ws))
			i += 1
		elif cmd == "pop" or cmd == "population":
			print(SimulationViewer.render_population_dashboard(ws))
			i += 1
		elif cmd == "mach" or cmd == "machinery":
			print(SimulationViewer.render_machinery_dashboard(ws))
			i += 1
		elif cmd == "econ" or cmd == "economy":
			print(SimulationViewer.render_economy_dashboard(ws))
			i += 1
		elif cmd == "util" or cmd == "water":
			print(SimulationViewer.render_utilities_dashboard(ws))
			i += 1
		elif cmd == "inst" or cmd == "governance":
			print(SimulationViewer.render_institutions_dashboard(ws))
			i += 1
		elif cmd == "inc" or cmd == "incidents":
			print(SimulationViewer.render_incidents_dashboard(ws))
			i += 1
		elif cmd == "person":
			var pid: int = param.to_int() if param != "" and param.is_valid_int() else 1
			_print_person_profile(_resolve_entity_id("person", pid))
			i += 2
		elif cmd == "household":
			var hid: int = param.to_int() if param != "" and param.is_valid_int() else 1
			_print_household_profile(_resolve_entity_id("household", hid))
			i += 2
		elif cmd == "room":
			var rid: int = param.to_int() if param != "" and param.is_valid_int() else 1
			_print_room_profile(_resolve_entity_id("room", rid))
			i += 2
		elif cmd == "policy":
			if param != "":
				_enact_policy_normalized(param)
			i += 2
		elif cmd == "order":
			if param != "":
				var dur: int = 144
				var next_param: String = args[i + 2] if i + 2 < args.size() else ""
				if next_param != "" and next_param.is_valid_int():
					dur = next_param.to_int()
					i += 3
				else:
					i += 2
				_dispatch_order_normalized(param, dur)
			else:
				i += 1
		elif cmd == "cancel":
			if param != "":
				var ok: bool = CommandAdapter.cancel_order(ws, param)
				print("[ORDER] Cancel '%s': %s" % [param, "SUCCESS" if ok else "FAILED"])
			i += 2
		elif cmd == "revoke":
			if param != "":
				var ok: bool = CommandAdapter.revoke_policy(ws, param)
				print("[POLICY] Revoke '%s': %s" % [param, "SUCCESS" if ok else "FAILED"])
			i += 2
		elif cmd == "invariants" or cmd == "check":
			_run_invariants_check()
			i += 1
		elif cmd == "benchmark":
			var days: int = param.to_int() if param != "" and param.is_valid_int() else 7
			_run_benchmark(days)
			i += 2
		else:
			print("[CLI] Unknown batch argument: %s" % cmd)
			i += 1

func _run_interactive_repl() -> void:
	print("================================================================================")
	print(" PROJECT SILO — INTERACTIVE TERMINAL UAT CONSOLE")
	print(" Type 'help' for available commands, 'status' for dashboard, 'quit' to exit.")
	print("================================================================================")
	print(SimulationViewer.render_header(ws))
	print("")
	
	var consecutive_empty_reads: int = 0
	
	while true:
		print("silo> ")
		var input: String = OS.read_string_from_stdin(1024).strip_edges()
		if input == "":
			consecutive_empty_reads += 1
			if consecutive_empty_reads > 50:
				break
			continue
		consecutive_empty_reads = 0
			
		var tokens: PackedStringArray = input.split(" ", false)
		if tokens.is_empty():
			continue
			
		var cmd: String = tokens[0].to_lower()
		var arg1: String = tokens[1] if tokens.size() > 1 else ""
		var arg2: String = tokens[2] if tokens.size() > 2 else ""
		
		if cmd == "quit" or cmd == "exit" or cmd == "q":
			print("Exiting SILO UAT console. Goodbye.")
			break
		elif cmd == "help" or cmd == "?":
			_print_help()
		elif cmd == "status" or cmd == "report":
			print(SimulationViewer.render_full_status_report(ws))
		elif cmd == "header":
			print(SimulationViewer.render_header(ws))
		elif cmd == "pop" or cmd == "population":
			print(SimulationViewer.render_population_dashboard(ws))
		elif cmd == "mach" or cmd == "machinery":
			print(SimulationViewer.render_machinery_dashboard(ws))
		elif cmd == "econ" or cmd == "economy":
			print(SimulationViewer.render_economy_dashboard(ws))
		elif cmd == "util" or cmd == "water":
			print(SimulationViewer.render_utilities_dashboard(ws))
		elif cmd == "inst" or cmd == "governance":
			print(SimulationViewer.render_institutions_dashboard(ws))
		elif cmd == "inc" or cmd == "incidents":
			print(SimulationViewer.render_incidents_dashboard(ws))
		elif cmd == "person" or cmd == "citizen":
			var pid: int = arg1.to_int() if arg1.is_valid_int() else 1
			_print_person_profile(_resolve_entity_id("person", pid))
		elif cmd == "household" or cmd == "house":
			var hid: int = arg1.to_int() if arg1.is_valid_int() else 1
			_print_household_profile(_resolve_entity_id("household", hid))
		elif cmd == "room" or cmd == "zone":
			var rid: int = arg1.to_int() if arg1.is_valid_int() else 1
			_print_room_profile(_resolve_entity_id("room", rid))
		elif cmd == "policies" or (cmd == "policy" and (arg1 == "list" or arg1 == "")):
			_print_policies_list()
		elif cmd == "orders" or (cmd == "order" and (arg1 == "list" or arg1 == "")):
			_print_orders_list()
		elif cmd == "policy":
			_enact_policy_normalized(arg1)
		elif cmd == "revoke":
			if arg1 == "":
				print("Usage: revoke <category> (e.g. rationing, work_hours, maintenance, security, education)")
			else:
				var ok: bool = CommandAdapter.revoke_policy(ws, arg1)
				if ok:
					print("[POLICY] Revoked policy category '%s', restored standard baseline." % arg1)
				else:
					print("[POLICY ERROR] Failed to revoke category: %s" % arg1)
		elif cmd == "order":
			var dur: int = arg2.to_int() if arg2.is_valid_int() else 144
			_dispatch_order_normalized(arg1, dur)
		elif cmd == "cancel":
			if arg1 == "":
				print("Usage: cancel <order_id>")
			else:
				var ok: bool = CommandAdapter.cancel_order(ws, arg1)
				if ok:
					print("[ORDER] Cancelled order: %s" % arg1)
				else:
					print("[ORDER ERROR] Failed to cancel order: %s" % arg1)
		elif cmd == "step":
			var count: int = arg1.to_int() if arg1.is_valid_int() else 1
			engine.step(count)
			print("[STEP] Advanced %d tick(s). Current time: %s | Checksum: 0x%X" % [
				count, ws.sim_clock.get_formatted_time(), ws.get_state_checksum()
			])
		elif cmd == "day" or cmd == "days":
			var days: int = arg1.to_int() if arg1.is_valid_int() else 1
			var start_ms: int = Time.get_ticks_msec()
			engine.step(days * SimClock.TICKS_PER_DAY)
			var dur_ms: int = Time.get_ticks_msec() - start_ms
			print("[STEP] Advanced %d day(s) (%d ticks) in %d ms." % [days, days * SimClock.TICKS_PER_DAY, dur_ms])
			print(SimulationViewer.render_header(ws))
		elif cmd == "invariants" or cmd == "check":
			_run_invariants_check()
		elif cmd == "benchmark":
			var days: int = arg1.to_int() if arg1.is_valid_int() else 7
			_run_benchmark(days)
		elif cmd == "reset":
			var pop_size: int = arg1.to_int() if arg1.is_valid_int() else 100
			var seed_val: int = arg2.to_int() if arg2.is_valid_int() else 42
			_init_simulation(pop_size, seed_val)
			print("[RESET] Re-initialized habitat with %d population (Seed %d)." % [pop_size, seed_val])
			print(SimulationViewer.render_header(ws))
		elif cmd == "checksum":
			print("WorldState 64-bit Checksum: 0x%X (Tick: %d)" % [ws.get_state_checksum(), ws.sim_clock.get_tick()])
		else:
			print("Unknown command: '%s'. Type 'help' for command list." % cmd)
		print("")

func _enact_policy_normalized(p_id: String) -> void:
	var pol_id: String = p_id
	if inst_sys.available_policies.has(pol_id):
		var ok: bool = CommandAdapter.enact_policy(ws, pol_id)
		if ok:
			print("[POLICY] Successfully enacted policy: %s" % pol_id)
			return
	if pol_id.begins_with("policy_"):
		var trimmed: String = pol_id.trim_prefix("policy_")
		if inst_sys.available_policies.has(trimmed):
			var ok: bool = CommandAdapter.enact_policy(ws, trimmed)
			if ok:
				print("[POLICY] Successfully enacted policy: %s" % trimmed)
				return
	if not pol_id.begins_with("policy_"):
		var prefixed: String = "policy_" + pol_id
		if inst_sys.available_policies.has(prefixed):
			var ok: bool = CommandAdapter.enact_policy(ws, prefixed)
			if ok:
				print("[POLICY] Successfully enacted policy: %s" % prefixed)
				return
	print("[POLICY ERROR] Policy '%s' not recognized. Type 'policies' for list of valid policies." % p_id)

func _dispatch_order_normalized(p_type: String, duration_ticks: int) -> void:
	var ord_type: String = p_type
	if not ord_type.begins_with("order_"):
		ord_type = "order_" + ord_type
	var order: ExecutiveOrder = ExecutiveOrder.create_order(ord_type, "", duration_ticks)
	var ok: bool = CommandAdapter.dispatch_order(ws, order)
	if ok:
		print("[ORDER] Dispatched %s (%s) for %d ticks." % [ord_type, order.name, duration_ticks])
	else:
		print("[ORDER ERROR] Failed to dispatch order '%s'. Type 'orders' for valid order types." % ord_type)

func _print_policies_list() -> void:
	print("--- [ AVAILABLE INSTITUTIONAL POLICIES ] -------------------------------")
	var default_policies: Dictionary = Policy.create_default_policies()
	for pid in default_policies:
		var pol: Policy = default_policies[pid]
		var is_active: bool = false
		if inst_sys.active_policies.has(pol.category):
			var active_p: Policy = inst_sys.active_policies[pol.category]
			if active_p.id == pol.id:
				is_active = true
		print("  [%s] %-24s | Cat: %-12s | %s" % [
			"ACTIVE" if is_active else "      ",
			pol.id,
			pol.category,
			pol.name
		])

func _print_orders_list() -> void:
	print("--- [ AVAILABLE EXECUTIVE ORDERS ] -------------------------------------")
	print("  order_machine_overdrive    - Increases machine throughput (+25%), increases component wear (2.5x)")
	print("  order_water_cuts           - Cuts water ration by 50%, raises social tension (+0.5/day)")
	print("  order_overtime_surge       - Mandatory 12-hour shifts (+50% output, +50% machine wear, +tension)")
	print("  order_lockdown_sector      - Restricts sector transit to Level 3+ clearance (+0.6/day tension)")
	print("  order_conscript_labor      - Conscripts residents into emergency technician roles (+tension)")
	print("")
	print(" Active Orders:")
	if inst_sys.active_orders.is_empty():
		print("   (None)")
	else:
		for oid in inst_sys.active_orders:
			var ord: ExecutiveOrder = inst_sys.active_orders[oid]
			print("   - %s (Elapsed: %d / %d ticks)" % [ord.name, ord.ticks_elapsed, ord.duration_ticks])

func _print_household_profile(household_id: int) -> void:
	var h: Dictionary = SimulationReader.get_household_summary(ws, household_id)
	if h.is_empty():
		print("Household ID %d not found in registry." % household_id)
		return
	print("--- [ HOUSEHOLD PROFILE: ID %d ] ---------------------------------------" % household_id)
	print(" Family Designation : %s" % h["name"])
	print(" Head of Household  : %s (ID %d)" % [h["head_name"], h["head_id"]])
	print(" Home Apartment Room: Room ID %d" % h["home_room_id"])
	print(" Member Count       : %d" % h["member_count"])
	print(" Members:")
	for m in h["members"]:
		print("   - [%-7s] (ID %-3d) %-24s | Job: %s" % [
			"LIVING" if m["is_alive"] else "DEAD", m["id"], m["name"], m["occupation"]
		])

func _print_room_profile(room_id: int) -> void:
	var r: Dictionary = SimulationReader.get_room_summary(ws, room_id)
	if r.is_empty():
		print("Room ID %d not found in registry." % room_id)
		return
	print("--- [ ROOM / ZONE PROFILE: ID %d ] -------------------------------------" % room_id)
	print(" Type        : %s (Type ID: %d)" % [r["room_type_name"], r["room_type"]])
	print(" Coordinates : Sector %d, Level %d" % [r["sector_id"], r["level"]])
	print(" Capacity    : %d occupants | Beds: %d (%d occupied)" % [
		r["capacity_people"], r["bed_count"], (r["occupied_beds"] as Dictionary).size()
	])
	print(" Current Occupants: %d" % r["occupant_count"])
	for occ in r["occupants"]:
		print("   - (ID %-3d) %-24s [Activity: %d]" % [occ["id"], occ["name"], occ["activity"]])
	if r["inventory_id"] > 0:
		print(" Inventory ID %d Stocks: %s" % [r["inventory_id"], str(r["inventory_stocks"])])

func _run_invariants_check() -> void:
	print("--- [ SILO INVARIANTS HEALTH AUDIT ] -----------------------------------")
	var p_val: Dictionary = PopulationInvariants.validate(ws)
	print(" [1/6] Population & Housing Invariants : %s (Errors: %d)" % [
		"PASS" if p_val["is_valid"] else "FAIL", p_val["errors"].size()
	])
	
	var s_val: Dictionary = SocietyInvariants.validate(ws)
	print(" [2/6] Society & Genealogy Invariants  : %s (Errors: %d)" % [
		"PASS" if s_val["is_valid"] else "FAIL", s_val["errors"].size()
	])
	
	var e_val: Dictionary = EconomyInvariants.validate(ws, ProductionSystem.INITIAL_SEAM_ORE_KG)
	print(" [3/6] Material Mass Conservation      : %s (Error: %.6f kg)" % [
		"PASS" if e_val["is_valid"] else "FAIL", e_val.get("stats", {}).get("error_kg", 0.0)
	])
	
	var m_val: Dictionary = MachineryInvariants.validate(ws)
	print(" [4/6] Machinery Degradation Invariants: %s (Errors: %d)" % [
		"PASS" if m_val["is_valid"] else "FAIL", m_val["errors"].size()
	])
	
	var w_val: Dictionary = WaterInvariants.validate(ws, 50000.0, water_sys)
	print(" [5/6] Potable Water Hydrodynamics     : %s (Errors: %d)" % [
		"PASS" if w_val["is_valid"] else "FAIL", w_val["errors"].size()
	])
	
	var inc_val: Dictionary = IncidentInvariants.validate(ws)
	print(" [6/6] Systemic Incidents Correlation  : %s (Errors: %d)" % [
		"PASS" if inc_val["is_valid"] else "FAIL", inc_val["errors"].size()
	])
	
	var all_ok: bool = p_val["is_valid"] and s_val["is_valid"] and e_val["is_valid"] and m_val["is_valid"] and w_val["is_valid"] and inc_val["is_valid"]
	print(" OVERALL SYSTEM HEALTH: %s" % ["✅ ALL INVARIANTS SATISFIED" if all_ok else "❌ INVARIANT FAILURES DETECTED"])

func _run_benchmark(days: int) -> void:
	print("--- [ BENCHMARKING %d DAYS (%d TICKS) ] --------------------------------" % [days, days * SimClock.TICKS_PER_DAY])
	var total_ticks: int = days * SimClock.TICKS_PER_DAY
	var start_usec: int = Time.get_ticks_usec()
	engine.step(total_ticks)
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var elapsed_sec: float = float(elapsed_usec) / 1000000.0
	var throughput: float = float(total_ticks) / maxf(0.0001, elapsed_sec)
	var ms_per_day: float = (elapsed_sec * 1000.0) / float(days)
	
	print(" Execution Time : %.3f s (%d ms)" % [elapsed_sec, int(round(elapsed_sec * 1000.0))])
	print(" Throughput     : %.1f ticks/second" % throughput)
	print(" Performance    : %.2f ms / simulated day" % ms_per_day)
	print(" State Checksum : 0x%X" % ws.get_state_checksum())

func _print_person_profile(person_id: int) -> void:
	var prof: Dictionary = SimulationReader.get_person_profile(ws, person_id)
	if prof.is_empty():
		print("Person ID %d not found in registry." % person_id)
		return
		
	print("--- [ RESIDENT PROFILE: ID %d ] ----------------------------------------" % person_id)
	print(" Name      : %s" % prof["full_name"])
	print(" Sex/Stage : %s | Stage: %s | Age: %d years" % [
		prof["sex"], prof["life_stage"], prof["age_years"]
	])
	print(" Occupation: %s (Dept: %s, Shift: %s, Clearance: L%d)" % [
		prof["occupation_id"], prof["department_id"], prof["shift"], prof["security_clearance"]
	])
	print(" Vitals    : Hydration: %.1f%% | Health: %.1f%%" % [
		prof["hydration_percent"], prof["health_percent"]
	])
	print(" Education : %.1f pts | Seniority: Level %d (%d tenure ticks)" % [
		prof["education_score"], prof["seniority_level"], prof["tenure_ticks"]
	])
	print(" Activity  : %s | Location ID: %d | Home: Room %d" % [
		prof["activity"], prof["current_location_id"], prof["home_room_id"]
	])
	print(" Family    : Household: %d | Partner: %s | Parents: %s | Children: %s" % [
		prof["household_id"],
		str(prof["partner_id"]) if int(prof["partner_id"]) > 0 else "None",
		str(prof["parent_ids"]),
		str(prof["children_ids"])
	])

func _print_help() -> void:
	print("Available Commands:")
	print("  status / report        - Display full multi-system habitat telemetry report")
	print("  header                 - Display status header (time, population, reservoir, tension)")
	print("  pop                    - Display population, demographics, vitals & activity breakdown")
	print("  mach                   - Display machinery operating states, wear meters & repair queue")
	print("  econ                   - Display material production pipeline & stock reconciliations")
	print("  util                   - Display water reservoir hydrodynamics, pump inflow & demand")
	print("  inst                   - Display social tension, active policies & executive orders")
	print("  inc                    - Display active systemic incidents & telemetry alerts")
	print("  person <id>            - Inspect comprehensive profile of a specific resident")
	print("  household <id>         - Inspect household family members, room, and head of house")
	print("  room <id>              - Inspect specific room occupants, beds, coordinates, and stocks")
	print("  policies               - List all available institutional policies & active status")
	print("  orders                 - List all available executive order types & active orders")
	print("  step [N]               - Step simulation forward by N ticks (default: 1 tick / 10 mins)")
	print("  day [N]                - Advance simulation forward by N days (144 * N ticks)")
	print("  policy <policy_id>     - Enact institutional policy (e.g. work_extended_10h, ration_strict)")
	print("  revoke <category>      - Revoke active policy category and restore standard baseline")
	print("  order <type> [dur]     - Dispatch executive order (e.g. machine_overdrive, water_cuts)")
	print("  cancel <order_id>      - Cancel an active executive order")
	print("  invariants / check     - Run full system invariant health audit across all domains")
	print("  benchmark [days]       - Benchmark simulation throughput and execution speed")
	print("  reset [pop] [seed]     - Re-generate habitat simulation with custom population & seed")
	print("  checksum               - Print authoritative 64-bit state checksum")
	print("  help / ?               - Display this help menu")
	print("  quit / exit / q        - Exit the interactive console")
