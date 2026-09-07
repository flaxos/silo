# src/sim/incidents/incident_detector.gd
class_name IncidentDetector
extends RefCounted

## Analytical telemetry engine that continuously inspects WorldState and identifies
## emergent physical and social bottlenecks across the habitat.

const RESERVOIR_WARNING_THRESHOLD: float = 0.20   # < 20% capacity
const RESERVOIR_CRITICAL_THRESHOLD: float = 0.10  # < 10% capacity
const COMPONENT_CRITICAL_WEAR_THRESHOLD: float = 85.0 # > 85% component wear
const SPARE_PARTS_MIN_WEAR_THRESHOLD: float = 60.0    # Machines needing parts
const DEHYDRATION_POP_WARNING_RATIO: float = 0.10     # > 10% population dehydrated
const DEHYDRATION_POP_CRITICAL_RATIO: float = 0.25    # > 25% population dehydrated
const SOCIAL_TENSION_WARNING_THRESHOLD: float = 50.0  # > 50.0 social tension
const SOCIAL_TENSION_CRITICAL_THRESHOLD: float = 75.0 # > 75.0 social tension
const SOCIAL_TENSION_EMERGENCY_THRESHOLD: float = 90.0 # > 90.0 social tension

static func detect_incidents(ws: WorldState) -> Array[Dictionary]:
	var detected: Array[Dictionary] = []
	if not ws:
		return detected

	_detect_water_incidents(ws, detected)
	_detect_machinery_incidents(ws, detected)
	_detect_spare_parts_incidents(ws, detected)
	_detect_workforce_incidents(ws, detected)
	_detect_health_incidents(ws, detected)
	_detect_social_incidents(ws, detected)

	return detected

static func _detect_water_incidents(ws: WorldState, detected: Array[Dictionary]) -> void:
	var current_liters: float = -1.0
	var capacity_liters: float = 100000.0

	if ws.custom_data.has("water_reservoir_liters"):
		current_liters = float(ws.custom_data["water_reservoir_liters"])
	elif ws.custom_data.has("water_system"):
		var wsys: Variant = ws.custom_data["water_system"]
		if wsys != null:
			current_liters = float(wsys.get("reservoir_current_liters"))
			capacity_liters = float(wsys.get("reservoir_capacity_liters"))

	if current_liters < 0.0:
		return

	if ws.custom_data.has("water_reservoir_capacity_liters"):
		capacity_liters = float(ws.custom_data["water_reservoir_capacity_liters"])

	var fill_ratio: float = current_liters / maxf(1.0, capacity_liters)

	if fill_ratio <= RESERVOIR_WARNING_THRESHOLD:
		var sev: int = Incident.SEVERITY_WARNING
		if current_liters <= 0.001:
			sev = Incident.SEVERITY_EMERGENCY
		elif fill_ratio <= RESERVOIR_CRITICAL_THRESHOLD:
			sev = Incident.SEVERITY_CRITICAL

		detected.append({
			"type": Incident.INCIDENT_WATER_RESERVOIR_DEPLETING,
			"severity": sev,
			"root_cause_id": 0,
			"title": "Potable Water Reservoir Depleting",
			"description": "Potable water reservoir level is at %.1f%% (%.1f / %.1f L)." % [fill_ratio * 100.0, current_liters, capacity_liters],
			"telemetry": {
				"current_liters": current_liters,
				"capacity_liters": capacity_liters,
				"fill_ratio": fill_ratio,
				"threshold_ratio": RESERVOIR_WARNING_THRESHOLD
			}
		})

static func _detect_machinery_incidents(ws: WorldState, detected: Array[Dictionary]) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")

	for mid in machine_ids:
		var m: Machine = registry.get_entity(mid) as Machine
		if not m:
			continue

		var max_wear: float = 0.0
		var worst_comp_id: String = ""

		for cid in m.components:
			var comp: MachineComponent = m.components[cid] as MachineComponent
			if comp and comp.wear_percent > max_wear:
				max_wear = comp.wear_percent
				worst_comp_id = cid

		# 1. Critical Pump / Component Wear
		if max_wear >= COMPONENT_CRITICAL_WEAR_THRESHOLD:
			var sev: int = Incident.SEVERITY_WARNING
			if max_wear >= 99.9 or m.state == Machine.STATE_BROKEN:
				sev = Incident.SEVERITY_EMERGENCY
			elif max_wear >= 90.0 or m.state == Machine.STATE_FAULT:
				sev = Incident.SEVERITY_CRITICAL

			var is_pump: bool = (m is WaterPump) or m.machine_type.contains("pump")
			var inc_type: String = Incident.INCIDENT_CRITICAL_PUMP_WEAR if is_pump else Incident.INCIDENT_INFRASTRUCTURE_FAULT

			detected.append({
				"type": inc_type,
				"severity": sev,
				"root_cause_id": m.id,
				"title": "Critical Machinery Degradation: %s (ID %d)" % [m.machine_type, m.id],
				"description": "Component '%s' on machine ID %d reached %.1f%% wear (State: %d)." % [worst_comp_id, m.id, max_wear, m.state],
				"telemetry": {
					"machine_id": m.id,
					"machine_type": m.machine_type,
					"component_id": worst_comp_id,
					"wear_percent": max_wear,
					"machine_state": m.state,
					"room_id": m.room_id
				}
			})
		elif m.state == Machine.STATE_BROKEN or m.state == Machine.STATE_FAULT:
			detected.append({
				"type": Incident.INCIDENT_INFRASTRUCTURE_FAULT,
				"severity": Incident.SEVERITY_EMERGENCY if m.state == Machine.STATE_BROKEN else Incident.SEVERITY_CRITICAL,
				"root_cause_id": m.id,
				"title": "Machine Breakdown: %s (ID %d)" % [m.machine_type, m.id],
				"description": "Machine ID %d is in fault/broken state (%d)." % [m.id, m.state],
				"telemetry": {
					"machine_id": m.id,
					"machine_type": m.machine_type,
					"machine_state": m.state,
					"room_id": m.room_id
				}
			})

static func _detect_spare_parts_incidents(ws: WorldState, detected: Array[Dictionary]) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	var room_ids: Array[int] = registry.get_entities_by_type("room")

	# Aggregate global stocks of spare part resources across all room inventories
	var resource_stocks: Dictionary = {}
	for rid in room_ids:
		var room: Room = registry.get_entity(rid) as Room
		if room and room.inventory_id > 0:
			var inv: Inventory = registry.get_entity(room.inventory_id) as Inventory
			if inv:
				for r_key in inv.stocks:
					resource_stocks[r_key] = float(resource_stocks.get(r_key, 0.0)) + float(inv.stocks[r_key])

	# Check if any degraded machine lacks available replacement parts
	var alerted_resources: Dictionary = {}
	for mid in machine_ids:
		var m: Machine = registry.get_entity(mid) as Machine
		if not m:
			continue

		for cid in m.components:
			var comp: MachineComponent = m.components[cid] as MachineComponent
			if comp and comp.wear_percent >= SPARE_PARTS_MIN_WEAR_THRESHOLD:
				var spare_res: String = comp.required_spare_resource_id
				if spare_res != "" and not alerted_resources.has(spare_res):
					var available_qty: float = float(resource_stocks.get(spare_res, 0.0))
					if available_qty < comp.required_spare_quantity:
						alerted_resources[spare_res] = true
						var sev: int = Incident.SEVERITY_WARNING
						if comp.wear_percent >= COMPONENT_CRITICAL_WEAR_THRESHOLD:
							sev = Incident.SEVERITY_CRITICAL
						if comp.wear_percent >= 99.9 or m.state == Machine.STATE_BROKEN:
							sev = Incident.SEVERITY_EMERGENCY

						detected.append({
							"type": Incident.INCIDENT_SPARE_PARTS_STOCKOUT,
							"severity": sev,
							"root_cause_id": m.id,
							"title": "Spare Parts Stockout: %s" % spare_res,
							"description": "Zero or insufficient '%s' in inventory (Available: %.1f) while machine ID %d wear is %.1f%%." % [
								spare_res, available_qty, m.id, comp.wear_percent
							],
							"telemetry": {
								"resource_id": spare_res,
								"available_quantity": available_qty,
								"required_quantity": comp.required_spare_quantity,
								"machine_id": m.id,
								"component_id": cid,
								"wear_percent": comp.wear_percent
							}
						})

static func _detect_workforce_incidents(ws: WorldState, detected: Array[Dictionary]) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var room_ids: Array[int] = registry.get_entities_by_type("room")
	var person_ids: Array[int] = registry.get_entities_by_type("person")

	# Check foundry workplaces
	var foundry_rooms: Array[Room] = []
	for rid in room_ids:
		var r: Room = registry.get_entity(rid) as Room
		if r and r.room_type == Room.TYPE_FOUNDRY:
			foundry_rooms.append(r)

	if foundry_rooms.is_empty():
		return

	# Count assigned and living foundry operators
	var assigned_foundry_workers: int = 0
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive and (p.occupation_id == "foundry_worker" or p.occupation_id == "furnace_operator"):
			assigned_foundry_workers += 1

	if assigned_foundry_workers == 0:
		var primary_foundry_id: int = foundry_rooms[0].id
		detected.append({
			"type": Incident.INCIDENT_FOUNDRY_LABOR_STARVATION,
			"severity": Incident.SEVERITY_WARNING,
			"root_cause_id": primary_foundry_id,
			"title": "Smelting Foundry Labor Starvation",
			"description": "Smelting foundry has 0 assigned operators, stalling downstream metal stock production.",
			"telemetry": {
				"foundry_room_id": primary_foundry_id,
				"assigned_workers": 0,
				"foundry_room_count": foundry_rooms.size()
			}
		})

static func _detect_health_incidents(ws: WorldState, detected: Array[Dictionary]) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var person_ids: Array[int] = registry.get_entities_by_type("person")

	var living_count: int = 0
	var dehydrated_count: int = 0
	var critically_dehydrated_count: int = 0
	var total_hydration: float = 0.0

	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if p and p.is_alive:
			living_count += 1
			total_hydration += p.hydration_percent
			if p.hydration_percent < 50.0:
				dehydrated_count += 1
			if p.hydration_percent < 20.0:
				critically_dehydrated_count += 1

	if living_count == 0:
		return

	var dehy_ratio: float = float(dehydrated_count) / float(living_count)
	var avg_hyd: float = total_hydration / float(living_count)

	if dehy_ratio >= DEHYDRATION_POP_WARNING_RATIO or avg_hyd < 70.0:
		var sev: int = Incident.SEVERITY_WARNING
		if dehy_ratio >= 0.50 or avg_hyd < 30.0 or critically_dehydrated_count > (living_count / 3):
			sev = Incident.SEVERITY_EMERGENCY
		elif dehy_ratio >= DEHYDRATION_POP_CRITICAL_RATIO or avg_hyd < 50.0:
			sev = Incident.SEVERITY_CRITICAL

		detected.append({
			"type": Incident.INCIDENT_DEHYDRATION_EPIDEMIC,
			"severity": sev,
			"root_cause_id": 0,
			"title": "Severe Population Dehydration Epidemic",
			"description": "%d of %d residents (%.1f%%) are severely dehydrated (Avg hydration: %.1f%%)." % [
				dehydrated_count, living_count, dehy_ratio * 100.0, avg_hyd
			],
			"telemetry": {
				"living_population": living_count,
				"dehydrated_count": dehydrated_count,
				"critically_dehydrated_count": critically_dehydrated_count,
				"dehydration_ratio": dehy_ratio,
				"avg_hydration": avg_hyd
			}
		})

static func _detect_social_incidents(ws: WorldState, detected: Array[Dictionary]) -> void:
	var tension: float = 0.0
	if ws.custom_data.has("social_tension_index"):
		tension = float(ws.custom_data["social_tension_index"])
	elif ws.custom_data.has("institution_system"):
		var isys: Variant = ws.custom_data["institution_system"]
		if isys != null:
			tension = float(isys.get("social_tension_index"))

	if tension >= SOCIAL_TENSION_WARNING_THRESHOLD:
		var sev: int = Incident.SEVERITY_WARNING
		if tension >= SOCIAL_TENSION_EMERGENCY_THRESHOLD:
			sev = Incident.SEVERITY_EMERGENCY
		elif tension >= SOCIAL_TENSION_CRITICAL_THRESHOLD:
			sev = Incident.SEVERITY_CRITICAL

		detected.append({
			"type": Incident.INCIDENT_SOCIAL_UNREST,
			"severity": sev,
			"root_cause_id": 0,
			"title": "Escalating Habitat Social Unrest",
			"description": "Social tension index has reached %.2f / 100.0." % tension,
			"telemetry": {
				"social_tension_index": tension,
				"warning_threshold": SOCIAL_TENSION_WARNING_THRESHOLD,
				"critical_threshold": SOCIAL_TENSION_CRITICAL_THRESHOLD
			}
		})
