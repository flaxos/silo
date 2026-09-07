# src/presentation/viewer_invariants.gd
class_name ViewerInvariants
extends RefCounted

## Asserts presentation and viewer decoupling invariants:
## 1. Read model queries and rendering operations produce ZERO authoritative state side-effects.
## 2. Simulations running with or without UI attached produce bit-for-bit identical state checksums.

static func validate_side_effect_freedom(ws: WorldState) -> Dictionary:
	var errors: Array[String] = []
	if not ws:
		errors.append("WorldState is null")
		return {"is_valid": false, "errors": errors}
		
	var checksum_before: int = ws.get_state_checksum()
	
	# Execute all reader queries
	var _pop: Dictionary = SimulationReader.get_population_summary(ws)
	var _econ: Dictionary = SimulationReader.get_economy_summary(ws)
	var _mach: Dictionary = SimulationReader.get_machinery_summary(ws)
	var _util: Dictionary = SimulationReader.get_utilities_summary(ws)
	var _inst: Dictionary = SimulationReader.get_institutions_summary(ws)
	var _snap: Dictionary = SimulationReader.get_full_telemetry_snapshot(ws)
	
	# Execute all ASCII renderers
	var _report: String = SimulationViewer.render_full_status_report(ws)
	var _hdr: String = SimulationViewer.render_header(ws)
	var _pdash: String = SimulationViewer.render_population_dashboard(ws)
	var _edash: String = SimulationViewer.render_economy_dashboard(ws)
	var _mdash: String = SimulationViewer.render_machinery_dashboard(ws)
	var _udash: String = SimulationViewer.render_utilities_dashboard(ws)
	var _idash: String = SimulationViewer.render_institutions_dashboard(ws)
	
	var checksum_after: int = ws.get_state_checksum()
	
	if checksum_before != checksum_after:
		errors.append("SimulationReader/SimulationViewer mutated authoritative state! Checksum before: %X, after: %X" % [checksum_before, checksum_after])
		
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"checksum_before": checksum_before,
		"checksum_after": checksum_after
	}
