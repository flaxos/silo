# src/sim/population/person.gd
class_name Person
extends RefCounted

const OpinionMemory = preload("res://src/sim/politics/opinion_memory.gd")
const PoliticalEvent = preload("res://src/sim/politics/political_event.gd")
const CitizenBelief = preload("res://src/sim/politics/citizen_belief.gd")

const SEX_FEMALE: int = 0
const SEX_MALE: int = 1

const STAGE_INFANT: int = 0   # 0 - 2 years
const STAGE_CHILD: int = 1    # 3 - 12 years
const STAGE_STUDENT: int = 2  # 13 - 17 years
const STAGE_ADULT: int = 3    # 18 - 64 years
const STAGE_ELDER: int = 4    # 65+ years

const ACTIVITY_SLEEPING: int = 0
const ACTIVITY_TRAVELING: int = 1
const ACTIVITY_WORKING: int = 2
const ACTIVITY_STUDYING: int = 3
const ACTIVITY_EATING: int = 4
const ACTIVITY_HYGIENE: int = 5
const ACTIVITY_RECREATING: int = 6
const ACTIVITY_IDLE: int = 7

var id: int = 0
var first_name: String = ""
var last_name: String = ""
var sex: int = SEX_FEMALE
var birth_tick: int = 0
var life_stage: int = STAGE_ADULT

var parent_ids: Array[int] = []
var children_ids: Array[int] = []
var partner_id: int = 0

var household_id: int = 0
var home_room_id: int = 0
var bed_id: int = -1

var is_alive: bool = true

# Vital metrics
var hydration_percent: float = 100.0 # 0.0 to 100.0
var health_percent: float = 100.0    # 0.0 to 100.0
var dehydration_ticks: int = 0

# Education & Social Progression
var education_score: float = 0.0     # 0.0 to 100.0
var tenure_ticks: int = 0            # Accumulated working ticks
var seniority_level: int = 0         # 0 (Junior) to 5+ (Veteran Lead)

# Daily life and occupation tracking
var security_clearance: int = 0         # 0 (Resident) to 5 (Executive Overseer)
var occupation_id: String = "unassigned"
var department_id: String = ""
var shift_id: int = 1 # Occupation.SHIFT_DAY
var workplace_room_id: int = 0
var school_room_id: int = 0
var canteen_room_id: int = 0

var current_activity: int = ACTIVITY_SLEEPING
var current_location_id: int = 0
var target_location_id: int = 0
var travel_ticks_remaining: int = 0
var target_activity_after_travel: int = ACTIVITY_IDLE

# Political Perception & Legitimacy Attitudes (Sprint 12)
var institutional_trust: float = 0.5
var perceived_fairness: float = 0.5
var perceived_security: float = 0.5
var economic_satisfaction: float = 0.5
var class_resentment: float = 0.0

var confidence_leadership: float = 0.5
var confidence_it: float = 0.5
var confidence_security: float = 0.5
var confidence_engineering: float = 0.5

var tolerance_coercion: float = 0.3
var preference_stability: float = 0.6
var preference_reform: float = 0.4
var preference_autonomy: float = 0.5
var preference_equality: float = 0.5
var preference_hierarchy: float = 0.5

# Faction & Movement Affiliation (Sprint 13)
var faction_id: int = 0
var sympathiser_faction_id: int = 0

var opinion_memories: Array[Dictionary] = []

# Information & Belief State (Sprint 15)
var beliefs: Dictionary = {} # event_id (String) -> CitizenBelief

func _init(p_id: int = 0, p_first: String = "", p_last: String = "", p_sex: int = SEX_FEMALE, p_birth_tick: int = 0) -> void:
	id = p_id
	first_name = p_first
	last_name = p_last
	sex = p_sex
	birth_tick = p_birth_tick
	parent_ids = []
	children_ids = []
	partner_id = 0
	household_id = 0
	home_room_id = 0
	bed_id = -1
	is_alive = true
	hydration_percent = 100.0
	health_percent = 100.0
	dehydration_ticks = 0
	education_score = 0.0
	tenure_ticks = 0
	seniority_level = 0
	faction_id = 0
	sympathiser_faction_id = 0
	
	occupation_id = "unassigned"
	department_id = ""
	shift_id = 1
	workplace_room_id = 0
	school_room_id = 0
	canteen_room_id = 0
	
	current_activity = ACTIVITY_SLEEPING
	current_location_id = 0
	target_location_id = 0
	travel_ticks_remaining = 0
	target_activity_after_travel = ACTIVITY_IDLE
	
	update_life_stage(birth_tick)

func get_age_years(current_tick: int) -> int:
	var ticks_lived: int = current_tick - birth_tick
	if ticks_lived <= 0:
		return 0
	return ticks_lived / SimClock.TICKS_PER_YEAR

static func get_life_stage_from_age(age_years: int) -> int:
	if age_years < 3:
		return STAGE_INFANT
	elif age_years < 13:
		return STAGE_CHILD
	elif age_years < 18:
		return STAGE_STUDENT
	elif age_years < 65:
		return STAGE_ADULT
	else:
		return STAGE_ELDER

func update_life_stage(current_tick: int) -> void:
	var age: int = get_age_years(current_tick)
	life_stage = get_life_stage_from_age(age)

func get_full_name() -> String:
	if last_name.is_empty():
		return first_name
	return "%s %s" % [first_name, last_name]

func get_life_stage_name() -> String:
	match life_stage:
		STAGE_INFANT:
			return "Infant"
		STAGE_CHILD:
			return "Child"
		STAGE_STUDENT:
			return "Student"
		STAGE_ADULT:
			return "Adult"
		STAGE_ELDER:
			return "Elder"
		_:
			return "Unknown"

func get_activity_name() -> String:
	match current_activity:
		ACTIVITY_SLEEPING:
			return "Sleeping"
		ACTIVITY_TRAVELING:
			return "Traveling"
		ACTIVITY_WORKING:
			return "Working"
		ACTIVITY_STUDYING:
			return "Studying"
		ACTIVITY_EATING:
			return "Eating"
		ACTIVITY_HYGIENE:
			return "Hygiene"
		ACTIVITY_RECREATING:
			return "Recreating"
		ACTIVITY_IDLE:
			return "Idle"
		_:
			return "Unknown"

func start_travel(destination_room_id: int, target_activity: int, travel_ticks: int) -> void:
	if travel_ticks <= 0:
		current_location_id = destination_room_id
		current_activity = target_activity
		target_location_id = 0
		travel_ticks_remaining = 0
		target_activity_after_travel = ACTIVITY_IDLE
	else:
		current_activity = ACTIVITY_TRAVELING
		target_location_id = destination_room_id
		travel_ticks_remaining = travel_ticks
		target_activity_after_travel = target_activity

## Steps travel down by 1 tick; returns true if arrived this tick
func step_travel() -> bool:
	if current_activity != ACTIVITY_TRAVELING:
		return false
	travel_ticks_remaining -= 1
	if travel_ticks_remaining <= 0:
		current_location_id = target_location_id
		current_activity = target_activity_after_travel
		target_location_id = 0
		travel_ticks_remaining = 0
		target_activity_after_travel = ACTIVITY_IDLE
		return true
	return false

func drink_water(liters: float) -> void:
	if liters <= 0.0:
		return
	# 1.0 L provides +40% hydration
	hydration_percent = minf(100.0, hydration_percent + (liters * 40.0))
	if hydration_percent >= 20.0:
		dehydration_ticks = 0

func apply_metabolic_decay(dt_ticks: int = 1) -> void:
	if not is_alive or dt_ticks <= 0:
		return
	# Decay ~0.2315% per tick (~100% over 432 ticks / 3 days without water)
	var decay: float = 0.231481 * float(dt_ticks)
	hydration_percent = maxf(0.0, hydration_percent - decay)
	
	if hydration_percent < 20.0:
		dehydration_ticks += dt_ticks
		if hydration_percent <= 0.001:
			# Health degradation when completely dehydrated for > 1 day (144 ticks)
			if dehydration_ticks > 144:
				health_percent = maxf(0.0, health_percent - (0.5 * float(dt_ticks)))
				if health_percent <= 0.0:
					is_alive = false

func is_severely_dehydrated() -> bool:
	return hydration_percent < 20.0

func add_education(amount: float) -> void:
	if amount <= 0.0:
		return
	education_score = minf(100.0, education_score + amount)

func add_tenure(ticks: int = 1) -> void:
	if ticks <= 0:
		return
	tenure_ticks += ticks
	seniority_level = tenure_ticks / (5 * SimClock.TICKS_PER_YEAR) # 1 seniority level per 5 years

func graduate(new_job_id: String, new_dept_id: String, new_workplace_id: int, new_shift: int = 1) -> void:
	occupation_id = new_job_id
	department_id = new_dept_id
	workplace_room_id = new_workplace_id
	school_room_id = 0
	shift_id = new_shift
	life_stage = STAGE_ADULT

func retire() -> void:
	occupation_id = "retired"
	department_id = ""
	workplace_room_id = 0
	school_room_id = 0
	shift_id = Occupation.SHIFT_OFF
	life_stage = STAGE_ELDER

func die() -> void:
	is_alive = false
	current_activity = ACTIVITY_IDLE
	workplace_room_id = 0
	school_room_id = 0

func record_opinion_memory(
	event_type: String,
	current_tick: int,
	dept: String,
	impact: float,
	desc: String,
	source_id: int = 0
) -> void:
	var mem: Dictionary = {
		"event_type": event_type,
		"onset_tick": current_tick,
		"attribution_dept": dept,
		"emotional_impact": clampf(impact, -1.0, 1.0),
		"salience": 1.0,
		"description": desc,
		"source_entity_id": source_id
	}
	opinion_memories.append(mem)
	if opinion_memories.size() > 50:
		opinion_memories.pop_front()
	recalculate_political_attitudes(current_tick)

func recalculate_political_attitudes(current_tick: int) -> void:
	var base_trust: float = 0.5
	var base_fairness: float = 0.5
	var base_security: float = 0.5
	var base_satisfaction: float = 0.5
	var base_resentment: float = 0.0
	
	var base_lead: float = 0.5
	var base_it: float = 0.5
	var base_sec: float = 0.5
	var base_eng: float = 0.5
	
	base_satisfaction += float(seniority_level) * 0.05
	base_fairness += float(security_clearance) * 0.03
	base_lead += float(security_clearance) * 0.05
	
	var delta_trust: float = 0.0
	var delta_fairness: float = 0.0
	var delta_security: float = 0.0
	var delta_satisfaction: float = 0.0
	var delta_resentment: float = 0.0
	
	var delta_lead: float = 0.0
	var delta_it: float = 0.0
	var delta_sec: float = 0.0
	var delta_eng: float = 0.0
	
	for mem in opinion_memories:
		var age: int = maxi(0, current_tick - int(mem.get("onset_tick", 0)))
		var halflifes: float = float(age) / float(OpinionMemory.HALF_LIFE_TICKS)
		var salience: float = pow(0.5, halflifes)
		mem["salience"] = salience
		
		var imp: float = float(mem.get("emotional_impact", 0.0)) * salience
		var dept: String = str(mem.get("attribution_dept", ""))
		var ev_type: String = str(mem.get("event_type", ""))
		
		delta_trust += imp * 0.35
		delta_satisfaction += imp * 0.30
		
		match dept:
			PoliticalEvent.DEPT_ADMINISTRATION:
				delta_lead += imp * 0.5
			PoliticalEvent.DEPT_ENGINEERING, PoliticalEvent.DEPT_UTILITIES:
				delta_eng += imp * 0.5
			PoliticalEvent.DEPT_SECURITY:
				delta_sec += imp * 0.5
				delta_security += imp * 0.4
			PoliticalEvent.DEPT_IT:
				delta_it += imp * 0.5
				
		match ev_type:
			PoliticalEvent.EVENT_FAMILY_BEREAVEMENT:
				delta_security += imp * 0.5
				delta_fairness += imp * 0.3
			PoliticalEvent.EVENT_HOUSING_OVERCROWDED:
				delta_resentment -= imp * 0.5
				delta_fairness += imp * 0.4
			PoliticalEvent.EVENT_HOUSING_UPGRADED:
				delta_fairness += imp * 0.3
				delta_resentment -= imp * 0.3
			PoliticalEvent.EVENT_DEMOTION_PENALTY:
				delta_resentment -= imp * 0.6
				delta_fairness += imp * 0.5
			PoliticalEvent.EVENT_COERCIVE_ORDER:
				delta_trust += imp * 0.4
				delta_fairness += imp * 0.3
			PoliticalEvent.EVENT_CRISIS_RESOLVED:
				delta_security += imp * 0.4
				delta_lead += imp * 0.3
			PoliticalEvent.EVENT_CORRUPTION_DISCOVERED:
				delta_trust += imp * 0.5 # imp is negative
				delta_fairness += imp * 0.5
				delta_lead += imp * 0.4
				delta_resentment -= imp * 0.4
			PoliticalEvent.EVENT_NEPOTISM_PASSED_OVER:
				delta_fairness += imp * 0.6
				delta_resentment -= imp * 0.5
				delta_trust += imp * 0.3
			PoliticalEvent.EVENT_FAVOUR_GRANTED:
				delta_satisfaction += imp * 0.4
			PoliticalEvent.EVENT_DISCIPLINARY_SANCTION:
				delta_trust += imp * 0.4
				delta_resentment -= imp * 0.6
				delta_fairness += imp * 0.3
				
	institutional_trust = clampf(base_trust + delta_trust, 0.0, 1.0)
	perceived_fairness = clampf(base_fairness + delta_fairness, 0.0, 1.0)
	perceived_security = clampf(base_security + delta_security, 0.0, 1.0)
	economic_satisfaction = clampf(base_satisfaction + delta_satisfaction, 0.0, 1.0)
	class_resentment = clampf(base_resentment + delta_resentment, 0.0, 1.0)
	
	confidence_leadership = clampf(base_lead + delta_lead, 0.0, 1.0)
	confidence_it = clampf(base_it + delta_it, 0.0, 1.0)
	confidence_security = clampf(base_sec + delta_sec, 0.0, 1.0)
	confidence_engineering = clampf(base_eng + delta_eng, 0.0, 1.0)

func record_belief(event_id: String, belief: CitizenBelief) -> void:
	beliefs[event_id] = belief

func get_belief(event_id: String) -> CitizenBelief:
	return beliefs.get(event_id, null) as CitizenBelief

func has_belief(event_id: String) -> bool:
	return beliefs.has(event_id)

func record_direct_experience(event_id: String, topic: String, truth: Dictionary) -> void:
	var b: CitizenBelief = CitizenBelief.new(event_id, topic, true, truth)
	beliefs[event_id] = b

func serialize() -> Dictionary:
	var memories_data: Array[Dictionary] = []
	for m in opinion_memories:
		memories_data.append(m.duplicate())
		
	var beliefs_data: Dictionary = {}
	for k in beliefs.keys():
		var b: CitizenBelief = beliefs[k] as CitizenBelief
		if b:
			beliefs_data[k] = b.serialize()

	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"sex": sex,
		"birth_tick": birth_tick,
		"life_stage": life_stage,
		"parent_ids": parent_ids.duplicate(),
		"children_ids": children_ids.duplicate(),
		"partner_id": partner_id,
		"household_id": household_id,
		"home_room_id": home_room_id,
		"bed_id": bed_id,
		"is_alive": is_alive,
		"hydration_percent": hydration_percent,
		"health_percent": health_percent,
		"dehydration_ticks": dehydration_ticks,
		"education_score": education_score,
		"tenure_ticks": tenure_ticks,
		"seniority_level": seniority_level,
		"security_clearance": security_clearance,
		"occupation_id": occupation_id,
		"department_id": department_id,
		"shift_id": shift_id,
		"workplace_room_id": workplace_room_id,
		"school_room_id": school_room_id,
		"canteen_room_id": canteen_room_id,
		"current_activity": current_activity,
		"current_location_id": current_location_id,
		"target_location_id": target_location_id,
		"travel_ticks_remaining": travel_ticks_remaining,
		"target_activity_after_travel": target_activity_after_travel,
		"institutional_trust": institutional_trust,
		"perceived_fairness": perceived_fairness,
		"perceived_security": perceived_security,
		"economic_satisfaction": economic_satisfaction,
		"class_resentment": class_resentment,
		"confidence_leadership": confidence_leadership,
		"confidence_it": confidence_it,
		"confidence_security": confidence_security,
		"confidence_engineering": confidence_engineering,
		"tolerance_coercion": tolerance_coercion,
		"preference_stability": preference_stability,
		"preference_reform": preference_reform,
		"preference_autonomy": preference_autonomy,
		"preference_equality": preference_equality,
		"preference_hierarchy": preference_hierarchy,
		"faction_id": faction_id,
		"sympathiser_faction_id": sympathiser_faction_id,
		"opinion_memories": memories_data,
		"beliefs": beliefs_data
	}

func deserialize(data: Dictionary) -> void:
	id = data.get("id", 0)
	first_name = data.get("first_name", "")
	last_name = data.get("last_name", "")
	sex = data.get("sex", SEX_FEMALE)
	birth_tick = data.get("birth_tick", 0)
	life_stage = data.get("life_stage", STAGE_ADULT)
	
	parent_ids = []
	for pid in data.get("parent_ids", []):
		parent_ids.append(int(pid))
		
	children_ids = []
	for cid in data.get("children_ids", []):
		children_ids.append(int(cid))
		
	partner_id = data.get("partner_id", 0)
	household_id = data.get("household_id", 0)
	home_room_id = data.get("home_room_id", 0)
	bed_id = data.get("bed_id", -1)
	is_alive = data.get("is_alive", true)
	hydration_percent = float(data.get("hydration_percent", 100.0))
	health_percent = float(data.get("health_percent", 100.0))
	dehydration_ticks = int(data.get("dehydration_ticks", 0))
	education_score = float(data.get("education_score", 0.0))
	tenure_ticks = int(data.get("tenure_ticks", 0))
	seniority_level = int(data.get("seniority_level", 0))
	security_clearance = int(data.get("security_clearance", 0))
	
	occupation_id = data.get("occupation_id", "unassigned")
	department_id = data.get("department_id", "")
	shift_id = data.get("shift_id", 1)
	workplace_room_id = data.get("workplace_room_id", 0)
	school_room_id = data.get("school_room_id", 0)
	canteen_room_id = data.get("canteen_room_id", 0)
	
	current_activity = data.get("current_activity", ACTIVITY_SLEEPING)
	current_location_id = data.get("current_location_id", home_room_id)
	target_location_id = data.get("target_location_id", 0)
	travel_ticks_remaining = data.get("travel_ticks_remaining", 0)
	target_activity_after_travel = data.get("target_activity_after_travel", ACTIVITY_IDLE)
	
	institutional_trust = float(data.get("institutional_trust", 0.5))
	perceived_fairness = float(data.get("perceived_fairness", 0.5))
	perceived_security = float(data.get("perceived_security", 0.5))
	economic_satisfaction = float(data.get("economic_satisfaction", 0.5))
	class_resentment = float(data.get("class_resentment", 0.0))
	confidence_leadership = float(data.get("confidence_leadership", 0.5))
	confidence_it = float(data.get("confidence_it", 0.5))
	confidence_security = float(data.get("confidence_security", 0.5))
	confidence_engineering = float(data.get("confidence_engineering", 0.5))
	tolerance_coercion = float(data.get("tolerance_coercion", 0.3))
	preference_stability = float(data.get("preference_stability", 0.6))
	preference_reform = float(data.get("preference_reform", 0.4))
	preference_autonomy = float(data.get("preference_autonomy", 0.5))
	preference_equality = float(data.get("preference_equality", 0.5))
	preference_hierarchy = float(data.get("preference_hierarchy", 0.5))
	faction_id = int(data.get("faction_id", 0))
	sympathiser_faction_id = int(data.get("sympathiser_faction_id", 0))
	
	opinion_memories = []
	for m in data.get("opinion_memories", []):
		if m is Dictionary:
			opinion_memories.append(m.duplicate())
			
	beliefs = {}
	var b_data: Dictionary = data.get("beliefs", {})
	for k in b_data.keys():
		var b_dict: Dictionary = b_data[k] as Dictionary
		if b_dict:
			var cb: CitizenBelief = CitizenBelief.new()
			cb.deserialize(b_dict)
			beliefs[k] = cb
