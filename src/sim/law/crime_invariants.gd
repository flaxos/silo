# src/sim/law/crime_invariants.gd
class_name CrimeInvariants
extends RefCounted

## Invariant validation for Sprint 17: Crime & Underground Economy.
## Enforces mass conservation, entity reference integrity, and evidence validity.

const CrimeIncident = preload("res://src/sim/law/crime_incident.gd")
const EconomyInvariants = preload("res://src/sim/economy/economy_invariants.gd")

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	var registry: EntityRegistry = ws.entity_registry
	
	var crimes: Array = ws.custom_data.get("crime_incidents", [])
	for item in crimes:
		var c: CrimeIncident = item as CrimeIncident
		if not c:
			errors.append("Invalid CrimeIncident entry in custom_data['crime_incidents']")
			continue
			
		if c.id <= 0:
			errors.append("CrimeIncident has non-positive ID %d" % c.id)
			
		# Perpetrator must exist in registry
		if c.perpetrator_id > 0:
			var perp: Person = registry.get_entity(c.perpetrator_id) as Person
			if not perp:
				errors.append("Crime #%d references non-existent perpetrator Person #%d" % [c.id, c.perpetrator_id])
				
		# Victim must exist if set
		if c.victim_id > 0:
			var victim: Person = registry.get_entity(c.victim_id) as Person
			if not victim:
				errors.append("Crime #%d references non-existent victim Person #%d" % [c.id, c.victim_id])
				
		# Location room must exist
		if c.location_room_id > 0:
			var room: Room = registry.get_entity(c.location_room_id) as Room
			if not room:
				errors.append("Crime #%d references non-existent location Room #%d" % [c.id, c.location_room_id])
				
		if c.quantity < 0.0:
			errors.append("Crime #%d has negative stolen quantity %f" % [c.id, c.quantity])
			
		# Witnesses must exist
		for wid in c.evidence.get("witness_ids", []):
			var witness: Person = registry.get_entity(int(wid)) as Person
			if not witness:
				errors.append("Crime #%d references non-existent witness Person #%d" % [c.id, int(wid)])
				
	# Strictly verify system-wide mass conservation
	var econ_result: Dictionary = EconomyInvariants.validate(ws)
	if not econ_result.get("is_valid", false):
		errors.append("Mass conservation violation during crime evaluation: %s" % str(econ_result.get("errors", [])))
		
	return {
		"is_valid": errors.is_empty(),
		"errors": errors
	}
