# PHYSICAL_VIEWER.md — Real-Time Physical Silo Viewer Architecture & Specification

## 1. Executive Summary

The **Physical Silo Viewer** (Integration 12-PV) enhances the Project SILO developer observability console into an interactive, real-time 2.5D cutaway visualization of the entire subterranean civilisation. The map is **not decorative artwork or a mockup**; it is a direct visual projection of 100% authoritative simulation state, rendering persistent simulated citizens, families, rooms, workplaces, machines, resource lines, and systemic incidents in their physical layout.

---

## 2. Architectural Principles & Invariants

```
┌─────────────────────────────────────────────────────────────┐
│             Authoritative Godot Simulation Core             │
│   (WorldState, SimClock, EntityRegistry, DailyLifeSystem)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│          Deterministic Spatial Model & Projection           │
│   (SiloSpatialModel, PhysicalReader, SimulationReader)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                Live State HTTP / JSON API                   │
│   (/api/physical_snapshot, /api/physical_delta, :id)       │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│            HTML5 Canvas + Vanilla JavaScript Client         │
│          (src/viewer/physical.js, physical.css)             │
└─────────────────────────────────────────────────────────────┘
```

1. **Strict Non-Authoritative Client**: JavaScript is strictly a consumer of read models. Browser code never mutates simulation truth, never calculates production, never calculates relationships, and never invents spatial locations.
2. **Observer Invisibility**: Rendering and polling the physical viewer creates zero state mutations and consumes zero PRNG iterations:
   $$\text{Checksum}(\text{Sim}_A\text{ without viewer}) \equiv \text{Checksum}(\text{Sim}_B\text{ with heavy viewer queries})$$
3. **Deterministic Spatial Layout**: `SiloSpatialModel` builds spatial coordinates purely from the existing authoritative room entities in `EntityRegistry`. Given the same world seed, room coordinates are bit-for-bit identical across runs.
4. **Movement as Pure Interpolation**: When citizens are in transit (`ACTIVITY_TRAVELING`), visual positions are interpolated along known travel intervals between authoritative origin and destination rooms. Authoritative arrival times and schedules are never altered for presentation.

---

## 3. Spatial Hierarchy & Geometry Model

The silo layout is structured into vertical levels and horizontal sectors:

- **Level Height**: 72.0 px per level, with 34.0 px structural rock gaps between levels.
- **Room Width**: Dynamically calculated from physical capacity:
  $$W = \text{clamp}(92.0 + 13.0 \cdot \sqrt{\text{capacity}}, 92.0, 230.0)\text{ px}$$
- **Horizontal Flow**: Rooms on the same level are grouped by sector with 36.0 px sector access gaps and 8.0 px room partitions.
- **Circulation Connectors**: Schematic stairwells and lift shafts connect adjacent vertical levels.

### Physical Room Taxonomy
1. **Residential Apartments & Dormitories**: Family units with allocated beds, occupant tracking, and personal storage.
2. **Education & Childcare**: Schools with student desks and educator assignments.
3. **Food & Dining**: Canteens and commercial kitchens with preparation equipment.
4. **Hygiene & Sanitation**: Communal washrooms and waste disposal hubs.
5. **Medical Clinics**: Treatment rooms and triage beds.
6. **IT & Infrastructure Control**: Server rooms and terminal consoles.
7. **Workshops & Machine Shops**: Precision manufacturing lathes and component assembly tables.
8. **Foundries & Smelters**: High-temperature blast furnaces and ingot casting molds.
9. **Deep Mines**: Extraction shafts, crushing hoppers, and ore transfer chutes.
10. **Water Pumping Stations**: Industrial centrifugal water pumps, shaft seals, and intake lines.

---

## 4. Visual Presentation & HUD Features

- **2.5D Isometric Cutaway**: Subterranean dark-rock background with layered geological striations, ambient room lighting, and isometric top/side wall extrusion.
- **Multi-Level Visual LOD**:
  - *Whole Silo (< 25% Zoom)*: High-density overview, room activity clusters, machine status lights, incident beacons.
  - *Mid Zoom (25% - 60% Zoom)*: Distinct room silhouettes, individual citizen dots, bed occupancy, component repair indicators.
  - *Close (> 60% Zoom)*: High-detail citizen outlines, bed frames, machine details, text labels.
- **Real-Time Overlays**:
  - `People`: Real-time citizen markers colored by occupation class (worker, student, security, medical, engineering).
  - `Homes`: Bed occupancy slots (gold = occupied, slate = empty) and household allocations.
  - `Work`: Active commercial and institutional workplaces.
  - `Industry`: Mines, foundries, and manufacturing facilities.
  - `Machines`: Machine operating state (Green = Nominal, Amber = Degraded, Red = Broken/Fault).
  - `Resources`: Production dependency links across the 4-step material chain.
  - `Water`: Utility conduit routes, pumping throughput, and hydration status.
  - `Incidents`: Red warning beacons marking active emergent crises.
  - `Institutions`: Administrative boundaries and policy intervention zones.
- **Interactive Tools & Modes**:
  - **Global Search**: Type-ahead search indexing citizens, households, rooms, machines, and incidents. Selecting a result pans the camera, switches levels if isolated, and opens the detail drawer.
  - **Follow Person**: Locks camera to a selected citizen, tracking them across shifts, meals, and home sleep.
  - **Follow Household**: Multi-member camera framing following all members of a family simultaneously across a 24h day.
  - **Level Isolation**: Focus on single level or toggle specific level visibilities.

---

## 5. REST JSON Endpoints

| Endpoint | Method | Query Parameters | Description |
| :--- | :--- | :--- | :--- |
| `/api/physical_snapshot` | `GET` | — | Full spatial geometry, all rooms, households, residents, machines, and dependency links. |
| `/api/physical_delta` | `GET` | `since=<tick>` | Incremental live update returning living person locations, machine states, and incidents. |
| `/api/physical_entity` | `GET` | `type=<type>&id=<id>` | Detailed authoritative inspection data for a person, household, room, machine, or incident. |
| `/api/physical_search` | `GET` | `q=<query>&limit=<n>` | Substring search returning matched entity IDs and physical room coordinates. |

---

## 6. Performance Benchmarks

- **1,200 Resident Full Snapshot Generation**: < 800 ms (headless Godot server).
- **Incremental Delta Update**: < 5 ms per tick.
- **Client Canvas Rendering**: Stable 60 FPS on desktop and tablet with 1,200 active simulated citizens.
