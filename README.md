# SILO

## Live physical viewer

```bash
cd ~/games/silo
./tools/run_observer.sh
```

Open the printed local URL (normally `http://127.0.0.1:8080/`). The default generated world contains 1,200 persistent residents. The physical cutaway is part of the existing observer; previous observability tabs remain available. Use `--pop 100 --seed 42 --port 8090` to customize startup.

See [Physical viewer](docs/PHYSICAL_VIEWER.md) for controls, truthful limits and UAT evidence, and [Physical coverage](docs/PHYSICAL_VIEWER_COVERAGE.md) for the spatial wiring audit. Integration 12-PV does not advance the advanced gameplay roadmap.

> **Civilisation simulation first. Management game second. Narrative game third.**

SILO is a deterministic, deep simulation of a long-lived underground human civilisation. The player acts as the Head of Information Systems / IT inside an isolated industrial habitat housing ~1,200 persistent residents (with growth potential to several thousand).

The game is built on **Simulation Truth**: every citizen, household, machine, component, inventory batch, and institutional process is a real, persistent simulation entity. Outcomes emerge directly from physical, economic, and social simulation dynamics rather than scripted events or arbitrary stat modifiers.

---

## Key Pillars

1. **Simulation Truth**: Real causal chains. A water crisis occurs because a pump bearing failed, machining lacked steel, foundry lacked ore, miners were unstaffed, and maintenance was deferred—not because a random event subtracted 30 water.
2. **Persistent Population**: Every resident has a persistent identity, lineage, household, bed assignment, qualifications, occupation, and schedule. No abstract population counters.
3. **Physical Industrial Economy**: Resources move through tangible transformation pipelines (mining → crushing → smelting → machining → stores → maintenance → machines). No global abstract `metal = 500`.
4. **Concrete Machinery & Utilities**: Machines degrade with operating hours, requiring human labour, tools, and fabricated spare parts. Power, water, ventilation, and data networks depend on physical infrastructure.
5. **Emergent Stratification**: Socioeconomic standing emerges from housing, occupation, ration entitlement, institutional power, and reputation, rather than arbitrary labels.
6. **Institutional Authority**: The player is not a god cursor. The player exercises power via structural Policies, operational Executive Orders, and targeted Special Interventions.
7. **Strict Determinism**: Zero reliance on global or unseeded randomness. Given `Seed + State + Inputs + Duration`, execution is 100% reproducible bit-for-bit.

---

## Tech Stack & Architecture

- **Engine**: Godot Engine 4.4+
- **Simulation Language**: GDScript (Core simulation runs decoupled from SceneTree)
- **Execution Model**: Headless-capable, discrete logical ticks (10 simulated minutes per tick; ~52,560 ticks/year; 45 real minutes at 1× ≈ 1 sim year).
- **Presentation**: Decoupled read models and adapters feed UI/isometric renderers. Entities are never Godot Scene Nodes with continuous `_process()` loops.

---

## Quickstart & Verification

### Running Headless Tests

Run the complete test suite headlessly via the Godot CLI:

```bash
godot --headless -s tools/test_runner.gd
```

Run specific test suites:

```bash
godot --headless -s tools/test_runner.gd -- unit
godot --headless -s tools/test_runner.gd -- determinism
godot --headless -s tools/test_runner.gd -- performance
```

---

## Documentation Index

- [`AGENTS.md`](AGENTS.md) — Agent operating model, roles, and handoff contracts.
- [`docs/GAME_PILLARS.md`](docs/GAME_PILLARS.md) — Core game concepts and player fantasy.
- [`docs/SIMULATION_SPEC.md`](docs/SIMULATION_SPEC.md) — Simulation mechanics, time model, and LOD architecture.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Technical architecture, system pipeline, and data flow.
- [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) — Entity data schemas and domain invariants.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — Phased development roadmap (Sprint 0 through Sprint 6).
- [`docs/CURRENT_SPRINT.md`](docs/CURRENT_SPRINT.md) — Active sprint objectives, deliverables, and acceptance gates.
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — Architecture Decision Records (ADRs).
- [`docs/TEST_STRATEGY.md`](docs/TEST_STRATEGY.md) — Testing philosophy, regression suites, and invariant checks.
- [`docs/PERFORMANCE_BUDGET.md`](docs/PERFORMANCE_BUDGET.md) — Tick time and memory limits for 100 to 1,200+ entities.
- [`docs/SAVE_FORMAT.md`](docs/SAVE_FORMAT.md) — State serialization and save/load verification specification.
- [`docs/GLOSSARY.md`](docs/GLOSSARY.md) — Canonical domain terminology.
