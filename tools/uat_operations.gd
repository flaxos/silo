extends SceneTree

## Rendered Godot control automation, separate from human gameplay acceptance.
var world: SiloPhysicalWorld
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	print("GODOT_OPERATIONS_UAT %s %s" % ["PASS" if condition else "FAIL", message])
	if not condition: failures += 1

func _run() -> void:
	world = load("res://src/game/physical_world.tscn").instantiate()
	root.add_child(world)
	world._set_speed(0.0)
	world.session_path = "/tmp/silo-uat-session.save"
	await process_frame
	check(world.sidebar_tabs.current_tab == 0, "Operations is the default sidebar")
	world.engine.step(18); world._refresh_live()
	await process_frame
	check(world.operations_panel.case_list.item_count == 1, "real wear appears in operations queue")
	var first_item := world.operations_panel.case_list.get_item_rect(0)
	await _click_at(world.operations_panel.case_list.global_position + first_item.get_center())
	await process_frame
	var case_id := world.operations_panel.selected_case
	if case_id.is_empty():
		check(false, "pointer input selects a case")
		quit(1)
		return
	var ops := world.ws.custom_data.operations_system as OperationsSystem
	var c: Dictionary = ops.cases[case_id]
	check(world.selected_id == str(c.source_id) and world.selected_room_id == int(c.room_id), "case selection locates actual pump")
	check(world.operations_panel.detail_panel.evidence_text.text.contains("WHY?"), "causal evidence is visible")
	await _screenshot("/tmp/silo-operations-water.png")
	var panel_rect := world.panel.get_global_rect()
	var action_rect := world.operations_panel.detail_panel.apply_button.get_global_rect()
	print("GODOT_OPERATIONS_LAYOUT viewport=%s panel=%s action=%s" % [root.get_visible_rect(), panel_rect, action_rect])
	check(root.get_visible_rect().encloses(panel_rect), "sidebar stays inside viewport")
	check(panel_rect.encloses(action_rect), "decision control stays inside sidebar")
	check(panel_rect.size.x <= 430.0, "physical silo remains the main screen")
	check(root.get_visible_rect().encloses(world.pause_button.get_global_rect()), "time control stays visible")
	check(root.get_visible_rect().encloses(world.isolate_button.get_global_rect()), "top control bar fits viewport")
	world.operations_panel.detail_panel.entity_requested.emit({"type": "machine", "id": c.source_id, "room_id": c.room_id})
	check(world.sidebar_tabs.current_tab == 1 and world.details_label.text.contains("MACHINE"), "machine link opens existing inspector")
	world.sidebar_tabs.current_tab = 0
	await _click_at(world.operations_panel.detail_panel.apply_button.get_global_rect().get_center())
	check(c.pending == "request_service" and c.status != "RESOLVED", "UI queues an authorized request without repair")
	# Resume through the real time control. Explicit ticks then keep UAT deterministic.
	await _click_at(world.pause_button.get_global_rect().get_center())
	check(world.speed > 0.0, "resume control advances time")
	world._set_speed(0.0)
	world.engine.step(72); world._refresh_live()
	check(c.status == "RESOLVED", "real maintenance resolves water case")
	world.operations_panel.archive_toggle.button_pressed = true
	world._refresh_operations(false)
	world._open_operation(case_id)
	await _screenshot("/tmp/silo-operations-water-outcome.png")
	check(world.operations_panel.detail_panel.history_text.text.contains("Early-service slot reserved"), "original decision remains visible with final consequences")
	world.operations_panel.archive_toggle.button_pressed = false
	world._refresh_operations(false)
	var information_case := ""
	for candidate in ops.cases.values():
		if candidate.kind == "information" and candidate.status != "RESOLVED": information_case = candidate.id; break
	check(information_case != "", "non-infrastructure school report emerged from actual attendance")
	if information_case != "":
		world._open_operation(information_case)
		await _screenshot("/tmp/silo-operations-information.png")
		check(root.get_visible_rect().encloses(world.panel.get_global_rect()), "information detail fits viewport")
		await _click_at(world.operations_panel.detail_panel.apply_button.get_global_rect().get_center())
		world.engine.step(1); world._refresh_live()
		check(ops.cases[information_case].status == "RESOLVED", "publication UI delivers and resolves communication case")
		await _screenshot("/tmp/silo-operations-information-outcome.png")
	world.operations_panel.save_requested.emit()
	var saved_checksum := world.ws.get_state_checksum()
	world.engine.step(2)
	world.operations_panel.load_requested.emit()
	check(saved_checksum == world.ws.get_state_checksum(), "save/load controls restore exact simulation")
	check(world.speed == 0.0, "restored session is paused")
	print("GODOT_OPERATIONS_UAT failures=%d human_acceptance=NOT_RUN browser_uat=NOT_APPLICABLE" % failures)
	quit(1 if failures else 0)

func _screenshot(path: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img:
		img.save_png(path)
		print("GODOT_OPERATIONS_SCREENSHOT " + path)

func _click_at(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = position; event.global_position = position; event.pressed = pressed
		root.push_input(event, true)
		await process_frame
