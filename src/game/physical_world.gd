class_name SiloPhysicalWorld
extends Node2D

## 2.5D / 3D Cylindrical Silo Wireframe & Top-Down Blueprint Presentation.
## Read-model-only Godot cutaway. Simulation systems own all authoritative state;
## this node advances the engine and renders PhysicalReader projections in one batch.

const Reader = preload("res://src/presentation/physical_reader.gd")
const LayoutConfig = preload("res://src/sim/spatial/silo_layout_config.gd")

# 8-Bit Phosphor Green World Wireframe Palette
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

# Tactical Blue / Cyan UI Console Palette (Solid Opaque, High-Contrast Readability)
const UI_PANEL_BG := Color(0.024, 0.051, 0.086, 1.0) # Solid 100% Opaque Tactical Slate Navy
const UI_TOP_BG := Color(0.02, 0.043, 0.075, 1.0)   # Solid 100% Opaque Header Bar
const UI_BORDER := Color("00b4d8")                   # Tactical Cyan Border
const UI_BORDER_BRIGHT := Color("00e5ff")            # Electric Cyan Accent Border
const UI_HEADER := Color("90e0ef")                   # Ice Blue Section Headers
const UI_LABEL := Color("64d2ff")                    # High-Visibility Cyan Labels
const UI_VALUE := Color("ffffff")                    # High-Contrast Pure White Telemetry
const UI_MUTED := Color("7a9bb8")                    # Slate Blue Descriptive Text
const UI_ACCENT := Color("ffb703")                   # Warning Amber
const UI_ALERT := Color("ff3b5c")                    # Alert Red

var engine: SimulationEngine
var ws: WorldState
var snapshot: Dictionary = {}
var geometry: Dictionary = {}
var room_by_id: Dictionary = {}
var room_summary_by_id: Dictionary = {}
var people_by_id: Dictionary = {}
var machine_by_id: Dictionary = {}
var person_draw_positions: Dictionary = {}
var person_visual_positions: Dictionary = {}
var machine_draw_positions: Dictionary = {}
var topdown_rect_cache: Dictionary = {}

var camera: Camera2D
var speed: float = 1.0
var tick_accumulator := 0.0
var selected_type := ""
var selected_id := ""
var selected_room_id := 0
var follow_person_id := 0
var isolated_level: Variant = null
var floor_plan_transition := 0.0
var dragging := false
var drag_last := Vector2.ZERO

enum {
	VIEW_CUTAWAY = 0,
	VIEW_ISOMETRIC = 1,
	VIEW_FLOOR_PLAN = 2
}
var view_mode: int = VIEW_CUTAWAY
var room_label_mode: int = 0 # 0: FULL (Text + Icon + Cap), 1: ICONS ONLY (Icon + ID), 2: OFF
var view_button: Button
var labels_button: Button
var room_iso_rect_cache: Dictionary = {}
var initial_view_mode: Variant = null
var initial_label_mode: Variant = null

var panel: PanelContainer
var details_label: RichTextLabel
var telemetry_label: RichTextLabel
var search_edit: LineEdit
var search_results: ItemList
var level_picker: OptionButton
var status_label: Label
var pause_button: Button
var speed_buttons: Dictionary = {}
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
var initial_select_room := 0
var initial_select_person := 0

func _ready() -> void:
	_parse_args()
	_boot_simulation()
	_build_indexes()
	_build_camera()
	_build_ui()
	if initial_view_mode != null:
		_set_view_mode(int(initial_view_mode))
	if initial_label_mode != null:
		room_label_mode = int(initial_label_mode)
		_update_label_button_text()

	if initial_select_room > 0 and room_by_id.has(initial_select_room):
		_select("room", str(initial_select_room), initial_select_room)
		_focus_room(initial_select_room, custom_zoom if custom_zoom > 0.0 else 1.0)
	elif initial_select_person > 0 and people_by_id.has(initial_select_person):
		_focus_person(initial_select_person, true)
	elif not people_by_id.is_empty():
		var first_id: int = int(people_by_id.keys()[0])
		_select("person", str(first_id), int(people_by_id[first_id].get("location_id", 0)))

	if isolated_level != null and view_mode != VIEW_ISOMETRIC:
		_apply_isolated_level(int(isolated_level))
		floor_plan_transition = 1.0
	elif custom_zoom > 0.0:
		camera.zoom = Vector2.ONE * custom_zoom
		if initial_select_room == 0 and initial_select_person == 0:
			var center_pt := _whole_silo_rect().get_center()
			camera.position = Vector2(center_pt.x + (192.0 / custom_zoom), center_pt.y)
	elif initial_select_room == 0 and initial_select_person == 0:
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
		elif arg.begins_with("--uat-screenshot="):
			uat_screenshot = arg.substr(17); i += 1
		elif arg == "--isolate" and i + 1 < args.size():
			isolated_level = args[i + 1].to_int(); i += 2
		elif arg.begins_with("--isolate="):
			isolated_level = arg.substr(10).to_int(); i += 1
		elif arg == "--zoom" and i + 1 < args.size():
			custom_zoom = args[i + 1].to_float(); i += 2
		elif arg.begins_with("--zoom="):
			custom_zoom = arg.substr(7).to_float(); i += 1
		elif arg == "--select-room" and i + 1 < args.size():
			initial_select_room = args[i + 1].to_int(); i += 2
		elif arg.begins_with("--select-room="):
			initial_select_room = arg.substr(14).to_int(); i += 1
		elif arg == "--select-person" and i + 1 < args.size():
			initial_select_person = args[i + 1].to_int(); i += 2
		elif arg.begins_with("--select-person="):
			initial_select_person = arg.substr(16).to_int(); i += 1
		elif arg == "--view" and i + 1 < args.size():
			var vm := args[i + 1].to_lower()
			if vm == "isometric" or vm == "iso": initial_view_mode = VIEW_ISOMETRIC
			elif vm == "floorplan" or vm == "topdown" or vm == "blueprint": initial_view_mode = VIEW_FLOOR_PLAN
			else: initial_view_mode = VIEW_CUTAWAY
			i += 2
		elif arg.begins_with("--view="):
			var vm := arg.substr(7).to_lower()
			if vm == "isometric" or vm == "iso": initial_view_mode = VIEW_ISOMETRIC
			elif vm == "floorplan" or vm == "topdown" or vm == "blueprint": initial_view_mode = VIEW_FLOOR_PLAN
			else: initial_view_mode = VIEW_CUTAWAY
			i += 1
		elif arg == "--labels" and i + 1 < args.size():
			var lm := args[i + 1].to_lower()
			if lm == "icons" or lm == "icon": initial_label_mode = 1
			elif lm == "off" or lm == "none": initial_label_mode = 2
			else: initial_label_mode = 0
			i += 2
		elif arg.begins_with("--labels="):
			var lm := arg.substr(9).to_lower()
			if lm == "icons" or lm == "icon": initial_label_mode = 1
			elif lm == "off" or lm == "none": initial_label_mode = 2
			else: initial_label_mode = 0
			i += 1
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
	topdown_rect_cache.clear()
	for room in geometry.get("rooms", []):
		var rid := int(room.get("id", 0))
		room_by_id[rid] = room
	for summary in snapshot.get("rooms", []):
		room_summary_by_id[int(summary.get("id", 0))] = summary
	for person in snapshot.get("people", []):
		people_by_id[int(person.get("id", 0))] = person
	for machine in snapshot.get("machines", []):
		machine_by_id[int(machine.get("id", 0))] = machine

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "CutawayCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)

	# 1. Top Tactical Control Bar (Solid Opaque Blue/Cyan CRT Header)
	var top := PanelContainer.new(); top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 54; top.add_theme_stylebox_override("panel", _tactical_panel_style(UI_TOP_BG, UI_BORDER))
	layer.add_child(top)
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 8); top.add_child(bar)
	var title := Label.new(); title.text = " ❖ SILO // TACTICAL OBSERVABILITY SYSTEM "
	title.add_theme_color_override("font_color", UI_BORDER_BRIGHT); bar.add_child(title)
	status_label = Label.new(); status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_color_override("font_color", UI_LABEL); bar.add_child(status_label)

	pause_button = Button.new(); pause_button.text = "⏸ PAUSE"; pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(_toggle_pause); _style_tactical_button(pause_button); bar.add_child(pause_button)

	for spec in [["0.5×", 0.5], ["1×", 1.0], ["4×", 4.0], ["16×", 16.0]]:
		var button := Button.new(); button.text = spec[0]; button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_set_speed.bind(spec[1]))
		_style_tactical_button(button); bar.add_child(button)
		speed_buttons[spec[1]] = button

	view_button = Button.new(); view_button.text = "VIEW: CUTAWAY [V]"; view_button.focus_mode = Control.FOCUS_NONE
	view_button.pressed.connect(_cycle_view_mode); _style_tactical_button(view_button); bar.add_child(view_button)

	labels_button = Button.new(); labels_button.text = "TAGS: FULL [L]"; labels_button.focus_mode = Control.FOCUS_NONE
	labels_button.pressed.connect(_cycle_label_mode); _style_tactical_button(labels_button); bar.add_child(labels_button)

	var fit := Button.new(); fit.text = "FIT [F]"; fit.focus_mode = Control.FOCUS_NONE
	fit.pressed.connect(_fit_whole); _style_tactical_button(fit); bar.add_child(fit)

	level_picker = OptionButton.new(); level_picker.tooltip_text = "Jump to level"; level_picker.focus_mode = Control.FOCUS_NONE
	level_picker.item_selected.connect(_level_selected)
	_style_tactical_button(level_picker); bar.add_child(level_picker)
	for lev in geometry.get("levels", []):
		level_picker.add_item("Level %s" % lev.get("id", "?"))
		level_picker.set_item_metadata(level_picker.item_count - 1, lev.get("id", 0))

	isolate_button = Button.new(); isolate_button.text = "ISOLATE [I]"; isolate_button.focus_mode = Control.FOCUS_NONE
	isolate_button.pressed.connect(_toggle_isolate); _style_tactical_button(isolate_button); bar.add_child(isolate_button)

	# 2. Right Tactical CRT Telemetry & Inspector Panel (100% Solid Opaque Slate Navy)
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -385; panel.offset_top = 60; panel.offset_right = -10; panel.offset_bottom = -10
	panel.add_theme_stylebox_override("panel", _tactical_panel_style(UI_PANEL_BG, UI_BORDER_BRIGHT))
	layer.add_child(panel)

	var side := VBoxContainer.new(); side.add_theme_constant_override("separation", 6); panel.add_child(side)

	var hud_title := Label.new(); hud_title.text = "┌── SILO TELEMETRY & OBSERVABILITY ──┐"
	hud_title.add_theme_color_override("font_color", UI_HEADER); side.add_child(hud_title)

	telemetry_label = RichTextLabel.new(); telemetry_label.bbcode_enabled = true; telemetry_label.fit_content = true
	telemetry_label.custom_minimum_size.y = 115
	side.add_child(telemetry_label)

	var sep1 := HSeparator.new(); sep1.add_theme_stylebox_override("separator", _separator_style()); side.add_child(sep1)

	var search_title := Label.new(); search_title.text = "ENTITY FINDER (RESIDENT / ROOM / MACHINE)"
	search_title.add_theme_color_override("font_color", UI_ACCENT); side.add_child(search_title)

	search_edit = LineEdit.new(); search_edit.placeholder_text = "Search ID, Name, or Room Type…"
	search_edit.text_changed.connect(_search); search_edit.text_submitted.connect(func(_q: String): _activate_first_search())
	_style_tactical_line_edit(search_edit); side.add_child(search_edit)

	search_results = ItemList.new(); search_results.custom_minimum_size.y = 85; search_results.focus_mode = Control.FOCUS_NONE
	search_results.item_selected.connect(_search_selected); _style_tactical_item_list(search_results); side.add_child(search_results)

	var sep2 := HSeparator.new(); sep2.add_theme_stylebox_override("separator", _separator_style()); side.add_child(sep2)

	var insp_title := Label.new(); insp_title.text = "SELECTED ENTITY INSPECTION"
	insp_title.add_theme_color_override("font_color", UI_HEADER); side.add_child(insp_title)

	details_label = RichTextLabel.new(); details_label.bbcode_enabled = true; details_label.fit_content = false
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; details_label.scroll_active = true
	details_label.text = "[color=#7a9bb8]Select any resident, room bay, machinery, or stair segment in the physical wireframe to inspect authoritative telemetry.[/color]"
	side.add_child(details_label)

	follow_button = Button.new(); follow_button.text = "TRACK CITIZEN [G]"; follow_button.disabled = true; follow_button.focus_mode = Control.FOCUS_NONE
	follow_button.pressed.connect(_toggle_follow); _style_tactical_button(follow_button); side.add_child(follow_button)

	var help := Label.new(); help.text = "W/A/S/D / RMB: Pan   Wheel: Zoom   F: Fit   Space: Pause\nV: View (Cutaway/Iso/Plan)   L: Labels (Full/Icons/Off)   I: Isolate   G: Track"
	help.add_theme_color_override("font_color", UI_MUTED); side.add_child(help)

	_update_status()
	_update_telemetry()
	_update_speed_buttons()

func _tactical_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg # Solid 100% opaque background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(10)
	return style

func _separator_style() -> StyleBoxLine:
	var sep := StyleBoxLine.new(); sep.color = UI_BORDER; sep.thickness = 1; return sep

func _style_tactical_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", UI_LABEL)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", UI_ACCENT)
	btn.add_theme_color_override("font_disabled_color", Color("405266"))
	var normal := StyleBoxFlat.new(); normal.bg_color = Color("141e2e"); normal.border_color = UI_BORDER
	normal.set_border_width_all(1); normal.set_content_margin_all(5)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat; hover.border_color = UI_BORDER_BRIGHT; hover.bg_color = Color("1f324d")
	btn.add_theme_stylebox_override("hover", hover)

func _style_tactical_line_edit(le: LineEdit) -> void:
	le.add_theme_color_override("font_color", UI_VALUE)
	le.add_theme_color_override("placeholder_color", UI_MUTED)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("0a1420"); sb.border_color = UI_BORDER
	sb.set_border_width_all(1); sb.set_content_margin_all(6)
	le.add_theme_stylebox_override("normal", sb)

func _style_tactical_item_list(il: ItemList) -> void:
	il.add_theme_color_override("font_color", UI_LABEL)
	il.add_theme_color_override("font_selected_color", Color.WHITE)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("0a1420"); sb.border_color = Color("1e3450")
	sb.set_border_width_all(1); sb.set_content_margin_all(4)
	il.add_theme_stylebox_override("panel", sb)

func _input(event: InputEvent) -> void:
	# Release LineEdit focus if clicking anywhere outside the search box
	if event is InputEventMouseButton and event.pressed:
		if search_edit and search_edit.has_focus():
			var s_rect := search_edit.get_global_rect()
			if not s_rect.has_point(event.position):
				search_edit.release_focus()

	# Dedicated global keyboard handling ensuring Spacebar ALWAYS pauses unless typing in LineEdit
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if search_edit and search_edit.has_focus():
				# If search box is empty or only whitespace, unfocus and toggle pause!
				if search_edit.text.strip_edges().is_empty():
					search_edit.text = ""
					search_edit.release_focus()
					_toggle_pause()
					get_viewport().set_input_as_handled()
					return
				return
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_V:
			_cycle_view_mode(); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_L:
			_cycle_label_mode(); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_1:
			_set_speed(0.5); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			_set_speed(1.0); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_3:
			_set_speed(4.0); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_4:
			_set_speed(16.0); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			_fit_whole(); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I:
			_toggle_isolate(); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_G:
			_toggle_follow(); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if search_edit and search_edit.has_focus():
				search_edit.release_focus()
				search_edit.text = ""
				_search("")
				get_viewport().set_input_as_handled()
				return
			isolated_level = null
			follow_person_id = 0
			if view_mode == VIEW_FLOOR_PLAN:
				_set_view_mode(VIEW_CUTAWAY)
			queue_redraw()
			get_viewport().set_input_as_handled()

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

func _process(delta: float) -> void:
	var began := Time.get_ticks_usec()
	if frames_drawn >= 5: frame_seconds_total += delta

	# Smooth top-down floor plan wireframe transition (animates between 0.0 cutaway and 1.0 blueprint)
	var target_transition := 1.0 if isolated_level != null else 0.0
	floor_plan_transition = move_toward(floor_plan_transition, target_transition, delta * 3.2)

	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): pan.x -= 1.0
	if Input.is_key_pressed(KEY_D): pan.x += 1.0
	if Input.is_key_pressed(KEY_W): pan.y -= 1.0
	if Input.is_key_pressed(KEY_S): pan.y += 1.0
	if pan.length_squared() > 0.0:
		camera.position += pan.normalized() * 650.0 * delta / camera.zoom.x
		follow_person_id = 0

	# Smooth simulation stepping supporting 0.5x real-time speed
	if speed > 0.0:
		tick_accumulator += delta * speed * 2.0
		var steps := mini(32, int(tick_accumulator))
		if steps > 0:
			engine.step(steps); tick_accumulator -= steps; _refresh_live()

	# Smooth visual interpolation for red dots (sub-tick gliding)
	for pid in person_draw_positions:
		var target_pos: Vector2 = person_draw_positions[pid]
		if not person_visual_positions.has(pid):
			person_visual_positions[pid] = target_pos
		else:
			person_visual_positions[pid] = (person_visual_positions[pid] as Vector2).lerp(target_pos, clampf(delta * 14.0, 0.1, 1.0))

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

func _toggle_pause() -> void:
	_set_speed(0.0 if speed > 0.0 else 1.0)

func _set_speed(value: float) -> void:
	speed = value
	_update_speed_buttons()
	_update_status()

func _update_speed_buttons() -> void:
	if pause_button:
		if speed == 0.0:
			pause_button.text = "▶ RUN [SPACE]"
			pause_button.add_theme_color_override("font_color", UI_ACCENT)
		else:
			pause_button.text = "⏸ PAUSE [SPACE]"
			pause_button.add_theme_color_override("font_color", UI_LABEL)
	for s_val in speed_buttons:
		var btn: Button = speed_buttons[s_val]
		if is_equal_approx(speed, s_val):
			btn.add_theme_color_override("font_color", UI_BORDER_BRIGHT)
		else:
			btn.add_theme_color_override("font_color", UI_LABEL)

func _update_status() -> void:
	if not status_label: return
	var year: int = 1; var day: int = 1; var hour: int = 0; var minute: int = 0; var tick_num: int = 0
	if ws and ws.sim_clock:
		year = ws.sim_clock.get_year()
		day = ws.sim_clock.get_day_of_year()
		hour = ws.sim_clock.get_hour_of_day()
		minute = ws.sim_clock.get_minute_of_hour()
		tick_num = ws.sim_clock.get_tick()
	else:
		var clock: Dictionary = snapshot.get("clock", {})
		year = int(clock.get("year", 1))
		day = int(clock.get("day_of_year", clock.get("day", 1)))
		hour = int(clock.get("hour", 0))
		minute = int(clock.get("minute", 0))
		tick_num = int(clock.get("tick", snapshot.get("revision", 0)))
	var state_text := "[⏸ PAUSED]" if speed == 0.0 else "[▶ RUNNING %.1f×]" % speed
	status_label.text = "Year %d · Day %d · %02d:%02d  |  %s  |  %d RESIDENTS (RED DOTS)  |  TICK %d" % [
		year, day, hour, minute, state_text, people_by_id.size(), tick_num
	]

func _cycle_view_mode() -> void:
	_set_view_mode((view_mode + 1) % 3)

func _set_view_mode(mode: int) -> void:
	view_mode = mode
	match view_mode:
		VIEW_CUTAWAY:
			isolated_level = null
			floor_plan_transition = 0.0
			if view_button: view_button.text = "VIEW: CUTAWAY [V]"
			if isolate_button: isolate_button.text = "ISOLATE [I]"
		VIEW_ISOMETRIC:
			isolated_level = null
			floor_plan_transition = 0.0
			if view_button: view_button.text = "VIEW: ISOMETRIC [V]"
			if isolate_button: isolate_button.text = "ISOLATE [I]"
		VIEW_FLOOR_PLAN:
			if isolated_level == null:
				var target_l := 1
				if selected_room_id > 0 and room_by_id.has(selected_room_id):
					target_l = int(room_by_id[selected_room_id].get("level", 1))
				_apply_isolated_level(target_l)
			floor_plan_transition = 1.0
			if view_button: view_button.text = "VIEW: FLOOR PLAN [V]"
	_fit_whole()
	queue_redraw()

func _cycle_label_mode() -> void:
	room_label_mode = (room_label_mode + 1) % 3
	_update_label_button_text()
	queue_redraw()

func _update_label_button_text() -> void:
	if not labels_button: return
	match room_label_mode:
		0: labels_button.text = "TAGS: FULL [L]"
		1: labels_button.text = "TAGS: ICONS [L]"
		2: labels_button.text = "TAGS: OFF [L]"

func _update_telemetry() -> void:
	if not telemetry_label: return
	var pop_summary: Dictionary = SimulationReader.get_population_summary(ws) if ws else {}
	var act: Dictionary = pop_summary.get("activity_counts", {})
	var util_summary: Dictionary = SimulationReader.get_utilities_summary(ws) if ws else {}
	var water_res: float = float(util_summary.get("water_reservoir", 99998.0))
	var water_cap: float = float(util_summary.get("water_capacity", 100000.0))

	var total_transit := 0; var max_stair_queue := 0
	for seg in geometry.get("stair_segments", []):
		var occ_val: Variant = seg.get("occupancy", 0)
		var occ: int = occ_val.size() if (occ_val is Dictionary or occ_val is Array) else int(occ_val)
		total_transit += occ
		var q_val: Variant = seg.get("queue_length", seg.get("queue", 0))
		var q_len: int = q_val.size() if q_val is Array else int(q_val)
		max_stair_queue = maxi(max_stair_queue, q_len)

	var view_mode_text: String
	match view_mode:
		VIEW_ISOMETRIC: view_mode_text = "[color=#00e5ff]3D ISOMETRIC AXONOMETRIC SILO (20 LEVELS)[/color]"
		VIEW_FLOOR_PLAN: view_mode_text = "[color=#00e5ff]TOP-DOWN CIRCULAR BLUEPRINT (LEVEL %s)[/color]" % str(isolated_level)
		_: view_mode_text = "[color=#00e5ff]VERTICAL CYLINDER CUTAWAY (20 LEVELS)[/color]"

	var lines: Array[String] = [
		"VIEW: %s" % view_mode_text,
		"[color=#90e0ef]POPULATION:[/color] [color=#ffffff]%d living (100%% viable)[/color]" % pop_summary.get("living_count", people_by_id.size()),
		"  • Work: [color=#ffb703]%d[/color] | Study: [color=#64d2ff]%d[/color] | Sleep: [color=#ffffff]%d[/color]" % [act.get("WORKING", 0), act.get("STUDYING", 0), act.get("SLEEPING", 0)],
		"  • In Transit: [color=#ff3b5c]%d[/color] | Eating/Rec: [color=#64d2ff]%d[/color]" % [act.get("TRAVELING", 0), act.get("EATING", 0) + act.get("RECREATING", 0)],
		"[color=#90e0ef]LIFE SUPPORT (WATER):[/color] [color=#ffffff]%.0f L / %.0f L[/color] [color=#00ff66][NOMINAL][/color]" % [water_res, water_cap],
		"[color=#90e0ef]CENTRAL CIRCULATION:[/color] [color=#ffffff]%d commuters[/color] | Peak queue: [color=#ffb703]%d[/color]" % [total_transit, max_stair_queue]
	]
	telemetry_label.text = "\n".join(lines)

func _draw() -> void:
	if geometry.is_empty(): return
	var start := Time.get_ticks_usec()
	if view_mode == VIEW_ISOMETRIC:
		_draw_isometric_world()
	else:
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

	# 1. Surrounding Geology & Rock Background
	draw_rect(silo_box.grow(400.0), ROCK_BG, true)
	draw_rect(silo_box.grow(30.0), CRT_BG, true)

	var t := floor_plan_transition
	var cutaway_alpha := 1.0 - t
	var blueprint_alpha := t

	# 2. Vertical Cutaway Geology & Casing (Fades out when transitioning to top-down floor plan)
	if cutaway_alpha > 0.01:
		var col_dark := Color(WIRE_DARK.r, WIRE_DARK.g, WIRE_DARK.b, WIRE_DARK.a * cutaway_alpha)
		var col_mid := Color(WIRE_MID.r, WIRE_MID.g, WIRE_MID.b, WIRE_MID.a * cutaway_alpha)
		var col_bright := Color(WIRE_BRIGHT.r, WIRE_BRIGHT.g, WIRE_BRIGHT.b, WIRE_BRIGHT.a * cutaway_alpha)

		var y_step := -220.0
		while y_step <= b.end.y + 240.0:
			draw_line(Vector2(cx_left - 320, y_step), Vector2(cx_left - 8, y_step + 6), col_dark, 1.0)
			draw_line(Vector2(cx_right + 8, y_step + 6), Vector2(cx_right + 320, y_step), col_dark, 1.0)
			y_step += 52.0

		for side_x in [cx_left, cx_right]:
			draw_line(Vector2(side_x - 6, -180), Vector2(side_x - 6, b.end.y + 160), col_mid, 2.0)
			draw_line(Vector2(side_x, -180), Vector2(side_x, b.end.y + 160), col_bright, 2.5)
			draw_line(Vector2(side_x + 6, -180), Vector2(side_x + 6, b.end.y + 160), col_mid, 2.0)

		# Top Surface Hatch Dome Complex
		if isolated_level == null:
			var dome_points: PackedVector2Array = []
			for s in range(33):
				var dt := float(s) / 32.0
				var px := lerpf(cx_left, cx_right, dt)
				var norm := (dt - 0.5) * 2.0
				var py_outer := -180.0 * (1.0 - norm * norm)
				dome_points.append(Vector2(px, py_outer))
			draw_polyline(dome_points, col_bright, 2.5)
			var hatch_rect := Rect2(center_x - 55, -225, 110, 45)
			draw_rect(hatch_rect, CRT_BG, true)
			draw_rect(hatch_rect, col_bright, false, 2.0)
			draw_string(ThemeDB.fallback_font, Vector2(center_x - 120, -235), "▲ TO SURFACE // SEALED HATCH COMPLEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col_bright)

		# Bottom Geological Foundation
		if isolated_level == null:
			var base_y := b.end.y + 18.0
			var anchor_rect := Rect2(center_x - 50, base_y, 100, 160)
			draw_rect(anchor_rect, CRT_BG, true)
			draw_rect(anchor_rect, col_bright, false, 2.5)
			draw_string(ThemeDB.fallback_font, Vector2(center_x - 125, base_y + 185), "▼ L-B1 GEOLOGICAL ANCHOR FOUNDATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col_bright)

		# Horizontal Floor Plates with Curved Lip
		for level in geometry.get("levels", []):
			var lid := int(level.get("id", 0))
			if isolated_level != null and lid != int(isolated_level): continue
			var floor_y := float(level.get("floor_y", float(level.get("y", 0.0)) + 104.0))
			draw_line(Vector2(cx_left - 12, floor_y), Vector2(cx_right + 12, floor_y), col_mid, 2.0)

			var curve_points: PackedVector2Array = []
			for s in range(25):
				var ct := float(s) / 24.0
				var px := lerpf(cx_left - 12, cx_right + 12, ct)
				var norm := (ct - 0.5) * 2.0
				var py := floor_y + 8.0 * (1.0 - norm * norm)
				curve_points.append(Vector2(px, py))
			draw_polyline(curve_points, col_dark, 1.5)

			var ltitle := _level_title(lid)
			draw_string(ThemeDB.fallback_font, Vector2(cx_left - 260, float(level.get("y", 0.0)) + 24), ltitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col_bright)

	# 3. Top-Down Circular Floor Plan Blueprint with Interconnected Architectural Hallways
	if blueprint_alpha > 0.01 and isolated_level != null:
		var bp_center := Vector2(0.0, _level_center_y(int(isolated_level)))
		var bp_mid := Color(WIRE_MID.r, WIRE_MID.g, WIRE_MID.b, WIRE_MID.a * blueprint_alpha)
		var bp_bright := Color(WIRE_BRIGHT.r, WIRE_BRIGHT.g, WIRE_BRIGHT.b, WIRE_BRIGHT.a * blueprint_alpha)
		var bp_dim := Color(WIRE_DIM.r, WIRE_DIM.g, WIRE_DIM.b, WIRE_DIM.a * blueprint_alpha)
		var bp_dark := Color(WIRE_DARK.r, WIRE_DARK.g, WIRE_DARK.b, WIRE_DARK.a * blueprint_alpha)

		# Outer Silo Cylindrical Casing Rings (Radius 405, 388, 375)
		draw_arc(bp_center, 405.0, 0.0, TAU, 64, bp_mid, 2.0)
		draw_arc(bp_center, 388.0, 0.0, TAU, 64, bp_bright, 2.5)
		draw_arc(bp_center, 375.0, 0.0, TAU, 64, bp_dim, 1.5)
		for sp in range(32):
			var ang := float(sp) * (TAU / 32.0)
			draw_line(bp_center + Vector2(cos(ang), sin(ang)) * 375.0, bp_center + Vector2(cos(ang), sin(ang)) * 405.0, bp_dim, 1.2)

		# Perimeter Ring Hallway (Radius 348 to 372)
		draw_arc(bp_center, 372.0, 0.0, TAU, 64, bp_mid, 1.5)
		draw_arc(bp_center, 348.0, 0.0, TAU, 64, bp_mid, 1.5)

		# Central Circulation Core (Stair & Elevator Hub, R <= 54)
		draw_arc(bp_center, 54.0, 0.0, TAU, 32, bp_bright, 2.5)
		draw_rect(Rect2(bp_center - Vector2(30, 30), Vector2(60, 60)), CRT_BG, true)
		draw_rect(Rect2(bp_center - Vector2(30, 30), Vector2(60, 60)), bp_bright, false, 2.0)
		for st in range(6):
			var sy := bp_center.y - 18.0 + float(st) * 7.0
			draw_line(Vector2(bp_center.x - 14, sy), Vector2(bp_center.x + 14, sy), bp_mid, 1.5)
		# Dual Elevator guide marks
		draw_line(Vector2(bp_center.x - 24, bp_center.y - 25), Vector2(bp_center.x - 24, bp_center.y + 25), bp_bright, 2.0)
		draw_line(Vector2(bp_center.x + 24, bp_center.y - 25), Vector2(bp_center.x + 24, bp_center.y + 25), bp_bright, 2.0)

		# Central Ring Hallway (Radius 56 to 96, 40 px wide walkway)
		draw_arc(bp_center, 96.0, 0.0, TAU, 48, bp_mid, 2.0)
		for sp in range(24):
			var ang := float(sp) * (TAU / 24.0)
			draw_line(bp_center + Vector2(cos(ang), sin(ang)) * 56.0, bp_center + Vector2(cos(ang), sin(ang)) * 96.0, bp_dark, 1.0)

		# 4 Main Cardinal Avenue Corridors (Double walls with floor tile cross-lines)
		# North Avenue (Sector A)
		draw_line(bp_center + Vector2(-16, -96), bp_center + Vector2(-16, -348), bp_bright, 2.0)
		draw_line(bp_center + Vector2(16, -96), bp_center + Vector2(16, -348), bp_bright, 2.0)
		for y_off in range(110, 340, 22):
			draw_line(bp_center + Vector2(-14, -y_off), bp_center + Vector2(14, -y_off), bp_dark, 1.0)

		# South Avenue (Sector C)
		draw_line(bp_center + Vector2(-16, 96), bp_center + Vector2(-16, 348), bp_bright, 2.0)
		draw_line(bp_center + Vector2(16, 96), bp_center + Vector2(16, 348), bp_bright, 2.0)
		for y_off in range(110, 340, 22):
			draw_line(bp_center + Vector2(-14, y_off), bp_center + Vector2(14, y_off), bp_dark, 1.0)

		# East Avenue (Sector B)
		draw_line(bp_center + Vector2(96, -16), bp_center + Vector2(348, -16), bp_bright, 2.0)
		draw_line(bp_center + Vector2(96, 16), bp_center + Vector2(348, 16), bp_bright, 2.0)
		for x_off in range(110, 340, 22):
			draw_line(bp_center + Vector2(x_off, -14), bp_center + Vector2(x_off, 14), bp_dark, 1.0)

		# West Avenue (Sector D)
		draw_line(bp_center + Vector2(-96, -16), bp_center + Vector2(-348, -16), bp_bright, 2.0)
		draw_line(bp_center + Vector2(-96, 16), bp_center + Vector2(-348, 16), bp_bright, 2.0)
		for x_off in range(110, 340, 22):
			draw_line(bp_center + Vector2(-x_off, -14), bp_center + Vector2(-x_off, 14), bp_dark, 1.0)

		# 4 Diagonal Secondary Branch Corridors (Width 24 px)
		for sp in [1, 3, 5, 7]:
			var ang := float(sp) * (TAU / 8.0)
			var dir := Vector2(cos(ang), sin(ang))
			var perp := Vector2(-dir.y, dir.x) * 12.0
			draw_line(bp_center + dir * 165.0 + perp, bp_center + dir * 348.0 + perp, bp_mid, 1.5)
			draw_line(bp_center + dir * 165.0 - perp, bp_center + dir * 348.0 - perp, bp_mid, 1.5)
			draw_line(bp_center + dir * 165.0, bp_center + dir * 348.0, bp_dark, 1.0)

		# Doorway Thresholds connecting rooms to hallways
		for room in geometry.get("rooms", []):
			if int(room.get("level", 0)) != int(isolated_level): continue
			var r_rect := _room_rect_topdown(room)
			var rtype := int(room.get("room_type", 0))
			if rtype == 0: # Residential apartment directly attached to cardinal avenue
				var r_center := r_rect.get_center()
				var dx_from_c := r_center.x - bp_center.x
				var dy_from_c := r_center.y - bp_center.y
				if absf(dx_from_c) > absf(dy_from_c): # East or West Avenue
					var door_y := bp_center.y + (16.0 if dy_from_c > 0 else -16.0)
					draw_line(Vector2(r_center.x - 8.0, door_y), Vector2(r_center.x + 8.0, door_y), bp_bright, 2.5)
				else: # North or South Avenue
					var door_x := bp_center.x + (16.0 if dx_from_c > 0 else -16.0)
					draw_line(Vector2(door_x, r_center.y - 8.0), Vector2(door_x, r_center.y + 8.0), bp_bright, 2.5)
			else:
				var d_center := r_rect.get_center()
				var d_vec := (d_center - bp_center).normalized()
				var door_p := d_center - d_vec * (minf(r_rect.size.x, r_rect.size.y) * 0.48)
				draw_line(door_p - Vector2(d_vec.y, -d_vec.x) * 8.0, door_p + Vector2(d_vec.y, -d_vec.x) * 8.0, bp_bright, 2.5)

		# Blueprint Compass & Sector Avenue Labels
		draw_string(ThemeDB.fallback_font, bp_center + Vector2(-95, -425), "▲ NORTH // MAIN AVENUE (SECTOR A)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, bp_bright)
		draw_string(ThemeDB.fallback_font, bp_center + Vector2(-95, 440), "▼ SOUTH // MAIN AVENUE (SECTOR C)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, bp_bright)
		draw_string(ThemeDB.fallback_font, bp_center + Vector2(-600, 5), "◀ WEST // MAIN AVENUE (SECTOR D)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, bp_bright)
		draw_string(ThemeDB.fallback_font, bp_center + Vector2(425, 5), "▶ EAST // MAIN AVENUE (SECTOR B)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, bp_bright)
		draw_string(ThemeDB.fallback_font, bp_center + Vector2(-95, -60), "CENTRAL STAIR & LIFT HUB", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, bp_bright)

func _iso_project(r: float, angle_rad: float, level_idx: float) -> Vector2:
	var wx: float = r * cos(angle_rad)
	var wy: float = r * sin(angle_rad)
	var iso_x: float = (wx - wy) * 0.866025
	var iso_y: float = (wx + wy) * 0.5 + level_idx * 115.0
	return Vector2(iso_x, iso_y)

func _draw_isometric_world() -> void:
	var z := camera.zoom.x
	var levels: Array = geometry.get("levels", [])
	if levels.is_empty(): return

	var num_levels: int = levels.size()

	# 1. Dark Bedrock Background
	var b_rect := _whole_silo_rect().grow(500.0)
	draw_rect(b_rect, ROCK_BG, true)

	# 2. Outer Bedrock Cavern Strata (Jagged rock walls enclosing the cylinder)
	var r_outer := 365.0
	var r_shaft := 68.0

	for l_idx in range(num_levels):
		var rock_left := _iso_project(r_outer + 35.0, PI * 0.5, float(l_idx))
		var rock_right := _iso_project(r_outer + 35.0, 0.0, float(l_idx))
		draw_line(rock_left + Vector2(-180, (l_idx % 4) * 8), rock_left, WIRE_DARK, 1.0)
		draw_line(rock_right, rock_right + Vector2(180, ((l_idx + 2) % 4) * 8), WIRE_DARK, 1.0)

		# Horizontal Tunnel Breaches into Rock (Levels 4, 10, 16)
		if l_idx in [3, 9, 15]:
			var t_l1 := rock_left
			var t_l2 := rock_left + Vector2(-150, -20)
			draw_line(t_l1, t_l2, WIRE_MID, 1.5)
			draw_line(t_l1 + Vector2(0, -32), t_l2 + Vector2(0, -32), WIRE_MID, 1.5)
			draw_line(t_l2, t_l2 + Vector2(0, -32), WIRE_BRIGHT, 2.0)
			if z >= 0.35:
				draw_string(ThemeDB.fallback_font, t_l2 + Vector2(-110, -10), "MINING CONDUIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, WIRE_DIM)

	# 3. Central Vertical Shaft (Octagonal guide column lines from Level 1 to 20)
	for sp in range(8):
		var a := float(sp) * TAU / 8.0
		var pt_top := _iso_project(r_shaft, a, -0.4)
		var pt_bot := _iso_project(r_shaft, a, float(num_levels) - 0.5)
		draw_line(pt_top, pt_bot, WIRE_DARK, 1.0)

	# 4. Vertical Elevator Guide Rails & Moving Lift Cabs
	var elev_a1 := _iso_project(r_shaft * 0.88, PI * 0.75, -0.4)
	var elev_a2 := _iso_project(r_shaft * 0.88, PI * 0.75, float(num_levels) - 0.5)
	var elev_b1 := _iso_project(r_shaft * 0.88, PI * 1.75, -0.4)
	var elev_b2 := _iso_project(r_shaft * 0.88, PI * 1.75, float(num_levels) - 0.5)
	draw_line(elev_a1, elev_a2, WIRE_BRIGHT, 2.0)
	draw_line(elev_b1, elev_b2, WIRE_BRIGHT, 2.0)

	var tick_f: float = float(ws.sim_clock.get_tick() if (ws and ws.sim_clock) else 0) + tick_accumulator
	var cab_l1 := fmod(tick_f * 0.12, float(num_levels))
	var cab_l2 := fmod(float(num_levels) * 0.6 + tick_f * 0.08, float(num_levels))
	var cab1_pos := _iso_project(r_shaft * 0.88, PI * 0.75, cab_l1)
	var cab2_pos := _iso_project(r_shaft * 0.88, PI * 1.75, cab_l2)
	draw_rect(Rect2(cab1_pos - Vector2(7, 12), Vector2(14, 24)), CRT_BG, true)
	draw_rect(Rect2(cab1_pos - Vector2(7, 12), Vector2(14, 24)), WIRE_BRIGHT, false, 1.5)
	draw_rect(Rect2(cab2_pos - Vector2(7, 12), Vector2(14, 24)), CRT_BG, true)
	draw_rect(Rect2(cab2_pos - Vector2(7, 12), Vector2(14, 24)), WIRE_BRIGHT, false, 1.5)

	# 5. Helical Spiral Staircase in Central Core
	for l_idx in range(num_levels):
		var steps := 8
		for s in range(steps):
			var frac := float(s) / float(steps)
			var a := frac * TAU - PI * 0.5
			var cur_l := float(l_idx) + frac
			var inner_p := _iso_project(18.0, a, cur_l)
			var outer_p := _iso_project(r_shaft * 0.82, a, cur_l)
			draw_line(inner_p, outer_p, WIRE_MID, 1.2)
			if s % 2 == 0:
				var next_a := (float(s + 1) / float(steps)) * TAU - PI * 0.5
				var next_outer := _iso_project(r_shaft * 0.82, next_a, cur_l + 1.0 / float(steps))
				draw_line(outer_p, next_outer, WIRE_BRIGHT, 1.5)

	# 6. Stacked Cylindrical Floor Slabs & Rooms
	room_iso_rect_cache.clear()
	for l_idx in range(num_levels):
		var level_dict: Dictionary = levels[l_idx]
		var lid := int(level_dict.get("id", l_idx + 1))

		# Floor Slab Cutaway Arc (From theta = 90 deg around the back to 360 deg)
		var arc_pts: PackedVector2Array = []
		var arc_steps := 28
		for s in range(arc_steps + 1):
			var ang := (PI * 0.5) + float(s) / float(arc_steps) * (PI * 1.5)
			arc_pts.append(_iso_project(r_outer, ang, float(l_idx)))
		draw_polyline(arc_pts, WIRE_MID, 2.0)

		# Cutaway Cross-Section Edges (Front 90-degree cutaway exposing interior!)
		var left_outer := _iso_project(r_outer, PI * 0.5, float(l_idx))
		var left_inner := _iso_project(r_shaft, PI * 0.5, float(l_idx))
		var right_outer := _iso_project(r_outer, 0.0, float(l_idx))
		var right_inner := _iso_project(r_shaft, 0.0, float(l_idx))
		draw_line(left_outer, left_inner, WIRE_BRIGHT, 2.0)
		draw_line(right_outer, right_inner, WIRE_BRIGHT, 2.0)

		# Floor Slab Thickness (Edge drop of 8 px)
		draw_line(left_outer, left_outer + Vector2(0, 8), WIRE_DARK, 1.5)
		draw_line(left_inner, left_inner + Vector2(0, 8), WIRE_DARK, 1.5)
		draw_line(left_outer + Vector2(0, 8), left_inner + Vector2(0, 8), WIRE_DARK, 1.2)
		draw_line(right_outer, right_outer + Vector2(0, 8), WIRE_DARK, 1.5)
		draw_line(right_inner, right_inner + Vector2(0, 8), WIRE_DARK, 1.5)
		draw_line(right_outer + Vector2(0, 8), right_inner + Vector2(0, 8), WIRE_DARK, 1.2)

		# Inner Balcony Railing overlooking Central Open Shaft
		var rail_pts: PackedVector2Array = []
		for s in range(16):
			var ang := (PI * 0.5) + float(s) / 15.0 * (PI * 1.5)
			rail_pts.append(_iso_project(r_shaft, ang, float(l_idx)))
		draw_polyline(rail_pts, WIRE_BRIGHT, 1.5)

		# Inter-Level Perimeter Diagonal Stairs
		if l_idx < num_levels - 1:
			var st_top := _iso_project(r_outer * 0.96, PI * 0.5, float(l_idx))
			var st_bot := _iso_project(r_outer * 0.96, PI * 0.5, float(l_idx + 1)) + Vector2(35, 0)
			draw_line(st_top, st_bot, WIRE_BRIGHT, 2.0)
			for step_i in range(5):
				var sf := float(step_i) / 4.0
				var sp := st_top.lerp(st_bot, sf)
				draw_line(sp - Vector2(4, 0), sp + Vector2(4, 0), WIRE_MID, 1.5)

		# Level Tag
		draw_string(ThemeDB.fallback_font, left_outer + Vector2(-95, -6), "L%02d" % lid, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, WIRE_BRIGHT)

		# Collect Rooms on this Level
		var level_rooms: Array = []
		for r in geometry.get("rooms", []):
			if int(r.get("level", 0)) == lid: level_rooms.append(r)

		var total_r := maxi(1, level_rooms.size())
		for r_idx in range(total_r):
			var room: Dictionary = level_rooms[r_idx]
			var rid := int(room.get("id", 0))
			var rtype := int(room.get("room_type", 0))
			var selected := selected_type == "room" and selected_id == str(rid)

			# Position room along back cylindrical arc
			var angle_span := (PI * 1.4) / float(total_r)
			var a1 := (PI * 0.55) + float(r_idx) * angle_span
			var a2 := a1 + angle_span * 0.88
			var r_in := r_shaft + 18.0
			var r_out := r_outer - 12.0

			var p1 := _iso_project(r_in, a1, float(l_idx))
			var p2 := _iso_project(r_out, a1, float(l_idx))
			var p3 := _iso_project(r_out, a2, float(l_idx))
			var p4 := _iso_project(r_in, a2, float(l_idx))

			var room_poly: PackedVector2Array = [p1, p2, p3, p4]
			var center_pt := (p1 + p2 + p3 + p4) * 0.25
			room_iso_rect_cache[rid] = {"center": center_pt, "poly": room_poly, "level": lid}

			# Subtle Category Tint
			var tint := _room_tint(rtype)
			draw_colored_polygon(room_poly, Color(tint.r, tint.g, tint.b, 0.12 if selected else 0.04))

			# Floor Boundary Wireframe
			var b_col := WIRE_ACCENT if selected else (WIRE_BRIGHT if rtype in [2, 7, 10, 11, 16] else WIRE_MID)
			draw_polyline(PackedVector2Array([p1, p2, p3, p4, p1]), b_col, 2.0 if selected else 1.2)

			# Vertical Wall Extrusions (Receding isometric walls)
			var wall_h := 45.0
			var top_p2 := p2 - Vector2(0, wall_h)
			var top_p3 := p3 - Vector2(0, wall_h)
			draw_line(p2, top_p2, WIRE_DIM, 1.0)
			draw_line(p3, top_p3, WIRE_DIM, 1.0)
			draw_line(top_p2, top_p3, WIRE_DIM, 1.0)

			# Doorway Threshold onto Corridor
			var door_p1 := p1.lerp(p4, 0.35)
			var door_p2 := p1.lerp(p4, 0.65)
			draw_line(door_p1, door_p2, WIRE_BRIGHT, 2.5)

			# Selected Reticle
			if selected:
				_draw_corner_brackets(Rect2(center_pt - Vector2(25, 20), Vector2(50, 40)), WIRE_BRIGHT, 6.0, 1.5)

			# Zoomed-In Interior Sketches
			if z >= 0.55:
				_draw_iso_interior(rtype, center_pt)

			# Room Icons & Labels
			if room_label_mode != 2:
				if room_label_mode == 1: # ICONS ONLY
					_draw_room_symbol(rtype, center_pt - Vector2(0, 6), 9.0, WIRE_BRIGHT if selected else WIRE_MID)
					if z >= 0.5:
						draw_string(ThemeDB.fallback_font, center_pt + Vector2(-12, 14), "#%d" % rid, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, WIRE_DIM)
				else: # FULL
					_draw_room_symbol(rtype, center_pt - Vector2(22, 6), 7.0, WIRE_BRIGHT if selected else WIRE_MID)
					if z >= 0.42:
						var short_name := _room_label(room).substr(0, 12)
						draw_string(ThemeDB.fallback_font, center_pt + Vector2(-10, -2), short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, WIRE_BRIGHT)
						draw_string(ThemeDB.fallback_font, center_pt + Vector2(-10, 10), "#%d · CAP %s" % [rid, room.get("capacity", "?")], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, WIRE_DIM)

	# 7. Render 1,200 Residents in 3D Isometric Coordinates
	_draw_isometric_people(z)

func _draw_iso_interior(rtype: int, c: Vector2) -> void:
	match rtype:
		0: # Bunk beds
			draw_line(c - Vector2(8, 0), c + Vector2(8, 0), WIRE_DIM, 1.5)
			draw_line(c - Vector2(8, 8), c + Vector2(8, 8), WIRE_DARK, 1.0)
		11: # School desks
			draw_line(c - Vector2(10, 4), c + Vector2(10, 4), WIRE_MID, 1.2)
			draw_line(c - Vector2(10, -4), c + Vector2(10, -4), WIRE_MID, 1.2)
		16: # Bio-farm racks
			draw_line(c - Vector2(12, 0), c + Vector2(12, 0), WIRE_BRIGHT, 1.5)
			draw_line(c - Vector2(12, -8), c + Vector2(12, -8), WIRE_BRIGHT, 1.5)
		7: # Mine tracks
			draw_line(c - Vector2(12, -6), c + Vector2(12, 6), WIRE_MID, 1.2)
			draw_line(c - Vector2(12, -10), c + Vector2(12, 2), WIRE_MID, 1.2)
		_:
			draw_rect(Rect2(c - Vector2(6, 4), Vector2(12, 8)), WIRE_DARK, false, 1.0)

func _draw_isometric_people(z: float) -> void:
	var dot_radius := clampf(1.8 * z, 1.6, 3.8)
	var glow_radius := dot_radius * 2.2
	var room_people_count: Dictionary = {}

	for person in snapshot.get("people", []):
		var pid := int(person.get("id", 0))
		var rid := int(person.get("location_id", 0))
		var chosen := selected_type == "person" and selected_id == str(pid)
		var is_traveling: bool = str(person.get("activity", "")).to_lower().contains("travel")

		var draw_pos: Vector2
		if is_traveling:
			var journey: Dictionary = person.get("journey", {})
			var from_l: int = int(journey.get("from_level", 1))
			var to_l: int = int(journey.get("to_level", 1))
			var prog: float = float(person.get("travel_progress", 0.5))
			var cur_l: float = lerpf(float(from_l - 1), float(to_l - 1), prog)
			var a := cur_l * TAU - PI * 0.5
			draw_pos = _iso_project(68.0 * 0.8, a, cur_l)
		elif room_iso_rect_cache.has(rid):
			var room_info: Dictionary = room_iso_rect_cache[rid]
			var c_pt: Vector2 = room_info["center"]
			var idx: int = room_people_count.get(rid, 0)
			room_people_count[rid] = idx + 1
			var col := idx % 6
			var row := idx / 6
			draw_pos = c_pt + Vector2(float(col - 2) * 5.5, float(row - 1) * 4.5)
		else:
			continue

		person_draw_positions[pid] = draw_pos

		var cur_radius: float = dot_radius * 1.35 if chosen else dot_radius
		draw_circle(draw_pos, cur_radius + (3.0 if chosen else (glow_radius - dot_radius)), PERSON_GLOW)
		draw_circle(draw_pos, cur_radius, PERSON_COLOR)

		if chosen:
			_draw_reticle(draw_pos, WIRE_BRIGHT, 12.0)
			var dst_id := int(person.get("destination_id", 0))
			if dst_id > 0 and room_iso_rect_cache.has(dst_id):
				var dst_pos: Vector2 = room_iso_rect_cache[dst_id]["center"]
				draw_dashed_line(draw_pos, dst_pos, UI_ACCENT, 1.5, 6.0)
			if z >= 0.4:
				var tag := "%s [%s]" % [person.get("name", "CITIZEN"), person.get("activity", "IDLE")]
				draw_string(ThemeDB.fallback_font, draw_pos + Vector2(12, -8), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_BORDER_BRIGHT)

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

func _level_center_y(lid: int) -> float:
	for level in geometry.get("levels", []):
		if int(level.get("id", -999)) == lid:
			return float(level.get("y", 0.0)) + 52.0
	return 0.0

func _draw_rooms() -> void:
	var z := camera.zoom.x
	for room in geometry.get("rooms", []):
		var lid := int(room.get("level", 0))
		if isolated_level != null and lid != int(isolated_level): continue
		var rect := _current_room_rect(room)
		var selected := selected_type == "room" and selected_id == str(room.get("id", 0))
		var rtype := int(room.get("room_type", 0))

		# 2.5D Axonometric Depth (interpolates to 0 in top-down view)
		var depth_factor := 1.0 - floor_plan_transition
		var depth_dy := -14.0 * depth_factor
		var back_rect := Rect2(rect.position.x + 4.0 * depth_factor, rect.position.y + depth_dy, rect.size.x - 8.0 * depth_factor, rect.size.y)

		# Recessed Chamber Dark Base
		draw_rect(back_rect, Color(0.0, 0.05, 0.02, 0.6), true)

		# Subtle Functional Category Tint
		var tint: Color = _room_tint(rtype)
		draw_rect(rect, tint, true)

		if depth_factor > 0.05:
			# 4 Perspective Depth Lines
			var d_col := Color(WIRE_DIM.r, WIRE_DIM.g, WIRE_DIM.b, WIRE_DIM.a * depth_factor)
			draw_line(rect.position, back_rect.position, d_col, 1.0)
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(back_rect.end.x, back_rect.position.y), d_col, 1.0)
			draw_line(Vector2(rect.position.x, rect.end.y), Vector2(back_rect.position.x, back_rect.end.y), d_col, 1.0)
			draw_line(Vector2(rect.end.x, rect.end.y), Vector2(back_rect.end.x, back_rect.end.y), d_col, 1.0)
			draw_rect(back_rect, d_col, false, 1.0)

			# 3D Floor Perspective Grid Lines
			var grid_cols := maxi(2, int(rect.size.x / 30.0))
			for g in range(1, grid_cols):
				var frac := float(g) / float(grid_cols)
				var f_pt := Vector2(rect.position.x + rect.size.x * frac, rect.end.y)
				var b_pt := Vector2(back_rect.position.x + back_rect.size.x * frac, back_rect.end.y)
				draw_line(f_pt, b_pt, WIRE_DARK, 1.0)

		# Front Room Frame (Glowing Phosphor Green)
		var border_color := WIRE_ACCENT if selected else WIRE_MID
		draw_rect(rect, border_color, false, 2.5 if selected else 1.5)

		if selected:
			_draw_corner_brackets(rect.grow(4.0), WIRE_BRIGHT, 8.0, 2.0)

		# Zoomed-In Interior Sketches
		if z >= 0.35:
			_draw_room_interior_wireframe(rtype, rect, back_rect)

		# Room Header Labels & Icons
		if room_label_mode != 2: # 2 is OFF
			var icon_color := WIRE_BRIGHT if selected else WIRE_MID
			if room_label_mode == 1: # ICONS ONLY (Clean decluttered map)
				if z >= 0.25 or floor_plan_transition > 0.3:
					_draw_room_symbol(rtype, rect.position + Vector2(16, 16), 9.0, icon_color)
					if z >= 0.45 or floor_plan_transition > 0.6:
						draw_string(ThemeDB.fallback_font, rect.position + Vector2(28, 20), "#%s" % room.get("id", "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, WIRE_MID)
			else: # FULL (Text + Icon + Cap)
				if z >= 0.28 or floor_plan_transition > 0.35:
					_draw_room_symbol(rtype, rect.position + Vector2(14, 15), 7.0, icon_color)
					var label := _room_label(room)
					draw_string(ThemeDB.fallback_font, rect.position + Vector2(26, 17), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 30, 11, WIRE_BRIGHT)
					if z >= 0.48 or floor_plan_transition > 0.7:
						draw_string(ThemeDB.fallback_font, rect.position + Vector2(26, 32), "#%s · CAP %s" % [room.get("id", "?"), room.get("capacity", "—")], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 30, 10, WIRE_MID)

func _draw_room_symbol(rtype: int, c: Vector2, r: float, col: Color) -> void:
	match rtype:
		0: # Residential Apartment: House silhouette
			var pts: PackedVector2Array = [
				c + Vector2(0, -r),
				c + Vector2(r * 0.9, -r * 0.15),
				c + Vector2(r * 0.9, r * 0.9),
				c + Vector2(-r * 0.9, r * 0.9),
				c + Vector2(-r * 0.9, -r * 0.15)
			]
			draw_polyline(pts, col, 1.5, true)
			draw_line(c + Vector2(-r * 0.25, r * 0.9), c + Vector2(-r * 0.25, r * 0.35), col, 1.2)
			draw_line(c + Vector2(-r * 0.25, r * 0.35), c + Vector2(r * 0.25, r * 0.35), col, 1.2)
			draw_line(c + Vector2(r * 0.25, r * 0.35), c + Vector2(r * 0.25, r * 0.9), col, 1.2)
		1: # Dormitory: Bunk bed
			draw_line(c + Vector2(-r * 0.8, -r * 0.2), c + Vector2(r * 0.8, -r * 0.2), col, 1.8)
			draw_line(c + Vector2(-r * 0.8, r * 0.5), c + Vector2(r * 0.8, r * 0.5), col, 1.8)
			draw_line(c + Vector2(-r * 0.8, -r * 0.7), c + Vector2(-r * 0.8, r * 0.8), col, 1.5)
			draw_line(c + Vector2(r * 0.8, -r * 0.7), c + Vector2(r * 0.8, r * 0.8), col, 1.5)
			draw_line(c + Vector2(r * 0.3, -r * 0.2), c + Vector2(r * 0.3, r * 0.5), col, 1.2)
		2, 3: # Canteen / Kitchen: Dining bowl with steam
			var arc_pts: PackedVector2Array = []
			for i in range(9):
				var ang: float = float(i) * PI / 8.0
				arc_pts.append(c + Vector2(cos(ang) * r * 0.8, sin(ang) * r * 0.5 + r * 0.15))
			draw_polyline(arc_pts, col, 1.5)
			draw_line(c + Vector2(-r * 0.8, r * 0.15), c + Vector2(r * 0.8, r * 0.15), col, 1.5)
			draw_line(c + Vector2(-r * 0.3, -r * 0.05), c + Vector2(-r * 0.35, -r * 0.55), col, 1.2)
			draw_line(c + Vector2(r * 0.3, -r * 0.05), c + Vector2(r * 0.35, -r * 0.55), col, 1.2)
		4: # Hygiene: Shower spray
			draw_line(c + Vector2(-r * 0.6, -r * 0.5), c + Vector2(0, -r * 0.7), col, 1.6)
			draw_line(c + Vector2(-r * 0.3, -r * 0.3), c + Vector2(r * 0.3, -r * 0.7), col, 2.0)
			draw_line(c + Vector2(-r * 0.3, 0), c + Vector2(-r * 0.5, r * 0.7), col, 1.2)
			draw_line(c + Vector2(0, 0), c + Vector2(-r * 0.1, r * 0.75), col, 1.2)
			draw_line(c + Vector2(r * 0.3, 0), c + Vector2(r * 0.3, r * 0.7), col, 1.2)
		5: # Machine Shop: Gear
			draw_arc(c, r * 0.5, 0, TAU, 12, col, 1.5)
			for i in range(6):
				var a := float(i) * TAU / 6.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.45, c + Vector2(cos(a), sin(a)) * r * 0.85, col, 1.8)
		6: # Foundry: Crucible
			var f_pts: PackedVector2Array = [
				c + Vector2(-r * 0.7, -r * 0.5), c + Vector2(r * 0.7, -r * 0.5),
				c + Vector2(r * 0.45, r * 0.7), c + Vector2(-r * 0.45, r * 0.7)
			]
			draw_polyline(f_pts, col, 1.5, true)
			draw_line(c + Vector2(-r * 0.9, -r * 0.5), c + Vector2(r * 0.9, -r * 0.5), col, 1.4)
		7: # Deep Mine: Crossed pickaxes
			draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.7, -r * 0.7), col, 1.5)
			draw_line(c + Vector2(r * 0.7, r * 0.7), c + Vector2(-r * 0.7, -r * 0.7), col, 1.5)
			draw_line(c + Vector2(r * 0.4, -r * 0.85), c + Vector2(r * 0.85, -r * 0.4), col, 2.2)
			draw_line(c + Vector2(-r * 0.85, -r * 0.4), c + Vector2(-r * 0.4, -r * 0.85), col, 2.2)
		8, 23: # Water Pump / Treatment: Teardrop & waves
			draw_line(c + Vector2(0, -r * 0.8), c + Vector2(r * 0.5, r * 0.2), col, 1.5)
			draw_line(c + Vector2(0, -r * 0.8), c + Vector2(-r * 0.5, r * 0.2), col, 1.5)
			draw_arc(c + Vector2(0, r * 0.2), r * 0.5, 0, PI, 8, col, 1.5)
			draw_line(c + Vector2(-r * 0.7, r * 0.75), c + Vector2(r * 0.7, r * 0.75), col, 1.2)
		9: # Server Room: 3 Rack slots
			draw_rect(Rect2(c - Vector2(r * 0.7, r * 0.6), Vector2(r * 1.4, r * 0.35)), col, false, 1.2)
			draw_rect(Rect2(c - Vector2(r * 0.7, -r * 0.05), Vector2(r * 1.4, r * 0.35)), col, false, 1.2)
			draw_circle(c + Vector2(-r * 0.4, -r * 0.42), 1.5, col)
			draw_circle(c + Vector2(-r * 0.4, r * 0.12), 1.5, col)
		10: # Clinic: Medical Cross
			draw_line(c + Vector2(-r * 0.7, 0), c + Vector2(r * 0.7, 0), col, 2.6)
			draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.7), col, 2.6)
		11: # School: Open book
			var b_l: PackedVector2Array = [c + Vector2(0, r * 0.4), c + Vector2(-r * 0.8, r * 0.25), c + Vector2(-r * 0.8, -r * 0.45), c + Vector2(0, -r * 0.3)]
			var b_r: PackedVector2Array = [c + Vector2(0, r * 0.4), c + Vector2(r * 0.8, r * 0.25), c + Vector2(r * 0.8, -r * 0.45), c + Vector2(0, -r * 0.3)]
			draw_polyline(b_l, col, 1.4, true)
			draw_polyline(b_r, col, 1.4, true)
			draw_line(c + Vector2(0, -r * 0.3), c + Vector2(0, r * 0.4), col, 1.8)
		12: # Admin: Pillar facade
			draw_line(c + Vector2(-r * 0.8, -r * 0.4), c + Vector2(0, -r * 0.8), col, 1.5)
			draw_line(c + Vector2(0, -r * 0.8), c + Vector2(r * 0.8, -r * 0.4), col, 1.5)
			draw_line(c + Vector2(-r * 0.8, -r * 0.4), c + Vector2(r * 0.8, -r * 0.4), col, 1.5)
			draw_line(c + Vector2(-r * 0.5, -r * 0.4), c + Vector2(-r * 0.5, r * 0.6), col, 1.4)
			draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, r * 0.6), col, 1.4)
			draw_line(c + Vector2(r * 0.5, -r * 0.4), c + Vector2(r * 0.5, r * 0.6), col, 1.4)
			draw_line(c + Vector2(-r * 0.8, r * 0.6), c + Vector2(r * 0.8, r * 0.6), col, 1.5)
		13: # Recreation: Diamond star
			var d_pts: PackedVector2Array = [c + Vector2(0, -r * 0.8), c + Vector2(r * 0.7, 0), c + Vector2(0, r * 0.8), c + Vector2(-r * 0.7, 0)]
			draw_polyline(d_pts, col, 1.5, true)
		14: # Storage: Crate with X brace
			draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.6), Vector2(r * 1.2, r * 1.2)), col, false, 1.5)
			draw_line(c - Vector2(r * 0.5, r * 0.5), c + Vector2(r * 0.5, r * 0.5), col, 1.0)
			draw_line(c + Vector2(-r * 0.5, r * 0.5), c + Vector2(r * 0.5, -r * 0.5), col, 1.0)
		15: # Security: Shield
			var s_pts: PackedVector2Array = [
				c + Vector2(-r * 0.7, -r * 0.7), c + Vector2(r * 0.7, -r * 0.7),
				c + Vector2(r * 0.6, r * 0.1), c + Vector2(0, r * 0.8), c + Vector2(-r * 0.6, r * 0.1)
			]
			draw_polyline(s_pts, col, 1.6, true)
		16: # Bio-Farm: Seedling Sprout
			draw_line(c + Vector2(0, r * 0.75), c + Vector2(0, -r * 0.25), col, 1.8)
			draw_line(c + Vector2(0, 0), c + Vector2(-r * 0.55, -r * 0.35), col, 1.5)
			draw_line(c + Vector2(-r * 0.55, -r * 0.35), c + Vector2(0, -r * 0.25), col, 1.5)
			draw_line(c + Vector2(0, -r * 0.1), c + Vector2(r * 0.55, -r * 0.45), col, 1.5)
			draw_line(c + Vector2(r * 0.55, -r * 0.45), c + Vector2(0, -r * 0.25), col, 1.5)
		18: # Waste Processing: Recycling arrows
			var t1 := c + Vector2(0, -r * 0.75)
			var t2 := c + Vector2(r * 0.7, r * 0.55)
			var t3 := c + Vector2(-r * 0.7, r * 0.55)
			draw_line(t1, t2, col, 1.5); draw_line(t2, t3, col, 1.5); draw_line(t3, t1, col, 1.5)
			draw_line(t1, t1 + Vector2(r * 0.2, r * 0.1), col, 1.4)
			draw_line(t2, t2 + Vector2(-r * 0.1, -r * 0.2), col, 1.4)
		19: # Air Handler: Ventilation Fan
			draw_arc(c, r * 0.7, 0, TAU, 12, col, 1.2)
			for i in range(4):
				var a := float(i) * PI * 0.5 + 0.25
				draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.65, col, 1.8)
		20: # Power Plant: Lightning bolt
			var bolt: PackedVector2Array = [
				c + Vector2(r * 0.2, -r * 0.75), c + Vector2(-r * 0.3, 0),
				c + Vector2(r * 0.1, 0), c + Vector2(-r * 0.2, r * 0.75),
				c + Vector2(r * 0.35, -r * 0.1), c + Vector2(0, -r * 0.1)
			]
			draw_polyline(bolt, col, 1.6, true)
		_: # Generic Room
			draw_rect(Rect2(c - Vector2(r * 0.5, r * 0.5), Vector2(r, r)), col, false, 1.4)

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
		0: # Residential: Double bunk bed frame and locker
			var bx := rect.position.x + 8.0; var by := rect.end.y - 6.0
			draw_rect(Rect2(bx, by - 30, 22, 28), WIRE_DIM, false, 1.0)
			draw_line(Vector2(bx, by - 14), Vector2(bx + 22, by - 14), WIRE_MID, 1.0)
			if rect.size.x > 130:
				var bx2 := rect.end.x - 30.0
				draw_rect(Rect2(bx2, by - 30, 22, 28), WIRE_DIM, false, 1.0)
				draw_line(Vector2(bx2, by - 14), Vector2(bx2 + 22, by - 14), WIRE_MID, 1.0)
		3: # Bio-farm: 3 tiers of hydroponic grow racks
			var rx1 := rect.position.x + 10.0; var rx2 := rect.end.x - 10.0; var by := rect.end.y - 8.0
			draw_line(Vector2(rx1, by - 8), Vector2(rx2, by - 8), WIRE_BRIGHT, 1.5)
			draw_line(Vector2(rx1, by - 22), Vector2(rx2, by - 22), WIRE_BRIGHT, 1.5)
			draw_line(Vector2(rx1, by - 36), Vector2(rx2, by - 36), WIRE_BRIGHT, 1.5)
		6: # Water: 2 cylindrical tanks with pipe manifold
			var tx1 := rect.position.x + 16.0; var by := rect.end.y - 6.0
			draw_rect(Rect2(tx1, by - 36, 26, 34), WIRE_CYAN, false, 1.5)
			draw_line(Vector2(tx1, by - 36), Vector2(tx1 + 26, by - 36), WIRE_BRIGHT, 2.0)
			if rect.size.x > 110:
				var tx2 := rect.position.x + 56.0
				draw_rect(Rect2(tx2, by - 36, 26, 34), WIRE_CYAN, false, 1.5)
				draw_line(Vector2(tx1 + 26, by - 18), Vector2(tx2, by - 18), WIRE_BRIGHT, 1.5)
		2: # Clinic: Medical examination gurney and IV drip stand
			var mx := rect.position.x + 18.0; var by := rect.end.y - 8.0
			draw_line(Vector2(mx, by - 8), Vector2(mx + 28, by - 8), WIRE_MID, 2.0)
			draw_line(Vector2(mx, by - 16), Vector2(mx + 8, by - 8), WIRE_MID, 1.5)
			draw_line(Vector2(mx - 6, by), Vector2(mx - 6, by - 26), WIRE_BRIGHT, 1.0)
		1: # School: Blackboard and student dual-desks
			var bx := rect.position.x + 12.0; var by := rect.end.y - 8.0
			draw_rect(Rect2(bx, rect.position.y + 12, maxi(40, int(rect.size.x - 24)), 16), WIRE_MID, false, 1.0)
			for d in range(mini(6, int((rect.size.x - 40) / 45.0))):
				draw_rect(Rect2(bx + 10 + d * 45, by - 14, 20, 12), WIRE_DIM, false, 1.0)
		4, 5, 8: # Industry / Deep Mine: Heavy industrial machinery silhouette
			var ix := rect.position.x + 14.0; var by := rect.end.y - 8.0
			draw_rect(Rect2(ix, by - 26, 42, 24), WIRE_ACCENT, false, 1.5)
			draw_line(Vector2(ix + 12, by - 36), Vector2(ix + 12, by - 26), WIRE_BRIGHT, 1.5)
			if rect.size.x > 260:
				var ix2 := rect.end.x - 60.0
				draw_rect(Rect2(ix2, by - 26, 42, 24), WIRE_ACCENT, false, 1.5)
		_:
			var cx := rect.position.x + 14.0; var by := rect.end.y - 8.0
			draw_rect(Rect2(cx, by - 18, 24, 16), WIRE_DIM, false, 1.0)

func _draw_stairs() -> void:
	var segments: Array = geometry.get("stair_segments", geometry.get("connectors", []))
	if segments.is_empty(): return
	var b := _bounds_rect()
	var center_x := (b.position.x - 24.0 + b.end.x + 24.0) * 0.5
	var cutaway_alpha := 1.0 - floor_plan_transition

	if cutaway_alpha <= 0.01: return

	# 1. Dual Vertical Elevator Shafts
	if isolated_level == null:
		var col_mid := Color(WIRE_MID.r, WIRE_MID.g, WIRE_MID.b, WIRE_MID.a * cutaway_alpha)
		var col_bright := Color(WIRE_BRIGHT.r, WIRE_BRIGHT.g, WIRE_BRIGHT.b, WIRE_BRIGHT.a * cutaway_alpha)
		for shaft_x in [center_x - 28.0, center_x + 28.0]:
			draw_line(Vector2(shaft_x - 6, -180), Vector2(shaft_x - 6, b.end.y + 100), col_mid, 1.5)
			draw_line(Vector2(shaft_x + 6, -180), Vector2(shaft_x + 6, b.end.y + 100), col_mid, 1.5)
			for car_level in [2, 7, 12, 18]:
				var car_y := float(car_level - 1) * 142.0 + 30.0
				var car_rect := Rect2(shaft_x - 5, car_y, 10, 18)
				draw_rect(car_rect, CRT_BG, true)
				draw_rect(car_rect, col_bright, false, 1.5)

	# 2. Central Zig-Zag Staircase Flights
	for seg in segments:
		var from_lid := int(seg.get("from_level", -999))
		var to_lid := int(seg.get("to_level", -999))
		if isolated_level != null and from_lid != int(isolated_level) and to_lid != int(isolated_level): continue

		var a := _landing_point(from_lid, seg)
		var b_pt := _landing_point(to_lid, seg, true)
		var zig_dir := 1.0 if (from_lid % 2 == 1) else -1.0
		var flight_start := Vector2(center_x - 14.0 * zig_dir, a.y)
		var flight_end := Vector2(center_x + 14.0 * zig_dir, b_pt.y)

		var col_mid := Color(WIRE_MID.r, WIRE_MID.g, WIRE_MID.b, WIRE_MID.a * cutaway_alpha)
		var col_bright := Color(WIRE_BRIGHT.r, WIRE_BRIGHT.g, WIRE_BRIGHT.b, WIRE_BRIGHT.a * cutaway_alpha)

		draw_line(flight_start, flight_end, col_mid, 16.0)
		draw_line(flight_start, flight_end, CRT_BG, 10.0)
		draw_line(flight_start + Vector2(-6, 0), flight_end + Vector2(-6, 0), col_bright, 1.5)
		draw_line(flight_start + Vector2(6, 0), flight_end + Vector2(6, 0), col_bright, 1.5)

		var step_count := maxi(4, int(absf(flight_end.y - flight_start.y) / 7.0))
		for s in range(step_count + 1):
			var p := flight_start.lerp(flight_end, float(s) / float(step_count))
			draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), col_bright, 1.0)

		if camera.zoom.x >= 0.32:
			var occ_val: Variant = seg.get("occupancy", 0)
			var occ: int = occ_val.size() if (occ_val is Dictionary or occ_val is Array) else int(occ_val)
			var cap := int(seg.get("capacity", 0))
			var q_val: Variant = seg.get("queue_length", seg.get("queue", 0))
			var queue: int = q_val.size() if q_val is Array else int(q_val)
			var text_color := WIRE_ALERT if queue > 10 else (WIRE_ACCENT if queue > 0 else WIRE_MID)
			var mid := flight_start.lerp(flight_end, 0.5)
			draw_string(ThemeDB.fallback_font, mid + Vector2(16, 2), "%d/%d [Q:%d]" % [occ, cap, queue], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(text_color.r, text_color.g, text_color.b, cutaway_alpha))

	# 3. Landing Catwalk Platforms
	for landing in geometry.get("landings", []):
		var lid := int(landing.get("level", 0))
		if isolated_level != null and lid != int(isolated_level): continue
		var p := Vector2(float(landing.get("x", 0)), float(landing.get("y", 0)))
		var w := float(landing.get("width", 68.0))
		var l_rect := Rect2(p.x, p.y + float(landing.get("height", 104.0)) - 8.0, w, 8.0)
		draw_rect(l_rect, CRT_BG, true)
		draw_rect(l_rect, Color(WIRE_BRIGHT.r, WIRE_BRIGHT.g, WIRE_BRIGHT.b, cutaway_alpha), false, 2.0)

func _landing_point(level_id: Variant, seg: Dictionary, destination := false) -> Vector2:
	for landing in geometry.get("landings", []):
		if int(landing.get("level", -999)) == int(level_id):
			return Vector2(float(landing.get("x", 0)) + float(landing.get("width", 68.0)) * 0.5, float(landing.get("y", 0)) + float(landing.get("height", 104.0)))
	var x := float(seg.get("x", _bounds_rect().get_center().x))
	var y := 0.0
	for level in geometry.get("levels", []):
		if int(level.get("id", -999)) == int(level_id): y = float(level.get("floor_y", float(level.get("y", 0)) + 104.0)); break
	return Vector2(x + (16.0 if destination else -16.0), y)

func _draw_people() -> void:
	var z := camera.zoom.x
	person_draw_positions.clear()
	var buckets: Dictionary = {}

	for person in people_by_id.values():
		if not bool(person.get("is_alive", true)): continue
		var rid := int(person.get("location_id", 0))
		if not room_by_id.has(rid): continue
		var room: Dictionary = room_by_id[rid]
		var r_level := int(room.get("level", 0))
		if isolated_level != null and r_level != int(isolated_level): continue
		if not buckets.has(rid): buckets[rid] = []
		buckets[rid].append(person)

	var dot_radius: float = clampf(2.6 / maxf(0.05, z), 3.5, 8.5)
	var glow_radius: float = dot_radius + clampf(1.6 / maxf(0.05, z), 2.0, 5.0)

	for rid in buckets:
		var people: Array = buckets[rid]; var room: Dictionary = room_by_id[rid]; var rect := _current_room_rect(room)
		var max_visible := people.size()

		# Generous multi-column layout filling wide room bays without overflowing
		var columns := maxi(4, int((rect.size.x - 24.0) / 13.0))

		for i in range(max_visible):
			var p: Dictionary = people[i]
			var pid := int(p.get("id", 0))
			var col := i % columns
			var row := i / columns

			# Position neatly on the room's 2.5D or top-down floor plane
			var pos := rect.position + Vector2(12.0 + col * 12.0, rect.size.y - 8.0 - row * 9.0)
			if str(p.get("activity", "")).to_lower().contains("travel"):
				pos = _journey_position(p, pos)

			person_draw_positions[pid] = pos
			var chosen := selected_type == "person" and selected_id == str(pid)

			# Use smooth interpolated visual position
			var draw_pos: Vector2 = person_visual_positions.get(pid, pos)

			# Vibrant Vector Red Dot Rendering (Outer glow + vivid red core)
			var cur_radius: float = dot_radius * 1.35 if chosen else dot_radius
			draw_circle(draw_pos, cur_radius + (3.0 if chosen else (glow_radius - dot_radius)), PERSON_GLOW)
			draw_circle(draw_pos, cur_radius, PERSON_COLOR)

			if chosen:
				# Tactical HUD reticle [ + ] around chosen resident
				_draw_reticle(draw_pos, WIRE_BRIGHT, 12.0)
				# Direct route vector line to target destination room
				var dst_id := int(p.get("destination_id", 0))
				if dst_id > 0 and room_by_id.has(dst_id):
					var dst_pos := _current_room_rect(room_by_id[dst_id]).get_center()
					draw_dashed_line(draw_pos, dst_pos, UI_ACCENT, 1.5, 6.0)
				if z >= 0.35 or floor_plan_transition > 0.4:
					var tag := "%s [%s]" % [p.get("name", "CITIZEN"), p.get("activity", "IDLE")]
					draw_string(ThemeDB.fallback_font, draw_pos + Vector2(14, -8), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_BORDER_BRIGHT)

func _draw_reticle(pos: Vector2, color: Color, size: float) -> void:
	draw_line(pos - Vector2(size + 4, 0), pos - Vector2(size - 4, 0), color, 1.5)
	draw_line(pos + Vector2(size - 4, 0), pos + Vector2(size + 4, 0), color, 1.5)
	draw_line(pos - Vector2(0, size + 4), pos - Vector2(0, size - 4), color, 1.5)
	draw_line(pos + Vector2(0, size - 4), pos + Vector2(0, size + 4), color, 1.5)
	_draw_corner_brackets(Rect2(pos - Vector2(size, size), Vector2(size * 2, size * 2)), color, 5.0, 1.5)

func _draw_corner_brackets(rect: Rect2, color: Color, len_arm: float, thick: float) -> void:
	draw_line(rect.position, rect.position + Vector2(len_arm, 0), color, thick)
	draw_line(rect.position, rect.position + Vector2(0, len_arm), color, thick)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - len_arm, rect.position.y), color, thick)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + len_arm), color, thick)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + len_arm, rect.end.y), color, thick)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - len_arm), color, thick)
	draw_line(rect.end, rect.end - Vector2(len_arm, 0), color, thick)
	draw_line(rect.end, rect.end - Vector2(0, len_arm), color, thick)

func _journey_position(person: Dictionary, fallback: Vector2) -> Vector2:
	var journey: Dictionary = person.get("journey", {})
	if journey.is_empty():
		var dst := int(person.get("destination_id", 0))
		return fallback.lerp(_current_room_rect(room_by_id[dst]).get_center(), float(person.get("travel_progress", 0.0))) if room_by_id.has(dst) else fallback
	var phase := str(journey.get("phase", ""))
	var origin_id := int(journey.get("origin_room_id", 0)); var destination_id := int(journey.get("destination_room_id", 0))
	var origin := _current_room_rect(room_by_id[origin_id]).get_center() if room_by_id.has(origin_id) else fallback
	var destination := _current_room_rect(room_by_id[destination_id]).get_center() if room_by_id.has(destination_id) else fallback
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
		var pos := _current_room_rect(room).position + Vector2(18, 48)
		machine_draw_positions[int(machine.get("id", 0))] = pos
		var poor := str(machine.get("state", "NOMINAL")) in ["FAULT", "BROKEN"]
		var m_color := UI_ALERT if poor else WIRE_BRIGHT
		var pts: PackedVector2Array = [pos + Vector2(0, -7), pos + Vector2(7, 0), pos + Vector2(0, 7), pos + Vector2(-7, 0)]
		draw_colored_polygon(pts, CRT_BG)
		draw_polyline(pts, m_color, 2.0)
		draw_line(pos + Vector2(-7, 0), pos + Vector2(0, -7), m_color, 2.0)

	for incident in snapshot.get("incidents", {}).get("active_incidents", []):
		var rid := int(incident.get("room_id", 0))
		if room_by_id.has(rid):
			var ipos := _current_room_rect(room_by_id[rid]).position + Vector2(36, 48)
			draw_circle(ipos, 8, UI_ALERT)
			_draw_corner_brackets(Rect2(ipos - Vector2(12, 12), Vector2(24, 24)), UI_ALERT, 5.0, 1.5)

func _zoom(factor: float, screen: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * screen
	var z := clampf(camera.zoom.x * factor, 0.05, 3.5); camera.zoom = Vector2(z, z)
	var after := get_canvas_transform().affine_inverse() * screen; camera.position += before - after

func _pick(point: Vector2) -> void:
	if view_mode == VIEW_ISOMETRIC:
		var nearest_person := 0; var nearest_distance := 14.0
		for pid in person_draw_positions:
			var distance := (person_draw_positions[pid] as Vector2).distance_to(point)
			if distance < nearest_distance: nearest_distance = distance; nearest_person = int(pid)
		if nearest_person > 0:
			_select("person", str(nearest_person), int(people_by_id[nearest_person].get("location_id", 0))); return

		for rid in room_iso_rect_cache:
			var info: Dictionary = room_iso_rect_cache[rid]
			var poly: PackedVector2Array = info.get("poly", [])
			if Geometry2D.is_point_in_polygon(point, poly):
				_select("room", str(rid), rid); return
		return

	if camera.zoom.x >= 0.45 or floor_plan_transition > 0.4:
		for mid in machine_draw_positions:
			if (machine_draw_positions[mid] as Vector2).distance_to(point) <= 12.0:
				_select("machine", str(mid), int(machine_by_id[mid].get("room_id", 0))); return
		var nearest_person := 0; var nearest_distance := 12.0
		for pid in person_draw_positions:
			var distance := (person_draw_positions[pid] as Vector2).distance_to(point)
			if distance < nearest_distance: nearest_distance = distance; nearest_person = int(pid)
		if nearest_person > 0:
			_select("person", str(nearest_person), int(people_by_id[nearest_person].get("location_id", 0))); return
	for room in geometry.get("rooms", []):
		if _current_room_rect(room).has_point(point): _select("room", str(room.get("id", 0)), int(room.get("id", 0))); return
	if floor_plan_transition < 0.5:
		for seg in geometry.get("stair_segments", geometry.get("connectors", [])):
			var a := _landing_point(seg.get("from_level", 0), seg); var b := _landing_point(seg.get("to_level", 0), seg, true)
			if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < 18: _select_stair(seg); return

func _select(type: String, id: String, room_id: int) -> void:
	selected_type = type; selected_id = id; selected_room_id = room_id
	follow_button.disabled = type != "person"; _show_details(type, id); queue_redraw()

func _select_stair(seg: Dictionary) -> void:
	selected_type = "stair"; selected_id = str(seg.get("id", "stair")); selected_room_id = 0; follow_button.disabled = true
	var lines: Array[String] = [
		"[font_size=18][color=#90e0ef]CENTRAL CIRCULATION SHAFT[/color][/font_size]",
		"[color=#ffb703]SEGMENT: %s[/color]" % selected_id,
		"[color=#64d2ff]Connected Levels:[/color] %s → %s" % [seg.get("from_level", "?"), seg.get("to_level", "?")],
		"[color=#64d2ff]Occupancy / Capacity:[/color] [color=#ffffff]%s / %s[/color]" % [seg.get("occupancy", 0), seg.get("capacity", "pending")],
		"[color=#64d2ff]Queued Commuters:[/color] [color=#ffb703]%s[/color]" % seg.get("queue_length", 0),
		"[color=#64d2ff]Congestion Flag:[/color] %s" % str(seg.get("congestion", false)),
		"[color=#64d2ff]Base Travel Time:[/color] %s ticks" % seg.get("base_travel_ticks", "pending"),
		"[color=#64d2ff]Estimated Travel Time:[/color] %s ticks" % seg.get("travel_time_ticks_estimate", seg.get("base_travel_ticks", "pending"))
	]
	details_label.text = "\n".join(lines)

func _show_details(type: String, id: String) -> void:
	var resolved := Reader.resolve_entity(ws, type, id)
	if resolved.is_empty(): details_label.text = "[color=#ff3b5c]Entity no longer available in authoritative simulation.[/color]"; return
	selected_room_id = int(resolved.get("room_id", selected_room_id))
	details_label.text = "[font_size=18][color=#00e5ff]%s #%s[/color][/font_size]\n[color=#7a9bb8]AUTHORITATIVE SIMULATION TELEMETRY[/color]\n\n%s" % [type.to_upper(), id, _format_details(resolved.get("details", {}))]

func _format_details(details: Dictionary) -> String:
	var lines: Array[String] = []

	# Priority formatting for clean, structured human readability without raw JSON
	for key in details.keys():
		var value: Variant = details[key]
		var title: String = _pretty(str(key))

		if key in ["members", "occupants"]:
			var arr: Array = value as Array
			lines.append("[color=#90e0ef]── %s (%d) ──[/color]" % [title.to_upper(), arr.size()])
			if arr.is_empty():
				lines.append("  [color=#7a9bb8]• (None currently present)[/color]")
			else:
				for item in arr.slice(0, 30):
					if item is Dictionary:
						lines.append("  " + _format_person_item(item))
					elif item is int or (item is String and (item as String).is_valid_int()):
						var pid := int(item)
						if people_by_id.has(pid):
							lines.append("  " + _format_person_item(people_by_id[pid]))
						else:
							lines.append("  • [color=#ffffff]Citizen #%d[/color]" % pid)
					else:
						lines.append("  • [color=#ffffff]%s[/color]" % str(item))
				if arr.size() > 30: lines.append("  [color=#7a9bb8]… %d more[/color]" % (arr.size() - 30))
		elif key == "workers":
			var arr: Array = value as Array
			lines.append("[color=#90e0ef]── WORKERS ASSIGNED (%d) ──[/color]" % arr.size())
			if arr.is_empty():
				lines.append("  [color=#7a9bb8]• (No workers assigned)[/color]")
			else:
				for item in arr.slice(0, 30):
					if item is Dictionary: lines.append("  " + _format_worker_item(item))
					else: lines.append("  • [color=#ffffff]%s[/color]" % str(item))
				if arr.size() > 30: lines.append("  [color=#7a9bb8]… %d more[/color]" % (arr.size() - 30))
		elif key == "students":
			var arr: Array = value as Array
			lines.append("[color=#90e0ef]── ENROLLED STUDENTS (%d) ──[/color]" % arr.size())
			if arr.is_empty():
				lines.append("  [color=#7a9bb8]• (No students enrolled)[/color]")
			else:
				for item in arr.slice(0, 30):
					if item is Dictionary: lines.append("  " + _format_student_item(item))
					else: lines.append("  • [color=#ffffff]%s[/color]" % str(item))
				if arr.size() > 30: lines.append("  [color=#7a9bb8]… %d more[/color]" % (arr.size() - 30))
		elif key == "households":
			var arr: Array = value as Array
			lines.append("[color=#90e0ef]── RESIDENT HOUSEHOLDS (%d) ──[/color]" % arr.size())
			if arr.is_empty():
				lines.append("  [color=#7a9bb8]• (Unoccupied)[/color]")
			else:
				for item in arr:
					if item is Dictionary: lines.append("  " + _format_household_item(item))
					else: lines.append("  • [color=#ffffff]%s[/color]" % str(item))
		elif key == "occupied_beds":
			var b_dict := value as Dictionary
			lines.append("[color=#90e0ef]── RESIDENT BED ASSIGNMENTS (%d) ──[/color]" % b_dict.size())
			if b_dict.is_empty():
				lines.append("  [color=#7a9bb8]• (All beds unassigned)[/color]")
			else:
				for bed_idx in b_dict.keys():
					var pid := int(b_dict[bed_idx])
					if people_by_id.has(pid):
						var p: Dictionary = people_by_id[pid]
						lines.append("  • [color=#7a9bb8]Bed %s:[/color] [b][color=#ffffff]%s[/color][/b] [color=#64d2ff](%s · %s)[/color]" % [
							str(bed_idx),
							p.get("name", p.get("full_name", "Citizen #%d" % pid)),
							_pretty(str(p.get("occupation", "Resident"))),
							_life_stage_name(int(p.get("life_stage", 3)))
						])
					else:
						lines.append("  • [color=#7a9bb8]Bed %s:[/color] [color=#ffffff]Citizen #%d[/color]" % [str(bed_idx), pid])
		elif key == "machines":
			var arr: Array = value as Array
			lines.append("[color=#90e0ef]── MACHINERY (%d) ──[/color]" % arr.size())
			for item in arr:
				if item is Dictionary: lines.append("  " + _format_machine_item(item))
				else: lines.append("  • [color=#ffffff]%s[/color]" % str(item))
		elif key == "shifts":
			var s_dict := value as Dictionary
			lines.append("[color=#90e0ef]── SHIFT ASSIGNMENTS ──[/color]")
			for s_id in s_dict.keys():
				lines.append("  • [b][color=#ffffff]Shift %s:[/color][/b] [color=#64d2ff]%d workers[/color]" % [str(s_id), int(s_dict[s_id])])
		elif value is Dictionary:
			lines.append("[color=#64d2ff]%s:[/color]" % title)
			for subkey in (value as Dictionary).keys():
				var subval: Variant = (value as Dictionary)[subkey]
				if subval is Dictionary:
					lines.append("  • [color=#7a9bb8]%s:[/color]" % _pretty(str(subkey)))
					for k3 in (subval as Dictionary).keys():
						lines.append("      - [color=#7a9bb8]%s:[/color] [color=#ffffff]%s[/color]" % [_pretty(str(k3)), str((subval as Dictionary)[k3])])
				elif subval is Array:
					lines.append("  • [color=#7a9bb8]%s (%d):[/color]" % [_pretty(str(subkey)), (subval as Array).size()])
					for item in (subval as Array).slice(0, 10):
						if item is Dictionary: lines.append("      - " + _format_generic_dict(item))
						else: lines.append("      - [color=#ffffff]%s[/color]" % str(item))
				else:
					lines.append("  • [color=#7a9bb8]%s:[/color] [color=#ffffff]%s[/color]" % [_pretty(str(subkey)), str(subval)])
		elif value is Array:
			lines.append("[color=#64d2ff]%s:[/color]" % title)
			for item in (value as Array).slice(0, 15):
				if item is Dictionary: lines.append("  • " + _format_generic_dict(item))
				else: lines.append("  • [color=#ffffff]%s[/color]" % str(item))
		else:
			lines.append("[color=#64d2ff]%s:[/color] [color=#ffffff]%s[/color]" % [title, str(value)])

	return "\n".join(lines)

func _format_person_item(p: Dictionary) -> String:
	var pname := str(p.get("name", p.get("full_name", "Citizen #%s" % p.get("id", "?"))))
	var occ := _pretty(str(p.get("occupation", p.get("occupation_id", "Resident"))))
	var stage := _life_stage_name(int(p.get("life_stage", 3)))
	return "• [b][color=#ffffff]%s[/color][/b] [color=#64d2ff](%s · %s)[/color]" % [pname, occ, stage]

func _format_worker_item(w: Dictionary) -> String:
	var wname := str(w.get("name", "Worker #%s" % w.get("id", "?")))
	var job := _pretty(str(w.get("job", "Worker")))
	var shift := str(w.get("shift", "Default"))
	var present: bool = bool(w.get("present", false))
	var p_status := "[color=#00ff66][ON-SITE][/color]" if present else "[color=#7a9bb8][OFF-SITE][/color]"
	return "• [b][color=#ffffff]%s[/color][/b] [color=#64d2ff](%s · Shift %s)[/color] %s" % [wname, job, shift, p_status]

func _format_student_item(s: Dictionary) -> String:
	var sname := str(s.get("name", "Student #%s" % s.get("id", "?")))
	var present: bool = bool(s.get("present", false))
	var p_status := "[color=#00ff66][IN CLASS][/color]" if present else "[color=#7a9bb8][AWAY][/color]"
	return "• [b][color=#ffffff]%s[/color][/b] [color=#64d2ff](Student)[/color] %s" % [sname, p_status]

func _format_household_item(h: Dictionary) -> String:
	var hname := str(h.get("name", "Household #%s" % h.get("id", "?")))
	var head := str(h.get("head_name", "None"))
	var members: Array = h.get("members", []) as Array
	var m_count: int = h.get("member_count", members.size())
	var head_str := " · Head: %s" % head if head != "None" else ""
	var header := "• [b][color=#ffffff]%s[/color][/b] [color=#64d2ff](%d members%s)[/color]" % [hname, m_count, head_str]
	if members.is_empty():
		return header
	var m_lines: Array[String] = [header]
	for m in members:
		if m is Dictionary:
			m_lines.append("    " + _format_person_item(m))
		elif people_by_id.has(int(m)):
			m_lines.append("    " + _format_person_item(people_by_id[int(m)]))
		else:
			m_lines.append("    • [color=#ffffff]Citizen #%s[/color]" % str(m))
	return "\n".join(m_lines)

func _format_generic_dict(d: Dictionary) -> String:
	if d.has("name") or d.has("full_name"):
		return _format_person_item(d)
	elif d.has("machine_type"):
		return _format_machine_item(d)
	var parts: Array[String] = []
	for k in d.keys():
		parts.append("%s: %s" % [_pretty(str(k)), str(d[k])])
	return "[color=#ffffff]%s[/color]" % ", ".join(parts)

func _format_machine_item(m: Dictionary) -> String:
	var mtype := _pretty(str(m.get("machine_type", "Machine")))
	var state := str(m.get("state", "NOMINAL"))
	var state_color := "#00ff66" if state == "NOMINAL" else ("#ffb703" if state == "DEGRADED" else "#ff3b5c")
	var health := int(m.get("health", m.get("condition", 100)))
	return "• [b][color=#ffffff]%s #[/color]%s[/b] [color=%s][%s][/color] [color=#64d2ff](Health: %d%%)[/color]" % [mtype, m.get("id", "?"), state_color, state, health]

func _life_stage_name(stage: int) -> String:
	match stage:
		0: return "Infant"
		1: return "Child"
		2: return "Student"
		3: return "Adult"
		4: return "Elder"
		_: return "Citizen"

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
	var room: Dictionary = room_by_id[room_id]
	if view_mode == VIEW_ISOMETRIC:
		if room_iso_rect_cache.has(room_id):
			camera.position = room_iso_rect_cache[room_id]["center"]
			camera.zoom = Vector2.ONE * zoom_target
		return
	if isolated_level != null:
		_apply_isolated_level(int(room.get("level", 1)))
	camera.position = _current_room_rect(room).get_center()
	camera.zoom = Vector2.ONE * zoom_target

func _focus_person(id: int, select := true) -> void:
	if not people_by_id.has(id): return
	var person: Dictionary = people_by_id[id]; var rid := int(person.get("location_id", 0))
	if select: _select("person", str(id), rid)
	if view_mode == VIEW_ISOMETRIC:
		if person_draw_positions.has(id):
			camera.position = person_draw_positions[id]
			camera.zoom = Vector2.ONE * 0.8
		return
	var pos: Vector2 = _journey_position(person, _current_room_rect(room_by_id[rid]).get_center()) if room_by_id.has(rid) else Vector2(person_draw_positions.get(id, camera.position))
	camera.position = pos
	if not person.get("journey", {}).is_empty(): isolated_level = null

func _toggle_follow() -> void:
	if selected_type != "person": return
	follow_person_id = 0 if follow_person_id == int(selected_id) else int(selected_id)
	follow_button.text = "STOP TRACKING [G]" if follow_person_id > 0 else "TRACK CITIZEN [G]"

func _level_selected(index: int) -> void:
	var level_id: Variant = level_picker.get_item_metadata(index)
	_apply_isolated_level(int(level_id))

func _apply_isolated_level(lid: int) -> void:
	isolated_level = lid
	view_mode = VIEW_FLOOR_PLAN
	floor_plan_transition = 1.0
	if view_button: view_button.text = "VIEW: FLOOR PLAN [V]"
	if isolate_button: isolate_button.text = "SHOW ALL [I]"
	var cy := _level_center_y(lid)
	camera.position = Vector2(192.0 / 0.85, cy)
	camera.zoom = Vector2.ONE * 0.85
	_update_telemetry()
	queue_redraw()

func _toggle_isolate() -> void:
	if isolated_level != null:
		isolated_level = null
		floor_plan_transition = 0.0
		view_mode = VIEW_CUTAWAY
		if view_button: view_button.text = "VIEW: CUTAWAY [V]"
		if isolate_button: isolate_button.text = "ISOLATE [I]"
		_fit_whole()
	elif selected_room_id > 0 and room_by_id.has(selected_room_id):
		_apply_isolated_level(int(room_by_id[selected_room_id].get("level", 1)))
	else:
		_apply_isolated_level(1)
	_update_telemetry()
	queue_redraw()

func _fit_whole() -> void:
	if view_mode != VIEW_FLOOR_PLAN:
		isolated_level = null
	follow_person_id = 0
	if isolate_button: isolate_button.text = "ISOLATE [I]" if isolated_level == null else "SHOW ALL [I]"
	var rect := _whole_silo_rect().grow(30.0)
	var viewport := get_viewport_rect().size - Vector2(400, 75)
	var z := clampf(minf(viewport.x / maxf(1.0, rect.size.x), viewport.y / maxf(1.0, rect.size.y)), 0.05, 1.2)
	camera.zoom = Vector2.ONE * z
	camera.position = Vector2(rect.get_center().x + (192.0 / z), rect.get_center().y)
	_update_telemetry()
	queue_redraw()

func _bounds_rect() -> Rect2:
	var b: Dictionary = geometry.get("bounds", {})
	return Rect2(float(b.get("x", 0)), float(b.get("y", 0)), maxf(1, float(b.get("width", 1000))), maxf(1, float(b.get("height", 1000))))

func _whole_silo_rect() -> Rect2:
	if view_mode == VIEW_ISOMETRIC:
		return Rect2(-650, -150, 1300, 2600)
	var b := _bounds_rect()
	return Rect2(b.position.x - 270.0, -260.0, b.size.x + 360.0, b.size.y + 530.0)

# Interpolated room rectangle: smoothly transitions between vertical cutaway and top-down floor plan
func _current_room_rect(room: Dictionary) -> Rect2:
	var cutaway_r := _room_rect_cutaway(room)
	if floor_plan_transition <= 0.001: return cutaway_r
	var topdown_r := _room_rect_topdown(room)
	if floor_plan_transition >= 0.999: return topdown_r
	var p := cutaway_r.position.lerp(topdown_r.position, floor_plan_transition)
	var s := cutaway_r.size.lerp(topdown_r.size, floor_plan_transition)
	return Rect2(p, s)

func _room_rect_cutaway(room: Dictionary) -> Rect2:
	return Rect2(float(room.get("x", 0)), float(room.get("y", 0)), float(room.get("width", 120)), float(room.get("height", 88)))

# Calculates top-down circular floor plan coordinates for an isolated level
func _room_rect_topdown(room: Dictionary) -> Rect2:
	var rid := int(room.get("id", 0))
	if topdown_rect_cache.has(rid): return topdown_rect_cache[rid]

	var lid := int(room.get("level", 1))
	var cy := _level_center_y(lid)
	var center := Vector2(0.0, cy)

	# Collect and sort all rooms on this level into special vs residential
	var level_rooms: Array = []
	for r in geometry.get("rooms", []):
		if int(r.get("level", 0)) == lid: level_rooms.append(r)

	level_rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", 0)) < int(b.get("id", 0)))

	var special_rooms: Array = []
	var res_rooms: Array = []
	for r in level_rooms:
		var rtype := int(r.get("room_type", 0))
		if rtype in [0]: # Residential apartment
			res_rooms.append(r)
		else:
			special_rooms.append(r)

	# 1. Special & Industrial Facilities: Placed in the four quadrant bays (between cardinal avenues)
	# connected to the diagonal secondary corridors and central ring
	var s_idx := special_rooms.find(room)
	if s_idx >= 0:
		var total_s := maxi(1, special_rooms.size())
		var quad_angles := [ -PI * 0.25, -PI * 0.75, PI * 0.75, PI * 0.25 ]
		var angle: float = quad_angles[s_idx % 4]
		if total_s > 4:
			angle += (float(s_idx / 4) * 0.22)
		var rad: float = 210.0 if total_s <= 4 else (165.0 + float(s_idx / 4) * 85.0)
		var r_pos := center + Vector2(cos(angle), sin(angle)) * rad
		var rw: float = clampf(float(room.get("width", 240.0)) * 0.65, 120.0, 220.0)
		var rh: float = clampf(float(room.get("height", 88.0)) * 0.85, 70.0, 95.0)
		var rect := Rect2(r_pos - Vector2(rw * 0.5, rh * 0.5), Vector2(rw, rh))
		topdown_rect_cache[rid] = rect
		return rect

	# 2. Residential Rooms: Flanking the 4 Cardinal Avenue Corridors in neat architectural blocks
	var r_idx := res_rooms.find(room)
	# 4 Cardinal Avenues: 0=North, 1=East, 2=South, 3=West
	var avenue_idx: int = r_idx % 4
	var avenue_slot: int = r_idx / 4 # slot along the avenue
	var side_sign: float = -1.0 if (avenue_slot % 2 == 0) else 1.0 # alternate left/right flank
	var depth_step: int = avenue_slot / 2 # 0, 1, 2, 3, 4 along corridor
	var dist_along: float = 135.0 + float(depth_step) * 52.0

	var rw_res: float = 64.0
	var rh_res: float = 46.0
	var rect_pos := center

	match avenue_idx:
		0: # North Avenue (Corridor X in [-16, 16], Y negative)
			var rx := center.x + (side_sign * (16.0 + rw_res * 0.5))
			var ry := center.y - dist_along
			rect_pos = Vector2(rx, ry)
		1: # East Avenue (Corridor Y in [-16, 16], X positive)
			var rx := center.x + dist_along
			var ry := center.y + (side_sign * (16.0 + rh_res * 0.5))
			rect_pos = Vector2(rx, ry)
			var swap := rw_res; rw_res = rh_res; rh_res = swap
		2: # South Avenue (Corridor X in [-16, 16], Y positive)
			var rx := center.x + (side_sign * (16.0 + rw_res * 0.5))
			var ry := center.y + dist_along
			rect_pos = Vector2(rx, ry)
		3: # West Avenue (Corridor Y in [-16, 16], X negative)
			var rx := center.x - dist_along
			var ry := center.y + (side_sign * (16.0 + rh_res * 0.5))
			rect_pos = Vector2(rx, ry)
			var swap := rw_res; rw_res = rh_res; rh_res = swap

	var res_rect := Rect2(rect_pos - Vector2(rw_res * 0.5, rh_res * 0.5), Vector2(rw_res, rh_res))
	topdown_rect_cache[rid] = res_rect
	return res_rect

func _room_label(room: Dictionary) -> String:
	var id := int(room.get("id", 0))
	if room_summary_by_id.has(id):
		var summary: Dictionary = room_summary_by_id[id]
		return str(summary.get("room_type_name", summary.get("name", "Room"))).to_upper()
	return "ROOM"
