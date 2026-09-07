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

---

## ADR-016: Informal Power, Patronage Networks & Epistemic Audit Discrepancies

### Status
Accepted

### Context
In hierarchical human societies subjected to scarce material resources and institutional rationing, official organizational charts and formal authority diverge from actual informal power. Bureaucrats, technicians, and officials divert resources, grant favors, and offer protection to relatives, friends, and political allies. Commonly in simulation games, corruption is modeled as a passive statistical tax or global modifier. In Project SILO, corruption must adhere to strict material conservation ($\Delta \text{Mass} = 0$), maintain epistemic divergence between official paperwork and ground reality, and propagate consequences along bounded social and institutional channels.

### Decision
1. **Informal Power & Patronage Graphs (`src/sim/politics/patronage_network.gd`)**:
   - Model informal power as a composite metric of formal clearance, tenure seniority, education score, faction influence, social network size, and actively held, unsettled favors owed by clients ($+12.0$ power per held favor debt).
   - Indebted clients suffer reduced autonomy and increased compliance to patron requests.
   - Detect patron-client clusters and calculate conflict-of-interest (COI) indices based on kinship ties, shared workplaces, and overlapping departmental jurisdictions.
2. **First-Class Informal Obligations (`src/sim/politics/favour.gd`)**:
   - Model informal debts as `Favour` objects tracking `granter_id`, `recipient_id`, `creation_tick`, `favour_type`, `obligation_value` ($0.0$ to $1.0$), and settlement lifecycle (`is_settled`, `settled_tick`).
3. **Mass-Conserving Illicit Diversion & Epistemic Discrepancies (`src/sim/politics/illicit_action.gd`, `src/sim/politics/corruption_system.gd`)**:
   - `CorruptionSystem` (`execution_order = 37`) evaluates temptation from disaffection, opportunity (clearance and workplace inventory access), and social pressure (needy relatives/clients).
   - Resource diversion physically transfers materials between inventory entities, strictly conserving mass.
   - Creates an official record discrepancy: the official ledger (`ws.custom_data["official_inventory_ledgers"]`) continues to record old higher stock values, while physical inventory is lower.
   - The gap constitutes hidden discrepancy tracked on `IllicitAction` with a `concealment_level` ($0.0$ to $1.0$).
4. **Organic Discovery, Auditing & Sanctions**:
   - Discovery occurs through two organic mechanisms: (1) Whistleblowing by honest co-workers or rival faction members in the perpetrator's social graph, or (2) Routine and manual institutional security audits.
   - Upon exposure, institutional sanctions (clearance demotion, formal warnings) apply, generating acute negative opinion memories (`EVENT_DISCIPLINARY_SANCTION`, `EVENT_CORRUPTION_DISCOVERED`), and official inventory records are reconciled to match physical ground truth.
5. **Invariant Validation (`src/sim/politics/corruption_invariants.gd`)**:
   - `CorruptionInvariants.validate_all(ws)` verifies entity references, obligation value bounds, discrepancy non-negativity, and verifies that `EconomyInvariants.validate(ws)` confirms total system mass conservation.
6. **Observability & HTML Viewer Integration**:
   - Exposed `/api/corruption`, `/api/patronage_network`, `/api/audit_log`, and `/api/illicit_trace` endpoints in `SimulationReader` and `ObserverServer`.
   - Integrated full "Corruption & Patronage" panel into HTML dashboard with patron cluster cards, illicit action registries, COI matrix, and 7-step causal audit trace inspector.

### Consequences
- Official reports can lie while physical inventories never do: players and systems must audit to reconcile records.
- Favor trading creates organic shadow alliances and nepotistic protection networks that undermine formal policy decrees.
- Full deterministic replayability (`Run A == Run B`) and observer invisibility are maintained.
- Provides the foundation for Sprint 15 (Strikes, Sabotage & Industrial Action) and Sprint 16 (Black Markets & Contraband).

---

## ADR-017: 2.5D / 3D Phosphor Green Cylindrical Silo Wireframe Presentation & Vector HUD

### Status
Accepted

### Context
To communicate the physical depth, scale, and claustrophobic gravity of the underground civilization, Project SILO required a visual representation that feels like a genuine architectural cross-section cutaway. The visual inspiration is the architectural cutaway poster showing a cylindrical silo embedded in bedrock: surface airlock dome, cylindrical outer casing, 20 habitable levels, central circulation spine with zig-zag stairs and vertical elevator shafts, and deep bedrock anchors. Rather than heavy textured 3D assets or flat 2D tilemaps, the design calls for an 8-bit phosphor green wireframe vector CRT aesthetic (`#00ff66`, `#00cc55`, `#005020`), vibrant red dots (`#ff2438`) for all 1,200 residents, and a tactical HUD sidebar plugging directly into authoritative simulation telemetry.

### Decision
1. **Phosphor Green 2.5D Cylindrical Geometry (`src/game/physical_world.gd`)**:
   - Silo outer casing columns with ring collars bounding the habitable cylinder.
   - Natural bedrock strata fracture lines in dark phosphor green flanking the structure.
   - Top Surface Hatch Dome Complex with parabolic wireframe arches, airlock bunker, atmospheric monitoring intakes, and telemetry mast above Level 1.
   - Bottom Geological Anchor Foundation with massive central anchor pillar, diagonal cross-trusses, and deep mining excavation conduits below Level 20.
   - Cylindrical curved floor plates for each level: curved 2.5D arc bowing forward/downward across each floor with structural I-beam cross-ties.
2. **2.5D Axonometric Room Bays**:
   - Front face outline in glowing green phosphor, receding back wall, 4 corner depth lines, and 3D floor perspective grid lines.
   - Zoom-dependent internal equipment wireframe sketches: residential double-deck bunk beds and lockers, bio-farm multi-tier hydroponic grow racks, clinic gurneys and IV stands, school desks and chalkboards, industrial lathes and workbenches, and water treatment cylindrical pressure vessels.
   - Functional subtle translucent category tints preserving the clean vector aesthetic.
3. **Central Circulation Spine (Stair Core & Elevator Shafts)**:
   - Alternating zig-zag diagonal stair flights between level landings with individual step treads and under-flight cross-truss lattice.
   - Dual vertical elevator guide rails flanking the stair core with wireframe lift car cabs.
   - Real-time congestion and queue badges on each stair segment.
4. **1,200 Living Residents as Vibrant Vector Red Dots (`#ff2438`)**:
   - Rendered with vivid solid core and soft outer glow halo, dynamically scaled across camera zoom levels.
   - Positioned realistically along 2.5D room floor planes or smoothly interpolated along stair flights and landings during travel.
   - Selected resident features tactical corner-bracket reticle `[ + ]`, destination route vector line, and floating tactical name/occupation HUD badge.
5. **Tactical CRT Sidebar HUD**:
   - Built directly into Godot presentation layer with retro vector terminal styling.
   - Real-time simulation telemetry stream: Sim Clock, Population vitality, Closed-loop water reservoir level, Machinery health, and Central circulation commuter count.
   - Live entity finder (name, ID, or room type) and comprehensive Entity Inspector displaying full authoritative read models without mutating simulation state.

### Consequences
- Delivers the full architectural cross-section atmosphere of the silo cutaway with physical depth.
- Performance remains exceptionally high (>60 FPS GPU, >140 FPS headless) by maintaining batched single-canvas rendering (`_draw()`) with zero per-resident node allocations.
- Deterministic simulation integrity is strictly preserved: presentation remains a 100% read-only consumer of `WorldState` and `PhysicalReader`.
- All 23 headless test suites (888 assertions) pass with zero regressions.

---

## ADR-018: Top-Down Circular Blueprint Mode, Expanded Facility Sizing & High-Contrast Tactical UI Console

### Status
Accepted

### Context
Following user playtesting and feedback on the 2.5D wireframe representation:
1. High-capacity facilities (School with 40 students, Deep Mine with 60 miners, Bio-Farm, Clinics, Canteens) were sized identically to smaller rooms, resulting in resident red dots cramming and overflowing room boundaries.
2. In level isolation mode (`[I]`), the view remained a 2D vertical cutaway rather than presenting the authentic architectural floor plan of a circular cylindrical silo.
3. Zooming into the cutaway caused world wireframe geometry to bleed through the right-hand UI sidebar due to partial alpha blending.
4. Raw JSON strings were dumped for household members and room occupants in the entity inspector.
5. Spacebar keypresses failed to pause when UI buttons held focus.
6. A real-time 0.5× speed was needed for smooth, continuous observation of resident transit.

### Decision
1. **Dynamic Architectural Sizing & Floor Alignment (`silo_spatial_model.gd`)**:
   - Facility widths scale proportionally by capacity up to 480 px (e.g. Deep Mine 472 px, School 368 px, Bio-Farm 316 px).
   - High-capacity facilities scale vertically to 104 px (from base 88 px).
   - Floor datum formula `y = floor_y - height` ensures all room bottoms sit flush upon the level girder regardless of variable ceiling heights.
2. **Top-Down Circular Blueprint Projection & Animated Transition (`physical_world.gd`)**:
   - Isolating a level triggers a smooth animated wireframe line transition (`floor_plan_transition` lerp) from vertical cutaway to top-down circular blueprint.
   - Circular floor plan arranges the central stair & elevator core in the middle ($R \le 54$ px), special/service facilities in the inner ring ($R \approx 145$ px), and residential apartments along outer radial sectors ($R \approx 250 - 340$ px) with radial hallways, compass markers (North/South/East/West), and concentric outer bulkheads.
   - Resident red dots smoothly lerp from cutaway coordinates to radial blueprint coordinates.
3. **Solid Opaque Tactical Blue / Cyan Console (`physical_world.gd`)**:
   - Right-hand telemetry panel and top header bar use 100% opaque slate navy backgrounds (`Color(0.024, 0.051, 0.086, 1.0)`) with tactical cyan borders and ice blue/electric cyan/white typography.
   - World wireframe geometry never bleeds through UI text regardless of zoom or pan.
4. **Structured Human-Readable Entity Formatting (`physical_world.gd`)**:
   - Replaced raw JSON dictionary outputs with dedicated bulleted formatters for citizens, resident bed assignments, households, assigned workers with on-site/off-site status, enrolled students, and machinery.
5. **Robust Global Input & Sub-Tick Motion**:
   - Global `_input(event)` intercepts Spacebar for pause toggle; all UI buttons set to `focus_mode = FOCUS_NONE`.
   - Added 0.5× speed toggle and continuous visual position interpolation (`person_visual_positions`) for smooth dot motion.

### Consequences
- Resolves all user feedback items cleanly while preserving strict simulation determinism and read-model decoupling.
- Delivers seamless visual switching between vertical cutaway overview and circular top-down architectural blueprint.
- Headless test suites remain 100% passing (888/888 assertions).

---

## ADR-019: 3D Isometric View Mode, Interconnected Blueprint Hallways, Vector Room Glyphs & Search Focus Isolation

### Status
Accepted

### Context
Following user playtesting and feedback on the physical presentation slice:
1. **Clock Display**: The status bar was stuck at `Year 1 · Day 1 · 00:00` even though simulation ticks were advancing because `PhysicalReader.get_updates(..., include_checksum=false)` omitted decomposed calendar fields.
2. **Spacebar Focus Trap**: Pressing Spacebar typed spaces into `search_edit` instead of toggling simulation pause because text input fields retained focus after mouse clicks outside the search box.
3. **Room Type Icons & Map Decluttering**: Rooms lacked recognizable visual symbols to distinguish room functions at a glance, and room label text cluttered dense sectors without an option to show icons only.
4. **Top-Down Floor Plan Structure**: The top-down blueprint scattered rooms radially rather than organizing them along authentic architectural corridors and hallways spanning from the central stairs.
5. **3D Isometric Silo View**: A third perspective was requested to show the physical depth and cylindrical geometry of the 20-level silo with a 3D isometric cutaway matching reference imagery.

### Decision
1. **Clock Telemetry Synchronization (`physical_reader.gd` & `physical_world.gd`)**:
   - `PhysicalReader.get_updates()` always populates `year`, `day_of_year`, `hour`, `minute`, `time`, and `formatted_time`.
   - `_update_status()` reads `ws.sim_clock` directly to format `Year %d · Day %d · %02d:%02d`, advancing 10 simulation minutes per tick.
2. **Search Focus Isolation & Spacebar Pause Handshake (`physical_world.gd`)**:
   - Mouse clicks outside the `search_edit` control immediately release focus (`search_edit.release_focus()`).
   - Spacebar input handler unfocuses `search_edit` if text is empty/whitespace and toggles simulation pause.
   - Pressing `Escape` releases focus and clears search queries.
3. **Vector Room Icons & 3-Way Label Display Mode (`physical_world.gd`)**:
   - Implemented `_draw_room_symbol(rtype, center, radius, color)` with distinct vector glyphs for all room types: Residential (house `⌂`), Dormitory (bunk bed), Canteen/Kitchen (dining bowl with steam), Hygiene (shower spray), Machine Shop (gear `⚙`), Foundry (crucible), Deep Mine (crossed pickaxes `⛏`), Water Pump (teardrop & waves `💧`), Server Room (rack slots), Clinic (medical cross `✚`), School (open book `📖`), Admin (pillar facade), Recreation (diamond star), Storage (crate), Security (shield `🛡`), Bio-Farm (sprout `🌱`), Waste Processing (recycling `♻`), Air Handler (fan), Power Plant (lightning bolt `⚡`).
   - Added 3-state label display toggle button (`TAGS: FULL [L]` / `TAGS: ICONS [L]` / `TAGS: OFF [L]`).
   - In `ICONS` mode, large room titles are hidden, leaving only the prominent vector icon and compact room ID tag (`#ID`) for an uncluttered wireframe map.
4. **Architectural Interconnected Hallways (`physical_world.gd`)**:
   - The top-down blueprint renders:
     - Central Circulation Hub ($R \le 54$ px) with spiral stair treads and dual elevator guides.
     - Central Ring Corridor ($R = 56 - 96$ px) with radial floor joint lines.
     - 4 Cardinal Avenue Corridors (North Sector A, East Sector B, South Sector C, West Sector D) with 32 px width, double structural walls, and floor tile hash marks.
     - 4 Diagonal secondary branch corridors ($45^\circ, 135^\circ, 225^\circ, 315^\circ$).
     - Perimeter Ring Corridor ($R = 348 - 372$ px).
   - Residential apartments neatly flank both sides of the 4 cardinal avenues in orderly blocks, sharing walls with the hallways and featuring door threshold openings connecting into the avenues.
   - Large facility rooms occupy quadrant bays adjoining the diagonal corridors and central ring.
5. **3D Axonometric Isometric View (`physical_world.gd`)**:
   - Implemented 3-way view switcher (`[V]`): `CUTAWAY`, `ISOMETRIC`, and `FLOOR PLAN`.
   - Isometric projection: $X_{\text{iso}} = (wx - wy) \cdot 0.866$, $Y_{\text{iso}} = (wx + wy) \cdot 0.5 + L \cdot 115.0$.
   - Renders 20 stacked cylindrical floor slabs with front $90^\circ$ cutaway exposing interior floor plates and balustrades.
   - Central vertical octagonal shaft with vertical elevator rails, animated elevator cabs, and winding helical spiral staircase.
   - Receding room bays along cylindrical arcs with doorways, category tints, vector symbols, and interior furniture sketches.
   - Outer bedrock cavern strata with jagged fracture lines and horizontal mining conduit tunnels.
   - 1,200 residents projected onto isometric floor planes and circulation spine.
   - Supports raycasting/picking for both rooms and individual residents in 3D isometric space.

### Consequences
- Satisfies all user UAT feedback items with zero compromises on simulation determinism or architectural clarity.
- Retains high GPU framerate (58+ FPS) via batched single-pass vector drawing.
- 100% test pass rate across all headless regression test suites (888/888 assertions).

---

## ADR-020: Information, Propaganda, Censorship & Epistemic Divergence (Sprint 15)

### Context
A realistic post-disaster underground society cannot rely on perfect, omnipresent knowledge. Information dissemination is inherently physical, institutional, and social:
1. Physical events occur authoritatively in `WorldState` (e.g. pipe ruptures, resource shortages, illicit diversion).
2. The administration communicates via official broadcast channels, bulletin boards, and workplace announcements, often redacting, delaying, or denying incidents.
3. Citizens hold bounded mental models (`CitizenBelief`), where eyewitnesses retain unshakeable confidence in direct experience while non-witnesses evaluate claims based on source credibility, institutional trust, and social network ties.
4. Suppressing an announcement must never delete simulation truth or rewrite witness memories.

### Decision
1. **Authoritative Information Model (`InformationObject`)**:
   - Represents announcements, notices, leaks, or rumors.
   - Preserves `truth_basis` (immutable dictionary of physical facts) alongside `claim` (the asserted framing, which may omit, spin, or fabricate facts).
   - Lifecycle states: `ACTIVE`, `DELAYED`, `REDACTED`, `SUPPRESSED`, `DENIED`.
2. **Bounded Citizen Belief Model (`CitizenBelief`)**:
   - Stored per citizen as `person.beliefs[event_id]`.
   - Tracks `has_direct_experience`, `known_truth`, `believed_claim`, `confidence`, and `doubt`.
   - Bounded by `MAX_HEARD_CLAIMS = 5` to ensure permanent memory bounds and interactive 1,200-resident performance.
3. **Censorship != Deletion Invariant**:
   - Calling `suppress_information()` halts broadcast delivery over official channels, but leaves `truth_basis`, inventory mass balances, and witness memories intact.
4. **Cognitive Divergence & Eyewitness Propaganda Detection**:
   - When an eyewitness (`has_direct_experience == true`) receives a contradictory official denial, their confidence in their own truth remains 1.0, skepticism towards the administration surges, and institutional trust drops.
   - When conflicting claims are heard by non-witnesses, ideological alignment (faction ties) and social network trust dictate adoption.
5. **Word-of-Mouth Network Propagation (`SocialGraph`)**:
   - Convinced citizens and witnesses spread claims along coworker and household edges during shift handovers, reinforcing belief conviction.
6. **Observability & Invariants**:
   - `InformationInvariants` validates ID monotonicity, truth preservation, bounded memory, and deterministic replay (`Run A == Run B`).
   - `InformationReader` exposes read models for information objects, citizen beliefs, competing narratives, and censorship logs.

### Consequences
- True epistemic divergence: factions and social classes form differing beliefs about the same physical silo reality.
- Headless verification: 64 new assertions passing with zero test regressions and 100% determinism.


