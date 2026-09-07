# GAME_PILLARS.md — Core Pillars and Design Principles

## 1. Product Thesis

SILO is a deterministic simulation of a long-lived underground human civilisation.

```
Civilisation simulation first.
Management game second.
Narrative game third.
```

- **Inherited Habitat**: The player inherits a living, functioning, weathered underground habitat with ~1,200 persistent residents rather than building a colony from raw ground.
- **Persistent Entities**: Every person, household, workplace, machine, and component exists in simulation memory. There is no aggregate scalar `Population = 1200` without 1,200 distinct person records.
- **Original Universe**: SILO does not copy names, characters, visual designs, terminology, lore, or story events from existing fiction. It is an original, grounded simulation of closed-loop underground industrial society.

---

## 2. Core Design Principle: Simulation Truth

Almost every gameplay outcome must emerge naturally from simulation state dynamics.

### Preferred Causal Flow
```
SIMULATION STATE
       ↓
SYSTEMIC CONSEQUENCE
       ↓
PLAYER INFORMATION
       ↓
PLAYER ACTION
       ↓
NEW SIMULATION STATE
       ↓
OPTIONAL NARRATIVE INTERPRETATION
```

### Prohibited Antipattern
```
SCRIPTED RANDOM EVENT (e.g. "Event_WaterCrisis")
       ↓
ARBITRARY STAT PENALTY (e.g. water -= 30, morale -= 10)
       ↓
FAKE ILLUSION OF CONSEQUENCE
```

### Reference Example: Water Crisis Causality
A water crisis in SILO occurs because:
1. Deep-well pump experiences mechanical wear on its primary bearing.
2. Required replacement bearing is absent from Stores inventory.
3. Machine shop lacks cylindrical steel stock to fabricate a replacement.
4. Smelting furnace output is reduced due to refractory degradation.
5. Deep ore mine extraction is understaffed due to illness or reassignment.
6. Maintenance on the pump is delayed past critical failure threshold.
7. Water pumping throughput collapses.
8. Greywater recycling and sanitation levels drop.
9. Gastrointestinal illness spreads across lower-tier housing.
10. Social unrest, absenteeism, and political friction emerge.

---

## 3. Player Role & Fantasy

### Role: Head of Information Systems / IT
The player occupies an executive technical position responsible for the silo's computational, network, automation, telemetry, and identity systems.

### Initial Authority Profile
- **Direct Control**: IT staff, servers, storage arrays, network switches, identity databases, access-control controllers, badge issuance, CCTV routing, system telemetry.
- **Indirect Influence**: Staff scheduling algorithms, maintenance dispatch software, logistics routing systems, education/apprenticeship placement records, surveillance logging.
- **No Direct Authority**: Mining operations, medical decisions, agriculture/hydroponics, security enforcement, industrial quotas. (Influence may grow or shrink through systemic institutional gameplay).

---

## 4. Player Power & Control Layers

The player is NOT a god cursor directing individuals to "walk here", "pick this up", or "repair that". The player exercises institutional power through three distinct layers:

### A. Policies (Structural Rules)
Long-term structural rules that alter how autonomous systems and populations behave:
- Ration allocation priorities
- Apprenticeship and education admission criteria
- Preventive maintenance schedules and component replacement thresholds
- Working hours, shift patterns, and mandatory overtime rules
- Housing tier assignment formulas
- Data retention and surveillance access policies

### B. Executive Orders (Operational Priorities)
Temporary shifts in operational focus with systemic opportunity costs:
- *PRIORITISE PRIMARY WATER SYSTEM RESTORATION*: Causes technicians to be reassigned, spare parts released from reserve, and transport prioritised, while delaying ventilation filter maintenance.

### C. Special Interventions (Coercive & Emergency Actions)
Targeted executive or emergency interventions that solve acute problems while generating friction:
- Overriding electronic door locks or locking down a sector
- Revoking security clearance or badge access for a specific individual
- Reassigning critical server compute power
- Quarantine enforcement or communications blackout
- Disclosing or suppressing sensitive telemetry logs
