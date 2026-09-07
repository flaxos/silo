# tools/observer_server.gd
extends SceneTree

const DEFAULT_PORT: int = 8080
const STATIC_ROOT: String = "res://src/viewer/"

const PoliticalSystem = preload("res://src/sim/politics/political_system.gd")
const PoliticalInvariants = preload("res://src/sim/politics/political_invariants.gd")
const FactionSystem = preload("res://src/sim/politics/faction_system.gd")
const FactionInvariants = preload("res://src/sim/politics/faction_invariants.gd")
const CorruptionSystem = preload("res://src/sim/politics/corruption_system.gd")
const CorruptionInvariants = preload("res://src/sim/politics/corruption_invariants.gd")
const InformationSystem = preload("res://src/sim/politics/information_system.gd")
const InformationInvariants = preload("res://src/sim/politics/information_invariants.gd")
const InformationReader = preload("res://src/presentation/information_reader.gd")
const CollectiveActionSystem = preload("res://src/sim/politics/collective_action_system.gd")
const CollectiveActionInvariants = preload("res://src/sim/politics/collective_action_invariants.gd")
const CollectiveActionReader = preload("res://src/presentation/collective_action_reader.gd")

var server: TCPServer
var port: int = DEFAULT_PORT
var engine: SimulationEngine
var ws: WorldState

var inst_sys: InstitutionSystem
var pol_sys: PoliticalSystem
var fact_sys: FactionSystem
var corr_sys: CorruptionSystem
var info_sys: InformationSystem
var action_sys: CollectiveActionSystem
var daily_life: DailyLifeSystem
var prod_sys: ProductionSystem
var maint_sys: MaintenanceSystem
var water_sys: WaterSystem
var inc_sys: IncidentSystem

# Runtime controls
var is_running: bool = false
var ticks_per_step: int = 1
var step_interval_sec: float = 0.5
var time_since_last_step: float = 0.0
var population_size: int = 1200
var sim_seed: int = 42
var spatial_reset_revision: int = 1
var spatial_cache_tick: int = -1
var spatial_snapshot_cache: Dictionary = {}
var spatial_update_cache: Dictionary = {}

var last_benchmark_result: Dictionary = {}

var bind_host: String = "0.0.0.0"

func _init() -> void:
	call_deferred("_start_server")

func _start_server() -> void:
	_parse_cmdline_args()
	_init_simulation(population_size, sim_seed)
	
	server = TCPServer.new()
	var err: Error = server.listen(port, bind_host)
	if err != OK:
		# Try fallback port if 8080 is busy
		port = 8081
		err = server.listen(port, bind_host)
		
	if err != OK:
		print("[ERROR] Failed to start HTTP server on port %d: %s" % [port, error_string(err)])
		quit(1)
		return
		
	print("==========================================================")
	print(" SILO — Observability HTTP Server Running")
	print("==========================================================")
	print(" Local URL    : http://127.0.0.1:%d/" % port)
	print("Viewer: http://127.0.0.1:%d" % port)
	print(" ZeroTier URL : http://192.168.193.11:%d/" % port)
	print(" LAN URL      : http://192.168.20.10:%d/" % port)
	print(" API Root     : http://127.0.0.1:%d/api/" % port)
	print(" Status       : Population=%d, Seed=%d, Tick=%d" % [population_size, sim_seed, ws.sim_clock.get_tick()])
	print(" Press Ctrl+C in terminal to stop.")
	print("==========================================================")

func _parse_cmdline_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		if arg == "--port" and i + 1 < args.size():
			port = args[i + 1].to_int()
			i += 2
		elif arg.begins_with("--port="):
			port = arg.substr(7).to_int()
			i += 1
		elif arg == "--pop" and i + 1 < args.size():
			population_size = args[i + 1].to_int()
			i += 2
		elif arg.begins_with("--pop="):
			population_size = arg.substr(6).to_int()
			i += 1
		elif arg == "--seed" and i + 1 < args.size():
			sim_seed = args[i + 1].to_int()
			i += 2
		elif arg.begins_with("--seed="):
			sim_seed = arg.substr(7).to_int()
			i += 1
		else:
			i += 1

func _init_simulation(pop_size: int, seed_val: int) -> void:
	population_size = pop_size
	sim_seed = seed_val
	
	engine = SimulationEngine.new(sim_seed)
	ws = engine.get_world_state()
	
	PopulationGenerator.generate_population(ws, population_size)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	
	inst_sys = InstitutionSystem.new()
	pol_sys = PoliticalSystem.new()
	fact_sys = FactionSystem.new()
	corr_sys = CorruptionSystem.new()
	info_sys = InformationSystem.new()
	action_sys = CollectiveActionSystem.new()
	daily_life = DailyLifeSystem.new()
	prod_sys = ProductionSystem.new()
	maint_sys = MaintenanceSystem.new()
	water_sys = WaterSystem.new(50000.0, 100000.0)
	inc_sys = IncidentSystem.new()
	
	engine.register_system(inst_sys)
	engine.register_system(pol_sys)
	engine.register_system(fact_sys)
	engine.register_system(corr_sys)
	engine.register_system(info_sys)
	engine.register_system(action_sys)
	engine.register_system(daily_life)
	engine.register_system(maint_sys)
	engine.register_system(prod_sys)
	engine.register_system(water_sys)
	engine.register_system(inc_sys)

func _process(delta: float) -> bool:
	if not server:
		return false
		
	# Handle simulation auto-stepping
	if is_running:
		time_since_last_step += delta
		if time_since_last_step >= step_interval_sec:
			time_since_last_step = 0.0
			engine.step(ticks_per_step)
			
	# Accept incoming TCP connections
	while server.is_connection_available():
		var peer: StreamPeerTCP = server.take_connection()
		if peer:
			_handle_client(peer)
			
	return false

func _handle_client(peer: StreamPeerTCP) -> void:
	# Give peer a moment to send data if needed
	var timeout: int = 50
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() == 0 and timeout > 0:
		OS.delay_msec(2)
		timeout -= 1
		peer.poll()
		
	var bytes_avail: int = peer.get_available_bytes()
	if bytes_avail <= 0:
		peer.disconnect_from_host()
		return
		
	var raw_request: String = peer.get_utf8_string(bytes_avail)
	if raw_request.is_empty():
		peer.disconnect_from_host()
		return
		
	var lines: PackedStringArray = raw_request.split("\r\n")
	if lines.is_empty() or lines[0].is_empty():
		lines = raw_request.split("\n")
	if lines.is_empty():
		peer.disconnect_from_host()
		return
		
	var req_line: PackedStringArray = lines[0].split(" ")
	if req_line.size() < 2:
		peer.disconnect_from_host()
		return
		
	var method: String = req_line[0].to_upper()
	var full_path: String = req_line[1]
	
	# Parse body if present (for POST requests)
	var body_str: String = ""
	var header_body_split: int = raw_request.find("\r\n\r\n")
	if header_body_split != -1:
		body_str = raw_request.substr(header_body_split + 4)
	else:
		var lf_split: int = raw_request.find("\n\n")
		if lf_split != -1:
			body_str = raw_request.substr(lf_split + 2)
			
	var json_body: Variant = null
	if not body_str.is_empty():
		var json: JSON = JSON.new()
		if json.parse(body_str) == OK:
			json_body = json.data
			
	# Handle CORS preflight
	if method == "OPTIONS":
		_send_cors_response(peer)
		return
		
	# Route request
	if full_path.begins_with("/api/"):
		_handle_api_request(peer, method, full_path, json_body)
	else:
		_handle_static_request(peer, full_path)
		
	peer.disconnect_from_host()

func _handle_static_request(peer: StreamPeerTCP, full_path: String) -> void:
	var path_clean: String = full_path.split("?")[0]
	if path_clean == "/" or path_clean == "":
		path_clean = "/index.html"
		
	var file_path: String = STATIC_ROOT + path_clean.substr(1)
	if not FileAccess.file_exists(file_path):
		_send_error(peer, 404, "File not found: " + path_clean)
		return
		
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		_send_error(peer, 500, "Cannot read file: " + path_clean)
		return
		
	var content: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	var mime_type: String = "text/plain"
	if path_clean.ends_with(".html"):
		mime_type = "text/html; charset=utf-8"
	elif path_clean.ends_with(".css"):
		mime_type = "text/css; charset=utf-8"
	elif path_clean.ends_with(".js"):
		mime_type = "application/javascript; charset=utf-8"
	elif path_clean.ends_with(".json"):
		mime_type = "application/json"
	elif path_clean.ends_with(".ico"):
		mime_type = "image/x-icon"
		
	var headers: String = "HTTP/1.1 200 OK\r\n"
	headers += "Content-Type: %s\r\n" % mime_type
	headers += "Content-Length: %d\r\n" % content.size()
	headers += "Access-Control-Allow-Origin: *\r\n"
	headers += "Cache-Control: no-cache\r\n"
	headers += "Connection: close\r\n\r\n"
	
	peer.put_data(headers.to_utf8_buffer())
	peer.put_data(content)

func _handle_api_request(peer: StreamPeerTCP, method: String, full_path: String, body: Variant) -> void:
	var path_parts: PackedStringArray = full_path.split("?")
	var api_path: String = path_parts[0]
	var query_params: Dictionary = {}
	if path_parts.size() > 1:
		query_params = _parse_query_params(path_parts[1])
		
	var response_data: Variant = null
	var status_code: int = 200
	
	match [method, api_path]:
		["GET", "/api/overview"]:
			var snapshot: Dictionary = SimulationReader.get_full_telemetry_snapshot(ws)
			snapshot["engine"] = {
				"is_running": is_running,
				"ticks_per_step": ticks_per_step,
				"step_interval_sec": step_interval_sec,
				"population_size": population_size,
				"seed": sim_seed
			}
			response_data = snapshot

		["GET", "/api/spatial"], ["GET", "/api/physical_snapshot"]:
			if spatial_snapshot_cache.is_empty():
				spatial_snapshot_cache = PhysicalReader.get_snapshot(ws, spatial_reset_revision)
			response_data = spatial_snapshot_cache

		["GET", "/api/spatial_updates"], ["GET", "/api/physical_delta"]:
			var since: int = int(query_params.get("since", -1))
			var current_tick: int = ws.sim_clock.get_tick()
			if spatial_cache_tick != current_tick:
				spatial_cache_tick = current_tick
				spatial_update_cache = PhysicalReader.get_updates(ws, current_tick - 1, spatial_reset_revision)
			if since >= current_tick:
				response_data = PhysicalReader.get_updates(ws, current_tick, spatial_reset_revision)
			else:
				response_data = spatial_update_cache

		["GET", "/api/spatial_entity"], ["GET", "/api/physical_entity"]:
			var entity_type: String = str(query_params.get("type", ""))
			var entity_id: String = str(query_params.get("id", ""))
			response_data = PhysicalReader.resolve_entity(ws, entity_type, entity_id)
			if response_data.is_empty():
				status_code = 404
				response_data = {"error": "Spatial entity not found"}

		["GET", "/api/physical_search"]:
			response_data = PhysicalReader.search(ws, str(query_params.get("q", "")), int(query_params.get("limit", 30)))
			
		["GET", "/api/people"]:
			var page: int = int(query_params.get("page", 1))
			var limit: int = int(query_params.get("limit", 50))
			var search: String = str(query_params.get("search", ""))
			var stage: String = str(query_params.get("stage", ""))
			var job: String = str(query_params.get("job", ""))
			var status: String = str(query_params.get("status", ""))
			response_data = SimulationReader.get_people_list(ws, page, limit, search, stage, job, status)
			
		["GET", "/api/person"]:
			var pid: int = int(query_params.get("id", 0))
			if pid <= 0:
				status_code = 400
				response_data = {"error": "Missing or invalid 'id' parameter"}
			else:
				var profile: Dictionary = SimulationReader.get_person_profile(ws, pid)
				if profile.is_empty():
					status_code = 404
					response_data = {"error": "Person ID %d not found" % pid}
				else:
					response_data = profile
					
		["GET", "/api/households"]:
			response_data = {"households": SimulationReader.get_households_list(ws)}
			
		["GET", "/api/household"]:
			var hid: int = int(query_params.get("id", 0))
			if hid <= 0:
				status_code = 400
				response_data = {"error": "Missing or invalid 'id' parameter"}
			else:
				var h_sum: Dictionary = SimulationReader.get_household_summary(ws, hid)
				if h_sum.is_empty():
					status_code = 404
					response_data = {"error": "Household ID %d not found" % hid}
				else:
					response_data = h_sum
					
		["GET", "/api/locations"]:
			response_data = SimulationReader.get_locations_hierarchy(ws)
			
		["GET", "/api/room"]:
			var rid: int = int(query_params.get("id", 0))
			if rid <= 0:
				status_code = 400
				response_data = {"error": "Missing or invalid 'id' parameter"}
			else:
				var r_sum: Dictionary = SimulationReader.get_room_summary(ws, rid)
				if r_sum.is_empty():
					status_code = 404
					response_data = {"error": "Room ID %d not found" % rid}
				else:
					response_data = r_sum
					
		["GET", "/api/labour"]:
			response_data = SimulationReader.get_labour_summary(ws)
			
		["GET", "/api/economy"]:
			response_data = SimulationReader.get_economy_summary(ws)
			
		["GET", "/api/machinery"]:
			response_data = SimulationReader.get_machinery_summary(ws)
			
		["GET", "/api/machine"], ["GET", "/api/causal_chain"]:
			var mid: int = int(query_params.get("id", query_params.get("machine_id", 0)))
			response_data = SimulationReader.get_causal_chain(ws, mid)
			
		["GET", "/api/utilities"]:
			response_data = SimulationReader.get_utilities_summary(ws)
			
		["GET", "/api/institutions"]:
			response_data = SimulationReader.get_institutions_summary(ws)
			
		["GET", "/api/politics"]:
			response_data = SimulationReader.get_political_summary(ws)
			
		["GET", "/api/factions"]:
			response_data = SimulationReader.get_factions_summary(ws)
			
		["GET", "/api/faction_detail"]:
			var fid: int = int(query_params.get("id", 0))
			if fid <= 0:
				status_code = 400
				response_data = {"error": "Missing or invalid 'id' parameter"}
			else:
				var fdetail: Dictionary = SimulationReader.get_faction_detail(ws, fid)
				if fdetail.is_empty():
					status_code = 404
					response_data = {"error": "Faction ID %d not found" % fid}
				else:
					response_data = fdetail
					
		["GET", "/api/corruption"]:
			response_data = SimulationReader.get_corruption_summary(ws)
			
		["GET", "/api/patronage_network"]:
			response_data = SimulationReader.get_patronage_network(ws)
			
		["GET", "/api/audit_log"]:
			response_data = SimulationReader.get_audit_log(ws)
			
		["GET", "/api/information"]:
			response_data = InformationReader.get_information_summary(ws)
			
		["GET", "/api/competing_narratives"]:
			var ev_id: String = str(query_params.get("event_id", ""))
			response_data = InformationReader.get_competing_narratives(ws, ev_id)
			
		["GET", "/api/censorship_log"]:
			response_data = {"censorship_audit_log": InformationReader.get_censorship_log(ws)}
			
		["GET", "/api/collective_actions"]:
			response_data = CollectiveActionReader.get_collective_action_summary(ws)
			
		["GET", "/api/active_strikes"]:
			response_data = {"actions": CollectiveActionReader.get_active_actions(ws)}
			
		["GET", "/api/sabotage_reports"]:
			response_data = {"sabotage_incidents": CollectiveActionReader.get_sabotage_log(ws)}
			
		["GET", "/api/illicit_trace"]:
			var aid: int = int(query_params.get("id", query_params.get("action_id", 0)))
			if aid <= 0:
				status_code = 400
				response_data = {"error": "Missing or invalid 'id' parameter"}
			else:
				var trace: Dictionary = SimulationReader.get_illicit_action_trace(ws, aid)
				if trace.is_empty():
					status_code = 404
					response_data = {"error": "Illicit action ID %d not found" % aid}
				else:
					response_data = trace
					
		["GET", "/api/social_network"]:
			var pid: int = int(query_params.get("id", 0))
			if pid <= 0:
				status_code = 400
				response_data = {"error": "Missing or invalid 'id' parameter"}
			else:
				var snet: Dictionary = SimulationReader.get_person_social_network(ws, pid)
				if snet.is_empty():
					status_code = 404
					response_data = {"error": "Person ID %d not found" % pid}
				else:
					response_data = snet
			
		["GET", "/api/person_politics"]:
			var pid: int = int(query_params.get("id", 0))
			if pid <= 0:
				status_code = 400
				response_data = {"error": "Missing or invalid 'id' parameter"}
			else:
				var prof: Dictionary = SimulationReader.get_person_political_profile(ws, pid)
				if prof.is_empty():
					status_code = 404
					response_data = {"error": "Person ID %d not found" % pid}
				else:
					response_data = prof
			
		["GET", "/api/incidents"]:
			response_data = SimulationReader.get_incidents_summary(ws)
			
		["GET", "/api/timeline"]:
			response_data = {"events": SimulationReader.get_timeline_events(ws)}
			
		["GET", "/api/dependencies"]:
			response_data = {
				"causal_chain": SimulationReader.get_causal_chain(ws, 0),
				"utilities": SimulationReader.get_utilities_summary(ws),
				"economy": SimulationReader.get_economy_summary(ws),
				"machinery": SimulationReader.get_machinery_summary(ws)
			}
			
		["GET", "/api/wiring"]:
			response_data = {"wiring_matrix": SimulationReader.get_wiring_matrix(ws)}
			
		["GET", "/api/invariants"], ["POST", "/api/validate"]:
			var validator: PopulationInvariants = PopulationInvariants.new()
			var pop_val: Dictionary = validator.validate_world_invariants(ws)
			var pol_val: Dictionary = PoliticalInvariants.validate_all(ws)
			var fact_val: Dictionary = FactionInvariants.validate_all(ws)
			var corr_val: Dictionary = CorruptionInvariants.validate_all(ws)
			var info_val: Dictionary = InformationInvariants.validate_all(ws)
			var action_val: Dictionary = CollectiveActionInvariants.validate_all(ws)
			var econ_sum: Dictionary = SimulationReader.get_economy_summary(ws)
			var mach_sum: Dictionary = SimulationReader.get_machinery_summary(ws)
			
			var all_ok: bool = pop_val.get("is_valid", true) and pol_val.get("is_valid", true) and fact_val.get("is_valid", true) and corr_val.get("is_valid", true) and info_val.get("is_valid", true) and action_val.get("is_valid", true) and econ_sum["mass_balance_error_kg"] < 0.001
			response_data = {
				"is_valid": all_ok,
				"checksum": ws.get_state_checksum(),
				"population_validation": pop_val,
				"political_validation": pol_val,
				"faction_validation": fact_val,
				"corruption_validation": corr_val,
				"information_validation": info_val,
				"collective_action_validation": action_val,
				"mass_balance": {
					"total_mass_kg": econ_sum["total_system_mass_kg"],
					"seam_ore_kg": econ_sum["seam_ore_kg"],
					"inventory_mass_kg": econ_sum["inventory_mass_kg"],
					"installed_mass_kg": econ_sum["installed_maintenance_mass_kg"],
					"error_kg": econ_sum["mass_balance_error_kg"],
					"is_conserved": econ_sum["mass_balance_error_kg"] < 0.001
				},
				"machinery_integrity": {
					"total_machines": mach_sum["total_machines"],
					"states": mach_sum["states"]
				}
			}
			
		["GET", "/api/performance"]:
			response_data = SimulationReader.get_performance_metrics(ws, last_benchmark_result)
			
		["GET", "/api/raw"]:
			var raw_type: String = str(query_params.get("type", "world"))
			var raw_id: int = int(query_params.get("id", 0))
			response_data = SimulationReader.get_raw_entity_state(ws, raw_type, raw_id)
			
		["POST", "/api/step"]:
			var ticks_to_step: int = 1
			if body is Dictionary and body.has("ticks"):
				ticks_to_step = int(body["ticks"])
			elif query_params.has("ticks"):
				ticks_to_step = int(query_params["ticks"])
				
			var t_start: int = Time.get_ticks_usec()
			engine.step(ticks_to_step)
			var t_elapsed_usec: int = Time.get_ticks_usec() - t_start
			
			last_benchmark_result = {
				"ticks_stepped": ticks_to_step,
				"duration_usec": t_elapsed_usec,
				"duration_ms": float(t_elapsed_usec) / 1000.0,
				"usec_per_tick": float(t_elapsed_usec) / float(maxi(1, ticks_to_step)),
				"ticks_per_sec": (float(ticks_to_step) / (float(t_elapsed_usec) / 1000000.0)) if t_elapsed_usec > 0 else 0.0
			}
			
			response_data = {
				"success": true,
				"stepped_ticks": ticks_to_step,
				"current_tick": ws.sim_clock.get_tick(),
				"formatted_time": ws.sim_clock.get_formatted_time(),
				"checksum": ws.get_state_checksum(),
				"benchmark": last_benchmark_result
			}
			
		["POST", "/api/pause"]:
			is_running = false
			response_data = {"success": true, "is_running": is_running}
			
		["POST", "/api/resume"]:
			is_running = true
			response_data = {"success": true, "is_running": is_running}
			
		["POST", "/api/speed"]:
			if body is Dictionary:
				if body.has("ticks_per_step"):
					ticks_per_step = maxi(1, int(body["ticks_per_step"]))
				if body.has("interval_sec"):
					step_interval_sec = maxf(0.01, float(body["interval_sec"]))
			elif query_params.has("ticks_per_step"):
				ticks_per_step = maxi(1, int(query_params["ticks_per_step"]))
				
			response_data = {
				"success": true,
				"ticks_per_step": ticks_per_step,
				"interval_sec": step_interval_sec
			}
			
		["POST", "/api/policy/enact"]:
			var pol_id: String = ""
			if body is Dictionary and body.has("policy_id"):
				pol_id = str(body["policy_id"])
			elif query_params.has("policy_id"):
				pol_id = str(query_params["policy_id"])
				
			var success: bool = CommandAdapter.enact_policy(ws, pol_id)
			response_data = {
				"success": success,
				"policy_id": pol_id,
				"institutions": SimulationReader.get_institutions_summary(ws)
			}
			
		["POST", "/api/policy/revoke"]:
			var cat: String = ""
			if body is Dictionary and body.has("category"):
				cat = str(body["category"])
			elif query_params.has("category"):
				cat = str(query_params["category"])
				
			var success: bool = CommandAdapter.revoke_policy(ws, cat)
			response_data = {
				"success": success,
				"category": cat,
				"institutions": SimulationReader.get_institutions_summary(ws)
			}
			
		["POST", "/api/order/issue"]:
			var ord_id: String = ""
			var dept: String = ""
			var target: String = ""
			var duration: int = 144
			
			if body is Dictionary:
				ord_id = str(body.get("order_id", "emergency_maintenance"))
				dept = str(body.get("department", "engineering"))
				target = str(body.get("target", "all"))
				duration = int(body.get("duration_ticks", 144))
			elif query_params.has("order_id"):
				ord_id = str(query_params["order_id"])
				dept = str(query_params.get("department", "engineering"))
				target = str(query_params.get("target", "all"))
				duration = int(query_params.get("duration_ticks", 144))
				
			var order: ExecutiveOrder = ExecutiveOrder.new(ord_id, ord_id, "Executive Order: " + ord_id.capitalize(), dept, target, duration)
			var success: bool = CommandAdapter.dispatch_order(ws, order)
			response_data = {
				"success": success,
				"order_id": ord_id,
				"institutions": SimulationReader.get_institutions_summary(ws)
			}
			
		["POST", "/api/order/cancel"]:
			var ord_id: String = ""
			if body is Dictionary and body.has("order_id"):
				ord_id = str(body["order_id"])
			elif query_params.has("order_id"):
				ord_id = str(query_params["order_id"])
				
			var success: bool = CommandAdapter.cancel_order(ws, ord_id)
			response_data = {
				"success": success,
				"order_id": ord_id,
				"institutions": SimulationReader.get_institutions_summary(ws)
			}
			
		["POST", "/api/reset"]:
			var pop_sz: int = population_size
			var seed_v: int = sim_seed
			if body is Dictionary:
				if body.has("population"):
					pop_sz = int(body["population"])
				if body.has("seed"):
					seed_v = int(body["seed"])
			elif query_params.has("population"):
				pop_sz = int(query_params["population"])
				
			_init_simulation(pop_sz, seed_v)
			spatial_reset_revision += 1
			spatial_cache_tick = -1
			spatial_snapshot_cache.clear()
			spatial_update_cache.clear()
			response_data = {
				"success": true,
				"population": population_size,
				"seed": sim_seed,
				"current_tick": ws.sim_clock.get_tick(),
				"checksum": ws.get_state_checksum()
			}
			
		_:
			status_code = 404
			response_data = {"error": "API route not found: %s %s" % [method, api_path]}

	_send_json_response(peer, status_code, response_data)

func _parse_query_params(query_string: String) -> Dictionary:
	var result: Dictionary = {}
	var pairs: PackedStringArray = query_string.split("&")
	for pair in pairs:
		var kv: PackedStringArray = pair.split("=")
		if kv.size() == 2:
			var key: String = kv[0].uri_decode()
			var val: String = kv[1].uri_decode()
			result[key] = val
		elif kv.size() == 1 and not kv[0].is_empty():
			result[kv[0].uri_decode()] = "true"
	return result

func _send_json_response(peer: StreamPeerTCP, status_code: int, data: Variant) -> void:
	var json_str: String = JSON.stringify(data)
	var content_bytes: PackedByteArray = json_str.to_utf8_buffer()
	
	var status_text: String = "200 OK"
	match status_code:
		200: status_text = "200 OK"
		201: status_text = "201 Created"
		400: status_text = "400 Bad Request"
		404: status_text = "404 Not Found"
		405: status_text = "405 Method Not Allowed"
		500: status_text = "500 Internal Server Error"
		
	var headers: String = "HTTP/1.1 %s\r\n" % status_text
	headers += "Content-Type: application/json; charset=utf-8\r\n"
	headers += "Content-Length: %d\r\n" % content_bytes.size()
	headers += "Access-Control-Allow-Origin: *\r\n"
	headers += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	headers += "Access-Control-Allow-Headers: Content-Type\r\n"
	headers += "Cache-Control: no-cache\r\n"
	headers += "Connection: close\r\n\r\n"
	
	peer.put_data(headers.to_utf8_buffer())
	peer.put_data(content_bytes)

func _send_cors_response(peer: StreamPeerTCP) -> void:
	var headers: String = "HTTP/1.1 204 No Content\r\n"
	headers += "Access-Control-Allow-Origin: *\r\n"
	headers += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	headers += "Access-Control-Allow-Headers: Content-Type\r\n"
	headers += "Access-Control-Max-Age: 86400\r\n"
	headers += "Connection: close\r\n\r\n"
	peer.put_data(headers.to_utf8_buffer())

func _send_error(peer: StreamPeerTCP, status_code: int, message: String) -> void:
	_send_json_response(peer, status_code, {"error": message, "status": status_code})
