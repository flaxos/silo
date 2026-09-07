# src/sim/institutions/policy.gd
class_name Policy
extends RefCounted

const CATEGORY_RATIONING: String = "rationing"
const CATEGORY_WORK_HOURS: String = "work_hours"
const CATEGORY_MAINTENANCE: String = "maintenance"
const CATEGORY_SECURITY: String = "security"
const CATEGORY_EDUCATION: String = "education"

# Standard Presets
const POLICY_RATION_STANDARD: String = "ration_standard"
const POLICY_RATION_STRICT: String = "ration_strict"
const POLICY_RATION_EMERGENCY: String = "ration_emergency"

const POLICY_WORK_STANDARD_8H: String = "work_standard_8h"
const POLICY_WORK_EXTENDED_10H: String = "work_extended_10h"
const POLICY_WORK_DOUBLE_12H: String = "work_double_12h"

const POLICY_MAINT_PREVENTATIVE: String = "maint_preventative"
const POLICY_MAINT_STANDARD: String = "maint_standard"
const POLICY_MAINT_DEFERRED: String = "maint_deferred"

const POLICY_SECURITY_OPEN: String = "security_open"
const POLICY_SECURITY_QUARANTINE: String = "security_quarantine"

const POLICY_EDU_STANDARD: String = "edu_standard"
const POLICY_EDU_ACCELERATED: String = "edu_accelerated"

var id: String = ""
var name: String = ""
var description: String = ""
var category: String = ""
var department_id: String = ""
var required_clearance: int = 0
var parameters: Dictionary = {}
var is_active: bool = false
var enacted_tick: int = 0

func _init(
	p_id: String = "",
	p_name: String = "",
	p_category: String = "",
	p_dept: String = "",
	p_params: Dictionary = {},
	p_clearance: int = 0
) -> void:
	id = p_id
	name = p_name
	category = p_category
	department_id = p_dept
	parameters = p_params.duplicate(true)
	required_clearance = p_clearance
	is_active = false
	enacted_tick = 0

static func create_default_policies() -> Dictionary:
	var map: Dictionary = {}
	
	# 1. Rationing Policies
	map[POLICY_RATION_STANDARD] = Policy.new(
		POLICY_RATION_STANDARD,
		"Standard Water Rationing (2.5 L/day)",
		CATEGORY_RATIONING,
		"utilities",
		{
			"water_ration_l_per_tick": 2.5 / 144.0, # ~0.017361 L/tick
			"hydration_recovery_mult": 1.0,
			"tension_per_day": 0.0,
			"fatigue_decay_mult": 1.0
		},
		0
	)
	
	map[POLICY_RATION_STRICT] = Policy.new(
		POLICY_RATION_STRICT,
		"Strict Water Conservation (1.8 L/day)",
		CATEGORY_RATIONING,
		"utilities",
		{
			"water_ration_l_per_tick": 1.8 / 144.0, # 0.0125 L/tick
			"hydration_recovery_mult": 0.72,
			"tension_per_day": 0.05,
			"fatigue_decay_mult": 0.95
		},
		1
	)
	
	map[POLICY_RATION_EMERGENCY] = Policy.new(
		POLICY_RATION_EMERGENCY,
		"Emergency Water Preservation (1.2 L/day)",
		CATEGORY_RATIONING,
		"utilities",
		{
			"water_ration_l_per_tick": 1.2 / 144.0, # ~0.008333 L/tick
			"hydration_recovery_mult": 0.48,
			"tension_per_day": 0.25,
			"fatigue_decay_mult": 0.85
		},
		2
	)
	
	# 2. Work Hours Policies
	map[POLICY_WORK_STANDARD_8H] = Policy.new(
		POLICY_WORK_STANDARD_8H,
		"Standard 8-Hour Work Shifts",
		CATEGORY_WORK_HOURS,
		"industry",
		{
			"shift_work_hours": 8,
			"production_labor_mult": 1.0,
			"machine_wear_rate_mult": 1.0,
			"worker_fatigue_rate_mult": 1.0,
			"tension_per_day": 0.0
		},
		0
	)
	
	map[POLICY_WORK_EXTENDED_10H] = Policy.new(
		POLICY_WORK_EXTENDED_10H,
		"Mandatory 10-Hour Extended Shifts",
		CATEGORY_WORK_HOURS,
		"industry",
		{
			"shift_work_hours": 10,
			"production_labor_mult": 1.25,
			"machine_wear_rate_mult": 1.25,
			"worker_fatigue_rate_mult": 1.40,
			"tension_per_day": 0.10
		},
		1
	)
	
	map[POLICY_WORK_DOUBLE_12H] = Policy.new(
		POLICY_WORK_DOUBLE_12H,
		"Emergency 12-Hour Surge Shifts",
		CATEGORY_WORK_HOURS,
		"industry",
		{
			"shift_work_hours": 12,
			"production_labor_mult": 1.50,
			"machine_wear_rate_mult": 1.50,
			"worker_fatigue_rate_mult": 2.00,
			"tension_per_day": 0.30
		},
		2
	)
	
	# 3. Maintenance Servicing Policies
	map[POLICY_MAINT_PREVENTATIVE] = Policy.new(
		POLICY_MAINT_PREVENTATIVE,
		"Aggressive Preventative Maintenance (>= 40% Wear)",
		CATEGORY_MAINTENANCE,
		"engineering",
		{
			"maintenance_wear_threshold": 40.0,
			"labor_allocation_priority": 1.5,
			"breakdown_risk_mult": 0.20
		},
		1
	)
	
	map[POLICY_MAINT_STANDARD] = Policy.new(
		POLICY_MAINT_STANDARD,
		"Standard Servicing Threshold (>= 60% Wear)",
		CATEGORY_MAINTENANCE,
		"engineering",
		{
			"maintenance_wear_threshold": 60.0,
			"labor_allocation_priority": 1.0,
			"breakdown_risk_mult": 1.0
		},
		0
	)
	
	map[POLICY_MAINT_DEFERRED] = Policy.new(
		POLICY_MAINT_DEFERRED,
		"Deferred Maintenance (>= 85% Wear)",
		CATEGORY_MAINTENANCE,
		"engineering",
		{
			"maintenance_wear_threshold": 85.0,
			"labor_allocation_priority": 0.5,
			"breakdown_risk_mult": 3.0
		},
		1
	)
	
	# 4. Security & Transit Policies
	map[POLICY_SECURITY_OPEN] = Policy.new(
		POLICY_SECURITY_OPEN,
		"Open Intra-Habitat Transit",
		CATEGORY_SECURITY,
		"security",
		{
			"inter_sector_clearance_required": 0,
			"tension_per_day": 0.0
		},
		0
	)
	
	map[POLICY_SECURITY_QUARANTINE] = Policy.new(
		POLICY_SECURITY_QUARANTINE,
		"Habitat Sector Lockdown / Quarantine",
		CATEGORY_SECURITY,
		"security",
		{
			"inter_sector_clearance_required": 2,
			"tension_per_day": 0.15
		},
		2
	)
	
	# 5. Education Policies
	map[POLICY_EDU_STANDARD] = Policy.new(
		POLICY_EDU_STANDARD,
		"Comprehensive General Education (Age 18 Graduation)",
		CATEGORY_EDUCATION,
		"education",
		{
			"graduation_age": 18,
			"education_gain_per_tick": 0.0005,
			"technical_skill_bonus": 1.0
		},
		0
	)
	
	map[POLICY_EDU_ACCELERATED] = Policy.new(
		POLICY_EDU_ACCELERATED,
		"Accelerated Technical Conscription (Age 16 Graduation)",
		CATEGORY_EDUCATION,
		"education",
		{
			"graduation_age": 16,
			"education_gain_per_tick": 0.0007,
			"technical_skill_bonus": 0.80,
			"tension_per_day": 0.08
		},
		1
	)
	
	return map

func serialize() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"category": category,
		"department_id": department_id,
		"required_clearance": required_clearance,
		"parameters": parameters.duplicate(true),
		"is_active": is_active,
		"enacted_tick": enacted_tick
	}

func deserialize(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	category = data.get("category", "")
	department_id = data.get("department_id", "")
	required_clearance = int(data.get("required_clearance", 0))
	parameters = data.get("parameters", {}).duplicate(true)
	is_active = bool(data.get("is_active", false))
	enacted_tick = int(data.get("enacted_tick", 0))
