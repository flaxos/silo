extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("==========================================================")
	print(" SILO — 1,200 Resident Tick Performance & Subsystem Profile")
	print("==========================================================")
	
	var engine := OperationsSession.create(1200, 42)
	var ws := engine.get_world_state()
	var systems := engine.scheduler.get_all_systems()
	
	var tick_durations_ms: Array[float] = []
	var slow_ticks: Array[Dictionary] = []
	var slow_threshold_ms: float = 35.0
	
	var sys_cumulative_ms := {}
	for sys in systems:
		sys_cumulative_ms[sys.system_id] = 0.0
	sys_cumulative_ms["event_dispatch"] = 0.0
	
	for tick in range(144): # 1 full day
		var tick_start := Time.get_ticks_usec()
		var sys_timings := {}
		
		# Step clock
		ws.sim_clock.advance_tick()
		var current_tick: int = ws.sim_clock.get_tick()
		
		# Events
		var t_ev := Time.get_ticks_usec()
		var due_events := ws.event_queue.pop_due_events(current_tick)
		for ev in due_events:
			for sys in systems:
				if sys.is_enabled:
					sys.handle_event(ws, str(ev.get("type", "")), ev.get("data", {}))
		var ev_ms := float(Time.get_ticks_usec() - t_ev) / 1000.0
		sys_timings["event_dispatch"] = ev_ms
		sys_cumulative_ms["event_dispatch"] = float(sys_cumulative_ms.get("event_dispatch", 0.0)) + ev_ms
		
		# Systems
		for sys in systems:
			if sys.is_enabled:
				var t0 := Time.get_ticks_usec()
				sys.tick(ws)
				var dt_ms := float(Time.get_ticks_usec() - t0) / 1000.0
				sys_timings[sys.system_id] = dt_ms
				sys_cumulative_ms[sys.system_id] = float(sys_cumulative_ms.get(sys.system_id, 0.0)) + dt_ms
				
		var tick_total_ms := float(Time.get_ticks_usec() - tick_start) / 1000.0
		tick_durations_ms.append(tick_total_ms)
		
		if tick_total_ms >= slow_threshold_ms:
			var max_sys := ""
			var max_sys_ms := 0.0
			for sid in sys_timings:
				if sys_timings[sid] > max_sys_ms:
					max_sys_ms = sys_timings[sid]
					max_sys = sid
			slow_ticks.append({
				"tick": tick,
				"total_ms": tick_total_ms,
				"dominant_system": max_sys,
				"dominant_ms": max_sys_ms,
				"all_systems": sys_timings
			})
			
	tick_durations_ms.sort()
	var count := tick_durations_ms.size()
	var sum := 0.0
	for d in tick_durations_ms: sum += d
	var avg := sum / float(count)
	var p50 := tick_durations_ms[int(count * 0.50)]
	var p95 := tick_durations_ms[int(count * 0.95)]
	var p99 := tick_durations_ms[int(count * 0.99)]
	var max_val := tick_durations_ms[count - 1]
	
	print("\n--- PERFORMANCE METRICS (1,200 Residents / 144 Ticks) ---")
	print("Average tick: %.2f ms" % avg)
	print("Median (P50): %.2f ms" % p50)
	print("P95:          %.2f ms" % p95)
	print("P99:          %.2f ms" % p99)
	print("Maximum tick: %.2f ms" % max_val)
	print("Ticks >= %.1f ms: %d / %d" % [slow_threshold_ms, slow_ticks.size(), count])
	
	print("\n--- SUBSYSTEM CUMULATIVE TIME (144 Ticks Total) ---")
	for sid in sys_cumulative_ms:
		var tot: float = sys_cumulative_ms[sid]
		print("  %-25s: %8.2f ms (%5.1f%% of sim time)" % [sid, tot, (tot / sum) * 100.0])
		
	if slow_ticks.size() > 0:
		print("\n--- SLOW TICK SAMPLES (>= %.1f ms) ---" % slow_threshold_ms)
		var show_n := mini(slow_ticks.size(), 8)
		for i in range(show_n):
			var st: Dictionary = slow_ticks[i]
			print("Tick %3d: Total %6.2f ms | Dominant: %-20s (%6.2f ms)" % [
				st.tick, st.total_ms, st.dominant_system, st.dominant_ms
			])
			
	quit()
