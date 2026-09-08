# TEST_STRATEGY.md — Test Strategy & Verification

This document outlines the testing methodology, suite structure, and quality gates for SILO.

---

## 1. Testing Philosophy

1. **Headless First**: All simulation tests run without rendering or window creation.
2. **Deterministic Verification**: Every feature includes regression tests verifying that simulation replay produces identical state checksums.
3. **Invariant-Driven**: State assertions verify fundamental domain laws (conservation of mass, unique IDs, genealogical reciprocal links, bed single-occupancy).
4. **Fast Feedback**: Core unit and smoke test suites must execute in < 1.0 second.

---

## 2. Test Suite Structure

```
tests/
├── framework/
│   └── test_asserts.gd        # Assertion helpers and result reporting
├── unit/                      # Isolated unit tests for individual classes
│   ├── test_seeded_random.gd
│   ├── test_sim_clock.gd
│   ├── test_entity_registry.gd
│   ├── test_event_queue.gd
│   └── test_checksum.gd
├── determinism/               # Seeded multi-run state equality tests
│   └── test_determinism_smoke.gd
├── integration/               # Multi-system interactions
├── simulation/                # Multi-year deep simulation stress tests
└── performance/               # Benchmarking tick execution times
    └── test_tick_performance.gd
```

---

## 3. Running Tests

### All Tests
```bash
godot --headless -s tools/test_runner.gd
```

### Specific Suites
```bash
# Run unit tests only
godot --headless -s tools/test_runner.gd -- unit

# Run determinism tests only
godot --headless -s tools/test_runner.gd -- determinism

# Run performance benchmarks
godot --headless -s tools/test_runner.gd -- performance
```

---

## 4. Acceptance Gates

Before any sprint can be marked complete, the following gates must be met:
1. **Zero Failures**: All unit, integration, and determinism tests pass (exit code 0).
2. **Determinism Parity**: Multi-run checksum comparison must show 100% equivalence over $\ge 1,000$ ticks.
3. **Performance Budget Compliance**: Headless tick execution speed must remain within the limits defined in `docs/PERFORMANCE_BUDGET.md`.
4. **Invariant Checks Clean**: Domain invariant validators report zero violations.


## Operations V0.1 acceptance & UX clarity verification

The operations loop and UX clarity layers are verified through two dedicated simulation test suites:
1. `tests/simulation/test_operations_loop.gd` (85 assertions): covers real-state detection, references, deduplication, recurrence/terminal states, physical part and labour prerequisites, action authority at enqueue/execution, cancellation/expiry, information classification, censorship/delivery/belief consequences, read-only projections, 1,000-tick replay, pending/active order persistence and disk-save continuation.
2. `tests/simulation/test_operations_ux_clarity.gd` (82 assertions): covers plain-English human titles and briefings, elimination of engine enums and debug jargon from player text, separation of root facility problems from official information status, IT authority boundaries versus outside authority, action trade-off explanations and anti-magic disclaimers, pump wear and failure state descriptions, labour crew cap (`MAX_CREW_PER_MACHINE = 3`), security officer generation and assignment, and administrative capacity review order issuance.

The complete suite reports **1,311 passed / 0 failed** across all 33 test suites.

```bash
godot --headless --log-file /tmp/silo-tests.log -s tools/test_runner.gd
godot --headless --log-file /tmp/silo-uat.log -s tools/uat_operations.gd
godot --headless -s tools/profile_slow_ticks.gd
```

The separate native-scene UAT (`tools/uat_operations.gd`) drives pointer events and UI signals, verifies case-to-inspector linking, executes decisions through the real command path, and checks layout/save controls (19 passed, 0 failed; panel 375×830 at `(1055, 60)`, action button at `(1065, 804)` inside the 1440×900 viewport). Remove `--headless` on a permitted desktop to render its screenshots. Headless UI checks do not establish visual quality or human gameplay acceptance.

Tick performance and subsystem execution profiling is automated via `tools/profile_slow_ticks.gd` over 144 ticks at 1,200 population: average tick 11.77ms, maximum tick 31.68ms (0 ticks >= 35ms). Primary execution load is isolated to `daily_life` (44.0%), `incidents` (20.7%), and `operations` (14.0%).

