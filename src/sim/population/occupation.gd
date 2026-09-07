# src/sim/population/occupation.gd
class_name Occupation
extends RefCounted

const SHIFT_OFF: int = 0
const SHIFT_DAY: int = 1     # 08:00 - 16:00 (tick 48 to 96)
const SHIFT_SWING: int = 2   # 16:00 - 00:00 (tick 96 to 144)
const SHIFT_NIGHT: int = 3   # 00:00 - 08:00 (tick 0 to 48)

const DEPT_MINING: String = "industry_mining"
const DEPT_PROCESSING: String = "industry_processing"
const DEPT_FOUNDRY: String = "industry_foundry"
const DEPT_MANUFACTURING: String = "industry_manufacturing"
const DEPT_ELECTRICAL: String = "engineering_electrical"
const DEPT_WATER: String = "engineering_water"
const DEPT_VENTILATION: String = "engineering_ventilation"
const DEPT_MAINTENANCE: String = "engineering_maintenance"
const DEPT_AGRICULTURE: String = "agriculture_food"
const DEPT_MEDICAL: String = "medical_clinic"
const DEPT_EDUCATION: String = "education_school"
const DEPT_LOGISTICS: String = "logistics_stores"
const DEPT_IT: String = "executive_it"
const DEPT_SANITATION: String = "sanitation"

const OCCUPATION_DEFINITIONS: Dictionary = {
	"miner": {
		"title": "Miner",
		"department": DEPT_MINING,
		"room_type": Room.TYPE_DEEP_MINE,
		"shifts": [SHIFT_DAY, SHIFT_SWING, SHIFT_NIGHT]
	},
	"furnace_operator": {
		"title": "Furnace Operator",
		"department": DEPT_FOUNDRY,
		"room_type": Room.TYPE_FOUNDRY,
		"shifts": [SHIFT_DAY, SHIFT_SWING, SHIFT_NIGHT]
	},
	"foundry_worker": {
		"title": "Foundry Worker",
		"department": DEPT_FOUNDRY,
		"room_type": Room.TYPE_FOUNDRY,
		"shifts": [SHIFT_DAY, SHIFT_SWING]
	},
	"machinist": {
		"title": "Machinist",
		"department": DEPT_MANUFACTURING,
		"room_type": Room.TYPE_MACHINE_SHOP,
		"shifts": [SHIFT_DAY, SHIFT_SWING]
	},
	"welder": {
		"title": "Fabricator / Welder",
		"department": DEPT_MANUFACTURING,
		"room_type": Room.TYPE_MACHINE_SHOP,
		"shifts": [SHIFT_DAY, SHIFT_SWING]
	},
	"maintenance_technician": {
		"title": "Maintenance Technician",
		"department": DEPT_MAINTENANCE,
		"room_type": Room.TYPE_WATER_PUMP_STATION,
		"shifts": [SHIFT_DAY, SHIFT_SWING, SHIFT_NIGHT]
	},
	"electrician": {
		"title": "Electrician",
		"department": DEPT_ELECTRICAL,
		"room_type": Room.TYPE_SERVER_ROOM,
		"shifts": [SHIFT_DAY, SHIFT_SWING]
	},
	"it_technician": {
		"title": "IT Systems Technician",
		"department": DEPT_IT,
		"room_type": Room.TYPE_SERVER_ROOM,
		"shifts": [SHIFT_DAY, SHIFT_SWING]
	},
	"doctor": {
		"title": "Physician",
		"department": DEPT_MEDICAL,
		"room_type": Room.TYPE_CLINIC,
		"shifts": [SHIFT_DAY, SHIFT_NIGHT]
	},
	"nurse": {
		"title": "Nurse",
		"department": DEPT_MEDICAL,
		"room_type": Room.TYPE_CLINIC,
		"shifts": [SHIFT_DAY, SHIFT_SWING, SHIFT_NIGHT]
	},
	"teacher": {
		"title": "Teacher",
		"department": DEPT_EDUCATION,
		"room_type": Room.TYPE_SCHOOL,
		"shifts": [SHIFT_DAY]
	},
	"cook": {
		"title": "Kitchen Staff",
		"department": DEPT_AGRICULTURE,
		"room_type": Room.TYPE_KITCHEN,
		"shifts": [SHIFT_DAY, SHIFT_SWING]
	},
	"sanitation_worker": {
		"title": "Sanitation Worker",
		"department": DEPT_SANITATION,
		"room_type": Room.TYPE_HYGIENE_FACILITY,
		"shifts": [SHIFT_DAY, SHIFT_NIGHT]
	},
	"student": {
		"title": "Student",
		"department": DEPT_EDUCATION,
		"room_type": Room.TYPE_SCHOOL,
		"shifts": [SHIFT_DAY]
	},
	"retired": {
		"title": "Retired",
		"department": "",
		"room_type": Room.TYPE_RESIDENTIAL_APARTMENT,
		"shifts": [SHIFT_OFF]
	},
	"unassigned": {
		"title": "Unassigned",
		"department": "",
		"room_type": Room.TYPE_RESIDENTIAL_APARTMENT,
		"shifts": [SHIFT_OFF]
	}
}

static func get_shift_name(shift_id: int) -> String:
	match shift_id:
		SHIFT_DAY:
			return "Day Shift (08:00 - 16:00)"
		SHIFT_SWING:
			return "Swing Shift (16:00 - 00:00)"
		SHIFT_NIGHT:
			return "Night Shift (00:00 - 08:00)"
		_:
			return "Off Duty"

static func is_work_hour(shift_id: int, tick_of_day: int) -> bool:
	match shift_id:
		SHIFT_DAY:
			return tick_of_day >= 48 and tick_of_day < 96  # 08:00 to 16:00
		SHIFT_SWING:
			return tick_of_day >= 96 and tick_of_day < 144 # 16:00 to 24:00
		SHIFT_NIGHT:
			return tick_of_day >= 0 and tick_of_day < 48   # 00:00 to 08:00
		_:
			return false
