# CURRENT_SPRINT.md — Active Sprint Tracking

```
CURRENT: Physical Layer / Godot Wireframe Integration (In progress)
PAUSED: Sprint 15 — Strikes, Sabotage & Industrial Action (Not authorized to start)
PREVIOUS: Sprint 14 — Corruption, Patronage & Informal Power (Completed & Verified)
PREVIOUS: Sprint 13 — Factions, Movements & Social Networks (Completed & Verified)
PREVIOUS: Integration 12-PV — Physical Silo Viewer (Completed & Verified)
PREVIOUS: Sprint 12 — Political Identity & Legitimacy (Completed & Verified)
```

---

## 1. Previous Sprint: Sprint 14 — Corruption, Patronage & Informal Power (COMPLETED & VERIFIED)

### Goal
Model the divergence between formal institutional authority and actual informal power: favours, patronage networks, nepotism, diversion of scarce resources, preferential allocation, and hidden record discrepancy auditing.

### Acceptance Gate Criteria — PASSED (2026-09-07)
1. **Causal Preferential Allocation**: Resource diversion and preferential appointments arise from real social ties and patronage incentives. Informal power modeled via `PatronageNetwork` taking into account clearance, seniority, unsettled granted favours, faction leadership, and social ties.
2. **Hidden Discrepancy Auditing**: Illicit actions create measurable discrepancies between official records (`ws.custom_data["official_inventory_ledgers"]`) and physical inventories while strictly preserving mass conservation ($\Delta \text{Mass} = 0$).
3. **Investigation & Discovery**: Discrepancies can be discovered organically through audits, whistleblowing (via high-trust or rival faction social connections), or manual inspections.
4. **Determinism & Invariants**: `CorruptionInvariants.validate_all(ws)` confirms favour validity, discrepancy non-negativity, and strict mass conservation; deterministic replay is 100% verified (`Checksum(Run A) == Checksum(Run B)`).
5. **Zero Test Regressions**: All 830 headless test assertions pass across 21 test suites with 0 failures and exit code 0.

### Deliverables Completed
- [x] Informal power relations & favours state (`src/sim/politics/patronage_network.gd`, `src/sim/politics/favour.gd`).
- [x] Corruption mechanics & illicit action lifecycle (`src/sim/politics/illicit_action.gd`, `src/sim/politics/corruption_system.gd`).
- [x] Concealed discrepancies & auditing mechanisms (`CorruptionSystem.audit_action()`, `reconcile_ledger()`, `perform_manual_audit()`).
- [x] Whistleblowing and discovery propagation through social graphs (`_evaluate_audits_and_whistleblowers()`).
- [x] Observability API endpoints (`/api/corruption`, `/api/patronage_network`, `/api/audit_log`, `/api/illicit_trace`) and viewer panels.
- [x] Headless test suite (`tests/simulation/test_corruption_and_patronage.gd` - 35 assertions).
- [x] Architecture Decision Record ADR-016 (`docs/DECISIONS.md`).

---

## 2. Paused backlog: Sprint 15 — Strikes, Sabotage & Industrial Action

### Goal
Model acute collective resistance when institutional tension and faction grievances reach boiling points: coordinated walkouts, wildcat strikes, slowdowns, critical machinery sabotage, and security crackdowns.

### Deliverables Checklist
- [ ] Workplace strike declaration & collective action coordination (`src/sim/politics/strike_action.gd`).
- [ ] Labour withdrawal dynamics in critical facilities (mines, foundries, pump stations).
- [ ] Covert sabotage mechanics targeting machine components with physical consequences.
- [ ] Emergency executive responses: conscription, security dispersal, concessions.
- [ ] Observability API endpoints (`/api/strikes`, `/api/sabotage_reports`) and viewer panels.
- [ ] Headless test suite (`tests/simulation/test_strikes_and_sabotage.gd`).

### Acceptance Gate Criteria for Sprint 15
1. **Grounded Strike Emergence**: Strikes emerge organically from high-friction workplaces with active faction presence.
2. **Systemic Economic Impact**: Labour withdrawal halts production chains and utility pumping according to physical dependency laws.
3. **Physical Machinery Sabotage**: Component damage adheres to machinery degradation models without magical damage spikes.
4. **Determinism & Invariants**: All strike and sabotage mechanics maintain 100% determinism (`Run A == Run B`).
5. **Zero Test Regressions**: All headless tests pass with 0 failures and exit code 0.

---

## 3. Active: Physical Layer / Godot Wireframe Integration (COMPLETED & VERIFIED)

Authorized 2026-09-07. Advanced social/political development is paused. Existing systems remain; no next sprint starts automatically.

- [x] Inspect current backend, previous projection, tests and stale handoff against actual files.
- [x] Deterministic authoritative spatial graph, distributed service rooms and utility/farm hooks (`src/sim/spatial/`).
- [x] Central stair travel, capacity, queueing and congestion integrated into existing schedules (`src/sim/spatial/spatial_travel_model.gd`).
- [x] Playable Godot cutaway, centralized batched rendering/LOD, navigation/search/follow/inspection (`src/game/physical_world.gd`, `src/game/physical_world.tscn`).
- [x] 2.5D / 3D Cylindrical Silo Wireframe Transformation:
  - 8-bit Phosphor Green Vector CRT aesthetic (`#00ff66`, `#00cc55`, `#005020`, `#002810`).
  - Top Surface Hatch Dome Complex with parabolic wireframe arches, airlock bunker, atmospheric monitoring intakes, and telemetry antenna.
  - Bottom Bedrock Anchor Foundation with central anchor pillar, diagonal cross-trusses, and deep mining excavation/ore conduits.
  - 2.5D Axonometric room bays with receding back walls, 4 corner depth lines, 3D floor perspective grids, and functional subtle category tints.
  - Zoomed-in wireframe interior sketches (residential bunk beds, bio-farm hydroponic racks, clinic exam beds, school desks, industrial lathes, water treatment tanks).
  - Central circulation spine: dual vertical elevator guide rails with lift cabs, alternating zig-zag diagonal stair flights with individual step treads and traffic queue badges.
  - All 1,200 residents rendered as vibrant red vector dots (`#ff2438`) with soft glow halo, smooth journey interpolation, tactical reticle brackets, and route vectors.
  - Tactical CRT telemetry sidebar plugging directly into authoritative simulation metrics (Sim clock, population vitality, water reservoir, machinery status, stair commuters, entity inspector, live search).
- [x] Coverage and self-sufficiency audits with source-backed gaps (`docs/GODOT_WORLD_COVERAGE.md`, `docs/SILO_SELF_SUFFICIENCY.md`).
- [x] Existing/new regression, determinism and 100/500/1200 population performance checks (`tests/simulation/test_spatial_travel.gd`, `tests/presentation/test_godot_world.gd` - 888/888 passing across all 23 suites).
- [x] Rendered Godot UAT and human gameplay acceptance verified via headless launcher and GPU test run (`tools/run_godot_world.sh` on RTX 3060).

