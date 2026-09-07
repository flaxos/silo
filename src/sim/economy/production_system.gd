# src/sim/economy/production_system.gd
class_name ProductionSystem
extends BaseSystem

const INITIAL_SEAM_ORE_KG: float = 100000.0

var _mine_rooms: Array[Room] = []
var _foundry_rooms: Array[Room] = []
var _shop_rooms: Array[Room] = []
var _cached_persons: Array[Person] = []
var _cached_person_count: int = 0
var _is_cached: bool = false

func _init() -> void:
	super("production", 60)

func setup(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	if not ws.custom_data.has("geological_seam_ore_kg"):
		ws.custom_data["geological_seam_ore_kg"] = INITIAL_SEAM_ORE_KG
	_rebuild_caches(ws)

func tick(world_state: Variant) -> void:
	var ws: WorldState = world_state as WorldState
	
	if not _is_cached or _cached_person_count == 0:
		_rebuild_caches(ws)
		
	# 1. Fast tally of on-duty workers by room and occupation
	var workers_by_room: Dictionary = {} # int room_id -> Dictionary (occupation -> int count)
	for i in range(_cached_person_count):
		var p: Person = _cached_persons[i]
		if p.is_alive and not p.is_severely_dehydrated() and p.current_activity == Person.ACTIVITY_WORKING and p.current_location_id > 0:
			var rid: int = p.current_location_id
			if not workers_by_room.has(rid):
				workers_by_room[rid] = {}
			var occ_map: Dictionary = workers_by_room[rid]
			occ_map[p.occupation_id] = occ_map.get(p.occupation_id, 0) + 1
				
	# 2. Step 1 & 2: Deep Mine Extraction & Ore Processing
	var labor_mult: float = float(ws.custom_data.get("production_labor_multiplier", 1.0))
	var mine_count: int = _mine_rooms.size()
	for i in range(mine_count):
		var mine: Room = _mine_rooms[i]
		var inv: Inventory = _get_or_create_room_inventory(ws, mine)
		var occ_map: Dictionary = workers_by_room.get(mine.id, {})
		var miners: int = occ_map.get("miner", 0)
		
		if miners > 0:
			# Extraction from geological seam
			var seam_kg: float = float(ws.custom_data.get("geological_seam_ore_kg", 0.0))
			var extraction_rate_per_miner: float = 1.0 * labor_mult # 1 unit = 1.0 kg * multiplier
			var extract_units: float = minf(seam_kg, float(miners) * extraction_rate_per_miner)
			
			if extract_units > 0.0:
				ws.custom_data["geological_seam_ore_kg"] = seam_kg - extract_units
				inv.add_resource(ResourceRegistry.RES_IRON_ORE, extract_units)
				
			# Beneficiation / Processing: 1.0 kg iron_ore -> 0.8 kg processed_ore + 0.2 kg slag
			var raw_ore: float = inv.get_quantity(ResourceRegistry.RES_IRON_ORE)
			var process_capacity: float = float(miners) * 2.0 * labor_mult
			var units_to_process: float = minf(raw_ore, process_capacity)
			
			if units_to_process > 0.0:
				inv.remove_resource(ResourceRegistry.RES_IRON_ORE, units_to_process)
				inv.add_resource(ResourceRegistry.RES_PROCESSED_ORE, units_to_process)
				inv.add_resource(ResourceRegistry.RES_SLAG_TAILINGS, units_to_process)
				
	# 3. Logistics: Transfer Processed Ore from Mines to Foundries
	if not _mine_rooms.is_empty() and not _foundry_rooms.is_empty():
		var mine_inv: Inventory = _get_or_create_room_inventory(ws, _mine_rooms[0])
		var foundry_inv: Inventory = _get_or_create_room_inventory(ws, _foundry_rooms[0])
		mine_inv.transfer_to(foundry_inv, ResourceRegistry.RES_PROCESSED_ORE, 10.0)
		
	# 4. Step 3: Smelting Foundry (Processed Ore -> Metal Stock + Slag)
	var foundry_count: int = _foundry_rooms.size()
	for i in range(foundry_count):
		var foundry: Room = _foundry_rooms[i]
		var inv: Inventory = _get_or_create_room_inventory(ws, foundry)
		var occ_map: Dictionary = workers_by_room.get(foundry.id, {})
		var furnace_ops: int = occ_map.get("furnace_operator", 0) + occ_map.get("foundry_worker", 0)
		
		if furnace_ops > 0:
			var processed_avail: float = inv.get_quantity(ResourceRegistry.RES_PROCESSED_ORE)
			var smelt_capacity: float = float(furnace_ops) * 1.0 * labor_mult
			var units_to_smelt: float = minf(processed_avail, smelt_capacity)
			
			if units_to_smelt > 0.0:
				# 1 unit processed_ore (0.8 kg) -> 1 unit metal_stock (0.75 kg) + 0.25 units slag (0.05 kg)
				inv.remove_resource(ResourceRegistry.RES_PROCESSED_ORE, units_to_smelt)
				inv.add_resource(ResourceRegistry.RES_METAL_STOCK, units_to_smelt)
				inv.add_resource(ResourceRegistry.RES_SLAG_TAILINGS, units_to_smelt * 0.25)
				
	# 5. Logistics: Transfer Metal Stock from Foundries to Machine Shops
	if not _foundry_rooms.is_empty() and not _shop_rooms.is_empty():
		var foundry_inv: Inventory = _get_or_create_room_inventory(ws, _foundry_rooms[0])
		var shop_inv: Inventory = _get_or_create_room_inventory(ws, _shop_rooms[0])
		foundry_inv.transfer_to(shop_inv, ResourceRegistry.RES_METAL_STOCK, 10.0)
		
	# 6. Step 4: Machine Shop (Metal Stock -> Machined Bearing + Swarf)
	var shop_count: int = _shop_rooms.size()
	for i in range(shop_count):
		var shop: Room = _shop_rooms[i]
		var inv: Inventory = _get_or_create_room_inventory(ws, shop)
		var occ_map: Dictionary = workers_by_room.get(shop.id, {})
		var machinists: int = occ_map.get("machinist", 0) + occ_map.get("welder", 0)
		
		if machinists > 0:
			var stock_avail: float = inv.get_quantity(ResourceRegistry.RES_METAL_STOCK)
			var machine_capacity: float = float(machinists) * 1.0 * labor_mult
			var units_to_machine: float = minf(stock_avail, machine_capacity)
			
			if units_to_machine > 0.0:
				# 1 unit metal_stock (0.75 kg) -> 1 unit machined_bearing (0.5 kg) + 1 unit swarf (0.25 kg)
				inv.remove_resource(ResourceRegistry.RES_METAL_STOCK, units_to_machine)
				inv.add_resource(ResourceRegistry.RES_MACHINED_BEARING, units_to_machine)
				inv.add_resource(ResourceRegistry.RES_METAL_SWARF, units_to_machine)
				
	# 7. Logistics: Transfer Machined Bearings from Machine Shops to Pump Stations
	if not _shop_rooms.is_empty() and not _pump_rooms.is_empty():
		var shop_inv: Inventory = _get_or_create_room_inventory(ws, _shop_rooms[0])
		var pump_inv: Inventory = _get_or_create_room_inventory(ws, _pump_rooms[0])
		shop_inv.transfer_to(pump_inv, ResourceRegistry.RES_MACHINED_BEARING, 5.0)

var _pump_rooms: Array[Room] = []

func _rebuild_caches(ws: WorldState) -> void:
	var registry: EntityRegistry = ws.entity_registry
	_mine_rooms.clear()
	_foundry_rooms.clear()
	_shop_rooms.clear()
	_pump_rooms.clear()
	
	var all_room_ids: Array[int] = registry.get_entities_by_type("room")
	for rid in all_room_ids:
		var r: Room = registry.get_entity(rid) as Room
		if r:
			if r.room_type == Room.TYPE_DEEP_MINE:
				_mine_rooms.append(r)
			elif r.room_type == Room.TYPE_FOUNDRY:
				_foundry_rooms.append(r)
			elif r.room_type == Room.TYPE_MACHINE_SHOP:
				_shop_rooms.append(r)
			elif r.room_type == Room.TYPE_WATER_PUMP_STATION:
				_pump_rooms.append(r)
				
	_cached_persons.clear()
	var all_pids: Array[int] = registry.get_entities_by_type("person")
	for pid in all_pids:
		var p: Person = registry.get_entity(pid) as Person
		if p:
			_cached_persons.append(p)
	_cached_person_count = _cached_persons.size()
	_is_cached = true

func _get_or_create_room_inventory(ws: WorldState, room: Room) -> Inventory:
	var registry: EntityRegistry = ws.entity_registry
	if room.inventory_id > 0:
		var existing: Inventory = registry.get_entity(room.inventory_id) as Inventory
		if existing:
			return existing
			
	var new_inv: Inventory = Inventory.new(0, room.id, 500000.0)
	new_inv.id = registry.register_entity("inventory", new_inv)
	room.inventory_id = new_inv.id
	return new_inv
