class_name SiloSpatialModel
extends RefCounted

const TravelModel = preload("res://src/sim/spatial/spatial_travel_model.gd")

## A deterministic, read-only physicalisation of the rooms already owned by the
## simulation. Coordinates are presentation-neutral authoritative metadata: this
## class never consumes WorldState randomness and never registers entities.

const ROOM_HEIGHT: float = 88.0
const LEVEL_GAP: float = 38.0
const ROOM_GAP: float = 10.0
const SECTOR_GAP: float = 36.0
const MIN_ROOM_WIDTH: float = 110.0
const MAX_ROOM_WIDTH: float = 480.0
const MAX_EXTRA_HEIGHT: float = 16.0

static func build(ws: WorldState) -> Dictionary:
	var result: Dictionary = {"levels": [], "rooms": [], "portals": [], "corridors": [], "landings": [], "stair_segments": [], "connectors": [], "bounds": {}, "warnings": []}
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
	var min_x: float = -420.0
	var max_x: float = 420.0
	const STAIR_X: float = -34.0
	const STAIR_WIDTH: float = 68.0
	var level_stride: float = ROOM_HEIGHT + MAX_EXTRA_HEIGHT + LEVEL_GAP
	for level_index in range(levels.size()):
		var level: int = int(levels[level_index])
		var level_rooms: Array = by_level[level]
		level_rooms.sort_custom(func(a: Room, b: Room) -> bool:
			return a.sector_id < b.sector_id or (a.sector_id == b.sector_id and a.id < b.id))
		var left_x: float = STAIR_X - 28.0
		var right_x: float = STAIR_X + STAIR_WIDTH + 28.0
		var level_y: float = float(level_index) * level_stride
		var floor_y: float = level_y + ROOM_HEIGHT + MAX_EXTRA_HEIGHT
		for room in level_rooms:
			var cap: int = maxi(1, room.capacity_people)
			var width: float
			var height: float = ROOM_HEIGHT
			if room.room_type in [Room.TYPE_RESIDENTIAL_APARTMENT, Room.TYPE_DORMITORY]:
				width = clampf(MIN_ROOM_WIDTH + sqrt(float(cap)) * 14.0, MIN_ROOM_WIDTH, 155.0)
			else:
				# Non-residential facilities (Deep Mine, School, Bio-Farm, Workshops, Clinics, Canteens)
				# are significantly wider and taller to match their physical role and resident capacity.
				width = clampf(160.0 + float(cap) * 5.2, 180.0, MAX_ROOM_WIDTH)
				if cap >= 25:
					height = ROOM_HEIGHT + MAX_EXTRA_HEIGHT

			var y: float = floor_y - height
			var x: float
			# Sector IDs grow with population size, so parity keeps both sides of the
			# central spine balanced without changing any authoritative domain IDs.
			if room.sector_id % 2 == 1:
				left_x -= width
				x = left_x
				left_x -= ROOM_GAP
			else:
				x = right_x
				right_x += width + ROOM_GAP
			result["rooms"].append({
				"id": room.id, "level": room.level, "sector_id": room.sector_id,
				"room_type": room.room_type, "x": x, "y": y,
				"width": width, "height": height, "capacity": room.capacity_people
			})
			var door_x: float = x + width * 0.5
			var door_y: float = floor_y
			var spine_y: float = door_y + 8.0
			result["portals"].append({
				"id": "portal_%d" % room.id, "room_id": room.id,
				"landing_id": "landing_%d" % level, "local_travel_ticks": 1,
				"x": door_x, "y": door_y
			})
			result["corridors"].append({
				"id": "corridor_%d" % room.id, "room_id": room.id,
				"portal_id": "portal_%d" % room.id, "landing_id": "landing_%d" % level,
				"from_x": door_x, "from_y": spine_y,
				"to_x": STAIR_X + STAIR_WIDTH * 0.5, "to_y": spine_y,
				"local_travel_ticks": 1
			})
		min_x = minf(min_x, left_x)
		max_x = maxf(max_x, right_x)
		result["levels"].append({"id": level, "index": level_index, "y": level_y, "floor_y": floor_y, "room_count": level_rooms.size()})
		result["landings"].append({"id": "landing_%d" % level, "level": level, "x": STAIR_X, "y": level_y, "width": STAIR_WIDTH, "height": ROOM_HEIGHT + MAX_EXTRA_HEIGHT})

	var travel_state: Dictionary = ws.custom_data.get(TravelModel.STATE_KEY, {})
	var live_segments: Dictionary = travel_state.get("segments", {})
	for i in range(maxi(0, levels.size() - 1)):
		var segment_id: String = TravelModel.segment_id_for(int(levels[i]), int(levels[i + 1]))
		var live: Dictionary = live_segments.get(segment_id, {})
		var segment: Dictionary = {
			"id": segment_id, "kind": "central_stair", "from_level": levels[i], "to_level": levels[i + 1],
			"from_landing_id": "landing_%d" % levels[i], "to_landing_id": "landing_%d" % levels[i + 1],
			"x": STAIR_X, "y": float(i) * level_stride + (ROOM_HEIGHT + MAX_EXTRA_HEIGHT),
			"width": STAIR_WIDTH, "height": LEVEL_GAP,
			"base_travel_ticks": int(live.get("base_travel_ticks", TravelModel.SEGMENT_TRAVEL_TICKS)),
			"capacity": int(live.get("capacity", TravelModel.SEGMENT_CAPACITY)),
			"occupancy": (live.get("occupants", {}) as Dictionary).size(),
			"queue": (live.get("queue", []) as Array).size(),
			"congestion_penalty": int(live.get("total_queue_ticks", 0))
		}
		result["stair_segments"].append(segment)
		result["connectors"].append(segment.duplicate())
	result["bounds"] = {"x": min_x, "y": 0.0, "width": max_x - min_x, "height": float(levels.size()) * level_stride}
	return result
