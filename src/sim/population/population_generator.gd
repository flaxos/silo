# src/sim/population/population_generator.gd
class_name PopulationGenerator
extends RefCounted

const FIRST_NAMES_FEMALE: Array[String] = [
	"Elena", "Maya", "Sarah", "Clara", "Nora", "Leah", "Iris", "Eva", "Rosa", "Anna",
	"Hanna", "Sofia", "Lydia", "Mira", "Vera", "Diana", "Astrid", "Naomi", "Greta", "Freja",
	"Ruth", "Esther", "Talia", "Judith", "Ada", "Karin", "Mara", "Nina", "Sylvia", "Celia",
	"Valerie", "Monica", "Theresa", "Mina", "Elise", "Paula", "Zoe", "Chloe", "Ingrid", "Helena"
]

const FIRST_NAMES_MALE: Array[String] = [
	"Marcus", "David", "Lucas", "Jonas", "Tobias", "Victor", "Felix", "Gabriel", "Julian", "Leon",
	"Simon", "Arthur", "Adam", "Elias", "Mateo", "Hugo", "Oscar", "Samuel", "Ruben", "Daniel",
	"Anton", "Erik", "Otto", "Leo", "Vincent", "Noah", "Liam", "Theodore", "Silas", "Caleb",
	"Emil", "Paul", "Aaron", "Walter", "Thomas", "Roman", "Nathan", "Dominic", "Ivan", "Stefan"
]

const SURNAMES: Array[String] = [
	"Vance", "Mercer", "Keller", "Brandt", "Holt", "Lind", "Kovacs", "Reyes", "Steele", "Chen",
	"Novak", "Fischer", "Sloan", "Harlan", "Frost", "Davenport", "Garrison", "Sterling", "Kowalski", "Richter",
	"Navarro", "Sorensen", "Duran", "Beck", "Castillo", "Mayer", "Sinclair", "Abbott", "Cross", "Fletcher",
	"Hardy", "Olsen", "Mercer", "Rowan", "Stratton", "Vaughn", "Weber", "Barrett", "Donovan", "Mercer",
	"Solomon", "Lowell", "Rasmussen", "Loomis", "Carver", "Kearney", "Calloway", "Dunne", "Aldridge", "Vogel"
]

## Generates a complete population of target_count residents in the given WorldState
static func generate_population(world_state: WorldState, target_count: int = 1200) -> Dictionary:
	var rng: SeededRandom = world_state.rng
	var registry: EntityRegistry = world_state.entity_registry
	var current_tick: int = world_state.sim_clock.get_tick()
	
	var people_created: int = 0
	var sector_counter: int = 1
	var level_counter: int = 1
	
	while people_created < target_count:
		var remaining: int = target_count - people_created
		
		# Choose household structure based on remaining slots
		if remaining >= 4 and rng.rand_chance(0.45):
			# Nuclear Family (3-5 people)
			var max_children: int = mini(3, remaining - 2)
			var child_count: int = rng.randi_range(1, max_children)
			people_created += _generate_nuclear_family(world_state, child_count, sector_counter, level_counter)
		elif remaining >= 4 and rng.rand_chance(0.25):
			# Multi-generational Family (4-6 people)
			var max_grandkids: int = mini(2, remaining - 3)
			var grandchild_count: int = rng.randi_range(1, maxi(1, max_grandkids))
			people_created += _generate_multigen_family(world_state, grandchild_count, sector_counter, level_counter)
		elif remaining >= 2 and rng.rand_chance(0.50):
			# Couple without children (2 people)
			people_created += _generate_couple(world_state, sector_counter, level_counter)
		else:
			# Single adult (1 person)
			people_created += _generate_single_adult(world_state, sector_counter, level_counter)
			
		level_counter += 1
		if level_counter > 20:
			level_counter = 1
			sector_counter += 1
			
	return PopulationInvariants.validate(world_state)

static func _generate_nuclear_family(world_state: WorldState, child_count: int, sector: int, level: int) -> int:
	var rng: SeededRandom = world_state.rng
	var registry: EntityRegistry = world_state.entity_registry
	var surname: String = rng.choice(SURNAMES)
	
	var father_age: int = rng.randi_range(28, 52)
	var mother_age: int = clampi(father_age + rng.randi_range(-4, 4), 25, 50)
	
	var father: Person = _create_person(world_state, rng.choice(FIRST_NAMES_MALE), surname, Person.SEX_MALE, father_age)
	var mother: Person = _create_person(world_state, rng.choice(FIRST_NAMES_FEMALE), surname, Person.SEX_FEMALE, mother_age)
	
	# Partner linkage
	father.partner_id = mother.id
	mother.partner_id = father.id
	
	var members: Array[Person] = [father, mother]
	
	# Generate children with plausible age spacing
	var max_child_age: int = mini(mother_age - 18, 17)
	var current_child_age_bound: int = max_child_age
	
	for i in range(child_count):
		if current_child_age_bound < 0:
			current_child_age_bound = 0
		var child_age: int = rng.randi_range(maxi(0, current_child_age_bound - 3), current_child_age_bound)
		var child_sex: int = Person.SEX_FEMALE if rng.rand_chance(0.5) else Person.SEX_MALE
		var first_pool: Array[String] = FIRST_NAMES_FEMALE if child_sex == Person.SEX_FEMALE else FIRST_NAMES_MALE
		var child: Person = _create_person(world_state, rng.choice(first_pool), surname, child_sex, child_age)
		
		# Genealogical linkage
		child.parent_ids = [father.id, mother.id]
		father.children_ids.append(child.id)
		mother.children_ids.append(child.id)
		
		members.append(child)
		current_child_age_bound = child_age - 2
		
	_house_family(world_state, members, "%s Household" % surname, sector, level)
	return members.size()

static func _generate_multigen_family(world_state: WorldState, grandchild_count: int, sector: int, level: int) -> int:
	var rng: SeededRandom = world_state.rng
	var surname: String = rng.choice(SURNAMES)
	
	var gp_age: int = rng.randi_range(66, 82)
	var gp_sex: int = Person.SEX_FEMALE if rng.rand_chance(0.5) else Person.SEX_MALE
	var gp_first: String = rng.choice(FIRST_NAMES_FEMALE if gp_sex == Person.SEX_FEMALE else FIRST_NAMES_MALE)
	var grandparent: Person = _create_person(world_state, gp_first, surname, gp_sex, gp_age)
	
	var parent_age: int = gp_age - rng.randi_range(22, 32)
	var parent_sex: int = Person.SEX_MALE if gp_sex == Person.SEX_FEMALE else Person.SEX_FEMALE
	var parent_first: String = rng.choice(FIRST_NAMES_MALE if parent_sex == Person.SEX_MALE else FIRST_NAMES_FEMALE)
	var parent_a: Person = _create_person(world_state, parent_first, surname, parent_sex, parent_age)
	
	# Grandparent -> Parent link
	parent_a.parent_ids = [grandparent.id]
	grandparent.children_ids.append(parent_a.id)
	
	var spouse_sex: int = Person.SEX_FEMALE if parent_sex == Person.SEX_MALE else Person.SEX_MALE
	var spouse_age: int = clampi(parent_age + rng.randi_range(-3, 3), 32, 58)
	var spouse_first: String = rng.choice(FIRST_NAMES_FEMALE if spouse_sex == Person.SEX_FEMALE else FIRST_NAMES_MALE)
	var parent_b: Person = _create_person(world_state, spouse_first, surname, spouse_sex, spouse_age)
	
	# Marriage link
	parent_a.partner_id = parent_b.id
	parent_b.partner_id = parent_a.id
	
	var members: Array[Person] = [grandparent, parent_a, parent_b]
	
	var mother_age: int = parent_b.get_age_years(world_state.sim_clock.get_tick()) if spouse_sex == Person.SEX_FEMALE else parent_a.get_age_years(world_state.sim_clock.get_tick())
	var max_gc_age: int = mini(mother_age - 18, 17)
	var gc_bound: int = max_gc_age
	
	for i in range(grandchild_count):
		if gc_bound < 0:
			gc_bound = 0
		var gc_age: int = rng.randi_range(maxi(0, gc_bound - 3), gc_bound)
		var gc_sex: int = Person.SEX_FEMALE if rng.rand_chance(0.5) else Person.SEX_MALE
		var gc_first: String = rng.choice(FIRST_NAMES_FEMALE if gc_sex == Person.SEX_FEMALE else FIRST_NAMES_MALE)
		var gc: Person = _create_person(world_state, gc_first, surname, gc_sex, gc_age)
		
		gc.parent_ids = [parent_a.id, parent_b.id]
		parent_a.children_ids.append(gc.id)
		parent_b.children_ids.append(gc.id)
		
		members.append(gc)
		gc_bound = gc_age - 2
		
	_house_family(world_state, members, "%s Multi-Gen Family" % surname, sector, level)
	return members.size()

static func _generate_couple(world_state: WorldState, sector: int, level: int) -> int:
	var rng: SeededRandom = world_state.rng
	var surname: String = rng.choice(SURNAMES)
	
	var p1_age: int = rng.randi_range(22, 68)
	var p2_age: int = clampi(p1_age + rng.randi_range(-4, 4), 20, 72)
	
	var p1: Person = _create_person(world_state, rng.choice(FIRST_NAMES_MALE), surname, Person.SEX_MALE, p1_age)
	var p2: Person = _create_person(world_state, rng.choice(FIRST_NAMES_FEMALE), surname, Person.SEX_FEMALE, p2_age)
	
	p1.partner_id = p2.id
	p2.partner_id = p1.id
	
	var members: Array[Person] = [p1, p2]
	_house_family(world_state, members, "%s Household" % surname, sector, level)
	return 2

static func _generate_single_adult(world_state: WorldState, sector: int, level: int) -> int:
	var rng: SeededRandom = world_state.rng
	var surname: String = rng.choice(SURNAMES)
	var is_female: bool = rng.rand_chance(0.5)
	var first_name: String = rng.choice(FIRST_NAMES_FEMALE if is_female else FIRST_NAMES_MALE)
	var sex: int = Person.SEX_FEMALE if is_female else Person.SEX_MALE
	var age: int = rng.randi_range(18, 65)
	
	var person: Person = _create_person(world_state, first_name, surname, sex, age)
	var members: Array[Person] = [person]
	_house_family(world_state, members, "%s Residence" % surname, sector, level)
	return 1

static func _create_person(world_state: WorldState, first: String, last: String, sex: int, age_years: int) -> Person:
	var rng: SeededRandom = world_state.rng
	var day_offset: int = rng.randi_range(0, SimClock.DAYS_PER_YEAR - 1)
	var tick_offset: int = rng.randi_range(0, SimClock.TICKS_PER_DAY - 1)
	var total_ticks_lived: int = age_years * SimClock.TICKS_PER_YEAR + day_offset * SimClock.TICKS_PER_DAY + tick_offset
	var birth_tick: int = - total_ticks_lived
	
	var person: Person = Person.new(0, first, last, sex, birth_tick)
	person.id = world_state.entity_registry.register_entity("person", person)
	person.update_life_stage(world_state.sim_clock.get_tick())
	return person

static func _house_family(world_state: WorldState, members: Array[Person], household_name: String, sector: int, level: int) -> void:
	var registry: EntityRegistry = world_state.entity_registry
	var bed_count: int = maxi(2, members.size())
	
	# Create Room
	var room: Room = Room.new(0, Room.TYPE_RESIDENTIAL_APARTMENT, bed_count, sector, level)
	room.id = registry.register_entity("room", room)
	
	# Create Household
	var head_person: Person = members[0]
	# Prefer adult head
	for m in members:
		if m.life_stage == Person.STAGE_ADULT or m.life_stage == Person.STAGE_ELDER:
			head_person = m
			break
			
	var household: Household = Household.new(0, household_name, room.id, head_person.id)
	household.id = registry.register_entity("household", household)
	
	# Assign members to room, bed, and household
	for m in members:
		m.household_id = household.id
		m.home_room_id = room.id
		var bed_idx: int = room.allocate_bed(m.id)
		m.bed_id = bed_idx
		household.add_member(m.id)
