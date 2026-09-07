# src/sim/machinery/water_pump.gd
class_name WaterPump
extends Machine

const TYPE_NAME: String = "water_pump"

const COMP_MOTOR: String = "electric_motor_15kw"
const COMP_BEARING: String = "bearing_roller_50mm"
const COMP_SHAFT_SEAL: String = "shaft_seal_viton"
const COMP_IMPELLER: String = "impeller_bronze"

var max_water_throughput_lpm: float = 500.0
var current_water_throughput_lpm: float = 500.0

func _init(p_id: int = 0, p_room_id: int = 0) -> void:
	super(p_id, p_room_id, TYPE_NAME)
	max_water_throughput_lpm = 500.0
	current_water_throughput_lpm = 500.0
	operating_power_draw_kw = 15.0
	
	_setup_default_components()

func _setup_default_components() -> void:
	components.clear()
	
	# 1. Electric Motor: slow degradation (0.02%/hr -> 5000 hrs life)
	add_component(MachineComponent.new(
		COMP_MOTOR,
		"15kW Electric Drive Motor",
		0.02,
		1.0,
		ResourceRegistry.RES_METAL_STOCK,
		1.0,
		18
	))
	
	# 2. Roller Bearing: main wearing component (0.10%/hr -> 1000 hrs life = 6000 ticks)
	# Requires machined_bearing manufactured in the Machine Shop!
	add_component(MachineComponent.new(
		COMP_BEARING,
		"50mm Cylindrical Roller Bearing",
		0.10,
		1.0,
		ResourceRegistry.RES_MACHINED_BEARING,
		1.0,
		12
	))
	
	# 3. Shaft Seal: moderate degradation (0.04%/hr -> 2500 hrs life)
	add_component(MachineComponent.new(
		COMP_SHAFT_SEAL,
		"Viton Mechanical Shaft Seal",
		0.04,
		0.8,
		"",
		0.0,
		6
	))
	
	# 4. Impeller: bronze fluid impeller (0.03%/hr -> 3333 hrs life)
	add_component(MachineComponent.new(
		COMP_IMPELLER,
		"Bronze Closed Impeller",
		0.03,
		0.9,
		ResourceRegistry.RES_METAL_STOCK,
		1.0,
		12
	))
	
	update_state()

func update_state() -> void:
	super.update_state()
	current_water_throughput_lpm = max_water_throughput_lpm * get_overall_efficiency()

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["max_water_throughput_lpm"] = max_water_throughput_lpm
	data["current_water_throughput_lpm"] = current_water_throughput_lpm
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	max_water_throughput_lpm = float(data.get("max_water_throughput_lpm", 500.0))
	current_water_throughput_lpm = float(data.get("current_water_throughput_lpm", 500.0))
