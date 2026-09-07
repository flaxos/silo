# src/sim/politics/faction.gd
class_name Faction
extends RefCounted

## Authoritative Faction Entity representing an emergent political movement or interest bloc.
## Factions emerge conditionally from shared lived grievances and social networks.

var id: int = 0
var name: String = ""
var manifesto: String = ""

# Ideology Profile Vector (0.0 to 1.0)
var ideology_profile: Dictionary = {
	"preference_equality": 0.5,
	"preference_hierarchy": 0.5,
	"preference_reform": 0.5,
	"preference_stability": 0.5,
	"preference_autonomy": 0.5,
	"tolerance_coercion": 0.3
}

var leader_id: int = 0
var member_ids: Array[int] = []
var sympathiser_ids: Array[int] = []

var cohesion: float = 1.0 # 0.0 (splintering/chaotic) to 1.0 (disciplined/solidarity)
var resources: float = 0.0 # Accumulated political capital or strike fund

# List of active grievances: [{"type": String, "severity": float, "salience": float, "target_dept": String, "description": String}]
var grievance_agenda: Array[Dictionary] = []

# Dynamic approval scores for active policies & orders (policy_id -> float [-1.0, 1.0])
var policy_approval_matrix: Dictionary = {}

# Inter-faction relationship scores (other_faction_id (int) -> float [-1.0, 1.0])
var inter_faction_relations: Dictionary = {}

# Departmental penetration (% of personnel in dept who are members/sympathisers)
var institutional_penetration: Dictionary = {
	"administration": 0.0,
	"engineering": 0.0,
	"security": 0.0,
	"utilities": 0.0,
	"it": 0.0
}

var creation_tick: int = 0
var is_active: bool = true

func _init(p_id: int = 0, p_name: String = "", p_leader_id: int = 0, p_tick: int = 0) -> void:
	id = p_id
	name = p_name
	leader_id = p_leader_id
	creation_tick = p_tick
	is_active = true
	cohesion = 1.0
	resources = 0.0
	member_ids = []
	sympathiser_ids = []
	grievance_agenda = []
	policy_approval_matrix = {}
	inter_faction_relations = {}
	institutional_penetration = {
		"administration": 0.0,
		"engineering": 0.0,
		"security": 0.0,
		"utilities": 0.0,
		"it": 0.0
	}
	ideology_profile = {
		"preference_equality": 0.5,
		"preference_hierarchy": 0.5,
		"preference_reform": 0.5,
		"preference_stability": 0.5,
		"preference_autonomy": 0.5,
		"tolerance_coercion": 0.3
	}
	if p_leader_id > 0:
		member_ids.append(p_leader_id)

func add_member(person_id: int) -> bool:
	if person_id <= 0:
		return false
	if not member_ids.has(person_id):
		member_ids.append(person_id)
	# Remove from sympathisers if upgraded
	if sympathiser_ids.has(person_id):
		sympathiser_ids.erase(person_id)
	return true

func remove_member(person_id: int) -> bool:
	if member_ids.has(person_id):
		member_ids.erase(person_id)
		if leader_id == person_id:
			leader_id = member_ids[0] if not member_ids.is_empty() else 0
		if member_ids.is_empty():
			is_active = false
		return true
	return false

func add_sympathiser(person_id: int) -> bool:
	if person_id <= 0 or member_ids.has(person_id):
		return false
	if not sympathiser_ids.has(person_id):
		sympathiser_ids.append(person_id)
	return true

func remove_sympathiser(person_id: int) -> bool:
	if sympathiser_ids.has(person_id):
		sympathiser_ids.erase(person_id)
		return true
	return false

func recalculate_cohesion(ws: WorldState) -> void:
	if not ws or not ws.entity_registry or member_ids.is_empty():
		cohesion = 0.0
		return
		
	var registry: EntityRegistry = ws.entity_registry
	var total_variance: float = 0.0
	var valid_members: int = 0
	
	for mid in member_ids:
		var p: Person = registry.get_entity(mid) as Person
		if p and p.is_alive:
			valid_members += 1
			var d_eq: float = absf(p.preference_equality - float(ideology_profile.get("preference_equality", 0.5)))
			var d_hier: float = absf(p.preference_hierarchy - float(ideology_profile.get("preference_hierarchy", 0.5)))
			var d_ref: float = absf(p.preference_reform - float(ideology_profile.get("preference_reform", 0.5)))
			var d_stab: float = absf(p.preference_stability - float(ideology_profile.get("preference_stability", 0.5)))
			var d_auto: float = absf(p.preference_autonomy - float(ideology_profile.get("preference_autonomy", 0.5)))
			var d_coerc: float = absf(p.tolerance_coercion - float(ideology_profile.get("tolerance_coercion", 0.3)))
			total_variance += (d_eq + d_hier + d_ref + d_stab + d_auto + d_coerc) / 6.0
			
	if valid_members == 0:
		cohesion = 0.0
		is_active = false
		return
		
	var avg_variance: float = total_variance / float(valid_members)
	cohesion = clampf(1.0 - (avg_variance * 1.5), 0.1, 1.0)

func recalculate_institutional_penetration(ws: WorldState) -> void:
	if not ws or not ws.entity_registry:
		return
		
	var registry: EntityRegistry = ws.entity_registry
	var dept_totals: Dictionary = {
		"administration": 0,
		"engineering": 0,
		"security": 0,
		"utilities": 0,
		"it": 0
	}
	var dept_members: Dictionary = {
		"administration": 0,
		"engineering": 0,
		"security": 0,
		"utilities": 0,
		"it": 0
	}
	
	var pids: Array[int] = registry.get_entities_by_type("person")
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive or p.department_id == "" or not dept_totals.has(p.department_id):
			continue
			
		dept_totals[p.department_id] = int(dept_totals[p.department_id]) + 1
		if member_ids.has(pid) or sympathiser_ids.has(pid):
			dept_members[p.department_id] = int(dept_members[p.department_id]) + 1
			
	for dept in dept_totals.keys():
		var total_cnt: int = int(dept_totals[dept])
		if total_cnt > 0:
			institutional_penetration[dept] = float(dept_members[dept]) / float(total_cnt)
		else:
			institutional_penetration[dept] = 0.0

func recalculate_policy_approvals(ws: WorldState) -> void:
	policy_approval_matrix.clear()
	if not ws:
		return
		
	var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
	if not inst_sys:
		return
		
	var target_equality: float = float(ideology_profile.get("preference_equality", 0.5))
	var target_autonomy: float = float(ideology_profile.get("preference_autonomy", 0.5))
	var target_reform: float = float(ideology_profile.get("preference_reform", 0.5))
	var target_coercion: float = float(ideology_profile.get("tolerance_coercion", 0.3))
	
	# Evaluate active policies
	for cat in inst_sys.active_policies.keys():
		var pol: Policy = inst_sys.active_policies[cat] as Policy
		if pol and pol.is_active:
			var approval: float = 0.0
			if pol.id.begins_with("ration_"):
				# Rationing policy: high equality factions approve of equal burden, high autonomy disapproves
				approval = (target_equality * 0.6) - (target_autonomy * 0.8) - 0.2
			elif pol.id.begins_with("shift_"):
				if pol.id == "shift_extended":
					# Long shifts: heavily disliked by high reform/autonomy factions
					approval = -0.5 - (target_autonomy * 0.4) + (target_coercion * 0.3)
				else:
					approval = 0.3 + (target_equality * 0.3)
			else:
				approval = (target_reform - 0.5) * 0.5
			policy_approval_matrix[pol.id] = clampf(approval, -1.0, 1.0)
			
	# Evaluate active executive orders
	for order_id in inst_sys.active_orders.keys():
		var order: ExecutiveOrder = inst_sys.active_orders[order_id] as ExecutiveOrder
		if not order:
			continue
		var approval: float = -0.3 # Coercive baseline dislike
		if order.order_type == ExecutiveOrder.ORDER_OVERTIME_SURGE:
			approval = -0.7 + (target_coercion * 0.5) - (target_autonomy * 0.4)
		elif order.order_type == ExecutiveOrder.ORDER_WATER_CUTS:
			approval = -0.8 - (target_autonomy * 0.5) + (target_equality * 0.2)
		elif order.order_type == ExecutiveOrder.ORDER_LOCKDOWN_SECTOR:
			approval = -0.5 + (float(ideology_profile.get("preference_stability", 0.5)) * 0.4) - (target_autonomy * 0.6)
		elif order.order_type == ExecutiveOrder.ORDER_CONSCRIPT_LABOR:
			approval = -0.9 + (target_coercion * 0.3) - (target_autonomy * 0.6)
		policy_approval_matrix[order.id] = clampf(approval, -1.0, 1.0)

func serialize() -> Dictionary:
	var mems: Array[int] = []
	for m in member_ids:
		mems.append(int(m))
	var symps: Array[int] = []
	for s in sympathiser_ids:
		symps.append(int(s))
	var g_agenda: Array[Dictionary] = []
	for g in grievance_agenda:
		g_agenda.append(g.duplicate())
		
	return {
		"id": id,
		"name": name,
		"manifesto": manifesto,
		"ideology_profile": ideology_profile.duplicate(),
		"leader_id": leader_id,
		"member_ids": mems,
		"sympathiser_ids": symps,
		"cohesion": cohesion,
		"resources": resources,
		"grievance_agenda": g_agenda,
		"policy_approval_matrix": policy_approval_matrix.duplicate(),
		"inter_faction_relations": inter_faction_relations.duplicate(),
		"institutional_penetration": institutional_penetration.duplicate(),
		"creation_tick": creation_tick,
		"is_active": is_active
	}

func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	name = str(data.get("name", ""))
	manifesto = str(data.get("manifesto", ""))
	ideology_profile = data.get("ideology_profile", {
		"preference_equality": 0.5,
		"preference_hierarchy": 0.5,
		"preference_reform": 0.5,
		"preference_stability": 0.5,
		"preference_autonomy": 0.5,
		"tolerance_coercion": 0.3
	})
	leader_id = int(data.get("leader_id", 0))
	member_ids = []
	for m in data.get("member_ids", []):
		member_ids.append(int(m))
	sympathiser_ids = []
	for s in data.get("sympathiser_ids", []):
		sympathiser_ids.append(int(s))
	cohesion = float(data.get("cohesion", 1.0))
	resources = float(data.get("resources", 0.0))
	grievance_agenda = []
	for g in data.get("grievance_agenda", []):
		if g is Dictionary:
			grievance_agenda.append(g.duplicate())
	policy_approval_matrix = data.get("policy_approval_matrix", {})
	inter_faction_relations = data.get("inter_faction_relations", {})
	institutional_penetration = data.get("institutional_penetration", {
		"administration": 0.0,
		"engineering": 0.0,
		"security": 0.0,
		"utilities": 0.0,
		"it": 0.0
	})
	creation_tick = int(data.get("creation_tick", 0))
	is_active = bool(data.get("is_active", true))
