class_name OperationsPanel
extends VBoxContainer

signal case_selected(case_id: String)
signal entity_requested(reference: Dictionary)
signal action_requested(case_id: String, action_id: String)
signal save_requested
signal load_requested
var heading: Label
var brief_label: Label
var case_list: ItemList
var archive_toggle: CheckButton
var detail_panel: CaseDetailPanel
var feedback: Label
var selected_case := ""
var rows: Array = []
var auto_pause: CheckButton
var show_all := false

func _init() -> void:
	name = "Operations"
	add_theme_constant_override("separation", 3)
	heading = Label.new(); heading.text = "OPERATIONS · HEAD OF IT"; add_child(heading)
	brief_label = Label.new(); brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(brief_label)
	var toggles := HBoxContainer.new(); add_child(toggles)
	auto_pause = CheckButton.new(); auto_pause.text = "Auto-pause"; auto_pause.tooltip_text = "Pause when a new real-state case is detected"; auto_pause.button_pressed = true; auto_pause.focus_mode = Control.FOCUS_NONE; toggles.add_child(auto_pause)
	archive_toggle = CheckButton.new(); archive_toggle.text = "Outcomes"; archive_toggle.focus_mode = Control.FOCUS_NONE; toggles.add_child(archive_toggle)
	case_list = ItemList.new(); case_list.custom_minimum_size.y = 50; case_list.focus_mode = Control.FOCUS_NONE
	case_list.item_selected.connect(_selected); add_child(case_list)
	detail_panel = CaseDetailPanel.new(); detail_panel.visible = false
	detail_panel.entity_requested.connect(func(ref: Dictionary): entity_requested.emit(ref))
	detail_panel.action_requested.connect(func(id: String, action: String): action_requested.emit(id, action))
	add_child(detail_panel)
	feedback = Label.new(); feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; feedback.add_theme_font_size_override("font_size", 11); add_child(feedback)
	var footer := HBoxContainer.new(); add_child(footer)
	for label in ["Save session", "Load session"]:
		var button := Button.new(); button.text = label; button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 10)
		button.custom_minimum_size.y = 22
		footer.add_child(button)
		if label == "Save session": button.pressed.connect(func(): save_requested.emit())
		else: button.pressed.connect(func(): load_requested.emit())

func refresh(brief: Dictionary, detail: Dictionary) -> void:
	heading.text = "OPERATIONS · %d OPEN" % brief.active_count
	brief_label.visible = selected_case.is_empty()
	feedback.visible = not feedback.text.is_empty()
	feedback.max_lines_visible = 2
	feedback.tooltip_text = feedback.text
	brief_label.text = "Investigate → choose → resume → review outcome.\nIT may request early service and manage official reports."
	if int(brief.active_count) == 0:
		brief_label.text = "No open cases. Let time advance.\nTelemetry and institutional reports will surface real conditions."
	rows = brief.archive if archive_toggle.button_pressed else brief.active
	# Show all overflow on request; top three are the default attention budget.
	var limit := rows.size() if archive_toggle.button_pressed or show_all else mini(OperationsConfig.VISIBLE_CASES, rows.size())
	case_list.clear()
	for i in range(limit):
		var row: Dictionary = rows[i]
		var sev := str(row.get("severity_text", severity_name(int(row.get("severity", 1)))))
		var st := str(row.get("status_text", row.get("status", "")))
		case_list.add_item("[%s] · %s\n%s · %s" % [sev, row.title, row.location, st])
		if str(row.id) == selected_case: case_list.select(i)
		case_list.set_item_tooltip(i, "%s · %s" % [row.id, row.title])
	if rows.size() > limit:
		case_list.add_item("+ %d more cases — click to show all" % (rows.size() - limit))
	detail_panel.show_case(detail)

func _selected(index: int) -> void:
	if not archive_toggle.button_pressed and not show_all and index == OperationsConfig.VISIBLE_CASES and rows.size() > OperationsConfig.VISIBLE_CASES:
		show_all = true
		case_list.clear()
		for row in rows: case_list.add_item("%s · %s · %s" % [row.id, row.title, row.status])
		return
	if index >= rows.size(): return
	selected_case = str(rows[index].id)
	feedback.text = ""
	case_selected.emit(selected_case)

static func severity_name(severity: int) -> String:
	return "URGENT" if severity >= 3 else ("HIGH" if severity >= 2 else "REVIEW")
