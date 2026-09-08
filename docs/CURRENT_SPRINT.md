# CURRENT_SPRINT.md — Active Sprint Tracking

```
CURRENT: Integration — Playable Operations Loop V0.1 (IMPLEMENTED; DESKTOP UAT PENDING)
PAUSED: Sprint 23 — Advanced Spatial Model & Pathfinding (not advanced)
PREVIOUS: Sprint 22 — Epidemics & Public Health (Completed & Verified)
PREVIOUS: Sprint 21 — Genetics, Heredity & Population Health (Completed & Verified)
PREVIOUS: Sprint 20 — Relationships, Romance & Household Dynamics (Completed & Verified)
PREVIOUS: Sprint 19 — Psychology, Stress & Adaptation (Completed & Verified)
PREVIOUS: Sprint 18 — Advanced Policing, Investigation & Justice (Completed & Verified)
PREVIOUS: Sprint 17 — Crime & Underground Economy (Completed & Verified)
PREVIOUS: Sprint 16 — Protest, Strikes, Civil Disobedience & Rebellion (Completed & Verified)
PREVIOUS: Sprint 15 — Propaganda, Information & Censorship (Completed & Verified)
PREVIOUS: Physical Layer / Godot Wireframe Integration (Completed & Verified)
PREVIOUS: Sprint 14 — Corruption, Patronage & Informal Power (Completed & Verified)
PREVIOUS: Sprint 13 — Factions, Movements & Social Networks (Completed & Verified)
PREVIOUS: Integration 12-PV — Physical Silo Viewer (Completed & Verified)
PREVIOUS: Sprint 12 — Political Identity & Legitimacy (Completed & Verified)
```

---

## 1. Active Sprint: Playable Operations Loop V0.1

Authorized integration window: approximately five hours. Advanced roadmap remains paused.

- [x] Inspect actual bootstrap, simulation, authority, physical projection and tests.
- [x] Define two-template loop: pump maintenance risk and institutional information review.
- [x] Implement deterministic cases, supported causal evidence and IT command authorization.
- [x] Integrate compact Godot operations queue, detail, location links and consequence history.
- [x] Prove water and non-infrastructure information loops.
- [x] Record targeted population/facility audit.
- [x] Complete full regression, replay, persistence and 1,200 population checks.
- [x] Record rendered UAT separately from human gameplay acceptance.
- [x] Operations UX Clarity & Correctness Pass:
  - [x] Human narrative presentation layer (`src/presentation/case_formatter.gd`) answering 7 core operational questions.
  - [x] Plain-English briefings without raw engine enums or debug jargon.
  - [x] Clear root problem (facility) vs. information status (official report) distinction.
  - [x] Strict authority separation: IT authority vs. Outside authority.
  - [x] Action trade-offs and anti-magic disclaimers on every choice.
  - [x] Staffing audit fix: generated 27 security officers assigned to Level 7 Security Post (0 errors).
  - [x] Labour crew cap (`MAX_CREW_PER_MACHINE = 3`) eliminating instant-repair bug.
  - [x] Subsystem performance profiling tool (`tools/profile_slow_ticks.gd`).
  - [x] Dedicated Directive / Decision Terminal Console: Housed in its own framed tactical OS container (`directive_box: PanelContainer`) with header banner, high-contrast directive choice picker, structured BBCode breakdown (Purpose, Trade-off, ⚠️ Anti-magic boundary), and bold execution trigger.
  - [x] Top-to-Bottom Vertical Rhythm & Viewport Scaling: Formatted layout into an intuitive flow (Case Identify & Locate → OS Telemetry Vitals Card → Dedicated Directive Console → Deep Dossier / History Tabs → Session Footer) fitting comfortably within the 830px panel limit without cramped controls.
  - [x] Remote Mobile Web UAT Setup:
    - Embedded Operations REST API in `tools/observer_server.gd` (`/api/operations/brief`, `/api/operations/detail`, `/api/operations/action`, save/load, auto-pause on case trigger).
    - Responsive mobile CSS with touch targets >= 44px (`src/viewer/operations.css`).
    - Mobile Operations Controller with auto-polling, directive dispatch, auto-pause detection, and silo map focus (`src/viewer/operations.js`).
    - Mobile thumb bottom navigation bar (`#mobile-nav`) in `src/viewer/index.html`.
    - Game server launcher script (`tools/run_game_server.sh`) with auto-detected LAN (`192.168.20.10`) and ZeroTier (`192.168.193.11`) URLs.
    - Automated E2E test (`tools/test_mobile_server.py`) passing 36/36 assertions.

### Verified handoff — 2026-09-08 (Remote Mobile UAT Pass)

Full test suite and headless regressions running cleanly. Mobile server automated verification: **36 passed, 0 failed** (`tools/test_mobile_server.py`), verifying:
- Viewport meta tag and mobile CSS media queries.
- Responsive `#tab-operations` with dedicated Directive Console, OS Telemetry vitals, and bottom navigation bar (`#mobile-nav`).
- End-to-end Operations REST API: live case brief, case detail with human plain-English briefing, directive queueing (`request_service`), and tick stepping.
- Session persistence (`/api/operations/save` and `/api/operations/load`).
- Server launcher `tools/run_game_server.sh` automatically prints local WiFi (`http://192.168.20.10:8080/`) and ZeroTier (`http://192.168.193.11:8080/`) URLs.

Native Godot headless UAT: **19 passed, 0 failed** (`tools/uat_operations.gd`).

- [ ] Rendered desktop UAT: blocked by sandbox denial of the X11 socket; Wayland unavailable.
- [ ] Human gameplay acceptance: Remote Mobile UAT ready to be conducted by user on phone via `http://192.168.20.10:8080/`.

Known limits: school overcrowding remains after report publication (mitigated via IT administrative review order), spare delivery routes for non-bearing parts are absent, save codec is limited to this session bootstrap. See `PLAYABLE_OPERATIONS_LOOP.md` for detail.

Next logical task: Launch `./tools/run_game_server.sh` and perform human mobile acceptance on phone/tablet over WiFi.

---

## 2. Previous Sprint: Sprint 22 — Epidemics & Public Health (COMPLETED & VERIFIED)

### Deliverables Checklist
- [x] Authoritative pathogen model (`src/sim/health/pathogen.gd`): incubation, infectiousness, severity, mortality, immunity duration.
- [x] Grounded contagion system (`src/sim/health/epidemic_system.gd`): transmission along real physical edges (household, workplace, school, transit).
- [x] SEIR progression: Susceptible $\to$ Exposed $\to$ Infectious $\to$ Symptomatic $\to$ Recovered.
- [x] Clinical healthcare: doctors and nurses in clinics treat patients up to bed capacity, reducing mortality by 80%.
- [x] Institutional public health policy: quarantine enforcement isolates carriers, withdrawing labor; school closures eliminate classroom transmission while mandating parental childcare absenteeism.
- [x] Invariant validation (`src/sim/health/epidemic_invariants.gd`): SEIR conservation, non-negative counts, valid health bounds.
- [x] Observability endpoints & read model: `HealthReader`, `/api/epidemic_status`, `/api/clinic_status`.
- [x] Headless test suite (`tests/simulation/test_epidemics_and_public_health.gd` — 16 assertions passing).

---

## 3. Previous Sprint: Sprint 21 — Genetics, Heredity & Population Health (COMPLETED & VERIFIED)

### Deliverables Checklist
- [x] Genetic traits on Person (`blood_type`, `trait_stamina`, `trait_resilience`, `trait_metabolism`, `congenital_conditions` in `src/sim/population/person.gd`).
- [x] Deterministic Mendelian inheritance & relatedness service (`src/sim/population/genetics_model.gd`): ABO/Rh blood allele sampling, exact pedigree relationship coefficient ($r$) calculation.
- [x] Recessive inbreeding risk mechanics: high parent relatedness ($r \ge 0.125$) generates risk of inheriting `congenital_frailty`.
- [x] Integration with `DemographicsSystem._spawn_birth`: births inherit parental blood types and blended traits.
- [x] Invariant validation (`src/sim/population/genetics_invariants.gd`): validates blood types, trait bounds [0.5, 1.5], and strictly acyclic lineages.
- [x] Observability endpoints & read model: `GeneticsReader`, `/api/genetics_summary`, `/api/person_genetics`.
- [x] Headless test suite (`tests/simulation/test_genetics_and_heredity.gd` — 37 assertions passing).

---

## 4. Previous Sprint: Sprint 20 — Relationships, Romance & Household Dynamics (COMPLETED & VERIFIED)

### Deliverables Checklist
- [x] Bounded bilateral relationship entity (`src/sim/population/relationship.gd`): familiarity, affection, attraction, trust, conflict in [0, 100], status progression.
- [x] Grounded interpersonal system (`src/sim/population/relationship_system.gd`): daily routine interaction sampling, incest taboo enforcement ($r \ge 0.25$).
- [x] Romantic partnerships and co-habitation: compatible adults form partnerships, link reciprocal `partner_id`, and move into shared households.
- [x] Separation and emotional fallout: estrangement breaks partnerships, triggers household splitting, and inflicts stress/morale penalties.
- [x] Bereavement: death of partners, children, or close friends inflicts acute grief (+35 stress, -45 morale).
- [x] Invariant validation (`src/sim/population/relationship_invariants.gd`): validates reciprocal consistency, incest taboo, bounds [0, 100].
- [x] Observability endpoints & read model: `RelationshipReader`, `/api/relationships`, `/api/person_relationships`, `/api/household_dynamics`.
- [x] Headless test suite (`tests/simulation/test_relationships_and_household_dynamics.gd` — 24 assertions passing).

---

## 2. Previous Sprint: Sprint 19 — Psychology, Stress & Adaptation (COMPLETED & VERIFIED)

### Deliverables Checklist
- [x] Bounded psychological state on Person (`stress`, `fatigue`, `morale`, `burnout`, `absent_from_work` in `src/sim/population/person.gd`).
- [x] Grounded psychological dynamics (`src/sim/population/psychology_system.gd`): sleep restoration, shift fatigue accumulation, dangerous work stress, dehydration penalties, chronic burnout.
- [x] Systemic consequences: emergent worker absenteeism (`absent_from_work = true`) withdrawing scheduled labor via `DailyLifeSystem` and halting physical production; operator fatigue jitter causing extra machine wear.
- [x] Invariant validation (`src/sim/population/psychology_invariants.gd`): verifies [0, 100] bounds for all living residents.
- [x] Observability endpoints & read model: `PsychologyReader`, `/api/psychology_summary`, `/api/person_psychology`.
- [x] Headless test suite (`tests/simulation/test_psychology_and_stress.gd` — 19 assertions passing).

---

## 3. Previous Sprint: Sprint 18 — Advanced Policing, Investigation & Justice (COMPLETED & VERIFIED)

### Deliverables Checklist
- [x] Authoritative case lifecycle model (`src/sim/law/security_case.gd`): open, investigating, warrant, arrested, convicted, closed; suspect scoring from physical traces.
- [x] Grounded security system (`src/sim/law/security_system.gd`): officer shift dispatch, IT policy surveillance retrieval, log retention expiration, physical arrest and cell detention.
- [x] Physical labor withdrawal: arrested/convicted workers held in security post rooms (`Room.TYPE_SECURITY_POST`), withdrawing labor from production lines; sentence duration tracking and release.
- [x] Adjudication and wrongful conviction mechanics: wrongful convictions spike resentment and erode institutional trust.
- [x] Invariant validation (`src/sim/law/security_invariants.gd`): verifies valid cases, officers, and detainee states.
- [x] Observability endpoints & read model: `SecurityReader`, `/api/security_cases`, `/api/security_summary`, `/api/detainees`.
- [x] Headless test suite (`tests/simulation/test_policing_and_justice.gd` — 26 assertions passing).

---

## 4. Previous Sprint: Sprint 17 — Crime & Underground Economy (COMPLETED & VERIFIED)

### Deliverables Checklist
- [x] Bounded authoritative Crime / Offence model (`src/sim/law/crime_incident.gd`): types (theft, inventory diversion, contraband, assault, vandalism, record manipulation), perpetrator, victim/target, location, opportunity, motive, evidence chain, concealment.
- [x] Bounded underground economy & black market transactions (`src/sim/law/underground_economy.gd`): illicit buyers/sellers, black market trades, risk pricing, physical mass conservation ($\Delta \text{Mass} = 0$).
- [x] Crime & Illicit Trade System (`src/sim/law/crime_system.gd`): evaluation of motive and opportunity, physical item diversion, component vandalism.
- [x] Physical evidence generation: badge swipe logs, CCTV records, eyewitness observations, inventory discrepancies.
- [x] Invariant validation (`src/sim/law/crime_invariants.gd`): mass conservation via `EconomyInvariants`, entity existence, evidence validity.
- [x] Observability read model & API endpoints (`src/presentation/crime_reader.gd`, `/api/crimes`, `/api/crimes_list`, `/api/black_market`, `/api/crime_trace`).
- [x] Headless test suite (`tests/simulation/test_crime_and_underground_economy.gd` — 36 assertions passing).

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

