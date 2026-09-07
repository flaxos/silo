# src/sim/politics/political_system.gd
class_name PoliticalSystem
extends BaseSystem

const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")
const LegitimacyModel = preload("res://src/sim/politics/legitimacy_model.gd")
const OpinionMemory = preload("res://src/sim/politics/opinion_memory.gd")

## Domain system managing citizen political attitudes, lived memory evaluation, and derived habitat legitimacy.

const EVALUATION_INTERVAL_TICKS: int = 144 # Evaluated once per simulated day (or on critical events)

var total_memories_created: int = 0
var last_evaluation_tick: int = -1

func _init() -> void:
	system_id = "political_system"
	execution_order = 35 # Executes between Institutions/Demographics (30/40) and Daily Life (50)

func setup(_world_state: Variant) -> void:
	var ws: WorldState = _world_state as WorldState
	if ws:
		ws.custom_data["political_system"] = self
		ws.custom_data["habitat_legitimacy"] = 0.5
		ws.custom_data["class_resentment_index"] = 0.0

func tick(_world_state: Variant) -> void:
	var ws: WorldState = _world_state as WorldState
	if not ws or not ws.sim_clock:
		return
		
	var cur_tick: int = ws.sim_clock.get_tick()
	
	# Periodic evaluation (every day)
	if cur_tick % EVALUATION_INTERVAL_TICKS == 0 and cur_tick != last_evaluation_tick:
		last_evaluation_tick = cur_tick
		_evaluate_daily_political_experiences(ws, cur_tick)
		
	# Recalculate derived aggregate metrics
	ws.custom_data["habitat_legitimacy"] = LegitimacyModel.calculate_overall_legitimacy(ws)
	ws.custom_data["class_resentment_index"] = LegitimacyModel.calculate_class_resentment_index(ws)

func _evaluate_daily_political_experiences(ws: WorldState, cur_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	if not registry:
		return
		
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	# 1. Check active policies in institution system
	var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
	var is_rationing: bool = false
	if inst_sys and inst_sys.active_policies.has("rationing"):
		var pol: Policy = inst_sys.active_policies["rationing"] as Policy
		if pol and pol.is_active and pol.id != "ration_standard":
			is_rationing = true
			
	var has_coercive_orders: bool = false
	if inst_sys and not inst_sys.active_orders.is_empty():
		has_coercive_orders = true
		
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		# Check dehydration experience
		if p.is_severely_dehydrated():
			p.record_opinion_memory(
				PoliticalEvent.EVENT_DEHYDRATION_SUFFERED,
				cur_tick,
				PoliticalEvent.DEPT_UTILITIES,
				-0.6,
				"Suffered acute dehydration due to habitat water utility outage.",
				0
			)
			total_memories_created += 1
		elif is_rationing:
			# Minor recurring discontent from rationing
			p.record_opinion_memory(
				PoliticalEvent.EVENT_WATER_RATIONED,
				cur_tick,
				PoliticalEvent.DEPT_ADMINISTRATION,
				-0.15,
				"Subjected to mandatory habitat water consumption rationing.",
				0
			)
			total_memories_created += 1
			
		# Check housing conditions
		if p.bed_id == -1:
			p.record_opinion_memory(
				PoliticalEvent.EVENT_HOUSING_OVERCROWDED,
				cur_tick,
				PoliticalEvent.DEPT_ADMINISTRATION,
				-0.25,
				"Lacks an assigned private bed in residential quarters.",
				p.home_room_id
			)
			total_memories_created += 1
			
		# Check coercive executive directives
		if has_coercive_orders and (p.department_id == "engineering" or p.department_id == "security"):
			p.record_opinion_memory(
				PoliticalEvent.EVENT_COERCIVE_ORDER,
				cur_tick,
				PoliticalEvent.DEPT_ADMINISTRATION,
				-0.2,
				"Compelled to work under active executive order directives.",
				0
			)
			total_memories_created += 1
			
		# Update attitudes after daily memories
		p.recalculate_political_attitudes(cur_tick)

func record_citizen_event(
	ws: WorldState,
	person_id: int,
	event_type: String,
	dept: String,
	impact: float,
	desc: String,
	source_id: int = 0
) -> bool:
	if not ws or not ws.entity_registry:
		return false
	var p: Person = ws.entity_registry.get_entity(person_id) as Person
	if not p or not p.is_alive:
		return false
		
	var cur_tick: int = ws.sim_clock.get_tick() if ws.sim_clock else 0
	p.record_opinion_memory(event_type, cur_tick, dept, impact, desc, source_id)
	total_memories_created += 1
	return true

func serialize() -> Dictionary:
	return {
		"total_memories_created": total_memories_created,
		"last_evaluation_tick": last_evaluation_tick
	}

func deserialize(data: Dictionary) -> void:
	total_memories_created = int(data.get("total_memories_created", 0))
	last_evaluation_tick = int(data.get("last_evaluation_tick", -1))
