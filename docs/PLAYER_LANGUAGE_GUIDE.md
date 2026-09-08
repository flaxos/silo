# PLAYER_LANGUAGE_GUIDE.md — Human Operations UI Principles

This document defines the language and presentation rules for player-facing interfaces in Project SILO.

---

## 1. Core Axiom: Human First, Technical Second

The simulation engine operates on authoritative numbers, identifiers, and physical equations. The player interface is a **human operations briefing**, not a simulation debugger or database console.

| Context | Internal / Engine | Human Player Facing |
|---|---|---|
| Problem Statement | `Machine #42 state=CRITICAL wear=0.92` | "The main water pump on Level 18 is near critical failure." |
| Root Cause | `BLOCKED_PART required="machined_bearing" qty=1.0` | "Maintenance cannot replace the worn bearing because no replacement part is in local stock." |
| Consequence | `Reservoir: 45000L net_flow=-8.3L/s` | "Stored water reserves are depleting to cover the deficit. At current rates, rationing will begin." |
| Action | `dispatch_command(EXEC_ORDER_SERVICE, 42)` | "Prioritise Maintenance (requests an early Engineering service window for this pump)." |
| Feedback | `ExecutiveOrder #12 accepted.` | "Early-service slot reserved. Maintenance threshold lowered to 55%; technicians will repair once parts and workers are present." |

Technical IDs, exact wear percentages, component hashes, and tick counts are preserved in an expandable **Technical Details** section for power users and debugging, but must never dominate the main view.

---

## 2. Seven Essential Human Questions

Whenever an operational case, alert, or incident is presented, the interface must answer seven questions in plain English:

1. **WHAT'S HAPPENING?**  
   One concise sentence describing the physical or social reality (e.g. *"Water output is falling on Level 18"*).
2. **WHY IS IT HAPPENING?**  
   The causal chain behind the problem (e.g. mechanical wear, missing parts, shift schedules, overcrowding).
3. **WHY IT MATTERS / CONSEQUENCES?**  
   What happens if the problem continues? Connect to real simulation consequences (reservoir depletion, resident thirst, unrest, educational deficit). Never invent fake stakes.
4. **WHO / WHAT IS AFFECTED?**  
   Specific facility, room, crew, and residents directly impacted or potentially at risk.
5. **WHAT DO WE KNOW VS. WHAT DON'T WE KNOW?**  
   Clearly distinguish direct telemetry from incomplete knowledge or future uncertainties. Never expose omniscient backend truth that the player's department would not realistically know.
6. **WHAT IS YOUR AUTHORITY?**  
   Explicitly separate what the player's role (e.g. Head of IT) can do versus what belongs to another department (Administration, Engineering, Education).
7. **WHAT CAN I DO & WHAT WILL IT CHANGE?**  
   Present actionable choices with explicit trade-offs and limits.

---

## 3. Action Transparency: Costs, Trade-offs & Limits

Every selectable directive or action must explicitly state three dimensions:

- **WHY DO IT?**  
  The intended positive effect or strategic rationale.
- **WHAT IS THE TRADE-OFF?**  
  Resource costs, occupied capacity slots, delay, or political risk.
- **WHAT DOES IT NOT DO?**  
  **Mandatory anti-magic rule**: State clearly what the action does *not* solve.
  - *Example*: "Publishing the report informs residents; it does **NOT** build additional classrooms or hire teachers."
  - *Example*: "Requesting early service lowers the wear threshold; it does **NOT** conjure spare parts or instantly repair the machine."

---

## 4. Forbidden Engine-Speak in Normal UI

Do not use internal engine vocabulary in player-facing labels or descriptions unless explicitly inside the Technical Details inspector:

| Forbidden Engine Term | Player-Facing Replacement |
|---|---|
| `Entity` / `Source Entity` | Person, Citizen, Machine, Facility, Room |
| `State Transition` | Status update, condition change |
| `Causal Node` | Cause, contributing factor |
| `Throughput Ratio` | Output percentage, current production |
| `Dispatch Command` | Issue directive, queue decision |
| `Authoritative State` | Actual condition, telemetry |
| `Simulation Tick` | Hour, day, time elapsed |
| `Modifier` / `Invariant` | Physical law, policy rule, balance limit |

---

## 5. Status & Severity Context

Avoid flat abstract terms like `HIGH` or `STATE_BROKEN` without context:
- Instead of `LOW`: *"Needs attention soon"*
- Instead of `MEDIUM`: *"Ongoing problem"*
- Instead of `HIGH`: *"Getting worse"*
- Instead of `CRITICAL`: *"Immediate risk to water supply"* / *"Main water pump has stopped"*
- Instead of `STATE_NOMINAL`: *"Operating normally"*
- Instead of `STATE_DEGRADED`: *"Running under elevated wear"*
