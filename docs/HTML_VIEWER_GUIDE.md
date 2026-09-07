# HTML_VIEWER_GUIDE.md — Developer User Guide for Project SILO Observability

This guide provides instructions for launching and utilizing the local HTML Observability Dashboard.

---

## 1. Quick Start

### Starting the Server
From the repository root, execute:
```bash
./tools/run_observer.sh
```

Or run via Godot directly:
```bash
godot --headless -s tools/observer_server.gd
```

### Accessing the Dashboard
Open your browser and navigate to:
```
http://localhost:8080/
```

### Remote / SSH Port Forwarding
If running on a remote headless machine, forward port 8080:
```bash
ssh -L 8080:localhost:8080 user@remote-host
```
Then open `http://localhost:8080/` in your local browser.

---

## 2. Command-Line Options

The observer server accepts standard CLI arguments:

```bash
# Set custom HTTP port (default: 8080)
./tools/run_observer.sh --port 8090

# Set initial population scale (e.g. 100, 250, 500, 1200)
./tools/run_observer.sh --pop 500

# Set deterministic PRNG seed
./tools/run_observer.sh --seed 12345

# Combine flags
./tools/run_observer.sh --port 8080 --pop 250 --seed 999
```

---

## 3. Dashboard Navigation & Views

The dashboard is structured into 16 high-density technical tabs:

### Core Observability
1. **Overview & Telemetry (`#overview`)**:
   - Live simulation clock, state checksum, demographic metrics, water reservoir volume, mass conservation error, machinery health status, and social tension index.
   - Stepping toolbar (+1 tick, +1 hr, +1 day, +7 days, auto-step toggle, speed selector, sim reset).
2. **Population Register (`#people`)**:
   - Filterable, searchable, paginated table of all living and deceased residents.
   - Click any resident's name or ID to open their complete profile drawer.
3. **Households (`#households`)**:
   - Residential family units, head of house, home room allocation, and member rosters.
4. **Spatial & Rooms (`#locations`)**:
   - Sector and Level spatial tree hierarchy. Displays room types, bed counts, occupied beds, and active occupants.
5. **Labour & Education (`#labour`)**:
   - Departmental staffing counts, occupation breakdown, and enrolled student rosters with education scores.

### Physical Systems
6. **Material Economy (`#economy`)**:
   - Strict mass conservation equation status banner ($\Delta_{\text{error}} < 10^{-6}\text{ kg}$).
   - 4-stage pipeline stock meters (Iron Ore $\rightarrow$ Processed Ore $\rightarrow$ Metal Stock $\rightarrow$ Machined Bearings).
7. **Machinery & Wear (`#machinery`)**:
   - Critical machinery entities with operating hours, operational state badges (NOMINAL, DEGRADED, FAULT, BROKEN), component wear progress bars, and active servicing indicators.
8. **8-Step Causal Trace (`#causal-chain`)**:
   - Continuous physical lineage from Geological Seam down to individual Citizen Hydration.
9. **Water & Utilities (`#utilities`)**:
   - Reservoir fill percentage, lifetime pumped vs consumed liters, and net flow rate telemetry.

### Governance & Crises
10. **Institutions & Policy (`#institutions`)**:
    - Active regulatory policies and executive directives.
    - One-click interactive buttons to enact/revoke policies and dispatch/cancel executive orders.
11. **Incidents & Crises (`#incidents`)**:
    - Real-time incident detector feed displaying emerging crises, severity ratings, telemetry diagnostics, and root cause entity links.
12. **Event Timeline (`#timeline`)**:
    - Chronological log of major physical and institutional milestones.
13. **Feedback Loops (`#dependencies`)**:
    - Closed-loop physical topology diagram.

### Verification & Architecture
14. **Invariants & Checks (`#invariants`)**:
    - One-click invariant audit running full mathematical conservation and acyclicity checks.
15. **22-System Matrix (`#wiring`)**:
    - Complete inventory of all 22 authoritative simulation systems with 100% green status indicators.
16. **Performance & Benchmarks (`#performance`)**:
    - Real-time tick latency ($\mu\text{s/tick}$), throughput (ticks/sec), and entity allocation counts.
17. **Raw State Inspector (`#raw`)**:
    - Interactive JSON tree viewer for raw serialization of any entity or full `WorldState`.

---

## 4. REST API Direct Inspection

You can also query the API directly via `curl` or terminal tools:

```bash
# Query live overview snapshot
curl -s http://localhost:8080/api/overview | jq

# Query person profile
curl -s http://localhost:8080/api/person?id=1 | jq

# Step simulation by 144 ticks (1 day)
curl -s -X POST http://localhost:8080/api/step -d '{"ticks": 144}' -H 'Content-Type: application/json' | jq

# Run full invariant validation
curl -s -X POST http://localhost:8080/api/validate | jq
```
