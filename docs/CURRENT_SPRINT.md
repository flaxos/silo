# CURRENT_SPRINT.md — Active Sprint Tracking

```
CURRENT: Sprint 15 — Strikes, Sabotage & Industrial Action (Ready to start)
PREVIOUS: Sprint 14 — Corruption, Patronage & Informal Power (Completed & Verified)
PREVIOUS: Sprint 13 — Factions, Movements & Social Networks (Completed & Verified)
PREVIOUS: Integration 12-PV — Physical Silo Viewer (Completed & Verified)
PREVIOUS: Sprint 12 — Political Identity & Legitimacy (Completed & Verified)
```

---

## 1. Previous Sprint: Sprint 14 — Corruption, Patronage & Informal Power (COMPLETED & VERIFIED)

### Goal
Model the divergence between formal institutional authority and actual informal power: favours, patronage networks, nepotism, diversion of scarce resources, preferential allocation, and hidden record discrepancy auditing.

### Acceptance Gate Criteria — PASSED (2026-09-07)
1. **Causal Preferential Allocation**: Resource diversion and preferential appointments arise from real social ties and patronage incentives. Informal power modeled via `PatronageNetwork` taking into account clearance, seniority, unsettled granted favours, faction leadership, and social ties.
2. **Hidden Discrepancy Auditing**: Illicit actions create measurable discrepancies between official records (`ws.custom_data["official_inventory_ledgers"]`) and physical inventories while strictly preserving mass conservation ($\Delta \text{Mass} = 0$).
3. **Investigation & Discovery**: Discrepancies can be discovered organically through audits, whistleblowing (via high-trust or rival faction social connections), or manual inspections.
4. **Determinism & Invariants**: `CorruptionInvariants.validate_all(ws)` confirms favour validity, discrepancy non-negativity, and strict mass conservation; deterministic replay is 100% verified (`Checksum(Run A) == Checksum(Run B)`).
5. **Zero Test Regressions**: All 830 headless test assertions pass across 21 test suites with 0 failures and exit code 0.

### Deliverables Completed
- [x] Informal power relations & favours state (`src/sim/politics/patronage_network.gd`, `src/sim/politics/favour.gd`).
- [x] Corruption mechanics & illicit action lifecycle (`src/sim/politics/illicit_action.gd`, `src/sim/politics/corruption_system.gd`).
- [x] Concealed discrepancies & auditing mechanisms (`CorruptionSystem.audit_action()`, `reconcile_ledger()`, `perform_manual_audit()`).
- [x] Whistleblowing and discovery propagation through social graphs (`_evaluate_audits_and_whistleblowers()`).
- [x] Observability API endpoints (`/api/corruption`, `/api/patronage_network`, `/api/audit_log`, `/api/illicit_trace`) and viewer panels.
- [x] Headless test suite (`tests/simulation/test_corruption_and_patronage.gd` - 35 assertions).
- [x] Architecture Decision Record ADR-016 (`docs/DECISIONS.md`).

---

## 2. Active Sprint: Sprint 15 — Strikes, Sabotage & Industrial Action

### Goal
Model acute collective resistance when institutional tension and faction grievances reach boiling points: coordinated walkouts, wildcat strikes, slowdowns, critical machinery sabotage, and security crackdowns.

### Deliverables Checklist
- [ ] Workplace strike declaration & collective action coordination (`src/sim/politics/strike_action.gd`).
- [ ] Labour withdrawal dynamics in critical facilities (mines, foundries, pump stations).
- [ ] Covert sabotage mechanics targeting machine components with physical consequences.
- [ ] Emergency executive responses: conscription, security dispersal, concessions.
- [ ] Observability API endpoints (`/api/strikes`, `/api/sabotage_reports`) and viewer panels.
- [ ] Headless test suite (`tests/simulation/test_strikes_and_sabotage.gd`).

### Acceptance Gate Criteria for Sprint 15
1. **Grounded Strike Emergence**: Strikes emerge organically from high-friction workplaces with active faction presence.
2. **Systemic Economic Impact**: Labour withdrawal halts production chains and utility pumping according to physical dependency laws.
3. **Physical Machinery Sabotage**: Component damage adheres to machinery degradation models without magical damage spikes.
4. **Determinism & Invariants**: All strike and sabotage mechanics maintain 100% determinism (`Run A == Run B`).
5. **Zero Test Regressions**: All headless tests pass with 0 failures and exit code 0.
