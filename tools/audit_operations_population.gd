extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var e := OperationsSession.create(1200, 42)
	var ws := e.world_state
	var age := {"0–5": 0, "6–17": 0, "18–64": 0, "65+": 0}
	var jobs := {}
	var shifts := {}
	var facilities := {}
	var assignment_errors := []
	var homes := {}
	for rid in ws.entity_registry.get_entities_by_type("room"):
		var r := ws.entity_registry.get_entity(rid) as Room
		facilities[rid] = {"id": rid, "type": r.room_type, "level": r.level, "sector": r.sector_id, "capacity": r.capacity_people, "beds": r.bed_count, "workers": 0, "students": 0, "peak_working": 0, "peak_studying": 0}
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var p := ws.entity_registry.get_entity(pid) as Person
		var years := p.get_age_years(0)
		age["0–5" if years < 6 else ("6–17" if years < 18 else ("18–64" if years < 65 else "65+"))] += 1
		jobs[p.occupation_id] = int(jobs.get(p.occupation_id, 0)) + 1
		var key := "%s / shift %d" % [p.occupation_id, p.shift_id]
		shifts[key] = int(shifts.get(key, 0)) + 1
		homes[p.household_id] = true
		if p.workplace_room_id > 0:
			facilities[p.workplace_room_id].workers += 1
			var def: Dictionary = Occupation.OCCUPATION_DEFINITIONS.get(p.occupation_id, {})
			if int(def.get("room_type", -1)) != int(facilities[p.workplace_room_id].type): assignment_errors.append(p.id)
		if p.school_room_id > 0: facilities[p.school_room_id].students += 1
	var max_cases := 0
	for tick in range(144):
		e.step(1)
		var working := {}; var studying := {}
		for pid in ws.entity_registry.get_entities_by_type("person"):
			var p := ws.entity_registry.get_entity(pid) as Person
			if p.current_activity == Person.ACTIVITY_WORKING: working[p.current_location_id] = int(working.get(p.current_location_id, 0)) + 1
			if p.current_activity == Person.ACTIVITY_STUDYING: studying[p.current_location_id] = int(studying.get(p.current_location_id, 0)) + 1
		for rid in facilities:
			facilities[rid].peak_working = maxi(facilities[rid].peak_working, int(working.get(rid, 0)))
			facilities[rid].peak_studying = maxi(facilities[rid].peak_studying, int(studying.get(rid, 0)))
		max_cases = maxi(max_cases, CaseReader.brief(ws).active_count)
	var result := {"seed": 42, "population": 1200, "age": age, "households": homes.size(), "occupations": jobs, "shifts": shifts, "facilities": facilities.values(), "assignment_errors": assignment_errors, "maximum_open_cases_day_one_no_actions": max_cases}
	var file := FileAccess.open("/tmp/silo-population-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("POPULATION_AUDIT " + JSON.stringify({"age": age, "households": homes.size(), "jobs": jobs, "assignment_errors": assignment_errors.size(), "max_cases": max_cases}))
	quit()
