class_name SiloPhysicalWorld
extends Node2D

## Read-model-only Godot cutaway. Simulation systems own all state; this node
## advances the engine and redraws PhysicalReader projections in one batch.

const Reader = preload("res://src/presentation/physical_reader.gd")
const LayoutConfig = preload("res://src/sim/spatial/silo_layout_config.gd")

const ROOM_COLORS := {
	0: Color("455266"), 1: Color("5f7892"), 2: Color("c7894b"),
	3: Color("9b665c"), 4: Color("56836a"), 5: Color("4c8b91"),
	6: Color("7d6a9c"), 7: Color("a0738b"), 8: Color("8a774d"),
	9: Color("72564b"), 10: Color("49647f"), 11: Color("8b5d50"),
	12: Color("758d55"), 13: Color("536d88"), 14: Color("815e72"),
	15: Color("69717b"), 16: Color("746147"), 17: Color("4e806d")
}
const BG := Color("111820")
const ROCK := Color("25272b")
const INK := Color("d5e1e8")
const MUTED := Color("82949f")
const ACCENT := Color("f1b95b")

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
var search_edit: LineEdit
var search_results: ItemList
var level_picker: OptionButton
var status_label: Label
var follow_button: Button
var uat_frames := 0
var frames_drawn := 0
var process_usec_total := 0
var draw_usec_total := 0
var frame_seconds_total := 0.0
var population_size := 1200
var sim_seed := 42
var uat_screenshot := ""

func _ready() -> void:
	_parse_args()
	_boot_simulation()
	_build_indexes()
	_build_camera()
	_build_ui()
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
		else: i += 1

func _boot_simulation() -> void:
	engine = SimulationEngine.new(sim_seed)
	ws = engine.get_world_state()
	PopulationGenerator.generate_population(ws, population_size)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	# Same active physical systems as the observer bootstrap. Presentation never
	# writes to their state; only SimulationEngine.step does.
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
	var top := PanelContainer.new(); top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 54; top.add_theme_stylebox_override("panel", _panel_style(Color("e6111820")))
	layer.add_child(top)
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 8); top.add_child(bar)
	var title := Label.new(); title.text = "  SILO  /  PHYSICAL LAYER"; title.add_theme_color_override("font_color", ACCENT); bar.add_child(title)
	status_label = Label.new(); status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.add_child(status_label)
	for spec in [["⏸", 0], ["1×", 1], ["4×", 4], ["16×", 16]]:
		var button := Button.new(); button.text = spec[0]; button.pressed.connect(_set_speed.bind(spec[1])); bar.add_child(button)
	var fit := Button.new(); fit.text = "Fit [F]"; fit.pressed.connect(_fit_whole); bar.add_child(fit)
	level_picker = OptionButton.new(); level_picker.tooltip_text = "Jump to level"
	level_picker.item_selected.connect(_level_selected); bar.add_child(level_picker)
	for lev in geometry.get("levels", []):
		level_picker.add_item("Level %s" % lev.get("id", "?")); level_picker.set_item_metadata(level_picker.item_count - 1, lev.get("id", 0))
	var isolate := Button.new(); isolate.text = "Isolate [I]"; isolate.pressed.connect(_toggle_isolate); bar.add_child(isolate)

	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -355; panel.offset_top = 62; panel.offset_right = -10; panel.offset_bottom = -14
	panel.add_theme_stylebox_override("panel", _panel_style(Color("f2172029"))); layer.add_child(panel)
	var side := VBoxContainer.new(); side.add_theme_constant_override("separation", 8); panel.add_child(side)
	var search_title := Label.new(); search_title.text = "FIND PERSON · HOUSEHOLD · ROOM · MACHINE"; search_title.add_theme_color_override("font_color", ACCENT); side.add_child(search_title)
	var legend := RichTextLabel.new(); legend.bbcode_enabled = true; legend.fit_content = true
	legend.text = "[color=#d8bf8c]■[/color] Housing  [color=#4dbf4d]■[/color] Bio-farm  [color=#e6f2e6]■[/color] Clinic\n[color=#668ccc]■[/color] School  [color=#d95933]■[/color] Industry  [color=#4d8cd9]■[/color] Water"
	side.add_child(legend)
	search_edit = LineEdit.new(); search_edit.placeholder_text = "Name, type, or stable ID…"; search_edit.text_changed.connect(_search); search_edit.text_submitted.connect(func(_q: String): _activate_first_search()); side.add_child(search_edit)
	search_results = ItemList.new(); search_results.custom_minimum_size.y = 118; search_results.item_selected.connect(_search_selected); side.add_child(search_results)
	var sep := HSeparator.new(); side.add_child(sep)
	details_label = RichTextLabel.new(); details_label.bbcode_enabled = true; details_label.fit_content = false; details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; details_label.text = "[color=#82949f]Click a citizen, room, machine, or stair.[/color]"; side.add_child(details_label)
	follow_button = Button.new(); follow_button.text = "Follow selected citizen [G]"; follow_button.disabled = true; follow_button.pressed.connect(_toggle_follow); side.add_child(follow_button)
	var help := Label.new(); help.text = "Wheel: zoom   RMB/MMB: pan   WASD: move\nF: whole silo   I: isolate   G: follow   Space: pause"; help.add_theme_color_override("font_color", MUTED); side.add_child(help)
	_update_status()

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = color; style.border_color = Color("485866")
	style.set_border_width_all(1); style.set_corner_radius_all(5); style.set_content_margin_all(10); return style

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
	# Incident locations are an explicit reader projection; silo-wide incidents
	# remain unplaced instead of being assigned a presentation-only room.
	snapshot["incidents"] = Reader.get_incident_locations(ws)
	_update_status()
	if not selected_type.is_empty(): _show_details(selected_type, selected_id)

func _update_status() -> void:
	if not status_label: return
	var clock: Dictionary = snapshot.get("clock", {})
	status_label.text = "   Year %s · Day %s · %s   |   %d residents   |   tick %s" % [clock.get("year", 1), clock.get("day_of_year", clock.get("day", 1)), clock.get("time", clock.get("time_string", "00:00")), people_by_id.size(), snapshot.get("revision", 0)]

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
	var b := _bounds_rect().grow(150.0)
	draw_rect(b, ROCK, true)
	draw_rect(_bounds_rect().grow(28.0), BG, true)
	for level in geometry.get("levels", []):
		if isolated_level != null and int(level.get("id", 0)) != int(isolated_level): continue
		var y := float(level.get("y", 0.0))
		draw_line(Vector2(b.position.x + 150, y + 82), Vector2(b.end.x - 150, y + 82), Color("33414a"), 3)
		draw_string(ThemeDB.fallback_font, Vector2(b.position.x + 160, y + 18), "LEVEL %s" % level.get("id", "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)

func _draw_rooms() -> void:
	var z := camera.zoom.x
	for room in geometry.get("rooms", []):
		if isolated_level != null and int(room.get("level", 0)) != int(isolated_level): continue
		var rect := _room_rect(room)
		var selected := selected_type == "room" and selected_id == str(room.get("id", 0))
		var c: Color = LayoutConfig.get_room_color(int(room.get("room_type", 0)))
		draw_rect(rect, c.darkened(0.18), true)
		draw_rect(rect, ACCENT if selected else c.lightened(0.18), false, 4 if selected else 2)
		# Repeated bays give the wireframe depth without creating scene nodes.
		if z >= 0.3:
			for bx in range(1, maxi(1, int(rect.size.x / 36.0))): draw_line(Vector2(rect.position.x + bx * 36, rect.end.y - 9), Vector2(rect.position.x + bx * 36, rect.end.y), c.lightened(0.25), 1)
		if z >= 0.32:
			var label := _room_label(room)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(7, 19), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12, 13, INK)
			if z >= 0.55: draw_string(ThemeDB.fallback_font, rect.position + Vector2(7, 38), "#%s · cap %s" % [room.get("id", "?"), room.get("capacity", "—")], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12, 11, MUTED)

func _draw_stairs() -> void:
	var segments: Array = geometry.get("stair_segments", geometry.get("connectors", []))
	if segments.is_empty(): return
	for seg in segments:
		if isolated_level != null and int(seg.get("from_level", -999)) != int(isolated_level) and int(seg.get("to_level", -999)) != int(isolated_level): continue
		var a := _landing_point(seg.get("from_level", 0), seg)
		var b := _landing_point(seg.get("to_level", 0), seg, true)
		draw_line(a, b, Color("dda84e"), 22)
		draw_line(a, b, Color("3c3428"), 14)
		var count := maxi(3, int(absf(b.y - a.y) / 12.0))
		for i in range(count + 1):
			var p := a.lerp(b, float(i) / count); draw_line(p + Vector2(-9, 0), p + Vector2(9, 0), ACCENT, 2)
		if camera.zoom.x >= 0.32:
			var occ := int(seg.get("occupancy", 0)); var cap := int(seg.get("capacity", 0)); var queue := int(seg.get("queue", 0))
			draw_string(ThemeDB.fallback_font, a.lerp(b, .5) + Vector2(16, 0), "%d/%d  q%d" % [occ, cap, queue], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ACCENT)
	for landing in geometry.get("landings", []):
		if isolated_level != null and int(landing.get("level", 0)) != int(isolated_level): continue
		var p := Vector2(float(landing.get("x", 0)), float(landing.get("y", 0)))
		draw_rect(Rect2(p - Vector2(25, 5), Vector2(50, 10)), ACCENT, true)

func _landing_point(level_id: Variant, seg: Dictionary, destination := false) -> Vector2:
	for landing in geometry.get("landings", []):
		if int(landing.get("level", -999)) == int(level_id): return Vector2(float(landing.get("x", 0)), float(landing.get("y", 0)))
	var x := float(seg.get("x", _bounds_rect().get_center().x))
	var y := 0.0
	for level in geometry.get("levels", []):
		if int(level.get("id", -999)) == int(level_id): y = float(level.get("y", 0)) + 40.0; break
	return Vector2(x + (18.0 if destination else -18.0), y)

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
	for rid in buckets:
		var people: Array = buckets[rid]; var room: Dictionary = room_by_id[rid]; var rect := _room_rect(room)
		if z < 0.18:
			var radius := clampf(sqrt(float(people.size())) * 2.2, 3, 13); draw_circle(rect.get_center(), radius, Color("6ad6db")); continue
		var max_visible := people.size() if z >= 0.55 else mini(people.size(), 28)
		for i in range(max_visible):
			var p: Dictionary = people[i]; var columns := maxi(2, int(rect.size.x / 11.0))
			var pos := rect.position + Vector2(8 + (i % columns) * 10, rect.size.y - 12 - (i / columns) * 10)
			if str(p.get("activity", "")).to_lower().contains("travel"):
				pos = _journey_position(p, pos)
			person_draw_positions[int(p.get("id", 0))] = pos
			var chosen := selected_type == "person" and selected_id == str(p.get("id", 0))
			draw_circle(pos, 5 if chosen else 3.2, ACCENT if chosen else Color("6ad6db"))
			if chosen: draw_arc(pos, 8, 0, TAU, 16, Color.WHITE, 1.5)

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
		var pos := _room_rect(room).position + Vector2(15, 50)
		machine_draw_positions[int(machine.get("id", 0))] = pos
		var poor := str(machine.get("state", "NOMINAL")) in ["FAULT", "BROKEN"]
		draw_rect(Rect2(pos - Vector2(6, 6), Vector2(12, 12)), Color("e75d57") if poor else Color("9fc06c"), true)
	for incident in snapshot.get("incidents", {}).get("active_incidents", []):
		var rid := int(incident.get("room_id", 0))
		if room_by_id.has(rid): draw_circle(_room_rect(room_by_id[rid]).position + Vector2(30, 50), 7, Color("ff4d58"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: _zoom(1.18, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: _zoom(0.84, mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mb.pressed; drag_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.position.x < get_viewport_rect().size.x - 365:
			_pick(get_global_mouse_position())
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion; camera.position -= mm.relative / camera.zoom; follow_person_id = 0
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F: _fit_whole()
			KEY_I: _toggle_isolate()
			KEY_G: _toggle_follow()
			KEY_SPACE: _set_speed(0 if speed > 0 else 1)
			KEY_ESCAPE: isolated_level = null; follow_person_id = 0; queue_redraw()

func _zoom(factor: float, screen: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * screen
	var z := clampf(camera.zoom.x * factor, 0.07, 3.5); camera.zoom = Vector2(z, z)
	var after := get_canvas_transform().affine_inverse() * screen; camera.position += before - after

func _pick(point: Vector2) -> void:
	# Exact cached draw positions keep overlapping entity types independently
	# selectable without allocating a Node for each citizen.
	if camera.zoom.x >= 0.45:
		for mid in machine_draw_positions:
			if (machine_draw_positions[mid] as Vector2).distance_to(point) <= 10.0:
				_select("machine", str(mid), int(machine_by_id[mid].get("room_id", 0))); return
		var nearest_person := 0; var nearest_distance := 9.0
		for pid in person_draw_positions:
			var distance := (person_draw_positions[pid] as Vector2).distance_to(point)
			if distance < nearest_distance: nearest_distance = distance; nearest_person = int(pid)
		if nearest_person > 0:
			_select("person", str(nearest_person), int(people_by_id[nearest_person].get("location_id", 0))); return
	for room in geometry.get("rooms", []):
		if _room_rect(room).has_point(point): _select("room", str(room.get("id", 0)), int(room.get("id", 0))); return
	for seg in geometry.get("stair_segments", geometry.get("connectors", [])):
		var a := _landing_point(seg.get("from_level", 0), seg); var b := _landing_point(seg.get("to_level", 0), seg, true)
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < 14: _select_stair(seg); return

func _select(type: String, id: String, room_id: int) -> void:
	selected_type = type; selected_id = id; selected_room_id = room_id
	follow_button.disabled = type != "person"; _show_details(type, id); queue_redraw()

func _select_stair(seg: Dictionary) -> void:
	selected_type = "stair"; selected_id = str(seg.get("id", "stair")); selected_room_id = 0; follow_button.disabled = true
	details_label.text = "[font_size=20][color=#f1b95b]CENTRAL STAIR[/color][/font_size]\n\n%s\nLevels %s → %s\nCapacity: %s\nOccupancy: %s\nQueue: %s\nBase travel: %s ticks\nCongestion: %s\nEstimated travel: %s ticks" % [selected_id, seg.get("from_level", "?"), seg.get("to_level", "?"), seg.get("capacity", "pending"), seg.get("occupancy", 0), seg.get("queue_length", 0), seg.get("base_travel_ticks", "pending"), str(seg.get("congestion", false)), seg.get("travel_time_ticks_estimate", seg.get("base_travel_ticks", "pending"))]

func _show_details(type: String, id: String) -> void:
	var resolved := Reader.resolve_entity(ws, type, id)
	if resolved.is_empty(): details_label.text = "[color=#e75d57]Entity no longer available.[/color]"; return
	selected_room_id = int(resolved.get("room_id", selected_room_id))
	details_label.text = "[font_size=20][color=#f1b95b]%s  #%s[/color][/font_size]\n[color=#82949f]authoritative read model[/color]\n\n%s" % [type.to_upper(), id, _format_value(resolved.get("details", {}), 0)]

func _format_value(value: Variant, depth: int) -> String:
	if depth > 2: return str(value)
	if value is Dictionary:
		var lines: Array[String] = []
		for key in value.keys():
			var v: Variant = value[key]
			if v is Dictionary or v is Array: lines.append("[color=#82949f]%s[/color]\n%s" % [_pretty(str(key)), _format_value(v, depth + 1)])
			else: lines.append("[color=#82949f]%s[/color]  %s" % [_pretty(str(key)), str(v)])
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
		search_results.add_item("%s  ·  %s  #%s" % [result.get("label", "?"), result.get("type", "?"), result.get("id", "?")])
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
	follow_button.text = "Stop following [G]" if follow_person_id > 0 else "Follow selected citizen [G]"

func _level_selected(index: int) -> void:
	var level_id: Variant = level_picker.get_item_metadata(index); isolated_level = level_id
	for level in geometry.get("levels", []):
		if int(level.get("id", -999)) == int(level_id): camera.position.y = float(level.get("y", 0)) + 36; camera.zoom = Vector2.ONE * 0.55; break
	queue_redraw()

func _toggle_isolate() -> void:
	if isolated_level != null: isolated_level = null
	elif selected_room_id > 0 and room_by_id.has(selected_room_id): isolated_level = room_by_id[selected_room_id].get("level", null)
	queue_redraw()

func _set_speed(value: int) -> void: speed = value

func _fit_whole() -> void:
	isolated_level = null; follow_person_id = 0
	var rect := _bounds_rect().grow(100); camera.position = rect.get_center()
	var viewport := get_viewport_rect().size - Vector2(380, 90)
	var z := clampf(minf(viewport.x / maxf(1, rect.size.x), viewport.y / maxf(1, rect.size.y)), 0.07, 1.0)
	camera.zoom = Vector2.ONE * z; queue_redraw()

func _bounds_rect() -> Rect2:
	var b: Dictionary = geometry.get("bounds", {})
	return Rect2(float(b.get("x", 0)), float(b.get("y", 0)), maxf(1, float(b.get("width", 1000))), maxf(1, float(b.get("height", 1000))))

func _room_rect(room: Dictionary) -> Rect2:
	return Rect2(float(room.get("x", 0)), float(room.get("y", 0)), float(room.get("width", 100)), float(room.get("height", 72)))

func _room_label(room: Dictionary) -> String:
	var id := int(room.get("id", 0))
	if room_summary_by_id.has(id):
		var summary: Dictionary = room_summary_by_id[id]
		return str(summary.get("room_type_name", summary.get("name", "Room"))).to_upper()
	return "ROOM"
