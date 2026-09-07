# OBSERVABILITY_ARCHITECTURE.md — Project SILO Simulation Observability

This document defines the complete architectural design, REST API contracts, and mathematical guarantees of the Project SILO HTML Observability Dashboard (Sprint 11).

---

## 1. Architectural Overview

The observability subsystem connects the authoritative Godot simulation kernel to a high-density, real-time developer dashboard while upholding strict physicalist simulation principles:

```
┌─────────────────────────────────────────────────────────────┐
│                 GODOT SIMULATION ENGINE                     │
│  - WorldState (SeededRandom, SimClock, EntityRegistry)      │
│  - Physical Domain Systems (Daily Life, Economy, Pumps)     │
│  - Invariant Verification Engine (Pop, Mass, Machinery)     │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Pure Read Projections)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│           PRESENTATION ADAPTER: SimulationReader            │
│  - Extracts immutable dictionaries                          │
│  - Zero RNG calls, zero state mutations                     │
│  - 8-Step Causal Lineage Resolution                         │
└──────────────────────────────┬──────────────────────────────┘
                               │ (In-Process Calls)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│          OBSERVER SERVER: tools/observer_server.gd          │
│  - Non-blocking Godot TCPServer on 127.0.0.1:8080           │
│  - REST JSON Endpoints (/api/*)                             │
│  - Static Asset Server (res://src/viewer/*)                 │
└──────────────────────────────┬──────────────────────────────┘
                               │ (HTTP / JSON / CORS)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│       HTML / CSS / JS DASHBOARD: src/viewer/                │
│  - 16 High-Density Observability Views                      │
│  - Real-Time Cross-Linking & Entity Inspection              │
│  - Stepping & Policy Controls via CommandAdapter            │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Core Invariants & Mathematical Guarantees

1. **Zero State Mutation on Read (Observer Invisibility)**:
   - Querying any API endpoint or rendering the complete state tree produces zero state mutations.
   - **Checksum Equivalence**:
     $$\text{Checksum}(\text{Sim}_A \text{ without queries}) \equiv \text{Checksum}(\text{Sim}_B \text{ under 1,000+ queries/tick})$$
2. **Zero Gameplay Redesign**:
   - The dashboard presents authoritative physical truth without altering game mechanics, adding arbitrary modifiers, or inventing fictional narrative text.
3. **Pure Presentation Decoupling**:
   - Simulation logic is never duplicated in JavaScript. The frontend is strictly a viewer of authoritative JSON projections.
4. **Strict Material Conservation**:
   - All mass is accounted for across the entire lifecycle:
     $$\text{Seam Ore (kg)} + \sum \text{Inventory Stocks (kg)} + \text{Installed Maintenance Spares (kg)} = 100,000.0\text{ kg}$$
     $$\Delta_{\text{error}} < 10^{-6}\text{ kg}$$

---

## 3. REST API Endpoint Specifications

All endpoints return JSON with standard CORS headers (`Access-Control-Allow-Origin: *`).

| Method | Endpoint | Query Parameters | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/overview` | — | Full telemetry snapshot: Clock, Population, Economy, Machinery, Utilities, Institutions, Incidents, and Engine status. |
| `GET` | `/api/people` | `page`, `limit`, `search`, `stage`, `job`, `status` | Paginated, searchable, filterable list of all citizen entities. |
| `GET` | `/api/person` | `id` | Comprehensive profile for a single resident (bio, routine, family tree, clearances, assignments). |
| `GET` | `/api/households` | — | Complete list of all residential households and member compositions. |
| `GET` | `/api/household` | `id` | Detailed household breakdown with head of house and home room link. |
| `GET` | `/api/locations` | — | Nested spatial hierarchy (Sectors $\rightarrow$ Levels $\rightarrow$ Rooms) with bed capacity and live occupancy. |
| `GET` | `/api/room` | `id` | Single room breakdown including bed allocations, inventory stocks, and current occupants. |
| `GET` | `/api/labour` | — | Departmental staffing distributions, occupation rosters, and student enrollment lists. |
| `GET` | `/api/economy` | — | Mass conservation balance, geological reserves, inventory stocks, and slag/swarf waste. |
| `GET` | `/api/machinery` | — | Machinery registry, operational states (NOMINAL, DEGRADED, FAULT, BROKEN), component wear %, and active repairs. |
| `GET` | `/api/causal_chain` | `machine_id` | 8-step physical traceability graph from Geological Seam down to Citizen Hydration. |
| `GET` | `/api/utilities` | — | Central water reservoir volume, fill %, lifetime pumped/consumed liters, and net flow rate. |
| `GET` | `/api/institutions` | — | Social tension index, active regulatory policies, and active executive directives. |
| `GET` | `/api/incidents` | — | Active and resolved incident logs with telemetry data, severity levels, and root causes. |
| `GET` | `/api/timeline` | — | Chronological event stream recording crises, policy shifts, and systemic milestones. |
| `GET` | `/api/dependencies` | — | Closed physical loop topology describing labor, material flow, maintenance, and hydration. |
| `GET` | `/api/wiring` | — | Verification matrix of all 22 simulation systems with source paths and execution order. |
| `GET` | `/api/invariants` | — | Live evaluation of state invariants (acyclic trees, single bed occupancy, mass balance $\Delta < 10^{-6}$). |
| `GET` | `/api/performance` | — | Engine execution benchmark metrics ($\mu\text{s/tick}$, ticks/sec) and entity registry counts. |
| `GET` | `/api/raw` | `type`, `id` | Raw JSON serialization of any entity or full `WorldState`. |
| `POST` | `/api/step` | `ticks` (Body or Param) | Steps the simulation by $N$ ticks and returns execution time benchmarks. |
| `POST` | `/api/pause` | — | Pauses auto-stepping in the engine loop. |
| `POST` | `/api/resume` | — | Resumes auto-stepping in the engine loop. |
| `POST` | `/api/speed` | `ticks_per_step`, `interval_sec` | Configures auto-stepping velocity. |
| `POST` | `/api/policy/enact` | `policy_id` | Enacts a regulatory policy via `CommandAdapter`. |
| `POST` | `/api/policy/revoke` | `category` | Revokes an active policy category. |
| `POST` | `/api/order/issue` | `order_id`, `department`, `target`, `duration_ticks` | Dispatches an executive directive. |
| `POST` | `/api/order/cancel` | `order_id` | Cancels an active executive directive. |
| `POST` | `/api/reset` | `population`, `seed` | Re-initializes the simulation with a clean state and seed. |
| `POST` | `/api/validate` | — | Triggers full multi-system invariant validation suite. |

---

## 4. 8-Step Physical Traceability Graph

The dashboard explicitly renders the continuous causal chain linking mineral resources to human survival:

```
[1. Geological Seam Ore (100,000 kg)]
          │
          ▼ (Deep Mine Extraction)
[2. Iron Ore Mineral ➔ Beneficiation Crushing ➔ Processed Ore]
          │
          ▼ (Induction Smelting Foundry)
[3. Refined Metal Stock (Ingots) + Slag Tailings Waste]
          │
          ▼ (Machine Shop Lathes)
[4. Machined Roller Bearings + Recyclable Metal Swarf]
          │
          ▼ (Maintenance Inventory Stocking)
[5. Spare Parts Inventory Allocation]
          │
          ▼ (Scheduled & Emergency Maintenance Servicing)
[6. Installed Water Pump Component Wear %]
          │
          ▼ (Physical Degradation Curves)
[7. Water Pump Throughput (0 - 500 L/min) ➔ Reservoir Storage]
          │
          ▼ (Habitation Hydration Distribution)
[8. Resident Hydration % & Dehydration Mortality Prevention]
```
