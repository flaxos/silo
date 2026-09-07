# CURRENT_SPRINT.md — Active Sprint Tracking

```
CURRENT: Sprint 14 — Corruption, Patronage & Informal Power (Ready to start)
PREVIOUS: Sprint 13 — Factions, Movements & Social Networks (Completed & Verified)
PREVIOUS: Integration 12-PV — Physical Silo Viewer (Completed & Verified)
PREVIOUS: Sprint 12 — Political Identity & Legitimacy (Completed & Verified)
```

---

## 1. Previous Sprint: Sprint 13 — Factions, Movements & Social Networks (COMPLETED & VERIFIED)

### Goal
Implement organic emergence of ideological factions and interest blocs based on shared political identities, occupations, lived grievances, and bounded social networks without hardcoded membership or scripted spawn events.

### Acceptance Gate Criteria — PASSED (2026-09-06)
1. **Bounded Social Graph & Influence**: Modeled direct, bounded social ties (family, household co-residents, coworkers, school cohorts, neighbors, crisis survivors). Influence propagation strictly obeys tie strength, recruiter seniority, and ideological alignment.
2. **Organic Faction Emergence**: Factions emerge dynamically when socially connected, aggrieved clusters exceed stress thresholds. Leaders are selected organically based on tenure, education, and social connectivity.
3. **Dynamic Grievance Platforms & Policy Responses**: Grievance agendas compile from member memories; policy and executive order approval matrices evaluate dynamically; inter-faction rivalry/coalition dynamics calculated.
4. **Authoritative Registration & Invariant Compliance**: `Faction` entity registered in `EntityRegistry` under `"faction"` with full serialization roundtrip. `FactionInvariants` validates entity references, metric bounds, leadership consistency, and absence of dual-membership conflicts.
5. **Observability & HTML Console Integration**: Exposed `/api/factions`, `/api/faction_detail`, and `/api/social_network` endpoints. Added "Factions & Blocs" tab in developer web viewer with movement cards, grievance platforms, policy approval bars, and interactive citizen network inspector.
6. **Headless & Determinism Verification**: All 789 test assertions pass across 20 test suites with 0 failures and exit code 0 (`Checksum(Run A) == Checksum(Run B)`).

### Deliverables Completed
- [x] Bounded Social Graph (`src/sim/politics/social_graph.gd`).
- [x] Authoritative Faction Entity (`src/sim/politics/faction.gd`).
- [x] Organic Faction System (`src/sim/politics/faction_system.gd`).
- [x] Person Model Affiliations (`src/sim/population/person.gd`).
- [x] System Invariant Checker (`src/sim/politics/faction_invariants.gd`).
- [x] Observability Reader & REST API (`src/presentation/simulation_reader.gd`, `tools/observer_server.gd`).
- [x] HTML Developer Console Factions UI (`src/viewer/index.html`, `src/viewer/viewer.js`).
- [x] Headless Test Suite (`tests/simulation/test_factions_and_blocs.gd` - 23 assertions).
- [x] Architecture Decision Record ADR-015 (`docs/DECISIONS.md`).

---

## 2. Active Sprint: Sprint 14 — Corruption, Patronage & Informal Power

### Goal
Model the divergence between formal institutional authority and actual informal power: favours, patronage networks, nepotism, diversion of scarce resources, preferential allocation, and hidden record discrepancy auditing.

### Deliverables Checklist
- [ ] Informal power relations & favours state (`src/sim/politics/patronage_network.gd`, `src/sim/politics/favour.gd`).
- [ ] Corruption mechanics: illicit resource diversion, job/housing favouritism, security leniency.
- [ ] Concealed discrepancies & auditing mechanisms (`src/sim/politics/audit_system.gd`).
- [ ] Whistleblowing and discovery propagation through social graphs.
- [ ] Observability API endpoints (`/api/corruption_trace`, `/api/patronage_network`) and viewer panels.
- [ ] Headless test suite (`tests/simulation/test_corruption_and_patronage.gd`).

### Acceptance Gate Criteria for Sprint 14
1. **Causal Preferential Allocation**: Resource diversion and preferential appointments arise from real social ties and patronage incentives.
2. **Hidden Discrepancy Auditing**: Illicit actions create measurable discrepancies between official records and physical inventories/assignments.
3. **Investigation & Discovery**: Discrepancies can be discovered organically through audits, whistleblowing, or inspections.
4. **Determinism & Invariants**: All patronage and corruption mechanics maintain 100% determinism (`Run A == Run B`).
5. **Zero Test Regressions**: All headless tests pass with 0 failures and exit code 0.

