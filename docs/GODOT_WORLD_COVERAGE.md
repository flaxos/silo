# Godot World Coverage

This is a source audit of the physical Godot integration. A room or configured
hook does not imply that its named service is simulated. `Live` means that the
display value comes from authoritative state that can change as the simulation
advances. Static geometry is marked separately.

The data flow is:

`WorldState and simulation systems -> spatial/read model -> Godot world -> player view`

Godot and the HTML observer are read-only consumers. Presentation interpolation
may move a marker between authoritative endpoints, but it does not change a
person's schedule, route, or arrival.

## Entity and system matrix

| Entity or system | Backend exists? | Physical location? | Rendered? | Clickable? | Live? | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Adult resident | Yes: persistent `Person`, household, occupation, schedule and travel state | Yes: current room, home and workplace | Yes | Yes | Yes | Wired |
| School-age resident | Yes: household, school assignment and study schedule | Yes: home, current room and school | Yes | Yes | Yes | Wired |
| Infant or retired resident | Yes: household and home routine; no workplace or school is expected | Yes: home and current room | Yes | Yes | Yes | Wired within backend scope |
| Household | Yes: stable ID, head and member IDs | Yes: `home_room_id` | Yes | Yes | Membership is authoritative; home occupancy changes | Wired |
| Bed | Yes: indexed allocation in a residential `Room` | Yes: owning room | Yes in room/person inspection | Through owning home/person | Allocation is authoritative | Wired |
| Residential room | Yes | Yes: level and sector, with deterministic presentation geometry | Yes | Yes | Occupancy is live; geometry is static | Wired |
| Workplace and school room | Yes | Yes | Yes | Yes | Assigned/current occupants are live | Wired |
| Canteen, kitchen and hygiene room | Yes | Yes | Yes | Yes | Occupants are live; there is no food or sanitation resource service state | Partial: daily-life location only |
| Clinic | Yes as a room with assigned doctors/nurses | Yes | Yes | Yes | Staff/current occupants are live | Partial: no treatment model |
| Bio-farm and food-processing space | No production backend | Yes as configured spatial hooks | Yes | Yes | No production state | Hook only |
| Water pump station | Yes | Yes | Yes | Yes | Reservoir, pumping and consumption state are live | Wired |
| Waste processing, wastewater treatment, air handler and power plant | No corresponding simulation system | Yes as configured spatial hooks | Yes | Yes | No service state | Hook only |
| Server room / IT | IT occupations and room assignment exist | Yes | Yes | Yes | Staff/current occupants only | Partial: no IT/comms service model |
| Security post | Institutional/security policy state exists; no post-operation model | Yes as a spatial hook | Yes | Yes | No post state | Hook only |
| Mine | Yes: labour-dependent extraction and room-owned inventory | Yes | Yes | Yes | Yes | Wired |
| Foundry | Yes: labour-dependent conversion and room-owned inventory | Yes | Yes | Yes | Yes | Wired |
| Machine shop | Yes: labour-dependent machining and room-owned inventory | Yes | Yes | Yes | Yes | Wired |
| Storage bay | Room hook only | Yes | Yes | Yes | No storage-bay process | Hook only; real inventories remain in their owning production rooms |
| Inventory | Yes: stable entity with owning room ID and conserved material quantities | Yes: owning room | Exposed in room/workplace inspection | Through owning room | Yes | Wired |
| Material transfer | Yes: deterministic direct inventory-to-inventory transfer | Endpoints are located | Dependency/endpoints can be shown | Through rooms | Yes | Partial: no carrier, travel or physical logistics |
| Machine | Yes | Yes: authoritative `room_id` | Yes | Yes | Condition and maintenance state are live | Wired |
| Machine component | Yes: wear, state, repair progress and required part | Yes through owning machine and room | Shown in machine inspection/status | Through machine | Yes | Wired |
| Incident | Yes | Resolves when its root-cause entity resolves to a room | Yes when resolved | Yes | Yes | Wired where a physical root cause exists; unresolved roots must remain flagged |
| Level and zone | Spatial read model | Yes | Yes | Level navigation is interactive | Static | Wired presentation geometry |
| Corridor / room portal | Spatial model supplies deterministic room-to-landing edges | Yes | No separate corridor object; the relationship is implicit in the cutaway | No | Static local-travel cost | Route hook, not free-form pathfinding or a simulated corridor |
| Central stair landing and segment | Deterministic spatial graph | Yes | Yes | Yes | Occupancy, queue and congestion are live read-model values | Wired |

The Godot renderer batches these projections in one `Node2D`: far zoom shows
room-density clusters, while medium and near zoom use lightweight citizen draw
calls rather than one processing node per resident. Authoritative journeys are
drawn through approach, queue, stair-segment and egress phases. Search covers
person/name/ID, household, room and machine; a result focuses and isolates its
level before opening the real inspector. Follow mode updates the camera from the
selected person's live location. Room, person, machine and stair selection are
implemented; near-zoom person/machine picking uses a room-priority heuristic.

## Mapping rules and honest gaps

- Residents use their existing person, household, room, workplace, school and
  machine IDs. Missing required references are audit failures; the viewer must
  not select a plausible substitute.
- `workplace_room_id == 0` is valid for infants, retired residents and other
  explicitly unassigned people. It is unresolved for a worker whose occupation
  requires a workplace.
- `school_room_id == 0` is valid outside school age. It is unresolved for an
  assigned student.
- A room type named clinic, bio-farm, power plant, air handler, waste processing,
  wastewater treatment, storage or server room supplies location and presentation
  metadata only unless a backend system listed above owns changing service state.
- Water is a reservoir-and-pump balance with per-person consumption. It is not a
  hydrodynamic pipe-network simulation.
- The production chain performs deterministic transfers between room-owned
  inventories. No person, cart, conveyor or travel path carries those transfers.
- Medical staffing and clinic attendance do not constitute diagnosis or
  treatment. Food-service attendance does not constitute calories, food stocks
  or farm output. IT staffing does not constitute a communications/network model.

## UAT evidence policy

Automated tests may establish deterministic layout, reference integrity,
read-only presentation, stair arithmetic and bounded snapshot/frame timing.
They do not establish that the game is readable, that controls feel smooth, or
that a human successfully followed a citizen through a full day. Those remain
human Godot UAT items until observed and recorded. Measured population, entity
counts, timings and test totals belong in the completion report produced by the
test run; this document does not substitute targets or estimates for results.
