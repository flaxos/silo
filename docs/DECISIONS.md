# DECISIONS.md — Architecture Decision Records (ADRs)

This document records all significant technical and architectural decisions made in SILO.

---

## ADR-001: Godot 4.4+ & GDScript with Node-Decoupled Simulation Core

### Status
Accepted

### Context
Simulating 1,200+ persistent residents with machines, utilities, and industry in Godot could easily result in severe performance degradation if modeled as SceneTree Nodes utilizing engine lifecycle methods (`_process()`, `_physics_process()`).

### Decision
The simulation core (`src/sim/`) is implemented in pure GDScript classes extending `RefCounted` or `Object`. Simulated entities are lightweight data objects stored in `WorldState` collections. Godot SceneTree nodes and UI components are strictly presentation adapters that read projections and never hold authoritative state.

### Consequences
- Simulation runs headlessly at thousands of ticks per second for CI and testing.
- Clean separation between simulation truth and visual presentation.
- Eliminates overhead from 1,200 active Node instances.

---

## ADR-002: Discrete 10-Minute Simulation Ticks

### Status
Accepted

### Context
Pacing target is ~45 real-world minutes per 1 simulated year at 1× speed. A tick rate that is too fine (e.g. 1 second per tick) wastes CPU cycles on mundane idle time; a tick rate that is too coarse (e.g. 1 day per tick) makes real-time travel and shift work impossible to simulate.

### Decision
Standardize on **10 simulated minutes per core tick** (6 ticks/hour, 144 ticks/day, 52,560 ticks/year). At 1× speed, this corresponds to ~19.47 ticks/second (~51.3 ms per tick).

### Consequences
- 10 minutes provides clean granularity for travel between habitat sectors, shift changes, machine operating hour accumulation, and meals.
- High-frequency subsystems (e.g., UI animations, sound, camera transitions) interpolate smoothly between ticks.

---

## ADR-003: Seeded Deterministic PRNG Service (`SeededRandom`)

### Status
Accepted

### Context
Simulation reproducibility requires that all probabilistic behavior (e.g. birth sex, component wear jitter, random failures, schedule variation) produces identical results given the same seed.

### Decision
Wrap Godot's `RandomNumberGenerator` inside a `SeededRandom` class attached to `WorldState`. Domain code is prohibited from calling global random functions. `SeededRandom` provides explicit state extraction and restoration.

### Consequences
- Bugs and crashes can be reproduced 100% reliably by replaying the initial seed and player input stream.
- Test suites can assert exact deterministic checksum equivalence.

---

## ADR-004: In-Memory Monotonic Integer Entity Registry

### Status
Accepted

### Context
Cross-referencing entities (e.g., child -> parents, machine -> room, person -> bed) requires unambiguous, persistent, fast references that serialize easily.

### Decision
Use sequential monotonic 64-bit integer IDs (`1, 2, 3, ...`) managed by `EntityRegistry`. Entity references across domain boundaries use integer IDs rather than direct object pointers to avoid cyclical reference memory leaks and simplify serialization.

### Consequences
- Fast $O(1)$ lookups in dictionaries.
- Zero cyclic memory leaks when freeing entities.
- Direct JSON serialization compatibility.

---

## ADR-005: Headless Godot Test Runner

### Status
Accepted

### Context
Automated verification must run quickly in terminal environments, headless CI, and during agent handoffs without requiring GUI displays, X11/Wayland servers, or external test frameworks.

### Decision
Implement a lightweight test framework (`tests/framework/test_asserts.gd`) and headless runner script (`tools/test_runner.gd`) runnable via `godot --headless -s tools/test_runner.gd`.

### Consequences
- Fast test execution in sub-second timeframes.
- Exits with standard POSIX return codes (0 for pass, 1 for fail).
- Zero third-party plugin dependencies.

---

## ADR-006: 64-Bit Cumulative State Checksumming

### Status
Accepted

### Context
To verify determinism across multi-thousand tick runs, comparing entire state dumps is memory- and CPU-intensive.

### Decision
Implement a deterministic 64-bit FNV-1a / Murmur-inspired hashing utility (`src/sim/core/checksum.gd`) that hashes tick index, RNG state, entity count, and structured entity attributes into a single unsigned 64-bit integer.

### Consequences
- Instantaneous validation of state alignment (`Checksum(Run A) == Checksum(Run B)`).
- Continuous regression detection during development.

---

## ADR-007: Machinery Degradation & Component-Level Maintenance Architecture

### Status
Accepted

### Context
Infrastructure machinery (such as centrifugal water pumps, air scrubbers, electrical transformers) must degrade through physical operation rather than abstract health bars or magical timer repairs. Repairing machinery must require actual labor from trained personnel, dedicated time, and physical replacement components fabricated through the material economy.

### Decision
Model machinery hierarchically:
1. `Machine` base entity (`src/sim/machinery/machine.gd`) encapsulates operating state (`NOMINAL`, `DEGRADED`, `FAULT`, `BROKEN`), active repair orders, and aggregated throughput efficiency.
2. `MachineComponent` value objects (`src/sim/machinery/machine_component.gd`) track individual sub-assembly wear percentages ($0.0 \dots 100.0\%$), hourly wear accumulation rates, criticality weights, required spare resource IDs (e.g. `machined_bearing`), and repair labor tick requirements.
3. `MaintenanceSystem` (`src/sim/machinery/maintenance_system.gd`) executes continuous operating wear during ticks and schedules on-duty `maintenance_technician` labor to perform repairs when components exceed service thresholds ($\ge 60.0\%$).
4. Physical spare parts are strictly consumed from room inventory containers upon repair completion.

### Consequences
- True systemic dependency: machine shops producing bearings directly sustain the physical water supply.
- Broken machinery halts output (e.g. water throughput drops to $0.0\text{ L/min}$), creating genuine cascading colony crises when maintenance or parts fail.
- Fully deterministic, headless testable execution.

---

## ADR-008: Closed-Loop Systemic Dependencies, Utilities & Emergent Crises

### Status
Accepted

### Context
Survival in SILO must be governed by genuine physical and social feedback loops rather than artificial scripted crises or arbitrary random disaster timers. Human labor extracts raw resources, transforms them into machinery components, maintains utility infrastructure, supplies biological needs, and keeps the human workforce alive and capable of labor.

### Decision
1. Implement utility infrastructure systems (`WaterSystem` in `src/sim/utilities/water_system.gd`) that interface directly with machinery (`WaterPump`), accumulate buffer reservoirs, and distribute potable water to citizens based on metabolic demand ($\approx 2.5\text{ L/day/person}$).
2. Track vital biological states (`hydration_percent`, `health_percent`, `dehydration_ticks`) on `Person` entities.
3. Establish closed-loop logistics connecting `MachineShop` bearing outputs directly to `TYPE_WATER_PUMP_STATION` inventories for preventative and corrective maintenance.
4. Incapacitate workers when hydration drops below $20\%$, causing industrial output and maintenance labor to collapse without manual intervention or narrative scripts.

### Consequences
- Labor disruptions propagate organically across every intermediate domain layer down to population survival.
- Exact mass conservation holds for all resources and utilities ($0.000000\text{ kg}$ error).
- Zero reliance on artificial game-master scripts or random catastrophe injections.

---

## ADR-009: Demographics, Multi-Generational Continuity & Social Stratification

### Status
Accepted

### Context
A deep subterranean habitat must model multi-generational survival across simulated years and decades. Residents must experience biological aging, acquire skills through schooling, step into vacant workforce roles, form partnerships, have children with exact genealogical lineages, and pass away, cleanly freeing physical beds and workplaces without leaving orphaned pointers or phantom state.

### Decision
1. Implement `DemographicsSystem` (`src/sim/population/demographics_system.gd`) executing discrete daily life stage evaluations (`INFANT` $\rightarrow$ `CHILD` $\rightarrow$ `STUDENT` $\rightarrow$ `ADULT` $\rightarrow$ `ELDER`), education accumulation, job graduation, romance/partnerships, births, and age-based natural mortality.
2. Track `education_score`, `tenure_ticks`, and `seniority_level` directly on the `Person` entity.
3. Guarantee 100% reciprocal parent $\leftrightarrow$ child genealogical consistency for all living and deceased entities.
4. When a resident dies, immediately deallocate their bed in `Room`, clear their workplace and school assignments, and reassign household headship to surviving adult members.

### Consequences
- Enables plausible multi-decade demographic evolution and generational turnover.
- Prevents bed over-allocation and workforce ghost occupancy.
- Supports social mobility, seniority progression, and organic educational qualification pipelines.

---

## ADR-010: Institutional Governance, Policy Modulation & Physical Friction Architecture

### Status
Accepted

### Context
Player authority and governance in SILO must not rely on god-powers, arbitrary instantaneous stat injections, or gamified perk trees that break physical conservation and grounding. Player directives must flow through authentic administrative and institutional levers (work hours, rationing quotas, maintenance thresholds, security lockdowns, emergency overdrive decrees) that directly modulate autonomous domain systems while creating real, compounding opportunity costs and social friction.

### Decision
1. Implement `Policy` value entities (`src/sim/institutions/policy.gd`) organized into mutually exclusive categories (`rationing`, `work_hours`, `maintenance`, `security`, `education`) with defined standard, strict, and emergency presets.
2. Implement `ExecutiveOrder` directive entities (`src/sim/institutions/executive_order.gd`) representing targeted, time-limited decrees (`ORDER_MACHINE_OVERDRIVE`, `ORDER_WATER_CUTS`, `ORDER_OVERTIME_SURGE`, `ORDER_LOCKDOWN_SECTOR`, `ORDER_CONSCRIPT_LABOR`) that record accumulated physical consequences (`extra_wear_acc`, `social_tension_acc`).
3. Implement `InstitutionSystem` (`src/sim/institutions/institution_system.gd`) executing before downstream domain systems (`execution_order = 30`), synchronizing authoritative operational parameters into `WorldState.custom_data`.
4. Downstream systems (`DailyLifeSystem`, `ProductionSystem`, `MaintenanceSystem`, `WaterSystem`) query `WorldState.custom_data` for active modifiers while maintaining standalone default fallbacks when run in isolation.
5. Invariants (`src/sim/institutions/institution_invariants.gd`) strictly enforce category exclusivity, valid parameter limits, and authentic consequence tracking.

### Consequences
- Interventions have persistent, measurable physical and social trade-offs (e.g. overdrive increases pump output by 25% but accelerates component wear 2.5x; extended shifts increase production output but raise worker fatigue and social tension).
- Full determinism is preserved across arbitrary policy sequences.
- Headless test execution validates 100% invariant compliance with zero graphical dependencies.

---

## ADR-011: Decoupled Read-Only Presentation Projections & Command Dispatch Architecture

### Status
Accepted

### Context
In complex management and deep simulation games, attaching UI components directly to domain state frequently causes hidden circular dependencies, UI-driven state mutations, memory leaks from dangling object references, and non-deterministic behavior between headless and graphical runs.

### Decision
1. Presentation queries MUST access state exclusively through pure projection builders (`SimulationReader` in `src/presentation/simulation_reader.gd`) which return immutable data dictionaries containing zero authoritatively referenced objects.
2. Presentation formatters (`SimulationViewer` in `src/presentation/simulation_viewer.gd`) translate projection dictionaries into ASCII telemetry and UI view models without touching `WorldState` entities.
3. User interactions and player interventions flow strictly through `CommandAdapter` (`src/presentation/command_adapter.gd`) which validates and routes decisions through domain systems.
4. `ViewerInvariants` (`src/presentation/viewer_invariants.gd`) asserts that querying or rendering state produces zero checksum change, and that simulations executed with active UI queries produce bit-for-bit identical state checksums to headless simulation runs (`Run A == Run B`).

### Consequences
- UI can be attached, detached, or swapped (e.g. Godot graphical viewport, debug terminal inspector, headless CI reporter) with zero impact on simulation physics or determinism.
- Strict isolation prevents accidental UI-authoritative bugs.
- 100% headless testability for all presentation adapters.

---

## ADR-012: Systemic Incident Detection & Physical Correlation Architecture

### Status
Accepted

### Context
In traditional simulation games, crises and incidents are frequently triggered by artificial, scripted "disaster directors" or stochastic event injectors (e.g. random fire rolls, arbitrary pipe bursts, artificial famine modifiers). This violates Project SILO's physicalist core thesis, where all problems must emerge from physical bottlenecks, component degradation, workforce shortages, or institutional policy friction. Furthermore, incidents must automatically resolve when the underlying physical conditions normalize, avoiding stuck alerts or manual clear triggers.

### Decision
1. **Physicalist Condition Detection**: All incidents are evaluated by a pure analytical detection engine (`IncidentDetector` in `src/sim/incidents/incident_detector.gd`) that inspects authoritative telemetry thresholds:
   - Water reservoir depletion (< 20% warning, < 10% critical, 0 L emergency).
   - Machinery and pump component degradation (> 85% wear critical, fault/broken emergency).
   - Spare parts stockout (insufficient replacement parts while machines have > 60% wear).
   - Smelting and workplace labor starvation (unstaffed critical facilities stalling material flow).
   - Severe dehydration epidemics (> 10% population with hydration < 50%).
   - Escalating social unrest (social tension index > 50.0).
2. **Deterministic Lifecycle Tracking**: `IncidentSystem` (`src/sim/incidents/incident_system.gd`, `execution_order = 80`) executes at the end of each simulation tick after physical domain systems have finished:
   - New incidents are instantiated deterministically with monotonic IDs and onset ticks.
   - Ongoing conditions update severity and telemetry payloads.
   - When a physical condition returns to nominal bounds, `IncidentSystem` immediately marks the incident as resolved (`resolved_tick = current_tick`, `is_active = false`) and moves it to historical archives.
3. **Physical Correlation Invariant**: `IncidentInvariants` (`src/sim/incidents/incident_invariants.gd`) asserts bidirectional truth: every active incident must correlate with an actual physical condition in `WorldState`, and every physical threshold breach must be represented by an active incident (zero false positives, zero phantom incidents, zero missed emergencies).
4. **Presentation & Replay Isolation**: `SimulationReader` and `SimulationViewer` expose active incidents through read models without state mutations. Replay determinism (`Run A == Run B`) is strictly preserved across multi-week runs.

### Consequences
- True emergent gameplay: crises reflect real physical breakdowns and labor failures rather than arbitrary random events.
- Invariant validators provide regression proof against artificial disaster injection.
- Incident history provides rich, grounded telemetry for the upcoming Sprint 10 Narrative Interpreter.

---

## ADR-013: Headless Godot HTTP Server & Pure Decoupled HTML Observability Architecture

### Status
Accepted

### Context
Developing and validating a complex physicalist multi-generational colony simulation requires inspecting 100% of internal state, spatial layouts, material flows, machinery wear curves, and institutional dynamics without relying solely on ASCII terminal printouts or heavy GUI viewports. Furthermore, remote debugging via SSH/tmux requires a browser-accessible, zero-dependency dashboard that works identically on headless Linux servers and local developer workstations. Most importantly, inspecting simulation telemetry must NEVER mutate state, consume RNG seeds, or alter determinism checksums.

### Decision
1. **Headless In-Process HTTP Server (`tools/observer_server.gd`)**:
   - Implements a lightweight non-blocking `TCPServer` directly in Godot GDScript listening on `127.0.0.1:8080`.
   - Serves static assets (`res://src/viewer/`) and handles structured JSON REST endpoints (`/api/*`).
   - Zero third-party dependencies (no Node.js, npm, Python, or external webservers required).
2. **Pure Read-Only Projection Layer (`src/presentation/simulation_reader.gd`)**:
   - All HTTP endpoints query `SimulationReader` projection methods which extract duplicated, immutable dictionaries from `WorldState`.
   - Observer queries never invoke `SeededRandom`, never modify entity collections, and never alter state checksums.
3. **8-Step Physical Traceability & Invariant Auditing**:
   - Exposes full physical lineage from Geological Seam reserves down to Citizen Hydration (`/api/causal_chain`).
   - Exposes on-demand mathematical invariant validation (`/api/validate`) verifying mass conservation ($\Delta < 10^{-6}\text{ kg}$), parent/child acyclicity, and bed occupancy.
4. **Command Routing via `CommandAdapter`**:
   - Simulation stepping (`/api/step`), policy enactments (`/api/policy/*`), and executive orders (`/api/order/*`) route strictly through authoritative domain systems and `CommandAdapter`.
5. **Mathematical Invisibility Verification (`tests/presentation/test_observability_api.gd`)**:
   - Automated tests assert exact checksum equivalence between simulation runs with zero queries and runs subjected to 1,000+ queries per tick:
     $$\text{Checksum}(\text{Sim}_A) \equiv \text{Checksum}(\text{Sim}_B)$$

### Consequences
- Instant, rich visual and tabular inspection of all 22 simulation systems.
- Zero risk of UI-driven state pollution or non-deterministic divergence.
- Compatible with headless servers, SSH port-forwarding, and local development.

---

## ADR-014: Lived-Experience Political Identity & Exponential Memory Salience Decay

### Status
Accepted

### Context
In traditional strategy and colony simulation games, citizen political attitudes are often modeled via global aggregate sliders, arbitrary stochastic mood modifiers, or static faction assignments. This violates Project SILO's physicalist and generational core thesis, where political opinions must emerge causally from actual lived experiences within the habitat (e.g. bereavement from mining collapses, dehydration during water pump outages, demotions following disciplinary hearings, cramped housing conditions, or promotions with security clearance). Furthermore, memories must naturally fade over time with continuous exponential decay towards baseline cultural attitudes rather than instantaneous amnesia.

### Decision
1. **Per-Citizen Political Model (`src/sim/population/person.gd`)**:
   - Institutional Perceptions $[0.0, 1.0]$: `institutional_trust`, `perceived_fairness`, `perceived_security`, `economic_satisfaction`, `class_resentment`.
   - Departmental Confidence $[0.0, 1.0]$: `confidence_leadership`, `confidence_it`, `confidence_security`, `confidence_engineering`.
   - Philosophical Values $[0.0, 1.0]$: `preference_stability`, `preference_reform`, `preference_autonomy`, `preference_equality`, `preference_hierarchy`, `tolerance_coercion`.
2. **Opinion-Memory Ingestion (`src/sim/politics/opinion_memory.gd`, `src/sim/politics/political_event.gd`)**:
   - Discrete events record `event_type`, `onset_tick`, `attribution_dept`, `emotional_impact` $[-1.0, 1.0]$, and `description`.
   - Events are emitted by physical and social subsystems (e.g., `IncidentSystem`, `DemographicsSystem`, `WaterSystem`, `InstitutionSystem`).
3. **Continuous Exponential Salience Decay**:
   - Memories decay with a 30-day half-life ($t_{1/2} = 4,320\text{ ticks}$):
     $$\text{Salience}(t) = 2^{-\frac{t - t_{\text{onset}}}{4320}}$$
   - Attitudes dynamically recompute as a weighted combination of baseline traits and active decaying memories.
4. **Derived Habitat Legitimacy Model (`src/sim/politics/legitimacy_model.gd`)**:
   - Overall legitimacy is derived by aggregating living citizen trust, weighted by perceived fairness, security, and class resentment penalties.
   - Departmental trust ratings are computed per administrative branch.
5. **Causality & Invariant Enforcement (`src/sim/politics/political_invariants.gd`)**:
   - Invariants guarantee that all attitudes remain strictly in $[0.0, 1.0]$, that non-baseline attitude deviations are backed by causal memory entries, and that deterministic state checksums match across runs and serialization roundtrips.

### Consequences
- Citizens with identical jobs or ages will diverge politically based on their individual historical misfortunes or privileges.
- Policy decisions and physical crises leave measurable political scars that fade smoothly over months.
- Foundation established for upcoming ideological faction emergence (Sprint 13) and collective discontent (Sprint 14).




## ADR-Physical-Viewer: preserve existing spatial assignments

Accepted for Integration 12-PV, 2026-09-06.

The simulation already has Room levels, sectors, residential beds, household homes, occupation/school room assignments, machine room references, inventory ownership and timed abstract travel. Reorganizing these assignments to match an illustrative skyline would change travel and downstream outcomes. Preserve them. Add deterministic room bounds as a pure simulation-domain spatial model, exposed through the existing observability server. Mixed-use levels and deep housing reflect the existing generator, not an invented settlement policy.

Water is the only implemented utility flow. Industrial transfers are instantaneous inventory operations. The reservoir and geological reserve are global quantities without independent physical containers. Expose these as global/system dependencies with explicit unresolved locations. Do not invent pipes, haul routes, machine operators, detention cells, or rooms for unimplemented systems.

Use Canvas for residents and equipment, with density at low zoom and persistent IDs at close zoom. Preserve dashboard inspectors. Browser UAT blocked by environment restrictions must leave acceptance open even when deterministic headless validation passes.

---

## ADR-015: Emergent Faction Clustering & Bounded Social Graph Propagation

### Status
Accepted

### Context
Political movements, interest groups, and factions in deep colony/habitat simulations are frequently implemented through arbitrary top-down spawn scripts, static hardcoded party rosters, or random roll events. This violates Project SILO's physicalist and generational core thesis: political alignment and factional emergence must arise organically from lived grievances (demotions, machine overdrive, water rationing, workplace trauma), shared physical conditions (co-workers in the mines, co-residents in shared apartments, school cohort peers), and direct word-of-mouth persuasion across bounded social ties rather than omniscient broadcasting or artificial scripting.

### Decision
1. **Bounded Social Graph (`src/sim/politics/social_graph.gd`)**:
   - Model social connections strictly through lived relational contexts: Family ($w=0.95$), Household Co-residents ($w=0.85$), Workplace Coworkers ($w=0.65$), School Cohorts ($w=0.60$), Sector Neighbors ($w=0.35$), Shared Crisis Survivors ($w=0.50$).
   - Direct influence weight is calculated as a product of structural tie strength, recruiter seniority/persuasiveness, ideological alignment, and target openness/loyalty resistance (high-trust clearance officials resist anti-establishment recruitment).
2. **Organic Faction Emergence & Leadership Selection (`src/sim/politics/faction_system.gd`)**:
   - `FactionSystem` (`execution_order = 36`) scans the population for aggrieved, socially connected clusters (e.g. miners subjected to overtime decrees or foundry workers facing material bottlenecks) when cluster tension exceeds emergence thresholds ($\ge 25.0$).
   - Faction leaders are chosen organically by identifying the individual with the highest combined seniority, education, and social connectivity within the cluster.
   - Word-of-mouth recruitment propagates strictly along existing social graph edges from active members to unaligned contacts (converting through Unaligned $\rightarrow$ Sympathiser $\rightarrow$ Full Member).
3. **Dynamic Grievance Agendas & Policy Response**:
   - Factions automatically compile and weight grievance agendas based on active member lived memory categories (`workplace_incident`, `overtime_fatigue`, `resource_shortage`, `political_repression`).
   - Dynamic policy and executive order approval matrices calculate authentic support or opposition based on ideological profile and agenda alignment.
   - Inter-faction compatibility scores determine dynamic rivalry ($-1.0$) or coalition potential ($+1.0$).
4. **Authoritative Registration & Serialization (`src/sim/politics/faction.gd`, `src/sim/population/person.gd`)**:
   - Factions are first-class entities registered in `EntityRegistry` under `"faction"`, with deterministic monotonic IDs and complete `serialize()` / `deserialize()` support.
   - Persons track `faction_id` and `sympathiser_faction_id` in authoritative state.
5. **Deterministic Invariant Verification (`src/sim/politics/faction_invariants.gd`)**:
   - Invariants enforce valid entity references, metric bounds $[0.0, 1.0]$, active leadership consistency, absence of dual-membership conflicts, and exact checksum determinism across multi-week headless runs.
6. **Observability & HTML Viewer Integration**:
   - Expose rich read-only endpoints (`/api/factions`, `/api/faction_detail`, `/api/social_network`) in `SimulationReader` and `ObserverServer`.
   - Add a dedicated "Factions & Blocs" tab in `index.html` and `viewer.js` with faction cards, grievance platforms, policy approval bars, and interactive citizen social network inspector.

### Consequences
- Factions emerge only when real systemic friction occurs, naturally dissolving or remaining dormant during stable, prosperous periods.
- Recruitment is physically grounded: an isolated worker with no social ties cannot be recruited through word of mouth.
- Replay determinism (`Run A == Run B`) and observer invisibility are strictly maintained.
- Provides the structural foundation for Sprint 14 (Corruption, Patronage & Informal Power) and Sprint 15 (Strikes, Sabotage & Industrial Action).

