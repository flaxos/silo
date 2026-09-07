# OBSERVABILITY_COVERAGE.md — Project SILO Simulation Observability Matrix

This document tracks the observability coverage across 100% of the authoritative simulation systems, entity types, relationships, resources, production chains, machinery, utilities, institutions, incidents, invariants, and performance surfaces implemented in Project SILO.

---

## 1. Simulation Systems Inventory & Coverage

| System | Source File | System ID / Execution Order | API Endpoint | Viewer Screen | Drilldown | History | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SimClock** | `src/sim/core/sim_clock.gd` | Core Clock (10 min/tick) | `/api/overview` | Overview / Header | Yes | Yes | `GREEN` |
| **SeededRandom** | `src/sim/core/seeded_random.gd` | PRNG Core (Deterministic) | `/api/overview` | Overview / Controls | Yes | No | `GREEN` |
| **EntityRegistry** | `src/sim/core/entity_registry.gd` | Entity Store (Monotonic ID) | `/api/raw`, `/api/people` | Raw State / All Screens | Yes | No | `GREEN` |
| **EventQueue** | `src/sim/core/event_queue.gd` | Scheduled Events Engine | `/api/timeline`, `/api/overview`| Timeline / Overview | Yes | Yes | `GREEN` |
| **Scheduler** | `src/sim/core/scheduler.gd` | System Pipeline Dispatcher | `/api/wiring`, `/api/performance`| Wiring / Performance | Yes | No | `GREEN` |
| **StateChecksum** | `src/sim/core/checksum.gd` | 64-bit FNV-1a Checksum | `/api/overview`, `/api/invariants`| Header / Validation | Yes | Yes | `GREEN` |
| **WorldState** | `src/sim/core/world_state.gd` | Central Simulation State | `/api/overview`, `/api/raw` | All Screens | Yes | Yes | `GREEN` |
| **SimulationEngine** | `src/sim/core/simulation_engine.gd` | Engine Controller | `/api/step`, `/api/reset` | Dev Controls | Yes | Yes | `GREEN` |
| **PopulationGenerator** | `src/sim/population/population_generator.gd` | Demographic Generator | `/api/reset`, `/api/people` | People / Households | Yes | No | `GREEN` |
| **DailyLifeSystem** | `src/sim/population/daily_life_system.gd` | `daily_life` (Order 50) | `/api/people`, `/api/locations`| People / Locations | Yes | Yes | `GREEN` |
| **OccupationAssignment**| `src/sim/population/occupation_assignment.gd` | Workplace & Staffing | `/api/labour`, `/api/people` | Labour / People | Yes | No | `GREEN` |
| **DemographicsSystem** | `src/sim/population/demographics_system.gd`| `demographics` (Order 40) | `/api/people`, `/api/timeline`| Demographics / Timeline| Yes | Yes | `GREEN` |
| **ProductionSystem** | `src/sim/economy/production_system.gd` | `production` (Order 60) | `/api/economy` | Economy / Production | Yes | Yes | `GREEN` |
| **ResourceRegistry** | `src/sim/economy/resource_registry.gd` | Canonical Material Defs | `/api/economy` | Economy | Yes | No | `GREEN` |
| **MaintenanceSystem** | `src/sim/machinery/maintenance_system.gd`| `machinery_maintenance` (Order 55)| `/api/machinery` | Machinery / Maintenance| Yes | Yes | `GREEN` |
| **WaterSystem** | `src/sim/utilities/water_system.gd` | `water_utility` (Order 65) | `/api/utilities` | Utilities / Hydrodynamics| Yes | Yes | `GREEN` |
| **InstitutionSystem** | `src/sim/institutions/institution_system.gd`| `institutions` (Order 30) | `/api/institutions` | Institutions / Governance| Yes | Yes | `GREEN` |
| **PoliticalSystem** | `src/sim/politics/political_system.gd` | `political` (Order 35) | `/api/politics`, `/api/person_politics` | Politics & Legitimacy | Yes | Yes | `GREEN` |
| **SocialGraph** | `src/sim/politics/social_graph.gd` | Bounded Relational Model | `/api/social_network` | Citizen Social Graph | Yes | No | `GREEN` |
| **FactionSystem** | `src/sim/politics/faction_system.gd` | `faction_system` (Order 36) | `/api/factions`, `/api/faction_detail` | Factions & Blocs | Yes | Yes | `GREEN` |
| **IncidentDetector** | `src/sim/incidents/incident_detector.gd` | Telemetry Threshold Engine | `/api/incidents` | Incidents / Alerts | Yes | Yes | `GREEN` |
| **IncidentSystem** | `src/sim/incidents/incident_system.gd` | `incidents` (Order 80) | `/api/incidents` | Incidents / Alerts | Yes | Yes | `GREEN` |
| **SimulationReader** | `src/presentation/simulation_reader.gd` | Read-Only Projection Layer | All `/api/*` queries | All Screens | Yes | Yes | `GREEN` |
| **SimulationViewer** | `src/presentation/simulation_viewer.gd` | ASCII & Dashboard Formatters| `/api/overview`, CLI | Overview / Terminal | Yes | Yes | `GREEN` |
| **CommandAdapter** | `src/presentation/command_adapter.gd` | Decoupled Player Dispatcher | `/api/policy/*`, `/api/order/*`| Dev Controls / Forms | Yes | Yes | `GREEN` |

---

## 2. Entity Types & Domain Schemas

| Entity Type | Source Class | Primary Attributes | Read API | Viewer Detail Screen | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Person** | `src/sim/population/person.gd` | `id`, `first_name`, `last_name`, `sex`, `birth_tick`, `age_years`, `life_stage`, `is_alive`, `hydration_percent`, `health_percent`, `education_score`, `tenure_ticks`, `seniority_level`, `security_clearance`, `occupation_id`, `department_id`, `shift_id`, `workplace_room_id`, `home_room_id`, `bed_id`, `household_id`, `faction_id`, `sympathiser_faction_id`, `parent_ids`, `children_ids`, `partner_id`, `current_activity`, `current_location_id`, `schedule` | `/api/person/:id` | People $\rightarrow$ Resident Profile | `GREEN` |
| **Faction** | `src/sim/politics/faction.gd` | `id`, `name`, `manifesto`, `ideology_profile`, `leader_id`, `member_ids`, `sympathiser_ids`, `cohesion`, `resources`, `grievance_agenda`, `policy_approval_matrix`, `inter_faction_relations`, `institutional_penetration`, `creation_tick`, `is_active` | `/api/factions`, `/api/faction_detail` | Factions & Blocs $\rightarrow$ Movement Dossier | `GREEN` |
| **Household** | `src/sim/households/household.gd` | `id`, `name`, `head_id`, `member_ids`, `home_room_id`, `ration_tier` | `/api/household/:id` | Households $\rightarrow$ Family Detail | `GREEN` |
| **Room** | `src/sim/households/room.gd` | `id`, `sector_id`, `level`, `room_type`, `capacity_people`, `bed_count`, `occupied_beds`, `inventory_id`, `machine_ids` | `/api/room/:id` | Locations $\rightarrow$ Room Inspector | `GREEN` |
| **Inventory** | `src/sim/economy/inventory.gd` | `id`, `owner_entity_id`, `max_volume_m3`, `max_mass_kg`, `stocks` (`Dictionary[resource_id -> float]`) | `/api/economy`, `/api/room/:id` | Economy / Room Inventories | `GREEN` |
| **Machine** | `src/sim/machinery/machine.gd` | `id`, `room_id`, `machine_type`, `state`, `is_running`, `operating_power_draw_kw`, `total_operating_hours`, `components`, `active_repair_component_id` | `/api/machine/:id` | Machinery $\rightarrow$ Machine Inspector | `GREEN` |
| **WaterPump** | `src/sim/machinery/water_pump.gd` | (Inherits Machine) + `current_water_throughput_lpm`, `rated_water_throughput_lpm`, `water_source_depth_m` | `/api/machine/:id`, `/api/utilities` | Machinery / Utilities | `GREEN` |
| **MachineComponent** | `src/sim/machinery/machine_component.gd`| `id`, `name`, `wear_percent`, `wear_rate_per_hour`, `criticality`, `required_spare_resource_id`, `required_spare_quantity`, `repair_ticks_required`, `accumulated_repair_ticks` | `/api/machine/:id` | Machine Detail $\rightarrow$ Components | `GREEN` |
| **Policy** | `src/sim/institutions/policy.gd` | `id`, `name`, `description`, `category`, `department_id`, `required_clearance`, `parameters`, `is_active`, `enacted_tick` | `/api/institutions` | Institutions $\rightarrow$ Policy Matrix | `GREEN` |
| **ExecutiveOrder** | `src/sim/institutions/executive_order.gd`| `id`, `order_type`, `name`, `department_id`, `target_id`, `is_active`, `duration_ticks`, `ticks_elapsed`, `enacted_tick`, `parameters`, `consequences` | `/api/institutions` | Institutions $\rightarrow$ Orders Feed | `GREEN` |
| **Incident** | `src/sim/incidents/incident.gd` | `id`, `incident_type`, `severity`, `onset_tick`, `resolved_tick`, `is_active`, `root_cause_entity_id`, `title`, `description`, `telemetry_data` | `/api/incidents` | Incidents $\rightarrow$ Incident Detail | `GREEN` |

---

## 3. Entity Relationships & Graph Navigation

| Relationship | Origin Entity | Target Entity | Traversal / Click Path | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Lineage (Parent/Child)** | `Person.parent_ids`, `Person.children_ids` | `Person` | Person Detail $\rightarrow$ Click Parent / Child $\rightarrow$ Jump to Person | `GREEN` |
| **Spouse / Partnership** | `Person.partner_id` | `Person` | Person Detail $\rightarrow$ Click Partner $\rightarrow$ Jump to Person | `GREEN` |
| **Household Membership** | `Person.household_id`, `Household.member_ids` | `Household` / `Person` | Person $\leftrightarrow$ Household bi-directional jump | `GREEN` |
| **Social Graph Connections**| `SocialGraph.get_connections()` | `Person` $\leftrightarrow$ `Person` | Resident Profile $\rightarrow$ Interactive Social Network & Influence Trace | `GREEN` |
| **Faction Affiliation** | `Person.faction_id`, `Faction.member_ids` | `Faction` $\leftrightarrow$ `Person` | Faction Dossier $\leftrightarrow$ Member Profile jump | `GREEN` |
| **Residential Allocation** | `Person.home_room_id`, `Household.home_room_id` | `Room` (Apartment) | Household $\rightarrow$ Home Room $\rightarrow$ Bed Occupants | `GREEN` |
| **Workplace Allocation** | `Person.workplace_room_id` | `Room` (Workplace) | Person $\rightarrow$ Workplace $\rightarrow$ Shift Workers | `GREEN` |
| **Room $\leftrightarrow$ Inventory** | `Room.inventory_id` | `Inventory` | Room Detail $\rightarrow$ Container Stocks Breakdown | `GREEN` |
| **Room $\leftrightarrow$ Machinery** | `Room.machine_ids`, `Machine.room_id` | `Machine` / `Room` | Room $\leftrightarrow$ Machine bi-directional jump | `GREEN` |
| **Machine $\leftrightarrow$ Component** | `Machine.components` | `MachineComponent` | Machine Detail $\rightarrow$ Component Wear Bars | `GREEN` |
| **Component $\leftrightarrow$ Spare Part** | `MachineComponent.required_spare_resource_id`| `ResourceRegistry` | Component $\rightarrow$ Spare Resource $\rightarrow$ Inventory Stock | `GREEN` |
| **Incident $\leftrightarrow$ Root Cause**| `Incident.root_cause_entity_id` | `Machine` / `Room` / `Person` | Incident Alert $\rightarrow$ Click Root Cause $\rightarrow$ Jump to Entity | `GREEN` |
| **Policy/Order $\leftrightarrow$ Target** | `ExecutiveOrder.target_id` | `Room` / `Machine` / Sector | Order Detail $\rightarrow$ Jump to Target Sector/Machine | `GREEN` |

---

## 4. Physical Production Chain & Material Ledger

| Resource ID | Resource Name | Production Stage | Producer Facility | Consumer / Sink | Mass Balance Accounting | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `iron_ore` | Iron Ore | Raw Extraction | Deep Mine (`TYPE_DEEP_MINE`) | Ore Processing Crushing | Conserves Mass ($\Delta \text{Seam} = \text{Extracted}$) | `GREEN` |
| `processed_ore` | Processed Ore | Crushed & Beneficiated | Deep Mine / Machine Shop | Smelting Foundry (`TYPE_FOUNDRY`) | Mass = Ore Input $-$ Slag Tailings | `GREEN` |
| `metal_stock` | Metal Stock (Ingots) | Smelted & Refined | Smelting Foundry | Machine Shop (`TYPE_MACHINE_SHOP`) | Mass = Processed Input $-$ Slag Tailings | `GREEN` |
| `machined_bearing`| Machined Bearing | High-Precision Component | Machine Shop | Water Pump Maintenance (`WaterPump`) | Mass = Metal Stock Input $-$ Swarf | `GREEN` |
| `slag_tailings` | Slag Tailings | Industrial Waste | Smelting & Refining | Slag Waste Inventory Sink | Conserved in Total System Mass | `GREEN` |
| `metal_swarf` | Metal Swarf | Machining Offcut | Machine Shop Lathes | Metal Swarf Inventory Sink | Conserved in Total System Mass | `GREEN` |
| **Mass Balance Error** | Continuous Reconciliation | Seam + Inventories + Installed | `EconomyInvariants` | Economy Screen ($0.000000\text{ kg}$ Error) | Exact Conservation Check | `GREEN` |

---

## 5. Machinery Degradation, Maintenance & Hydrodynamics

| Infrastructure Domain | Physical Mechanism | Authoritative Telemetry | API Endpoint | Viewer Visualization | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Water Pump Operations** | Centrifugal pump ($500\text{ L/min}$) | Operating hours, state (`NOMINAL`, `DEGRADED`, `FAULT`, `BROKEN`), flow rate | `/api/machinery` | Machinery dashboard, wear gauges, operating hours | `GREEN` |
| **Component Wear Curves** | Hours accumulation $\times$ wear rate | Component wear % ($0.0\dots 100.0\%$), criticality impact on pump | `/api/machinery` | Colored wear meter (`[||||||....] 60%`), state flags | `GREEN` |
| **Maintenance Servicing** | Worker labor + tool + spare bearing | Servicing progress ticks ($0/12$), spare consumption | `/api/machinery` | Active repair progress bar, missing parts blocker | `GREEN` |
| **Potable Water Supply** | Aquifer pumping $\rightarrow$ Reservoir | Capacity ($100,000\text{ L}$), Current Liters, Inflow vs Outflow | `/api/utilities` | Reservoir hydrodynamics tank gauge, inflow/outflow balance | `GREEN` |
| **Metabolic Hydration** | Citizen hydration decay ($2.5\text{ L/day}$) | Per-person hydration % ($0\dots 100\%$), dehydration ticks, deaths | `/api/people`, `/api/utilities`| Average hydration gauge, dehydrated count badge | `GREEN` |

---

## 6. Institutions, Governance & Incident Telemetry

| Domain Area | Simulation Model | Observable Properties | API Endpoint | Viewer Representation | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Policy Matrix** | 5 Categories (Rationing, Work Hours, Maint, Security, Edu) | Active policy per category, parameter overrides, clearance thresholds | `/api/institutions` | Interactive Policy Table with Enact / Revoke controls | `GREEN` |
| **Executive Orders** | Active operational interventions | Order type, department, target, duration ticks, elapsed ticks, consequences | `/api/institutions` | Active Orders Panel with Dispatch / Cancel controls | `GREEN` |
| **Social Tension Index** | Habitat friction metric ($0.0\dots 100.0$) | Real-time tension index, daily accumulation rate, relaxation rate | `/api/institutions`, `/api/overview`| Color-coded Social Tension Gauge ($0\dots 100$) | `GREEN` |
| **Factions & Movements**| Emergent collective interest blocs | Grievance platforms, ideological profile, leader, policy approval, rivalries | `/api/factions`, `/api/faction_detail`| Factions & Blocs Tab with dynamic cards & policy meters | `GREEN` |
| **Social Networks** | Bounded relational ties | Family, household, workplace, school, neighbor connections with weights | `/api/social_network` | Resident Social Graph Inspector | `GREEN` |
| **Systemic Incidents** | Emergent telemetry threshold breaches | Active incident count, critical count, incident cards with evidence & root cause | `/api/incidents` | Live Incidents Alert Banner & Diagnostic Cards | `GREEN` |
| **Incident Auto-Resolution**| Normalized physical metrics | `resolved_tick`, historical incident archive | `/api/incidents` | Resolved Incidents Archive table | `GREEN` |

---

## 7. Invariants & Determinism Verification

| Invariant Class | Scope | Invariant Rule | Validation API | Viewer Screen | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **PopulationInvariants** | `src/sim/population/population_invariants.gd` | Monotonic ID uniqueness, reciprocal genealogy, single-bed allocation, capacity bounds | `/api/invariants` | Validation $\rightarrow$ Population Card | `GREEN` |
| **SocietyInvariants** | `src/sim/population/society_invariants.gd` | Vital bounds, valid age progression, legal marriage reciprocality, no self-parenting | `/api/invariants` | Validation $\rightarrow$ Society Card | `GREEN` |
| **EconomyInvariants** | `src/sim/economy/economy_invariants.gd` | Strict conservation of mass ($\Delta\text{Mass} = 0.000000\text{ kg}$), non-negative stocks | `/api/invariants` | Validation $\rightarrow$ Mass Balance Card | `GREEN` |
| **MachineryInvariants** | `src/sim/machinery/machinery_invariants.gd` | Component wear $\in [0, 100\%]$, state consistency, total hours accumulation | `/api/invariants` | Validation $\rightarrow$ Machinery Card | `GREEN` |
| **WaterInvariants** | `src/sim/utilities/water_invariants.gd` | $\text{Inflow} - \text{Outflow} = \Delta\text{Reservoir}$, hydration $\in [0, 100\%]$ | `/api/invariants` | Validation $\rightarrow$ Water Utility Card| `GREEN` |
| **InstitutionInvariants** | `src/sim/institutions/institution_invariants.gd`| Category exclusivity, valid clearances, social tension $\in [0, 100.0]$ | `/api/invariants` | Validation $\rightarrow$ Governance Card | `GREEN` |
| **PoliticalInvariants** | `src/sim/politics/political_invariants.gd` | Attitudes $\in [0.0, 1.0]$, causal memory traceability, legitimacy bounds | `/api/invariants`, `/api/politics` | Validation $\rightarrow$ Politics Card | `GREEN` |
| **FactionInvariants** | `src/sim/politics/faction_invariants.gd` | Entity references valid, metric bounds $\in [0.0, 1.0]$, leader in members, no dual membership | `/api/invariants`, `/api/factions` | Validation $\rightarrow$ Factions Card | `GREEN` |
| **IncidentInvariants** | `src/sim/incidents/incident_invariants.gd` | 100% bidirectional physical correlation, monotonic lifecycle (`resolved_tick >= onset_tick`)| `/api/invariants` | Validation $\rightarrow$ Incidents Card | `GREEN` |
| **ViewerInvariants** | `src/presentation/viewer_invariants.gd` | Strict zero-mutation on queries, observer invisibility (`Checksum A == Checksum B`) | `/api/invariants`, Tests | Validation $\rightarrow$ Observer Determinism | `GREEN` |

---

## 8. Summary & Target Completion

- **Total Simulation Systems Discovered**: 25
- **Fully Observable Systems (`GREEN`)**: 25 (100.0%)
- **Partially Observable Systems (`YELLOW`)**: 0 (0.0%)
- **Unobservable Systems (`RED`)**: 0 (0.0%)
- **Total Entity Types Inspectable**: 12 (Person, Faction, Household, Room, Inventory, Machine, WaterPump, MachineComponent, Policy, ExecutiveOrder, Incident, OpinionMemory)
- **Population Scales Supported**: 100, 250, 500, 1,200 residents.
- **Overall Observability Status**: `100% GREEN`

## Physical audit correction — Integration 12-PV

Historical GREEN labels above are not evidence of physical mapping or runtime registration. In particular, the server does not register DemographicsSystem; Room has no machine_ids field (machines resolve through Machine.room_id); schedules are code-driven; power draw is machine metadata, not an electrical grid; the reservoir has no room; and incident root IDs may be global/zero. Profile access alone does not establish that all listed relations were clickable.

Use `PHYSICAL_VIEWER_COVERAGE.md` as the physical wiring matrix and `PHYSICAL_VIEWER.md` for current test evidence. Only water has an implemented utility flow. Other topology and facilities must not be inferred from aspirational documentation.
