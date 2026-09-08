# src/sim/politics/information_channel.gd
class_name InformationChannel
extends RefCounted

## Defines channel routing logic, reach rules, audience resolution, and transmission characteristics.

const InformationObject = preload("res://src/sim/politics/information_object.gd")
const SocialGraph = preload("res://src/sim/politics/social_graph.gd")

const TYPE_OFFICIAL: String = "OFFICIAL_ANNOUNCEMENT"
const TYPE_NOTICE_BOARD: String = "NOTICE_BOARD"
const TYPE_WORKPLACE: String = "WORKPLACE_COMM"
const TYPE_FACTION: String = "FACTION_CHANNEL"
const TYPE_WORD_OF_MOUTH: String = "WORD_OF_MOUTH"

static func resolve_target_recipients(ws: WorldState, info: InformationObject) -> Array[int]:
	var result: Array[int] = []
	if not ws or not ws.entity_registry:
		return result
		
	var registry: EntityRegistry = ws.entity_registry
	var all_pids: Array[int] = registry.get_entities_by_type("person")
	var target: Dictionary = info.target_audience
	var target_type: String = str(target.get("type", "all"))
	
	match info.channel_type:
		TYPE_OFFICIAL:
			# Official broadcasts reach according to audience target
			match target_type:
				"all":
					for pid in all_pids:
						var p: Person = registry.get_entity(pid) as Person
						if p and p.is_alive and p.life_stage >= Person.STAGE_STUDENT:
							result.append(pid)
				"department":
					var target_dept: String = str(target.get("department", ""))
					for pid in all_pids:
						var p: Person = registry.get_entity(pid) as Person
						if p and p.is_alive and p.department_id == target_dept:
							result.append(pid)
				"workplace":
					var target_room: int = int(target.get("workplace_room_id", 0))
					for pid in all_pids:
						var p: Person = registry.get_entity(pid) as Person
						if p and p.is_alive and p.workplace_room_id == target_room:
							result.append(pid)
				"clearance":
					var min_clearance: int = int(target.get("min_clearance", 1))
					for pid in all_pids:
						var p: Person = registry.get_entity(pid) as Person
						if p and p.is_alive and p.security_clearance >= min_clearance:
							result.append(pid)
				_:
					for pid in all_pids:
						var p: Person = registry.get_entity(pid) as Person
						if p and p.is_alive and p.life_stage >= Person.STAGE_STUDENT:
							result.append(pid)
							
		TYPE_WORKPLACE:
			var room_id: int = int(target.get("workplace_room_id", 0))
			if room_id <= 0 and info.source_entity_type == "citizen":
				var src_p: Person = registry.get_entity(info.source_entity_id) as Person
				if src_p:
					room_id = src_p.workplace_room_id
			for pid in all_pids:
				var p: Person = registry.get_entity(pid) as Person
				if p and p.is_alive and p.workplace_room_id == room_id and room_id > 0:
					result.append(pid)
					
		TYPE_FACTION:
			var target_faction_id: int = int(target.get("faction_id", 0))
			if target_faction_id <= 0 and info.source_entity_type == "faction":
				target_faction_id = info.source_entity_id
			for pid in all_pids:
				var p: Person = registry.get_entity(pid) as Person
				if p and p.is_alive:
					if p.faction_id == target_faction_id or p.sympathiser_faction_id == target_faction_id:
						result.append(pid)
						
		TYPE_NOTICE_BOARD:
			# Reaches citizens who live or work on the specified level or sector
			var level: int = int(target.get("level", 1))
			for pid in all_pids:
				var p: Person = registry.get_entity(pid) as Person
				if not p or not p.is_alive:
					continue
				var home: Room = registry.get_entity(p.home_room_id) as Room
				var work: Room = registry.get_entity(p.workplace_room_id) as Room
				if (home and home.level == level) or (work and work.level == level):
					result.append(pid)
					
		TYPE_WORD_OF_MOUTH:
			# Direct 1-hop social graph neighbors of source
			if info.source_entity_type == "citizen":
				var connections: Array[Dictionary] = SocialGraph.get_social_connections(ws, info.source_entity_id)
				for conn in connections:
					var tid: int = int(conn.get("target_id", 0))
					if tid > 0:
						result.append(tid)
						
	return result
