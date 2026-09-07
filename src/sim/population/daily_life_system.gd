# src/sim/population/daily_life_system.gd
class_name DailyLifeSystem
extends BaseSystem

const TravelModel = preload("res://src/sim/spatial/spatial_travel_model.gd")

# Fast spatial cache: int room_id -> Vector2i(sector_id, level)
var _room_spatial_cache: Dictionary = {}
var _cached_persons: Array[Person] = []
var _cached_person_count: int = 0

func _init() -> void:
	super("daily_life", 50)

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	_build_room_spatial_cache(ws)
	_rebuild_person_cache(ws)
	TravelModel.initialize(ws)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	var clock: SimClock = ws.sim_clock
	var tick_of_day: int = clock.get_tick_of_day()
	TravelModel.step(ws)
	
	if _cached_person_count == 0:
		_rebuild_person_cache(ws)
		_build_room_spatial_cache(ws)
	
	for i in range(_cached_person_count):
		var p: Person = _cached_persons[i]
		if not p.is_alive:
			continue
			
		# 1. Authoritative graph travel is progressed centrally above. Citizens in
		# transit wait for stair admission/arrival without per-person processing.
		if p.current_activity == Person.ACTIVITY_TRAVELING:
			continue
				
		# 2. Determine scheduled activity and destination room without dictionary allocation
		var desired_activity: int = Person.ACTIVITY_IDLE
		var desired_room_id: int = p.home_room_id
		var canteen_id: int = p.canteen_room_id if p.canteen_room_id > 0 else p.home_room_id
		
		if p.life_stage == Person.STAGE_INFANT or (p.life_stage == Person.STAGE_CHILD and p.occupation_id != "student"):
			# Infants / young children
			if tick_of_day >= 126 or tick_of_day < 42:
				desired_activity = Person.ACTIVITY_SLEEPING
			elif (tick_of_day >= 42 and tick_of_day < 48) or (tick_of_day >= 72 and tick_of_day < 78) or (tick_of_day >= 108 and tick_of_day < 114):
				desired_activity = Person.ACTIVITY_EATING
			else:
				desired_activity = Person.ACTIVITY_RECREATING
			desired_room_id = p.home_room_id
			
		elif p.occupation_id == "student":
			# Students
			var school_id: int = p.school_room_id if p.school_room_id > 0 else p.home_room_id
			if tick_of_day >= 132 or tick_of_day < 36:
				desired_activity = Person.ACTIVITY_SLEEPING
				desired_room_id = p.home_room_id
			elif tick_of_day >= 36 and tick_of_day < 42:
				desired_activity = Person.ACTIVITY_HYGIENE
				desired_room_id = p.home_room_id
			elif tick_of_day >= 42 and tick_of_day < 48:
				desired_activity = Person.ACTIVITY_EATING
				desired_room_id = canteen_id
			elif (tick_of_day >= 48 and tick_of_day < 72) or (tick_of_day >= 78 and tick_of_day < 90):
				desired_activity = Person.ACTIVITY_STUDYING
				desired_room_id = school_id
			elif tick_of_day >= 72 and tick_of_day < 78:
				desired_activity = Person.ACTIVITY_EATING
				desired_room_id = canteen_id
			elif tick_of_day >= 90 and tick_of_day < 108:
				desired_activity = Person.ACTIVITY_RECREATING
				desired_room_id = p.home_room_id
			elif tick_of_day >= 108 and tick_of_day < 114:
				desired_activity = Person.ACTIVITY_EATING
				desired_room_id = canteen_id
			else:
				desired_activity = Person.ACTIVITY_RECREATING
				desired_room_id = p.home_room_id
				
		elif p.life_stage == Person.STAGE_ELDER or p.shift_id == Occupation.SHIFT_OFF:
			# Elders / Off-duty
			if tick_of_day >= 132 or tick_of_day < 36:
				desired_activity = Person.ACTIVITY_SLEEPING
				desired_room_id = p.home_room_id
			elif tick_of_day >= 36 and tick_of_day < 42:
				desired_activity = Person.ACTIVITY_HYGIENE
				desired_room_id = p.home_room_id
			elif tick_of_day >= 42 and tick_of_day < 48:
				desired_activity = Person.ACTIVITY_EATING
				desired_room_id = canteen_id
			elif tick_of_day >= 72 and tick_of_day < 78:
				desired_activity = Person.ACTIVITY_EATING
				desired_room_id = canteen_id
			elif tick_of_day >= 108 and tick_of_day < 114:
				desired_activity = Person.ACTIVITY_EATING
				desired_room_id = canteen_id
			else:
				desired_activity = Person.ACTIVITY_RECREATING
				desired_room_id = p.home_room_id
				
		else:
			# Working adults by shift
			var work_id: int = p.workplace_room_id if p.workplace_room_id > 0 else p.home_room_id
			var work_end_tick: int = 96
			var shift_hours: int = int(ws.custom_data.get("shift_work_hours_day", 8))
			if shift_hours >= 12:
				work_end_tick = 120
			elif shift_hours >= 10:
				work_end_tick = 108
				
			match p.shift_id:
				Occupation.SHIFT_DAY:
					if tick_of_day >= 132 or tick_of_day < 36:
						desired_activity = Person.ACTIVITY_SLEEPING
						desired_room_id = p.home_room_id
					elif tick_of_day >= 36 and tick_of_day < 42:
						desired_activity = Person.ACTIVITY_HYGIENE
						desired_room_id = p.home_room_id
					elif tick_of_day >= 42 and tick_of_day < 48:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					elif (tick_of_day >= 48 and tick_of_day < 72) or (tick_of_day >= 78 and tick_of_day < work_end_tick):
						desired_activity = Person.ACTIVITY_WORKING
						desired_room_id = work_id
					elif tick_of_day >= 72 and tick_of_day < 78:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					elif tick_of_day >= work_end_tick and tick_of_day < 108:
						desired_activity = Person.ACTIVITY_RECREATING
						desired_room_id = p.home_room_id
					elif tick_of_day >= 108 and tick_of_day < 114:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					else:
						desired_activity = Person.ACTIVITY_RECREATING
						desired_room_id = p.home_room_id
						
				Occupation.SHIFT_SWING:
					if tick_of_day >= 6 and tick_of_day < 54:
						desired_activity = Person.ACTIVITY_SLEEPING
						desired_room_id = p.home_room_id
					elif tick_of_day >= 54 and tick_of_day < 60:
						desired_activity = Person.ACTIVITY_HYGIENE
						desired_room_id = p.home_room_id
					elif tick_of_day >= 60 and tick_of_day < 66:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					elif tick_of_day >= 66 and tick_of_day < 90:
						desired_activity = Person.ACTIVITY_RECREATING
						desired_room_id = p.home_room_id
					elif tick_of_day >= 90 and tick_of_day < 96:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					elif (tick_of_day >= 96 and tick_of_day < 120) or (tick_of_day >= 126 and tick_of_day < 144):
						desired_activity = Person.ACTIVITY_WORKING
						desired_room_id = work_id
					elif tick_of_day >= 120 and tick_of_day < 126:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					else:
						desired_activity = Person.ACTIVITY_HYGIENE
						desired_room_id = p.home_room_id
						
				Occupation.SHIFT_NIGHT:
					if (tick_of_day >= 0 and tick_of_day < 24) or (tick_of_day >= 30 and tick_of_day < 48):
						desired_activity = Person.ACTIVITY_WORKING
						desired_room_id = work_id
					elif tick_of_day >= 24 and tick_of_day < 30:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					elif tick_of_day >= 48 and tick_of_day < 54:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					elif tick_of_day >= 54 and tick_of_day < 102:
						desired_activity = Person.ACTIVITY_SLEEPING
						desired_room_id = p.home_room_id
					elif tick_of_day >= 102 and tick_of_day < 108:
						desired_activity = Person.ACTIVITY_HYGIENE
						desired_room_id = p.home_room_id
					elif tick_of_day >= 108 and tick_of_day < 114:
						desired_activity = Person.ACTIVITY_EATING
						desired_room_id = canteen_id
					else:
						desired_activity = Person.ACTIVITY_RECREATING
						desired_room_id = p.home_room_id
						
				_:
					desired_activity = Person.ACTIVITY_IDLE
					desired_room_id = p.home_room_id

		# 3. Check if spatial transition is required
		if p.current_location_id != desired_room_id:
			var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
			var can_travel: bool = true
			if inst_sys:
				var from_coord: Vector2i = _room_spatial_cache.get(p.current_location_id, Vector2i(1, 1))
				var to_coord: Vector2i = _room_spatial_cache.get(desired_room_id, Vector2i(1, 1))
				can_travel = inst_sys.is_sector_travel_allowed(p.security_clearance, from_coord.x, to_coord.x)
				
			if can_travel:
				TravelModel.begin_journey(ws, p, desired_room_id, desired_activity)
			else:
				# Blocked by quarantine / security clearance
				p.current_activity = Person.ACTIVITY_IDLE
		else:
			p.current_activity = desired_activity

func compute_travel_ticks_fast(from_id: int, to_id: int) -> int:
	if from_id == to_id or from_id <= 0 or to_id <= 0:
		return 0
	
	var from_coord: Vector2i = _room_spatial_cache.get(from_id, Vector2i(1, 1))
	var to_coord: Vector2i = _room_spatial_cache.get(to_id, Vector2i(1, 1))
	
	var delta_sector: int = abs(from_coord.x - to_coord.x)
	var delta_level: int = abs(from_coord.y - to_coord.y)
	
	if delta_sector == 0:
		if delta_level == 0:
			return 1 # Same sector & level: 1 tick (10 minutes)
		else:
			return 1 + (delta_level / 5) # 1 - 2 ticks
	else:
		return 2 + delta_sector + (delta_level / 5) # 2 - 4 ticks

func compute_travel_ticks(ws: WorldState, from_id: int, to_id: int) -> int:
	return TravelModel.compute_base_ticks(ws, from_id, to_id)

func _build_room_spatial_cache(ws: WorldState) -> void:
	_room_spatial_cache.clear()
	var registry: EntityRegistry = ws.entity_registry
	var all_room_ids: Array[int] = registry.get_entities_by_type("room")
	var n: int = all_room_ids.size()
	for i in range(n):
		var rid: int = all_room_ids[i]
		var r: Room = registry.get_entity(rid) as Room
		if r:
			_room_spatial_cache[rid] = Vector2i(r.sector_id, r.level)

func _rebuild_person_cache(ws: WorldState) -> void:
	_cached_persons.clear()
	var registry: EntityRegistry = ws.entity_registry
	var all_pids: Array[int] = registry.get_entities_by_type("person")
	for pid in all_pids:
		var p: Person = registry.get_entity(pid) as Person
		if p:
			_cached_persons.append(p)
	_cached_person_count = _cached_persons.size()
