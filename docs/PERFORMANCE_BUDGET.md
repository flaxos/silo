# PERFORMANCE_BUDGET.md — Performance Budgets & Guidelines

This document establishes performance budgets and GDScript optimization standards for SILO.

---

## 1. Simulation Tick Performance Budgets

At $1\times$ speed (~19.47 ticks/second), the real-world interval between ticks is **51.3 milliseconds**. 

To allow ample headroom for presentation, UI, pathfinding, and fast-forward speeds ($2\times, 4\times, 8\times$), the core headless simulation tick must consume only a small fraction of this window.

| Scale Target | Total Persistent Entities | Headless Tick Budget (Max) | Target Throughput (Headless) |
|---|---|---|---|
| **Stage 1** | 100 residents + 50 machines | **< 0.20 ms** | > 5,000 ticks/sec |
| **Stage 2** | 250 residents + 120 machines | **< 0.50 ms** | > 2,000 ticks/sec |
| **Stage 3** | 500 residents + 250 machines | **< 1.00 ms** | > 1,000 ticks/sec |
| **Stage 4 (Lore Target)** | 1,200 residents + 600 machines | **< 2.00 ms** | > 500 ticks/sec |
| **Stress Test** | 3,000 residents + 1,500 machines | **< 5.00 ms** | > 200 ticks/sec |

---

## 2. Memory Budgets

- **Simulation State Heap**: $\le 64\text{ MB}$ for 1,200 residents, full genealogy, machines, and 1 year of rolling telemetry.
- **Garbage Collection Pressure**: Minimize temporary object creation per tick. Zero temporary allocations in hot inner loops.

---

## 3. GDScript Optimization Guidelines

1. **Avoid Allocations in Hot Paths**: Reuse pre-allocated arrays, buffers, and dictionary keys rather than instantiating new objects each tick.
2. **Integer IDs over Object References**: Store entity references as integer IDs to keep data flat and cache-friendly.
3. **No String Concatenation in Ticks**: Avoid string formatting (`"%s_%d" % [...]`) inside inner system update loops.
4. **Stagger Low-Frequency Subsystems**: High-overhead calculations (e.g. quarterly demographic censuses, distant equipment wear checks) should be scheduled at staggered tick intervals via `EventQueue` rather than evaluated every single tick.
5. **Static Typing**: Use static GDScript typing (`var x: int`, `func update(state: WorldState) -> void:`) across all core files to enable Godot VM compiler optimizations.
