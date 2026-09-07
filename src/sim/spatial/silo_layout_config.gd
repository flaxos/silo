# src/sim/spatial/silo_layout_config.gd
class_name SiloLayoutConfig
extends RefCounted

## Static configuration for the silo's physical zones and rendering metadata.
## This is presentation-layer data that maps simulation rooms to visual zones.
## It never mutates simulation state.

# Room type → display name mapping
const ROOM_TYPE_NAMES: Dictionary = {
	0: "Apartment",
	1: "Dormitory",
	2: "Canteen",
	3: "Kitchen",
	4: "Hygiene Facility",
	5: "Machine Shop",
	6: "Smelting Foundry",
	7: "Deep Mine",
	8: "Water Pump Station",
	9: "Server Room",
	10: "Clinic",
	11: "School",
	12: "Administration",
	13: "Recreation Hall",
	14: "Storage Bay",
	15: "Security Post",
	16: "Bio-Farm",
	17: "Food Processing",
	18: "Waste Processing",
	19: "Air Handler",
	20: "Power Plant",
	21: "Staircase",
	22: "Corridor",
	23: "Wastewater Treatment"
}

# Room type → display color (RGBA)
const ROOM_TYPE_COLORS: Dictionary = {
	0: Color(0.85, 0.75, 0.55, 1.0),    # Apartment: warm amber
	1: Color(0.80, 0.70, 0.50, 1.0),    # Dormitory: similar
	2: Color(0.90, 0.60, 0.30, 1.0),    # Canteen: orange
	3: Color(0.85, 0.45, 0.25, 1.0),    # Kitchen: orange-red
	4: Color(0.55, 0.75, 0.90, 1.0),    # Hygiene: light blue
	5: Color(0.60, 0.62, 0.65, 1.0),    # Machine Shop: steel grey
	6: Color(0.85, 0.35, 0.20, 1.0),    # Foundry: red-orange
	7: Color(0.45, 0.35, 0.25, 1.0),    # Deep Mine: dark brown
	8: Color(0.30, 0.55, 0.85, 1.0),    # Water Pump: blue
	9: Color(0.25, 0.75, 0.80, 1.0),    # Server Room: cyan
	10: Color(0.90, 0.95, 0.90, 1.0),   # Clinic: white-green
	11: Color(0.40, 0.55, 0.80, 1.0),   # School: blue
	12: Color(0.80, 0.75, 0.65, 1.0),   # Administration: beige
	13: Color(0.55, 0.75, 0.55, 1.0),   # Recreation: green
	14: Color(0.50, 0.50, 0.50, 1.0),   # Storage: grey
	15: Color(0.70, 0.30, 0.30, 1.0),   # Security: dark red
	16: Color(0.30, 0.75, 0.30, 1.0),   # Bio-Farm: bright green
	17: Color(0.70, 0.65, 0.35, 1.0),   # Food Processing: olive
	18: Color(0.55, 0.45, 0.35, 1.0),   # Waste Processing: brown
	19: Color(0.65, 0.75, 0.80, 1.0),   # Air Handler: light grey-blue
	20: Color(0.90, 0.80, 0.25, 1.0),   # Power Plant: gold
	21: Color(0.45, 0.45, 0.50, 1.0),   # Staircase: concrete grey
	22: Color(0.40, 0.40, 0.42, 1.0),   # Corridor: dark grey
	23: Color(0.28, 0.50, 0.55, 1.0),   # Wastewater treatment hook
}

# Activity → dot color for citizen rendering
const ACTIVITY_COLORS: Dictionary = {
	0: Color(0.25, 0.30, 0.55, 0.8),    # Sleeping: dim blue
	1: Color(0.95, 0.95, 0.95, 1.0),    # Traveling: white
	2: Color(0.90, 0.80, 0.20, 1.0),    # Working: yellow
	3: Color(0.30, 0.80, 0.90, 1.0),    # Studying: cyan
	4: Color(0.90, 0.60, 0.20, 1.0),    # Eating: orange
	5: Color(0.50, 0.70, 0.90, 1.0),    # Hygiene: light blue
	6: Color(0.40, 0.80, 0.40, 1.0),    # Recreating: green
	7: Color(0.50, 0.50, 0.50, 0.6),    # Idle: grey
}

# Zone definitions: maps level ranges to zone names for the level labels
const ZONE_DEFINITIONS: Array[Dictionary] = [
	{"name": "UPPER ADMIN", "min_level": 1, "max_level": 1, "color": Color(0.80, 0.75, 0.65)},
	{"name": "RESIDENTIAL", "min_level": 2, "max_level": 4, "color": Color(0.85, 0.75, 0.55)},
	{"name": "SERVICES", "min_level": 3, "max_level": 5, "color": Color(0.70, 0.70, 0.75)},
	{"name": "ENGINEERING", "min_level": 5, "max_level": 6, "color": Color(0.55, 0.60, 0.65)},
	{"name": "PROCESSING", "min_level": 7, "max_level": 10, "color": Color(0.75, 0.50, 0.30)},
	{"name": "DEEP INDUSTRY", "min_level": 11, "max_level": 15, "color": Color(0.55, 0.40, 0.30)},
	{"name": "MINES & WATER", "min_level": 16, "max_level": 18, "color": Color(0.40, 0.35, 0.30)},
]

static func get_room_type_name(room_type: int) -> String:
	return ROOM_TYPE_NAMES.get(room_type, "Unknown")

static func get_room_color(room_type: int) -> Color:
	return ROOM_TYPE_COLORS.get(room_type, Color(0.5, 0.5, 0.5))

static func get_activity_color(activity: int) -> Color:
	return ACTIVITY_COLORS.get(activity, Color(0.5, 0.5, 0.5, 0.6))

static func get_zone_for_level(level: int) -> String:
	for zone in ZONE_DEFINITIONS:
		if level >= zone["min_level"] and level <= zone["max_level"]:
			return zone["name"]
	return ""

static func get_zone_color_for_level(level: int) -> Color:
	for zone in ZONE_DEFINITIONS:
		if level >= zone["min_level"] and level <= zone["max_level"]:
			return zone["color"]
	return Color(0.4, 0.4, 0.4)
