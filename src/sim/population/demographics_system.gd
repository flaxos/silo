# src/sim/population/demographics_system.gd
class_name DemographicsSystem
extends BaseSystem

const GeneticsModel = preload("res://src/sim/population/genetics_model.gd")

const SYSTEM_ID: String = "demographics"
const EXECUTION_ORDER: int = 40

const ESSENTIAL_OCCUPATIONS: Array[String] = [
	"miner", "furnace_operator", "foundry_worker", "machinist", "welder",
	"maintenance_technician", "electrician", "cook", "nurse", "doctor", "teacher"
]

var _cached_persons: Array[Person] = []
var _cached_person_count: int = 0
var _cached_school_rooms: Array[Room] = []
var _cached_functional_rooms: Dictionary = {} # int room_type -> Array[Room]
var _is_cached: bool = false

var total_births: int = 0
var total_deaths: int = 0
var total_graduations: int = 0
var total_retirements: int = 0
var total_marriages: int = 0

func _init() -> void:
	super(SYSTEM_ID, EXECUTION_ORDER)
	total_births = 0
	total_deaths = 0
	total_graduations = 0
	total_retirements = 0
	total_marriages = 0

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	_rebuild_caches(ws)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	var clock: SimClock = ws.sim_clock
	var current_tick: int = clock.get_tick()
	var tick_of_day: int = clock.get_tick_of_day()
	
	if not _is_cached or _cached_person_count == 0:
		_rebuild_caches(ws)
		
	# 1. Per-tick activities: education progression & tenure
	for i in range(_cached_person_count):
		var p: Person = _cached_persons[i]
		if not p.is_alive:
			continue
			
		if p.current_activity == Person.ACTIVITY_STUDYING:
			p.add_education(0.01)
		elif p.current_activity == Person.ACTIVITY_WORKING:
			p.add_tenure(1)
			
	# 2. Daily demographic processing (once per 144 ticks at midnight)
	if tick_of_day == 0:
		_process_daily_demographics(ws, current_tick)

func _process_daily_demographics(ws: WorldState, current_tick: int) -> void:
	var rng: SeededRandom = ws.rng
	var registry: EntityRegistry = ws.entity_registry
	
	# Pass 1: Life stage updates, school enrollment, graduation, retirement & mortality
	var single_adults_male: Array[Person] = []
	var single_adults_female: Array[Person] = []
	var fertile_couples: Array[Dictionary] = [] # {"father": Person, "mother": Person}
	
	# Snapshot list of living persons for safe iteration
	var living_persons: Array[Person] = []
	for i in range(_cached_person_count):
		var p: Person = _cached_persons[i]
		if p.is_alive:
			living_persons.append(p)
			
	for p in living_persons:
		var age_years: int = p.get_age_years(current_tick)
		p.update_life_stage(current_tick)
		
		# A. Mortality Check
		var death_prob: float = 0.0
		if age_years >= 85:
			death_prob = 0.0010
		elif age_years >= 75:
			death_prob = 0.0003
		elif age_years >= 65:
			death_prob = 0.00005
			
		if not p.is_alive or p.health_percent <= 0.001 or (death_prob > 0.0 and rng.randf() < death_prob):
			_handle_person_death(ws, p)
			total_deaths += 1
			continue
			
		# B. School Enrollment (Children reaching 6)
		if p.life_stage == Person.STAGE_CHILD and age_years >= 6 and p.occupation_id != "student":
			p.occupation_id = "student"
			p.department_id = Occupation.DEPT_EDUCATION
			p.shift_id = Occupation.SHIFT_DAY
			p.school_room_id = _get_closest_school(p.home_room_id)
			
		# C. Graduation (Students reaching 18)
		elif p.occupation_id == "student" and age_years >= 18:
			_graduate_student(ws, p)
			total_graduations += 1
			
		# D. Retirement (Adults reaching 65)
		elif p.life_stage == Person.STAGE_ELDER and age_years >= 65 and p.occupation_id != "retired" and p.occupation_id != "unassigned":
			p.retire()
			total_retirements += 1
			
		# E. Tally Partnership Candidates
		if p.is_alive and p.life_stage == Person.STAGE_ADULT and age_years >= 18 and age_years <= 50 and p.partner_id == 0:
			if p.sex == Person.SEX_MALE:
				single_adults_male.append(p)
			else:
				single_adults_female.append(p)
				
		# F. Tally Fertile Couples for Births
		if p.is_alive and p.sex == Person.SEX_FEMALE and p.partner_id > 0 and age_years >= 18 and age_years <= 42:
			var partner: Person = registry.get_entity(p.partner_id) as Person
			if partner and partner.is_alive and partner.sex == Person.SEX_MALE:
				fertile_couples.append({"father": partner, "mother": p})
				
	# Pass 2: Form Partnerships
	var match_count: int = mini(single_adults_male.size(), single_adults_female.size())
	for i in range(match_count):
		if rng.rand_chance(0.05): # 5% daily chance for unpartnered adults to form pair
			var male: Person = single_adults_male[i]
			var female: Person = single_adults_female[i]
			if male.partner_id == 0 and female.partner_id == 0:
				male.partner_id = female.id
				female.partner_id = male.id
				total_marriages += 1
				
	# Pass 3: Births (Demographic Renewal)
	for couple in fertile_couples:
		var mother: Person = couple["mother"] as Person
		var father: Person = couple["father"] as Person
		
		# Limit fertility based on existing children count (< 3 children per household)
		if mother.children_ids.size() < 3:
			# ~0.35 births per year per eligible couple -> ~0.0024 per day
			if rng.randf() < 0.0024:
				_spawn_birth(ws, father, mother, current_tick)
				total_births += 1
				
	_rebuild_caches(ws)

func _graduate_student(ws: WorldState, student: Person) -> void:
	var rng: SeededRandom = ws.rng
	# Select appropriate adult occupation
	var target_job: String = rng.choice(ESSENTIAL_OCCUPATIONS)
	var job_def: Dictionary = Occupation.OCCUPATION_DEFINITIONS.get(target_job, {})
	var dept: String = job_def.get("department", "")
	var room_type: int = job_def.get("room_type", Room.TYPE_MACHINE_SHOP)
	var allowed_shifts: Array = job_def.get("shifts", [Occupation.SHIFT_DAY])
	var shift: int = allowed_shifts[0]
	
	var workplace_id: int = _get_closest_facility(room_type, student.home_room_id)
	student.graduate(target_job, dept, workplace_id, shift)

func _spawn_birth(ws: WorldState, father: Person, mother: Person, current_tick: int) -> Person:
	var rng: SeededRandom = ws.rng
	var registry: EntityRegistry = ws.entity_registry
	
	var sex: int = Person.SEX_FEMALE if rng.rand_chance(0.50) else Person.SEX_MALE
	var first_name: String = rng.choice(PopulationGenerator.FIRST_NAMES_FEMALE) if sex == Person.SEX_FEMALE else rng.choice(PopulationGenerator.FIRST_NAMES_MALE)
	var surname: String = father.last_name if not father.last_name.is_empty() else mother.last_name
	
	var baby: Person = Person.new(0, first_name, surname, sex, current_tick)
	baby.life_stage = Person.STAGE_INFANT
	baby.parent_ids = [father.id, mother.id]
	baby.household_id = mother.household_id
	baby.home_room_id = mother.home_room_id
	baby.current_location_id = mother.home_room_id
	baby.current_activity = Person.ACTIVITY_SLEEPING
	
	# Genetic traits inheritance (Sprint 21)
	baby.blood_type = GeneticsModel.inherit_blood_type(father.blood_type, mother.blood_type, rng)
	var relatedness: float = GeneticsModel.compute_relatedness(registry, father, mother)
	var traits: Dictionary = GeneticsModel.inherit_traits(father, mother, rng, relatedness)
	baby.trait_stamina = float(traits.get("stamina", 1.0))
	baby.trait_resilience = float(traits.get("resilience", 1.0))
	baby.trait_metabolism = float(traits.get("metabolism", 1.0))
	baby.congenital_conditions = traits.get("conditions", [])
	if baby.congenital_conditions.has("congenital_frailty"):
		baby.health_percent = 85.0
	
	# Register entity
	baby.id = registry.register_entity("person", baby)
	
	# Reciprocal updates on parents
	if not father.children_ids.has(baby.id):
		father.children_ids.append(baby.id)
	if not mother.children_ids.has(baby.id):
		mother.children_ids.append(baby.id)
		
	# Allocate bed in mother's room if available
	if mother.home_room_id > 0:
		var room: Room = registry.get_entity(mother.home_room_id) as Room
		if room:
			baby.bed_id = room.allocate_bed(baby.id)
			
	# Add to household member roster
	if mother.household_id > 0:
		var hh: Household = registry.get_entity(mother.household_id) as Household
		if hh and not hh.member_ids.has(baby.id):
			hh.member_ids.append(baby.id)
			
	return baby

func _handle_person_death(ws: WorldState, person: Person) -> void:
	var registry: EntityRegistry = ws.entity_registry
	person.die()
	
	# 1. Free bed allocation
	if person.home_room_id > 0:
		var room: Room = registry.get_entity(person.home_room_id) as Room
		if room:
			room.free_bed(person.id)
		person.bed_id = -1
		
	# 2. Reciprocal partnership clear
	if person.partner_id > 0:
		var partner: Person = registry.get_entity(person.partner_id) as Person
		if partner and partner.partner_id == person.id:
			partner.partner_id = 0
		person.partner_id = 0
		
	# 3. Household head succession
	if person.household_id > 0:
		var hh: Household = registry.get_entity(person.household_id) as Household
		if hh and hh.head_id == person.id:
			_reassign_household_head(registry, hh)

func _reassign_household_head(registry: EntityRegistry, hh: Household) -> void:
	var new_head_id: int = 0
	for mid in hh.member_ids:
		var m: Person = registry.get_entity(mid) as Person
		if m and m.is_alive and m.life_stage >= Person.STAGE_ADULT:
			new_head_id = m.id
			break
	hh.head_id = new_head_id

func _get_closest_school(home_room_id: int) -> int:
	if _cached_school_rooms.is_empty():
		return 0
	return _cached_school_rooms[0].id

func _get_closest_facility(room_type: int, home_room_id: int) -> int:
	var list: Array = _cached_functional_rooms.get(room_type, [])
	if list.is_empty():
		return 0
	var r: Room = list[0] as Room
	return r.id

func _rebuild_caches(ws: WorldState) -> void:
	var registry: EntityRegistry = ws.entity_registry
	_cached_persons.clear()
	_cached_school_rooms.clear()
	_cached_functional_rooms.clear()
	
	var all_pids: Array[int] = registry.get_entities_by_type("person")
	for pid in all_pids:
		var p: Person = registry.get_entity(pid) as Person
		if p:
			_cached_persons.append(p)
	_cached_person_count = _cached_persons.size()
	
	var all_rids: Array[int] = registry.get_entities_by_type("room")
	for rid in all_rids:
		var r: Room = registry.get_entity(rid) as Room
		if r:
			if r.room_type == Room.TYPE_SCHOOL:
				_cached_school_rooms.append(r)
				
			if not _cached_functional_rooms.has(r.room_type):
				var arr: Array[Room] = []
				_cached_functional_rooms[r.room_type] = arr
			var type_arr: Array[Room] = _cached_functional_rooms[r.room_type]
			type_arr.append(r)
			
	_is_cached = true
