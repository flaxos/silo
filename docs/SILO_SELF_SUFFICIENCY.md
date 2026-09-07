# Silo Self-Sufficiency Audit

This audit describes the backend and physical integration that exists in source.
The status applies to the named self-sufficiency domain, not merely to the
presence of a room label, occupation, policy, numeric field or visual icon.

Status meanings:

- `IMPLEMENTED + WIRED`: a backend process has changing authoritative state and
  that state is physically located and exposed to the Godot read model.
- `IMPLEMENTED NOT PHYSICAL`: backend state or a process exists, but its physical
  operation is not represented.
- `PHYSICAL HOOK ONLY`: configured rooms and/or staff locations exist, but the
  named service process is absent.
- `NOT IMPLEMENTED`: no meaningful backend process or dedicated physical hook
  exists.

| Domain | Status | Source-backed scope and gap |
| --- | --- | --- |
| housing | IMPLEMENTED + WIRED | Persistent households own residential quarters; every generated resident is assigned a room and indexed bed. Home and current occupancy are projected physically. |
| food | PHYSICAL HOOK ONLY | Canteen/kitchen/food-processing spaces and eating schedules exist. There are no food resources, meal production, nutrition balance or ration consumption. |
| agriculture | PHYSICAL HOOK ONLY | Bio-farm spaces are present for rendering. There is no crop, farm labour, input or food-output simulation. |
| water | IMPLEMENTED + WIRED | Pump machinery feeds an authoritative reservoir; living residents consume water and hydration/incident state responds. The pump has a physical room. This is a balance model, not pipe hydrodynamics. |
| wastewater | PHYSICAL HOOK ONLY | A dedicated wastewater-treatment room marks the future physical integration point. There is no wastewater volume, collection, treatment process or output state. |
| air/ventilation | PHYSICAL HOOK ONLY | Air-handler space and ventilation occupation vocabulary may exist, but there is no air quality, airflow or ventilation service system. |
| power | PHYSICAL HOOK ONLY | Power-plant space and machine power-draw fields exist, but there is no generation, load balance, fuel, distribution or outage system. |
| waste/recycling | PHYSICAL HOOK ONLY | Production creates conserved slag/tailings and metal swarf in room inventories, and waste-processing space exists. There is no collection, processing, recycling or disposal system. |
| medical | PHYSICAL HOOK ONLY | Clinics, doctors/nurses, health fields and work schedules exist. There is no diagnosis, patient assignment, treatment, medicine or clinic-capacity process. |
| education | IMPLEMENTED + WIRED | School-age residents receive real school assignments, teachers have school workplaces, and daily schedules enter study. The backend demographics system can advance education while studying, and schools/attendance are physically located. The physical-viewer bootstrap must register that system before claiming live score progression. |
| sanitation | PHYSICAL HOOK ONLY | Hygiene rooms, sanitation workers and hygiene activity exist. There is no cleaning load, contamination, consumable or sanitation-service process. |
| logistics | IMPLEMENTED NOT PHYSICAL | The production system deterministically transfers material between room-owned inventories. Transfers are instantaneous state operations with no carrier, queue, route, travel time or handling labour. |
| industry | IMPLEMENTED + WIRED | Foundry and machine-shop production uses assigned labour and physical room inventories; machinery maintenance consumes real parts. Facilities and current state are projected. |
| mining | IMPLEMENTED + WIRED | Assigned miners extract a finite geological seam into a mine-room inventory and process ore for the downstream chain. The mine is physically located. |
| storage | IMPLEMENTED + WIRED | Inventories have stable IDs, capacity, conserved quantities and authoritative owning room IDs, and are inspectable at those rooms. Dedicated storage-bay operations are only a hook. |
| IT/comms | PHYSICAL HOOK ONLY | IT technicians and server-room workplaces exist. There is no server health, data service, communications, network topology or outage process. |
| security | IMPLEMENTED NOT PHYSICAL | Institutional/security policy and resident perception state exist. Security-post operation, patrol, staffing assignment and a spatial security service are absent. |

## Counts

| Status | Domains |
| --- | ---: |
| IMPLEMENTED + WIRED | 6 |
| IMPLEMENTED NOT PHYSICAL | 2 |
| PHYSICAL HOOK ONLY | 9 |
| NOT IMPLEMENTED | 0 |
| **Total** | **17** |

The six wired domains are housing, water, education, industry, mining and
storage. The counts describe coverage, not a claim that the silo is actually
self-sufficient. Every requested domain now has at least a spatial or backend
representation, but food production, agriculture, wastewater, air, power, waste
processing, medical treatment, sanitation operations and IT/comms service remain
outside the implemented backend.
