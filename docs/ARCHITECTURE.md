# ARCHITECTURE.md — Technical Architecture

## 1. Architectural Overview

SILO uses a unidirectional, layered architecture designed for strict determinism, high-performance headless execution, and complete decoupling of simulation truth from rendering.

```
┌─────────────────────────────────────────────────────────────┐
│                       SIMULATION CORE                       │
│  SimClock │ SeededRandom │ EntityRegistry │ EventQueue     │
│  Scheduler │ WorldState │ Checksum │ BaseSystem            │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                       DOMAIN SYSTEMS                        │
│  Infrastructure │ Economy │ Population │ Institutions       │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    READ MODELS / QUERIES                    │
│  (Read-only snapshots, spatial queries, entity inspectors)  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION ADAPTER                     │
│  (Interpolation, UI data binding, visual entity mapping)    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     GODOT SCENES & UI                       │
│  (Isometric viewport, terminal interfaces, debug panels)    │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Decoupling Rules

1. **Entities Are Not Scene Nodes**:
   - Simulated citizens, machines, and items are lightweight data structures (`RefCounted` or structured Dictionaries) managed inside `WorldState`.
   - Never create 1,200 Godot `Node2D`/`Node3D` instances with active `_process()` or `_physics_process()` calls.
2. **Headless Execution**:
   - The entire simulation engine can run without Godot windowing, graphics, or audio drivers (e.g. `godot --headless`).
3. **Unidirectional Dependency**:
   - Core has zero knowledge of Domain Systems.
   - Domain Systems have zero knowledge of Presentation/UI.
   - Presentation reads from Read Models and sends player commands through the Command/Order interface.

---

## 3. Tick Execution Pipeline

Every discrete simulation tick (10 simulated minutes) executes in strict, deterministic sequence:

```
[ Tick Start ]
      │
      ▼
┌─────────────────────────────────────────────────────────┐
│ 1. PRE-TICK PHASE                                       │
│    - Advance SimClock by 1 tick (10 minutes)            │
│    - Drain and validate incoming player commands/orders │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ 2. EVENT DISPATCH PHASE                                 │
│    - EventQueue dispatches all events scheduled for now │
│    - Timers, scheduled arrivals, wake-ups trigger       │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ 3. DOMAIN SYSTEMS PIPELINE (Strict Order)               │
│    A. UtilityGridSystem (Power, Water, Air flow)        │
│    B. MachinerySystem (Degradation, operating hours)    │
│    C. ProductionSystem (Material transformations)       │
│    D. PopulationSystem (Needs, schedules, activities)   │
│    E. MaintenanceSystem (Repair task execution)         │
│    F. InstitutionPolicySystem (Policy evaluation)       │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ 4. POST-TICK & VALIDATION PHASE                         │
│    - Check invariant assertions (in debug/test modes)   │
│    - Compute state checksum for determinism tracking    │
│    - Publish read-model delta notifications             │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
[ Tick Complete ]
```

---

## 4. State Containers & Registry

### `WorldState`
The central container holding the authoritative state of the universe:
- `sim_clock: SimClock` — Current tick and calendar time.
- `rng: SeededRandom` — Master PRNG stream.
- `entities: EntityRegistry` — Central storage for all simulation entities indexed by integer ID.
- `event_queue: EventQueue` — Priority queue of future events.
- `custom_data: Dictionary` — System-specific global variables and balance parameters.

### `EntityRegistry`
- Provides monotonic integer IDs (`1, 2, 3, ...`).
- Fast $O(1)$ lookup by ID.
- Type indexing (`get_by_type("person")`, `get_by_type("machine")`).
- Safe deletion and cleanup.

## Integration 12-PV: physical projection

`WorldState / Room / Person → SiloSpatialModel + PhysicalReader → existing observer_server → existing HTML observer / Canvas cutaway`.

The simulation already owns levels, sectors, rooms, beds, home and workplace references, and abstract timed travel. `SiloSpatialModel` adds a deterministic geometric interpretation of existing assignments; it neither advances RNG nor registers entities. `PhysicalReader` composes read-only map snapshots and selected entity details. Browser camera position, selection, visibility, and interpolation are presentation state only. No new routing, job, production, or utility simulation is introduced.

Initial geometry/identities are separated from live updates. A server reset revision invalidates browser caches. Int64 checksums on the physical API are strings, preserving exact values across JSON and JavaScript. System dependency links describe existing production and utility relationships; circulation geometry does not establish lift/pathfinding simulation.
