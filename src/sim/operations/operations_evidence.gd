class_name OperationsEvidence
extends RefCounted

## Pure evidence projection. No inventory creation, RNG, or writes while inspecting.
static func pump(ws: WorldState, machine_id: int) -> Dictionary:
	var m := ws.entity_registry.get_entity(machine_id) as WaterPump
	if not m:
		return {}
	var c := m.get_most_worn_component()
	if not c:
		return {}
	var room := ws.entity_registry.get_entity(m.room_id) as Room
	var inv := inventory(ws, room)
	var staff := workforce(ws, m.room_id, ["maintenance_technician"])
	var stock := inv.get_quantity(c.required_spare_resource_id) if inv else 0.0
	var needs_part := c.required_spare_resource_id != "" and stock < c.required_spare_quantity
	var threshold := float(ws.custom_data.get("maintenance_trigger_wear", 60.0))
	var inst := ws.custom_data.get("institution_system") as InstitutionSystem
	if inst:
		threshold = inst.get_machine_maintenance_threshold(m.id)
	var why: Array[Dictionary] = []
	why.append(link("machine", m.id, m.room_id, "Pump output %.1f / %.1f L/min; reservoir %.0f L." % [m.current_water_throughput_lpm, m.max_water_throughput_lpm, float(ws.custom_data.get("water_reservoir_liters", 0.0))]))
	why.append(link("machine", m.id, m.room_id, "%s: %.2f%% wear. Repair labour %d / %d technician-ticks." % [c.name, c.wear_percent, c.accumulated_repair_ticks, c.repair_ticks_required]))
	why.append(link("room", m.room_id, m.room_id, "Service eligibility %.0f%% wear; %d assigned technicians, %d working here now." % [threshold, staff.assigned, staff.on_duty]))
	if staff.person_id > 0:
		why.append(link("person", staff.person_id, staff.person_room, "Inspect an assigned technician's actual shift and journey."))
	if c.required_spare_resource_id != "":
		why.append(link("inventory", inv.id if inv else 0, m.room_id, "%s: %.1f available here / %.1f required.%s" % [c.required_spare_resource_id, stock, c.required_spare_quantity, " Repair waits for parts." if needs_part else " Part available."]))
	if needs_part and c.required_spare_resource_id == ResourceRegistry.RES_MACHINED_BEARING:
		_append_bearing_chain(ws, why, m.room_id)
	elif needs_part:
		why.append(link("", 0, 0, "No implemented automatic supply route for this part to this pump. Engineering supply remains unresolved."))
	var blocker := "Waiting for the service threshold."
	if c.wear_percent >= threshold:
		if needs_part: blocker = "Waiting for a real replacement part."
		elif staff.on_duty == 0: blocker = "Waiting for scheduled technicians to arrive."
		else: blocker = "Technicians can perform the repair with local stock."
	return {"machine_id": m.id, "room_id": m.room_id, "component_id": c.id,
		"wear": c.wear_percent, "state": m.state, "output": m.current_water_throughput_lpm,
		"repair_ticks": c.accumulated_repair_ticks, "required_ticks": c.repair_ticks_required,
		"stock": stock, "needs_part": needs_part, "on_duty": staff.on_duty,
		"threshold": threshold, "why": why, "summary": blocker,
		"known": ["Direct machinery telemetry and current inventory/shift records.", blocker],
		"suspected": [], "unknown": ["Future arrivals and future part availability are not guaranteed."]}

static func inventory(ws: WorldState, room: Room) -> Inventory:
	return ws.entity_registry.get_entity(room.inventory_id) as Inventory if room else null

static func workforce(ws: WorldState, room_id: int, occupations: Array) -> Dictionary:
	var result := {"assigned": 0, "on_duty": 0, "person_id": 0, "person_room": 0}
	for pid in ws.entity_registry.get_entities_by_type("person"):
		var p := ws.entity_registry.get_entity(pid) as Person
		if not p or not p.is_alive or not p.occupation_id in occupations:
			continue
		if p.workplace_room_id == room_id:
			result.assigned += 1
			if result.person_id == 0:
				result.person_id = p.id
				result.person_room = p.current_location_id
		if p.current_location_id == room_id and p.current_activity == Person.ACTIVITY_WORKING and not p.is_severely_dehydrated():
			result.on_duty += 1
	return result

static func first_room(ws: WorldState, room_type: int) -> Room:
	# ProductionSystem transfers between the FIRST registered facilities only.
	for rid in ws.entity_registry.get_entities_by_type("room"):
		var r := ws.entity_registry.get_entity(rid) as Room
		if r and r.room_type == room_type:
			return r
	return null

static func _append_bearing_chain(ws: WorldState, why: Array[Dictionary], pump_room: int) -> void:
	var destination := first_room(ws, Room.TYPE_WATER_PUMP_STATION)
	if not destination or destination.id != pump_room:
		why.append(link("", 0, 0, "No production transfer route to this pump station is implemented."))
		return
	var stages := [
		[Room.TYPE_MACHINE_SHOP, ResourceRegistry.RES_METAL_STOCK, ["machinist", "welder"], "Machine shop", ResourceRegistry.RES_MACHINED_BEARING],
		[Room.TYPE_FOUNDRY, ResourceRegistry.RES_PROCESSED_ORE, ["furnace_operator", "foundry_worker"], "Foundry", ResourceRegistry.RES_METAL_STOCK],
		[Room.TYPE_DEEP_MINE, ResourceRegistry.RES_IRON_ORE, ["miner"], "Mine", ResourceRegistry.RES_PROCESSED_ORE]]
	for stage in stages:
		var r := first_room(ws, stage[0])
		if not r:
			why.append(link("", 0, 0, "%s source room is missing." % stage[3]))
			break
		var inv := inventory(ws, r)
		var input_stock := inv.get_quantity(stage[1]) if inv else 0.0
		var output_stock := inv.get_quantity(stage[4]) if inv else 0.0
		var staff := workforce(ws, r.id, stage[2])
		why.append(link("room", r.id, r.id, "%s: %d working / %d assigned; %s %.1f; outgoing %s %.1f. Transfers are automatic inventory operations." % [stage[3], staff.on_duty, staff.assigned, stage[1], input_stock, stage[4], output_stock]))
		if output_stock > 0.0:
			break # A waiting transfer is supported; an upstream shortage is not.
		if staff.on_duty == 0 or input_stock > 0.0:
			break # Do not invent missing upstream materials when labour is the constraint.
		if int(stage[0]) == Room.TYPE_DEEP_MINE:
			why.append(link("room", r.id, r.id, "Physical geological seam: %.1f kg remaining." % float(ws.custom_data.get("geological_seam_ore_kg", 0.0))))

static func link(kind: String, id: int, room_id: int, text: String) -> Dictionary:
	return {"type": kind, "id": id, "room_id": room_id, "text": text}
