# src/sim/politics/corruption_system.gd
class_name CorruptionSystem
extends BaseSystem

## Authoritative simulation system for informal power, corrupt favours,
## mass-conserving resource diversions, record discrepancies, auditing, and whistleblowing.

const SYSTEM_ID: String = "corruption_system"
const EXECUTION_ORDER: int = 37 # Runs after FactionSystem (36) and before Demographics (40) / DailyLife (50)

var audit_interval_ticks: int = 144 # Evaluated daily
var last_evaluation_tick: int = 0
var audit_rigour: float = 0.6       # Base audit detection rigour (0.0 to 1.0)

func _init() -> void:
	super._init(SYSTEM_ID, EXECUTION_ORDER)

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws:
		return
		
	if not ws.custom_data.has("favours"):
		ws.custom_data["favours"] = []
	if not ws.custom_data.has("illicit_actions"):
		ws.custom_data["illicit_actions"] = []
	if not ws.custom_data.has("official_inventory_ledgers"):
		ws.custom_data["official_inventory_ledgers"] = {}
		
	_initialize_official_ledgers(ws)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws or not ws.sim_clock:
		return
		
	var current_tick: int = ws.sim_clock.get_tick()
	if current_tick % audit_interval_ticks != 0:
		return
		
	last_evaluation_tick = current_tick
	
	# 1. Evaluate temptation and organic illicit actions
	_evaluate_illicit_actions(ws, current_tick)
	
	# 2. Evaluate audits and whistleblower detection
	_evaluate_audits_and_whistleblowers(ws, current_tick)
	
	# 3. Process disciplinary sanctions and record reconciliation
	_process_sanctions(ws, current_tick)

func _initialize_official_ledgers(ws: WorldState) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	var room_ids: Array[int] = registry.get_entities_by_type("room")
	
	for rid in room_ids:
		var room: Room = registry.get_entity(rid) as Room
		if not room:
			continue
		if not ledgers.has(rid):
			ledgers[rid] = {}
		if room.inventory_id > 0:
			var inv: Inventory = registry.get_entity(room.inventory_id) as Inventory
			if inv:
				for res_id in inv.stocks.keys():
					ledgers[rid][res_id] = float(inv.stocks[res_id])
					
	ws.custom_data["official_inventory_ledgers"] = ledgers

func _evaluate_illicit_actions(ws: WorldState, current_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	var rng: SeededRandom = ws.rng
	
	for pid in pids:
		var person: Person = registry.get_entity(pid) as Person
		if not person or not person.is_alive or person.life_stage != Person.STAGE_ADULT:
			continue
			
		# Check if corruptible (only evaluate officials or workers with inventory access)
		if person.workplace_room_id <= 0 and person.security_clearance < 1:
			continue
			
		var temptation: float = PatronageNetwork.calculate_corruption_temptation(ws, person.id)
		if temptation < 0.65:
			continue
			
		# Check for viable beneficiary among close social ties (family or faction comrades)
		var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, person.id)
		var target_ben: Person = null
		for conn in connections:
			var ben_id: int = int(conn.get("target_id", 0))
			var ben_candidate: Person = registry.get_entity(ben_id) as Person
			if ben_candidate and ben_candidate.is_alive and ben_candidate.id != person.id:
				if ben_candidate.economic_satisfaction < 0.4 or ben_candidate.is_severely_dehydrated():
					target_ben = ben_candidate
					break
				elif str(conn.get("relation_type", "")) == SocialGraph.RELATION_FAMILY:
					target_ben = ben_candidate
					break
					
		if not target_ben:
			continue
			
		# Attempt physical resource diversion if workplace has stock
		if person.workplace_room_id > 0 and target_ben.home_room_id > 0:
			var work_room: Room = registry.get_entity(person.workplace_room_id) as Room
			var home_room: Room = registry.get_entity(target_ben.home_room_id) as Room
			if work_room and home_room and work_room.inventory_id > 0 and home_room.inventory_id > 0:
				var work_inv: Inventory = registry.get_entity(work_room.inventory_id) as Inventory
				var home_inv: Inventory = registry.get_entity(home_room.inventory_id) as Inventory
				if work_inv and home_inv:
					# Check available spare resources to divert
					var divert_res: String = ""
					for r_id in work_inv.stocks.keys():
						if float(work_inv.stocks[r_id]) >= 2.0:
							divert_res = r_id
							break
							
					if divert_res != "":
						var divert_qty: float = minf(2.0, float(work_inv.stocks[divert_res]))
						var concealment: float = clampf(0.5 + (person.education_score / 200.0) + (float(person.tenure_ticks) / 50000.0), 0.4, 0.95)
						execute_resource_diversion(
							ws,
							person.id,
							target_ben.id,
							work_room.id,
							home_room.id,
							divert_res,
							divert_qty,
							concealment
						)

func execute_resource_diversion(
	ws: WorldState,
	perp_id: int,
	ben_id: int,
	source_room_id: int,
	dest_room_id: int,
	res_id: String,
	amount: float,
	concealment: float = 0.8
) -> IllicitAction:
	var registry: EntityRegistry = ws.entity_registry
	var perp: Person = registry.get_entity(perp_id) as Person
	var ben: Person = registry.get_entity(ben_id) as Person
	var src_room: Room = registry.get_entity(source_room_id) as Room
	var dst_room: Room = registry.get_entity(dest_room_id) as Room
	
	if not perp or not ben or not src_room or not dst_room or amount <= 0.0:
		return null
		
	var src_inv: Inventory = registry.get_entity(src_room.inventory_id) as Inventory
	var dst_inv: Inventory = registry.get_entity(dst_room.inventory_id) as Inventory
	if not src_inv or not dst_inv:
		return null
		
	# Physical transfer (preserves 100% mass conservation)
	var removed: float = src_inv.remove_resource(res_id, amount)
	if removed <= 0.0:
		return null
	dst_inv.add_resource(res_id, removed)
	
	# Record discrepancy: Official ledger remains at old higher stock amount
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	if not ledgers.has(source_room_id):
		ledgers[source_room_id] = {}
	if not ledgers[source_room_id].has(res_id):
		ledgers[source_room_id][res_id] = src_inv.get_stock(res_id) + removed
	var official_recorded: float = float(ledgers[source_room_id][res_id])
	var physical_actual: float = src_inv.get_stock(res_id)
	var discrepancy: float = absf(official_recorded - physical_actual)
	
	# Create Favour debt
	var favours: Array = ws.custom_data.get("favours", [])
	var favour_id: int = favours.size() + 1
	var favour: Favour = Favour.new(
		favour_id,
		perp.id,
		ben.id,
		ws.sim_clock.get_tick(),
		Favour.FAVOUR_RESOURCE_DIVERSION,
		clampf(amount / 5.0, 0.3, 1.0),
		"Diverted %s (%.1f kg) to home storage" % [res_id, removed]
	)
	favours.append(favour)
	ws.custom_data["favours"] = favours
	
	# Create Illicit Action
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	var action_id: int = actions.size() + 1
	var action: IllicitAction = IllicitAction.new(
		action_id,
		ws.sim_clock.get_tick(),
		perp.id,
		ben.id,
		IllicitAction.ACTION_DIVERSION_STOCK
	)
	action.target_resource = res_id
	action.target_amount = removed
	action.source_room_id = source_room_id
	action.destination_room_id = dest_room_id
	action.official_record_amount = official_recorded
	action.physical_actual_amount = physical_actual
	action.discrepancy_amount = discrepancy
	action.concealment_level = clampf(concealment, 0.1, 0.99)
	action.discovery_status = IllicitAction.STATUS_CONCEALED
	action.favour_id = favour_id
	action.description = "%s diverted %.1f units of %s from Room %d to Room %d for %s" % [
		perp.get_full_name(), removed, res_id, source_room_id, dest_room_id, ben.get_full_name()
	]
	
	actions.append(action)
	ws.custom_data["illicit_actions"] = actions
	
	# Beneficiary emotional response
	ben.record_opinion_memory(
		PoliticalEvent.EVENT_FAVOUR_GRANTED,
		ws.sim_clock.get_tick(),
		PoliticalEvent.DEPT_ADMINISTRATION,
		0.4,
		"Received illicit aid from %s" % perp.get_full_name(),
		perp.id
	)
	
	return action

func _evaluate_audits_and_whistleblowers(ws: WorldState, current_tick: int) -> void:
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	var registry: EntityRegistry = ws.entity_registry
	var rng: SeededRandom = ws.rng
	
	for a_item in actions:
		var action: IllicitAction = a_item as IllicitAction
		if not action or action.discovery_status != IllicitAction.STATUS_CONCEALED:
			continue
			
		var perp: Person = registry.get_entity(action.perpetrator_id) as Person
		if not perp:
			continue
			
		var is_discovered: bool = false
		var discoverer_id: int = 0
		var evidence: float = 0.0
		
		# 1. Whistleblower discovery via social graph (coworkers or neighbors)
		var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, perp.id)
		for conn in connections:
			var conn_id: int = int(conn.get("target_id", 0))
			var conn_person: Person = registry.get_entity(conn_id) as Person
			if not conn_person or not conn_person.is_alive or conn_id == action.beneficiary_id:
				continue
				
			# Whistleblower trigger: High institutional trust, or rival faction member with grudge
			var is_honest: bool = (conn_person.institutional_trust >= 0.65 and conn_person.perceived_fairness >= 0.5)
			var is_rival: bool = (conn_person.faction_id > 0 and perp.faction_id > 0 and conn_person.faction_id != perp.faction_id)
			
			if is_honest or is_rival:
				var detection_chance: float = (1.0 - action.concealment_level) * 0.8
				if action.discrepancy_amount > 3.0:
					detection_chance += 0.2
				if rng.randf() < detection_chance:
					is_discovered = true
					discoverer_id = conn_person.id
					evidence = clampf(0.6 + (1.0 - action.concealment_level) * 0.4, 0.5, 1.0)
					break
					
		# 2. Routine institutional audit check
		if not is_discovered:
			var audit_chance: float = (1.0 - action.concealment_level) * audit_rigour * 0.5
			if rng.randf() < audit_chance:
				is_discovered = true
				discoverer_id = 0 # Official Security / Audit Dept
				evidence = clampf(0.7 + audit_rigour * 0.3, 0.6, 1.0)
				
		if is_discovered:
			action.discovery_status = IllicitAction.STATUS_EXPOSED
			action.discovered_tick = current_tick
			action.discoverer_id = discoverer_id
			action.evidence_strength = evidence

func _process_sanctions(ws: WorldState, current_tick: int) -> void:
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	var registry: EntityRegistry = ws.entity_registry
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	
	for a_item in actions:
		var action: IllicitAction = a_item as IllicitAction
		if not action or action.discovery_status != IllicitAction.STATUS_EXPOSED:
			continue
			
		var perp: Person = registry.get_entity(action.perpetrator_id) as Person
		if perp and perp.is_alive:
			# Apply institutional sanctions
			if perp.security_clearance > 0:
				perp.security_clearance -= 1
				action.penalty_applied = "clearance_revoked"
			else:
				action.penalty_applied = "formal_reprimand"
				
			perp.record_opinion_memory(
				PoliticalEvent.EVENT_DISCIPLINARY_SANCTION,
				current_tick,
				PoliticalEvent.DEPT_SECURITY,
				-0.6,
				"Sanctioned for corruption and illicit resource diversion"
			)
			
		var ben: Person = registry.get_entity(action.beneficiary_id) as Person
		if ben and ben.is_alive:
			ben.record_opinion_memory(
				PoliticalEvent.EVENT_CORRUPTION_DISCOVERED,
				current_tick,
				PoliticalEvent.DEPT_SECURITY,
				-0.4,
				"Benefited from exposed illicit diversion"
			)
			
		# Reconcile official inventory ledger to match physical truth
		if action.source_room_id > 0 and action.target_resource != "":
			var src_room: Room = registry.get_entity(action.source_room_id) as Room
			if src_room and src_room.inventory_id > 0:
				var src_inv: Inventory = registry.get_entity(src_room.inventory_id) as Inventory
				if src_inv:
					if not ledgers.has(action.source_room_id):
						ledgers[action.source_room_id] = {}
					ledgers[action.source_room_id][action.target_resource] = src_inv.get_stock(action.target_resource)
					
		action.discovery_status = IllicitAction.STATUS_SANCTIONED

func perform_manual_audit(ws: WorldState, auditor_id: int, target_room_id: int) -> Array[IllicitAction]:
	var exposed: Array[IllicitAction] = []
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	var registry: EntityRegistry = ws.entity_registry
	var current_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	
	for a_item in actions:
		var act: IllicitAction = a_item as IllicitAction
		if act and act.source_room_id == target_room_id and act.discovery_status == IllicitAction.STATUS_CONCEALED:
			act.discovery_status = IllicitAction.STATUS_EXPOSED
			act.discovered_tick = current_tick
			act.discoverer_id = auditor_id
			act.evidence_strength = 0.95
			exposed.append(act)
			
	_process_sanctions(ws, current_tick)
	return exposed

func settle_favour(ws: WorldState, favour_id: int, tick: int = -1) -> bool:
	var favours: Array = ws.custom_data.get("favours", [])
	var actual_tick: int = tick if tick >= 0 else (ws.sim_clock.get_tick() if ws.sim_clock else 0)
	for f_item in favours:
		var f: Favour = f_item as Favour
		if f and f.id == favour_id and not f.is_settled:
			f.settle(actual_tick)
			return true
	return false

## Create a favour between two citizens directly (external API for tests and commands)
func grant_favour(ws: WorldState, granter_id: int, recipient_id: int, favour_type: String, obligation_value: float) -> int:
	var registry: EntityRegistry = ws.entity_registry
	var granter: Person = registry.get_entity(granter_id) as Person
	var recipient: Person = registry.get_entity(recipient_id) as Person
	if not granter or not recipient:
		return 0
	
	var favours: Array = ws.custom_data.get("favours", [])
	var favour_id: int = favours.size() + 1
	var favour: Favour = Favour.new(
		favour_id,
		granter_id,
		recipient_id,
		ws.sim_clock.get_tick() if ws.sim_clock else 0,
		favour_type,
		clampf(obligation_value / 100.0, 0.0, 1.0) if obligation_value > 1.0 else clampf(obligation_value, 0.0, 1.0),
		"%s granted favour to %s" % [granter.get_full_name(), recipient.get_full_name()]
	)
	favours.append(favour)
	ws.custom_data["favours"] = favours
	return favour_id

## Read the official inventory ledger amount for a room/resource pair
func get_official_ledger_amount(ws: WorldState, room_id: int, resource_id: String) -> float:
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	if ledgers.has(room_id):
		var room_ledger: Dictionary = ledgers[room_id] as Dictionary
		if room_ledger and room_ledger.has(resource_id):
			return float(room_ledger[resource_id])
	return 0.0

## Manually audit a specific illicit action — marks it as exposed
func audit_action(ws: WorldState, action_id: int, evidence: float, auditor_id: int) -> void:
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	for a_item in actions:
		var action: IllicitAction = a_item as IllicitAction
		if action and action.id == action_id and action.discovery_status == IllicitAction.STATUS_CONCEALED:
			action.discovery_status = IllicitAction.STATUS_EXPOSED
			action.discovered_tick = ws.sim_clock.get_tick() if ws.sim_clock else 0
			action.discoverer_id = auditor_id
			action.evidence_strength = clampf(evidence, 0.0, 1.0)
			break

## Apply institutional sanction for an exposed illicit action
func apply_sanction(ws: WorldState, action_id: int) -> void:
	var actions: Array = ws.custom_data.get("illicit_actions", [])
	var registry: EntityRegistry = ws.entity_registry
	var current_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	
	for a_item in actions:
		var action: IllicitAction = a_item as IllicitAction
		if not action or action.id != action_id:
			continue
		if action.discovery_status != IllicitAction.STATUS_EXPOSED:
			continue
		
		var perp: Person = registry.get_entity(action.perpetrator_id) as Person
		if perp and perp.is_alive:
			if perp.security_clearance > 0:
				perp.security_clearance -= 1
				action.penalty_applied = "clearance_revoked"
			else:
				action.penalty_applied = "formal_reprimand"
			
			perp.record_opinion_memory(
				PoliticalEvent.EVENT_DISCIPLINARY_SANCTION,
				current_tick,
				PoliticalEvent.DEPT_SECURITY,
				-0.6,
				"Sanctioned for corruption and illicit resource diversion"
			)
		
		var ben: Person = registry.get_entity(action.beneficiary_id) as Person
		if ben and ben.is_alive:
			ben.record_opinion_memory(
				PoliticalEvent.EVENT_CORRUPTION_DISCOVERED,
				current_tick,
				PoliticalEvent.DEPT_SECURITY,
				-0.4,
				"Benefited from exposed illicit diversion"
			)
		
		# Reconcile official inventory ledger to match physical truth
		if action.source_room_id > 0 and action.target_resource != "":
			var src_room: Room = registry.get_entity(action.source_room_id) as Room
			if src_room and src_room.inventory_id > 0:
				var src_inv: Inventory = registry.get_entity(src_room.inventory_id) as Inventory
				if src_inv:
					if not ledgers.has(action.source_room_id):
						ledgers[action.source_room_id] = {}
					ledgers[action.source_room_id][action.target_resource] = src_inv.get_stock(action.target_resource)
		
		action.discovery_status = IllicitAction.STATUS_SANCTIONED
		break

## Reconcile official ledger for a specific room/resource to match physical inventory
func reconcile_ledger(ws: WorldState, room_id: int, resource_id: String) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	var room: Room = registry.get_entity(room_id) as Room
	if room and room.inventory_id > 0:
		var inv: Inventory = registry.get_entity(room.inventory_id) as Inventory
		if inv:
			if not ledgers.has(room_id):
				ledgers[room_id] = {}
			ledgers[room_id][resource_id] = inv.get_stock(resource_id)
			ws.custom_data["official_inventory_ledgers"] = ledgers

func serialize() -> Dictionary:
	return {
		"audit_interval_ticks": audit_interval_ticks,
		"last_evaluation_tick": last_evaluation_tick,
		"audit_rigour": audit_rigour
	}

func deserialize(data: Dictionary) -> void:
	audit_interval_ticks = int(data.get("audit_interval_ticks", 144))
	last_evaluation_tick = int(data.get("last_evaluation_tick", 0))
	audit_rigour = float(data.get("audit_rigour", 0.6))
