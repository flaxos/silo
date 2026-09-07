# src/sim/law/crime_system.gd
class_name CrimeSystem
extends BaseSystem

## Manages systemic crime generation, motive & opportunity calculations,
## physical theft/vandalism execution, evidence logging, and discovery paths.

const CrimeIncident = preload("res://src/sim/law/crime_incident.gd")
const Machine = preload("res://src/sim/machinery/machine.gd")
const MachineComponent = preload("res://src/sim/machinery/machine_component.gd")

var next_crime_id: int = 1

func _init() -> void:
	super("crime_system", 41)
	next_crime_id = 1

func setup(ws: Variant) -> void:
	var world: WorldState = ws as WorldState
	if world:
		if not world.custom_data.has("crime_incidents"):
			world.custom_data["crime_incidents"] = []
		if not world.custom_data.has("black_market_transactions"):
			world.custom_data["black_market_transactions"] = []
		if not world.custom_data.has("official_inventory_ledgers"):
			world.custom_data["official_inventory_ledgers"] = {}

func tick(ws: Variant) -> void:
	var world: WorldState = ws as WorldState
	if not world:
		return
	
	var current_tick: int = world.sim_clock.get_tick()
	# Evaluate spontaneous petty crime periodically (every 24 ticks / 4 sim hours)
	if current_tick % 24 == 0:
		_evaluate_criminal_opportunity(world, current_tick)

func _evaluate_criminal_opportunity(ws: WorldState, current_tick: int) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	for pid in pids:
		var person: Person = registry.get_entity(pid) as Person
		if not person or not person.is_alive or person.life_stage != Person.STAGE_ADULT:
			continue
		
		# Motive: acute economic dissatisfaction, extreme thirst/hunger, or high class resentment
		var has_motive: bool = (person.economic_satisfaction < 0.25 or person.is_severely_dehydrated() or person.class_resentment > 0.8)
		if not has_motive:
			continue
			
		# Opportunity: person is at a workplace with stocked inventory
		if person.workplace_room_id <= 0:
			continue
			
		var work_room: Room = registry.get_entity(person.workplace_room_id) as Room
		var home_room: Room = registry.get_entity(person.home_room_id) as Room
		if not work_room or not home_room or work_room.inventory_id <= 0 or home_room.inventory_id <= 0:
			continue
			
		var work_inv: Inventory = registry.get_entity(work_room.inventory_id) as Inventory
		var home_inv: Inventory = registry.get_entity(home_room.inventory_id) as Inventory
		if not work_inv or not home_inv:
			continue
			
		# Check if workplace has stealable goods (rations or finished goods)
		var stealable_res: String = ""
		for r_id in work_inv.stocks.keys():
			if float(work_inv.stocks[r_id]) >= 1.0:
				stealable_res = r_id
				break
				
		if stealable_res != "":
			# Steal a small unit
			var amount: float = minf(1.0, float(work_inv.stocks[stealable_res]))
			commit_theft(ws, person.id, work_room.id, home_room.id, stealable_res, amount, 0.6)

static func _ensure_room_inventory(ws: WorldState, room: Room) -> Inventory:
	if not room:
		return null
	if room.inventory_id > 0:
		return ws.entity_registry.get_entity(room.inventory_id) as Inventory
	var inv: Inventory = Inventory.new(0, room.id, 100000.0)
	inv.id = ws.entity_registry.register_entity("inventory", inv)
	room.inventory_id = inv.id
	return inv

## Executes an authoritative theft of physical goods.
## Conserves 100% of material mass while generating realistic evidence traces.
func commit_theft(
	ws: WorldState,
	perp_id: int,
	source_room_id: int,
	dest_room_id: int,
	res_id: String,
	amount: float,
	concealment: float = 0.5
) -> CrimeIncident:
	var registry: EntityRegistry = ws.entity_registry
	var perp: Person = registry.get_entity(perp_id) as Person
	var src_room: Room = registry.get_entity(source_room_id) as Room
	var dst_room: Room = registry.get_entity(dest_room_id) as Room
	
	if not perp or not src_room or not dst_room or amount <= 0.0:
		return null
		
	var src_inv: Inventory = _ensure_room_inventory(ws, src_room)
	var dst_inv: Inventory = _ensure_room_inventory(ws, dst_room)
	if not src_inv or not dst_inv:
		return null
		
	# Physical transfer from source to destination
	var removed: float = src_inv.remove_resource(res_id, amount)
	if removed <= 0.0:
		return null
	dst_inv.add_resource(res_id, removed)
	
	# Discrepancy creation in official records
	var ledgers: Dictionary = ws.custom_data.get("official_inventory_ledgers", {})
	if not ledgers.has(source_room_id):
		ledgers[source_room_id] = {}
	if not ledgers[source_room_id].has(res_id):
		ledgers[source_room_id][res_id] = src_inv.get_stock(res_id) + removed
	var official_recorded: float = float(ledgers[source_room_id][res_id])
	var physical_actual: float = src_inv.get_stock(res_id)
	var discrepancy: float = absf(official_recorded - physical_actual)
	
	# Grounded Evidence Generation
	var current_tick: int = ws.sim_clock.get_tick()
	var witnesses: Array[int] = []
	var pids: Array[int] = registry.get_entities_by_type("person")
	for pid in pids:
		var other: Person = registry.get_entity(pid) as Person
		if other and other.is_alive and other.id != perp.id and other.current_location_id == source_room_id:
			witnesses.append(other.id)
			
	var crime: CrimeIncident = CrimeIncident.new(
		next_crime_id,
		CrimeIncident.TYPE_THEFT,
		perp.id,
		source_room_id,
		current_tick,
		res_id,
		removed
	)
	next_crime_id += 1
	
	crime.concealment_level = clampf(concealment, 0.0, 1.0)
	crime.evidence["badge_log_recorded"] = true # Access system automatically logged the room entry
	crime.evidence["cctv_recorded"] = bool(ws.custom_data.get("cctv_active", false))
	crime.evidence["witness_ids"] = witnesses
	crime.evidence["inventory_discrepancy"] = discrepancy
	crime.evidence["physical_traces"] = "missing_container_tampered_seal"
	
	var list: Array = ws.custom_data.get("crime_incidents", [])
	list.append(crime)
	ws.custom_data["crime_incidents"] = list
	
	return crime

## Executes physical machinery vandalism / sabotage as a criminal act.
func commit_vandalism(
	ws: WorldState,
	perp_id: int,
	machine_id: int,
	component_id: String,
	damage_amount: float,
	concealment: float = 0.5
) -> CrimeIncident:
	var registry: EntityRegistry = ws.entity_registry
	var perp: Person = registry.get_entity(perp_id) as Person
	var machine: Machine = registry.get_entity(machine_id) as Machine
	
	if not perp or not machine or damage_amount <= 0.0:
		return null
		
	var comp: MachineComponent = machine.components.get(component_id, null)
	if not comp:
		return null
		
	# Physically degrade the component
	comp.wear_percent = clampf(comp.wear_percent + damage_amount, 0.0, 100.0)
	machine.update_state()
	
	var current_tick: int = ws.sim_clock.get_tick()
	var witnesses: Array[int] = []
	var pids: Array[int] = registry.get_entities_by_type("person")
	for pid in pids:
		var other: Person = registry.get_entity(pid) as Person
		if other and other.is_alive and other.id != perp.id and other.current_location_id == machine.room_id:
			witnesses.append(other.id)
			
	var crime: CrimeIncident = CrimeIncident.new(
		next_crime_id,
		CrimeIncident.TYPE_VANDALISM,
		perp.id,
		machine.room_id,
		current_tick,
		"",
		0.0
	)
	next_crime_id += 1
	
	crime.target_machine_id = machine_id
	crime.target_component_id = component_id
	crime.concealment_level = clampf(concealment, 0.0, 1.0)
	crime.evidence["badge_log_recorded"] = true
	crime.evidence["cctv_recorded"] = bool(ws.custom_data.get("cctv_active", false))
	crime.evidence["witness_ids"] = witnesses
	crime.evidence["physical_traces"] = "forced_tool_marks_on_%s" % component_id
	
	var list: Array = ws.custom_data.get("crime_incidents", [])
	list.append(crime)
	ws.custom_data["crime_incidents"] = list
	
	return crime

## Marks a crime as discovered (e.g. following an audit or witness statement).
func report_crime(ws: WorldState, crime_id: int) -> bool:
	var list: Array = ws.custom_data.get("crime_incidents", [])
	for item in list:
		var c: CrimeIncident = item as CrimeIncident
		if c and c.id == crime_id:
			c.status = CrimeIncident.STATUS_DISCOVERED
			return true
	return false

func get_crime(ws: WorldState, crime_id: int) -> CrimeIncident:
	var list: Array = ws.custom_data.get("crime_incidents", [])
	for item in list:
		var c: CrimeIncident = item as CrimeIncident
		if c and c.id == crime_id:
			return c
	return null

func get_all_crimes(ws: WorldState) -> Array[CrimeIncident]:
	var results: Array[CrimeIncident] = []
	var list: Array = ws.custom_data.get("crime_incidents", [])
	for item in list:
		var c: CrimeIncident = item as CrimeIncident
		if c:
			results.append(c)
	return results

func serialize() -> Dictionary:
	return {
		"system_id": system_id,
		"execution_order": execution_order,
		"next_crime_id": next_crime_id
	}

func deserialize(d: Dictionary) -> void:
	system_id = str(d.get("system_id", "crime_system"))
	execution_order = int(d.get("execution_order", 41))
	next_crime_id = int(d.get("next_crime_id", 1))
