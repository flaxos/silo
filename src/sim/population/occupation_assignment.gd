# src/sim/population/occupation_assignment.gd
class_name OccupationAssignment
extends RefCounted

## Spawns necessary functional rooms and assigns occupations, shifts, workplaces, and schools to all residents
static func setup_workplaces_and_assignments(world_state: WorldState) -> Dictionary:
	var registry: EntityRegistry = world_state.entity_registry
	var rng: SeededRandom = world_state.rng
	var current_tick: int = world_state.sim_clock.get_tick()
	
	# 1. Create Functional Facilities across sectors
	var facility_rooms: Dictionary = _create_functional_rooms(world_state)
	
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	var adult_jobs: Array[String] = [
		"miner", "miner", "miner", "miner", "miner",
		"furnace_operator", "foundry_worker", "foundry_worker",
		"machinist", "machinist", "machinist", "welder",
		"maintenance_technician", "maintenance_technician", "electrician",
		"it_technician",
		"doctor", "nurse", "nurse",
		"teacher", "teacher",
		"cook", "cook",
		"sanitation_worker"
	]
	
	var stats: Dictionary = {
		"students": 0,
		"workers": 0,
		"retired": 0,
		"infants": 0,
		"facilities_created": facility_rooms.size()
	}
	
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if not p:
			continue
			
		# Initialize initial location to home room
		p.current_location_id = p.home_room_id
		p.current_activity = Person.ACTIVITY_SLEEPING
		p.canteen_room_id = _get_closest_facility(world_state, p.home_room_id, Room.TYPE_CANTEEN)
		
		var age: int = p.get_age_years(current_tick)
		
		if age < 6:
			# Toddlers / Infants
			p.occupation_id = "unassigned"
			p.department_id = ""
			p.shift_id = Occupation.SHIFT_OFF
			p.workplace_room_id = 0
			p.school_room_id = 0
			stats["infants"] += 1
		elif age < 18:
			# School-age children and students
			p.occupation_id = "student"
			p.department_id = Occupation.DEPT_EDUCATION
			p.shift_id = Occupation.SHIFT_DAY
			p.workplace_room_id = 0
			p.school_room_id = _get_closest_facility(world_state, p.home_room_id, Room.TYPE_SCHOOL)
			stats["students"] += 1
		elif age >= 65:
			# Elders
			p.occupation_id = "retired"
			p.department_id = ""
			p.shift_id = Occupation.SHIFT_OFF
			p.workplace_room_id = 0
			p.school_room_id = 0
			stats["retired"] += 1
		else:
			# Working Adults (18 - 64)
			var job_key: String = rng.choice(adult_jobs)
			var job_def: Dictionary = Occupation.OCCUPATION_DEFINITIONS.get(job_key, {})
			p.occupation_id = job_key
			p.department_id = job_def.get("department", "")
			
			var allowed_shifts: Array = job_def.get("shifts", [Occupation.SHIFT_DAY])
			if allowed_shifts.size() > 1 and rng.rand_chance(0.20):
				p.shift_id = rng.choice(allowed_shifts)
			else:
				p.shift_id = allowed_shifts[0]
				
			var room_type: int = job_def.get("room_type", Room.TYPE_MACHINE_SHOP)
			p.workplace_room_id = _get_closest_facility(world_state, p.home_room_id, room_type)
			p.school_room_id = 0
			stats["workers"] += 1
			
	return stats

static func _create_functional_rooms(world_state: WorldState) -> Dictionary:
	var registry: EntityRegistry = world_state.entity_registry
	var rooms_created: Dictionary = {}
	
	# Define core standard functional rooms
	var specs: Array[Dictionary] = [
		{"type": Room.TYPE_CANTEEN, "sector": 1, "level": 3, "cap": 50},
		{"type": Room.TYPE_CANTEEN, "sector": 2, "level": 3, "cap": 50},
		{"type": Room.TYPE_CANTEEN, "sector": 3, "level": 3, "cap": 50},
		{"type": Room.TYPE_CANTEEN, "sector": 4, "level": 3, "cap": 50},
		{"type": Room.TYPE_SCHOOL, "sector": 1, "level": 2, "cap": 40},
		{"type": Room.TYPE_SCHOOL, "sector": 2, "level": 2, "cap": 40},
		{"type": Room.TYPE_CLINIC, "sector": 1, "level": 4, "cap": 20},
		{"type": Room.TYPE_KITCHEN, "sector": 1, "level": 3, "cap": 20},
		{"type": Room.TYPE_HYGIENE_FACILITY, "sector": 1, "level": 1, "cap": 30},
		{"type": Room.TYPE_SERVER_ROOM, "sector": 1, "level": 5, "cap": 15},
		{"type": Room.TYPE_MACHINE_SHOP, "sector": 3, "level": 6, "cap": 40},
		{"type": Room.TYPE_FOUNDRY, "sector": 3, "level": 10, "cap": 30},
		{"type": Room.TYPE_DEEP_MINE, "sector": 4, "level": 15, "cap": 60},
		{"type": Room.TYPE_WATER_PUMP_STATION, "sector": 4, "level": 18, "cap": 20},
	]
	
	for spec in specs:
		var r: Room = Room.new(0, spec["type"], 0, spec["sector"], spec["level"])
		r.capacity_people = spec["cap"]
		r.id = registry.register_entity("room", r)
		rooms_created[r.id] = r
		
		if r.room_type == Room.TYPE_WATER_PUMP_STATION:
			var pump: WaterPump = WaterPump.new(0, r.id)
			pump.id = registry.register_entity("machine", pump)
		
	return rooms_created

static func _get_closest_facility(world_state: WorldState, home_room_id: int, target_room_type: int) -> int:
	var registry: EntityRegistry = world_state.entity_registry
	var all_room_ids: Array[int] = registry.get_entities_by_type("room")
	var home_room: Room = registry.get_entity(home_room_id) as Room
	
	var best_room_id: int = 0
	var min_distance: int = 999999
	
	for rid in all_room_ids:
		var r: Room = registry.get_entity(rid) as Room
		if r and r.room_type == target_room_type:
			if not home_room:
				return rid
			var dist: int = abs(home_room.sector_id - r.sector_id) * 10 + abs(home_room.level - r.level)
			if dist < min_distance:
				min_distance = dist
				best_room_id = rid
				
	return best_room_id
