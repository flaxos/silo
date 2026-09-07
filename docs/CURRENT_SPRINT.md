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
- [x] User Feedback Resolutions (2026-09-07 Batch 2):
  - Fixed Clock Advancement: Synchronized decomposed calendar fields (`year`, `day_of_year`, `hour`, `minute`, `time`) in `PhysicalReader.get_updates()` and directly referenced `ws.sim_clock` in `_update_status()`. Time advances continuously by 10 simulation minutes per tick (`Year %d · Day %d · %02d:%02d`).
  - Fixed Spacebar Focus Trap: Added outside mouse click intercept to immediately release focus from `search_edit`, plus handled empty-query Spacebar presses inside search to release focus and toggle simulation pause seamlessly. Pressing `Escape` unfocuses and clears search.
  - Implemented Vector Room Type Icons: Designed custom vector glyphs for all 20 room types (residential house `⌂`, bunk bed, dining bowl with steam, hygiene spray, lathe/gear `⚙`, crucible, mining picks `⛏`, water teardrop `💧`, server racks, medical cross `✚`, school book `📖`, pillar facade, diamond star, storage crate, security shield `🛡`, bio-farm sprout `🌱`, recycling `♻`, fan, lightning `⚡`).
  - Added Room Label Display Modes: Added 3-state toggle button (`TAGS: FULL [L]` / `TAGS: ICONS [L]` / `TAGS: OFF [L]`). In `ICONS` mode, map text clutter is eliminated, displaying only the prominent vector icon and compact room `#ID` tag.
  - Architectural Interconnected Hallways: Upgraded the top-down circular blueprint with authentic circulation hallways: Central Stair & Elevator Hub, Central Ring Corridor ($R = 56-96$ px), 4 Cardinal Avenue Corridors (North Sector A, East Sector B, South Sector C, West Sector D) with double structural walls and floor tiles, 4 Diagonal secondary corridors, and Perimeter Ring Corridor. Residential apartments neatly flank both sides of the cardinal avenues with doorway thresholds opening into the hallways; large facilities occupy dedicated quadrant bays.
  - 3D Axonometric Isometric Silo Cutaway View (`[V]`): Added a full 3D isometric perspective view mode showing all 20 stacked cylindrical floor slabs with a front $90^\circ$ cutaway exposing interior floor plates, octagonal central shaft with vertical elevator rails and animated lift cabs, central helical spiral staircase with treads and railings, diagonal perimeter stairs, receding room bays with doorway thresholds and vector icons, outer bedrock cavern strata with mining conduit tunnels, and 1,200 residents rendered in 3D isometric space with full raycasting/picking support.
  - Verified 100% Pass Rate: All 23 headless test suites (888/888 assertions) pass with zero errors. All presentation suites pass in 90s. High GPU performance confirmed at 58+ FPS on RTX 3060.

