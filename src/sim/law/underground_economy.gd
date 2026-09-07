# src/sim/law/underground_economy.gd
class_name UndergroundEconomy
extends RefCounted

## Manages informal black-market exchange, contraband distribution,
## and scarcity-driven pricing in the silo under-grid.

const CONTRABAND_STIMULANT: String = "contraband_stimulant"
const CONTRABAND_RADIO: String = "unregistered_radio"
const CONTRABAND_RATION: String = "illicit_ration"
const CONTRABAND_TOOL: String = "smuggled_tool"

## Base price multiplier depending on silo enforcement level (0.0 to 1.0)
static func calculate_black_market_price(base_cost: float, security_pressure: float) -> float:
	# As enforcement pressure increases, black market risk premium escalates
	var risk_multiplier: float = 1.0 + (security_pressure * 2.5)
	return base_cost * risk_multiplier

static func _ensure_room_inventory(ws: WorldState, room: Room) -> Inventory:
	if not room:
		return null
	if room.inventory_id > 0:
		return ws.entity_registry.get_entity(room.inventory_id) as Inventory
	var inv: Inventory = Inventory.new(0, room.id, 100000.0)
	inv.id = ws.entity_registry.register_entity("inventory", inv)
	room.inventory_id = inv.id
	return inv

## Executes a direct physical black market transaction between two citizens,
## transferring goods between their respective room inventories.
static func execute_trade(
	ws: WorldState,
	buyer_id: int,
	seller_id: int,
	item_res_id: String,
	item_amount: float,
	payment_res_id: String,
	payment_amount: float,
	deal_location_room_id: int = 0
) -> Dictionary:
	var registry: EntityRegistry = ws.entity_registry
	var buyer: Person = registry.get_entity(buyer_id) as Person
	var seller: Person = registry.get_entity(seller_id) as Person
	
	if not buyer or not seller or item_amount <= 0.0 or payment_amount <= 0.0:
		return {"success": false, "reason": "invalid_participants_or_quantities"}
	
	var buyer_room: Room = registry.get_entity(buyer.home_room_id) as Room
	var seller_room: Room = registry.get_entity(seller.home_room_id) as Room
	if not buyer_room or not seller_room:
		return {"success": false, "reason": "missing_residence_rooms"}
		
	var buyer_inv: Inventory = _ensure_room_inventory(ws, buyer_room)
	var seller_inv: Inventory = _ensure_room_inventory(ws, seller_room)
	if not buyer_inv or not seller_inv:
		return {"success": false, "reason": "missing_inventories"}
		
	# Check availability: seller must possess the item, buyer must possess the payment
	if seller_inv.get_quantity(item_res_id) < (item_amount - 0.0001):
		return {"success": false, "reason": "seller_lacks_goods"}
	if buyer_inv.get_quantity(payment_res_id) < (payment_amount - 0.0001):
		return {"success": false, "reason": "buyer_lacks_payment"}
		
	# Physical transfer (preserves total system mass)
	var removed_goods: float = seller_inv.remove_resource(item_res_id, item_amount)
	var added_goods: float = buyer_inv.add_resource(item_res_id, removed_goods)
	
	var removed_pay: float = buyer_inv.remove_resource(payment_res_id, payment_amount)
	var added_pay: float = seller_inv.add_resource(payment_res_id, removed_pay)
	
	var current_tick: int = ws.sim_clock.get_tick()
	var deal_record: Dictionary = {
		"tick": current_tick,
		"buyer_id": buyer_id,
		"seller_id": seller_id,
		"item_res_id": item_res_id,
		"item_amount": added_goods,
		"payment_res_id": payment_res_id,
		"payment_amount": added_pay,
		"location_room_id": deal_location_room_id if deal_location_room_id > 0 else seller_room.id
	}
	
	var ledger: Array = ws.custom_data.get("black_market_transactions", [])
	ledger.append(deal_record)
	ws.custom_data["black_market_transactions"] = ledger
	
	return {
		"success": true,
		"record": deal_record
	}
