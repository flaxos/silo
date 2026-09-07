# src/presentation/crime_reader.gd
class_name CrimeReader
extends RefCounted

## Read model adapter for Crime & Underground Economy.
## Read-only queries with zero simulation mutations.

const CrimeIncident = preload("res://src/sim/law/crime_incident.gd")

static func get_crime_summary(ws: WorldState) -> Dictionary:
	var list: Array = ws.custom_data.get("crime_incidents", [])
	var total: int = list.size()
	var by_type: Dictionary = {}
	var by_status: Dictionary = {}
	var total_stolen_mass_kg: float = 0.0
	
	for item in list:
		var c: CrimeIncident = item as CrimeIncident
		if c:
			by_type[c.crime_type] = int(by_type.get(c.crime_type, 0)) + 1
			by_status[c.status] = int(by_status.get(c.status, 0)) + 1
			if c.resource_id != "" and c.quantity > 0.0:
				total_stolen_mass_kg += (c.quantity * ResourceRegistry.get_unit_mass(c.resource_id))
				
	return {
		"total_crimes_count": total,
		"crimes_by_type": by_type,
		"crimes_by_status": by_status,
		"total_stolen_mass_kg": total_stolen_mass_kg
	}

static func get_all_crimes(ws: WorldState) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var list: Array = ws.custom_data.get("crime_incidents", [])
	var registry: EntityRegistry = ws.entity_registry
	
	for item in list:
		var c: CrimeIncident = item as CrimeIncident
		if c:
			var perp_name: String = "Unknown"
			var perp_occ: String = "Unknown"
			if c.perpetrator_id > 0:
				var p: Person = registry.get_entity(c.perpetrator_id) as Person
				if p:
					perp_name = "%s %s" % [p.first_name, p.last_name]
					perp_occ = p.occupation_id
					
			var loc_name: String = "Room #%d" % c.location_room_id
			var r: Room = registry.get_entity(c.location_room_id) as Room
			if r:
				loc_name = "Room #%d (L%d, type %d)" % [r.id, r.level, r.room_type]
				
			results.append({
				"id": c.id,
				"type": c.crime_type,
				"perpetrator_id": c.perpetrator_id,
				"perpetrator_name": perp_name,
				"perpetrator_occupation": perp_occ,
				"location_room_id": c.location_room_id,
				"location_name": loc_name,
				"tick": c.tick_occurred,
				"resource_id": c.resource_id,
				"quantity": c.quantity,
				"target_machine_id": c.target_machine_id,
				"target_component_id": c.target_component_id,
				"status": c.status,
				"evidence": c.evidence
			})
	return results

static func get_black_market_summary(ws: WorldState) -> Dictionary:
	var transactions: Array = ws.custom_data.get("black_market_transactions", [])
	return {
		"total_deals_count": transactions.size(),
		"recent_deals": transactions.slice(maxi(0, transactions.size() - 10), transactions.size())
	}

static func get_crime_trace(ws: WorldState, crime_id: int) -> Dictionary:
	var list: Array = ws.custom_data.get("crime_incidents", [])
	var target_crime: CrimeIncident = null
	for item in list:
		var c: CrimeIncident = item as CrimeIncident
		if c and c.id == crime_id:
			target_crime = c
			break
			
	if not target_crime:
		return {"error": "Crime not found"}
		
	var registry: EntityRegistry = ws.entity_registry
	var perp: Person = registry.get_entity(target_crime.perpetrator_id) as Person
	var room: Room = registry.get_entity(target_crime.location_room_id) as Room
	
	var witness_details: Array[Dictionary] = []
	for wid in target_crime.evidence.get("witness_ids", []):
		var w: Person = registry.get_entity(int(wid)) as Person
		if w:
			witness_details.append({
				"id": w.id,
				"name": "%s %s" % [w.first_name, w.last_name],
				"occupation": w.occupation_id
			})
			
	return {
		"crime_id": target_crime.id,
		"crime_type": target_crime.crime_type,
		"perpetrator": {
			"id": perp.id if perp else 0,
			"name": ("%s %s" % [perp.first_name, perp.last_name]) if perp else "Unknown",
			"occupation": perp.occupation_id if perp else "none",
			"economic_satisfaction": perp.economic_satisfaction if perp else 0.0,
			"class_resentment": perp.class_resentment if perp else 0.0
		},
		"location": {
			"room_id": room.id if room else 0,
			"room_type": room.room_type if room else -1,
			"level": room.level if room else 0
		},
		"stolen_item": {
			"resource_id": target_crime.resource_id,
			"quantity": target_crime.quantity
		},
		"evidence": {
			"badge_log_recorded": target_crime.evidence.get("badge_log_recorded", false),
			"cctv_recorded": target_crime.evidence.get("cctv_recorded", false),
			"inventory_discrepancy": target_crime.evidence.get("inventory_discrepancy", 0.0),
			"physical_traces": target_crime.evidence.get("physical_traces", ""),
			"witnesses": witness_details
		},
		"status": target_crime.status
	}
