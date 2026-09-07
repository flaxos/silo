# ROADMAP.md — Project Roadmap

The SILO roadmap is strictly sequenced. Each sprint is gated by automated acceptance tests, invariant validators, and deterministic verification before the next sprint can begin.

---

```
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 0: Project Foundation (Completed)                    │
│ Core Clock, Seeded PRNG, Entity Registry, Event Scheduler,  │
│ State Checksums, Headless Test Runner.                      │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 1: People Exist (Completed)                          │
│ Persistent Person & Household Entities, Bed Assignments,    │
│ Genealogy, Deterministic Population Generator (100–1,200).  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 2: Daily Life Works (Completed)                      │
│ Occupations, Shifts, Schools, 24h Daily Routine Schedules,  │
│ Sector-to-Sector Travel Abstraction.                        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 3: Material Economy (Completed)                      │
│ Physical Production Chains (Ore → Smelt → Machine → Store), │
│ Conservation of Mass, Staffed Workplaces.                   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 4: Machines Need People (Completed)                  │
│ Water-Pump Vertical Slice: Degradation, Components, Wear,   │
│ Maintenance Tasks, Labor, Spare Parts, Tools & Downtime.    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 5: Systemic Dependency Loop (Completed)              │
│ Closed Loop: Workforce → Mining → Manufacturing → Parts →   │
│ Maintenance → Water → Wellbeing. Emergent Water Crisis.     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 6: Society Across Time (Completed)                   │
│ Ageing, Education, Qualifications, Relationships, Births,   │
│ Deaths, Retirement, Inheritance, Emergent Class Mobility.   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 7: Institutional Control (Completed)                 │
│ Policies, Executive Orders, Emergency Interventions         │
│ Modifying Autonomous Systems with Concrete Opportunity Cost.│
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 8: Playable Simulation Viewer (Completed)            │
│ Pragmatic UI / Inspection Viewers: Residents, Households,   │
│ Workplaces, Machines, Production, Tasks, Inventories.       │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 9: Systemic Incidents (Completed)                    │
│ Detect & Surface Emergent Habitat Conditions: Bottlenecks,  │
│ Absenteeism, Critical Infrastructure Risk, Outages, Unrest. │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 10: Narrative Interpreter                            │
│ Grounded Narrative Layer Interpreting Simulation State      │
│ Without Altering Authoritative Physics or Inventing Stats.  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SPRINT 11: Complete HTML Sim Observability (Completed)      │
│ Local Developer Web Viewer Exposing 100% of Authoritative   │
│ Simulation State & Wiring with Zero-Mutation Guarantees.    │
└─────────────────────────────────────────────────────────────┘
```

---

## Sprint Specifications

### Sprint 0 — Project Foundation (Completed)
- **Hypothesis**: We can create an engine-independent, deterministic simulation core running headlessly in Godot 4.4+.
- **Deliverables**: Repository structure, full documentation suite, `SimClock`, `SeededRandom`, `EntityRegistry`, `EventQueue`, `Scheduler`, `Checksum`, `WorldState`, `SimulationEngine`, and `tools/test_runner.gd`.
- **Acceptance Gate**: Deterministic test passes (`Run A == Run B` checksum match for identical seed/ticks). Headless test runner passes with exit code 0. Zero rendering dependencies.
- **Exclusions**: No people, jobs, production, machines, UI, or narrative.

### Sprint 1 — People Exist (Completed)
- **Hypothesis**: The simulation can represent a persistent population of 100 to 1,200+ residents with valid genealogies, households, and bed assignments.
- **Deliverables**: `Person`, `Household`, `Room` (residential), deterministic population generator for 100, 250, 500, and 1,200 populations.
- **Acceptance Gate**: 100% invariant validity: no duplicate IDs, valid parent/child reciprocal links, no bed over-allocation, plausible age structures, deterministic generation across runs.
- **Exclusions**: No jobs, economy, or social AI.

### Sprint 2 — Daily Life Works (Completed)
- **Hypothesis**: Residents can autonomously live a coherent 24-hour cycle without player micro-management.
- **Deliverables**: Occupations, shifts, departments, school assignments, daily routines, transit times between sectors.
- **Acceptance Gate**: 7-day headless simulation showing coherent sleep → travel → work/study → return loops without teleportation.

### Sprint 3 — Material Economy (Completed)
- **Hypothesis**: The silo can transform physical materials through staffed production chains with strictly conserved inventories.
- **Deliverables**: Resource registry, inventory containers, production chain (Iron Ore → Processed Ore → Metal Stock → Machined Component), workplace staffing checks.
- **Acceptance Gate**: Unstaffed mine starves foundry; unstaffed foundry starves machine shop. Zero resource generation from nothing. Inventories strictly reconcile.

### Sprint 4 — Machines Need People (Completed)
- **Hypothesis**: Infrastructure degrades with wear and requires real labor, skills, and fabricated replacement components to stay operational.
- **Deliverables**: Complete water-pump vertical slice with wear curves, breakdown states, maintenance task dispatch, required skills, tools, downtime, and repair.
- **Acceptance Gate**: Deep-well pump fails when bearing wears out; repair succeeds only when technician, tools, and replacement bearing are present.

### Sprint 5 — Systemic Dependency Loop (Completed)
- **Hypothesis**: Closing the physical loop between workforce, mining, manufacturing, spare parts, maintenance, water infrastructure, and wellbeing creates genuine systemic crises.
- **Deliverables**: Integrated multi-system feedback loops.
- **Acceptance Gate**: A deterministic staffing reduction in mining/machining organically causes pump failure and water crisis without any scripted crisis event functions.

### Sprint 6 — Society Across Time (Completed)
- **Hypothesis**: The habitat can sustain multi-generational population turnover with dynamic social stratification.
- **Deliverables**: Ageing, education, qualifications, relationships, marriage, births, deaths, retirement, inheritance, and emergent class mobility.
- **Acceptance Gate**: 50-year headless simulation maintains plausible demographics, generational continuity, and fluid socioeconomic mobility.

### Sprint 7 — Institutional Control (Completed)
- **Hypothesis**: The player can manage habitat operations through institutional policies, executive orders, and targeted interventions that modify autonomous simulation behaviors.
- **Deliverables**: Policy engine, executive order dispatch, security access overrides, clearance matrix, intervention consequence tracking.
- **Acceptance Gate**: Interventions alter behavior with persistent opportunity costs rather than arbitrary stat modifiers.

### Sprint 8 — Playable Simulation Viewer (Completed)
- **Hypothesis**: A pragmatic, decoupled UI allows full inspection of all simulation state without owning authoritative data.
- **Deliverables**: Inspection viewers for residents, households, workplaces, machines, production chains, alerts, tasks, and inventories.
- **Acceptance Gate**: Headless simulation runs identical checksums with or without UI attached.

### Sprint 9 — Systemic Incidents (Completed)
- **Hypothesis**: Diagnostic telemetry can detect and surface emergent conditions across the habitat.
- **Deliverables**: Telemetry monitors for production collapse, absenteeism, infrastructure risk, critical spare parts shortages, unrest, and outages.
- **Acceptance Gate**: Incidents trigger purely on physical/social simulation thresholds and auto-resolve when conditions normalize.

### Sprint 10 — Narrative Interpreter
- **Hypothesis**: Authorship can interpret rich simulation history into compelling narrative logs without compromising simulation truth.
- **Deliverables**: Event journaling, incident recaps, resident biographies generated from state history.
- **Acceptance Gate**: Narrative layer is strictly read-only and exerts zero backward causality on physics or state.

### Sprint 11 — Complete HTML Sim Observability (Completed)
- **Hypothesis**: A complete, decoupled HTML developer dashboard can expose 100% of authoritative simulation systems and physical causal lineage with zero mutation side effects.
- **Deliverables**: Headless Godot HTTP server (`tools/observer_server.gd`), REST JSON API, 16-view developer UI (`src/viewer/`), 8-step physical traceability graph, 22-system matrix, launcher script (`tools/run_observer.sh`), and mathematical invisibility proofs.
- **Acceptance Gate**: 100% system coverage, 0 state mutations on read (`Checksum(Sim A) == Checksum(Sim B)`), all headless assertions pass.

### Sprint 12 — Political Identity & Legitimacy (Completed)
- **Hypothesis**: Citizens develop divergent, persistent political attitudes and institutional trust based on their lived experiences and observed events rather than arbitrary sliders.
- **Deliverables**: Political perception state on `Person`, `OpinionMemory` event journal with 30-day exponential half-life, `PoliticalSystem` (`execution_order = 35`), `LegitimacyModel`, causal attribution trace, invariant validation (`political_invariants.gd`), and HTML observability console integration.
- **Acceptance Gate**: Multi-year deterministic scenario where citizens with different histories develop measurably different attitudes; all attitudes are causally traceable back to source events; zero false global meters; all 643 headless test assertions pass with 0 failures.

### Sprint 13 — Factions, Movements & Social Networks (Completed)
- **Hypothesis**: Citizens organically coalesce into distinct ideological factions and social blocs based on shared political identities, occupations, lived grievances, and bounded social networks without hardcoded membership.
- **Deliverables**: Bounded social graph (`social_graph.gd`), authoritative `Faction` entity, organic emergence and recruitment engine (`faction_system.gd`), person affiliation state, dynamic grievance agendas, policy approval matrices, inter-faction rivalry/coalition dynamics, invariant validation (`faction_invariants.gd`), and HTML observability console integration (`/api/factions`, `/api/faction_detail`, `/api/social_network`).
- **Acceptance Gate**: Deterministic stress scenario where aggrieved worker clusters form movements, elect organic leaders, recruit along social edges, and calculate dynamic policy approvals; 100% determinism (`Run A == Run B`); all 789 headless test assertions pass across 20 test suites with 0 failures.

### Sprint 14 — Corruption, Patronage & Informal Power (Completed)
- **Hypothesis**: In hierarchical habitats under scarce resource rationing, official authority diverges from actual informal power, generating shadow favour trading, nepotistic protection, and epistemic discrepancies between official records and physical truth.
- **Deliverables**: Informal power network modeling (`patronage_network.gd`), authoritative favours ledger (`favour.gd`), illicit diversion actions (`illicit_action.gd`), corruption evaluation and audit reconciliation system (`corruption_system.gd`), invariant validation (`corruption_invariants.gd`), and HTML observability console integration (`/api/corruption`, `/api/patronage_network`, `/api/audit_log`, `/api/illicit_trace`).
- **Acceptance Gate**: Multi-week deterministic scenario modeling mass-conserving resource diversion ($\Delta \text{Mass} = 0$), epistemic ledger discrepancy creation, whistleblower discovery via social graph, institutional sanctions, and audit ledger reconciliation; 100% determinism (`Run A == Run B`); all 830 headless test assertions pass across 21 test suites with 0 failures.

### Sprint 15 — Propaganda, Information & Censorship (Completed)
- **Hypothesis**: Information operates as an authoritative, simulated resource and political instrument where epistemic divergence emerges naturally from channel access, social graph proximity, trust, and physical witness experience.
- **Deliverables**: Authoritative information object model (`information_object.gd`), bounded citizen belief state (`citizen_belief.gd`), multi-tier distribution channels (`information_channel.gd`, `information_system.gd`), institutional actions (publish, delay, redact, suppress, leak, deny), invariant validation (`information_invariants.gd`), and HTML observability console integration (`/api/information`, `/api/competing_narratives`, `/api/censorship_log`).
- **Acceptance Gate**: Divergent beliefs across social networks; censorship does not mutate simulation truth or delete witness memories; corruption whistleblowing generates competing claims; all 888+ headless test assertions pass with 0 failures.

### Sprint 16 — Protest, Strikes, Civil Disobedience & Rebellion (Completed)
- **Hypothesis**: Political conflict, faction grievances, and divergent beliefs coalesce into physical collective actions (strikes, protests, slowdowns, sabotage) carried out by identified citizens with real economic and infrastructural consequences.
- **Deliverables**: Authoritative collective action model (`collective_action.gd`), systemic collective action engine (`collective_action_system.gd`), grounded labor withdrawal via `DailyLifeSystem` halting production naturally, targeted physical machinery sabotage degrading component health (`MachineComponent.wear_percent`), dual resolution paths (concessions vs crackdown), invariant validation (`collective_action_invariants.gd`), and observability endpoints (`/api/collective_actions`, `/api/active_strikes`, `/api/sabotage_reports`).
- **Acceptance Gate**: Striking workers stop scheduled labor halting physical production chains; physical sabotage damages machine components; concessions restore labor while crackdowns spike resentment; 100% determinism (`Run A == Run B`); all 986 headless test assertions pass across 25 test suites with 0 failures.

---

## Advanced Phases (Sprints 13–45)
For the full detailed specifications of Sprints 13 through 45, see [docs/ADVANCED_ROADMAP.md](file:///home/flax/games/silo/docs/ADVANCED_ROADMAP.md).


## Integration 12-PV — Physical Silo Viewer (Completed)

- **Hypothesis**: The authoritative simulation state can be projected onto a real-time, deterministic 2.5D cutaway underground map with zero state mutation side effects, exact spatial correspondence, and sub-second generation at scale.
- **Deliverables**: Authoritative spatial model (`silo_spatial_model.gd`), physical query adapter (`physical_reader.gd`), REST API endpoints (`/api/physical_snapshot`, `/api/physical_delta`, `/api/physical_entity`, `/api/physical_search`), interactive HTML5 Canvas cutaway renderer (`physical.js`, `physical.css`), follow-person / follow-household camera trackers, and comprehensive UAT test automation.
- **Acceptance Gate**: All 5 UAT automation criteria pass; 1,200 resident spatial generation under 1,000 ms (896 ms measured); observer invisibility mathematically proven (`Checksum A == Checksum B`); all 757 test assertions pass (19 test suites, 0 failures).
