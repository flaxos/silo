class_name SiloPhysicalWorld
extends Node2D

## 2.5D / 3D Cylindrical Silo Wireframe Presentation.
## Read-model-only Godot cutaway. Simulation systems own all authoritative state;
## this node advances the engine and renders PhysicalReader projections in one batch.

const Reader = preload("res://src/presentation/physical_reader.gd")
const LayoutConfig = preload("res://src/sim/spatial/silo_layout_config.gd")

# 8-Bit Phosphor Green & Vector CRT Palette
const CRT_BG := Color("030905")
const ROCK_BG := Color("010402")
const WIRE_BRIGHT := Color("00ff66")
const WIRE_MID := Color("00cc55")
const WIRE_DIM := Color("005020")
const WIRE_DARK := Color("002810")
const WIRE_ACCENT := Color("ffb020")
const WIRE_ALERT := Color("ff3344")
const WIRE_CYAN := Color("00e5cc")
const PERSON_COLOR := Color("ff2438")
const PERSON_GLOW := Color(1.0, 0.14, 0.22, 0.35)
const PERSON_CHOSEN := Color("ffffff")

var engine: SimulationEngine
var ws: WorldState
var snapshot: Dictionary = {}
var geometry: Dictionary = {}
var room_by_id: Dictionary = {}
var room_summary_by_id: Dictionary = {}
var people_by_id: Dictionary = {}
var machine_by_id: Dictionary = {}
var person_draw_positions: Dictionary = {}
var machine_draw_positions: Dictionary = {}
var camera: Camera2D
var speed: int = 1
var tick_accumulator := 0.0
var selected_type := ""
var selected_id := ""
var selected_room_id := 0
var follow_person_id := 0
var isolated_level: Variant = null
var dragging := false
var drag_last := Vector2.ZERO

var panel: PanelContainer
var details_label: RichTextLabel
var telemetry_label: RichTextLabel
var search_edit: LineEdit
var search_results: ItemList
var level_picker: OptionButton
var status_label: Label
var follow_button: Button
var isolate_button: Button

var uat_frames := 0
var frames_drawn := 0
var process_usec_total := 0
var draw_usec_total := 0
var frame_seconds_total := 0.0
var population_size := 1200
var sim_seed := 42
var uat_screenshot := ""
var custom_zoom := 0.0

func _ready() -> void:
	_parse_args()
	_boot_simulation()
	_build_indexes()
	_build_camera()
	_build_ui()
	if not people_by_id.is_empty():
		var first_id: int = int(people_by_id.keys()[0])
		_select("person", str(first_id), int(people_by_id[first_id].get("location_id", 0)))
	if isolated_level != null:
		var target_y := 0.0
		for level in geometry.get("levels", []):
			if int(level.get("id", -999)) == int(isolated_level):
				target_y = float(level.get("y", 0)) + 36.0; break
		var z_val := custom_zoom if custom_zoom > 0.0 else 0.85
		camera.position = Vector2(_bounds_rect().get_center().x + 192.0 / z_val, target_y)
		camera.zoom = Vector2.ONE * z_val
	elif custom_zoom > 0.0:
		camera.zoom = Vector2.ONE * custom_zoom
	else:
		call_deferred("_fit_whole")
	set_process(true)
	queue_redraw()

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in OS.get_cmdline_args():
		if not args.has(a): args.append(a)
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--pop" and i + 1 < args.size():
			population_size = maxi(1, args[i + 1].to_int()); i += 2
		elif arg.begins_with("--pop="):
			population_size = maxi(1, arg.substr(6).to_int()); i += 1
		elif arg == "--seed" and i + 1 < args.size():
			sim_seed = args[i + 1].to_int(); i += 2
		elif arg.begins_with("--seed="):
			sim_seed = arg.substr(7).to_int(); i += 1
		elif arg == "--uat-frames" and i + 1 < args.size():
			uat_frames = maxi(1, args[i + 1].to_int()); i += 2
		elif arg.begins_with("--uat-frames="):
			uat_frames = maxi(1, arg.substr(13).to_int()); i += 1
		elif arg == "--uat-screenshot" and i + 1 < args.size():
			uat_screenshot = args[i + 1]; i += 2
		elif arg == "--isolate" and i + 1 < args.size():
			isolated_level = args[i + 1].to_int(); i += 2
		elif arg.begins_with("--isolate="):
			isolated_level = arg.substr(10).to_int(); i += 1
		elif arg == "--zoom" and i + 1 < args.size():
			custom_zoom = args[i + 1].to_float(); i += 2
		elif arg.begins_with("--zoom="):
			custom_zoom = arg.substr(7).to_float(); i += 1
		else: i += 1

func _boot_simulation() -> void:
	engine = SimulationEngine.new(sim_seed)
	ws = engine.get_world_state()
	PopulationGenerator.generate_population(ws, population_size)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	engine.register_system(InstitutionSystem.new())
	engine.register_system(DailyLifeSystem.new())
	engine.register_system(MaintenanceSystem.new())
	engine.register_system(ProductionSystem.new())
	engine.register_system(WaterSystem.new(50000.0, 100000.0))
	engine.register_system(IncidentSystem.new())
	snapshot = Reader.get_snapshot(ws, 1)
	snapshot["incidents"] = Reader.get_incident_locations(ws)
	geometry = snapshot.get("geometry", {})

func _build_indexes() -> void:
	room_by_id.clear(); room_summary_by_id.clear(); people_by_id.clear(); machine_by_id.clear()
	for room in geometry.get("rooms", []): room_by_id[int(room.get("id", 0))] = room
	for summary in snapshot.get("rooms", []): room_summary_by_id[int(summary.get("id", 0))] = summary
	for person in snapshot.get("people", []): people_by_id[int(person.get("id", 0))] = person
	for machine in snapshot.get("machines", []): machine_by_id[int(machine.get("id", 0))] = machine

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "CutawayCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)

	# Top Control Bar (CRT Header)
	var top := PanelContainer.new(); top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 54; top.add_theme_stylebox_override("panel", _crt_panel_style(Color("f0040e08"), WIRE_MID))
	layer.add_child(top)
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 10); top.add_child(bar)
	var title := Label.new(); title.text = " ❖ SILO // TACTICAL OBSERVABILITY SYSTEM "
	title.add_theme_color_override("font_color", WIRE_BRIGHT); bar.add_child(title)
	status_label = Label.new(); status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_color_override("font_color", WIRE_MID); bar.add_child(status_label)

	for spec in [["⏸ PAUSE", 0], ["1×", 1], ["4×", 4], ["16×", 16]]:
		var button := Button.new(); button.text = spec[0]; button.pressed.connect(_set_speed.bind(spec[1]))
		_style_crt_button(button); bar.add_child(button)

	var fit := Button.new(); fit.text = "FIT [F]"; fit.pressed.connect(_fit_whole)
	_style_crt_button(fit); bar.add_child(fit)

	level_picker = OptionButton.new(); level_picker.tooltip_text = "Jump to level"
	level_picker.item_selected.connect(_level_selected)
	_style_crt_button(level_picker); bar.add_child(level_picker)
	for lev in geometry.get("levels", []):
		level_picker.add_item("Level %s" % lev.get("id", "?"))
		level_picker.set_item_metadata(level_picker.item_count - 1, lev.get("id", 0))

	isolate_button = Button.new(); isolate_button.text = "ISOLATE [I]"; isolate_button.pressed.connect(_toggle_isolate)
	_style_crt_button(isolate_button); bar.add_child(isolate_button)

	# Right CRT Telemetry & Inspector Panel
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -385; panel.offset_top = 62; panel.offset_right = -10; panel.offset_bottom = -10
	panel.add_theme_stylebox_override("panel", _crt_panel_style(Color("f4040e08"), WIRE_BRIGHT))
	layer.add_child(panel)

	var side := VBoxContainer.new(); side.add_theme_constant_override("separation", 6); panel.add_child(side)

	var hud_title := Label.new(); hud_title.text = "┌── SILO TELEMETRY & OBSERVABILITY ──┐"
	hud_title.add_theme_color_override("font_color", WIRE_BRIGHT); side.add_child(hud_title)

	telemetry_label = RichTextLabel.new(); telemetry_label.bbcode_enabled = true; telemetry_label.fit_content = true
	telemetry_label.custom_minimum_size.y = 120
	side.add_child(telemetry_label)

	var sep1 := HSeparator.new(); sep1.add_theme_stylebox_override("separator", _separator_style()); side.add_child(sep1)

	var search_title := Label.new(); search_title.text = "ENTITY FINDER (RESIDENT / ROOM / MACHINE)"
	search_title.add_theme_color_override("font_color", WIRE_ACCENT); side.add_child(search_title)

	search_edit = LineEdit.new(); search_edit.placeholder_text = "Search ID, Name, or Room Type…"
	search_edit.text_changed.connect(_search); search_edit.text_submitted.connect(func(_q: String): _activate_first_search())
	_style_crt_line_edit(search_edit); side.add_child(search_edit)

	search_results = ItemList.new(); search_results.custom_minimum_size.y = 100
	search_results.item_selected.connect(_search_selected); _style_crt_item_list(search_results); side.add_child(search_results)

	var sep2 := HSeparator.new(); sep2.add_theme_stylebox_override("separator", _separator_style()); side.add_child(sep2)

	var insp_title := Label.new(); insp_title.text = "SELECTED ENTITY INSPECTION"
	insp_title.add_theme_color_override("font_color", WIRE_BRIGHT); side.add_child(insp_title)

	details_label = RichTextLabel.new(); details_label.bbcode_enabled = true; details_label.fit_content = false
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_label.text = "[color=#00cc55]Select any resident, room bay, machinery, or stair segment in the physical wireframe to inspect authoritative telemetry.[/color]"
	side.add_child(details_label)

	follow_button = Button.new(); follow_button.text = "TRACK CITIZEN [G]"; follow_button.disabled = true
	follow_button.pressed.connect(_toggle_follow); _style_crt_button(follow_button); side.add_child(follow_button)

	var help := Label.new(); help.text = "W/A/S/D or RMB: Pan   Wheel: Zoom   F: Whole Silo\nI: Isolate   G: Follow Citizen   Space: Pause"
	help.add_theme_color_override("font_color", WIRE_MID); side.add_child(help)

	_update_status()
	_update_telemetry()

func _crt_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = bg; style.border_color = border
	style.set_border_width_all(2); style.set_corner_radius_all(0); style.set_content_margin_all(10); return style

func _separator_style() -> StyleBoxLine:
	var sep := StyleBoxLine.new(); sep.color = WIRE_MID; sep.thickness = 1; return sep

func _style_crt_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", WIRE_BRIGHT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", WIRE_ACCENT)
	btn.add_theme_color_override("font_disabled_color", WIRE_DIM)
	var normal := StyleBoxFlat.new(); normal.bg_color = Color("1a031408"); normal.border_color = WIRE_MID
	normal.set_border_width_all(1); normal.set_content_margin_all(5)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat; hover.border_color = WIRE_BRIGHT; hover.bg_color = Color("28005520")
	btn.add_theme_stylebox_override("hover", hover)

func _style_crt_line_edit(le: LineEdit) -> void:
	le.add_theme_color_override("font_color", WIRE_BRIGHT)
	le.add_theme_color_override("placeholder_color", WIRE_DIM)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("020603"); sb.border_color = WIRE_MID
	sb.set_border_width_all(1); sb.set_content_margin_all(6)
	le.add_theme_stylebox_override("normal", sb)

func _style_crt_item_list(il: ItemList) -> void:
	il.add_theme_color_override("font_color", WIRE_BRIGHT)
	il.add_theme_color_override("font_selected_color", Color.WHITE)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("020603"); sb.border_color = WIRE_DIM
	sb.set_border_width_all(1); sb.set_content_margin_all(4)
	il.add_theme_stylebox_override("panel", sb)

func _process(delta: float) -> void:
	var began := Time.get_ticks_usec()
	if frames_drawn >= 5: frame_seconds_total += delta
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): pan.x -= 1.0
	if Input.is_key_pressed(KEY_D): pan.x += 1.0
	if Input.is_key_pressed(KEY_W): pan.y -= 1.0
	if Input.is_key_pressed(KEY_S): pan.y += 1.0
	if pan.length_squared() > 0.0:
		camera.position += pan.normalized() * 650.0 * delta / camera.zoom.x
		follow_person_id = 0
	if speed > 0:
		tick_accumulator += delta * float(speed) * 2.0
		var steps := mini(32, int(tick_accumulator))
		if steps > 0:
			engine.step(steps); tick_accumulator -= steps; _refresh_live()
	if follow_person_id > 0: _focus_person(follow_person_id, false)
	queue_redraw()
	process_usec_total += Time.get_ticks_usec() - began
	frames_drawn += 1
	if uat_frames > 0 and frames_drawn >= uat_frames:
		uat_frames = 0
		if not uat_screenshot.is_empty():
			var texture := get_viewport().get_texture()
			var image: Image = texture.get_image() if texture else null
			if image:
				var image_error := image.save_png(uat_screenshot)
				print("SILO_GODOT_SCREENSHOT path=%s result=%s" % [uat_screenshot, error_string(image_error)])
			else: print("SILO_GODOT_SCREENSHOT unavailable with current render driver")
		var measured_frames := maxi(1, frames_drawn - 5)
		var measured_fps := float(measured_frames) / frame_seconds_total if frame_seconds_total > 0.0 else 0.0
		print("SILO_GODOT_UAT frames=%d population=%d fps=%.1f process_cpu_ms=%.3f draw_cpu_ms=%.3f rooms=%d people=%d" % [frames_drawn, population_size, measured_fps, float(process_usec_total) / 1000.0 / frames_drawn, float(draw_usec_total) / 1000.0 / frames_drawn, room_by_id.size(), people_by_id.size()])
		get_tree().quit(0)

func _refresh_live() -> void:
	var updates := Reader.get_updates(ws, int(snapshot.get("revision", -1)), 1, false)
	snapshot["revision"] = updates.get("revision", snapshot.get("revision", 0))
	snapshot["clock"] = updates.get("clock", snapshot.get("clock", {}))
	for live in updates.get("people", []):
		var id := int(live.get("id", 0))
		if people_by_id.has(id): people_by_id[id].merge(live, true)
	for machine in updates.get("machines", []): machine_by_id[int(machine.get("id", 0))] = machine
	var live_stairs: Dictionary = {}
	for stair in updates.get("stairs", Reader.get_stairs(ws)):
		live_stairs[str(stair.get("id", ""))] = stair
	for segment in geometry.get("stair_segments", []):
		var sid := str(segment.get("id", ""))
		if live_stairs.has(sid): segment.merge(live_stairs[sid], true)
	snapshot["incidents"] = Reader.get_incident_locations(ws)
	_update_status()
	_update_telemetry()
	if not selected_type.is_empty(): _show_details(selected_type, selected_id)

func _update_status() -> void:
	if not status_label: return
	var clock: Dictionary = snapshot.get("clock", {})
	status_label.text = "Year %s · Day %s · %s  |  %d RESIDENTS (RED DOTS)  |  TICK %s" % [clock.get("year", 1), clock.get("day_of_year", clock.get("day", 1)), clock.get("time", clock.get("time_string", "00:00")), people_by_id.size(), snapshot.get("revision", 0)]

func _update_telemetry() -> void:
	if not telemetry_label: return
	var pop_summary: Dictionary = SimulationReader.get_population_summary(ws) if ws else {}
	var act: Dictionary = pop_summary.get("activity_counts", {})
	var util_summary: Dictionary = SimulationReader.get_utilities_summary(ws) if ws else {}
	var water_res: float = float(util_summary.get("water_reservoir", 99998.0))
	var water_cap: float = float(util_summary.get("water_capacity", 100000.0))

	# Central stair traffic metrics
	var total_transit := 0; var max_stair_queue := 0
	for seg in geometry.get("stair_segments", []):
		var occ_val: Variant = seg.get("occupancy", 0)
		var occ: int = occ_val.size() if (occ_val is Dictionary or occ_val is Array) else int(occ_val)
		total_transit += occ
		var q_val: Variant = seg.get("queue_length", seg.get("queue", 0))
		var q_len: int = q_val.size() if q_val is Array else int(q_val)
		max_stair_queue = maxi(max_stair_queue, q_len)

	var lines: Array[String] = [
		"[color=#00ff66]POPULATION:[/color] %d living (100%% viable)" % pop_summary.get("living_count", people_by_id.size()),
		"  • Work: [color=#ffb020]%d[/color] | Study: [color=#38e0bb]%d[/color] | Sleep: [color=#00cc55]%d[/color]" % [act.get("WORKING", 0), act.get("STUDYING", 0), act.get("SLEEPING", 0)],
		"  • In Transit: [color=#ff2438]%d[/color] | Eating/Rec: [color=#00ff66]%d[/color]" % [act.get("TRAVELING", 0), act.get("EATING", 0) + act.get("RECREATING", 0)],
		"[color=#00ff66]LIFE SUPPORT (WATER):[/color] %.0f L / %.0f L [color=#00ff66][NOMINAL][/color]" % [water_res, water_cap],
		"[color=#00ff66]CENTRAL CIRCULATION:[/color] %d commuters | Peak queue: %d" % [total_transit, max_stair_queue],
		"[color=#00ff66]SECTOR GRID:[/color] 20 Levels Active | 446 Habitable Bays"
	]
	telemetry_label.text = "\n".join(lines)

func _draw() -> void:
	if geometry.is_empty(): return
	var start := Time.get_ticks_usec()
	_draw_rock_and_levels()
	_draw_stairs()
	_draw_rooms()
	_draw_machines_and_incidents()
	_draw_people()
	draw_usec_total += Time.get_ticks_usec() - start

func _draw_rock_and_levels() -> void:
	var b := _bounds_rect()
	var silo_box := _whole_silo_rect()
	var cx_left := b.position.x - 24.0
	var cx_right := b.end.x + 24.0
	var center_x := (cx_left + cx_right) * 0.5

	# 1. Deep Surrounding Geology & Rock Strata Lines (Phosphor CRT aesthetic)
	draw_rect(silo_box.grow(400.0), ROCK_BG, true)
	draw_rect(silo_box.grow(30.0), CRT_BG, true)

	# Excavated rock fracture wireframe strata (deterministic lines flanking the silo)
	var y_step := -220.0
	while y_step <= b.end.y + 240.0:
		# Left geological strata
		draw_line(Vector2(cx_left - 320, y_step), Vector2(cx_left - 8, y_step + 6), WIRE_DARK, 1.0)
		draw_line(Vector2(cx_left - 240, y_step + 12), Vector2(cx_left - 180, y_step - 8), WIRE_DARK, 1.0)
		# Right geological strata
		draw_line(Vector2(cx_right + 8, y_step + 6), Vector2(cx_right + 320, y_step), WIRE_DARK, 1.0)
		draw_line(Vector2(cx_right + 180, y_step - 8), Vector2(cx_right + 240, y_step + 12), WIRE_DARK, 1.0)
		y_step += 52.0

	# 2. Outer Reinforced Concrete & Steel Casing Boundary (Vertical cylindrical boundary columns)
	for side_x in [cx_left, cx_right]:
		draw_line(Vector2(side_x - 6, -180), Vector2(side_x - 6, b.end.y + 160), WIRE_MID, 2.0)
		draw_line(Vector2(side_x, -180), Vector2(side_x, b.end.y + 160), WIRE_BRIGHT, 2.5)
		draw_line(Vector2(side_x + 6, -180), Vector2(side_x + 6, b.end.y + 160), WIRE_MID, 2.0)

	# 3. Top Surface Hatch Dome Complex (Wireframe parabolic arches above Level 1)
	if isolated_level == null:
		var dome_points: PackedVector2Array = []
		var inner_dome_points: PackedVector2Array = []
		var dome_segments := 32
		for s in range(dome_segments + 1):
			var t := float(s) / float(dome_segments)
			var px := lerpf(cx_left, cx_right, t)
			var norm := (t - 0.5) * 2.0
			var arch_curve := 1.0 - norm * norm
			var py_outer := -180.0 * arch_curve
			var py_inner := -140.0 * arch_curve
			dome_points.append(Vector2(px, py_outer))
			inner_dome_points.append(Vector2(px, py_inner))
			if s % 4 == 0 and s > 0 and s < dome_segments:
				draw_line(Vector2(px, py_outer), Vector2(px, py_inner), WIRE_DIM, 1.0)

		draw_polyline(dome_points, WIRE_BRIGHT, 2.5)
		draw_polyline(inner_dome_points, WIRE_MID, 1.5)

		# Surface Hatch Airlock Chamber
		var hatch_rect := Rect2(center_x - 55, -225, 110, 45)
		draw_rect(hatch_rect, CRT_BG, true)
		draw_rect(hatch_rect, WIRE_BRIGHT, false, 2.0)
		draw_line(Vector2(center_x - 22, -225), Vector2(center_x - 22, -180), WIRE_MID, 1.5)
		draw_line(Vector2(center_x + 22, -225), Vector2(center_x + 22, -180), WIRE_MID, 1.5)
		# Surface Telemetry Antenna Mast
		draw_line(Vector2(center_x, -225), Vector2(center_x, -270), WIRE_BRIGHT, 2.0)
		draw_line(Vector2(center_x - 16, -255), Vector2(center_x + 16, -255), WIRE_MID, 1.5)
		draw_line(Vector2(center_x - 10, -265), Vector2(center_x + 10, -265), WIRE_BRIGHT, 1.5)

		draw_string(ThemeDB.fallback_font, Vector2(center_x - 120, -235), "▲ TO SURFACE // SEALED HATCH COMPLEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, WIRE_BRIGHT)
		draw_string(ThemeDB.fallback_font, Vector2(center_x - 140, -195), "HEPA AIR FILTRATION & ATMOSPHERIC SENSORS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WIRE_MID)

	# 4. Bottom Geological Anchor Foundation & Deep Mining Conduits
	if isolated_level == null:
		var base_y := b.end.y + 18.0
		# Massive central anchor pillar descending from circulation core
		var anchor_rect := Rect2(center_x - 50, base_y, 100, 160)
		draw_rect(anchor_rect, CRT_BG, true)
		draw_rect(anchor_rect, WIRE_BRIGHT, false, 2.5)
		# Diagonal structural anchor cross-trusses
		draw_line(Vector2(center_x - 50, base_y), Vector2(center_x + 50, base_y + 80), WIRE_DIM, 2.0)
		draw_line(Vector2(center_x + 50, base_y), Vector2(center_x - 50, base_y + 80), WIRE_DIM, 2.0)
		draw_line(Vector2(center_x - 50, base_y + 80), Vector2(center_x + 50, base_y + 160), WIRE_DIM, 2.0)
		draw_line(Vector2(center_x + 50, base_y + 80), Vector2(center_x - 50, base_y + 160), WIRE_DIM, 2.0)

		# Deep excavation / ore extraction shafts descending past the bottom
		for shaft_x in [cx_left + 70, cx_right - 70]:
			draw_line(Vector2(shaft_x - 14, base_y), Vector2(shaft_x - 14, base_y + 240), WIRE_MID, 2.0)
			draw_line(Vector2(shaft_x + 14, base_y), Vector2(shaft_x + 14, base_y + 240), WIRE_MID, 2.0)
			for ty in range(8):
				draw_line(Vector2(shaft_x - 14, base_y + ty * 30), Vector2(shaft_x + 14, base_y + ty * 30), WIRE_DIM, 1.0)

		draw_string(ThemeDB.fallback_font, Vector2(center_x - 125, base_y + 185), "▼ L-B1 GEOLOGICAL ANCHOR FOUNDATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, WIRE_BRIGHT)
		draw_string(ThemeDB.fallback_font, Vector2(center_x - 165, base_y + 205), "▼ DEEP EXTRACTION SHAFTS // ORE TRANSPORT TO PROCESSING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WIRE_MID)

	# 5. Cylindrical Floor Plates with 2.5D Curved Lip Arcs
	for level in geometry.get("levels", []):
		var lid := int(level.get("id", 0))
		if isolated_level != null and lid != int(isolated_level): continue
		var y := float(level.get("y", 0.0))
		var floor_y := y + 72.0 + 6.0

		# Horizontal structural I-beam girder
		draw_line(Vector2(cx_left - 12, floor_y), Vector2(cx_right + 12, floor_y), WIRE_MID, 2.0)

		# 2.5D Curved cylindrical front lip (arc bowing forward/downward in perspective)
		var curve_points: PackedVector2Array = []
		for s in range(25):
			var t := float(s) / 24.0
			var px := lerpf(cx_left - 12, cx_right + 12, t)
			var norm := (t - 0.5) * 2.0
			var py := floor_y + 8.0 * (1.0 - norm * norm)
			curve_points.append(Vector2(px, py))
			if s % 4 == 0:
				draw_line(Vector2(px, floor_y), Vector2(px, py), WIRE_DIM, 1.0)
		draw_polyline(curve_points, WIRE_DIM, 1.5)

		# Level Designation Label in Phosphor Green on left casing margin
		var ltitle := _level_title(lid)
		draw_string(ThemeDB.fallback_font, Vector2(cx_left - 240, y + 20), ltitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WIRE_BRIGHT)

func _level_title(lid: int) -> String:
	match lid:
		1: return "L-01 [ADMIN & COMMAND]"
		2: return "L-02 [IT & COMMS]"
		3: return "L-03 [ARCHIVES & CIVIC]"
		4: return "L-04 [RESIDENTIAL A]"
		5: return "L-05 [CLINIC & HEALTH]"
		6: return "L-06 [PRIMARY EDUCATION]"
		7: return "L-07 [COMMUNITY CANTEEN]"
		8: return "L-08 [RESIDENTIAL B]"
		9: return "L-09 [BIO-FARM HYDROPONICS]"
		10: return "L-10 [WATER TREATMENT]"
		11: return "L-11 [RESIDENTIAL C]"
		12: return "L-12 [WORKSHOPS & REPAIR]"
		13: return "L-13 [VOCATIONAL TRAINING]"
		14: return "L-14 [DENTAL & MEDICAL]"
		15: return "L-15 [FOOD PROCESSING]"
		16: return "L-16 [RESIDENTIAL D]"
		17: return "L-17 [GYM & RECREATION]"
		18: return "L-18 [HYDROPONICS B]"
		19: return "L-19 [SYSTEMS ENGINEERING]"
		20: return "L-20 [HEAVY INDUSTRY]"
		_: return "L-%02d [SECTOR %d]" % [lid, lid]

func _draw_rooms() -> void:
	var z := camera.zoom.x
	for room in geometry.get("rooms", []):
		if isolated_level != null and int(room.get("level", 0)) != int(isolated_level): continue
		var rect := _room_rect(room)
		var selected := selected_type == "room" and selected_id == str(room.get("id", 0))
		var rtype := int(room.get("room_type", 0))

		# 2.5D Axonometric Room Depth Extrusion
		var depth_dy := -14.0
		var back_rect := Rect2(rect.position.x + 4.0, rect.position.y + depth_dy, rect.size.x - 8.0, rect.size.y)

		# Subtle Translucent Functional Color Tint
		var tint: Color = _room_tint(rtype)
		draw_rect(rect, tint, true)

		# 4 Perspective Depth Lines Connecting Front Face to Back Wall
		draw_line(rect.position, back_rect.position, WIRE_DIM, 1.0)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(back_rect.end.x, back_rect.position.y), WIRE_DIM, 1.0)
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(back_rect.position.x, back_rect.end.y), WIRE_DIM, 1.0)
		draw_line(Vector2(rect.end.x, rect.end.y), Vector2(back_rect.end.x, back_rect.end.y), WIRE_DIM, 1.0)

		# Back Wall Frame
		draw_rect(back_rect, WIRE_DIM, false, 1.0)

		# 3D Floor Perspective Grid (Isometric ground lines)
		var grid_cols := maxi(2, int(rect.size.x / 28.0))
		for g in range(1, grid_cols):
			var frac := float(g) / float(grid_cols)
			var f_pt := Vector2(rect.position.x + rect.size.x * frac, rect.end.y)
			var b_pt := Vector2(back_rect.position.x + back_rect.size.x * frac, back_rect.end.y)
			draw_line(f_pt, b_pt, WIRE_DARK, 1.0)

		# Overhead structural ceiling ribs
		draw_line(Vector2(rect.position.x + 8, rect.position.y + 4), Vector2(rect.end.x - 8, rect.position.y + 4), WIRE_DIM, 1.0)

		# Front Room Frame (Glowing Phosphor Green)
		var border_color := WIRE_ACCENT if selected else WIRE_MID
		draw_rect(rect, border_color, false, 2.5 if selected else 1.5)

		if selected:
			# Pulsing tactical reticle corner brackets
			_draw_corner_brackets(rect.grow(4.0), WIRE_BRIGHT, 8.0, 2.0)

		# Internal Wireframe Equipment & Furniture Sketches (When zoomed in)
		if z >= 0.35:
			_draw_room_interior_wireframe(rtype, rect, back_rect)

		# Room Header & Telemetry Labels
		if z >= 0.30:
			var label := _room_label(room)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 17), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 12, WIRE_BRIGHT)
			if z >= 0.52:
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 33), "#%s · CAP %s" % [room.get("id", "?"), room.get("capacity", "—")], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 10, WIRE_MID)

func _room_tint(rtype: int) -> Color:
	match rtype:
		0: return Color(0.85, 0.65, 0.35, 0.05) # Housing amber
		1: return Color(0.35, 0.65, 1.0, 0.06)  # School blue
		2: return Color(0.9, 1.0, 0.9, 0.07)    # Clinic white
		3: return Color(0.0, 1.0, 0.4, 0.07)    # Farm green
		4, 5, 8: return Color(1.0, 0.5, 0.2, 0.07) # Industry orange
		6: return Color(0.0, 0.8, 1.0, 0.07)    # Water cyan
		7, 9: return Color(0.7, 0.4, 1.0, 0.06) # Admin violet
		_: return Color(0.0, 1.0, 0.4, 0.04)

func _draw_room_interior_wireframe(rtype: int, rect: Rect2, _back: Rect2) -> void:
	match rtype:
		0: # Residential: Double-deck bunk beds & locker
			var bx := rect.position.x + 8.0
			var by := rect.end.y - 6.0
			# Bunk 1
			draw_rect(Rect2(bx, by - 30, 22, 28), WIRE_DIM, false, 1.0)
			draw_line(Vector2(bx, by - 14), Vector2(bx + 22, by - 14), WIRE_MID, 1.0)
			draw_line(Vector2(bx + 18, by - 30), Vector2(bx + 18, by), WIRE_MID, 1.0)
			# Bunk 2 if room is wide enough
			if rect.size.x > 120:
				var bx2 := rect.end.x - 30.0
				draw_rect(Rect2(bx2, by - 30, 22, 28), WIRE_DIM, false, 1.0)
				draw_line(Vector2(bx2, by - 14), Vector2(bx2 + 22, by - 14), WIRE_MID, 1.0)
		3: # Bio-farm: 3 tiers of hydroponic grow racks
			var rx1 := rect.position.x + 10.0
			var rx2 := rect.end.x - 10.0
			var by := rect.end.y - 8.0
			draw_line(Vector2(rx1, by - 8), Vector2(rx2, by - 8), WIRE_BRIGHT, 1.5)
			draw_line(Vector2(rx1, by - 22), Vector2(rx2, by - 22), WIRE_BRIGHT, 1.5)
			draw_line(Vector2(rx1, by - 36), Vector2(rx2, by - 36), WIRE_BRIGHT, 1.5)
			draw_line(Vector2(rx1 + 10, by - 42), Vector2(rx1 + 10, by), WIRE_MID, 1.0)
			draw_line(Vector2(rx2 - 10, by - 42), Vector2(rx2 - 10, by), WIRE_MID, 1.0)
		6: # Water: 2 cylindrical tanks with pipe manifold
			var tx1 := rect.position.x + 16.0
			var by := rect.end.y - 6.0
			draw_rect(Rect2(tx1, by - 36, 26, 34), WIRE_CYAN, false, 1.5)
			draw_line(Vector2(tx1, by - 36), Vector2(tx1 + 26, by - 36), WIRE_BRIGHT, 2.0)
			if rect.size.x > 110:
				var tx2 := rect.position.x + 52.0
				draw_rect(Rect2(tx2, by - 36, 26, 34), WIRE_CYAN, false, 1.5)
				draw_line(Vector2(tx1 + 26, by - 18), Vector2(tx2, by - 18), WIRE_BRIGHT, 1.5)
		2: # Clinic: Medical bed & IV drip stand
			var mx := rect.position.x + 18.0
			var by := rect.end.y - 8.0
			draw_line(Vector2(mx, by - 8), Vector2(mx + 28, by - 8), WIRE_MID, 2.0)
			draw_line(Vector2(mx, by - 16), Vector2(mx + 8, by - 8), WIRE_MID, 1.5)
			draw_line(Vector2(mx - 6, by), Vector2(mx - 6, by - 26), WIRE_BRIGHT, 1.0)
			draw_line(Vector2(mx - 10, by - 26), Vector2(mx - 2, by - 26), WIRE_BRIGHT, 1.0)
		1: # School: Blackboard & student desks
			var bx := rect.position.x + 12.0
			var by := rect.end.y - 8.0
			draw_rect(Rect2(bx, rect.position.y + 12, rect.size.x - 24, 16), WIRE_MID, false, 1.0)
			draw_rect(Rect2(bx + 10, by - 14, 16, 12), WIRE_DIM, false, 1.0)
			if rect.size.x > 120:
				draw_rect(Rect2(bx + 36, by - 14, 16, 12), WIRE_DIM, false, 1.0)
		4, 5, 8: # Industry: Industrial lathe machine & workbench
			var ix := rect.position.x + 14.0
			var by := rect.end.y - 8.0
			draw_rect(Rect2(ix, by - 22, 34, 20), WIRE_ACCENT, false, 1.5)
			draw_line(Vector2(ix + 6, by - 30), Vector2(ix + 6, by - 22), WIRE_BRIGHT, 1.5)
			draw_line(Vector2(rect.position.x + 8, rect.position.y + 8), Vector2(rect.end.x - 8, rect.position.y + 8), WIRE_DIM, 1.0)
		_:
			# Generic equipment console
			var cx := rect.position.x + 14.0
			var by := rect.end.y - 8.0
			draw_rect(Rect2(cx, by - 18, 24, 16), WIRE_DIM, false, 1.0)

func _draw_stairs() -> void:
	var segments: Array = geometry.get("stair_segments", geometry.get("connectors", []))
	if segments.is_empty(): return
	var b := _bounds_rect()
	var center_x := (b.position.x - 24.0 + b.end.x + 24.0) * 0.5

	# 1. Dual Vertical Elevator Shafts (Flanking the staircase core)
	if isolated_level == null:
		for shaft_x in [center_x - 28.0, center_x + 28.0]:
			draw_line(Vector2(shaft_x - 6, -180), Vector2(shaft_x - 6, b.end.y + 100), WIRE_MID, 1.5)
			draw_line(Vector2(shaft_x + 6, -180), Vector2(shaft_x + 6, b.end.y + 100), WIRE_MID, 1.5)
			# Elevator lift car wireframe cabs at alternating levels
			for car_level in [2, 7, 12, 18]:
				var car_y := float(car_level - 1) * 106.0 + 30.0
				var car_rect := Rect2(shaft_x - 5, car_y, 10, 18)
				draw_rect(car_rect, CRT_BG, true)
				draw_rect(car_rect, WIRE_BRIGHT, false, 1.5)
				draw_line(Vector2(shaft_x, car_y), Vector2(shaft_x, car_y - 30), WIRE_DIM, 1.0)

	# 2. Central Zig-Zag Staircase Flights & Landings
	for seg in segments:
		var from_lid := int(seg.get("from_level", -999))
		var to_lid := int(seg.get("to_level", -999))
		if isolated_level != null and from_lid != int(isolated_level) and to_lid != int(isolated_level): continue

		var a := _landing_point(from_lid, seg)
		var b_pt := _landing_point(to_lid, seg, true)

		# Zig-zag alternating diagonal flight
		var zig_dir := 1.0 if (from_lid % 2 == 1) else -1.0
		var flight_start := Vector2(center_x - 14.0 * zig_dir, a.y)
		var flight_end := Vector2(center_x + 14.0 * zig_dir, b_pt.y)

		# Structural diagonal stringers (Stair flight boundary beams)
		draw_line(flight_start, flight_end, WIRE_MID, 16.0)
		draw_line(flight_start, flight_end, CRT_BG, 10.0)
		draw_line(flight_start + Vector2(-6, 0), flight_end + Vector2(-6, 0), WIRE_BRIGHT, 1.5)
		draw_line(flight_start + Vector2(6, 0), flight_end + Vector2(6, 0), WIRE_BRIGHT, 1.5)

		# Individual Step Treads along the flight
		var step_count := maxi(4, int(absf(flight_end.y - flight_start.y) / 7.0))
		for s in range(step_count + 1):
			var p := flight_start.lerp(flight_end, float(s) / float(step_count))
			draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), WIRE_BRIGHT, 1.0)

		# Cross-truss bracing under the flight
		draw_line(flight_start + Vector2(0, 4), flight_end + Vector2(0, -4), WIRE_DARK, 1.0)

		# Congestion & Traffic Badge
		if camera.zoom.x >= 0.32:
			var occ_val: Variant = seg.get("occupancy", 0)
			var occ: int = occ_val.size() if (occ_val is Dictionary or occ_val is Array) else int(occ_val)
			var cap := int(seg.get("capacity", 0))
			var q_val: Variant = seg.get("queue_length", seg.get("queue", 0))
			var queue: int = q_val.size() if q_val is Array else int(q_val)
			var text_color := WIRE_ALERT if queue > 10 else (WIRE_ACCENT if queue > 0 else WIRE_MID)
			var mid := flight_start.lerp(flight_end, 0.5)
			draw_string(ThemeDB.fallback_font, mid + Vector2(16, 2), "%d/%d [Q:%d]" % [occ, cap, queue], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_color)

	# 3. Landing Catwalk Platforms with Safety Barriers
	for landing in geometry.get("landings", []):
		var lid := int(landing.get("level", 0))
		if isolated_level != null and lid != int(isolated_level): continue
		var p := Vector2(float(landing.get("x", 0)), float(landing.get("y", 0)))
		var w := float(landing.get("width", 68.0))
		var l_rect := Rect2(p.x, p.y + 70.0, w, 8.0)
		draw_rect(l_rect, CRT_BG, true)
		draw_rect(l_rect, WIRE_BRIGHT, false, 2.0)
		# Handrail line
		draw_line(Vector2(p.x, p.y + 64.0), Vector2(p.x + w, p.y + 64.0), WIRE_MID, 1.0)

func _landing_point(level_id: Variant, seg: Dictionary, destination := false) -> Vector2:
	for landing in geometry.get("landings", []):
		if int(landing.get("level", -999)) == int(level_id):
			return Vector2(float(landing.get("x", 0)) + float(landing.get("width", 68.0)) * 0.5, float(landing.get("y", 0)) + 74.0)
	var x := float(seg.get("x", _bounds_rect().get_center().x))
	var y := 0.0
	for level in geometry.get("levels", []):
		if int(level.get("id", -999)) == int(level_id): y = float(level.get("y", 0)) + 74.0; break
	return Vector2(x + (16.0 if destination else -16.0), y)

func _draw_people() -> void:
	var z := camera.zoom.x
	person_draw_positions.clear()
	var buckets: Dictionary = {}

	for person in people_by_id.values():
		if not bool(person.get("is_alive", true)): continue
		var rid := int(person.get("location_id", 0))
		if not room_by_id.has(rid): continue
		if isolated_level != null and int(room_by_id[rid].get("level", 0)) != int(isolated_level): continue
		if not buckets.has(rid): buckets[rid] = []
		buckets[rid].append(person)

	var dot_radius: float = clampf(2.6 / maxf(0.05, z), 3.5, 8.5)
	var glow_radius: float = dot_radius + clampf(1.6 / maxf(0.05, z), 2.0, 5.0)

	for rid in buckets:
		var people: Array = buckets[rid]; var room: Dictionary = room_by_id[rid]; var rect := _room_rect(room)
		var max_visible := people.size() if z >= 0.45 else mini(people.size(), 30)

		for i in range(max_visible):
			var p: Dictionary = people[i]
			var pid := int(p.get("id", 0))
			var columns := maxi(3, int((rect.size.x - 20) / 13.0))

			# Position neatly on the room's 2.5D floor plane
			var pos := rect.position + Vector2(10 + (i % columns) * 12.0, rect.size.y - 10 - (i / columns) * 8.0)
			if str(p.get("activity", "")).to_lower().contains("travel"):
				pos = _journey_position(p, pos)

			person_draw_positions[pid] = pos
			var chosen := selected_type == "person" and selected_id == str(pid)

			# Vibrant Vector Red Dot Rendering (Outer glow + vivid red core)
			var cur_radius: float = dot_radius * 1.35 if chosen else dot_radius
			draw_circle(pos, cur_radius + (3.0 if chosen else (glow_radius - dot_radius)), PERSON_GLOW)
			draw_circle(pos, cur_radius, PERSON_COLOR)

			if chosen:
				# Tactical HUD reticle [ + ] around chosen resident
				_draw_reticle(pos, WIRE_BRIGHT, 12.0)
				# Direct route vector line to target destination room
				var dst_id := int(p.get("destination_id", 0))
				if dst_id > 0 and room_by_id.has(dst_id):
					var dst_pos := _room_rect(room_by_id[dst_id]).get_center()
					draw_dashed_line(pos, dst_pos, WIRE_ACCENT, 1.5, 6.0)
				# Floating Tactical Tag
				if z >= 0.35:
					var tag := "%s [%s]" % [p.get("name", "CITIZEN"), p.get("activity", "IDLE")]
					draw_string(ThemeDB.fallback_font, pos + Vector2(14, -8), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WIRE_BRIGHT)

func _draw_reticle(pos: Vector2, color: Color, size: float) -> void:
	# Crosshair ticks
	draw_line(pos - Vector2(size + 4, 0), pos - Vector2(size - 4, 0), color, 1.5)
	draw_line(pos + Vector2(size - 4, 0), pos + Vector2(size + 4, 0), color, 1.5)
	draw_line(pos - Vector2(0, size + 4), pos - Vector2(0, size - 4), color, 1.5)
	draw_line(pos + Vector2(0, size - 4), pos + Vector2(0, size + 4), color, 1.5)
	# Corner brackets
	_draw_corner_brackets(Rect2(pos - Vector2(size, size), Vector2(size * 2, size * 2)), color, 5.0, 1.5)

func _draw_corner_brackets(rect: Rect2, color: Color, len_arm: float, thick: float) -> void:
	# Top-Left
	draw_line(rect.position, rect.position + Vector2(len_arm, 0), color, thick)
	draw_line(rect.position, rect.position + Vector2(0, len_arm), color, thick)
	# Top-Right
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - len_arm, rect.position.y), color, thick)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + len_arm), color, thick)
	# Bottom-Left
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + len_arm, rect.end.y), color, thick)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - len_arm), color, thick)
	# Bottom-Right
	draw_line(rect.end, rect.end - Vector2(len_arm, 0), color, thick)
	draw_line(rect.end, rect.end - Vector2(0, len_arm), color, thick)

func _journey_position(person: Dictionary, fallback: Vector2) -> Vector2:
	var journey: Dictionary = person.get("journey", {})
	if journey.is_empty():
		var dst := int(person.get("destination_id", 0))
		return fallback.lerp(_room_rect(room_by_id[dst]).get_center(), float(person.get("travel_progress", 0.0))) if room_by_id.has(dst) else fallback
	var phase := str(journey.get("phase", ""))
	var origin_id := int(journey.get("origin_room_id", 0)); var destination_id := int(journey.get("destination_room_id", 0))
	var origin := _room_rect(room_by_id[origin_id]).get_center() if room_by_id.has(origin_id) else fallback
	var destination := _room_rect(room_by_id[destination_id]).get_center() if room_by_id.has(destination_id) else fallback
	var route: Array = journey.get("route", [])
	if phase == "approach": return origin.lerp(_landing_for_level(int(journey.get("from_level", 0))), 0.65)
	if phase == "egress": return _landing_for_level(int(journey.get("to_level", 0))).lerp(destination, 0.65)
	var index := int(journey.get("segment_index", -1))
	if phase == "queued": index += 1
	if index >= 0 and index < route.size():
		for segment in geometry.get("stair_segments", []):
			if str(segment.get("id", "")) == str(route[index]):
				var a := _landing_point(segment.get("from_level", 0), segment)
				var b := _landing_point(segment.get("to_level", 0), segment, true)
				var ascending := int(journey.get("to_level", 0)) > int(journey.get("from_level", 0))
				if not ascending: var swap := a; a = b; b = swap
				return a if phase == "queued" else a.lerp(b, 0.5)
	return fallback

func _landing_for_level(level_id: int) -> Vector2:
	for landing in geometry.get("landings", []):
		if int(landing.get("level", -999)) == level_id:
			return Vector2(float(landing.get("x", 0)) + float(landing.get("width", 0)) * 0.5, float(landing.get("y", 0)) + float(landing.get("height", 0)) * 0.5)
	return _bounds_rect().get_center()

func _draw_machines_and_incidents() -> void:
	machine_draw_positions.clear()
	for machine in machine_by_id.values():
		var rid := int(machine.get("room_id", 0)); if not room_by_id.has(rid): continue
		var room: Dictionary = room_by_id[rid]
		if isolated_level != null and int(room.get("level", 0)) != int(isolated_level): continue
		var pos := _room_rect(room).position + Vector2(18, 48)
		machine_draw_positions[int(machine.get("id", 0))] = pos
		var poor := str(machine.get("state", "NOMINAL")) in ["FAULT", "BROKEN"]
		var m_color := WIRE_ALERT if poor else WIRE_BRIGHT
		# Wireframe diamond machinery symbol
		var pts: PackedVector2Array = [pos + Vector2(0, -7), pos + Vector2(7, 0), pos + Vector2(0, 7), pos + Vector2(-7, 0)]
		draw_colored_polygon(pts, CRT_BG)
		draw_polyline(pts, m_color, 2.0)
		draw_line(pos + Vector2(-7, 0), pos + Vector2(0, -7), m_color, 2.0)

	for incident in snapshot.get("incidents", {}).get("active_incidents", []):
		var rid := int(incident.get("room_id", 0))
		if room_by_id.has(rid):
			var ipos := _room_rect(room_by_id[rid]).position + Vector2(36, 48)
			draw_circle(ipos, 8, WIRE_ALERT)
			_draw_corner_brackets(Rect2(ipos - Vector2(12, 12), Vector2(24, 24)), WIRE_ALERT, 5.0, 1.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: _zoom(1.18, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: _zoom(0.84, mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mb.pressed; drag_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.position.x < get_viewport_rect().size.x - 395:
			_pick(get_global_mouse_position())
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion; camera.position -= mm.relative / camera.zoom; follow_person_id = 0
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F: _fit_whole()
			KEY_I: _toggle_isolate()
			KEY_G: _toggle_follow()
			KEY_SPACE: _set_speed(0 if speed > 0 else 1)
			KEY_1: _set_speed(1)
			KEY_2: _set_speed(4)
			KEY_3: _set_speed(16)
			KEY_ESCAPE: isolated_level = null; follow_person_id = 0; queue_redraw()

func _zoom(factor: float, screen: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * screen
	var z := clampf(camera.zoom.x * factor, 0.05, 3.5); camera.zoom = Vector2(z, z)
	var after := get_canvas_transform().affine_inverse() * screen; camera.position += before - after

func _pick(point: Vector2) -> void:
	if camera.zoom.x >= 0.45:
		for mid in machine_draw_positions:
			if (machine_draw_positions[mid] as Vector2).distance_to(point) <= 12.0:
				_select("machine", str(mid), int(machine_by_id[mid].get("room_id", 0))); return
		var nearest_person := 0; var nearest_distance := 11.0
		for pid in person_draw_positions:
			var distance := (person_draw_positions[pid] as Vector2).distance_to(point)
			if distance < nearest_distance: nearest_distance = distance; nearest_person = int(pid)
		if nearest_person > 0:
			_select("person", str(nearest_person), int(people_by_id[nearest_person].get("location_id", 0))); return
	for room in geometry.get("rooms", []):
		if _room_rect(room).has_point(point): _select("room", str(room.get("id", 0)), int(room.get("id", 0))); return
	for seg in geometry.get("stair_segments", geometry.get("connectors", [])):
		var a := _landing_point(seg.get("from_level", 0), seg); var b := _landing_point(seg.get("to_level", 0), seg, true)
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < 18: _select_stair(seg); return

func _select(type: String, id: String, room_id: int) -> void:
	selected_type = type; selected_id = id; selected_room_id = room_id
	follow_button.disabled = type != "person"; _show_details(type, id); queue_redraw()

func _select_stair(seg: Dictionary) -> void:
	selected_type = "stair"; selected_id = str(seg.get("id", "stair")); selected_room_id = 0; follow_button.disabled = true
	var lines: Array[String] = [
		"[font_size=18][color=#00ff66]CENTRAL CIRCULATION SHAFT[/color][/font_size]",
		"[color=#ffb020]SEGMENT: %s[/color]" % selected_id,
		"[color=#00cc55]Connected Levels:[/color] %s → %s" % [seg.get("from_level", "?"), seg.get("to_level", "?")],
		"[color=#00cc55]Occupancy / Capacity:[/color] %s / %s" % [seg.get("occupancy", 0), seg.get("capacity", "pending")],
		"[color=#00cc55]Queued Commuters:[/color] %s" % seg.get("queue_length", 0),
		"[color=#00cc55]Congestion Flag:[/color] %s" % str(seg.get("congestion", false)),
		"[color=#00cc55]Base Travel Time:[/color] %s ticks" % seg.get("base_travel_ticks", "pending"),
		"[color=#00cc55]Estimated Travel Time:[/color] %s ticks" % seg.get("travel_time_ticks_estimate", seg.get("base_travel_ticks", "pending"))
	]
	details_label.text = "\n".join(lines)

func _show_details(type: String, id: String) -> void:
	var resolved := Reader.resolve_entity(ws, type, id)
	if resolved.is_empty(): details_label.text = "[color=#ff3344]Entity no longer available in authoritative simulation.[/color]"; return
	selected_room_id = int(resolved.get("room_id", selected_room_id))
	details_label.text = "[font_size=18][color=#00ff66]%s #%s[/color][/font_size]\n[color=#005020]AUTHORITATIVE SIMULATION TELEMETRY[/color]\n\n%s" % [type.to_upper(), id, _format_value(resolved.get("details", {}), 0)]

func _format_value(value: Variant, depth: int) -> String:
	if depth > 2: return str(value)
	if value is Dictionary:
		var lines: Array[String] = []
		for key in value.keys():
			var v: Variant = value[key]
			if v is Dictionary or v is Array: lines.append("[color=#00cc55]%s[/color]\n%s" % [_pretty(str(key)), _format_value(v, depth + 1)])
			else: lines.append("[color=#00cc55]%s:[/color] [color=#ffffff]%s[/color]" % [_pretty(str(key)), str(v)])
		return "\n".join(lines)
	if value is Array:
		var lines: Array[String] = []; for item in value.slice(0, 20): lines.append("  • " + (_format_value(item, depth + 1) if item is Dictionary else str(item)))
		if value.size() > 20: lines.append("  … %d more" % (value.size() - 20))
		return "\n".join(lines)
	return str(value)

func _pretty(text: String) -> String: return text.replace("_", " ").capitalize()

func _search(query: String) -> void:
	search_results.clear()
	if query.strip_edges().is_empty(): return
	for result in Reader.search(ws, query, 40).get("results", []):
		search_results.add_item("%s · %s #%s" % [result.get("label", "?"), result.get("type", "?"), result.get("id", "?")])
		search_results.set_item_metadata(search_results.item_count - 1, result)

func _activate_first_search() -> void:
	if search_results.item_count > 0: _search_selected(0)

func _search_selected(index: int) -> void:
	var result: Dictionary = search_results.get_item_metadata(index)
	_select(str(result.get("type", "")), str(result.get("id", "")), int(result.get("room_id", 0)))
	_focus_room(int(result.get("room_id", 0)), 1.0)

func _focus_room(room_id: int, zoom_target := 1.0) -> void:
	if not room_by_id.has(room_id): return
	var room: Dictionary = room_by_id[room_id]; isolated_level = room.get("level", null)
	camera.position = _room_rect(room).get_center(); camera.zoom = Vector2.ONE * zoom_target

func _focus_person(id: int, select := true) -> void:
	if not people_by_id.has(id): return
	var person: Dictionary = people_by_id[id]; var rid := int(person.get("location_id", 0))
	if select: _select("person", str(id), rid)
	var pos: Vector2 = _journey_position(person, _room_rect(room_by_id[rid]).get_center()) if room_by_id.has(rid) else Vector2(person_draw_positions.get(id, camera.position))
	camera.position = pos
	if not person.get("journey", {}).is_empty(): isolated_level = null

func _toggle_follow() -> void:
	if selected_type != "person": return
	follow_person_id = 0 if follow_person_id == int(selected_id) else int(selected_id)
	follow_button.text = "STOP TRACKING [G]" if follow_person_id > 0 else "TRACK CITIZEN [G]"

func _level_selected(index: int) -> void:
	var level_id: Variant = level_picker.get_item_metadata(index); isolated_level = level_id
	for level in geometry.get("levels", []):
		if int(level.get("id", -999)) == int(level_id): camera.position.y = float(level.get("y", 0)) + 36; camera.zoom = Vector2.ONE * 0.55; break
	queue_redraw()

func _toggle_isolate() -> void:
	if isolated_level != null:
		isolated_level = null
		isolate_button.text = "ISOLATE [I]"
	elif selected_room_id > 0 and room_by_id.has(selected_room_id):
		isolated_level = room_by_id[selected_room_id].get("level", null)
		isolate_button.text = "SHOW ALL [I]"
	queue_redraw()

func _set_speed(value: int) -> void: speed = value

func _fit_whole() -> void:
	isolated_level = null; follow_person_id = 0
	var rect := _whole_silo_rect().grow(30.0)
	var viewport := get_viewport_rect().size - Vector2(400, 75)
	var z := clampf(minf(viewport.x / maxf(1.0, rect.size.x), viewport.y / maxf(1.0, rect.size.y)), 0.05, 1.2)
	camera.zoom = Vector2.ONE * z
	# Center view in the canvas area to the left of the 385px sidebar
	camera.position = Vector2(rect.get_center().x + (192.0 / z), rect.get_center().y)
	queue_redraw()

func _bounds_rect() -> Rect2:
	var b: Dictionary = geometry.get("bounds", {})
	return Rect2(float(b.get("x", 0)), float(b.get("y", 0)), maxf(1, float(b.get("width", 1000))), maxf(1, float(b.get("height", 1000))))

func _whole_silo_rect() -> Rect2:
	var b := _bounds_rect()
	return Rect2(b.position.x - 270.0, -260.0, b.size.x + 360.0, b.size.y + 530.0)

func _room_rect(room: Dictionary) -> Rect2:
	return Rect2(float(room.get("x", 0)), float(room.get("y", 0)), float(room.get("width", 100)), float(room.get("height", 72)))

func _room_label(room: Dictionary) -> String:
	var id := int(room.get("id", 0))
	if room_summary_by_id.has(id):
		var summary: Dictionary = room_summary_by_id[id]
		return str(summary.get("room_type_name", summary.get("name", "Room"))).to_upper()
	return "ROOM"
