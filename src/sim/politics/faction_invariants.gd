# src/sim/politics/faction_invariants.gd
class_name FactionInvariants
extends RefCounted

const Faction = preload("res://src/sim/politics/faction.gd")
const Person = preload("res://src/sim/population/person.gd")

## Systemic invariant checkers for emergent political factions, membership integrity,
## and policy response bounds.

static func validate_all(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	if not ws or not ws.entity_registry:
		return {"is_valid": true, "errors": errors}
		
	var registry: EntityRegistry = ws.entity_registry
	var fids: Array[int] = registry.get_entities_by_type("faction")
	
	for fid in fids:
		var faction: Faction = registry.get_entity(fid) as Faction
		if not faction:
			errors.append("Entity #%d in faction registry is not a valid Faction instance" % fid)
			continue
			
		# Metric bounds checks
		if faction.cohesion < 0.0 or faction.cohesion > 1.0:
			errors.append("Faction #%d '%s' cohesion %.2f out of bounds [0.0, 1.0]" % [fid, faction.name, faction.cohesion])
		if faction.resources < 0.0:
			errors.append("Faction #%d '%s' has negative resources %.2f" % [fid, faction.name, faction.resources])
			
		for pol_id in faction.policy_approval_matrix.keys():
			var val: float = float(faction.policy_approval_matrix[pol_id])
			if val < -1.001 or val > 1.001:
				errors.append("Faction #%d '%s' policy approval %s (%.2f) out of bounds [-1.0, 1.0]" % [fid, faction.name, pol_id, val])
				
		for other_id in faction.inter_faction_relations.keys():
			var rel: float = float(faction.inter_faction_relations[other_id])
			if rel < -1.001 or rel > 1.001:
				errors.append("Faction #%d '%s' relation to faction #%s (%.2f) out of bounds [-1.0, 1.0]" % [fid, faction.name, str(other_id), rel])
				
		for dept in faction.institutional_penetration.keys():
			var pen: float = float(faction.institutional_penetration[dept])
			if pen < -0.001 or pen > 1.001:
				errors.append("Faction #%d '%s' penetration in %s (%.2f) out of bounds [0.0, 1.0]" % [fid, faction.name, dept, pen])
				
		# Active faction membership checks
		if faction.is_active:
			if faction.member_ids.is_empty():
				errors.append("Active Faction #%d '%s' has zero members" % [fid, faction.name])
			if faction.leader_id <= 0 or not faction.member_ids.has(faction.leader_id):
				errors.append("Faction #%d '%s' leader #%d is not in member_ids" % [fid, faction.name, faction.leader_id])
				
		# Membership reference checks
		for mid in faction.member_ids:
			var p: Person = registry.get_entity(mid) as Person
			if not p:
				errors.append("Faction #%d '%s' member #%d does not exist in registry" % [fid, faction.name, mid])
			elif not p.is_alive and faction.is_active:
				errors.append("Faction #%d '%s' contains deceased member #%d (%s)" % [fid, faction.name, mid, p.first_name])
			elif p and p.faction_id != faction.id and faction.is_active:
				errors.append("Faction #%d '%s' member #%d has mismatched person.faction_id %d" % [fid, faction.name, mid, p.faction_id])
				
		for sid in faction.sympathiser_ids:
			if faction.member_ids.has(sid):
				errors.append("Citizen #%d is simultaneously a member and sympathiser in Faction #%d '%s'" % [sid, fid, faction.name])
			var sp: Person = registry.get_entity(sid) as Person
			if not sp:
				errors.append("Faction #%d '%s' sympathiser #%d does not exist in registry" % [fid, faction.name, sid])
			elif not sp.is_alive and faction.is_active:
				errors.append("Faction #%d '%s' contains deceased sympathiser #%d" % [fid, faction.name, sid])
				
	return {
		"is_valid": errors.is_empty(),
		"errors": errors
	}

static func assert_invariants(ws: WorldState) -> void:
	var res: Dictionary = validate_all(ws)
	if not res["is_valid"]:
		var msg: String = "FACTION INVARIANT VIOLATION:\n" + "\n".join(res["errors"])
		push_error(msg)
		assert(false, msg)
