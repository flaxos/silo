class_name OperationsSession
extends RefCounted

## Bounded gameplay bootstrap. No renderer state or future-domain systems.
static func create(population: int = 1200, seed_value: int = 42) -> SimulationEngine:
	var engine := SimulationEngine.new(seed_value)
	var ws := engine.get_world_state()
	PopulationGenerator.generate_population(ws, population)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	ws.custom_data["player_role"] = OperationsConfig.ROLE_IT
	ws.custom_data["it_service_delegation"] = true
	for mid in ws.entity_registry.get_entities_by_type("machine"):
		var pump := ws.entity_registry.get_entity(mid) as WaterPump
		if pump:
			var hours := OperationsConfig.INITIAL_BEARING_WEAR / pump.get_component(WaterPump.COMP_BEARING).wear_rate_per_hour
			pump.total_operating_hours = hours
			for comp in pump.components.values():
				comp.wear_percent = minf(100.0, hours * comp.wear_rate_per_hour)
			pump.update_state()
	_register(engine)
	return engine

static func _register(engine: SimulationEngine, saved_systems: Dictionary = {}) -> void:
	var systems: Array[BaseSystem] = [InstitutionSystem.new(), InformationSystem.new(), DailyLifeSystem.new(), MaintenanceSystem.new(), ProductionSystem.new(), WaterSystem.new(), IncidentSystem.new(), OperationsSystem.new()]
	for sys in systems:
		if saved_systems.has(sys.system_id) and sys.has_method("deserialize"):
			sys.deserialize(saved_systems[sys.system_id])
		engine.register_system(sys)

## Engine's legacy save method does not rehydrate domain entities. This codec is
## deliberately limited to this session's known types, with binary Variant data
## preserving integer dictionary keys and RNG bits (JSON cannot do that).
static func capture(engine: SimulationEngine) -> Dictionary:
	var ws := engine.get_world_state()
	var custom := {}
	for key in ws.custom_data:
		var value: Variant = ws.custom_data[key]
		if value is BaseSystem or key in ["information_objects", "pending_delayed_information"]:
			continue
		custom[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	var information := []
	for info in ws.custom_data.get("information_objects", []): information.append(info.serialize())
	var pending := []
	for info in ws.custom_data.get("pending_delayed_information", []): pending.append(info.id)
	var systems := {}
	for sys in engine.scheduler.get_all_systems():
		if sys.has_method("serialize"): systems[sys.system_id] = sys.serialize()
	return {"operations_format": 1, "seed": ws.initial_seed, "clock": ws.sim_clock.serialize(), "rng": ws.rng.serialize(),
		"entities": ws.entity_registry.serialize(), "events": ws.event_queue.serialize(), "custom": custom,
		"information": information, "pending_information": pending, "systems": systems}

static func restore(data: Dictionary) -> SimulationEngine:
	if int(data.get("operations_format", 0)) != 1:
		return null
	for key in ["clock", "rng", "entities", "events", "custom", "systems"]:
		if not data.get(key) is Dictionary: return null
	for key in ["information", "pending_information"]:
		if not data.get(key) is Array: return null
	if not data.has("seed") or not data.entities.get("entities") is Array:
		return null
	var engine := SimulationEngine.new(int(data.seed))
	var ws := engine.get_world_state()
	ws.sim_clock.deserialize(data.clock)
	ws.rng.deserialize(data.rng)
	# Restore registry next-ID as well as exact typed objects and references.
	var registry_data: Dictionary = data.entities.duplicate(true)
	var entities: Array = registry_data.get("entities", [])
	for item in entities:
		var entity: Variant
		match str(item.type):
			"person": entity = Person.new()
			"household": entity = Household.new()
			"room": entity = Room.new()
			"inventory": entity = Inventory.new()
			"machine": entity = WaterPump.new() if item.data.get("machine_type", "") == WaterPump.TYPE_NAME else Machine.new()
			_: return null
		entity.deserialize(item.data)
		item.data = entity
	ws.entity_registry.deserialize(registry_data)
	ws.event_queue.deserialize(data.events)
	ws.custom_data = data.custom.duplicate(true)
	var infos := []
	var pending := []
	for raw in data.information:
		var info := InformationObject.new()
		info.deserialize(raw)
		infos.append(info)
		if info.id in data.pending_information: pending.append(info)
	ws.custom_data["information_objects"] = infos
	ws.custom_data["pending_delayed_information"] = pending
	_register(engine, data.systems)
	# DailyLife.setup initializes a fresh graph; reinstate saved in-flight travel.
	if data.custom.has(SpatialTravelModel.STATE_KEY):
		ws.custom_data[SpatialTravelModel.STATE_KEY] = data.custom[SpatialTravelModel.STATE_KEY].duplicate(true)
	return engine

static func save_file(engine: SimulationEngine, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file: return FileAccess.get_open_error()
	file.store_var(capture(engine), false)
	return file.get_error()

static func load_file(path: String) -> SimulationEngine:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return null
	var data: Variant = file.get_var(false)
	return restore(data) if data is Dictionary else null
