# GLOSSARY.md — Project Terminology

This document defines canonical terms used across the SILO codebase and design documentation.

---

## Simulation Concepts

- **Simulation Truth**: The core design principle that all gameplay outcomes, resource shortages, health crises, and social tensions must emerge organically from simulated physical, economic, or behavioral state, rather than ad-hoc scripted events.
- **Core Tick**: The discrete time unit of the simulation engine. Exactly 10 simulated minutes.
- **SimClock**: The service managing simulation ticks, converting ticks to 24-hour clock time, day of year, and simulation year.
- **SeededRandom**: The stateful pseudo-random number generator service owned by `WorldState`. The sole authoritative source of randomness in the simulation.
- **EntityRegistry**: Central registry assigning monotonic integer IDs to all simulated entities (people, households, rooms, machines, inventories).
- **WorldState**: The root container holding the state of the simulated universe (clock, RNG, entity registry, event queue, global systems data).
- **EventQueue**: A priority queue storing events to be dispatched at specific future simulation ticks.
- **State Checksum**: A deterministic 64-bit integer hash representing the exact state of the universe at a given tick, used to verify deterministic replay.

---

## Domain Concepts

- **Habitat / Silo**: The subterranean closed-loop facility housing the human population.
- **Sector / Level**: Spatial subdivisions of the habitat representing physical tiers and functional zones (e.g. Upper Residential, Middle Industry, Deep Mines).
- **Person**: A persistent citizen entity with identity, genealogy, qualifications, needs, and schedule.
- **Household**: A family or cohabitating group sharing living quarters, ration allocations, and generational wealth.
- **Bed Assignment**: The physical bed unit allocated to an individual resident. Enforces the invariant that no two residents can occupy the same bed at the same time.
- **Production Chain**: A sequence of physical transformations where raw inputs (e.g. iron ore) are converted via labor, energy, and machinery into intermediate goods (stock) and finished components (bearings).
- **Conservation of Mass**: The invariant that matter cannot be created or destroyed in industrial systems without an explicitly modeled source or waste sink.
- **Machine Component**: A replaceable sub-assembly of a machine (motor, bearing, seal, impeller) with distinct wear curves and failure modes.
- **Utility Grid**: Network infrastructure delivering electricity, fresh water, greywater disposal, air ventilation, and data networking.
- **SCADA / PLC**: Industrial automation controllers and telemetry systems monitored and configured by the player in their IT leadership role.
- **Policy**: A long-term structural rule governing autonomous system behaviors (e.g. ration rules, apprenticeship admission criteria).
- **Executive Order**: A temporary operational directive with opportunity costs (e.g. prioritizing water system repairs over ventilation).
- **Special Intervention**: A direct, acute executive action (e.g. door override, security detention, telemetry blackout).
