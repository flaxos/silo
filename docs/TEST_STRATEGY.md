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
