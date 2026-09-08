# src/sim/institutions/institution_system.gd
class_name InstitutionSystem
extends BaseSystem

const SYSTEM_ID: String = "institutions"
const EXECUTION_ORDER: int = 30 # Runs before DailyLife(50), Maintenance(55), Production(60), Water(65), Demographics(70)

var available_policies: Dictionary = {} # policy_id: String -> Policy
var active_policies: Dictionary = {} # category: String -> Policy
var active_orders: Dictionary = {} # order_id: String -> ExecutiveOrder

var social_tension_index: float = 0.0 # 0.0 to 100.0
var total_policies_enacted: int = 0
var total_orders_dispatched: int = 0
var total_orders_expired: int = 0

func _init() -> void:
	super(SYSTEM_ID, EXECUTION_ORDER)
	_init_default_registry()

func _init_default_registry() -> void:
	available_policies = Policy.create_default_policies()
	active_policies.clear()
	active_orders.clear()
	social_tension_index = 0.0
	total_policies_enacted = 0
	total_orders_dispatched = 0
	total_orders_expired = 0
	
	# Enact standard baseline policies by default
	_activate_policy_internal(available_policies[Policy.POLICY_RATION_STANDARD], 0)
	_activate_policy_internal(available_policies[Policy.POLICY_WORK_STANDARD_8H], 0)
	_activate_policy_internal(available_policies[Policy.POLICY_MAINT_STANDARD], 0)
	_activate_policy_internal(available_policies[Policy.POLICY_SECURITY_OPEN], 0)
	_activate_policy_internal(available_policies[Policy.POLICY_EDU_STANDARD], 0)

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	_sync_to_world_state(ws)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	var current_tick: int = ws.sim_clock.get_tick()
	
	# 1. Step and process active executive orders
	var expired_order_ids: Array[String] = []
	for order_id in active_orders:
		var order: ExecutiveOrder = active_orders[order_id] as ExecutiveOrder
		if not order or not order.is_active:
			expired_order_ids.append(order_id)
			continue
			
		order.step_order(ws)
		
		# Accumulate real-world consequences into order tracking
		var daily_tension: float = float(order.parameters.get("social_tension_rate_per_day", 0.0))
		if daily_tension > 0.0:
			var tension_delta: float = daily_tension / 144.0
			order.consequences["social_tension_acc"] = float(order.consequences.get("social_tension_acc", 0.0)) + tension_delta
			social_tension_index = minf(100.0, social_tension_index + tension_delta)
			
		var wear_mult: float = float(order.parameters.get("wear_rate_mult", 1.0))
		if wear_mult > 1.0:
			order.consequences["extra_wear_acc"] = float(order.consequences.get("extra_wear_acc", 0.0)) + ((wear_mult - 1.0) * (10.0 / 60.0))
			
		if order.is_expired():
			order.is_active = false
			expired_order_ids.append(order_id)
			total_orders_expired += 1
			
	for oid in expired_order_ids:
		active_orders.erase(oid)
		
	# 2. Process active policy friction and tension
	var total_policy_tension_per_day: float = 0.0
	for cat in active_policies:
		var pol: Policy = active_policies[cat] as Policy
		if pol and pol.is_active:
			var p_tension: float = float(pol.parameters.get("tension_per_day", 0.0))
			total_policy_tension_per_day += p_tension
			
	if total_policy_tension_per_day > 0.0:
		social_tension_index = minf(100.0, social_tension_index + (total_policy_tension_per_day / 144.0))
	else:
		# Natural tension relaxation under nominal conditions (-0.05 per day)
		social_tension_index = maxf(0.0, social_tension_index - (0.05 / 144.0))
		
	# 3. Synchronize aggregated institutional parameters into WorldState
	_sync_to_world_state(ws)

func enact_policy(policy_id: String, ws: WorldState = null) -> bool:
	if not available_policies.has(policy_id):
		return false
		
	var policy: Policy = available_policies[policy_id]
	var tick_idx: int = ws.sim_clock.get_tick() if ws else 0
	_activate_policy_internal(policy, tick_idx)
	total_policies_enacted += 1
	
	if ws:
		_sync_to_world_state(ws)
	return true

func revoke_policy(category: String, ws: WorldState = null) -> bool:
	if not active_policies.has(category):
		return false
		
	var existing: Policy = active_policies[category]
	existing.is_active = false
	active_policies.erase(category)
	
	# Fall back to default standard policy for this category
	var default_id: String = ""
	match category:
		Policy.CATEGORY_RATIONING:
			default_id = Policy.POLICY_RATION_STANDARD
		Policy.CATEGORY_WORK_HOURS:
			default_id = Policy.POLICY_WORK_STANDARD_8H
		Policy.CATEGORY_MAINTENANCE:
			default_id = Policy.POLICY_MAINT_STANDARD
		Policy.CATEGORY_SECURITY:
			default_id = Policy.POLICY_SECURITY_OPEN
		Policy.CATEGORY_EDUCATION:
			default_id = Policy.POLICY_EDU_STANDARD
			
	if default_id != "" and available_policies.has(default_id):
		var tick_idx: int = ws.sim_clock.get_tick() if ws else 0
		_activate_policy_internal(available_policies[default_id], tick_idx)
		
	if ws:
		_sync_to_world_state(ws)
	return true

func issue_order(order: ExecutiveOrder, ws: WorldState = null) -> bool:
	if not order:
		return false
		
	order.is_active = true
	order.ticks_elapsed = 0
	order.enacted_tick = ws.sim_clock.get_tick() if ws else 0
	active_orders[order.id] = order
	total_orders_dispatched += 1
	
	if ws:
		_sync_to_world_state(ws)
	return true

func cancel_order(order_id: String, ws: WorldState = null) -> bool:
	if not active_orders.has(order_id):
		return false
		
	var order: ExecutiveOrder = active_orders[order_id]
	order.is_active = false
	active_orders.erase(order_id)
	
	if ws:
		_sync_to_world_state(ws)
	return true

func get_active_policy(category: String) -> Policy:
	return active_policies.get(category, null) as Policy

func get_active_order(order_id: String) -> ExecutiveOrder:
	return active_orders.get(order_id, null) as ExecutiveOrder

func get_water_ration_rate() -> float:
	# Check active executive orders first
	for oid in active_orders:
		var ord: ExecutiveOrder = active_orders[oid]
		if ord.order_type == ExecutiveOrder.ORDER_WATER_CUTS:
			var mult: float = float(ord.parameters.get("water_consumption_mult", 0.50))
			return (2.5 / 144.0) * mult
			
	# Check active policy
	var rat_pol: Policy = active_policies.get(Policy.CATEGORY_RATIONING, null)
	if rat_pol and rat_pol.is_active:
		return float(rat_pol.parameters.get("water_ration_l_per_tick", 2.5 / 144.0))
		
	return 2.5 / 144.0

func get_maintenance_trigger_wear() -> float:
	var maint_pol: Policy = active_policies.get(Policy.CATEGORY_MAINTENANCE, null)
	if maint_pol and maint_pol.is_active:
		return float(maint_pol.parameters.get("maintenance_wear_threshold", 60.0))
	return 60.0

## Standing Engineering delegation to IT: one early-service scheduling slot.
## No power to conscript labour, set industrial quotas, or bypass repair inputs.
func request_it_service(ws: WorldState, machine_id: int) -> bool:
	if str(ws.custom_data.get("player_role", "")) != OperationsConfig.ROLE_IT or not bool(ws.custom_data.get("it_service_delegation", false)):
		return false
	var machine := ws.entity_registry.get_entity(machine_id) as WaterPump
	if not machine or not machine.needs_maintenance(OperationsConfig.EARLY_WEAR):
		return false
	if active_orders.has(OperationsConfig.ORDER_EARLY_SERVICE):
		return false
	var order := ExecutiveOrder.new(OperationsConfig.ORDER_EARLY_SERVICE, OperationsConfig.ORDER_EARLY_SERVICE,
		"IT request: early Engineering service", Occupation.DEPT_IT, str(machine_id), OperationsConfig.SERVICE_TICKS,
		{"maintenance_wear_threshold": OperationsConfig.EARLY_WEAR})
	return issue_order(order, ws)

func get_machine_maintenance_threshold(machine_id: int) -> float:
	var threshold := get_maintenance_trigger_wear()
	var order := get_active_order(OperationsConfig.ORDER_EARLY_SERVICE)
	if order and order.is_active and order.target_id == str(machine_id):
		return minf(threshold, OperationsConfig.EARLY_WEAR)
	return threshold

func get_shift_work_hours() -> int:
	for oid in active_orders:
		var ord: ExecutiveOrder = active_orders[oid]
		if ord.order_type == ExecutiveOrder.ORDER_OVERTIME_SURGE:
			return 12
			
	var work_pol: Policy = active_policies.get(Policy.CATEGORY_WORK_HOURS, null)
	if work_pol and work_pol.is_active:
		return int(work_pol.parameters.get("shift_work_hours", 8))
	return 8

func get_production_labor_multiplier() -> float:
	for oid in active_orders:
		var ord: ExecutiveOrder = active_orders[oid]
		if ord.order_type == ExecutiveOrder.ORDER_OVERTIME_SURGE:
			return float(ord.parameters.get("labor_output_mult", 1.50))
			
	var work_pol: Policy = active_policies.get(Policy.CATEGORY_WORK_HOURS, null)
	if work_pol and work_pol.is_active:
		return float(work_pol.parameters.get("production_labor_mult", 1.0))
	return 1.0

func get_machine_wear_rate_multiplier(machine_id: int = 0) -> float:
	var mult: float = 1.0
	
	# Check machine overdrive order
	for oid in active_orders:
		var ord: ExecutiveOrder = active_orders[oid]
		if ord.order_type == ExecutiveOrder.ORDER_MACHINE_OVERDRIVE:
			if ord.target_id == "" or ord.target_id == "all" or ord.target_id == str(machine_id):
				mult *= float(ord.parameters.get("wear_rate_mult", 2.50))
		elif ord.order_type == ExecutiveOrder.ORDER_OVERTIME_SURGE:
			mult *= float(ord.parameters.get("machine_wear_mult", 1.50))
			
	var work_pol: Policy = active_policies.get(Policy.CATEGORY_WORK_HOURS, null)
	if work_pol and work_pol.is_active:
		mult *= float(work_pol.parameters.get("machine_wear_rate_mult", 1.0))
		
	return mult

func get_machine_throughput_multiplier(machine_id: int = 0) -> float:
	var mult: float = 1.0
	for oid in active_orders:
		var ord: ExecutiveOrder = active_orders[oid]
		if ord.order_type == ExecutiveOrder.ORDER_MACHINE_OVERDRIVE:
			if ord.target_id == "" or ord.target_id == "all" or ord.target_id == str(machine_id):
				mult *= float(ord.parameters.get("throughput_mult", 1.25))
	return mult

func is_sector_travel_allowed(person_clearance: int, from_sector: int, to_sector: int) -> bool:
	if from_sector == to_sector:
		return true
		
	# Check sector lockdown orders
	for oid in active_orders:
		var ord: ExecutiveOrder = active_orders[oid]
		if ord.order_type == ExecutiveOrder.ORDER_LOCKDOWN_SECTOR:
			var locked_sector: int = int(ord.parameters.get("locked_sector_id", 0))
			if locked_sector == to_sector or locked_sector == from_sector:
				if person_clearance < 3: # Requires level 3 clearance during lockdown
					return false
					
	# Check quarantine policy
	var sec_pol: Policy = active_policies.get(Policy.CATEGORY_SECURITY, null)
	if sec_pol and sec_pol.is_active:
		var req_clr: int = int(sec_pol.parameters.get("inter_sector_clearance_required", 0))
		if person_clearance < req_clr:
			return false
			
	return true

func _activate_policy_internal(policy: Policy, tick_idx: int) -> void:
	if not policy:
		return
	if active_policies.has(policy.category):
		var prev: Policy = active_policies[policy.category]
		prev.is_active = false
		
	policy.is_active = true
	policy.enacted_tick = tick_idx
	active_policies[policy.category] = policy

func _sync_to_world_state(ws: WorldState) -> void:
	if not ws:
		return
	ws.custom_data["institution_system"] = self
	ws.custom_data["water_ration_rate"] = get_water_ration_rate()
	ws.custom_data["maintenance_trigger_wear"] = get_maintenance_trigger_wear()
	ws.custom_data["shift_work_hours_day"] = get_shift_work_hours()
	ws.custom_data["production_labor_multiplier"] = get_production_labor_multiplier()
	ws.custom_data["machine_wear_multiplier"] = get_machine_wear_rate_multiplier()
	ws.custom_data["machine_throughput_multiplier"] = get_machine_throughput_multiplier()
	ws.custom_data["social_tension_index"] = social_tension_index
	ws.custom_data["active_policy_count"] = active_policies.size()
	ws.custom_data["active_order_count"] = active_orders.size()

func serialize() -> Dictionary:
	var active_pol_dict: Dictionary = {}
	for cat in active_policies:
		var p: Policy = active_policies[cat]
		active_pol_dict[cat] = p.id
		
	var ord_dict: Dictionary = {}
	for ord_id in active_orders:
		var o: ExecutiveOrder = active_orders[ord_id]
		ord_dict[ord_id] = o.serialize()
		
	return {
		"social_tension_index": social_tension_index,
		"total_policies_enacted": total_policies_enacted,
		"total_orders_dispatched": total_orders_dispatched,
		"total_orders_expired": total_orders_expired,
		"active_policies": active_pol_dict,
		"active_orders": ord_dict
	}

func deserialize(data: Dictionary) -> void:
	social_tension_index = float(data.get("social_tension_index", 0.0))
	total_policies_enacted = int(data.get("total_policies_enacted", 0))
	total_orders_dispatched = int(data.get("total_orders_dispatched", 0))
	total_orders_expired = int(data.get("total_orders_expired", 0))
	
	active_policies.clear()
	var act_pols: Dictionary = data.get("active_policies", {})
	for cat in act_pols:
		var pol_id: String = act_pols[cat]
		if available_policies.has(pol_id):
			_activate_policy_internal(available_policies[pol_id], 0)
			
	active_orders.clear()
	var act_ords: Dictionary = data.get("active_orders", {})
	for ord_id in act_ords:
		var ord_data: Dictionary = act_ords[ord_id]
		var ord: ExecutiveOrder = ExecutiveOrder.new()
		ord.deserialize(ord_data)
		active_orders[ord.id] = ord
