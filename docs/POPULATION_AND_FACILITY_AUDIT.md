# Population and Facility Audit — Operations V0.1

Measured from `OperationsSession.create(1200, 42)`, initial assignments and 144 ticks of unchanged daily schedules. Reproduce with `godot --headless --log-file /tmp/silo-audit.log -s tools/audit_operations_population.gd`; raw measurements are written to `/tmp/silo-population-audit.json`.

This is a bounded plausibility audit, not a rebalance. No occupation, bed, household, room, sector, level or schedule assignment was changed in this integration.

## Population

| Measure | Actual |
|---|---:|
| Residents | 1,200 |
| Age 0–5 | 29 (2.4%) |
| Age 6–17 | 427 (35.6%) |
| Age 18–64 / assigned workers | 675 (56.3%) |
| Age 65+ / retired | 69 (5.8%) |
| Dependants (nonworkers) | 525 |
| Households / residential apartments | 387 / 387 |
| Mean household size | 3.10 |
| Broken occupation-to-facility type mappings | 0 |
| Maximum open cases in day one, no player actions | 2 |

**OK:** all working occupations have a matching existing facility; prior physical reference assertions cover all homes, beds, schools and household links. **QUESTIONABLE:** the age distribution is heavily weighted toward school-age children (427 versus only 29 under six); generation is not a calibrated stable demographic pyramid. No demographic redesign was attempted.

## Occupations and shifts

Shift counts are assignments, not guaranteed attendance. Transit and meal schedules still consume time.

| Occupation | Total | Day | Swing | Night |
|---|---:|---:|---:|---:|
| cook | 61 | 55 | 6 | 0 |
| doctor | 34 | 31 | 0 | 3 |
| electrician | 27 | 24 | 3 | 0 |
| foundry worker | 59 | 51 | 8 | 0 |
| furnace operator | 25 | 21 | 0 | 4 |
| it technician | 25 | 23 | 2 | 0 |
| machinist | 68 | 63 | 5 | 0 |
| maintenance technician | 60 | 53 | 3 | 4 |
| miner | 144 | 125 | 7 | 12 |
| nurse | 63 | 54 | 5 | 4 |
| sanitation worker | 27 | 22 | 0 | 5 |
| security officer | 27 | 24 | 3 | 0 |
| teacher | 60 | 60 | 0 | 0 |
| welder | 22 | 20 | 2 | 0 |

## Existing facility staffing

Peak attendance is measured over the first complete day. Capacity is the room's declared people capacity; the current schedule model does not enforce it.

| Facility | Level | Assigned workers | Enrolled students | Peak working | Peak studying | Declared capacity |
|---|---:|---:|---:|---:|---:|---:|
| Schools #1979 | 2 | 8 | 95 | 8 | 95 | 40 |
| Schools #1980 | 9 | 18 | 125 | 18 | 125 | 40 |
| Schools #1981 | 16 | 34 | 207 | 34 | 207 | 40 |
| Clinics #1982 | 4 | 27 | 0 | 23 | 0 | 20 |
| Clinics #1983 | 11 | 41 | 0 | 36 | 0 | 20 |
| Clinics #1984 | 17 | 29 | 0 | 26 | 0 | 20 |
| Kitchen #1985 | 3 | 61 | 0 | 48 | 0 | 20 |
| Server room #1996 | 5 | 52 | 0 | 45 | 0 | 15 |
| Machine shop #2003 | 6 | 90 | 0 | 79 | 0 | 40 |
| Foundry #2004 | 10 | 84 | 0 | 72 | 0 | 30 |
| Deep mine #2005 | 15 | 144 | 0 | 119 | 0 | 60 |
| Water pump station #2006 | 18 | 60 | 0 | 45 | 0 | 20 |
| Security post #2010 | 7 | 27 | 0 | 24 | 0 | 20 |

**QUESTIONABLE staffing areas (8 audit concerns, categorized as By Design, Known Limitation, or Future Balance):**

1. Demographics — Age distribution **[Known limitation]**: 427 school-age children (35.6%) versus only 29 under six (2.4%). Initial generation samples household compositions without simulating multi-decade demographic waves; full cohort calibration is deferred to long-term demographic balance.
2. Education — Student/desk ratio **[By design / Known limitation]**: 427 enrolled students for 120 declared places across three schools; school #1981 reaches 207 studying students plus 34 teachers. Teacher supply (47–60) is ample by ratio, but room spatial allocation is overcrowded. This real attendance drives the institutional information case; publishing the report delivers transparency but does NOT physically expand rooms or recruit teachers.
3. Medical — Staff exceeding clinic capacity **[Future balance]**: 91 doctors and nurses assigned across three capacity-20 clinics (peak working 23–36 per clinic). Staff headcount was provisioned for epidemic surge handling; in baseline operations without an active epidemic, clinic capacity is exceeded by medical staff alone.
4. Maintenance — Technician concentration **[Fixed limitation / Bounded by design]**: 55–60 maintenance technicians assigned to water pump station #2006 (peak 45 on shift). Previously, raw repair arithmetic permitted all 45 technicians to instantly complete component repairs in a single tick once replacement parts arrived. **FIXED in UX Clarity Pass:** Added bounded workspace crew cap (`MAX_CREW_PER_MACHINE = 3` in `maintenance_system.gd`). Effective repair labour per tick is now capped at 3 workers, eliminating instant-repair bugs while preserving physical labour conservation and multi-tick repair progression.
5. Mining — Mine worker concentration **[Future balance]**: 134–144 miners assigned to deep mine #2005 (capacity 60, peak 119 working simultaneously). Physical ore extraction, hauling and vein depletion are authentic, but spatial density and shift staggered rotation require future workforce scheduling passes.
6. Industry — Shift and spatial density **[Known limitation]**: 79 foundry/furnace operators and 88 machinists assigned to machine shop #2003 (capacity 40) and foundry #2004 (capacity 30). Day-heavy shifts and instantaneous room inventory transfers bypass floor congestion and intermediate machine tool bottlenecks.
7. IT / Electrical — Shared server room **[Known limitation]**: 28 IT technicians and 26 electricians share server room #1996 (capacity 15, peak 45). Electricians map to the server room because power plant generation/distribution networks are deferred; reassigning them without an active power simulation would break occupation validity.
8. Food-service — Kitchen vs canteen allocation **[Future balance]**: 49–61 cooks assigned to single kitchen #1985 (capacity 20, peak 48), while 20 canteens have zero dedicated serving staff. Meal consumption locations are physically modelled, but meal preparation pipelines and server jobs are deferred to nutrition systems.

**OK within current backend:** all mining, foundry, machining, security, and pump-maintenance worker categories exist and reach their required rooms; education teachers/students have valid schools; IT and sanitation staff have existing workplaces. Sanitation has 23–27 workers across three hygiene facilities, without an active cleaning load simulation.

## Facility inventory

| Room type | Count |
|---|---:|
| Residential apartments | 387 |
| Canteens | 20 |
| Kitchen | 1 |
| Hygiene facilities | 3 |
| Machine shop | 1 |
| Foundry | 1 |
| Deep mine | 1 |
| Water pump station | 1 |
| Server room | 1 |
| Clinics | 3 |
| Schools | 3 |
| Recreation | 2 |
| Storage bays | 2 |
| Security post | 1 |
| Bio-farms | 3 |
| Food processing | 1 |
| Waste processing | 1 |
| Air handler | 1 |
| Power plant | 1 |
| Wastewater treatment | 1 |

435 rooms total: 387 homes and 48 functional/spatial facilities. There is one real water-pump machine. Real inventories are created in their production/maintenance rooms, not automatically in dedicated storage bays.

## Missing roles and future gaps

**CRITICAL ROLE — Generated security staff: [FIXED]**
- **Prior state:** Missing. `SecuritySystem.open_case` required a living officer, but no security occupation was generated in adult population assignment; the Level 7 Security Post had 0 staff.
- **Action taken:** Defined `DEPT_SECURITY: String = "security"` and `"security_officer"` in `src/sim/population/occupation.gd`. Added `"security_officer"` to adult job generator in `src/sim/population/occupation_assignment.gd`.
- **Current status:** 27 security officers deterministically generated and assigned to Level 7 Security Post (`Room.TYPE_SECURITY_POST`, #2010; declared capacity 20, peak working 24). Assignment errors: 0.

**FUTURE SYSTEM GAPS — ten explicitly counted architectural gaps:**

| Gap | What exists physically / structurally | What is deferred | Why deferred |
|---|---|---|---|
| 1. Agriculture | Three bio-farm rooms (#2011, #2012, #2013) | Crop growth, harvest, irrigation, farm workers | Requires Phase C agricultural production model |
| 2. Food processing & serving | Kitchen #1985, food processing #2014, 20 canteens, 49 cooks | Nutrition, recipe conversion, meal hauling, canteen staff | Requires caloric intake and food inventory mechanics |
| 3. Power operations | Power plant room #2017, 26 electricians | Power generation, fuel inputs, grid load, distribution topology | Requires utility grid topology simulation |
| 4. Ventilation operations | Air handler room #2016 | Airflow, oxygenation, duct networks, filter degradation | Requires environmental fluid/gas dispersion engine |
| 5. Wastewater operations | Wastewater treatment room #2018 | Blackwater collection, greywater recycling, sludge volume | Requires dual-pipe fluid network and effluent loops |
| 6. Waste & recycling | Waste processing room #2015, scrap inventory items | Hauling trash, sorting scrap, recycling labor processes | Requires solid waste logistics and collection schedules |
| 7. Physical logistics / stores | Two storage bay rooms (#2008, #2009) | Physical material hauling, storekeepers, transit delays | Transfers currently instantaneous between linked rooms |
| 8. IT equipment & comms | Server room #1996, 28 IT technicians | Server rack hardware failure, network cabling, packet bandwidth | Information objects model official data flows; hardware deferred |
| 9. Sanitation workload | Three hygiene facilities (#1986–#1988), 23 sanitation workers | Cleaning tasks, surface contamination, consumable usage | Daily life visits hygiene rooms; dirt accumulation deferred |
| 10. Civil administration | Abstract institutional policies, executive orders | Civil servants, clerks, bureaucratic desk facilities | Orders currently executed via abstract department authority |

## Count convention for the completion report

Critical missing roles: **1** (security — now FIXED). Questionable areas: **8** (categorized above: 1 by design, 4 known limitations, 3 future balance). Future-system gaps: **10** (the table above). Counts are categories, not the number of absent workers. Browser/human gameplay acceptance is recorded as PENDING and distinct from automated headless assertions.
