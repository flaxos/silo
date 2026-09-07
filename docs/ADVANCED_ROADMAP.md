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

Create systemic crime arising from real motive, opportunity, scarcity, relationships and institutional conditions.

Crime must alter actual simulation state rather than increment an abstract crime meter.

## Build

Add crime events/entities supporting:

- theft
- inventory diversion
- contraband
- fraud
- record manipulation
- vandalism
- assault
- black-market trading
- unauthorised access
- sabotage
- corruption-linked offences

Crime should depend on combinations of:

- material scarcity
- opportunity
- access permissions
- location
- relationships
- financial/material incentive
- psychological pressure
- institutional trust
- faction relationships
- perceived enforcement risk

Every crime must reference real:

- people
- locations
- inventories or records
- time
- opportunity
- consequences

## Underground economy

Support:

- illicit buyers
- illicit sellers
- stolen goods
- contraband
- favours
- protected suppliers
- informal exchange networks
- black-market scarcity pricing where appropriate

Goods must remain real inventory.

A stolen bearing cannot simultaneously remain in legitimate storage.

## Evidence

Generate evidence from actual circumstances:

- access logs
- CCTV where available
- witnesses
- inventory discrepancies
- communications
- fingerprints/forensics only if later represented
- possession
- location history
- transaction patterns

## Acceptance

A theft must be traceable:

```text
real inventory exists
→ offender has motive/opportunity
→ inventory physically disappears
→ shortage affects legitimate systems
→ evidence exists
→ investigation may begin
→ outcome depends on available evidence
No arbitrary global crime += 10.
SPRINT 18 — ADVANCED POLICING, INVESTIGATION & JUSTICE
Goal
Make Security a staffed operational institution rather than an omniscient event button.
Build
Represent:
- security officers
- posts
- shifts
- patrol zones
- dispatch
- response priority
- jurisdiction
- access authority
- investigations
- evidence chains
- interviews
- surveillance requests
- warrants/authorisations where policy supports them
- arrests
- escort
- detention
- cells
- prisoner management
- adjudication
- sentencing
- release/parole where appropriate
- case history
Security personnel remain real citizens.
Deploying an officer removes them from another duty.
Investigation
Cases should track:
incident
→ available evidence
→ suspects
→ investigative actions
→ confidence
→ arrest or closure
→ adjudication
Security can:
- solve correctly
- fail
- arrest the wrong person
- overlook evidence
- be obstructed
- be corrupted
IT integration
The player’s IT authority may influence access to:
- CCTV
- badge logs
- identity records
- door events
- communications metadata
- data retention
- evidence integrity
- access permissions
- server logs
IT must not automatically reveal truth.
It controls information availability.
Acceptance
Create a deterministic crime scenario.
Two runs with different:
- CCTV availability
- log retention
- patrol staffing
must produce materially different investigative capability while preserving the same underlying crime.
SPRINT 19 — PSYCHOLOGY, STRESS & ADAPTATION
Goal
Give citizens persistent internal state driven by lived experience without attempting a full human-mind simulator.
Model
Use bounded variables such as:
- stress
- fatigue
- fear
- grief
- anger
- loneliness
- belonging
- purpose
- perceived control
- perceived safety
- burnout
- social support
Inputs may include:
- sleep
- commute
- housing quality
- crowding
- workload
- dangerous work
- family relationships
- bereavement
- scarcity
- illness
- accidents
- violence
- detention
- promotion/demotion
- institutional treatment
- recreation
- social connection
Outputs may affect:
- productivity
- lateness
- absenteeism
- mistakes
- relationship conflict
- social participation
- faction engagement
- crime
- medical demand
- risk-taking
Do not use arbitrary global morale modifiers.
Acceptance
A cohort experiencing:
long commute
+ repeated overtime
+ poor housing
+ industrial accidents
must develop measurably different behavioural outcomes from an otherwise similar well-supported cohort.
The causes must remain inspectable.
SPRINT 20 — RELATIONSHIPS, ROMANCE & HOUSEHOLD DYNAMICS
Goal
Make interpersonal life materially influence generations, households, politics and wellbeing.
Build
Relationship dimensions may include:
- familiarity
- friendship
- affection
- attraction
- trust
- respect
- conflict
- commitment
Support:
- friendship formation
- romantic relationships
- partnerships
- separation
- household joining
- household splitting
- parenting
- caregiving
- family conflict
- reconciliation
- bereavement
Relationships should emerge primarily from real social exposure:
- household
- workplace
- school
- neighbourhood
- recreation
- institutions
- incidents
- mutual social connections
Do not globally pair random compatible citizens.
System effects
Relationships affect:
- household demand
- births
- parenting
- social graph
- psychology
- political influence
- nepotism/corruption
- class mobility
- caregiving
- relocation preferences
Acceptance
Run multiple decades.
Partnerships and households must emerge differently when physical placement, workplace assignment and social exposure differ.
SPRINT 21 — GENETICS, HEREDITY & POPULATION HEALTH
Goal
Support a believable multi-generation closed population without building a genome simulator.
Build
Maintain:
- parentage
- lineage
- relatedness
- deterministic inheritance
- limited inherited traits
- fertility factors where useful
- blood type if medically useful
- bounded recessive-risk mechanics
- close-relative relationship checks
Only model traits that have gameplay consequences.
Population genetics
Provide derived population-level indicators for:
- relatedness concentration
- genetic diversity risk
- inherited-condition prevalence
These must derive from actual family trees.
Acceptance
A multi-generation isolated population must:
- retain valid genealogy
- generate deterministic inheritance
- detect rising relatedness risk
- never create impossible parentage
SPRINT 22 — EPIDEMICS & PUBLIC HEALTH
Goal
Make disease spread through actual social and physical contact.
Disease model
Represent:
- susceptibility
- exposure
- incubation
- infectious period
- symptoms
- severity
- recovery
- mortality
- immunity where appropriate
Transmission may depend on:
- household contact
- workplace contact
- school contact
- shared rooms
- staircase/crowding exposure
- sanitation
- ventilation
- protective policy
- duration of exposure
Healthcare
Represent:
- clinics
- hospital beds
- medical staff
- treatment capacity
- diagnostics
- isolation
- quarantine
- contact tracing where technically/politically possible
- medication/supplies where implemented
Systemic consequences
Closing a school may:
school transmission ↓
→ childcare requirement ↑
→ parent labour availability ↓
Quarantine must physically remove citizens from normal schedules.
Acceptance
An outbreak must propagate through real contact structures.
Changing:
- housing density
- school closure
- ventilation
- quarantine
- medical staffing
must change the outbreak systemically.
5. PHASE C — PHYSICAL INFRASTRUCTURE DEPTH
SPRINT 23 — ADVANCED SPATIAL MODEL & PATHFINDING
Goal
Upgrade the current physicalisation layer into simulation-grade spatial movement.
The existing Godot physical world is the foundation, not something to replace.
Spatial hierarchy
Formalise:
Silo
→ Level
→ District
→ Zone
→ Room
→ Portal
→ Corridor
→ Stair/Lift
Build
Add:
- deterministic navigation graph
- route cost
- physical distance
- central staircase segments
- passenger lift nodes
- corridor capacity
- congestion
- queueing
- access permissions
- locked doors
- restricted areas
- route closures
- rerouting
- travel ETA
- emergency routing
The massive central staircase remains the primary pedestrian spine.
LOD
Visible citizens:
- interpolate along physical routes
Off-screen citizens:
- deterministic route + ETA simulation
Do not require 1,200 full navigation agents every frame.
Acceptance
Closing a stair segment, corridor or lift must:
- prevent impossible traversal
- reroute affected citizens
- alter arrival times
- create congestion elsewhere
- remain deterministic
1,200+ citizens must remain inside performance budget.
SPRINT 24 — MATERIAL LOGISTICS & PHYSICAL TRANSPORT
Goal
Make resources physically exist and move through the silo.
Build
Represent:
- local inventories
- warehouses
- stores
- stockrooms
- material reservations
- haul requests
- freight workers
- carts
- freight lifts
- service corridors
- ore transport
- delivery queues
- source selection
- destination selection
- delivery ETA
Production must require physical material availability.
resource exists
AND
resource is reserved
AND
resource can physically reach consumer
→ production may proceed
Global inventory visibility must not imply instant access.
Freight versus pedestrian movement
Separate:
PEOPLE
central staircase
passenger lifts
corridors

GOODS
freight lifts
service corridors
haul routes
industrial shafts
A failed freight lift may leave people mobile while heavy machinery parts become stranded.
Acceptance
Place a required pump component in a distant warehouse.
Maintenance cannot begin until:
- the component is reserved
- transport is assigned
- a valid route exists
- delivery completes
Blocking the freight route must delay maintenance.
SPRINT 25 — ELECTRICAL TOPOLOGY
Goal
Make electrical infrastructure a real dependency network.
Do not attempt electrical-engineering software fidelity.
Build
Represent:
- generators
- busbars
- switchgear
- transformers
- feeders
- circuits
- breakers
- loads
- batteries
- UPS systems
- emergency power
- isolation points
Model:
- available generation
- load
- capacity
- overload
- trip
- isolation
- redundancy
- backup duration
- restoration
- black-start requirements where appropriate
Every electrical consumer maps to actual infrastructure.
Acceptance
A feeder failure must disable exactly its dependent loads unless valid redundant supply exists.
A pump with no electrical supply cannot operate regardless of mechanical condition.
SPRINT 26 — DATA NETWORK TOPOLOGY
Goal
Turn IT infrastructure into a physical and logical system the player can operate.
Build
Represent:
- endpoints
- switches
- routers
- fibre
- copper
- server rooms
- storage
- application services
- authentication
- logical network segments
- CCTV network
- access-control network
- operational-technology network
- redundancy
- bandwidth abstraction
- service dependencies
Do not simulate individual packets.
Failure model
Differentiate:
- endpoint failure
- switch failure
- uplink failure
- server/service failure
- authentication failure
- power failure
- physical cable failure
- configuration/segmentation failure
Player relevance
Head of IT should be able to understand:
physical hardware
→ network connectivity
→ service availability
→ institutional consequence
Acceptance
Taking a network switch offline must affect exactly the endpoints/services dependent on its reachable topology.
CCTV or access control must fail locally rather than through arbitrary global modifiers.
SPRINT 27 — PLC, SCADA & AUTOMATION SIMULATION
Goal
Connect software/control systems to physical infrastructure.
Build
Represent:
- controllers
- sensors
- actuators
- control loops
- interlocks
- alarms
- HMI/SCADA interfaces
- network connectivity
- automation state
- local/manual mode
- remote mode
- degraded mode
- overrides
Do not implement real PLC programming languages.
Use conceptual control logic.
Failure distinction
The simulation must distinguish:
mechanical failure
electrical failure
sensor failure
controller failure
network failure
software/configuration failure
operator error
A working PLC cannot actuate:
- an unpowered motor
- a mechanically failed valve
- unreachable hardware
Acceptance
Create one automated water system where several distinct failures produce different symptoms, diagnostics and repair requirements.
6. PHASE D — BUILDING THE PHYSICAL SILO
SPRINT 28 — PRODUCTIONISED ISOMETRIC / 2.5D WORLD REPRESENTATION
Goal
Turn the current Godot physicalisation prototype into the primary production game world.
This sprint does NOT invent the physical world from scratch.
It productionises the already-proven physical layer.
Build
Support:
- full vertical silo cutaway
- central staircase
- distributed neighbourhoods
- room rendering
- resident rendering
- machinery
- bio-farms
- utilities
- live incidents
- search
- follow citizen
- selection
- level isolation
- overlays
- camera navigation
- visual LOD
Add overlays for implemented systems:
- population
- housing
- employment
- congestion
- logistics
- power
- water
- network
- incidents
- institutions
Architecture
Godot remains presentation.
Authoritative simulation remains backend truth.
No Godot object may become the canonical citizen, machine, inventory or policy state.
Acceptance
A player can visually trace:
citizen
→ home
→ commute
→ workplace
→ machine
→ resource dependency
→ infrastructure failure
without opening the debug observer.
SPRINT 29 — FULL CONSTRUCTION SYSTEM
Goal
Allow the silo to physically evolve through actual labour, materials and infrastructure.
Construction lifecycle
proposal
→ approval
→ design
→ excavation/preparation
→ materials reserved
→ materials delivered
→ labour assigned
→ construction
→ inspection
→ utility connection
→ commissioning
→ operation
Build
Support:
- excavation
- rooms
- walls
- corridors
- doors
- stairs
- service shafts
- residential quarters
- utility rooms
- machinery installation
- storage
- farms
- workshops
- conversion of existing space
- demolition/decommissioning
Construction must require:
- accessible site
- labour
- skills
- tools
- real materials
- valid logistics
- required utilities
No instant construction.
Acceptance
Building a new clinic must consume real materials and labour, physically connect to the silo and remain unusable until commissioned.
SPRINT 30 — PROCEDURAL SILO, HISTORY & VIABILITY GENERATION
Goal
Generate a functioning inherited civilisation rather than an empty dungeon.
World generation
Generate:
- physical layout
- levels
- neighbourhoods
- distributed residential areas
- schools
- clinics
- canteens
- sanitation
- recreation
- bio-farms
- utilities
- storage
- engineering
- manufacturing
- foundry
- mining
- IT
- security
- circulation
- freight routes
Generate a real population:
- families
- households
- housing
- jobs
- schools
- class/status
- relationships
- institutions
Generate history:
- leadership
- family dynasties
- previous incidents
- machine age
- technical debt
- infrastructure modifications
- staffing problems
- shortages
- maintenance backlog
- political grievances
- class geography
- corruption history where implemented
Viability gate
A generated silo must pass baseline checks for:
- housing
- food capacity
- water
- sanitation
- power
- medical capacity
- education
- labour
- maintenance
- access
- critical infrastructure
Do not generate guaranteed perfection.
Generate a functioning civilisation with inherited weaknesses.
Acceptance
Two seeds produce materially different but viable silo histories and layouts.
No generated world may depend on impossible housing, staffing or infrastructure references.
PHASE D.5 — CLOSED-LOOP SELF-SUFFICIENCY
The silo must eventually prove that it can sustain human life as a closed civilisation rather than merely displaying life-support rooms.
SPRINT 30A — FOOD, AGRICULTURE & NUTRIENT CYCLE
Goal
Make long-term food survival systemic.
Build
Represent at useful abstraction:
- agricultural area
- crop categories
- growing cycles
- seed stock
- water requirement
- nutrient requirement
- lighting/power
- agricultural labour
- harvest
- food processing
- storage
- refrigeration
- kitchens
- meal distribution
- spoilage
- organic waste
- nutrient recovery where appropriate
Do not simulate every ingredient or individual vegetable.
Track useful outputs such as:
- calories
- nutritional sufficiency
- storage
- production resilience
Acceptance
Loss of farm power, water or labour must reduce future food supply through the real production chain.
SPRINT 30B — WATER, WASTEWATER & SANITATION CLOSURE
Goal
Turn the existing water system into a believable closed-loop civilisation utility.
Build
Represent:
water source/recovery
→ treatment
→ clean storage
→ distribution
→ consumption
→ greywater/sewage
→ wastewater treatment
→ recovery
→ losses
Support:
- contamination
- treatment capacity
- pump dependency
- storage
- hygiene demand
- sanitation
- sewage backlog
- wastewater failures
Acceptance
A wastewater failure must eventually produce real sanitation and health consequences rather than merely reducing a global value.
SPRINT 30C — ATMOSPHERIC LIFE SUPPORT
Goal
Make underground air a meaningful infrastructure system.
Build
Use zone-level simulation rather than fluid dynamics.
Track where useful:
- oxygen
- CO2
- temperature
- humidity
- air quality
- contaminants
- occupancy load
Represent:
- ventilation zones
- air handlers
- fans
- filtration
- ducts
- environmental sensors
Acceptance
Failure of an air handler must affect only connected zones and create progressive consequences based on occupancy and ventilation state.
SPRINT 30D — WASTE, RECYCLING & MATERIAL RECOVERY
Goal
Prevent the silo economy from assuming waste disappears.
Build
Represent useful waste classes:
- organic
- scrap metal
- industrial waste
- plastics
- electronics
- medical waste
- sewage by-products
Support:
- collection
- transport
- sorting
- reclamation
- recycling
- disposal
- storage constraints
Recovered materials should return to actual inventories.
Acceptance
Long simulations must demonstrate material loss/recovery rather than infinite closed-loop efficiency.
7. PHASE E — SECURITY, CONFLICT & OUTSIDE WORLD
SPRINT 31 — TACTICAL SECURITY OPERATIONS
Goal
Make security interventions physically occur in the silo.
Build
Support operational orders:
- patrol
- checkpoint
- search
- escort
- arrest
- evacuation
- lockdown
- crowd control
- protective detail
- incident containment
- prison transfer
Orders require:
- real officers
- travel
- time
- access
- equipment
- available staffing
Acceptance
Dispatching Security to a protest must reduce coverage elsewhere.
Officers must physically reach the incident before acting.
SPRINT 32 — COMBAT
Goal
Support rare high-consequence violence without turning SILO into a combat-first game.
Build
Represent at bounded fidelity:
- melee
- ranged conflict
- cover
- suppression
- injury
- incapacitation
- surrender
- capture
- medical evacuation
- infrastructure damage
Combatants are persistent citizens.
Consequences affect:
- families
- labour
- psychology
- politics
- institutions
- medical capacity
Acceptance
A violent confrontation leaves persistent demographic, institutional and infrastructure consequences.
Combat must not become the default solution to political problems.
SPRINT 33 — EXPEDITIONS
Goal
Allow the silo to send actual citizens beyond its normal boundary.
Expedition lifecycle
objective
→ personnel
→ equipment
→ supplies
→ route
→ departure
→ travel
→ events
→ return / loss
Build
Support objectives such as:
- reconnaissance
- salvage
- resource survey
- communications repair
- rescue
- external investigation
Expeditions consume real:
- people
- food
- water
- medical supplies
- equipment
Skills matter.
Losses persist.
Acceptance
Success must depend on actual personnel, equipment, supplies and external conditions.
SPRINT 34 — OUTSIDE WORLD
Goal
Create an external simulation sufficient for strategic decisions and expeditions.
Do not build a second 1,200-person civilisation simulator.
Build
Represent external regions at appropriate LOD:
- terrain/regions
- ruins
- infrastructure
- hazards
- weather
- radiation/environment where setting requires
- resources
- signals
- abandoned facilities
- external groups
- routes
External entities become more detailed when they interact with the silo.
Acceptance
External conditions evolve over time and materially alter expedition risk and opportunity.
8. PHASE F — ENDGAME & CAMPAIGN STRUCTURE
SPRINT 35 — STRATEGIC OBJECTIVES & ENDGAME
Goal
Give long campaigns systemic conclusions without forcing one canonical ending.
Potential systemic outcomes
Survival
Maintain a viable closed civilisation over the required generational period.
Collapse
Population, infrastructure or ecological systems become unsustainable.
Authoritarian Stability
The silo remains functional under concentrated institutional control.
Political Transformation
Governance fundamentally changes through reforms or collective action.
Restoration
Technology and outside conditions permit restoration beyond the silo.
Expansion
Create additional viable settlements.
Exodus
The population deliberately abandons the silo.
Technological Transition
Critical systems reach a substantially more sustainable technological state.
Civil Conflict
Internal political conflict fundamentally transforms or destroys the settlement.
Acceptance
Endgame evaluation must read:
- current simulation state
- historical player decisions
- institutional history
- population outcomes
- infrastructure condition
- political development
- external discoveries
No final dialogue choice may override decades of simulation truth.
SPRINT 36 — CAMPAIGN HISTORY & LEGACY
Goal
Turn the entire simulation into a readable history of the civilisation.
Build
Generate from actual recorded events:
- leadership timeline
- demographic history
- family dynasties
- construction milestones
- industrial milestones
- major failures
- shortages
- epidemics
- political movements
- reforms
- corruption scandals
- crimes
- strikes
- rebellions
- casualties
- expeditions
- outside discoveries
- major IT decisions
Acceptance
Two materially different campaigns must produce materially different historical records.
No major event should appear in campaign history unless it actually occurred.
9. PHASE G — PRODUCTION QUALITY
SPRINT 37 — FINAL UX / INFORMATION DESIGN
Goal
Turn development/debug interfaces into a coherent management-game experience.
Build
Create clear information hierarchy for:
- physical world
- citizen inspection
- households
- alerts
- schedules
- policies
- IT
- infrastructure
- politics
- production
- logistics
- incidents
- security
- expeditions
Support:
WHAT happened?
WHY did it happen?
WHERE is it happening?
WHO is affected?
WHAT can I actually control?
WHAT may happen next?
Keep deep observability available without requiring players to understand implementation details.
Acceptance
A new player can diagnose a systemic problem from the main game UI without opening developer tools.
SPRINT 38 — FINAL ART DIRECTION
Goal
Establish a distinctive production visual identity.
Principles
Use grounded near-future underground industrial realism.
Visual language may include:
- decades of retrofits
- exposed pipes
- cable trays
- ageing machinery
- practical signage
- institutional architecture
- different construction generations
- human clutter
- constrained lighting
- class differences visible through housing and services
- industrial lower levels
- greener agricultural zones
- central staircase as the visual spine
Avoid direct imitation of existing bunker/colony IP.
Build
Productionise:
- environment kit
- rooms
- characters
- machinery
- farms
- utilities
- props
- UI visual language
- VFX
- lighting
- animation
Acceptance
Art must communicate simulation information rather than obscure it.
SPRINT 39 — AUDIO & MUSIC
Goal
Make the silo audible as a functioning civilisation and machine.
Build
Systemic soundscape:
- ventilation
- pumps
- transformers
- machinery
- farms
- alarms
- PA systems
- doors
- lifts
- stair crowds
- workshops
- residential ambience
- school activity
- medical activity
- mining
Audio may respond to:
- district
- time
- occupancy
- infrastructure condition
- incidents
- unrest
- power state
Acceptance
Players should often recognise location type and infrastructure distress from sound alone.
SPRINT 40 — PERFORMANCE, SAVE STABILITY & LONG-RUN HARDENING
Goal
Prove production viability.
Standard benchmark
1200 residents.
Stress benchmark
3000 residents where architecture permits.
Test
- multi-decade simulation
- 50+ year campaigns
- save/load consistency
- deterministic checksum
- memory growth
- simulation speed
- rendering
- pathfinding
- staircase congestion
- logistics
- epidemics
- large faction events
- mass shift changes
- power failures
- network failures
- PLC failures
- incident storms
Acceptance
Require:
- no systemic divergence after save/load
- no unbounded memory growth
- acceptable simulation speed
- responsive Godot presentation
- bounded pathfinding cost
- stable long-run event history
- deterministic reproducibility
10. PHASE H — EXTENSIBILITY
SPRINT 41 — MODDING FOUNDATION
Goal
Allow data-driven extension without destabilising the simulation core.
Stable moddable schemas
Potential:
- occupations
- resources
- recipes
- machines
- machine components
- rooms
- construction definitions
- crops
- diseases
- policies
- institutions
- factions
- incidents
- narrative templates
- outside locations
- art/audio references
Acceptance
A sample mod can add:
- one resource
- one production chain
- one room/machine
- one incident or policy
without editing core source.
SPRINT 42 — MODDING TOOLS & DOCUMENTATION
Goal
Make mod creation practical.
Build
- schema validation
- error reporting
- load order
- dependencies
- compatibility/version checks
- example mods
- documentation
- development reload where safe
- mod inspection tools
Acceptance
A third party can build a basic content mod using documentation alone.
11. PHASE I — MULTIPLAYER
SPRINT 43 — MULTIPLAYER DESIGN VALIDATION
Goal
Determine whether multiplayer actually improves SILO before building networking.
Candidate model
Cooperative administration where players may occupy roles such as:
- IT
- Engineering
- Security
- Administration
Alternative models may be tested but must not distort the single-player game.
Evaluate:
- pause/speed authority
- conflicting orders
- information asymmetry
- institutional authority
- save ownership
- disconnects
- griefing
- UI complexity
Acceptance
Produce and test a multiplayer design prototype/spec.
If multiplayer harms the core game, stop here.
SPRINT 44 — DETERMINISTIC COMMAND REPLICATION
Goal
Synchronise player commands rather than continuously synchronising every citizen.
Architecture
authoritative deterministic simulation
+ ordered player commands
+ assigned simulation ticks
→ reproducible client state
Build
- command sequence numbers
- tick assignment
- validation
- checksum exchange
- divergence detection
- resynchronisation
- reconnect support
Acceptance
Two clients processing the same command stream remain checksum-identical over an extended simulation.
SPRINT 45 — CO-OP GAMEPLAY
Goal
Implement the validated cooperative model.
Players use the same institutional systems as single-player.
Do not create multiplayer-only simulation rules unless unavoidable.
Acceptance
A complete campaign segment can be played cooperatively while:
- maintaining deterministic simulation
- preserving institutional authority
- handling conflicting orders
- handling disconnect/reconnect
- preserving saves
Multiplayer remains optional.
CROSS-CUTTING RULES FOR ALL ADVANCED SPRINTS
Every sprint must:
1. preserve deterministic simulation;
2. preserve all previous acceptance tests;
3. expose new state through observability;
4. expose relevant state through the Godot physical world where spatially meaningful;
5. add performance benchmarks where entity counts or update rates increase;
6. use real citizens/resources/locations rather than disposable spawned representations;
7. record systemic history;
8. avoid fake global meters when derived state is possible.
The physical Godot world is now a permanent architecture layer:
SIMULATION TRUTH
→ READ / SPATIAL MODEL
→ GODOT PRESENTATION
Godot never becomes a second authoritative simulation.
The central staircase, neighbourhoods, housing, services, industry and utilities must remain mechanically connected to the simulation rather than decorative.
The global objective remains:
Maximum useful causality per unit of complexity.