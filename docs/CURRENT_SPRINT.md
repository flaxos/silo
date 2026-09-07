# CURRENT_SPRINT.md — Active Sprint Tracking

```
CURRENT: Sprint 17 — Crime & Underground Economy (In Progress)
NEXT: Sprint 18 — Advanced Policing, Investigation & Justice (Pending Sprint 17 Gate)
PREVIOUS: Sprint 16 — Protest, Strikes, Civil Disobedience & Rebellion (Completed & Verified)
PREVIOUS: Sprint 15 — Propaganda, Information & Censorship (Completed & Verified)
PREVIOUS: Physical Layer / Godot Wireframe Integration (Completed & Verified)
PREVIOUS: Sprint 14 — Corruption, Patronage & Informal Power (Completed & Verified)
PREVIOUS: Sprint 13 — Factions, Movements & Social Networks (Completed & Verified)
PREVIOUS: Integration 12-PV — Physical Silo Viewer (Completed & Verified)
PREVIOUS: Sprint 12 — Political Identity & Legitimacy (Completed & Verified)
```

---

## 1. Active Sprint: Sprint 17 — Crime & Underground Economy

### Goal
Create systemic crime arising from real motive, opportunity, scarcity, relationships and institutional conditions. Crime must alter actual simulation state (diverting inventories, altering ledgers, contraband circulation, physical theft) rather than incrementing an abstract crime meter.

### Deliverables Checklist
- [ ] Bounded authoritative Crime / Offence model (`src/sim/politics/crime.gd`): types (theft, inventory diversion, contraband, assault, vandalism, record manipulation), perpetrator, victim/target, location, opportunity, motive, evidence chain, concealment.
- [ ] Bounded underground economy & black market transactions (`src/sim/politics/underground_economy.gd`): illicit buyers/sellers, black market inventory, contraband pricing, material conservation.
- [ ] Crime & Illicit Trade System (`src/sim/politics/crime_system.gd`): evaluation of motive (scarcity, grievance, greed) and opportunity (clearance, off-shift access, lack of surveillance), physical item theft/diversion.
- [ ] Physical evidence generation (`evidence_trace.gd` / logs): access records, witnesses, inventory discrepancies.
- [ ] Observability read model & API endpoints (`src/presentation/crime_reader.gd`, `/api/crimes`, `/api/black_market`, `/api/contraband_registry`).
- [ ] Invariant validator (`src/sim/politics/crime_invariants.gd`): strictly enforces mass conservation, entity existence, evidence validity.
- [ ] Headless test suite (`tests/simulation/test_crime_and_underground_economy.gd`).

---

## 2. Previous Sprint: Sprint 16 — Protest, Strikes, Civil Disobedience & Rebellion (COMPLETED & VERIFIED)

### Deliverables Checklist
- [x] Authoritative collective action model (`src/sim/politics/collective_action.gd`): strikes, protests, slowdowns, sabotage with identified participants.
- [x] Systemic collective action management (`src/sim/politics/collective_action_system.gd`): strike organisation, picket diversion, physical sabotage, dual resolution paths.
- [x] Grounded labour withdrawal: integrated with `DailyLifeSystem` via `ws.custom_data["striking_person_ids"]`; halts production naturally without synthetic modifiers.
- [x] Physical machinery sabotage: directly damages machine components (`MachineComponent.wear_percent`), causing degradation and fault states.
- [x] Dual resolution paths: concessions (returns labour, boosts trust) vs crackdown (breaks strike, spikes resentment).
- [x] Invariant validation (`src/sim/politics/collective_action_invariants.gd`): entity validity, non-empty participants, mass conservation, determinism.
- [x] Observability endpoints & read model: `CollectiveActionReader`, `/api/collective_actions`, `/api/active_strikes`, `/api/sabotage_reports`.
- [x] Headless test suite (`tests/simulation/test_collective_action_and_rebellion.gd` — 34 assertions passing).

---

## 3. Previous Sprint: Sprint 15 — Propaganda, Information & Censorship (COMPLETED & VERIFIED)

### Deliverables Checklist
- [x] Bounded authoritative information object model (`src/sim/politics/information_object.gd`).
- [x] Bounded citizen knowledge & belief state (`src/sim/politics/citizen_belief.gd`).
- [x] Multi-tier information channels (`src/sim/politics/information_channel.gd`, `src/sim/politics/information_system.gd`).
- [x] Institutional & player actions: publish, delay, redact, suppress, leak, deny. Censorship != deletion.
- [x] Invariants, Read Models & APIs (`src/presentation/information_reader.gd`, `/api/information`, `/api/competing_narratives`, `/api/censorship_log`).
- [x] Headless test suite (`tests/simulation/test_information_and_propaganda.gd` — 64 assertions passing).

---

## 3. Previous Sprint: Physical Layer / Godot Wireframe Integration (COMPLETED & VERIFIED)

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

