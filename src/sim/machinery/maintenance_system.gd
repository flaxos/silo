# src/sim/machinery/maintenance_system.gd
class_name MaintenanceSystem
extends BaseSystem

const SYSTEM_ID: String = "machinery_maintenance"
const EXECUTION_ORDER: int = 55
const HOURS_PER_TICK: float = 10.0 / 60.0 # 1/6 hour per 10-minute tick
const MAINTENANCE_TRIGGER_WEAR: float = 60.0
const MAX_CREW_PER_MACHINE: int = 3 # Physical workspace limit per machine component


var _cached_machines: Array[Machine] = []
var _cached_persons: Array[Person] = []
var _cached_person_count: int = 0
var _is_cached: bool = false

func _init() -> void:
	super(SYSTEM_ID, EXECUTION_ORDER)

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	_rebuild_caches(ws)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	
	if not _is_cached:
		_rebuild_caches(ws)
		
	# 1. Step continuous degradation for running machines
	var wear_mult: float = float(ws.custom_data.get("machine_wear_multiplier", 1.0))
	var hours_this_tick: float = HOURS_PER_TICK * wear_mult
	var machine_count: int = _cached_machines.size()
	for i in range(machine_count):
		var m: Machine = _cached_machines[i]
		m.tick_operation(hours_this_tick)
		
	# 2. Tally on-duty maintenance workers by room
	var workers_by_room: Dictionary = {} # int room_id -> int technician_count
	for i in range(_cached_person_count):
		var p: Person = _cached_persons[i]
		if p.is_alive and not p.is_severely_dehydrated() and p.current_activity == Person.ACTIVITY_WORKING and p.current_location_id > 0:
			if p.occupation_id == "maintenance_technician":
				var rid: int = p.current_location_id
				workers_by_room[rid] = workers_by_room.get(rid, 0) + 1
				
	# 3. Process maintenance and component repairs
	for i in range(machine_count):
		var machine: Machine = _cached_machines[i]
		var trigger_wear: float = float(ws.custom_data.get("maintenance_trigger_wear", MAINTENANCE_TRIGGER_WEAR))
		var institution := ws.custom_data.get("institution_system") as InstitutionSystem
		if institution:
			trigger_wear = institution.get_machine_maintenance_threshold(machine.id)
		var tech_count: int = workers_by_room.get(machine.room_id, 0)
		
		if tech_count <= 0:
			continue
			
		# Identify active or next target component needing maintenance
		var target_comp: MachineComponent = null
		if machine.active_repair_component_id != "" and machine.components.has(machine.active_repair_component_id):
			var active_c: MachineComponent = machine.components[machine.active_repair_component_id] as MachineComponent
			if active_c.wear_percent >= trigger_wear - 0.001 or active_c.accumulated_repair_ticks > 0:
				target_comp = active_c
			else:
				machine.active_repair_component_id = ""
				
		if target_comp == null:
			# Find most worn component >= threshold
			var highest_wear: float = -1.0
			var sorted_keys: Array = machine.components.keys()
			sorted_keys.sort()
			
			for k in sorted_keys:
				var c: MachineComponent = machine.components[k] as MachineComponent
				if c.wear_percent >= trigger_wear - 0.001 and c.wear_percent > highest_wear:
					highest_wear = c.wear_percent
					target_comp = c
					
			if target_comp != null:
				machine.active_repair_component_id = target_comp.id
				
		if target_comp == null:
			continue
			
		# Verify spare part availability before committing labor
		var inv: Inventory = _get_or_create_room_inventory(ws, machine.room_id)
		var needs_spare: bool = (target_comp.required_spare_resource_id != "" and target_comp.required_spare_quantity > 0.0)
		
		if needs_spare and not inv.has_resource(target_comp.required_spare_resource_id, target_comp.required_spare_quantity):
			# Cannot repair without required spare component in inventory
			continue
			
		# Apply technician labor ticks (capped by physical workspace on component)
		var effective_crew: int = mini(tech_count, MAX_CREW_PER_MACHINE)
		target_comp.accumulated_repair_ticks += effective_crew
		
		if target_comp.accumulated_repair_ticks >= target_comp.repair_ticks_required:
			# Consume spare part from inventory
			if needs_spare:
				inv.remove_resource(target_comp.required_spare_resource_id, target_comp.required_spare_quantity)
				var consumed_mass: float = target_comp.required_spare_quantity * ResourceRegistry.get_unit_mass(target_comp.required_spare_resource_id)
				ws.custom_data["maintenance_installed_mass_kg"] = float(ws.custom_data.get("maintenance_installed_mass_kg", 0.0)) + consumed_mass
				
			# Complete repair and reset wear
			target_comp.repair()
			machine.active_repair_component_id = ""
			machine.update_state()

func _rebuild_caches(ws: WorldState) -> void:
	var registry: EntityRegistry = ws.entity_registry
	_cached_machines.clear()
	
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	for mid in machine_ids:
		var m: Machine = registry.get_entity(mid) as Machine
		if m:
			_cached_machines.append(m)
			
	_cached_persons.clear()
	var person_ids: Array[int] = registry.get_entities_by_type("person")
	for pid in person_ids:
		var p: Person = registry.get_entity(pid) as Person
		if p:
			_cached_persons.append(p)
	_cached_person_count = _cached_persons.size()
	_is_cached = true

func _get_or_create_room_inventory(ws: WorldState, room_id: int) -> Inventory:
	var registry: EntityRegistry = ws.entity_registry
	var room: Room = registry.get_entity(room_id) as Room
	if not room:
		return null
		
	if room.inventory_id > 0:
		var existing: Inventory = registry.get_entity(room.inventory_id) as Inventory
		if existing:
			return existing
			
	var new_inv: Inventory = Inventory.new(0, room.id, 500000.0)
	new_inv.id = registry.register_entity("inventory", new_inv)
	room.inventory_id = new_inv.id
	return new_inv
