
SILO — DEEP SIMULATION PROJECT BOOTSTRAP

You are the founding technical architect and maintainer of a new game project.

Your task is not to build the whole game, but to establish a production-quality foundation another coding agent can inherit without conversation history.

The project must resist scope creep, hidden coupling, premature UI, and narrative bloat.

---

1. WORKING PROJECT

Working title: SILO

This is temporary. Create original work. Do not copy protected names, characters, designs, terminology, lore, events, or architecture from existing media.

---

2. PRODUCT THESIS

SILO is a deterministic simulation of a long-lived underground human civilisation.

The player eventually holds a senior information-systems role.

The game is:

«Civilisation simulation first. Management game second. Narrative game third.»

The simulation must function before authored narrative matters.

Every resident is a persistent entity. A population of 1,200 must mean 1,200 simulated people, not merely a number.

---

3. CORE PRINCIPLE

Important outcomes should originate from simulation state:

SIMULATION STATE
→ SYSTEMIC CONSEQUENCE
→ PLAYER INFORMATION
→ PLAYER ACTION
→ NEW SIMULATION STATE
→ OPTIONAL NARRATIVE

Avoid scripted stat changes such as:

Event_Water_Crisis
water -= 30
morale -= 10

unless an external event genuinely changes physical circumstances.

---

4. SIMULATION DOMAINS

The simulation will eventually include:

- persistent people, households, families, and generations
- education, employment, schedules, and social status
- physical resources and production chains
- persistent machines with wear, components, and maintenance
- power, water, wastewater, ventilation, food, communications, and logistics
- institutions, policies, authority, and social stratification

Do not implement every field immediately. Keep the architecture extensible.

---

5. PLAYER POWER

The player acts through institutional authority, not direct citizen control.

Policies

Structural rules affecting autonomous systems, such as housing, employment, maintenance, surveillance, medical priority, and information access.

Executive orders

Temporary priorities that reallocate labour and resources, creating opportunity costs.

Interventions

Direct actions such as detention, searches, lockdowns, quarantine, evacuation, access overrides, forced overtime, or information suppression.

Consequences must persist through simulation systems.

---

6. PLAYER ROLE

Initial role: Head of Information Systems / IT

Initial authority may include:

- IT staff
- computing infrastructure
- networks
- identity systems
- communications
- databases
- CCTV
- access control
- automation systems

Influence may extend to staffing, maintenance, logistics, education, personnel records, reporting, and surveillance.

Mining, medicine, food, policing, and industry initially remain outside direct authority.

Do not create rigid morality paths. Political power should emerge from behaviour.

---

7. TECHNOLOGY

Use modern or plausible near-modern technology:

- servers, storage, databases, Ethernet, fibre, CCTV, radios
- badge access, PLCs, sensors, motors, pumps, generators, UPS systems
- workshops, machine tools, ventilation, and water treatment

Keep systems playable and abstracted. Avoid magical technology and unnecessary real-world configuration detail.

---

8. ENGINE AND ARCHITECTURE

Use Godot 4.4+ and GDScript.

The simulation must not depend heavily on SceneTree Nodes.

Avoid:

- 1,200 "_process()" calls
- one active Node per citizen
- rendering-dependent simulation

The core must run:

- headlessly
- deterministically
- faster than realtime
- under automated tests

Rendering consumes simulation state; it is not authoritative.

A suitable architecture includes:

Simulation Core
├── SimClock
├── WorldState
├── EntityRegistry
├── Scheduler
├── EventQueue
├── SeededRandom
├── Domain Systems
└── PolicySystem
        ↓
Read Models / Queries
        ↓
Presentation Adapter
        ↓
Godot Scenes / UI

Document justified deviations.

---

9. DETERMINISM AND TIME

Given the same initial world, seed, inputs, and duration, important state must match exactly.

Use a central seeded RNG. Do not use uncontrolled randomness.

Support reproducibility through:

seed + save/state + input/event history

Target pacing:

45 real minutes at 1× ≈ 1 simulation year

Future controls:

PAUSE
1×
2×
4×
8×

Use a discrete simulation clock. Start with approximately 10 simulated minutes per core tick and document the final choice.

---

10. SIMULATION LOD

Every citizen remains a persistent entity.

Computational detail may vary:

- ACTIVE: detailed simulation for visible or involved entities
- SCHEDULED: normal schedule and destination simulation
- ABSTRACTED: event-based or mathematical updates

LOD may reduce cost but must not invent or remove truth.

---

11. SCALE TARGETS

Lore target: approximately 1,200 residents, potentially several thousand.

Test headlessly at:

100
250
500
1,200

Document tick cost, memory where measurable, scaling, and bottlenecks.

Do not optimise without measurements.

---

12. PROJECT RULES

- No feature sprawl.
- No premature polish, shaders, customisation, or cinematics.
- No giant god classes.
- Document important architecture changes.
- Test core systems headlessly.
- Replace important magic numbers with named configuration.
- Use only deterministic randomness.
- Keep authoritative state out of UI.
- Defer narrative until the simulation works.

---

13. REPOSITORY STRUCTURE

Create a sensible structure such as:

/
├── project.godot
├── README.md
├── AGENTS.md
├── docs/
├── src/
│   ├── sim/
│   ├── presentation/
│   └── game/
├── data/
├── tests/
└── tools/

Recommended documentation:

docs/
├── GAME_PILLARS.md
├── SIMULATION_SPEC.md
├── ARCHITECTURE.md
├── DOMAIN_MODEL.md
├── ROADMAP.md
├── CURRENT_SPRINT.md
├── DECISIONS.md
├── TEST_STRATEGY.md
├── PERFORMANCE_BUDGET.md
├── SAVE_FORMAT.md
└── GLOSSARY.md

Keep boundaries clear and documentation concise.

---

14. AGENT OPERATING MODEL

Create "AGENTS.md" defining these responsibilities:

- Orchestrator / Tech Lead: scope, architecture, delegation, integration, acceptance
- Simulation Architect: time, state, determinism, scheduling, entity lifecycle
- Population Agent: people, households, genealogy, education, jobs, schedules
- Economy / Industry Agent: resources, inventories, production, logistics
- Infrastructure Agent: machines, degradation, maintenance, utilities
- Institutions Agent: organisations, authority, policies, orders, interventions
- QA / Determinism Agent: tests, invariants, replay, performance, regression
- Presentation Agent: visualisation, debug UI, and player interfaces

These are responsibilities, not necessarily separate processes.

Presentation begins only when the simulation milestone permits it.

---

15. HANDOFF CONTRACT

Every substantial session must:

1. Run relevant tests.
2. Update "CURRENT_SPRINT.md".
3. Record significant decisions.
4. Update roadmap state.
5. Record known failures.
6. State what remains.
7. Never claim completion without passing the acceptance gate.

The repository, not chat history, is the memory.

---

16. ROADMAP

Do not combine sprints.

Sprint 0 — Project Foundation

Build only:

- repository structure
- documentation
- simulation clock
- deterministic RNG
- world state
- stable entity IDs
- event/scheduling foundation
- headless test runner
- smoke simulation

Acceptance: identical seed and tick count produce identical checksums; headless tests pass; rendering is unnecessary.

Exclude families, jobs, production, machinery, visual silo, policies, and narrative.

Sprint 1 — People Exist

Build persistent people, households, family relationships, housing, beds, life stages, and deterministic population generation for 100–1,200 residents.

Validate IDs, relationships, housing, beds, ages, and determinism.

Sprint 2 — Daily Life Works

Add occupations, departments, shifts, students, schedules, abstract travel, activities, and locations.

Run a seven-day simulation and verify coherent routines.

Sprint 3 — Material Economy

Implement:

iron ore
→ processed ore
→ metal stock
→ machined component

Require workers, workplaces, time, and inputs. Reconcile inventories and prevent material creation from nothing.

Sprint 4 — Machines Need People

Implement one complete water-pump vertical slice with wear, failure, maintenance tasks, skills, parts, tools, downtime, and repair.

Sprint 5 — Systemic Dependency Loop

Connect workforce, mining, manufacturing, spare parts, maintenance, water infrastructure, and wellbeing.

A deterministic staffing reduction must cause an emergent water crisis without a scripted crisis function.

Sprint 6 — Society Across Time

Add ageing, education, qualifications, relationships, births, deaths, retirement, inheritance where needed, and class mobility.

Sprint 7 — Institutional Control

Add policies, executive orders, and interventions that modify existing systems rather than arbitrary narrative stats.

Sprint 8 — Playable Simulation Viewer

Add an intentionally rough interface for inspecting residents, households, workplaces, machines, production, alerts, relationships, tasks, inventories, and dependencies.

Sprint 9 — Systemic Incidents

Detect existing conditions such as production collapse, absenteeism, infrastructure risk, shortages, unrest, disease clusters, and outages.

Sprint 10 — Narrative Interpreter

Only after the simulation is demonstrably interesting. Narrative may interpret simulation conditions but must not replace them.

---

17. BACKLOG ONLY

Do not implement yet:

- detailed politics, factions, rebellion, corruption, propaganda
- advanced policing, crime, romance, genetics, epidemics, psychology
- advanced pathfinding and electrical/network topology
- PLC simulation
- full isometric construction
- procedural generation, combat, expeditions, outside world, endgame
- final art, audio, modding, multiplayer

---

18. INVARIANTS

Add automated validation where practical.

Examples:

- plausible ages, jobs, and life stages
- valid housing and beds
- reciprocal family relationships
- conserved inventories and production
- failed machines produce no normal output
- no simultaneous incompatible jobs or locations
- dead entities cannot work
- detention rules are respected

---

19. SAVE AND DEBUGGING

Document:

- world seed
- simulation timestamp
- stable IDs
- authoritative state
- configuration references
- version number

Do not serialise presentation objects as authoritative state.

Eventually support:

generate_world(seed, population)
advance_ticks(n)
inspect_person(id)
inspect_household(id)
inspect_inventory(location)
inspect_machine(id)
world_checksum()
validate_world()

---

20. PERFORMANCE

Optimise architecture before micro-optimisation.

Avoid per-resident "_process()", unnecessary Nodes, frame polling, thousands of Timers, repeated full-world scans, and hot-loop allocations.

Prefer central scheduling, batching, indexed access, event-driven updates, cached derived values, and deterministic work scheduling.

---

21. CURRENT TASK

Perform Sprint 0 only.

Do not implement population simulation.

1. Inspect or initialise the repository.
2. Create concise documentation.
3. Create a working Godot project.
4. Implement:
   - "SimClock"
   - deterministic RNG wrapper
   - stable entity-ID service
   - "WorldState"
   - scheduled/event execution
   - headless smoke simulation
   - deterministic checksum
   - repeatability test
5. Create "AGENTS.md".
6. Set "CURRENT_SPRINT.md" to:

CURRENT: Sprint 0 — Project Foundation
NEXT: Sprint 1 — People Exist

If all acceptance tests pass, mark Sprint 0 complete and set the current sprint to Sprint 1, but do not implement Sprint 1.

---

22. ACCEPTANCE GATE

Do not declare success unless:

- Godot parses and launches headlessly
- automated tests run
- deterministic simulation tests pass
- identical seeds produce identical checksums
- different seeds produce different expected randomised state
- the simulation core has no rendering dependency
- documentation exists
- "AGENTS.md", "ROADMAP.md", and "CURRENT_SPRINT.md" exist
- no unexplained parser errors remain
- repository status is understandable

---

23. FINAL RESPONSE FORMAT

Report only:

Created

Files and systems created.

Architecture

Important choices made.

Tests

Exact tests and results.

Determinism

Evidence of repeatability.

Deviations

Intentional differences and reasons.

Risks

Technical issues to monitor.

Sprint status

Exactly which sprint is complete/current.

Next bounded task

One copy-paste prompt for the next agent to execute Sprint 1.

Do not implement the next task.

---

24. PRINCIPLE FOR FUTURE AGENTS

When choosing between adding features and making the simulation coherent, observable, deterministic, and tested, choose the latter.

Build a simulation where interesting stories emerge before writing those stories.

