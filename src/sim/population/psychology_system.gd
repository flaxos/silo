# src/sim/population/psychology_system.gd
class_name PsychologySystem
extends BaseSystem

## Authoritative simulation of citizen psychology, stress, fatigue, morale,
## burnout, and behavioral consequences (absenteeism, fatigue-induced machine wear).

const Machine = preload("res://src/sim/machinery/machine.gd")
const MachineComponent = preload("res://src/sim/machinery/machine_component.gd")

func _init() -> void:
	super("psychology_system", 43)

func setup(_ws: Variant) -> void:
	pass

func tick(ws: Variant) -> void:
	var world: WorldState = ws as WorldState
	if not world:
		return
		
	var registry: EntityRegistry = world.entity_registry
	var pids: Array[int] = registry.get_entities_by_type("person")
	
	for pid in pids:
		var p: Person = registry.get_entity(pid) as Person
		if not p or not p.is_alive:
			continue
			
		_update_person_psychology(world, p)

func _update_person_psychology(ws: WorldState, p: Person) -> void:
	# 1. Fatigue dynamics
	if p.current_activity == Person.ACTIVITY_SLEEPING:
		p.fatigue = maxf(0.0, p.fatigue - 0.75) # Restorative sleep
	elif p.current_activity == Person.ACTIVITY_WORKING:
		p.fatigue = minf(100.0, p.fatigue + 0.50) # Labor exertion
		
		# Fatigue consequence: accelerated wear on machine components if working exhausted
		if p.fatigue > 70.0 and p.workplace_room_id > 0:
			_apply_fatigue_workplace_wear(ws, p)
			
	elif p.current_activity == Person.ACTIVITY_TRAVELING:
		p.fatigue = minf(100.0, p.fatigue + 0.25)
	elif p.current_activity == Person.ACTIVITY_RECREATING:
		p.fatigue = maxf(0.0, p.fatigue - 0.20)
	else:
		p.fatigue = minf(100.0, p.fatigue + 0.10)
		
	# 2. Stress dynamics
	var stress_delta: float = 0.0
	
	# Severe physical dehydration
	if p.hydration_percent < 50.0:
		stress_delta += (50.0 - p.hydration_percent) * 0.05
		
	# Economic deprivation & resentment
	if p.economic_satisfaction < 0.30:
		stress_delta += 0.20
	if p.class_resentment > 0.60:
		stress_delta += 0.15
		
	# Relieving activities
	if p.current_activity == Person.ACTIVITY_RECREATING:
		stress_delta -= 0.80
	elif p.current_activity == Person.ACTIVITY_SLEEPING:
		stress_delta -= 0.30
		
	p.stress = clampf(p.stress + stress_delta, 0.0, 100.0)
	
	# 3. Morale calculation (emerges from stress, fatigue, and attitudes)
	var target_morale: float = clampf(
		100.0 - (p.stress * 0.45) - (p.fatigue * 0.35) - (p.class_resentment * 25.0) + (p.institutional_trust * 10.0),
		0.0,
		100.0
	)
	p.morale = lerpf(p.morale, target_morale, 0.05)
	
	# 4. Burnout accumulation
	if p.fatigue > 80.0 and p.stress > 75.0:
		p.burnout = minf(100.0, p.burnout + 0.50)
	else:
		p.burnout = maxf(0.0, p.burnout - 0.10)
		
	# 5. Absenteeism emergence
	# If exhausted or in severe acute stress, citizen fails to report to shift
	if p.fatigue >= 85.0 or p.stress >= 90.0 or p.burnout >= 80.0:
		p.absent_from_work = true
	else:
		p.absent_from_work = false

func _apply_fatigue_workplace_wear(ws: WorldState, p: Person) -> void:
	var registry: EntityRegistry = ws.entity_registry
	var machine_ids: Array[int] = registry.get_entities_by_type("machine")
	for mid in machine_ids:
		var m: Machine = registry.get_entity(mid) as Machine
		if m and m.room_id == p.workplace_room_id and m.is_running:
			for comp in m.components.values():
				var c: MachineComponent = comp as MachineComponent
				if c:
					# Additional wear inflicted by exhausted operator mistakes (0.01% per tick)
					c.wear_percent = minf(100.0, c.wear_percent + 0.01)
			m.update_state()
			break

func serialize() -> Dictionary:
	return {
		"system_id": system_id,
		"execution_order": execution_order
	}

func deserialize(d: Dictionary) -> void:
	system_id = str(d.get("system_id", "psychology_system"))
	execution_order = int(d.get("execution_order", 43))
