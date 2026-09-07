# src/sim/machinery/machine_component.gd
class_name MachineComponent
extends RefCounted

const STATE_NOMINAL: int = 0   # Wear < 60%
const STATE_DEGRADED: int = 1  # Wear 60% - 90%
const STATE_FAULT: int = 2     # Wear 90% - 99.9%
const STATE_BROKEN: int = 3    # Wear 100%

var id: String = ""
var name: String = ""
var wear_percent: float = 0.0 # 0.0 to 100.0
var wear_rate_per_hour: float = 0.1 # % per operating hour
var criticality: float = 1.0 # 0.0 to 1.0 (1.0 = failure halts machine)
var required_spare_resource_id: String = "" # e.g. ResourceRegistry.RES_MACHINED_BEARING
var required_spare_quantity: float = 1.0
var repair_ticks_required: int = 12 # 12 ticks * 10 min = 2 hours
var accumulated_repair_ticks: int = 0

func _init(
	p_id: String = "",
	p_name: String = "",
	p_wear_rate_per_hour: float = 0.1,
	p_criticality: float = 1.0,
	p_required_spare: String = "",
	p_required_qty: float = 1.0,
	p_repair_ticks: int = 12
) -> void:
	id = p_id
	name = p_name
	wear_rate_per_hour = p_wear_rate_per_hour
	criticality = p_criticality
	required_spare_resource_id = p_required_spare
	required_spare_quantity = p_required_qty
	repair_ticks_required = p_repair_ticks
	wear_percent = 0.0
	accumulated_repair_ticks = 0

func add_operating_hours(hours: float) -> void:
	if hours <= 0.0:
		return
	wear_percent = minf(100.0, wear_percent + (wear_rate_per_hour * hours))

func get_wear_state() -> int:
	if wear_percent >= 100.0 - 0.001:
		return STATE_BROKEN
	elif wear_percent >= 90.0 - 0.001:
		return STATE_FAULT
	elif wear_percent >= 60.0 - 0.001:
		return STATE_DEGRADED
	else:
		return STATE_NOMINAL

func is_broken() -> bool:
	return wear_percent >= (100.0 - 0.001)

func get_efficiency() -> float:
	if is_broken():
		return 0.0
	elif wear_percent >= 90.0 - 0.001:
		# Between 90% and 100% wear: drops from 0.70 down to 0.20
		var progress: float = (wear_percent - 90.0) / 10.0
		return maxf(0.0, 0.70 - (progress * 0.50))
	elif wear_percent >= 60.0 - 0.001:
		# Between 60% and 90% wear: drops from 1.0 down to 0.70
		var progress: float = (wear_percent - 60.0) / 30.0
		return maxf(0.70, 1.0 - (progress * 0.30))
	else:
		return 1.0

func repair() -> void:
	wear_percent = 0.0
	accumulated_repair_ticks = 0

func serialize() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"wear_percent": wear_percent,
		"wear_rate_per_hour": wear_rate_per_hour,
		"criticality": criticality,
		"required_spare_resource_id": required_spare_resource_id,
		"required_spare_quantity": required_spare_quantity,
		"repair_ticks_required": repair_ticks_required,
		"accumulated_repair_ticks": accumulated_repair_ticks
	}

func deserialize(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	wear_percent = float(data.get("wear_percent", 0.0))
	wear_rate_per_hour = float(data.get("wear_rate_per_hour", 0.1))
	criticality = float(data.get("criticality", 1.0))
	required_spare_resource_id = data.get("required_spare_resource_id", "")
	required_spare_quantity = float(data.get("required_spare_quantity", 1.0))
	repair_ticks_required = int(data.get("repair_ticks_required", 12))
	accumulated_repair_ticks = int(data.get("accumulated_repair_ticks", 0))
