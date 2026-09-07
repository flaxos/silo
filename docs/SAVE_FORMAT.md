# SAVE_FORMAT.md — State Serialization & Save Format

This document specifies the save game file format, versioning, and state verification rules for SILO.

---

## 1. Save File Structure

Save files are serialized as structured JSON (or Godot binary `var_to_bytes_with_objects` with schema validation) structured with a metadata header and comprehensive state payload:

```json
{
  "format_version": 1,
  "game_version": "0.1.0",
  "save_timestamp_utc": "2026-09-06T12:00:00Z",
  "initial_seed": 42,
  "current_tick": 14400,
  "state_checksum": 174829104829102,
  "sim_clock": {
    "tick_index": 14400,
    "year": 1,
    "day_of_year": 100,
    "hour_of_day": 0,
    "minute_of_day": 0
  },
  "rng_state": {
    "seed": 42,
    "state": 839201948102
  },
  "entity_registry": {
    "next_id": 1450,
    "entities": [
      {
        "id": 1,
        "type": "person",
        "data": { ... }
      }
    ]
  },
  "event_queue": {
    "events": [
      {
        "target_tick": 14406,
        "event_type": "shift_change",
        "data": { ... }
      }
    ]
  },
  "systems_state": {
    "utilities": { ... },
    "machinery": { ... },
    "institutions": { ... }
  }
}
```

---

## 2. Save / Load Verification & Determinism

### Deterministic Round-Trip Invariant
Given:
1. Simulation runs from tick 0 to tick $T_1$ with seed $S$.
2. State is saved to disk ($Save_1$).
3. Simulation continues from $T_1$ to $T_2$, reaching state checksum $C_{\text{continuous}}$.
4. In a separate process, $Save_1$ is loaded and simulated from $T_1$ to $T_2$, reaching state checksum $C_{\text{loaded}}$.

**Invariant**:
$$C_{\text{continuous}} == C_{\text{loaded}}$$

This ensures that saving and loading preserves complete simulation fidelity without any loss or jitter.
