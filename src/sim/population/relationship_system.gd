# src/sim/population/relationship_system.gd
class_name RelationshipSystem
extends BaseSystem

const Relationship = preload("res://src/sim/population/relationship.gd")

const SYSTEM_ID: String = "relationships"
const EXECUTION_ORDER: int = 44

## Map of "idA_idB" -> Relationship
var relationships: Dictionary = {}
var total_partnerships_formed: int = 0
var total_separations: int = 0
var total_friendships_formed: int = 0

func _init() -> void:
	super(SYSTEM_ID, EXECUTION_ORDER)
	relationships = {}
	total_partnerships_formed = 0
	total_separations = 0
	total_friendships_formed = 0

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws.custom_data.has("relationships"):
		ws.custom_data["relationships"] = relationships
	else:
		relationships = ws.custom_data["relationships"]

func get_or_create_relationship(p_a: int, p_b: int) -> Relationship:
	if p_a == p_b or p_a <= 0 or p_b <= 0:
		return null
	var key: String = Relationship.make_key(p_a, p_b)
	if relationships.has(key):
		return relationships[key]
	var rel: Relationship = Relationship.new(p_a, p_b)
	relationships[key] = rel
	return rel

func get_relationship(p_a: int, p_b: int) -> Relationship:
	var key: String = Relationship.make_key(p_a, p_b)
	return relationships.get(key, null)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	var clock: SimClock = ws.sim_clock
	var current_tick: int = clock.get_tick()
	var tick_of_hour: int = current_tick % 6
	
	# Execute interaction sampling once an hour (every 6 ticks) to maintain performance
	if tick_of_hour == 0:
		_process_interactions(ws, current_tick)
		
	# Daily reconciliation (proposals, separations, household movement) at midnight
	if clock.get_tick_of_day() == 0:
		_process_daily_lifecycle(ws, current_tick)

func _process_interactions(ws: WorldState, current_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var rng: SeededRandom = ws.rng
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	# Group living persons by location room
	var room_occupants: Dictionary = {} # room_id -> Array[Person]
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive or p.current_location_id <= 0:
			continue
		if not room_occupants.has(p.current_location_id):
			room_occupants[p.current_location_id] = []
		var arr: Array = room_occupants[p.current_location_id]
		arr.append(p)
		
	for room_id in room_occupants:
		var occupants: Array = room_occupants[room_id]
		var count: int = occupants.size()
		if count < 2:
			continue
			
		# Sample pairs up to a reasonable cap to avoid explosion in large rooms
		var sample_count: int = mini(count * 2, 20)
		for s in range(sample_count):
			var idx1: int = rng.randi_range(0, count - 1)
			var idx2: int = rng.randi_range(0, count - 1)
			if idx1 == idx2:
				continue
			var p1: Person = occupants[idx1] as Person
			var p2: Person = occupants[idx2] as Person
			_interact(ws, p1, p2)

func _interact(ws: WorldState, p1: Person, p2: Person) -> void:
	var rng: SeededRandom = ws.rng
	var rel: Relationship = get_or_create_relationship(p1.id, p2.id)
	if not rel:
		return
		
	rel.shared_history_ticks += 6
	rel.familiarity += 0.25
	
	# Are they coworkers, household mates, or students?
	var is_household: bool = (p1.household_id > 0 and p1.household_id == p2.household_id)
	var is_coworker: bool = (p1.workplace_room_id > 0 and p1.workplace_room_id == p2.workplace_room_id)
	var is_school: bool = (p1.school_room_id > 0 and p1.school_room_id == p2.school_room_id)
	
	# Fatigue tension
	if p1.fatigue > 70.0 and p2.fatigue > 70.0 and rng.rand_chance(0.10):
		rel.conflict += 0.5
		rel.affection -= 0.2
	else:
		rel.affection += 0.1
		rel.trust += 0.05
		
	# Romantic attraction check: opposite sex, both adults, reasonable age difference, not family
	if p1.sex != p2.sex and p1.life_stage == Person.STAGE_ADULT and p2.life_stage == Person.STAGE_ADULT:
		if not _is_incestuous(p1, p2):
			var age_diff: int = absi(p1.get_age_years(ws.sim_clock.get_tick()) - p2.get_age_years(ws.sim_clock.get_tick()))
			if age_diff <= 15:
				rel.attraction += 0.2
				
	# Positive relationship buffer on stress/morale
	if rel.status in [Relationship.STATUS_FRIEND, Relationship.STATUS_CLOSE_FRIEND, Relationship.STATUS_PARTNER]:
		p1.morale = minf(100.0, p1.morale + 0.02)
		p2.morale = minf(100.0, p2.morale + 0.02)
		p1.stress = maxf(0.0, p1.stress - 0.02)
		p2.stress = maxf(0.0, p2.stress - 0.02)
		
	var old_status: int = rel.status
	rel.update_status()
	if old_status != Relationship.STATUS_FRIEND and rel.status == Relationship.STATUS_FRIEND:
		total_friendships_formed += 1

func _is_incestuous(p1: Person, p2: Person) -> bool:
	if p1.id in p2.parent_ids or p2.id in p1.parent_ids:
		return true
	if p1.id in p2.children_ids or p2.id in p1.children_ids:
		return true
	# Siblings: check shared parents
	for pid in p1.parent_ids:
		if pid > 0 and pid in p2.parent_ids:
			return true
	return false

func _process_daily_lifecycle(ws: WorldState, current_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var rng: SeededRandom = ws.rng
	
	for key in relationships:
		var rel: Relationship = relationships[key]
		var p1: Person = registry.get_entity(rel.person_a_id) as Person
		var p2: Person = registry.get_entity(rel.person_b_id) as Person
		if not p1 or not p2 or not p1.is_alive or not p2.is_alive:
			continue
			
		# 1. Partner proposal
		if rel.status == Relationship.STATUS_ROMANTIC_INTEREST:
			if p1.partner_id == 0 and p2.partner_id == 0 and p1.life_stage == Person.STAGE_ADULT and p2.life_stage == Person.STAGE_ADULT:
				if rel.affection >= 55.0 and rel.attraction >= 55.0 and not _is_incestuous(p1, p2):
					if rng.rand_chance(0.20):
						_form_partnership(ws, p1, p2, rel)
						
		# 2. Separation / Divorce
		elif rel.status == Relationship.STATUS_PARTNER:
			if rel.conflict >= 80.0 and rel.affection <= 20.0:
				if rng.rand_chance(0.15):
					_separate_partners(ws, p1, p2, rel)

func _form_partnership(ws: WorldState, p1: Person, p2: Person, rel: Relationship) -> void:
	p1.partner_id = p2.id
	p2.partner_id = p1.id
	rel.status = Relationship.STATUS_PARTNER
	total_partnerships_formed += 1
	
	# Co-habitation: move p2 into p1's household if different
	if p1.household_id > 0 and p1.household_id != p2.household_id:
		var registry: EntityRegistry = ws.entity_registry
		var old_hh: Household = registry.get_entity(p2.household_id) as Household
		var new_hh: Household = registry.get_entity(p1.household_id) as Household
		if old_hh:
			old_hh.member_ids.erase(p2.id)
		if new_hh and not new_hh.member_ids.has(p2.id):
			new_hh.member_ids.append(p2.id)
		p2.household_id = p1.household_id
		p2.home_room_id = p1.home_room_id

func _separate_partners(ws: WorldState, p1: Person, p2: Person, rel: Relationship) -> void:
	p1.partner_id = 0
	p2.partner_id = 0
	rel.status = Relationship.STATUS_ESTRANGED
	total_separations += 1
	
	# Emotional fallout
	p1.stress = minf(100.0, p1.stress + 25.0)
	p2.stress = minf(100.0, p2.stress + 25.0)
	p1.morale = maxf(0.0, p1.morale - 30.0)
	p2.morale = maxf(0.0, p2.morale - 30.0)

func notify_death(ws: WorldState, deceased: Person) -> void:
	var registry: EntityRegistry = ws.entity_registry
	for key in relationships:
		var rel: Relationship = relationships[key]
		var other_id: int = 0
		if rel.person_a_id == deceased.id:
			other_id = rel.person_b_id
		elif rel.person_b_id == deceased.id:
			other_id = rel.person_a_id
		else:
			continue
			
		var survivor: Person = registry.get_entity(other_id) as Person
		if survivor and survivor.is_alive:
			if rel.status == Relationship.STATUS_PARTNER or rel.person_a_id in survivor.parent_ids or rel.person_b_id in survivor.parent_ids or other_id in deceased.children_ids:
				survivor.stress = minf(100.0, survivor.stress + 35.0)
				survivor.morale = maxf(0.0, survivor.morale - 45.0)
			elif rel.status in [Relationship.STATUS_CLOSE_FRIEND, Relationship.STATUS_FRIEND]:
				survivor.stress = minf(100.0, survivor.stress + 15.0)
				survivor.morale = maxf(0.0, survivor.morale - 20.0)

func serialize() -> Dictionary:
	var rels_data: Array[Dictionary] = []
	for k in relationships:
		rels_data.append(relationships[k].serialize())
	return {
		"system_id": SYSTEM_ID,
		"execution_order": execution_order,
		"relationships": rels_data,
		"total_partnerships_formed": total_partnerships_formed,
		"total_separations": total_separations,
		"total_friendships_formed": total_friendships_formed
	}

func deserialize(data: Dictionary) -> void:
	execution_order = int(data.get("execution_order", 44))
	total_partnerships_formed = int(data.get("total_partnerships_formed", 0))
	total_separations = int(data.get("total_separations", 0))
	total_friendships_formed = int(data.get("total_friendships_formed", 0))
	relationships.clear()
	for r_data in data.get("relationships", []):
		var rel: Relationship = Relationship.new()
		rel.deserialize(r_data)
		var key: String = Relationship.make_key(rel.person_a_id, rel.person_b_id)
		relationships[key] = rel
