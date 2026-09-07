# AGENTS.md — Agent Operating Model & Handoff Contract

This document defines the agent operating model, role responsibilities, project rules, and handoff contracts for any AI coding agent working on Project SILO.

---

## 1. Operating Model & Role Specialisation

Roles represent specialized areas of responsibility. Even when working in a single conversation, keep these boundaries strictly partitioned.

```
                    ┌─────────────────────────┐
                    │ Orchestrator/Tech Lead  │
                    └───────────┬─────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│  Simulation  │        │  Population  │        │   Economy /  │
│  Architect   │        │    Agent     │        │   Industry   │
└──────────────┘        └──────────────┘        └──────────────┘
        │                       │                       │
        ├───────────────────────┼───────────────────────┤
        ▼                       ▼                       ▼
┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│Infrastructure│        │ Institutions │        │ QA / Determ. │
│    Agent     │        │    Agent     │        │    Agent     │
└──────────────┘        └──────────────┘        └──────────────┘
                                │
                                ▼
                        ┌──────────────┐
                        │ Presentation │
                        │    Agent     │
                        └──────────────┘
```

### Orchestrator / Tech Lead
- **Scope**: Scope control, sprint boundaries, architecture integrity, integration, roadmap tracking, acceptance gates.
- **Rules**: Must reject any work outside the active sprint. Enforces project rules and handoff contracts.

### Simulation Architect
- **Scope**: `src/sim/core/` (WorldState, SimClock, SeededRandom, EntityRegistry, EventQueue, Scheduler, Checksum).
- **Rules**: Owns deterministic execution, time stepping, entity lifecycle, and system ordering. May NOT implement presentation or UI concerns.

### Population Agent
- **Scope**: `src/sim/population/`, `src/sim/households/`.
- **Rules**: Owns citizens, households, genealogy, education, schedules, life stages. Must never bypass central simulation services (e.g., `SeededRandom`, `EntityRegistry`).

### Economy / Industry Agent
- **Scope**: `src/sim/economy/`, `data/resources/`, `data/occupations/`.
- **Rules**: Owns inventories, resources, production chains, manufacturing, mining, logistics. Must enforce material conservation—no generating resources from nothing without an explicit physical source.

### Infrastructure Agent
- **Scope**: `src/sim/machinery/`, `src/sim/utilities/`, `data/machines/`.
- **Rules**: Owns machinery degradation, component breakdown, maintenance tasks, and utility grids (power, water, air). Machines may not magically repair themselves without labor, skill, time, and parts.

### Institutions Agent
- **Scope**: `src/sim/institutions/`, `src/sim/policies/`, `data/policies/`.
- **Rules**: Owns organisations, departments, authority layers, policies, executive orders, special interventions, and emergent social stratification. (Activated in later sprints).

### QA / Determinism Agent
- **Scope**: `tests/`, `tools/`.
- **Rules**: Owns acceptance tests, regression suites, deterministic replay verification (`Run A == Run B`), invariant checkers, and performance benchmarking. Has authority to block sprint completion if gates fail.

### Presentation Agent
- **Scope**: `src/presentation/`, `src/game/`.
- **Rules**: Visualisation, debug UI, isometric representation, player interfaces. Presentation is strictly a consumer of read models; UI must NEVER own or mutate authoritative simulation state directly. Activated only after underlying simulation milestones permit.

---

## 2. Mandatory Project Rules

1. **NO FEATURE SPRAWL**: Never implement future roadmap features because they seem easy. Stick strictly to the active sprint in `docs/CURRENT_SPRINT.md`.
2. **NO PREMATURE POLISH**: No polished menus, elaborate graphics, shaders, character customisation, or narrative cinematics.
3. **NO GIANT GOD CLASSES**: Domain systems must have clear, bounded responsibilities.
4. **NO SILENT ARCHITECTURE CHANGES**: Important architectural decisions belong in `docs/DECISIONS.md`.
5. **NO TEST-FREE CORE SYSTEMS**: All simulation logic must be headlessly testable.
6. **NO HIDDEN MAGIC NUMBERS**: Balance constants must become named configuration constants or data files in `data/`.
7. **NO GLOBAL RANDOMNESS**: All randomness must originate from `SeededRandom` via `WorldState`. Never call `randi()`, `randf()`, `randf_range()` directly.
8. **NO UI-OWNED GAME STATE**: UI queries read models and dispatches player actions/orders. UI never stores authoritative state.
9. **NO NARRATIVE BEFORE SIMULATION**: Narrative interpretation is layered on top of simulation state, never hardcoded as arbitrary stat penalties.

---

## 3. Agent Handoff Contract

Every session must leave the repository in a pristine, reproducible state:

1. **Run Tests**: Execute `godot --headless -s tools/test_runner.gd` and confirm zero failures.
2. **Update `CURRENT_SPRINT.md`**: Update task checkboxes, record active sprint state, note any blockers or deferred items.
3. **Record Decisions**: If an architectural choice was made, record an ADR in `docs/DECISIONS.md`.
4. **Update Roadmap**: If sprint gates passed, update roadmap progress in `docs/ROADMAP.md`.
5. **Record Known Failures**: Explicitly document any unresolved bugs or performance regressions in `docs/CURRENT_SPRINT.md`.
6. **State What Remains**: Clearly state the next logical tasks so the inheriting agent can start immediately.
7. **No False Completion**: Never mark a sprint complete unless all acceptance gate criteria pass.

**The repository is the sole memory.** Do not rely on chat context.

## Physical viewer integration contract

Integration 12-PV is scoped to physicalising existing simulation. Read `docs/PHYSICAL_VIEWER.md` and `docs/PHYSICAL_VIEWER_COVERAGE.md` before modifying the map. Preserve Room IDs, sector/level assignments, household beds, workplaces and authoritative schedules. Geometry and query projections must remain deterministic and read-only. Browser movement is interpolation; dependency lines must never imply simulated hauling or future utility topology. Record unresolved links instead of assigning invented rooms. Report browser UAT and human gameplay acceptance independently of headless assertions.
