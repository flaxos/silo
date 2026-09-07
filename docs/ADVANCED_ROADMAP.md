# SILO — Advanced Simulation & Game Roadmap

**Status:** Post-Sprint 11 planning document  
**Purpose:** Define the advanced roadmap after the core deterministic simulation and observability layer are proven.  
**Primary rule:** Do not implement these sprints merely because they are listed. Each sprint begins only after the prior sprint's acceptance gate passes.

---

# 1. PRODUCT DIRECTION

SILO is a deterministic underground-civilisation simulation in which the player operates through institutional authority rather than direct god-like control.

The advanced roadmap expands the proven simulation into:

- politics, factions, corruption, propaganda and rebellion
- advanced policing and crime
- psychology, relationships, romance, families and genetics
- epidemics and public health
- spatial logistics and advanced pathfinding
- electrical, communications and industrial-control topology
- PLC and automation simulation
- full isometric construction and physical silo growth
- procedural generation
- combat and security operations
- expeditions and the outside world
- endgame conditions
- final art, audio and usability
- modding
- multiplayer

The order matters.

Systems that affect the simulation must be built before presentation systems that visualise them.

The project must continue to obey:

> **Simulation truth → systemic consequence → player information → player action → new simulation truth**

Narrative, UI and presentation may expose or interpret the simulation, but must not become an alternative source of truth.

---

# 2. ADVANCED ROADMAP PRINCIPLES

## 2.1 No feature exists in isolation

Every advanced system must connect to existing simulation domains.

Examples:

- politics depends on actual people, institutions, jobs, households and material outcomes
- crime occurs at actual locations and affects actual inventories or people
- propaganda spreads through real communication channels
- epidemics propagate through real contact patterns
- power failures disable real machines
- network failures affect real control systems
- PLC failures affect real physical infrastructure
- combat removes actual citizens from the labour and family systems
- expeditions consume actual people, equipment and resources

## 2.2 Avoid fake global meters

Avoid standalone values such as:

```text
rebellion = 72
crime = 45
propaganda = 19
romance = 60
```

Prefer derived state.

For example, rebellion risk may emerge from:

- faction membership
- perceived legitimacy
- recent coercive actions
- material deprivation
- social networks
- leadership capability
- security pressure
- communication access
- shared grievances
- opportunity

Global summaries may exist for UI convenience, but they should be derived from underlying entities.

## 2.3 Preserve determinism

All advanced simulation must remain reproducible from:

```text
world state
+ seed
+ player actions
+ elapsed simulation time
```

No subsystem may use uncontrolled randomness.

## 2.4 Protect simulation performance

Every sprint must define:

- entity count affected
- update frequency
- expected computational complexity
- benchmarks
- LOD strategy where relevant

Do not make every resident run expensive AI every tick.

## 2.5 Prefer event-driven simulation

Use schedules, events, cached state, spatial indexes and dependency graphs rather than constant global polling.

## 2.6 Multiplayer is last

Do not alter core architecture for multiplayer until the single-player simulation is mature.

The deterministic architecture should make later multiplayer easier, but multiplayer requirements must not distort earlier design.

---

# 3. PHASE A — POLITICAL SOCIETY

---

# SPRINT 12 — POLITICAL IDENTITY & LEGITIMACY

## Goal

Create the foundation for political behaviour without creating formal factions yet.

Citizens must be capable of forming political attitudes from their actual lived experience.

## Build

Add political perception state to citizens.

Potential dimensions:

- institutional trust
- perceived fairness
- perceived personal security
- economic satisfaction
- class resentment
- confidence in leadership
- confidence in IT
- confidence in Security
- confidence in Engineering
- tolerance for coercion
- preference for stability
- preference for reform
- preference for individual autonomy
- preference for equality
- preference for hierarchy

Do not treat these as arbitrary personality sliders.

They should change through observed or experienced events.

Examples:

- losing a relative in a preventable industrial accident
- receiving better housing
- promotion
- demotion
- detention
- food shortage
- successful crisis response
- surveillance exposure
- corruption discovered
- school placement denied
- family member saved by medical care
- repeated infrastructure reliability

Create:

- opinion-memory inputs
- trust update rules
- institutional legitimacy model
- local/social influence hooks
- derived political summaries

## Acceptance

Run a multi-year deterministic scenario.

Two citizens with different histories should develop measurably different institutional attitudes.

Political state must be traceable to actual events.

The observability console must show:

```text
current attitude
← contributing experiences
← source events
```

## Exclude

- formal factions
- organised rebellion
- propaganda campaigns
- elections
- coups

---

# SPRINT 13 — FACTIONS, MOVEMENTS & SOCIAL NETWORKS

## Goal

Allow political groups to emerge from real relationships, grievances and interests.

## Build

Add:

- faction entity
- membership
- sympathiser state
- leadership
- recruitment
- faction goals
- ideology/profile
- institutional penetration
- social influence
- faction resources where appropriate
- faction communication
- faction cohesion
- faction rivalry
- faction alliances

Faction formation should be conditional.

Potential triggers:

- shared occupation
- shared class position
- family networks
- shared residential area
- shared grievance
- charismatic organiser
- institutional affiliation
- common ideology
- prisoner networks

Do not randomly spawn "The Rebels".

A labour-rights movement might emerge among miners because:

```text
injury rate ↑
+ maintenance quality ↓
+ compensation perceived unfair
+ respected foreman becomes organiser
+ dense work/social network
```

## Social graph

Implement bounded social influence.

Residents should have meaningful ties rather than all-to-all relationships.

Potential edges:

- family
- household
- coworker
- school cohort
- neighbour
- friend
- partner
- institution
- former cellmate
- shared incident

## Acceptance

In a deterministic stress scenario:

1. a coherent grievance emerges;
2. affected citizens become more politically aligned;
3. a movement/faction forms;
4. recruitment follows social connections;
5. citizens outside the relevant network are less affected.

No scripted `spawn_rebel_faction()` event should be required.

---

# SPRINT 14 — CORRUPTION, PATRONAGE & INFORMAL POWER

## Goal

Model the difference between formal authority and actual power.

## Build

Add:

- favours
- patronage
- nepotism
- bribery where the economy supports it
- preferential allocation
- concealed rule-breaking
- misuse of institutional access
- conflicts of interest
- black-market relationships
- protection networks
- whistleblowing
- corruption investigations

People should have incentives.

Examples:

- housing officer favours relatives
- storekeeper diverts scarce goods
- security officer protects a friend
- supervisor manipulates work assignments
- IT administrator alters records
- executive protects a politically useful family

Corruption should interact with:

- access rights
- records
- inventories
- jobs
- housing
- education
- policing
- reputation
- faction relationships

## Acceptance

Create a deterministic scenario where preferential allocation occurs.

The viewer must trace:

```text
actor
→ relationship/incentive
→ illicit action
→ affected resource/person
→ hidden record discrepancy
→ discovery path
→ institutional consequence
```

---

# SPRINT 15 — PROPAGANDA, INFORMATION & CENSORSHIP

## Goal

Turn information into a simulated resource and political weapon.

## Build

Create information objects/events with properties such as:

- source
- truth basis
- certainty
- audience
- distribution channel
- visibility
- censorship state
- credibility
- emotional salience
- institutional classification

Communication channels may include:

- official announcements
- terminals
- messaging
- notice boards
- word of mouth
- workplace meetings
- school
- security briefings
- rumours
- underground networks

Player actions may include:

- publish
- delay
- suppress
- redact
- reframe
- deny
- leak
- target distribution
- shut channels
- alter retention

Do not implement a simple "propaganda effectiveness" roll.

Effect should depend on:

- trust in sender
- recipient experience
- social reinforcement
- competing information
- credibility
- evidence
- faction affiliation

## Acceptance

One event must produce different beliefs across different social networks based on channel access and trust.

The player must be able to suppress information without deleting the underlying simulation truth.

---

# SPRINT 16 — PROTEST, STRIKES, CIVIL DISOBEDIENCE & REBELLION

## Goal

Allow political conflict to become collective action.

## Escalation model

Potential progression:

```text
grievance
→ discussion
→ organisation
→ petition
→ work slowdown
→ strike
→ protest
→ occupation
→ sabotage
→ organised resistance
→ armed rebellion
```

This must not be a mandatory ladder.

Different factions may choose different strategies.

## Build

Add:

- collective-action planning
- participation decisions
- organisers
- demands
- negotiation
- picketing
- strikes
- sabotage
- clandestine cells
- protest locations
- crowd formation
- security response
- defections
- rebellion logistics

Actions require real people.

If 120 miners strike, those 120 miners stop normal work.

That must affect production.

If Security deploys 30 officers, those officers leave other duties.

## Acceptance

A strike must:

- involve identified citizens
- remove their labour
- affect the actual production chain
- generate institutional responses
- modify political attitudes
- potentially spread through social networks
- resolve through actual changes, suppression or collapse

No arbitrary `production -= strike_modifier`.

---

# 4. PHASE B — LAW, CRIME & HUMAN BEHAVIOUR

---

# SPRINT 17 — CRIME & UNDERGROUND ECONOMY

## Goal

Create systemic crime arising from motive, opportunity and social conditions.

## Acceptance

A theft investigation must be traceable from:

```text
missing inventory
→ access opportunity
→ people present
→ records/evidence
→ suspect
→ investigation
→ enforcement outcome
```

---

# SPRINT 18 — ADVANCED POLICING, INVESTIGATION & JUSTICE

## Goal

Make policing an operational institution rather than an event button.

---

# SPRINT 19 — PSYCHOLOGY, STRESS & ADAPTATION

## Goal

Give people persistent internal state without building an impossible full human-mind simulation.

---

# SPRINT 20 — RELATIONSHIPS, ROMANCE & HOUSEHOLD DYNAMICS

## Goal

Make interpersonal life matter to generational and social simulation.

---

# SPRINT 21 — GENETICS, HEREDITY & POPULATION HEALTH

## Goal

Support long-lived closed-population demographic simulation.

---

# SPRINT 22 — EPIDEMICS & PUBLIC HEALTH

## Goal

Make disease spread through real social/spatial contact.

---

# 5. PHASE C — PHYSICAL INFRASTRUCTURE DEPTH

---

# SPRINT 23 — ADVANCED SPATIAL MODEL & PATHFINDING
# SPRINT 24 — MATERIAL LOGISTICS & PHYSICAL TRANSPORT
# SPRINT 25 — ELECTRICAL TOPOLOGY
# SPRINT 26 — DATA NETWORK TOPOLOGY
# SPRINT 27 — PLC, SCADA & AUTOMATION SIMULATION

---

# 6. PHASE D — BUILDING THE PHYSICAL SILO

---

# SPRINT 28 — ISOMETRIC WORLD REPRESENTATION
# SPRINT 29 — FULL CONSTRUCTION SYSTEM
# SPRINT 30 — PROCEDURAL SILO & HISTORY GENERATION

---

# 7. PHASE E — SECURITY CONFLICT & OUTSIDE WORLD

---

# SPRINT 31 — TACTICAL SECURITY OPERATIONS
# SPRINT 32 — COMBAT
# SPRINT 33 — EXPEDITIONS
# SPRINT 34 — OUTSIDE WORLD

---

# 8. PHASE F — ENDGAME & CAMPAIGN STRUCTURE

---

# SPRINT 35 — STRATEGIC OBJECTIVES & ENDGAME
# SPRINT 36 — CAMPAIGN HISTORY & LEGACY

---

# 9. PHASE G — PRODUCTION QUALITY

---

# SPRINT 37 — FINAL UX / INFORMATION DESIGN
# SPRINT 38 — FINAL ART DIRECTION
# SPRINT 39 — AUDIO & MUSIC
# SPRINT 40 — PERFORMANCE, SAVE STABILITY & LONG-RUN HARDENING

---

# 10. PHASE H — EXTENSIBILITY

---

# SPRINT 41 — MODDING FOUNDATION
# SPRINT 42 — MODDING TOOLS & DOCUMENTATION

---

# 11. PHASE I — MULTIPLAYER

---

# SPRINT 43 — MULTIPLAYER DESIGN VALIDATION
# SPRINT 44 — DETERMINISTIC COMMAND REPLICATION
# SPRINT 45 — CO-OP GAMEPLAY

---

# 12. ROADMAP SUMMARY TABLE

| Sprint | System | Phase |
|---:|---|---|
| 12 | Political identity & legitimacy | Phase A: Political Society |
| 13 | Factions & social networks | Phase A: Political Society |
| 14 | Corruption & patronage | Phase A: Political Society |
| 15 | Propaganda & information | Phase A: Political Society |
| 16 | Protest, strikes & rebellion | Phase A: Political Society |
| 17 | Crime & underground economy | Phase B: Law & Crime |
| 18 | Advanced policing & justice | Phase B: Law & Crime |
| 19 | Psychology | Phase B: Human Behaviour |
| 20 | Relationships & romance | Phase B: Human Behaviour |
| 21 | Genetics & heredity | Phase B: Human Behaviour |
| 22 | Epidemics & public health | Phase B: Human Behaviour |
| 23 | Advanced spatial model/pathfinding | Phase C: Physical Infrastructure |
| 24 | Physical logistics | Phase C: Physical Infrastructure |
| 25 | Electrical topology | Phase C: Physical Infrastructure |
| 26 | Data network topology | Phase C: Physical Infrastructure |
| 27 | PLC/SCADA/automation | Phase C: Physical Infrastructure |
| 28 | Isometric world representation | Phase D: Physical Silo |
| 29 | Full construction | Phase D: Physical Silo |
| 30 | Procedural silo/history generation | Phase D: Physical Silo |
| 31 | Tactical security | Phase E: Security & Conflict |
| 32 | Combat | Phase E: Security & Conflict |
| 33 | Expeditions | Phase E: Outside World |
| 34 | Outside world | Phase E: Outside World |
| 35 | Endgame | Phase F: Endgame & Campaign |
| 36 | Campaign history/legacy | Phase F: Endgame & Campaign |
| 37 | Final UX | Phase G: Production Quality |
| 38 | Final art | Phase G: Production Quality |
| 39 | Audio/music | Phase G: Production Quality |
| 40 | Performance/save hardening | Phase G: Production Quality |
| 41 | Modding foundation | Phase H: Extensibility |
| 42 | Modding tools/docs | Phase H: Extensibility |
| 43 | Multiplayer design validation | Phase I: Multiplayer |
| 44 | Deterministic command replication | Phase I: Multiplayer |
| 45 | Co-op gameplay | Phase I: Multiplayer |
