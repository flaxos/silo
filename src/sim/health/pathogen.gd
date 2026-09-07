# src/sim/health/pathogen.gd
class_name Pathogen
extends RefCounted

## Authoritative pathogen specification for epidemic and contagion simulation.

var id: String = ""
var name: String = ""
var incubation_ticks: int = 72       # Ticks from exposure to infectiousness (e.g. 12h)
var infectious_ticks: int = 144      # Ticks of active infectiousness (e.g. 24h)
var symptomatic_ticks: int = 144     # Ticks of clinical symptoms (e.g. 24h)
var base_transmission_rate: float = 0.15 # Base chance of transmission per contact hour
var severity: float = 0.3            # Health reduction per day of symptoms (0-1)
var mortality_rate: float = 0.02     # Base mortality chance during symptomatic period
var immunity_ticks: int = 2880       # Ticks of post-recovery immunity (e.g. 20 days)

func _init(p_id: String = "silo_cough", p_name: String = "Silo Cough") -> void:
	id = p_id
	name = p_name
	incubation_ticks = 72
	infectious_ticks = 144
	symptomatic_ticks = 144
	base_transmission_rate = 0.15
	severity = 0.3
	mortality_rate = 0.02
	immunity_ticks = 2880

func serialize() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"incubation_ticks": incubation_ticks,
		"infectious_ticks": infectious_ticks,
		"symptomatic_ticks": symptomatic_ticks,
		"base_transmission_rate": base_transmission_rate,
		"severity": severity,
		"mortality_rate": mortality_rate,
		"immunity_ticks": immunity_ticks
	}

func deserialize(data: Dictionary) -> void:
	id = str(data.get("id", "silo_cough"))
	name = str(data.get("name", "Silo Cough"))
	incubation_ticks = int(data.get("incubation_ticks", 72))
	infectious_ticks = int(data.get("infectious_ticks", 144))
	symptomatic_ticks = int(data.get("symptomatic_ticks", 144))
	base_transmission_rate = float(data.get("base_transmission_rate", 0.15))
	severity = float(data.get("severity", 0.3))
	mortality_rate = float(data.get("mortality_rate", 0.02))
	immunity_ticks = int(data.get("immunity_ticks", 2880))
