# src/presentation/simulation_viewer.gd
class_name SimulationViewer
extends RefCounted

## Formats simulation read models into clean, decoupled ASCII dashboards and telemetry reports.

static func format_bar(val: float, max_val: float, width: int = 20, fill_char: String = "#", empty_char: String = "-") -> String:
	if max_val <= 0.0:
		return "[" + empty_char.repeat(width) + "] 0.0%"
	var pct: float = clampf(val / max_val, 0.0, 1.0)
	var filled_len: int = int(round(pct * float(width)))
	var empty_len: int = maxi(0, width - filled_len)
	return "[" + fill_char.repeat(filled_len) + empty_char.repeat(empty_len) + "] " + ("%5.1f%%" % (pct * 100.0))

static func render_header(ws: WorldState) -> String:
	var clock: Dictionary = SimulationReader.get_clock_summary(ws)
	var pop: Dictionary = SimulationReader.get_population_summary(ws)
	var util: Dictionary = SimulationReader.get_utilities_summary(ws)
	var inst: Dictionary = SimulationReader.get_institutions_summary(ws)
	
	var lines: Array[String] = [
		"================================================================================",
		" PROJECT SILO — SIMULATION TELEMETRY VIEWER",
		" Time: %-26s | Checksum: 0x%X" % [clock["formatted_time"], clock["checksum"]],
		" Population: %-4d Living (%-3d Deceased)   | Reservoir: %6.1f L (%4.1f%%)" % [
			pop["living_count"], pop["deceased_count"], util["reservoir_current_liters"], util["fill_percent"]
		],
		" Social Tension: %4.1f / 100.0              | Active Policies: %-2d | Orders: %-2d" % [
			inst["social_tension_index"], inst["active_policies"].size(), inst["active_orders"].size()
		],
		"================================================================================"
	]
	return "\n".join(lines)

static func render_population_dashboard(ws: WorldState) -> String:
	var pop: Dictionary = SimulationReader.get_population_summary(ws)
	var lines: Array[String] = [
		"--- [ POPULATION & DEMOGRAPHICS ] ----------------------------------------------",
		" Demographics Breakdown:",
		"   Infants  : %-4d | Children : %-4d | Students: %-4d" % [pop["infants"], pop["children"], pop["students"]],
		"   Adults   : %-4d | Elders   : %-4d | Employed: %-4d" % [pop["adults"], pop["elders"], pop["employed_count"]],
		" Population Vitals:",
		"   Hydration: %s (Avg %4.1f%%)" % [format_bar(pop["avg_hydration"], 100.0, 15), pop["avg_hydration"]],
		"   Health   : %s (Avg %4.1f%%)" % [format_bar(pop["avg_health"], 100.0, 15), pop["avg_health"]],
		"   Education: %s (Avg %4.1f pts)" % [format_bar(pop["avg_education"], 100.0, 15), pop["avg_education"]],
		" Activity Distribution:",
		"   SLEEPING : %-3d | WORKING  : %-3d | STUDYING : %-3d | EATING   : %-3d" % [
			pop["activity_counts"]["SLEEPING"], pop["activity_counts"]["WORKING"],
			pop["activity_counts"]["STUDYING"], pop["activity_counts"]["EATING"]
		],
		"   HYGIENE  : %-3d | RECREATE : %-3d | TRAVELING: %-3d | IDLE     : %-3d" % [
			pop["activity_counts"]["HYGIENE"], pop["activity_counts"]["RECREATING"],
			pop["activity_counts"]["TRAVELING"], pop["activity_counts"]["IDLE"]
		]
	]
	return "\n".join(lines)

static func render_economy_dashboard(ws: WorldState) -> String:
	var econ: Dictionary = SimulationReader.get_economy_summary(ws)
	var res: Dictionary = econ["resource_totals"]
	var lines: Array[String] = [
		"--- [ MATERIAL ECONOMY & PRODUCTION CHAIN ] -----------------------------------",
		" Geological Seam Reserves : %8.1f kg remaining" % econ["seam_ore_kg"],
		" Material Stocks in Sinks & Inventories:",
		"   [1] Iron Ore         : %7.1f kg" % res[ResourceRegistry.RES_IRON_ORE],
		"   [2] Processed Ore    : %7.1f kg" % res[ResourceRegistry.RES_PROCESSED_ORE],
		"   [3] Metal Stock      : %7.1f kg" % res[ResourceRegistry.RES_METAL_STOCK],
		"   [4] Machined Bearings: %7.1f units (%5.1f kg)" % [
			res[ResourceRegistry.RES_MACHINED_BEARING],
			res[ResourceRegistry.RES_MACHINED_BEARING] * ResourceRegistry.get_unit_mass(ResourceRegistry.RES_MACHINED_BEARING)
		],
		"   [+] By-product Tailings: %6.1f kg Slag | %6.1f kg Swarf" % [
			res[ResourceRegistry.RES_SLAG_TAILINGS], res[ResourceRegistry.RES_METAL_SWARF]
		],
		" Mass Conservation Ledger:",
		"   Seam: %8.1f kg + Inventories: %7.1f kg + Maintenance Installed: %6.1f kg" % [
			econ["seam_ore_kg"], econ["inventory_mass_kg"], econ["installed_maintenance_mass_kg"]
		],
		"   Total System Mass: %9.3f kg | Discrepancy Error: %7.6f kg [OK]" % [
			econ["total_system_mass_kg"], econ["mass_balance_error_kg"]
		]
	]
	return "\n".join(lines)

static func render_machinery_dashboard(ws: WorldState) -> String:
	var mach: Dictionary = SimulationReader.get_machinery_summary(ws)
	var lines: Array[String] = [
		"--- [ MACHINERY & INFRASTRUCTURE ] ---------------------------------------------",
		" Total Machines: %d (Nominal: %d | Degraded: %d | Fault: %d | Broken: %d)" % [
			mach["total_machines"], mach["states"]["NOMINAL"], mach["states"]["DEGRADED"],
			mach["states"]["FAULT"], mach["states"]["BROKEN"]
		]
	]
	
	for m in mach["machines_list"]:
		lines.append("   Machine #%-2d [%-24s] State: %-8s | Hours: %5.1f h | Flow: %5.1f L/min" % [
			m["id"], m["type"], m["state"], m["operating_hours"], m["throughput_lpm"]
		])
		for cid in m["components"]:
			var c: Dictionary = m["components"][cid]
			var broken_tag: String = " [BROKEN]" if c["is_broken"] else ""
			lines.append("     - %-22s: %s%s" % [
				cid, format_bar(c["wear_percent"], 100.0, 10), broken_tag
			])
			
	return "\n".join(lines)

static func render_utilities_dashboard(ws: WorldState) -> String:
	var util: Dictionary = SimulationReader.get_utilities_summary(ws)
	var lines: Array[String] = [
		"--- [ UTILITIES & WATER SUPPLY ] -----------------------------------------------",
		" Potable Water Reservoir: %s (%6.1f / %6.1f L)" % [
			format_bar(util["reservoir_current_liters"], util["reservoir_capacity_liters"], 18),
			util["reservoir_current_liters"], util["reservoir_capacity_liters"]
		],
		" Cumulative Hydrodynamics Ledger:",
		"   Total Water Pumped   : %8.1f L" % util["total_pumped_liters"],
		"   Total Water Consumed : %8.1f L" % util["total_consumed_liters"],
		"   Net Volume Delta     : %+8.1f L" % util["net_volume_change_liters"]
	]
	return "\n".join(lines)

static func render_institutions_dashboard(ws: WorldState) -> String:
	var inst: Dictionary = SimulationReader.get_institutions_summary(ws)
	var lines: Array[String] = [
		"--- [ INSTITUTIONAL GOVERNANCE & POLICIES ] ------------------------------------",
		" Habitat Social Tension: %s (%4.1f / 100.0)" % [
			format_bar(inst["social_tension_index"], 100.0, 18), inst["social_tension_index"]
		],
		" Active Policies by Category:"
	]
	
	if inst["active_policies"].is_empty():
		lines.append("   (None)")
	else:
		for cat in inst["active_policies"]:
			var pol: Dictionary = inst["active_policies"][cat]
			lines.append("   - %-12s: %s [%s]" % [cat.capitalize(), pol["name"], pol["department"].capitalize()])
			
	lines.append(" Active Executive Orders:")
	if inst["active_orders"].is_empty():
		lines.append("   (None)")
	else:
		for ord in inst["active_orders"]:
			var dur_str: String = "Indefinite" if ord["duration_ticks"] <= 0 else ("%d / %d ticks" % [ord["ticks_elapsed"], ord["duration_ticks"]])
			lines.append("   - [%s] %s | Elapsed: %s" % [ord["department"].to_upper(), ord["name"], dur_str])
			
	return "\n".join(lines)

static func render_incidents_dashboard(ws: WorldState) -> String:
	var inc_sum: Dictionary = SimulationReader.get_incidents_summary(ws)
	var lines: Array[String] = [
		"--- [ SYSTEMIC INCIDENTS & TELEMETRY ALERTS ] ----------------------------------",
		" Active Incidents: %-2d (%-2d Critical/Emergency) | Resolved Historical: %-3d" % [
			inc_sum["active_count"], inc_sum["critical_count"], inc_sum["resolved_count"]
		]
	]
	
	if inc_sum["active_incidents"].is_empty():
		lines.append("   (All telemetry metrics within nominal bounds — No active incidents)")
	else:
		for inc in inc_sum["active_incidents"]:
			var sev_str: String = inc["severity_name"]
			var dur_str: String = "%d ticks" % inc["duration_ticks"]
			lines.append("   ! [%s] %s (ID %d, Duration: %s)" % [sev_str, inc["title"], inc["id"], dur_str])
			lines.append("     Detail: %s" % inc["description"])
			
	return "\n".join(lines)

static func render_full_status_report(ws: WorldState) -> String:
	var sections: Array[String] = [
		render_header(ws),
		render_population_dashboard(ws),
		render_economy_dashboard(ws),
		render_machinery_dashboard(ws),
		render_utilities_dashboard(ws),
		render_institutions_dashboard(ws),
		render_incidents_dashboard(ws),
		"================================================================================"
	]
	return "\n\n".join(sections)
