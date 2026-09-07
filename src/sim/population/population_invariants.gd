# src/sim/population/population_invariants.gd
class_name PopulationInvariants
extends RefCounted

## Validates all population, household, and housing invariants in the WorldState
static func validate(world_state: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = world_state.entity_registry
	var current_tick: int = world_state.sim_clock.get_tick()
	
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	var household_ids: Array[int] = registry.get_entities_by_type("household")
	var room_ids: Array[int] = registry.get_entities_by_type("room")
	
	var person_map: Dictionary = {}
	var household_map: Dictionary = {}
	var room_map: Dictionary = {}
	
	for pid in person_ids:
		person_map[pid] = registry.get_entity(pid)
	for hid in household_ids:
		household_map[hid] = registry.get_entity(hid)
	for rid in room_ids:
		room_map[rid] = registry.get_entity(rid)
		
	# 1. Validate Person Invariants
	var global_bed_allocations: Dictionary = {} # "roomID_bedID" -> person_id
	var life_stage_counts: Dictionary = {
		Person.STAGE_INFANT: 0,
		Person.STAGE_CHILD: 0,
		Person.STAGE_STUDENT: 0,
		Person.STAGE_ADULT: 0,
		Person.STAGE_ELDER: 0
	}
	
	for pid in person_ids:
		var p: Person = person_map.get(pid, null) as Person
		if not p:
			errors.append("Entity %d is registered as 'person' but is not a Person object" % pid)
			continue
			
		if p.id != pid:
			errors.append("Person ID mismatch: entity key is %d but person.id is %d" % [pid, p.id])
			
		var age: int = p.get_age_years(current_tick)
		if age < 0 or age > 120:
			errors.append("Person %d (%s) has implausible age %d" % [pid, p.get_full_name(), age])
			
		var expected_stage: int = Person.get_life_stage_from_age(age)
		if p.life_stage != expected_stage:
			errors.append("Person %d (%s) life stage %d does not match expected %d for age %d" % [
				pid, p.get_full_name(), p.life_stage, expected_stage, age
			])
		life_stage_counts[p.life_stage] = life_stage_counts.get(p.life_stage, 0) + 1
		
		# Partner reciprocity
		if p.partner_id > 0:
			if not person_map.has(p.partner_id):
				errors.append("Person %d partner_id %d does not exist" % [pid, p.partner_id])
			else:
				var partner: Person = person_map[p.partner_id] as Person
				if partner.partner_id != pid:
					errors.append("Partner reciprocity broken: %d points to %d, but %d points to %d" % [
						pid, p.partner_id, p.partner_id, partner.partner_id
					])
		
		# Parent / child reciprocity & biological age gap
		for parent_id in p.parent_ids:
			if not person_map.has(parent_id):
				errors.append("Person %d parent_id %d does not exist" % [pid, parent_id])
			else:
				var parent: Person = person_map[parent_id] as Person
				if not parent.children_ids.has(pid):
					errors.append("Lineage reciprocity broken: %d lists %d as parent, but %d does not list %d as child" % [
						pid, parent_id, parent_id, pid
					])
				var parent_age: int = parent.get_age_years(current_tick)
				if parent_age - age < 14:
					errors.append("Biological gap violated: parent %d (age %d) is too young for child %d (age %d)" % [
						parent_id, parent_age, pid, age
					])
					
		for child_id in p.children_ids:
			if not person_map.has(child_id):
				errors.append("Person %d child_id %d does not exist" % [pid, child_id])
			else:
				var child: Person = person_map[child_id] as Person
				if not child.parent_ids.has(pid):
					errors.append("Lineage reciprocity broken: parent %d lists %d as child, but %d does not list %d as parent" % [
						pid, child_id, child_id, pid
					])
					
		# Household linkage
		if p.household_id <= 0:
			errors.append("Person %d has invalid household_id %d" % [pid, p.household_id])
		elif not household_map.has(p.household_id):
			errors.append("Person %d household_id %d does not exist" % [pid, p.household_id])
		else:
			var h: Household = household_map[p.household_id] as Household
			if not h.has_member(pid):
				errors.append("Household linkage broken: person %d points to household %d, but household does not list person" % [
					pid, p.household_id
				])
				
		# Room & Bed assignment
		if p.home_room_id <= 0:
			errors.append("Person %d has unassigned home_room_id %d" % [pid, p.home_room_id])
		elif not room_map.has(p.home_room_id):
			errors.append("Person %d home_room_id %d does not exist" % [pid, p.home_room_id])
		else:
			var r: Room = room_map[p.home_room_id] as Room
			if p.bed_id < 0 or p.bed_id >= r.bed_count:
				errors.append("Person %d bed_id %d out of bounds for room %d (bed_count %d)" % [
					pid, p.bed_id, p.home_room_id, r.bed_count
				])
			else:
				var occupant: int = r.get_occupant_of_bed(p.bed_id)
				if occupant != pid:
					errors.append("Room bed occupant mismatch: person %d assigned bed %d in room %d, but room reports occupant %d" % [
						pid, p.bed_id, p.home_room_id, occupant
					])
				var bed_key: String = "%d_%d" % [p.home_room_id, p.bed_id]
				if global_bed_allocations.has(bed_key):
					errors.append("Bed double-booking! Room %d Bed %d allocated to both person %d and %d" % [
						p.home_room_id, p.bed_id, global_bed_allocations[bed_key], pid
					])
				else:
					global_bed_allocations[bed_key] = pid
					
	# 2. Validate Household Invariants
	for hid in household_ids:
		var h: Household = household_map.get(hid, null) as Household
		if not h:
			continue
		if h.member_ids.is_empty():
			errors.append("Household %d is empty (0 members)" % hid)
		if h.head_id <= 0 or not person_map.has(h.head_id):
			errors.append("Household %d has invalid head_id %d" % [hid, h.head_id])
		elif not h.has_member(h.head_id):
			errors.append("Household %d head_id %d is not in member_ids" % [hid, h.head_id])
		for mid in h.member_ids:
			if not person_map.has(mid):
				errors.append("Household %d member %d does not exist" % [hid, mid])
				
	# 3. Validate Room Invariants
	for rid in room_ids:
		var r: Room = room_map.get(rid, null) as Room
		if not r:
			continue
		if r.occupied_beds.size() > r.bed_count:
			errors.append("Room %d occupied beds (%d) exceeds bed count (%d)" % [
				rid, r.occupied_beds.size(), r.bed_count
			])
		for bed_idx in r.occupied_beds.keys():
			var occ_id: int = r.occupied_beds[bed_idx]
			if not person_map.has(occ_id):
				errors.append("Room %d bed %d occupied by non-existent person %d" % [rid, bed_idx, occ_id])
			else:
				var occ_p: Person = person_map[occ_id] as Person
				if occ_p.home_room_id != rid or occ_p.bed_id != bed_idx:
					errors.append("Room %d bed %d points to person %d, but person points to room %d bed %d" % [
						rid, bed_idx, occ_id, occ_p.home_room_id, occ_p.bed_id
					])
					
	var stats: Dictionary = {
		"total_people": person_ids.size(),
		"total_households": household_ids.size(),
		"total_rooms": room_ids.size(),
		"life_stages": life_stage_counts,
		"bed_allocations": global_bed_allocations.size()
	}
	
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"stats": stats
	}
