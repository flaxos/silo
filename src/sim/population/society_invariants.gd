# src/sim/population/society_invariants.gd
class_name SocietyInvariants
extends RefCounted

static func validate(world_state: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = world_state.entity_registry
	var clock: SimClock = world_state.sim_clock
	var current_tick: int = clock.get_tick()
	
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	var room_ids: Array[int] = registry.get_entities_by_type("room")
	
	var total_people: int = person_ids.size()
	var living_count: int = 0
	var deceased_count: int = 0
	var infant_count: int = 0
	var child_count: int = 0
	var student_count: int = 0
	var adult_count: int = 0
	var elder_count: int = 0
	
	var allocated_beds_global: Dictionary = {} # String "room_id:bed_idx" -> int person_id
	
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if not p:
			errors.append("Person ID %d is null" % pid)
			continue
			
		if p.is_alive:
			living_count += 1
			match p.life_stage:
				Person.STAGE_INFANT: infant_count += 1
				Person.STAGE_CHILD: child_count += 1
				Person.STAGE_STUDENT: student_count += 1
				Person.STAGE_ADULT: adult_count += 1
				Person.STAGE_ELDER: elder_count += 1
				_: errors.append("Living person ID %d has unknown life_stage %d" % [pid, p.life_stage])
				
			# 1. Partner reciprocity for living residents
			if p.partner_id > 0:
				var partner: Person = registry.get_entity(p.partner_id) as Person
				if not partner:
					errors.append("Person ID %d references non-existent partner ID %d" % [pid, p.partner_id])
				elif not partner.is_alive:
					errors.append("Person ID %d references deceased partner ID %d" % [pid, p.partner_id])
				elif partner.partner_id != p.id:
					errors.append("Partner link non-reciprocal: Person %d -> %d, but partner points to %d" % [pid, p.partner_id, partner.partner_id])
					
			# 2. Bed allocation integrity
			if p.bed_id >= 0 and p.home_room_id > 0:
				var r: Room = registry.get_entity(p.home_room_id) as Room
				if not r:
					errors.append("Person ID %d references non-existent home room ID %d" % [pid, p.home_room_id])
				else:
					var occupant: int = r.get_occupant_of_bed(p.bed_id)
					if occupant != p.id:
						errors.append("Person ID %d bed mismatch: room %d bed %d has occupant %d" % [pid, p.home_room_id, p.bed_id, occupant])
						
					var bed_key: String = "%d:%d" % [p.home_room_id, p.bed_id]
					if allocated_beds_global.has(bed_key):
						errors.append("Duplicate bed allocation: %s held by both Person %d and %d" % [bed_key, allocated_beds_global[bed_key], p.id])
					else:
						allocated_beds_global[bed_key] = p.id
		else:
			deceased_count += 1
			# Deceased resident invariant checks
			if p.bed_id >= 0:
				errors.append("Deceased person ID %d still holds bed_id %d" % [pid, p.bed_id])
			if p.workplace_room_id > 0:
				errors.append("Deceased person ID %d still holds workplace %d" % [pid, p.workplace_room_id])
			if p.school_room_id > 0:
				errors.append("Deceased person ID %d still holds school %d" % [pid, p.school_room_id])
				
		# 3. Genealogical Reciprocity (Applies to all persons living and deceased)
		for parent_id in p.parent_ids:
			if parent_id == p.id:
				errors.append("Person ID %d is their own parent" % pid)
			var parent: Person = registry.get_entity(parent_id) as Person
			if not parent:
				errors.append("Person ID %d references non-existent parent ID %d" % [pid, parent_id])
			elif not parent.children_ids.has(p.id):
				errors.append("Parent %d missing child reference to Person %d" % [parent_id, p.id])
				
		for child_id in p.children_ids:
			if child_id == p.id:
				errors.append("Person ID %d is their own child" % pid)
			var child: Person = registry.get_entity(child_id) as Person
			if not child:
				errors.append("Person ID %d references non-existent child ID %d" % [pid, child_id])
			elif not child.parent_ids.has(p.id):
				errors.append("Child %d missing parent reference to Person %d" % [child_id, p.id])
				
	# 4. Check rooms occupied_beds contains only living occupants
	for rid in room_ids:
		var r: Room = registry.get_entity(rid) as Room
		if r:
			for bed_idx in r.occupied_beds.keys():
				var occupant_id: int = int(r.occupied_beds[bed_idx])
				var occ_person: Person = registry.get_entity(occupant_id) as Person
				if not occ_person:
					errors.append("Room %d bed %d has non-existent occupant ID %d" % [rid, bed_idx, occupant_id])
				elif not occ_person.is_alive:
					errors.append("Room %d bed %d occupied by deceased person ID %d" % [rid, bed_idx, occupant_id])
					
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"stats": {
			"total_people": total_people,
			"living_count": living_count,
			"deceased_count": deceased_count,
			"infants": infant_count,
			"children": child_count,
			"students": student_count,
			"adults": adult_count,
			"elders": elder_count
		}
	}
