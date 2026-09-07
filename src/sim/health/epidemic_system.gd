# src/sim/health/epidemic_system.gd
class_name EpidemicSystem
extends BaseSystem

const Pathogen = preload("res://src/sim/health/pathogen.gd")

const SYSTEM_ID: String = "epidemics"
const EXECUTION_ORDER: int = 46

var pathogens: Dictionary = {} # String id -> Pathogen
var total_infections: int = 0
var total_recoveries: int = 0
var total_fatalities: int = 0

func _init() -> void:
	super(SYSTEM_ID, EXECUTION_ORDER)
	pathogens = {}
	total_infections = 0
	total_recoveries = 0
	total_fatalities = 0
	
	# Register default baseline respiratory pathogen
	var default_flu: Pathogen = Pathogen.new("silo_cough", "Silo Respiratory Cough")
	pathogens[default_flu.id] = default_flu

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws.custom_data.has("pathogens"):
		ws.custom_data["pathogens"] = pathogens
	else:
		pathogens = ws.custom_data["pathogens"]

func start_outbreak(ws: WorldState, pathogen_id: String, patient_zero_id: int = 0) -> int:
	var registry: EntityRegistry = ws.entity_registry
	var p: Person = null
	if patient_zero_id > 0:
		p = registry.get_entity(patient_zero_id) as Person
	else:
		var pids: Array[int] = registry.get_entities_by_type("person")
		for pid in pids:
			var candidate: Person = registry.get_entity(pid) as Person
			if candidate and candidate.is_alive and candidate.life_stage == Person.STAGE_ADULT:
				p = candidate
				break
				
	if not p:
		return 0
		
	p.infection_stage = Person.INFECTION_INFECTIOUS
	p.infection_tick = ws.sim_clock.get_tick()
	p.pathogen_id = pathogen_id
	total_infections += 1
	return p.id

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	var clock: SimClock = ws.sim_clock
	var current_tick: int = clock.get_tick()
	
	# 1. Evaluate contacts and transmission every hour (6 ticks)
	if current_tick % 6 == 0:
		_evaluate_transmissions(ws, current_tick)
		
	# 2. Disease progression and clinical care every 6 ticks
	if current_tick % 6 == 0:
		_progress_infections(ws, current_tick)
		
	# 3. Institutional interventions (quarantine & childcare constraints)
	_apply_interventions(ws)

func _evaluate_transmissions(ws: WorldState, current_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var rng: SeededRandom = ws.rng
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	var infectious_persons: Array[Person] = []
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and (p.infection_stage == Person.INFECTION_INFECTIOUS or p.infection_stage == Person.INFECTION_SYMPTOMATIC):
			if not p.is_quarantined:
				infectious_persons.append(p)
				
	if infectious_persons.is_empty():
		return
		
	var schools_closed: bool = ws.custom_data.get("schools_closed", false)
	
	for carrier in infectious_persons:
		var pathogen: Pathogen = pathogens.get(carrier.pathogen_id, null)
		if not pathogen:
			continue
			
		var base_rate: float = pathogen.base_transmission_rate
		
		# A. Household transmission
		if carrier.household_id > 0:
			var hh: Household = registry.get_entity(carrier.household_id) as Household
			if hh:
				for mid in hh.member_ids:
					if mid == carrier.id:
						continue
					var mate: Person = registry.get_entity(mid) as Person
					if mate and mate.is_alive and mate.infection_stage == Person.INFECTION_SUSCEPTIBLE:
						if rng.rand_chance(base_rate * 0.40):
							_infect_person(mate, pathogen.id, current_tick)
							
		# B. Workplace transmission
		if carrier.workplace_room_id > 0 and carrier.current_activity == Person.ACTIVITY_WORKING:
			for pid in pids:
				if pid == carrier.id:
					continue
				var coworker: Person = registry.get_entity(pid) as Person
				if coworker and coworker.is_alive and coworker.workplace_room_id == carrier.workplace_room_id and coworker.current_activity == Person.ACTIVITY_WORKING:
					if coworker.infection_stage == Person.INFECTION_SUSCEPTIBLE:
						if rng.rand_chance(base_rate * 0.20):
							_infect_person(coworker, pathogen.id, current_tick)
							
		# C. School transmission
		if not schools_closed and carrier.school_room_id > 0 and carrier.current_activity == Person.ACTIVITY_STUDYING:
			for pid in pids:
				if pid == carrier.id:
					continue
				var student: Person = registry.get_entity(pid) as Person
				if student and student.is_alive and student.school_room_id == carrier.school_room_id and student.current_activity == Person.ACTIVITY_STUDYING:
					if student.infection_stage == Person.INFECTION_SUSCEPTIBLE:
						if rng.rand_chance(base_rate * 0.25):
							_infect_person(student, pathogen.id, current_tick)

func _infect_person(p: Person, pathogen_id: String, current_tick: int) -> void:
	p.infection_stage = Person.INFECTION_EXPOSED
	p.infection_tick = current_tick
	p.pathogen_id = pathogen_id
	total_infections += 1

func _progress_infections(ws: WorldState, current_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var rng: SeededRandom = ws.rng
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	# Determine clinic capacity & medical staffing
	var clinic_beds: int = 0
	var medical_staff: int = 0
	var rids: Array[int] = registry.get_entities_by_type("room")
	for rid in rids:
		var room: Room = registry.get_entity(rid) as Room
		if room and room.room_type == Room.TYPE_CLINIC:
			clinic_beds += room.bed_count
			
	for pid in pids:
		var worker: Person = registry.get_entity(pid) as Person
		if worker and worker.is_alive and (worker.occupation_id == "doctor" or worker.occupation_id == "nurse") and worker.current_activity == Person.ACTIVITY_WORKING:
			medical_staff += 1
			
	var patients_treated: int = 0
	var max_treatment_capacity: int = mini(clinic_beds, medical_staff * 5)
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive or p.infection_stage == Person.INFECTION_SUSCEPTIBLE:
			continue
			
		var pathogen: Pathogen = pathogens.get(p.pathogen_id, null)
		if not pathogen:
			continue
			
		var elapsed_ticks: int = current_tick - p.infection_tick
		
		# Exposed -> Infectious
		if p.infection_stage == Person.INFECTION_EXPOSED:
			if elapsed_ticks >= pathogen.incubation_ticks:
				p.infection_stage = Person.INFECTION_INFECTIOUS
				
		# Infectious -> Symptomatic
		elif p.infection_stage == Person.INFECTION_INFECTIOUS:
			if elapsed_ticks >= (pathogen.incubation_ticks + pathogen.infectious_ticks):
				p.infection_stage = Person.INFECTION_SYMPTOMATIC
				p.absent_from_work = true # Sick leave, withdraws labor
				
		# Symptomatic -> Recovery or Death
		elif p.infection_stage == Person.INFECTION_SYMPTOMATIC:
			var is_treated: bool = (patients_treated < max_treatment_capacity)
			if is_treated:
				patients_treated += 1
				
			p.health_percent = maxf(0.0, p.health_percent - (pathogen.severity * (0.5 if is_treated else 1.0)))
			
			# Mortality check
			var mortality_chance: float = pathogen.mortality_rate * (0.2 if is_treated else 1.0) / 24.0
			if p.health_percent <= 0.0 or rng.rand_chance(mortality_chance):
				p.die()
				total_fatalities += 1
				continue
				
			# Recovery check
			if elapsed_ticks >= (pathogen.incubation_ticks + pathogen.infectious_ticks + pathogen.symptomatic_ticks):
				p.infection_stage = Person.INFECTION_RECOVERED
				p.absent_from_work = false
				p.is_quarantined = false
				p.health_percent = minf(100.0, p.health_percent + 50.0)
				total_recoveries += 1
				
		# Recovered -> Susceptible (Immunity wanes)
		elif p.infection_stage == Person.INFECTION_RECOVERED:
			if elapsed_ticks >= (pathogen.incubation_ticks + pathogen.infectious_ticks + pathogen.symptomatic_ticks + pathogen.immunity_ticks):
				p.infection_stage = Person.INFECTION_SUSCEPTIBLE
				p.pathogen_id = ""

func _apply_interventions(ws: WorldState) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	var quarantine_active: bool = ws.custom_data.get("quarantine_active", false)
	var schools_closed: bool = ws.custom_data.get("schools_closed", false)
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		# Quarantine enforcement: isolate symptomatic or infectious citizens
		if quarantine_active and (p.infection_stage in [Person.INFECTION_INFECTIOUS, Person.INFECTION_SYMPTOMATIC]):
			p.is_quarantined = true
			p.absent_from_work = true
		elif not quarantine_active and p.infection_stage != Person.INFECTION_SYMPTOMATIC:
			p.is_quarantined = false
			
		# School closure childcare constraint: parent withdraws labor
		if schools_closed and p.life_stage == Person.STAGE_ADULT and not p.children_ids.is_empty():
			p.absent_from_work = true

func serialize() -> Dictionary:
	var pats_data: Array[Dictionary] = []
	for k in pathogens:
		pats_data.append(pathogens[k].serialize())
	return {
		"system_id": SYSTEM_ID,
		"execution_order": execution_order,
		"pathogens": pats_data,
		"total_infections": total_infections,
		"total_recoveries": total_recoveries,
		"total_fatalities": total_fatalities
	}

func deserialize(data: Dictionary) -> void:
	execution_order = int(data.get("execution_order", 46))
	total_infections = int(data.get("total_infections", 0))
	total_recoveries = int(data.get("total_recoveries", 0))
	total_fatalities = int(data.get("total_fatalities", 0))
	pathogens.clear()
	for p_data in data.get("pathogens", []):
		var p: Pathogen = Pathogen.new()
		p.deserialize(p_data)
		pathogens[p.id] = p
