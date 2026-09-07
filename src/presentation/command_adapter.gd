# src/presentation/command_adapter.gd
class_name CommandAdapter
extends RefCounted

## Decoupled player command dispatcher that routes player decisions through official simulation systems.
## Presentation and UI must NEVER mutate simulation data directly; all player actions pass through CommandAdapter.

static func enact_policy(ws: WorldState, policy_id: String) -> bool:
	if not ws:
		return false
	var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
	if not inst_sys:
		return false
	return inst_sys.enact_policy(policy_id, ws)

static func revoke_policy(ws: WorldState, category: String) -> bool:
	if not ws:
		return false
	var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
	if not inst_sys:
		return false
	return inst_sys.revoke_policy(category, ws)

static func dispatch_order(ws: WorldState, order: ExecutiveOrder) -> bool:
	if not ws or not order:
		return false
	var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
	if not inst_sys:
		return false
	return inst_sys.issue_order(order, ws)

static func cancel_order(ws: WorldState, order_id: String) -> bool:
	if not ws:
		return false
	var inst_sys: InstitutionSystem = ws.custom_data.get("institution_system", null) as InstitutionSystem
	if not inst_sys:
		return false
	return inst_sys.cancel_order(order_id, ws)
