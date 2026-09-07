class_name SiloSpatialModel
extends RefCounted

## A deterministic, read-only physicalisation of the rooms already owned by the
## simulation. Coordinates are presentation-neutral authoritative metadata: this
## class never consumes WorldState randomness and never registers entities.

const ROOM_HEIGHT: float = 72.0
const LEVEL_GAP: float = 34.0
const ROOM_GAP: float = 8.0
const SECTOR_GAP: float = 36.0
const MIN_ROOM_WIDTH: float = 92.0
const MAX_ROOM_WIDTH: float = 230.0

static func build(ws: WorldState) -> Dictionary:
	var result: Dictionary = {"levels": [], "rooms": [], "connectors": [], "bounds": {}, "warnings": []}
	if not ws or not ws.entity_registry:
		return result
	var registry: EntityRegistry = ws.entity_registry
	var room_ids: Array[int] = registry.get_entities_by_type("room").duplicate()
	room_ids.sort()
	var by_level: Dictionary = {}
	for room_id in room_ids:
		var room: Room = registry.get_entity(room_id) as Room
		if not room:
			continue
		if not by_level.has(room.level):
			by_level[room.level] = []
		(by_level[room.level] as Array).append(room)

	var levels: Array = by_level.keys()
	levels.sort()
	var max_width: float = 0.0
	for level_index in range(levels.size()):
		var level: int = int(levels[level_index])
		var level_rooms: Array = by_level[level]
		level_rooms.sort_custom(func(a: Room, b: Room) -> bool:
			return a.sector_id < b.sector_id or (a.sector_id == b.sector_id and a.id < b.id))
		var cursor_x: float = 0.0
		var previous_sector: int = -1
		for room in level_rooms:
			if previous_sector >= 0 and room.sector_id != previous_sector:
				cursor_x += SECTOR_GAP
			var width: float = clampf(MIN_ROOM_WIDTH + sqrt(float(maxi(1, room.capacity_people))) * 13.0, MIN_ROOM_WIDTH, MAX_ROOM_WIDTH)
			var y: float = float(level_index) * (ROOM_HEIGHT + LEVEL_GAP)
			result["rooms"].append({
				"id": room.id, "level": room.level, "sector_id": room.sector_id,
				"room_type": room.room_type, "x": cursor_x, "y": y,
				"width": width, "height": ROOM_HEIGHT, "capacity": room.capacity_people
			})
			cursor_x += width + ROOM_GAP
			previous_sector = room.sector_id
		max_width = maxf(max_width, cursor_x)
		result["levels"].append({"id": level, "index": level_index, "y": float(level_index) * (ROOM_HEIGHT + LEVEL_GAP), "room_count": level_rooms.size()})

	# These connectors deliberately describe schematic circulation between actual
	# levels. They make no claim that lift routing/pathfinding is simulated.
	for i in range(maxi(0, levels.size() - 1)):
		result["connectors"].append({
			"id": "circulation_%s_%s" % [levels[i], levels[i + 1]],
			"kind": "schematic_circulation", "from_level": levels[i], "to_level": levels[i + 1],
			"x": max_width + 24.0
		})
	result["bounds"] = {"x": 0.0, "y": 0.0, "width": max_width + 70.0, "height": float(levels.size()) * (ROOM_HEIGHT + LEVEL_GAP)}
	return result
