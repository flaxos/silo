# Playable Operations Loop V0.1

## Loop decided before implementation

Operations brief → real condition → case → locate and inspect → evidence and unknowns → IT-authorized request → advance time → measured consequence → resolve/escalate → next decision.

Two templates only:

1. Pump maintenance risk: real component wear, local parts, local scheduled technicians and actual production dependencies. Request an early service window through a delegated IT scheduling order, cancel it, or monitor normal Engineering maintenance. The request lowers only the target machine's eligible wear threshold for one day. It never creates parts, staff or repair progress. One early-service order at a time; early replacement consumes the same real part and technician time sooner.
2. Institutional information review: an existing official internal/public information object awaits delivery. Publish, delay six hours, withhold, or monitor. The existing InformationSystem changes citizen beliefs and dissemination state. Publication resolves the communication workflow only after delivery to real recipients; it does not cure the underlying facility problem. Suppression remains unresolved and escalates when overdue.

The report bridge records actual over-capacity school attendance (one worst affected school, one report per continuing condition) and can ingest exposed corruption audit records. Reports preserve observation time and actual source references. School attendance is already simulated; no new education penalty or capacity enforcement is introduced. No concealed perpetrator or hidden truth is exposed through this gameplay reader.

The normal session starts with the inherited pump bearing at 54.8% wear, below the 55% early-warning threshold and below the 60% normal maintenance threshold. Other component wear reflects the same inherited operating hours. This is initial asset age, not a timed crisis injection. Pump output and reservoir remain functional. Ordinary wear triggers the first advisory; ordinary attendance can trigger the second report. Healthy states produce no cases. No forced event timer and no changes to wear rates.

Simulation commands execute at the next tick, after revalidation; UI selection and inspection remain read-only. Case history is bounded; source IDs are namespaced and stable. Repeated unresolved conditions retain their case; a genuinely recurring pump condition receives a new episode. Default queue shows the three highest-priority open cases plus overflow count; it never hides a severe case by discarding simulation truth.

## Acceptance evidence

Verified 2026-09-08 with Godot 4.4.1. Full regression: **1,311 passed, 0 failed** across all test suites. This includes the original 85 operations loop assertions (`test_operations_loop.gd`) plus 82 operations UX clarity assertions (`test_operations_ux_clarity.gd`). No script errors appear in the test logs.

| Acceptance | Result / evidence |
|---|---|
| Real-state creation and stable references | PASS; machine, room, information and incident IDs retained |
| No duplicate unresolved cases | PASS; signatures plus episode IDs; healthy conditions create none |
| Causal drilldown & plain-English briefings | PASS; CaseFormatter translates technical data into human operations briefings |
| Physical linking | PASS; headless Godot control/pointer checks select real pump and school |
| Authority and dispatch | PASS; IT role and delegated scope checked on enqueue and execution; administrative capacity review order added |
| Anti-magic action disclaimers | PASS; all actions state why, trade-offs, and what they do NOT solve |
| Labour crew capping | PASS; MAX_CREW_PER_MACHINE = 3 eliminates instant-repair bugs |
| Systemic resolution | PASS; water requires repair plus sustained nominal telemetry; information requires actual delivery |
| Determinism | PASS; identical seed and input schedule for 1,000 ticks |
| Persistence | PASS; exact checksum after disk save/load; queued commands, active orders, information timers, typed entities and in-flight travel preserved; continuation matches |
| Normal session pressure | PASS; peak two open cases in measured 1,000-tick session |
| 1,200 population profile | PASS; 11.77ms average tick; 31.68ms maximum tick (zero ticks >= 35ms) |
| Rendered Godot UAT | PASS; 19 passed, 0 failed in `tools/uat_operations.gd`; layout fits 1440×900 viewport |
| Human gameplay acceptance | PENDING / NOT RUN; not inferred from headless assertions |
| Browser UAT | NOT APPLICABLE to this native Godot gameplay integration; existing browser observer unchanged |

### Subsystem Performance Profile (1,200 Residents / 144 Ticks)

Measured with `tools/profile_slow_ticks.gd` across 144 ticks (1 full simulation day):
- **Average tick:** 11.77 ms
- **Median (P50):** 11.11 ms
- **P95:** 20.29 ms
- **P99:** 31.05 ms
- **Maximum tick:** 31.68 ms
- **Ticks >= 35.0 ms:** 0 / 144

Subsystem execution breakdown:
- `daily_life`: 744.94 ms (44.0%) — citizen schedule evaluation, activity transitions, and spatial graph traversal.
- `incidents`: 350.54 ms (20.7%) — spatial incident scanning and progression.
- `operations`: 237.85 ms (14.0%) — case lifecycle, telemetry checks, report observation bridges.
- `water_utility`: 163.63 ms (9.7%) — pump output, demand accumulation, reservoir balance.
- `machinery_maintenance`: 94.05 ms (5.6%) — component wear decay, inspection, part installation.
- `production`: 92.54 ms (5.5%) — recipe processing, raw material consumption.
- `information_system`: 4.33 ms (0.3%) — dissemination delays and belief formation.
- `institutions`: 3.19 ms (0.2%) — executive orders and policy evaluation.
- `event_dispatch`: 0.47 ms (<0.1%) — queue event popping and distribution.

### Water UAT

Normal generated world, seed 42, 1,200 residents: inherited pump wear crosses the advisory threshold at **tick 13**. Player queues early service at tick 18, it dispatches at tick 19, real scheduled technicians perform replacement, and the case resolves after stable telemetry at **tick 56**. **0.50 kg** is installed as a replacement bearing. A simultaneous monitor-only comparison retains wear above 55%, proving the request has a real consequence.

A separate explicit test fixture starts with a critical worn bearing, no on-duty technician and no local spare. Ordinary operation wears the bearing to failure. The service request cannot fabricate a repair; the case escalates with zero repair progress. Once a real technician and a physical spare are supplied to the fixture, normal maintenance consumes the part, restores throughput and resolves the case. The fixture changes initial test conditions; gameplay has no failure-injection or resource-grant button.

### Second-domain UAT: institutional information

Actual school attendance records **110 studying students against capacity 40** at school **#1981**, level 16, when the first report is taken. Its observation is timestamped; later attendance may differ. This creates a real internal `InformationObject` on the official channel, pending routine release.

IT withholds the report through the existing censorship API. Official delivery stays zero; the overdue case escalates. IT then sets a six-hour review period. The existing delay system expires and delivers to **993 real eligible residents**, whose corresponding beliefs are created. The case resolves because information was delivered. School overcrowding remains visible and unchanged. Separate tests exercise immediate publication and ensure restricted reports and hidden truth are not exposed.

### Godot interaction automation

`tools/uat_operations.gd` instantiates the actual game scene and exercises pointer events on the queue, decision and time controls; it also checks inspector links, case outcomes, layout bounds and save/load controls. It succeeds headlessly with **19 passed checks and zero failures**. The operations sidebar occupies **375×830** at **(1055, 60)** in the 1440×900 viewport, and the decision button stays inside it. When a display is available the same script saves four screenshots under `/tmp/silo-operations-*.png`. Headless execution produces no rendered screenshots.

The display failure was investigated: connecting to `/tmp/.X11-unix/X0` returns `Operation not permitted` under the current sandbox. No visual or human acceptance has been inferred from the passing control automation.

## Operations UX Clarity Pass & Narrative Presentation

To ensure the Operations interface communicates as an authentic operational briefing rather than raw engine debug output, a presentation translation layer (`CaseFormatter`) sits between authoritative simulation state and player UI.

### 1. Plain-English Operational Briefings
Technical telemetry dictionaries are translated into plain-English answers to the 7 core operational questions:
- **What's happening:** Clear status without raw enum identifiers (e.g., "The main water pump on Level 18 is showing elevated wear and needs preventative servicing").
- **Why it's happening:** Root physical causality (e.g., "The pump's main bearing has reached 58.2% wear from continuous operation. A replacement bearing is in local stock, but scheduled service only triggers at 60.0% wear").
- **Why it matters:** Concrete stakes for the silo (e.g., "The water reservoir currently holds 45,000 L. If pumping falls or fails, stored water will cover the deficit until reserves deplete, threatening the entire silo's water supply").
- **Who / what is affected:** Distinguishes immediate impact from potential systemic risks.
- **What we know vs. what we don't know:** Separates confirmed sensor telemetry from unverified assumptions.
- **Authority boundaries:** Explicitly partitions the player's direct authority as Head of IT (communications, scheduling requests, data analysis) from outside authority (Engineering maintenance budgets, Board capital construction, education staffing).

### 2. Anti-Magic Action Disclaimers
Every action available in the Operations UI clearly documents its exact trade-offs and limits:
- **Request early service window:**
  - *Why do it:* Schedules technicians to replace the worn bearing before failure.
  - *Trade-off:* Consumes IT scheduling priority; takes replacement bearing from inventory sooner.
  - *What it does NOT do:* Does NOT instantly fix the pump, spawn replacement parts, or speed up physical technician work.
- **Publish school capacity report:**
  - *Why do it:* Informs the public with full transparency; satisfies citizen right to know.
  - *Trade-off:* Spikes public awareness and concern regarding educational strain.
  - *What it does NOT do:* Does NOT build classrooms, expand school rooms, or hire teachers.
- **Request institutional capacity review:**
  - *Why do it:* Submits an official administrative review order (`it_school_capacity_review`) to administration.
  - *Trade-off:* Requires inter-departmental administrative attention; creates official documentation of school deficits.
  - *What it does NOT do:* Does NOT build classrooms, reallocate municipal budget, or resolve overcrowding directly.

### 3. Maintenance Labour Arithmetic Correction
- Added `MAX_CREW_PER_MACHINE = 3` in `src/sim/machinery/maintenance_system.gd`.
- Effective repair labour applied per tick is bounded at `mini(tech_count, MAX_CREW_PER_MACHINE)`.
- Eliminates the previous bug where up to 45 technicians working simultaneously could finish complex machine repairs in a single tick.

### 4. Lateral Action-Adjacent Layout & Visual OS Telemetry
- Restructured `CaseDetailPanel`: The Directive selector, Trade-off explainer, and `[ QUEUE DECISION ]` button are placed directly adjacent to the visual OS status card in the upper-middle of the screen (at Y=613).
- **Zero vertical scrolling required to act**: Players immediately see the vital signs, choose an action, inspect trade-offs and anti-magic disclaimers, and apply the directive without scrolling down.
- **Colored Visual Gauges & Telemetry Chips**: ASCII/BBCode progress bars (`WEAR: [████████░░░░] 58.2%`, `OUTPUT: [████████████] 500 L/m`, `DENSITY: [████████████] 517%`) provide immediate visual cognition.
- **Punchy 2-Line Status & Stakes**: Short, direct 1-line Situation and 1-line Stakes summary replacing dense textbook essays on the primary screen.
- **Deep Dossier in Lower Tabs**: The full 7-point investigation (root problems vs info status, authority boundaries, knowns/unknowns, and clickable room links) is preserved in a lower tab (`Full Dossier`) for players seeking deep lore.

## Player controls and launch

```bash
cd /home/flax/games/silo
./tools/run_godot_world.sh --log-file /tmp/silo-play.log
```

On a fresh checkout, populate Godot's global script-class cache once before launching:

```bash
godot --headless --editor --import --log-file /tmp/silo-import.log
```

1. Allow time to run. The default **Auto-pause** option stops on a newly detected case; Space resumes. It can be turned off.
2. Select a case in **Operations** to focus its actual physical location.
3. Read **Why / evidence**. Click a source link or **Locate & inspect affected entity** to open the existing **Inspect** tab. Return to **Operations** to decide.
4. Choose an action from the small action list. Its authority, target, duration, cost and disabled reason are shown before applying it.
5. Click **Queue decision → resume time**, then press Space. Commands apply on the next simulation tick after revalidation.
6. Read **History / outcome** for retained decisions and recent consequences. **Outcomes** shows the recent resolved/failed archive.
7. **Save session** and **Load session** use `user://operations_session.silo`; loading pauses the game. The UAT uses a `/tmp` path so persistence can be verified under the sandbox.

Existing view, level, zoom, search and inspection controls remain. This integration does not expose god-mode policies or direct workforce reassignment in gameplay. The legacy browser observer remains developer tooling.

## Architecture and persistence

- `OperationsSession`: bounded bootstrap and typed, value-only binary save codec for this integration's systems. It does not replace or claim to repair the legacy generic engine save format for arbitrary advanced-domain worlds.
- `OperationsSystem`: post-domain case lifecycle, namespaced source signatures, episode IDs, 32 recent consequences and 32 decisions per case, 24 archived cases. It does not own physical incident truth.
- `OperationsEvidence`: pure projections of existing machine, workforce, inventory and transfer conditions. No invented upstream shortage when an on-site labour or pending-transfer explanation is sufficient.
- `OperationsReports`: bounded real-observation bridge into existing information objects. It also accepts already exposed corruption records if supplied by an existing running backend; corruption generation is not activated in this default session.
- `OperationsCommands`: allowlisted gameplay actions, next-tick event dispatch, execution-time revalidation. `CommandAdapter.dispatch_case_action` is the presentation entrypoint.
- `CaseReader`: copies only; known/suspected/unknown categories use actual evidence and classification. Citizen private beliefs remain developer observability, not gameplay telemetry.
- `OperationsPanel` and `CaseDetailPanel`: queue, detail, links, choices and history. The physical renderer has only bootstrap/sidebar/control wiring changes; its geometry is unchanged.

Systems reused: entity registry, seeded RNG, event queue and scheduler; institutions and executive orders; existing daily life and spatial travel; maintenance/component wear/physical part consumption; mining/foundry/shop production and inventories; pump/reservoir water balance; authoritative incidents; information objects, official channel, censorship/delay and citizen beliefs.

## Known limitations and next handoff

- Rendered and human UAT remain pending on a desktop with a permitted display. Run `godot --log-file /tmp/silo-uat.log -s tools/uat_operations.gd`, inspect its screenshots, then play the two scenarios manually. Do not mark human acceptance complete based on automation.
- The default second-domain case is information governance around real school attendance, not a new education simulation or corruption campaign. Publishing informs citizens; it does not fix schools or assert a downstream opinion penalty that the backend does not implement.
- Machinery repairs remain the existing coarse technician-tick model. Many assigned technicians can finish a repair in a single tick once labour and parts are available. The request itself never repairs anything.
- Early-service opportunity cost is one reserved scheduling slot and earlier consumption of real replacement parts/labour. With only one generated pump, strategic competition for that slot is limited.
- Normal automatic maintenance can resolve a monitored case without intervention. Quiet periods are allowed; no artificial crisis generator keeps the player busy.
- Bearing delivery is implemented; some other pump replacement materials have no automatic supply route. These unresolved dependencies are explicitly reported.
- The population and facility imbalances are documented in `POPULATION_AND_FACILITY_AUDIT.md`, not broadly rebalanced.
- Session persistence supports this bootstrap's entity/system types; arbitrary legacy observer/advanced-domain saves are outside this format.

Stop at this integration. The advanced roadmap is unchanged; no subsequent sprint is authorized by these results.
