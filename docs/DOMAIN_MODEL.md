# DOMAIN_MODEL.md — Domain Model & Entity Schemas

This document defines the core domain entities, data schemas, and domain invariants for SILO.

---

## 1. Core Domain Entities

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│     Person      │◄─────►│    Household    │◄─────►│      Room       │
│                 │       │                 │       │ (Home/Work/Etc) │
└────────┬────────┘       └─────────────────┘       └────────┬────────┘
         │                                                   │
         ▼                                                   ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   Occupation    │       │     Machine     │◄─────►│    Inventory    │
│  & Department   │       │   & Component   │       │  & Material     │
└─────────────────┘       └─────────────────┘       └─────────────────┘
```

---

## 2. Entity Schemas

### A. Person (`Person`)
- `id: int` — Unique monotonic entity ID.
- `first_name: String`, `last_name: String` — Generated identity name.
- `sex: int` — Biological sex (0 = Female, 1 = Male).
- `birth_tick: int` — Simulation tick of birth.
- `age_years: int` — Computed age in simulated years (`(current_tick - birth_tick) / TICKS_PER_YEAR`).
- `parent_ids: Array[int]` — Up to 2 parent IDs (empty for founding generation).
- `children_ids: Array[int]` — List of biological/adopted child IDs.
- `partner_id: int` — Spouse / committed partner ID (or 0).
- `household_id: int` — Associated household entity ID.
- `home_room_id: int` — Assigned residential room ID.
- `bed_id: int` — Assigned bed index / entity ID.
- `life_stage: int` — `INFANT`, `CHILD`, `STUDENT`, `ADULT`, `ELDER`.
- `occupation_id: String` — Current job definition key (e.g., `machinist`, `furnace_operator`, `it_technician`, `student`, `none`).
- `department_id: String` — Department key (e.g., `engineering_water`, `industry_foundry`, `executive_it`).
- `shift_id: int` — Work shift (`DAY`, `NIGHT`, `ROTATING`, `OFF`).
- `security_clearance: int` — Level 0 (Resident) to Level 5 (Executive Overseer).
- `health_status: Dictionary` — Vital metrics (physical integrity, illness, fatigue).
- `needs: Dictionary` — Sleep, Nutrition, Hydration, Hygiene, Social, Recreation.
- `current_location_id: int` — Current room/zone entity ID.
- `current_activity: int` — `SLEEPING`, `TRAVELING`, `WORKING`, `STUDYING`, `EATING`, `HYGIENE`, `RECREATING`, `IDLE`.
- `schedule: Array[Dictionary]` — 24-hour routine definition.

### B. Household (`Household`)
- `id: int` — Unique entity ID.
- `name: String` — Household family designation.
- `home_room_id: int` — Assigned apartment/quarters room ID.
- `head_id: int` — Person ID of primary household representative.
- `member_ids: Array[int]` — List of person IDs residing in the household.
- `ration_tier: int` — Household ration priority tier.

### C. Room / Zone (`Room`)
- `id: int` — Unique entity ID.
- `sector_id: int`, `level: int` — Physical location coordinates in the silo.
- `room_type: int` — `RESIDENTIAL_APARTMENT`, `DORMITORY`, `CANTEEN`, `KITCHEN`, `HYGIENE_FACILITY`, `MACHINE_SHOP`, `FOUNDRY`, `DEEP_MINE`, `WATER_PUMP_STATION`, `SERVER_ROOM`, `CLINIC`, `SCHOOL`.
- `capacity_people: int` — Maximum simultaneous occupancy.
- `bed_count: int` — Number of installed beds (for residential rooms).
- `occupied_beds: Array[int]` — Map of bed index -> Person ID.
- `inventory_id: int` — Container inventory ID for localized storage.
- `machine_ids: Array[int]` — List of machines physically installed in the room.

### D. Inventory & Material (`Inventory`, `MaterialBatch`)
- `id: int` — Unique inventory container ID.
- `owner_entity_id: int` — ID of owning room, machine, or person.
- `max_volume_m3: float`, `max_mass_kg: float` — Physical storage limits.
- `stocks: Dictionary` — Map of `resource_id: String` -> `quantity: float` (e.g. `iron_ore: 1250.0`, `machined_bearings: 14.0`).

### E. Machine & Components (`Machine`, `MachineComponent`)
- `id: int` — Unique machine entity ID.
- `machine_type: String` — Definition key (e.g. `water_pump_heavy_centrifugal`, `lathe_industrial`, `furnace_induction_electric`).
- `room_id: int` — Installed room entity ID.
- `operating_state: int` — `OFF`, `STANDBY`, `RUNNING`, `FAULT`, `DEGRADED`, `BROKEN`.
- `operating_hours: float` — Total run time.
- `components: Array[Dictionary]` — Sub-components:
  - `component_type: String` (e.g. `bearing_roller_50mm`, `electric_motor_15kw`, `shaft_seal_viton`)
  - `wear_percent: float` (0.0 = New, 100.0 = Total Failure)
  - `criticality: float` (Impact of failure on machine operation)
- `maintenance_interval_ticks: int` — Ticks between required servicing.
- `power_draw_kw: float`, `water_draw_lpm: float` — Resource consumption rates.

---

## 3. Domain Invariants

1. **Identity Uniqueness**: Every entity in the registry has a strictly unique monotonic integer ID.
2. **Genealogical Consistency**:
   - `child.parent_ids` references valid living or deceased person IDs.
   - For all $p \in \text{child.parent\_ids}$, $\text{child.id} \in p\text{.children\_ids}$.
   - A person cannot be their own parent or child.
3. **Bed Occupancy Consistency**:
   - Every resident assigned to a bed references a valid `Room` with `bed_count > 0`.
   - No bed index is allocated to more than 1 resident simultaneously.
4. **Material Conservation**:
   - Resources cannot be created from nothing or vanish without trace.
   - $\Delta \text{Inventory}_{\text{Input}} + \Delta \text{Inventory}_{\text{Output}} + \text{Waste} = 0$.
5. **No Teleportation**:
   - Transitions between distant rooms must pass through transition states with realistic travel ticks.
6. **No Magic Repairs**:
   - Machine component wear cannot decrease without a maintenance task containing worker labor, time, required tool, and matching replacement component.


## Operations case workflow (V0.1)

An operations case is a simulation-owned dictionary in `OperationsSystem.cases`, not a replacement `Incident` or `SecurityCase`. It contains a stable `OP-xxxx` episode ID, namespaced source key (`pump:<entity_id>` or `information:<info_id>`), source ID, affected room ID, detection tick, severity, status, pending action, bounded decision/consequence history, real incident IDs where applicable and the latest observed outcome.

States are NEW, ACTIVE, MONITORING, ESCALATING, STABILISED, RESOLVED and FAILED. Physical recovery requires wear below the recovery bound, nominal running output and three confirmation ticks. Information resolution requires actual recipient delivery. Missing/unavailable source state fails honestly. Terminal cases cannot be reopened by a click; a new physical episode receives a new ID.

At most one unresolved case exists per source signature. At most 16 case commands may be queued, with one pending command per case. Case selection is not an acknowledgement write. Known/suspected/unknown fields are read projections; hidden information truth and private beliefs are not exposed as IT knowledge.
